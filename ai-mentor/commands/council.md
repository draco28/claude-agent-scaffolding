---
description: Convene the 5-persona advisory council (Karpathy LLM Council pattern) for multi-angle validation of an idea or decision.
argument-hint: "[idea or decision to validate] [--neutral]"
allowed-tools: []
---

The user invoked `/council`. Convene the 5 advisors using the `ai-mentor:council` skill — Contrarian, First Principles Thinker, Outsider, Executor, Historian. Single response, all 5 personas in markdown-headed sections, then a recommended Chairman synthesis by default (or the "Chairman, your synthesis?" prompt under `--neutral` / "no recommendations").

Idea/decision to validate (may be empty — ask for clarification if so): $ARGUMENTS
