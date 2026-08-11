---
description: Drive a planned ossify spine's rounds end to end (spine-branch cut, one worktree per work item, implementer dispatch in decomposition order, the round barrier)
argument-hint: "<spine-id>"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep, Task
---

Parse args from `$ARGUMENTS` via the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `ossify:work-item` skill in its orchestrator mode, which owns the
execution lane.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  echo "run-spine: ARGS=${ARGS:-<none>}"
'
```

Now invoke the skill in-conversation:

**`Skill(ossify:work-item)`** — pass the parsed spine id and say plainly that you
are driving the spine's rounds, not one work item. The skill routes to
`references/round-orchestration.md`, which owns the whole lane: the spine-branch
cut-and-checkout, one worktree per work item, `oss work_item_exec`, dispatching
`ossify:implementer-agent` per item, the 3-iteration cap, and the round barrier.
Returns are processed in declared decomposition order regardless of arrival order.

This is the entry point `plan-spine` hands the baton to. `plan-spine` plans and
stops; `/close <spine-id>` takes over once the final round clears its barrier.

**Not this command:** one work item from a known handoff path is `/work-item
<handoff-path>`. The work-item gate, the cumulative demo, the harvest and the
retro are `/close`.
