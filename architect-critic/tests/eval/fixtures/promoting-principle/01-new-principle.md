---
scenario_id: 01-new-principle
expected_behavior: principle is appended to the user-global principles.md with a [promoted YYYY-MM-DD source:manual] annotation; skill emits a success message confirming the principle text and target file
fixture_kind: invocation-args
---

Invocation: `/promote-principle "Prefer explicit over implicit configuration"`

The user-global principles file currently has only the shipped defaults. No duplicate of "Prefer explicit over implicit configuration" exists in the active (non-commented) section. The skill must:
1. Append the principle to the user-global file with a promotion timestamp and `source:manual` tag.
2. Record the promotion in `state.json` under `principle_promotions[]`.
3. Emit a confirmation message that includes the principle text and the file path written.

Initial user-global principles file:

```markdown
# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Your principles

(empty — add yours here, one per line)

## Examples (commented out — uncomment to activate)

# Prefer explicit over implicit configuration
# Push validation to system boundaries; trust internal code
# Every state-change operation needs a documented rollback path
```

Note: the commented-out examples must NOT trigger duplicate detection — only active (non-commented) lines count.
