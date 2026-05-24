---
scenario_id: 05-validation-empty-text
expected_behavior: skill rejects the invocation with a clear validation error message explaining that principle text is required; nothing is written to principles.md or state.json
fixture_kind: invocation-args
---

Invocation: `/promote-principle ""`

The user passed an empty string as the principle text. The skill must:
1. Detect the empty text during argument parsing (before any file I/O).
2. Emit a clear error message (e.g., "principle text required" or "principle cannot be empty").
3. Exit with a non-zero status.
4. Write nothing to principles.md or state.json.

This is a guard-rail scenario — the skill must not silently append a blank line or an annotation-only line to the principles file.

Current user-global principles file (must remain unmodified after this invocation):

```markdown
# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Your principles

Avoid feature flags that outlive the experiment they gate [promoted 2026-05-10 source:manual]
```
