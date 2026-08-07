import { execFile } from "node:child_process";
import { realpath } from "node:fs/promises";
import { isAbsolute, join, relative, resolve } from "node:path";
import { promisify } from "node:util";

import { getSkillOwner } from "./catalog.js";
import {
  translateOwnedPrompt,
  translateToolOutput,
} from "./translate.js";

const ARGUMENT_EXPORT =
  /^[ \t]*export[ \t]+ARCHITECT_CRITIC_ARGS=(?:"((?:\\[^\r\n]|[^"\\\r\n])*)"|'([^'\r\n]*)')[ \t]*(?:\r?\n)?$/;
const SKILL_BASE_DIRECTORY =
  /(?:^|\r?\n)Base directory for this skill: ([^\r\n]+)(?=\r?\n|$)/g;
const FORBIDDEN_GIT_VERBS = new Set(["commit", "push", "pull", "fetch"]);
const ALLOWED_GIT_OPERATIONS = new Set(["status", "rev-parse", "diff", "add"]);
const GIT_INFORMATION_OPTIONS = new Set([
  "-v",
  "--version",
  "-h",
  "--help",
  "--exec-path",
  "--html-path",
  "--man-path",
  "--info-path",
  "--list-cmds",
]);
const GIT_OPTIONS_WITH_VALUE = new Set([
  "-C",
  "--git-dir",
  "--work-tree",
  "--namespace",
  "--super-prefix",
  "--config-env",
  "--attr-source",
  "--exec-path",
]);
const SHELL_SEPARATORS = new Set([
  ";",
  "&",
  "|",
  "(",
  ")",
  "<",
  ">",
  "`",
  "#",
]);
const MAX_AUDIT_QUOTE_DEPTH = 8;
const SESSION_START_TIMEOUT_MS = 5_000;
const execFileAsync = promisify(execFile);

function containsPath(root, filePath) {
  const nested = relative(root, filePath);
  return nested === "" || (!nested.startsWith("..") && !isAbsolute(nested));
}

async function resolvedPath(filePath) {
  try {
    return await realpath(filePath);
  } catch {
    return;
  }
}

async function ownedPath(owner, filePath) {
  if (typeof filePath !== "string" || !isAbsolute(filePath)) return;
  const [root, candidate] = await Promise.all([
    resolvedPath(owner.root),
    resolvedPath(filePath),
  ]);
  if (root && candidate && containsPath(root, candidate)) return candidate;
}

function commandSkillDirectory(parts) {
  const directories = parts.flatMap((part) =>
    part.type === "text" && typeof part.text === "string"
      ? [...part.text.matchAll(SKILL_BASE_DIRECTORY)].map((match) => match[1])
      : [],
  );
  return directories.length === 1 ? directories[0] : undefined;
}

function exportedArguments(command) {
  if (typeof command !== "string") return;
  const match = ARGUMENT_EXPORT.exec(command);
  if (!match) return;
  if (match[2] !== undefined) return match[2];

  let value = "";
  for (let index = 0; index < match[1].length; index += 1) {
    const character = match[1][index];
    if (character === "$" || character === "`") return;
    if (character !== "\\") {
      value += character;
      continue;
    }

    const escaped = match[1][index + 1];
    index += 1;
    value += '"\\$`'.includes(escaped) ? escaped : `\\${escaped}`;
  }
  return value;
}

function isGitExecutable(token) {
  return token.value === "git" || token.value.endsWith("/git");
}

function ansiWhitespaceEscape(command, index) {
  const escaped = command.slice(index + 1);
  let match;
  let radix = 16;
  if (escaped.startsWith("t")) match = ["t", "9"];
  else if ((match = /^x([0-9a-f]{1,2})/i.exec(escaped))) {
    match = [match[0], match[1]];
  } else if ((match = /^([0-7]{1,3})/.exec(escaped))) {
    match = [match[0], match[1]];
    radix = 8;
  } else if ((match = /^u([0-9a-fA-F]{1,4})/.exec(escaped))) {
    match = [match[0], match[1]];
  } else if ((match = /^U([0-9a-fA-F]{1,8})/.exec(escaped))) {
    match = [match[0], match[1]];
  } else {
    return;
  }

  const codePoint = Number.parseInt(match[1], radix);
  if (codePoint !== 0x09 && codePoint !== 0x20) return;
  return match[0].length;
}

