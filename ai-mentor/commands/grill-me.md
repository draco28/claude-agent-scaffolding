---
description: Interrogate the user's plan or design one question at a time. Stress-test assumptions and surface unmade decisions.
argument-hint: "[plan or design to grill] [--neutral]"
allowed-tools: []
---

The user invoked `/grill-me`. Grill the user on the topic below using the `ai-mentor:grill-me` skill — one question at a time, walk the tree until shared understanding. Each question carries a recommendation by default; `--neutral` (or "no recommendations") in the topic text suppresses them.

Topic to grill (may be empty — fall back to current conversation context): $ARGUMENTS
