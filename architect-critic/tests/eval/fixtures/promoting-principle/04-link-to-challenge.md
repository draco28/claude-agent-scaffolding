---
scenario_id: 04-link-to-challenge
expected_behavior: when promoting a principle during an active critiquing-spec run, the skill auto-attaches linked_challenge with the current challenge fingerprint to the promotion record in state.json's principle_promotions[]
fixture_kind: mixed
---

Invocation: `/promote-principle "Every state mutation exposed via an API must be idempotent"`

This invocation happens DURING an active critiquing-spec run. The current session context provides the challenge fingerprint `sha256:a3f8c91d` (stub) for the challenge the user is responding to. The skill must:
1. Append the principle to user-global principles.md with the standard annotation.
2. Record the promotion in `state.json` under `principle_promotions[]` with an additional `"linked_challenge": "sha256:a3f8c91d"` field, linking this principle to the specific critic challenge that prompted it.
3. Emit the standard success message (the linked_challenge field is a state-side concern, not required in the confirmation output, but must be present in state.json).

Frontmatter context provided to the skill at invocation time:
- `current_challenge_fingerprint: sha256:a3f8c91d`
- `current_request_id: crit-2026-05-23T14-00Z-close-f1g2`

Current state (in-flight run present):

```json
{
  "schema_version": 1,
  "in_flight": [
    {
      "request_id": "crit-2026-05-23T14-00Z-close-f1g2",
      "started_at": "2026-05-23T14:00:12Z",
      "depth": "close",
      "phase_id": null
    }
  ],
  "recent_runs": [],
  "principle_promotions": [],
  "candidate_promotions": [],
  "declined_candidates": []
}
```

User-global principles file:

```markdown
# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Your principles

(empty — add yours here, one per line)
```
