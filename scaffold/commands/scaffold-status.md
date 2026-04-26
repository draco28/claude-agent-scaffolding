---
description: Show the current scaffold state — current slice, phase, stack, LLM flag, branch, worktree count, last audit.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

Read \`${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/branches/<branch>/state.json\` and pretty-print.

> **Build status:** stub. Implementation lands in Phase C. The plugin
> registers this command on install but it is not yet functional.
