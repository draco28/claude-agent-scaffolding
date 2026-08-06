import { readFile } from "node:fs/promises";
import { delimiter, join } from "node:path";
import { fileURLToPath } from "node:url";

import { resolveEnabledPlugins } from "../lib/catalog.js";
import { parseMarkdown } from "../lib/markdown.js";
import { createRuntime } from "../lib/runtime.js";

const wrapperDirectory = fileURLToPath(new URL("../bin", import.meta.url));

export async function ScaffoldingPlugin(input, options = {}) {
  const selected = resolveEnabledPlugins(options);
  const skillPaths = selected.map(({ root }) => join(root, "skills"));
  const aliases = [];

  for (const plugin of selected) {
    for (const command of plugin.commands) {
      const commandPath = join(plugin.root, "commands", `${command.name}.md`);
      const markdown = await readFile(commandPath, "utf8");
      const { frontmatter } = parseMarkdown(markdown, commandPath);
      const argumentsLine =
        command.name === "critique-doctor"
          ? ""
          : "\n\nArguments: $ARGUMENTS";
      aliases.push([
        command.name,
        {
          description: frontmatter.description,
          template:
            `Use OpenCode's \`skill\` tool to invoke the unqualified ` +
            `\`${command.skill}\` skill and follow it exactly.${argumentsLine}`,
        },
        plugin,
      ]);
    }
  }
  const registeredCommands = new Map();
  const runtime = createRuntime({
    selected,
    registeredCommands,
    directory: input.directory,
  });
  const runtimeShellEnv = runtime["shell.env"];

  return {
    config: async (config) => {
      config.skills ??= {};
      config.skills.paths ??= [];
      for (const skillPath of skillPaths) {
        if (!config.skills.paths.includes(skillPath)) {
          config.skills.paths.push(skillPath);
        }
      }

      config.command ??= {};
      for (const [name, command, owner] of aliases) {
        config.command[name] ??= command;
        if (config.command[name] === command) {
          registeredCommands.set(name, owner);
        } else {
          registeredCommands.delete(name);
        }
      }
    },
    ...runtime,
    "shell.env": async (input, output) => {
      await runtimeShellEnv(input, output);
      const callerPath = output.env.PATH ?? process.env.PATH ?? "";
      const pathEntries = callerPath
        ? callerPath
            .split(delimiter)
            .filter((entry) => entry !== wrapperDirectory)
        : [];
      output.env.PATH = [wrapperDirectory, ...pathEntries].join(delimiter);
      output.env.OPENCODE_SCAFFOLDING_PLUGINS = selected
        .map(({ name }) => name)
        .join(":");
    },
  };
}
