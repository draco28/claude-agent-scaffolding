---
scenario_id: 02-shipped-plus-user-promoted
expected_behavior: skill groups principles by source — shipped-default section first, then user-promoted section; each user-promoted principle shows the "user-promoted" source tag and promotion timestamp
fixture_kind: principles-md
---

The user-global principles file contains shipped defaults PLUS 2 user-promoted principles appended via `/promote-principle`. The skill must render two distinct sections: shipped defaults first, then user-promoted, preserving the source annotations and timestamps.

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

## Your principles

Avoid feature flags that outlive the experiment they gate [promoted 2026-05-10 source:manual]
Tests must hit real boundaries (DB, network) — mocks only at the seam [promoted 2026-05-19 source:manual]
```
