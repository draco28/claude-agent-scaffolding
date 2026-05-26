---
description: Show the merged principles set (shipped + user + project + memory-bank)
argument-hint: [--source all|shipped|user|project]
---

# /principles-list

Invoke the **listing-principles** skill. The skill body merges shipped defaults
(ghost-notes + CORE) → user-global → project-scoped → memory-bank patterns, renders grouped
by source with annotations. This slash command is a thin wrapper.

## Arguments

- `--source all|shipped|user|project` — filter to a single source (default `all`).

## Bridge

```bash
export ARCHITECT_CRITIC_ARGS="$ARGUMENTS"
```

## Invoke

Now invoke the skill via:

```
Skill(architect-critic:listing-principles)
```

The qualified `<plugin>:<skill>` form is required — pass the arguments above via `$ARCHITECT_CRITIC_ARGS`.
