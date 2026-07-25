---
description: Drive spec-core onboarding for a new ossify project (journey map, skeleton-cut, bones, risk gates, posture, spec-core critic)
argument-hint: "[project-name]"
allowed-tools: Bash(bash:*), Read, Write, Edit, SlashCommand
---

Parse args from `$ARGUMENTS` via the env-var bridge (no positional `$1`/`$2`/`$N`),
then invoke the `ossify:start` skill, which owns spec-core onboarding.

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  ARGS="${ARGS_FROM_CLAUDE:-}"
  echo "start: ARGS=${ARGS:-<none>}"
'
```

Now invoke the skill in-conversation:

**`Skill(ossify:start)`** — pass the parsed project name. The skill body owns the
journey map → skeleton-cut → bones → risk gates → smoke-test → posture block →
spec-core critic moment flow and shells out to `oss` for all state.
