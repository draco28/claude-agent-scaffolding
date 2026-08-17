---
scenario_id: 04-source-filter-shipped-only
expected_behavior: when skill is invoked with --source shipped, output contains only shipped-default principles; user-promoted and project-scoped principles are omitted entirely
fixture_kind: mixed
---

Invocation: `/principles-list --source shipped`

The full principles set contains shipped defaults, 2 user-promoted principles, and 1 project-scoped principle from `.claude/architect-critic/principles.md`. With `--source shipped`, the skill must output only the shipped defaults and omit the user-promoted and project sections.

Shipped defaults in this scenario — the plugin's `templates/principles.md` contains:

```markdown
Look for what is absent, not just what is present — ghost-notes heuristic
Every state-change operation needs a documented rollback path
Push validation to system boundaries; trust internal code
Prefer explicit over implicit configuration
```

User-global principles file (`~/.claude/architect-critic/principles.md`):

```markdown
# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Your principles

Avoid feature flags that outlive the experiment they gate [promoted 2026-05-10 source:manual]
Tests must hit real boundaries (DB, network) — mocks only at the seam [promoted 2026-05-19 source:manual]
```

Project-scoped principles file (`.claude/architect-critic/principles.md`):

```markdown
All service methods must return typed Result<T, E> — never throw unchecked exceptions [promoted 2026-05-20 source:manual scope:project]
```