function hasUnescapedCloser(command, index, closer) {
  for (let next = index + 1; next < command.length; next += 1) {
    if (command[next] === "\\" && command[next + 1] !== undefined) {
      next += 1;
      continue;
    }
    if (command[next] === closer) return true;
  }
  return false;
}

function opensSingleQuote(command, index, value) {
  if (!hasUnescapedCloser(command, index, "'")) return false;
  if (
    !value ||
    !/[A-Za-z0-9_]$/.test(value) ||
    !/[A-Za-z0-9_]/.test(command[index + 1] ?? "")
  ) {
    return true;
  }
  for (let next = index + 1; next < command.length; next += 1) {
    const character = command[next];
    if (character === "\\" && command[next + 1] !== undefined) {
      next += 1;
      continue;
    }
    if (character === "'") return true;
    if (/\s/.test(character) || SHELL_SEPARATORS.has(character)) return false;
  }
  return false;
}

function auditTokens(command) {
  const tokens = [];
  let value = "";
  const quoteStack = [];
  let nextQuoteGroup = 0;
  let quoteStart = false;
  let separated = true;

  function activeQuote() {
    return quoteStack[quoteStack.length - 1];
  }

  function flushWord() {
    if (!value) return;
    tokens.push({
      type: "word",
      value,
      quoteGroup: activeQuote()?.group,
      quoteStart,
      joinedToPrevious: !separated,
    });
    value = "";
    quoteStart = false;
    separated = false;
  }

  for (let index = 0; index < command.length; index += 1) {
    const character = command[index];
    if (
      character === "$" &&
      command[index + 1] === "'" &&
      quoteStack.length < MAX_AUDIT_QUOTE_DEPTH &&
      hasUnescapedCloser(command, index + 1, "'")
    ) {
      flushWord();
      quoteStack.push({ marker: "ansi", group: nextQuoteGroup });
      nextQuoteGroup += 1;
      quoteStart = true;
      index += 1;
      continue;
    }
    if (activeQuote()?.marker === "ansi" && character === "'") {
      flushWord();
      quoteStack.pop();
      quoteStart = false;
      continue;
    }
    const quote = activeQuote();
    const closesQuote = quote?.marker === character;
    const opensQuote =
      quoteStack.length < MAX_AUDIT_QUOTE_DEPTH &&
      (character === "'"
        ? opensSingleQuote(command, index, value)
        : (character === '"' || character === "`") &&
          hasUnescapedCloser(command, index, character));
    if (closesQuote || opensQuote) {
      flushWord();
      if (closesQuote) {
        quoteStack.pop();
        quoteStart = false;
      } else {
        quoteStack.push({ marker: character, group: nextQuoteGroup });
        nextQuoteGroup += 1;
        quoteStart = true;
      }
      continue;
    }
    if (activeQuote()?.marker === "ansi" && character === "\\") {
      const escapeLength = ansiWhitespaceEscape(command, index);
      if (escapeLength) {
        flushWord();
        separated = true;
        index += escapeLength;
        continue;
      }
    }
    if (character === "\\" && command[index + 1] !== undefined) {
      value += command[index + 1];
      index += 1;
      continue;
    }
    if (/\s/.test(character)) {
      flushWord();
      separated = true;
      continue;
    }
    if (SHELL_SEPARATORS.has(character)) {
      flushWord();
      if (quoteStack.length > 0) {
        separated = true;
        continue;
      }
      tokens.push({ type: "separator" });
      quoteStart = false;
      separated = true;
      if (command[index + 1] === character) index += 1;
      continue;
    }

    value += character;
  }
  flushWord();
  return tokens;
}

function isGitAliasConfig(value) {
  const separator = value.indexOf("=");
  const key = separator === -1 ? value : value.slice(0, separator);
  return key.toLowerCase().startsWith("alias.");
}

