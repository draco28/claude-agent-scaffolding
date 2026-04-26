---
description: Run all tests for the current slice; report which acceptance criteria pass; mark slice complete if all pass.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

Gate: implement phase reached. Runs the detected test command, parses results, updates AC status in state.json.

> **Build status:** stub. Implementation lands in Phase D. The plugin
> registers this command on install but it is not yet functional.
