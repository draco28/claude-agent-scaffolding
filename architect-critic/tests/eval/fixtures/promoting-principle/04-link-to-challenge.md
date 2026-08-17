---
scenario_id: 04-link-to-challenge
expected_behavior: when promoting a principle during an active critiquing-spec run, the skill records a normal promotion whose state entry carries NO linked_challenge (the challenge-link machinery is not shipped) and names the originating challenge as prose at most
fixture_kind: mixed
---

Invocation: `/promote-principle "Every state mutation exposed via an API must be idempotent"`

This invocation happens DURING an active critiquing-spec run. The current session context names the challenge fingerprint `sha256:a3f8c91d` (stub) for the challenge the user is responding to. The skill must:
1. Append the principle to user-global principles.md with the standard annotation.
2. Record the promotion in `state.json` under `principle_promotions[]` via `arc state_append_promotion manual "<text>" user` — the record is `{timestamp, source, text, scope}` and carries **no** `linked_challenge` field: nothing in the shipped plugin sets a challenge-fingerprint env var or reads such a field, so a state-side link cannot be produced and must not be claimed.
3. Emit the standard success message. Naming the originating challenge in the confirmation as prose is the only provenance the shipped machinery supports; the state record stays lean.

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
