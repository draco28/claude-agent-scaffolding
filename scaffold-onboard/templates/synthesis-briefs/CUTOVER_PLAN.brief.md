---
doc: CUTOVER_PLAN
routes_to: product_adrs
wave: 4
required_sections:
  - "Environments"
  - "Hosting"
  - "Rollout strategy"
  - "Cutover script"
  - "Pre-cutover"
  - "During cutover"
  - "Post-cutover"
  - "Rollback"
  - "Communication"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document synthesizes a production-ready cutover plan from MASTER-SPEC Phase 8
(environments, hosting) and Phase 10 (rollout strategy, observability, stakeholders).

Environments: derive from `phase_8.2.2`. Name each environment (dev / staging / prod or
equivalent) with its purpose and any project-specific promotion criteria visible in the
spec. Do NOT emit generic environment descriptions — use the actual environment names and
hosting details from the spec.

Hosting: derive from `phase_8.3.1`. State the deployment target (cloud provider, container
runtime, serverless platform, or on-prem) and any notable infrastructure constraints
(e.g., region requirements, compliance boundaries from `phase_4.1.2`).

Rollout strategy: derive from `phase_10.1.1`. State whether the release is phased /
feature-flagged / canary / big-bang, and why that strategy fits the project's risk
profile and team size (`phase_2.1.2`). Reference specific BACKLOG items from the ledger
that are in scope for the first release.

Cutover script — Pre-cutover: write a numbered, ORDERED list of tasks to complete before
the cutover window opens. Each step must include an expected outcome so the operator
knows what "done" looks like before proceeding. Draw steps from Phase 8 (infra
provisioning, environment readiness) and Phase 10 (pre-flight checks, backup/snapshot
procedures). Example step shape: "1. Snapshot production database — expected outcome:
backup job completes with exit code 0 and snapshot ID logged." Do NOT use fill-in
markers or placeholder text.

Cutover script — During cutover: write a numbered, ORDERED list of steps that constitute
the live cutover. Each step must state the action, the operator responsible, and the
expected observable outcome. Ground steps in the project's actual deployment mechanism
from Phase 8 and the rollout strategy from Phase 10. Every step must be specific enough
that an operator can execute it without additional context. Do NOT use fill-in markers.

Cutover script — Post-cutover: write a numbered, ORDERED list of verification and
sign-off tasks. Each step must reference a concrete check (e.g., specific metrics,
health endpoint, smoke test from TEST_STRATEGY.md, alerting thresholds from
`phase_10.2.2`). Include a go/no-go sign-off step naming the responsible role from
`phase_10.3.1`. Do NOT use fill-in markers.

Cutover script — Rollback: write a numbered, ORDERED list of revert steps. State
explicitly the trigger condition — "we roll back if X" — grounded in the project's
alerting thresholds (`phase_10.2.2`) or a failed post-cutover check. Each revert step
must have an expected outcome. Include a step to notify stakeholders of the rollback.
Do NOT use fill-in markers or vague instructions like "undo the deployment."

Communication: list the real stakeholder roles to notify, derived from MASTER-SPEC
Phase 2 (team, sponsor) and Phase 10 (on-call, response plan). For each stakeholder
group state the communication channel (Slack channel name, email list, or status page)
and the trigger (pre-cutover notice, go-live confirmation, rollback alert). Do NOT emit
a `*(list)*` placeholder — every stakeholder entry must be populated from the spec.
