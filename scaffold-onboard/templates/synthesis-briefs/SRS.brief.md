---
doc: SRS
routes_to: srs
wave: 2
required_sections:
  - "Functional Requirements"
  - "Non-Functional Requirements"
  - "Traceability"
mints: [FR, NFR]
consumes: [UC]
model: opus
---
## Synthesis guidance

Functional Requirements: derive each FR from a PRD **use case** (UC-N) in the
provided ledger slice. Every `FR-N` states a capability the system must DO and
MUST trace to ≥1 UC (`traces_uc`). Do NOT source FRs from implementation choices
(module boundaries, code style, ORM/API selection — those are design, not FRs).

Non-Functional Requirements: derive each `NFR-N` from a quality attribute —
latency/throughput budgets (MASTER-SPEC §5.3.2), determinism invariants (Phase 3),
security invariants (Phase 4), coverage floors / quality gates (Phase 9). Do NOT
source NFRs from devops/hosting/CI (Phase 8). Where an NFR is a slice's acceptance
bar, phrase it test-ably (e.g. "p95 < 200ms", "100× identical hash").

Traceability: render a table mapping each FR/NFR → the UC(s) it serves.
Number FR and NFR from 1. Cite only UC IDs present in the ledger slice.
