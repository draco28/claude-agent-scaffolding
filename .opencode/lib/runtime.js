import { realpath } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";

import { getSkillOwner } from "./catalog.js";
import { translatePrompt, translateToolOutput } from "./translate.js";

const ARGUMENT_EXPORT =
  /^[ \t]*export[ \t]+ARCHITECT_CRITIC_ARGS=(?:"((?:\\[^\r\n]|[^"\\\r\n])*)"|'([^'\r\n]*)')[ \t]*(?:\r?\n)?$/;
const SKILL_BASE_DIRECTORY =
  /(?:^|\r?\n)Base directory for this skill: ([^\r\n]+)(?=\r?\n|$)/g;

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

export function createRuntime({
  selected,
  registeredCommands,
  directory = process.cwd(),
}) {
  const selectedNames = new Set(selected.map(({ name }) => name));
  const architectCriticSelected = selectedNames.has("architect-critic");
  const sessions = new Map();

  return {
    "chat.message": async ({ sessionID }) => {
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
      if (!architectCriticSelected || input.tool !== "bash") return;
      const args = exportedArguments(output.args?.command);
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
