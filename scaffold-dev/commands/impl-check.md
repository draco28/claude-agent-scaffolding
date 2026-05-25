---
description: Run implementation-check verification on the current work item or slice. Usage: /impl-check [<scope>]
argument-hint: "[<scope>]"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep
---

# /impl-check

Wraps the `implementation-checking` skill — runs AC verification + rules
checks for the active work item / slice. Bridge `$ARGUMENTS` into an env var
the skill body reads (per `feedback_slash_command_dollar_n_bug` — never
`$1`/`$2`/`$N`).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  SCAFFOLD_DEV_ARGS="${ARGS_FROM_CLAUDE:-}"
  export SCAFFOLD_DEV_ARGS
  echo "impl-check: SCAFFOLD_DEV_ARGS=${SCAFFOLD_DEV_ARGS:-<none>}"
'
```

Now invoke the skill in-conversation.

**`Skill(scaffold-dev:implementation-checking)`** — pass any scope hint
parsed from `$SCAFFOLD_DEV_ARGS` (default: active cursor). The skill body
owns AC enumeration, verification step execution, machine-checkable-rules
sweep, and pass/fail report per scaffold-dev SPEC §7.
