---
description: Regenerate <repo>/CLAUDE.md from the current personal-defaults + project-layer sources.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

Read both source layers, concatenate, write to \`<repo>/CLAUDE.md\` with footer timestamp. Warn if manual edits detected since last generation.

> **Build status:** stub. Implementation lands in Phase C. The plugin
> registers this command on install but it is not yet functional.
