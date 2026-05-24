---
scenario_id: 02-single-run
expected_behavior: skill renders a table with exactly 1 data row showing the single completed run; columns include completed_at, depth, adversaries_used, challenge_count, and concessions
fixture_kind: state-json
---

State has exactly one completed run: a shallow claude-only audit that raised 5 challenges and logged 2 concessions. The table must have exactly one data row.

```json
{
  "schema_version": 1,
  "in_flight": [],
  "recent_runs": [
    {
      "request_id": "crit-2026-05-22T14-00Z-shallow-a1b2",
      "completed_at": "2026-05-22T14:07:43Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 5,
      "divergence_count": 0,
      "concessions": 2,
      "elapsed_ms": 18400,
      "cost_usd": 0.03,
      "codex_timeout": false
    }
  ],
  "principle_promotions": [],
  "candidate_promotions": [],
  "declined_candidates": []
}
```
