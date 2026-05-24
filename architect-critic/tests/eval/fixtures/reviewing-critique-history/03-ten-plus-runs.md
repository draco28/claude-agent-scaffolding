---
scenario_id: 03-ten-plus-runs
expected_behavior: skill shows the 10 most-recent runs (default limit) and omits the 2 oldest entries; table rows are in reverse-chronological order (most recent first)
fixture_kind: state-json
---

State has 12 completed runs. With the default limit of 10, the skill must omit the 2 oldest (IDs ending `c001` and `c002`). The oldest omitted run completed on 2026-04-10; the most recent kept run completed on 2026-05-23.

```json
{
  "schema_version": 1,
  "in_flight": [],
  "recent_runs": [
    {
      "request_id": "crit-2026-04-10T09-00Z-shallow-c001",
      "completed_at": "2026-04-10T09:12:00Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 3,
      "divergence_count": 0,
      "concessions": 1,
      "elapsed_ms": 14200,
      "cost_usd": 0.02,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-04-18T11-00Z-shallow-c002",
      "completed_at": "2026-04-18T11-30-00Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 4,
      "divergence_count": 1,
      "concessions": 0,
      "elapsed_ms": 16000,
      "cost_usd": 0.02,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-04-25T08-00Z-close-c003",
      "completed_at": "2026-04-25T08-45-00Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 7,
      "divergence_count": 2,
      "concessions": 3,
      "elapsed_ms": 42100,
      "cost_usd": 0.11,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-04-30T15-00Z-shallow-c004",
      "completed_at": "2026-04-30T15-22-00Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 5,
      "divergence_count": 0,
      "concessions": 2,
      "elapsed_ms": 19800,
      "cost_usd": 0.03,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-03T10-00Z-close-c005",
      "completed_at": "2026-05-03T10-55-00Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 8,
      "divergence_count": 1,
      "concessions": 4,
      "elapsed_ms": 38700,
      "cost_usd": 0.09,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-07T09-00Z-shallow-c006",
      "completed_at": "2026-05-07T09-18-00Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 4,
      "divergence_count": 0,
      "concessions": 1,
      "elapsed_ms": 15600,
      "cost_usd": 0.02,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-11T14-00Z-close-c007",
      "completed_at": "2026-05-11T14-33-00Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 6,
      "divergence_count": 3,
      "concessions": 2,
      "elapsed_ms": 44500,
      "cost_usd": 0.12,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-15T11-00Z-shallow-c008",
      "completed_at": "2026-05-15T11-09-00Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 3,
      "divergence_count": 0,
      "concessions": 0,
      "elapsed_ms": 11200,
      "cost_usd": 0.02,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-19T16-00Z-close-c009",
      "completed_at": "2026-05-19T16-47-00Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 9,
      "divergence_count": 2,
      "concessions": 5,
      "elapsed_ms": 51300,
      "cost_usd": 0.14,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-20T08-00Z-shallow-c010",
      "completed_at": "2026-05-20T08-22-00Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 4,
      "divergence_count": 1,
      "concessions": 1,
      "elapsed_ms": 17900,
      "cost_usd": 0.03,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-22T13-00Z-close-c011",
      "completed_at": "2026-05-22T13-51-00Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 7,
      "divergence_count": 0,
      "concessions": 3,
      "elapsed_ms": 39400,
      "cost_usd": 0.10,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-23T09-00Z-shallow-c012",
      "completed_at": "2026-05-23T09-04-00Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 5,
      "divergence_count": 0,
      "concessions": 2,
      "elapsed_ms": 20100,
      "cost_usd": 0.03,
      "codex_timeout": false
    }
  ],
  "principle_promotions": [],
  "candidate_promotions": [],
  "declined_candidates": []
}
```
