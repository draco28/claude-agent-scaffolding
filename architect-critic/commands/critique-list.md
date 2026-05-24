---
description: Show recent architect-critic runs
argument-hint: [--limit N]
---

# /critique-list

Invoke the **reviewing-critique-history** skill. The skill body reads state.json (schema v2)
and renders `recent_runs[]` as a human-readable table. This slash command is a thin wrapper.

## Arguments

- `--limit N` — show most-recent N rows (default 10).

## Bridge

```bash
export ARCHITECT_CRITIC_ARGS="$ARGUMENTS"
```

## Invoke

Now invoke the `reviewing-critique-history` skill, passing the arguments above via `$ARCHITECT_CRITIC_ARGS`.
