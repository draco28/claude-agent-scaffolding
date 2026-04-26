---
description: Interactive runbook for a failure mode. Prompts for symptoms, diagnosis, remediation. Writes docs/runbooks/<slug>.md.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

Auto-creates docs/runbooks/ if missing. Template: SRE-style (templates/runbook.md.tmpl).

> **Build status:** stub. Implementation lands in Phase E. The plugin
> registers this command on install but it is not yet functional.
