---
description: Execute a single work item (manual fallback for subagent dispatch). Usage: /work-item <handoff-path-or-id>
argument-hint: "<handoff-path-or-id>"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep
---

# /work-item

Manual fallback per SPEC §6.4 — invoke the `executing-work-item` skill
in-conversation (not via subagent) for a single handoff doc. Bridge
`$ARGUMENTS` into an env var the skill body reads (per
`feedback_slash_command_dollar_n_bug` — never `$1`/`$2`/`$N`).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  SCAFFOLD_DEV_ARGS="${ARGS_FROM_CLAUDE:-}"
  export SCAFFOLD_DEV_ARGS
  echo "work-item: SCAFFOLD_DEV_ARGS=${SCAFFOLD_DEV_ARGS:-<none>}"
'
```

Now invoke the skill in-conversation.

**`Skill(scaffold-dev:executing-work-item)`** — read the handoff path or
work-item id from `$SCAFFOLD_DEV_ARGS`. The skill body owns the pre-flight
gap check, TDD loop per AC, verification, report authoring, and stage step
(no commit) per scaffold-dev SPEC §6.4.
