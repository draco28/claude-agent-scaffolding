import { realpath } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";

import { getCommandOwner, getSkillOwner } from "./catalog.js";
import { translatePrompt, translateToolOutput } from "./translate.js";

const ARGUMENT_EXPORT =
  /(?:^|\n)[ \t]*export[ \t]+ARCHITECT_CRITIC_ARGS=(?:"((?:\\.|[^"\\])*)"|'([^']*)')[ \t]*(?:\n|$)/;

function commandOwner(command) {
  return getCommandOwner(command) ?? getSkillOwner(command);
}

function containsPath(root, filePath) {
  const nested = relative(root, filePath);
  return nested === "" || (!nested.startsWith("..") && !isAbsolute(nested));
}

async function resolvedPath(filePath) {
  try {
    return await realpath(filePath);
  } catch {
    return resolve(filePath);
  }
}

function exportedArguments(command) {
  if (typeof command !== "string") return;
  const match = ARGUMENT_EXPORT.exec(command);
  if (!match) return;
  if (match[2] !== undefined) return match[2];
  return match[1].replace(/\\(["\\$`])/g, "$1").replace(/\\\n/g, "");
}

export function createRuntime({
  selected,
  canonicalCommands,
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
      if (!canonicalCommands.has(input.command)) return;
      const owner = commandOwner(input.command);
      if (!owner || !selectedNames.has(owner.name)) return;

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
        if (owner && selectedNames.has(owner.name)) {
          translateToolOutput(input.tool, input.args, output);
        }
        return;
      }
      if (input.tool !== "read" || typeof input.args?.filePath !== "string") {
        return;
      }

      const requestedPath = resolve(directory, input.args.filePath);
      const filePath = await resolvedPath(requestedPath);
      for (const owner of selected) {
        const root = await resolvedPath(owner.root);
        if (containsPath(root, filePath)) {
          translateToolOutput(
            "read",
            { ...input.args, filePath: requestedPath },
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
