---
description: Force a full reconcile of this project's ossify state onto its Huly board, or bind the repo to a Huly project on first run
argument-hint: "[--bind IDENT]"
allowed-tools: Bash(bash:*), Read
---

Parse args from `$ARGUMENTS` via the env-var bridge (no positional `$1`/`$2`/`$N`):

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c 'set -u; echo "sync: ARGS=${ARGS_FROM_CLAUDE:-<none>}"'
```

Now **read `${CLAUDE_PLUGIN_ROOT}/skills/sync/SKILL.md` end to end and follow it**, passing
`--bind IDENT` through when it was given.
