---
description: Bootstrap a fresh dual-repo workspace (AI workspace + canonical). Wraps the initializing-dual-repo-workspace skill.
allowed-tools: ["Read", "Write", "Bash"]
---

Invoke the `initializing-dual-repo-workspace` skill from the workspace-init plugin.

Arguments: $ARGUMENTS

If `$ARGUMENTS` is non-empty, treat it as the project name and start the bootstrap procedure from SPEC §8.1 with that name. Otherwise, prompt for the project name interactively.

Follow the skill body exactly. Do not skip any of the 8 pre-onboard tasks. Do not auto-commit (stage only). Print the next-steps message verbatim. If any task fails, invoke the rollback via `wi rollback "${ai_root}/.workspace/init-log"` (the `wi` dispatcher is on PATH; it sources lib modules under bash regardless of caller shell).
