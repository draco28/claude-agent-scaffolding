---
description: Show recent architect-critic runs
argument-hint: [--limit N]
---

# /critique-list

Invoke the **reviewing-critique-history** skill. The skill body reads state.json (schema v3)
and renders `recent_runs[]` plus any background `external_runs[]` as human-readable tables.
This slash command is a thin wrapper.

## Arguments

- `--limit N` — show most-recent N rows (default 10).

## Bridge

```bash
export ARCHITECT_CRITIC_ARGS="$ARGUMENTS"
```

## Invoke

Now invoke the skill via:

```
Skill(architect-critic:reviewing-critique-history)
```

The qualified `<plugin>:<skill>` form is required — pass the arguments above via `$ARCHITECT_CRITIC_ARGS`.
