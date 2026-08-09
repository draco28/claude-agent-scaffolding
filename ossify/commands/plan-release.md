---
description: Plan an ossify release (feature-map grooming, exit criteria, spine DAG, class declaration under the fail-closed critic veto, RELEASE.md)
argument-hint: "[release-name]"
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Parse args from `$ARGUMENTS` via the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `ossify:plan-release` skill, which owns release planning.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  echo "plan-release: ARGS=${ARGS:-<none>}"
'
```

Now invoke the skill in-conversation:

**`Skill(ossify:plan-release)`** — pass the parsed release name. The skill body
owns the inputs (incl. the mandatory real-use findings) → spine selection + exit
criteria + ledger budget → spine DAG → class declaration under the bone-touch
judge and the fail-closed critic veto → RELEASE.md → next-release sketch flow, and
shells out to `oss` for all state.
