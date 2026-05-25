---
description: Plan and orchestrate a vertical slice. Usage: /orchestrate VS-N.M
argument-hint: "VS-N.M"
allowed-tools: Bash(bash:*), Read, Write, Edit, Glob, Grep, Task, SlashCommand
---

# /orchestrate

Bridge `$ARGUMENTS` into an env var for the skill body to read (per
`feedback_slash_command_dollar_n_bug` — never use `$1`/`$2`/`$N` positionals
in slash-command bodies; substitute via env-var at template render).

```bash
ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
  set -u
  SCAFFOLD_DEV_ARGS="${ARGS_FROM_CLAUDE:-}"
  export SCAFFOLD_DEV_ARGS
  echo "orchestrate: SCAFFOLD_DEV_ARGS=${SCAFFOLD_DEV_ARGS:-<none>}"
'
```

Now invoke the skill in-conversation.

**`Skill(scaffold-dev:planning-vertical-slice)`** — pass the VS-id parsed from
`$SCAFFOLD_DEV_ARGS` (e.g. `VS-1.2`). The skill body owns the slice-planning
loop, manifest discovery, ROADMAP lookup, sprint-spec authoring, work-item
decomposition, and subagent dispatch per scaffold-dev SPEC §6.
