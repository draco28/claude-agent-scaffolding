---
scenario_id: 05-with-codex-timeout-flag
expected_behavior: table flags the run where codex_timeout is true with a visible marker (asterisk, "(timeout)" suffix, footnote, or separate note) so the user can distinguish it from a clean close-depth run
fixture_kind: state-json
---

State has 3 runs; the second (close-depth) run has `codex_timeout: true` — codex was invoked but did not complete within the allotted window. The skill must make this visible in the rendered output so the user knows the close-depth adversary result was incomplete.

```json
{
  "schema_version": 1,
  "in_flight": [],
  "recent_runs": [
    {
      "request_id": "crit-2026-05-10T09-00Z-shallow-e1f2",
      "completed_at": "2026-05-10T09:11:44Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 4,
      "divergence_count": 0,
      "concessions": 2,
      "elapsed_ms": 17100,
      "cost_usd": 0.02,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-18T14-00Z-close-e2g3",
      "completed_at": "2026-05-18T14:32:58Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 5,
      "divergence_count": 0,
      "concessions": 2,
      "elapsed_ms": 120000,
      "cost_usd": 0.08,
      "codex_timeout": true
    },
    {
      "request_id": "crit-2026-05-23T10-00Z-close-e3h4",
      "completed_at": "2026-05-23T10:19:07Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 7,
      "divergence_count": 2,
      "concessions": 3,
      "elapsed_ms": 44800,
      "cost_usd": 0.12,
      "codex_timeout": false
    }
  ],
  "principle_promotions": [],
  "candidate_promotions": [],
  "declined_candidates": []
}
```
