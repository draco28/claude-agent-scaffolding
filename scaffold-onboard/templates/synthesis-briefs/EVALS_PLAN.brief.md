---
doc: EVALS_PLAN
routes_to: product_adrs
wave: 4
required_sections:
  - "Eval dimensions"
  - "Dataset"
  - "Eval cadence"
  - "Failure handling"
  - "See also"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document synthesizes the LLM/ML evaluation plan from MASTER-SPEC Phase 9.3 and the
quality NFRs in the provided ledger. It applies only when the project uses LLMs or ML
(visible in Phase 5 and Phase 9.3).

Eval dimensions: reproduce `phase_9.3.2` and expand each dimension with a concrete
acceptance threshold. For every NFR in the ledger that encodes a measurable quality bar
for model outputs (e.g., accuracy floor, latency ceiling, determinism invariant), map
that NFR ID to the corresponding eval dimension and state its acceptance threshold
explicitly (e.g., "NFR-5 accuracy: >= 0.92 F1 on golden set"). Do NOT leave thresholds
as "TBD" or vague prose — derive them from phase_9.3.2 and the NFR IDs.

Dataset: describe the golden evaluation dataset in project-specific terms. Derive the
data class and domain from Phase 3 (entities) and Phase 4 (sensitive data handling in
`phase_4.1.1`). State: the source of the golden set, the approximate size, the
refresh cadence, and the acceptance threshold per dimension. If `phase_4.1.1` signals
sensitive or regulated data, note the anonymization / synthetic-data approach required
for the eval set.

Eval cadence: specify when each tier of evals runs. Three tiers are mandatory:
  - Pre-merge: lightweight smoke evals on every PR that touches prompt or model code —
    name the specific subset of the eval suite and the runtime budget.
  - Nightly: full suite against the golden set — name the alerting channel from
    `phase_10.2.2`.
  - Pre-release: regression check against the prior 3 releases — define the regression
    threshold (e.g., no dimension may regress more than 2 percentage points).
Ground cadence specifics in Phase 8 (CI/CD pipeline) and Phase 10 (alerting).

Failure handling: state the concrete merge-blocking condition in terms of the eval
dimensions and their NFR-linked thresholds. State the nightly alert trigger referencing
`phase_10.2.2`. Add a project-specific escalation path drawn from `phase_10.3.1`.

See also: include links to MODEL_CARD.md and PROMPT_GOVERNANCE.md as in the template.
