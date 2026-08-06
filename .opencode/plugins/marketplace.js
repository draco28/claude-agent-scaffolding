import { readFile } from "node:fs/promises";
import { join } from "node:path";

import { resolveEnabledPlugins } from "../lib/catalog.js";
import { parseMarkdown } from "../lib/markdown.js";

export async function ScaffoldingPlugin(input, options = {}) {
  void input;
  const selected = resolveEnabledPlugins(options);
  const skillPaths = selected.map(({ root }) => join(root, "skills"));
  const aliases = [];

  for (const plugin of selected) {
    for (const command of plugin.commands) {
      const markdown = await readFile(
        join(plugin.root, "commands", `${command.name}.md`),
        "utf8",
      );
      const { frontmatter, body } = parseMarkdown(markdown);
      aliases.push([
        command.name,
        { description: frontmatter.description, template: body },
      ]);
    }
  }

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
      for (const [name, command] of aliases) {
        config.command[name] ??= command;
      }
    },
  };
}
