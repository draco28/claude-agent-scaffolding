---
description: Plan an ossify feature spine (1-5 work items, DAG rounds, per-round specs, grill-me for bone spines, cumulative-demo criteria under the journey-line floor, fake ledger)
argument-hint: "<spine-id>"
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Parse args from `$ARGUMENTS` via the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `ossify:plan-spine` skill, which owns spine planning.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  echo "plan-spine: ARGS=${ARGS:-<none>}"
'
```

Now invoke the skill in-conversation:

**`Skill(ossify:plan-spine)`** — pass the parsed spine id (`r1.s2`). The skill body
owns the pre-flight probes (manifest + project + a planned release) → decomposition
into 1-5 work items with a `target_repo` → round identification via the work-item
DAG → per-round spec authoring with the citation fold-in → the grill-me gate for
bone spines only → demo authoring under the journey-line floor → fake-ledger
discipline, and shells out to `oss` for all state.
