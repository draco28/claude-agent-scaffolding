import { realpath } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";

import { getSkillOwner } from "./catalog.js";
import { translatePrompt, translateToolOutput } from "./translate.js";

const ARGUMENT_EXPORT =
  /^[ \t]*export[ \t]+ARCHITECT_CRITIC_ARGS=(?:"((?:\\[^\r\n]|[^"\\\r\n])*)"|'([^'\r\n]*)')[ \t]*(?:\r?\n)?$/;
const SKILL_BASE_DIRECTORY =
  /(?:^|\r?\n)Base directory for this skill: ([^\r\n]+)(?=\r?\n|$)/g;
const FORBIDDEN_GIT_VERBS = new Set(["commit", "push", "pull", "fetch"]);
const NESTED_SHELLS = new Set(["sh", "bash", "zsh"]);
const MAX_SHELL_SCAN_DEPTH = 4;
const GIT_OPTIONS_WITH_VALUE = new Set([
  "-C",
  "--git-dir",
  "--work-tree",
  "--namespace",
  "--super-prefix",
  "--config-env",
  "--attr-source",
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
]);

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
  if (token.mixedQuotes) return false;
  return token.value === "git" || token.value.endsWith("/git");
}

function executableName(token) {
  if (token.mixedQuotes) return;
  return token.value.slice(token.value.lastIndexOf("/") + 1);
}

function shellTokens(command) {
  const tokens = [];
  let value = "";
  let quote;
  let sawQuoted = false;
  let sawUnquoted = false;
  let malformed = false;

  function flushWord() {
    if (!value && !sawQuoted) return;
    tokens.push({
      type: "word",
      value,
      mixedQuotes: sawQuoted && sawUnquoted,
    });
    value = "";
    sawQuoted = false;
    sawUnquoted = false;
  }

  for (let index = 0; index < command.length; index += 1) {
    const character = command[index];
    if (quote) {
      if (character === quote) {
        quote = undefined;
      } else if (character === "\\" && quote === '"') {
        const escaped = command[index + 1];
        if (escaped !== undefined) {
          if (escaped !== "\n") value += escaped;
          index += 1;
        } else {
          value += character;
          malformed = true;
        }
      } else {
        value += character;
      }
      continue;
    }

    if (character === '"' || character === "'") {
      quote = character;
      sawQuoted = true;
      continue;
    }
    if (character === "\\") {
      sawUnquoted = true;
      const escaped = command[index + 1];
      if (escaped !== undefined) {
        if (escaped !== "\n") value += escaped;
        index += 1;
      } else {
        value += character;
        malformed = true;
      }
      continue;
    }
    if (/\s/.test(character)) {
      flushWord();
      if (character === "\n") tokens.push({ type: "separator" });
      continue;
    }
    if (SHELL_SEPARATORS.has(character)) {
      flushWord();
      tokens.push({ type: "separator" });
      if (command[index + 1] === character) index += 1;
      continue;
    }

    sawUnquoted = true;
    value += character;
  }
  flushWord();
  return { tokens, malformed: malformed || quote !== undefined };
}

function aliasDefinition(value, aliases) {
  const separator = value.indexOf("=");
  if (separator === -1) return;
  const key = value.slice(0, separator);
  if (!key.startsWith("alias.") || key.length === "alias.".length) return;
  aliases.set(key.slice("alias.".length), value.slice(separator + 1));
}

function directAliasVerb(value) {
  const { tokens, malformed } = shellTokens(value);
  if (malformed) {
    throw new Error(
      "ossify-implementer-agent requires a valid nested shell command",
    );
  }
  const first = tokens.find(({ type }) => type === "word");
  return first && FORBIDDEN_GIT_VERBS.has(first.value)
    ? first.value
    : undefined;
}

function nestedCommandVerb(tokens, index, depth) {
  const executable = executableName(tokens[index]);
  if (NESTED_SHELLS.has(executable)) {
    for (let next = index + 1; next < tokens.length; next += 1) {
      const token = tokens[next];
      if (token.type === "separator") break;
      if (/^-[^-]*c[^-]*$/.test(token.value)) {
        const command = tokens[next + 1];
        if (command?.type !== "word") {
          throw new Error(
            "ossify-implementer-agent requires a valid nested shell command",
          );
        }
        return forbiddenGitVerb(command.value, depth + 1);
      }
    }
    return;
  }

  if (executable !== "eval") return;
  const words = [];
  for (let next = index + 1; next < tokens.length; next += 1) {
    const token = tokens[next];
    if (token.type === "separator") break;
    if (token.value === "--" && words.length === 0) continue;
    words.push(token.value);
  }
  if (words.length > 0) return forbiddenGitVerb(words.join(" "), depth + 1);
}

function gitInvocationVerb(tokens, index, depth) {
  const aliases = new Map();
  for (let next = index + 1; next < tokens.length; next += 1) {
    const token = tokens[next];
    if (token.type === "separator") break;
    const word = token.value;

    if (word === "--exec-path") break;
    if (word === "-c") {
      const value = tokens[next + 1];
      if (value?.type !== "word") break;
      aliasDefinition(value.value, aliases);
      next += 1;
      continue;
    }

    const option = word.split("=", 1)[0];
    if (GIT_OPTIONS_WITH_VALUE.has(option)) {
      if (!word.includes("=")) {
        if (tokens[next + 1]?.type !== "word") break;
        next += 1;
      }
      continue;
    }
    if (word.startsWith("-")) continue;
    if (FORBIDDEN_GIT_VERBS.has(word)) return word;

    const alias = aliases.get(word);
    if (!alias) return;
    if (alias.startsWith("!")) {
      return forbiddenGitVerb(alias.slice(1), depth + 1);
    }
    return directAliasVerb(alias);
  }
}

function forbiddenGitVerb(command, depth = 0) {
  if (depth > MAX_SHELL_SCAN_DEPTH) {
    throw new Error("ossify-implementer-agent shell nesting depth exceeded");
  }
  const { tokens, malformed } = shellTokens(command);
  if (malformed) {
    throw new Error(
      "ossify-implementer-agent requires a valid nested shell command",
    );
  }

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (token.type !== "word") continue;
    if (isGitExecutable(token)) {
      const verb = gitInvocationVerb(tokens, index, depth);
      if (verb) return verb;
    }
    const nestedVerb = nestedCommandVerb(tokens, index, depth);
    if (nestedVerb) return nestedVerb;
  }
}

export function createRuntime({
  selected,
  registeredCommands,
  registeredAgents,
  directory = process.cwd(),
}) {
  const selectedNames = new Set(selected.map(({ name }) => name));
  const architectCriticSelected = selectedNames.has("architect-critic");
  const sessions = new Map();
  const sessionAgents = new Map();

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
          part.text = translatePrompt(part.text, owner);
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
  };
}