function optionValue(tokens, index, inlineValue) {
  const firstIndex = inlineValue === undefined ? index + 1 : index;
  const first = tokens[firstIndex];
  if (first?.type !== "word") return;

  let last = firstIndex;
  while (true) {
    const current = tokens[last];
    if (current.quoteStart && current.quoteGroup !== undefined) {
      while (tokens[last + 1]?.quoteGroup === current.quoteGroup) last += 1;
    }
    if (!tokens[last + 1]?.joinedToPrevious) break;
    last += 1;
  }
  const pieces = tokens.slice(firstIndex, last + 1);
  let value = inlineValue === undefined ? pieces[0].value : inlineValue;
  for (const piece of pieces.slice(1)) {
    value += `${piece.joinedToPrevious ? "" : " "}${piece.value}`;
  }
  return {
    value,
    index: last,
  };
}

function gitInvocationVerb(tokens, index) {
  for (let next = index + 1; next < tokens.length; next += 1) {
    const token = tokens[next];
    if (token.type === "separator") break;
    const word = token.value;

    if (
      GIT_INFORMATION_OPTIONS.has(word) ||
      word.startsWith("--list-cmds=")
    ) {
      return;
    }
    if (word === "-c") {
      const value = optionValue(tokens, next);
      if (!value) break;
      if (isGitAliasConfig(value.value)) {
        throw new Error(
          "ossify-implementer-agent cannot run inline Git alias configuration",
        );
      }
      next = value.index;
      continue;
    }
    if (word.startsWith("-c") && word.length > 2) {
      const inlineValue = word.slice(2).replace(/^=/, "");
      const value = optionValue(tokens, next, inlineValue);
      if (isGitAliasConfig(value.value)) {
        throw new Error(
          "ossify-implementer-agent cannot run inline Git alias configuration",
        );
      }
      next = value.index;
      continue;
    }
    if (word === "--config-env" || word.startsWith("--config-env=")) {
      const inlineValue = word.includes("=")
        ? word.slice(word.indexOf("=") + 1)
        : undefined;
      const value = optionValue(tokens, next, inlineValue);
      if (!value) break;
      if (isGitAliasConfig(value.value)) {
        throw new Error(
          "ossify-implementer-agent cannot run inline Git alias configuration",
        );
      }
      next = value.index;
      continue;
    }

    const option = word.split("=", 1)[0];
    if (GIT_OPTIONS_WITH_VALUE.has(option)) {
      if (option === "--exec-path" && word === option) return;
      const inlineValue = word.includes("=")
        ? word.slice(word.indexOf("=") + 1)
        : undefined;
      const value = optionValue(tokens, next, inlineValue);
      if (!value) break;
      next = value.index;
      continue;
    }
    if (word.startsWith("-")) continue;
    if (FORBIDDEN_GIT_VERBS.has(word)) return word;
    if (!ALLOWED_GIT_OPERATIONS.has(word)) {
      throw new Error(
        `ossify-implementer-agent cannot run unknown Git subcommand ${word}`,
      );
    }
    return;
  }
  throw new Error(
    "ossify-implementer-agent requires a canonical Git subcommand",
  );
}

function forbiddenGitVerb(command) {
  const tokens = auditTokens(command);
  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token.type !== "word") continue;
    if (isGitExecutable(token)) {
      const nextToken = tokens[index + 1];
      if (
        token.quoteGroup !== undefined &&
        nextToken?.quoteGroup === token.quoteGroup &&
        isGitExecutable(nextToken)
      ) {
        continue;
      }
      const verb = gitInvocationVerb(tokens, index);
      if (verb) return verb;
    }
  }
}

