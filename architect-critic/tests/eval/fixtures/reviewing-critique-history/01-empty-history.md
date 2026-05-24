---
scenario_id: 01-empty-history
expected_behavior: skill outputs an empty-state message ("No critique runs yet." or equivalent) — NOT a table with headers
fixture_kind: state-json
---

State has no critique runs. The skill should gracefully handle an empty `recent_runs` array and emit a human-readable empty-state message rather than rendering a table with no rows.

```json
{
  "schema_version": 1,
  "in_flight": [],
  "recent_runs": [],
  "principle_promotions": [],
  "candidate_promotions": [],
  "declined_candidates": []
}
```
