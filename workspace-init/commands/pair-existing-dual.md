---
description: Pair an already-populated AI workspace with an already-populated canonical repository (Scenario C). Wraps the pairing-existing-dual skill.
allowed-tools: ["Read", "Write", "Bash"]
---

Invoke the `pairing-existing-dual` skill from the workspace-init plugin.

Arguments: $ARGUMENTS

`$ARGUMENTS` should carry two absolute paths: the existing (already-populated) AI workspace, then the existing canonical git repo — e.g. `/abs/path/my-workspace /abs/path/my-canonical`. If either is missing, prompt for it interactively.

Follow the skill body exactly. This is the both-repos-already-exist case: write the `.workspace/pairing.json` manifest into the existing AI workspace and install the trace-filter commit-msg hook (always in canonical; also in the AI workspace if it is a git repo). NEVER create, seed, stub, or overwrite any existing AI-workspace content — the only file authored inside it is `.workspace/pairing.json`. NEVER touch the canonical working tree beyond installing `.git/hooks/commit-msg`. NEVER `git init` the user's existing AI workspace.
