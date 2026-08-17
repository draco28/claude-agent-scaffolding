---
scenario_id: 03-with-suppressed-candidate
expected_behavior: skill shows active principles normally, then surfaces the suppressed auto-promotion candidate in a footer with status "suppressed" and the expiry date (2026-06-14)
fixture_kind: mixed
---

State has a suppressed auto-promotion candidate: the user declined an auto-promote suggestion for "Don't add fallbacks for scenarios that can't happen" with a 30-day suppression window set on 2026-05-15. The skill must list active principles as usual, then show the suppressed candidate in a separate footer section so the user is aware of the pending suppression and its expiry date.

User-global principles file (the shipped template at `templates/principles.md` is Source 1 and carries its own two defaults — the Ghost Notes principle and the CORE protocol — which render under `## Shipped defaults`; this file's own entries are user-promoted):

```markdown
# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Your principles (user-promoted)

Every state-change operation needs a documented rollback path
Push validation to system boundaries; trust internal code
Prefer explicit over implicit configuration
Name every state field after what it holds, not what writes it
```

State (relevant portion for suppression):

```json
{
  "schema_version": 2,
  "recent_runs": [],
  "principle_promotions": [],
  "candidate_promotions": [],
  "declined_candidates": [],
  "auto_promote_suppressions": [
    {
      "fingerprint": "sha256-of-dont-add-fallbacks-for-scenarios-that-cant-happen",
      "text": "Don't add fallbacks for scenarios that can't happen",
      "suppressed_at": "2026-05-15T10:22:00Z",
      "expires_at": "2026-06-14T10:22:00Z",
      "reason_score": 4
    }
  ]
}
```
