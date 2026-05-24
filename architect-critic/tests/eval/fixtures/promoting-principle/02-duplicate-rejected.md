---
scenario_id: 02-duplicate-rejected
expected_behavior: skill rejects the promotion and explains that an effectively identical principle already exists (the ghost-notes shipped default); nothing is written to principles.md or state.json
fixture_kind: invocation-args
---

Invocation: `/promote-principle "Look for what is absent"`

The user-global principles file already has the shipped default: "Look for what is absent, not just what is present — ghost-notes heuristic". The new text "Look for what is absent" is a clear prefix-match / normalized-similarity match of the existing active principle. The skill must:
1. Detect the overlap and reject the promotion.
2. Emit an error message citing which existing principle triggered the duplicate check.
3. Write nothing to principles.md or state.json.

Current user-global principles file:

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
