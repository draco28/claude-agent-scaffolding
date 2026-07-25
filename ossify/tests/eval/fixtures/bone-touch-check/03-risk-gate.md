---
scenario_id: 03-risk-gate
expected_verdict: auto-bone
---
Registered risk gate "live-order-execution" has touch surface `src/exec/**` and a control checklist (paper env, human confirm, kill switch, audit trail). A spine's plan changes `src/exec/router.rs`. (Expected: escalates to the bone close path PLUS the gate's control checklist.)
