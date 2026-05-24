---
scenario_id: 01-only-shipped-defaults
expected_behavior: skill lists only the shipped-default principles (ghost-notes heuristic + CORE defaults) with a "shipped-default" source annotation; no user or project section appears
fixture_kind: principles-md
---

The user-global principles file contains only the shipped template defaults — the preamble, the ghost-notes heuristic, and the CORE shipped defaults. No principles have been promoted by the user and no project-scoped file exists. The skill must render all shipped defaults with a `shipped-default` annotation and omit any user or project section headers.

```markdown
# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Shipped defaults

Look for what is absent, not just what is present — ghost-notes heuristic
Every state-change operation needs a documented rollback path
Push validation to system boundaries; trust internal code
Prefer explicit over implicit configuration
```
