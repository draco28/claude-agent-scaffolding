---
description: Derive .claude/memory-bank/ (11 files) and CLAUDE.md from MASTER-SPEC.md. Deterministic and idempotent.
argument-hint: "[--force]"
allowed-tools: Bash(bash:*)
---

[Stub — implementation in Phase D, Task TD.10]

This command will:
1. Validate MASTER-SPEC.md exists and parses
2. Re-derive 9 derived memory-bank files (00-04, 07, 08, index)
3. Preserve 2 live files (05, 06) and WORKFLOW.md unless --force
4. Render CLAUDE.md with Tier 0 preload + branch routing
5. Write .claude/settings.json if it doesn't exist
