---
description: Derive governance docs (PRD, SRS, BACKLOG, PROJECT_PLAN, ADR-0001) from MASTER-SPEC.md. --full adds 9 more.
argument-hint: "[--full] [--regenerate]"
allowed-tools: Bash(bash:*)
---

[Stub — implementation in Phase E, Task TE.7]

This command will:
1. Validate MASTER-SPEC.md exists and parses
2. Render 5 default governance docs (PRD, SRS-lite, BACKLOG, PROJECT_PLAN, adr/0001)
3. With --full, also render 9 more (3 are LLM-project-gated)
4. Preserve existing files unless --regenerate
