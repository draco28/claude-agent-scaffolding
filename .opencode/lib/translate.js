import { homedir } from "node:os";
import { join } from "node:path";

import { PLUGIN_CATALOG, getSkillOwner } from "./catalog.js";

function contextFor(owner) {
  return {
    root: owner.root,
    dataRoot: join(homedir(), ".claude", owner.name),
  };
}

export function translatePrompt(text, context) {
  if (typeof text !== "string") {
    throw new TypeError("prompt text must be a string");
  }

  let translated = text.replace(
    /\bSkill\(\s*([a-z0-9-]+):([a-z0-9-]+)\s*\)/g,
    (invocation, pluginName, skillName) =>
      getSkillOwner(skillName)?.name === pluginName
        ? `skill(name="${skillName}")`
        : invocation,
  );
  translated = translated.replace(
    /\bTask\(\s*subagent_type="ossify:implementer-agent"/g,
    'task(subagent_type="ossify-implementer-agent"',
  );
  translated = translated.replaceAll("AskUserQuestion", "question");

  if (context?.root) {
    const root = context.root.replace(/\/+$/, "");
    translated = translated.replace(
      /\$(?:\{CLAUDE_PLUGIN_ROOT\}|CLAUDE_PLUGIN_ROOT\b)/g,
      () => root,
    );
  }
  const dataRoot =
    context?.dataRoot ??
    (context?.name ? join(homedir(), ".claude", context.name) : undefined);
  if (dataRoot) {
    translated = translated.replace(
      /\$(?:\{CLAUDE_PLUGIN_DATA\}|CLAUDE_PLUGIN_DATA\b)/g,
      () => dataRoot,
    );
  }

  return translated;
}

export function translateToolOutput(tool, args, output) {
  if (typeof output?.output !== "string") return;

  const owner =
    (tool === "skill" || tool === "read") &&
    PLUGIN_CATALOG.includes(args?.owner)
      ? args.owner
      : undefined;
  if (owner) {
    output.output = translatePrompt(output.output, contextFor(owner));
  }
}
