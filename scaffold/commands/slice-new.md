---
description: Start a new slice. Creates docs/slices/slice-NN-<name>.md from template, sets phase=spec.
argument-hint: "<name>"
allowed-tools: Bash(bash:*)
---

Numbering: per-branch (OQ-3). 2-digit zero-padded up to 99 (OQ-15). Refuses if a slice is in-progress unless \`--force\` (OQ-10). See SPEC \`§5.2\`.

> **Build status:** stub. Implementation lands in Phase D. The plugin
> registers this command on install but it is not yet functional.