export function createRuntime({
  selected,
  registeredCommands,
  registeredAgents,
  directory = process.cwd(),
  sessionStartTimeoutMs = SESSION_START_TIMEOUT_MS,
}) {
  const selectedNames = new Set(selected.map(({ name }) => name));
  const architectCritic = selected.find(
    ({ name }) => name === "architect-critic",
  );
  const architectCriticSelected = Boolean(architectCritic);
  const sessions = new Map();
  const sessionAgents = new Map();
  const sessionStartAttempts = new Set();

  return {
    "chat.message": async ({ sessionID, agent }) => {
      if (typeof agent === "string" && agent.trim()) {
        if (registeredAgents.has(agent)) sessionAgents.set(sessionID, agent);
        else sessionAgents.delete(sessionID);
      }

      const state = sessions.get(sessionID);
      if (!state) return;
      if (state.preserveCommandMessage) {
        state.preserveCommandMessage = false;
        return;
      }
      sessions.delete(sessionID);
    },

    "command.execute.before": async (input, output) => {
      let owner = registeredCommands.get(input.command);
      if (!owner) {
        owner = getSkillOwner(input.command);
        if (!owner || !selectedNames.has(owner.name)) return;
        const baseDirectory = commandSkillDirectory(output.parts);
        if (!baseDirectory || !(await ownedPath(owner, baseDirectory))) return;
      }

      for (const part of output.parts) {
        if (part.type === "text" && typeof part.text === "string") {
          part.text = translateOwnedPrompt(part.text, owner, input.command);
        }
      }

      if (owner.name === "architect-critic") {
        sessions.set(input.sessionID, {
          arguments: input.arguments,
          preserveCommandMessage: true,
        });
      }
    },

    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return;
      if (typeof input.sessionID !== "string" || !input.sessionID.trim()) {
        throw new Error("bash tool call requires a valid nonempty sessionID");
      }
      const command = output.args?.command;
      if (typeof command !== "string") {
        throw new Error("bash tool call requires a valid bash command");
      }
      if (
        registeredAgents.has("ossify-implementer-agent") &&
        sessionAgents.get(input.sessionID) === "ossify-implementer-agent"
      ) {
        const verb = forbiddenGitVerb(command);
        if (verb) {
          throw new Error(
            `ossify-implementer-agent cannot run git ${verb}`,
          );
        }
      }

      if (!architectCriticSelected) return;
      const args = exportedArguments(command);
      if (args !== undefined) {
        sessions.set(input.sessionID, {
          arguments: args,
          preserveCommandMessage: false,
        });
      }
    },

    "tool.execute.after": async (input, output) => {
      if (input.tool === "skill") {
        const owner = getSkillOwner(input.args?.name);
        if (!owner || !selectedNames.has(owner.name)) return;
        const skillDirectory = await ownedPath(owner, output.metadata?.dir);
        if (!skillDirectory) return;
        translateToolOutput(
          input.tool,
          { ...input.args, owner, filePath: skillDirectory },
          output,
        );
        return;
      }
      if (input.tool !== "read" || typeof input.args?.filePath !== "string") {
        return;
      }

      const requestedPath = resolve(directory, input.args.filePath);
      const filePath = await resolvedPath(requestedPath);
      if (!filePath) return;
      for (const owner of selected) {
        const root = await resolvedPath(owner.root);
        if (root && containsPath(root, filePath)) {
          translateToolOutput(
            "read",
            { ...input.args, filePath, owner },
            output,
          );
          return;
        }
      }
    },

    "shell.env": async (input, output) => {
      if (!input.sessionID) return;
      const state = sessions.get(input.sessionID);
      if (state) {
        output.env.ARCHITECT_CRITIC_ARGS = state.arguments;
      }
    },

    "experimental.chat.messages.transform": async (_input, output) => {
      if (!architectCritic) return;
      if (!Array.isArray(output?.messages)) return;
      const firstUser = output.messages.find(
        (message) => message?.info?.role === "user",
      );
      const sessionID = firstUser?.info?.sessionID;
      if (typeof sessionID !== "string" || !sessionID.trim()) return;
      if (!Array.isArray(firstUser.parts)) return;
      const firstText = firstUser.parts.find(
        (part) => part?.type === "text" && typeof part.text === "string",
      );
      if (!firstText || sessionStartAttempts.has(sessionID)) return;

      sessionStartAttempts.add(sessionID);
      try {
        const { stdout } = await execFileAsync(
          join(architectCritic.root, "hooks-handlers", "session-start.sh"),
          [],
          {
            cwd: directory,
            env: {
              ...process.env,
              PLUGIN_ROOT: architectCritic.root,
              CLAUDE_PLUGIN_ROOT: architectCritic.root,
            },
            timeout: sessionStartTimeoutMs,
            killSignal: "SIGKILL",
          },
        );
        if (typeof stdout === "string" && stdout.trim()) {
          firstText.text = stdout + firstText.text;
        }
      } catch {
        // Session status is advisory and must never block the conversation.
      }
    },
  };
}
