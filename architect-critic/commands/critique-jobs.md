---
description: Manage background async critique jobs — status / result / cancel / resume
argument-hint: <status|result|cancel|resume> [run-id]
---

# /critique-jobs

Invoke the **managing-async-critique** skill to manage background close-depth critique
jobs created by `/critique --close --async`. This slash command is a thin wrapper.

## Arguments

- `status [run-id]` — show a job's disposition (defaults to the latest running job).
- `result [run-id]` — show a finished job's raw Codex challenges (no rebuttal).
- `cancel [run-id]` — cancel a running job.
- `resume [run-id]` — consolidate both adversaries + run the unified rebuttal (defaults to the latest completed job). A concluded job resumes inspect-only.

## Bridge

```bash
export ARCHITECT_CRITIC_ARGS="$ARGUMENTS"
```

## Invoke

Now invoke the skill via:

```
Skill(architect-critic:managing-async-critique)
```

The qualified `<plugin>:<skill>` form is required — pass the arguments above via `$ARCHITECT_CRITIC_ARGS`.
