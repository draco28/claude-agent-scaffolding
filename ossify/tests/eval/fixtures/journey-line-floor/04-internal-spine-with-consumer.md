---
scenario_id: 04-internal-spine-with-consumer
expected_verdict: accept
expected_reason: internal spine names a committed consumer within one release
---
An internal spine contributes only `auto:` lines (a pricing cache) and names the committed user-facing spine "quote ticket" scheduled in the next release as its consumer.
