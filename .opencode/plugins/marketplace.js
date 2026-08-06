import { readFile } from "node:fs/promises";
import { join } from "node:path";

import { resolveEnabledPlugins } from "../lib/catalog.js";
import { parseMarkdown } from "../lib/markdown.js";
import { createRuntime } from "../lib/runtime.js";

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
      ]);
    }
  }
  const canonicalCommands = new Set(
    selected.flatMap(({ skills, commands }) => [
      ...skills,
      ...commands.map(({ name }) => name),
    ]),
  );
  const runtime = createRuntime({
    selected,
    canonicalCommands,
    directory: input.directory,
  });

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
      for (const plugin of selected) {
        for (const skill of plugin.skills) {
          if (Object.hasOwn(config.command, skill)) {
            canonicalCommands.delete(skill);
          }
        }
      }
      for (const [name, command] of aliases) {
        if (
          Object.hasOwn(config.command, name) &&
          config.command[name] !== command
        ) {
          canonicalCommands.delete(name);
        }
        config.command[name] ??= command;
      }
    },
    ...runtime,
  };
}
