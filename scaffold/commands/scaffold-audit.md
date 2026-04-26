---
description: Run a gap analysis on the current repo (README quality, ADRs, runbooks, test framework, LLM artifacts). Outputs a markdown table.
argument-hint: "[--save]"
allowed-tools: Bash(bash:*)
---

Walk filesystem against the audit checklist. With \`--save\`, write \`docs/AUDIT.md\`. See SPEC \`§5.1\` audit table.

> **Build status:** stub. Implementation lands in Phase C. The plugin
> registers this command on install but it is not yet functional.
