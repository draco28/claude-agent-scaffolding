---
scenario_id: 04-mixed-depths
expected_behavior: table's depth column distinguishes "shallow" from "close"; adversaries_used column shows ["claude"] for shallow runs and ["claude","codex"] for close runs — both values visible in the same output
fixture_kind: state-json
---

State has 6 runs: 3 shallow (claude-only) and 3 close (claude+codex). The skill must render both depth values and both adversary combinations in the same table so the user can compare run types at a glance.

```json
{
  "schema_version": 1,
  "in_flight": [],
  "recent_runs": [
    {
      "request_id": "crit-2026-04-28T10-00Z-shallow-d1a2",
      "completed_at": "2026-04-28T10-14:22Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 4,
      "divergence_count": 0,
      "concessions": 1,
      "elapsed_ms": 16300,
      "cost_usd": 0.02,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-01T14-00Z-close-d2b3",
      "completed_at": "2026-05-01T14:38:09Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 8,
      "divergence_count": 2,
      "concessions": 4,
      "elapsed_ms": 47200,
      "cost_usd": 0.13,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-05T09-00Z-shallow-d3c4",
      "completed_at": "2026-05-05T09:22:51Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 3,
      "divergence_count": 0,
      "concessions": 0,
      "elapsed_ms": 13700,
      "cost_usd": 0.02,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-09T15-00Z-close-d4d5",
      "completed_at": "2026-05-09T15:57:33Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 6,
      "divergence_count": 1,
      "concessions": 3,
      "elapsed_ms": 41800,
      "cost_usd": 0.11,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-14T11-00Z-shallow-d5e6",
      "completed_at": "2026-05-14T11:03:17Z",
      "depth": "shallow",
      "adversaries_used": ["claude"],
      "challenge_count": 5,
      "divergence_count": 0,
      "concessions": 2,
      "elapsed_ms": 18900,
      "cost_usd": 0.03,
      "codex_timeout": false
    },
    {
      "request_id": "crit-2026-05-21T13-00Z-close-d6f7",
      "completed_at": "2026-05-21T13:44:02Z",
      "depth": "close",
      "adversaries_used": ["claude", "codex"],
      "challenge_count": 9,
      "divergence_count": 3,
      "concessions": 5,
      "elapsed_ms": 53600,
      "cost_usd": 0.15,
      "codex_timeout": false
    }
  ],
  "principle_promotions": [],
  "candidate_promotions": [],
  "declined_candidates": []
}
```
