---
scenario_id: 03-internal-spine-no-consumer
expected_verdict: reject
expected_reason: internal spine names no committed consuming user-facing spine
---
An internal spine contributes only `auto:` lines (a normalization layer) and claims product value on the grounds that "the UI will consume it someday". No consuming user-facing spine is named or scheduled.
