---
doc: TEST_STRATEGY
routes_to: product_adrs
wave: 4
required_sections:
  - "Coverage floor"
  - "Test types in scope"
  - "Pyramid"
  - "Pre-merge gates"
  - "Framework"
  - "What we deliberately don't test"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document synthesizes a project-specific test strategy from MASTER-SPEC Phase 9
(quality, gates, coverage, LLM evals if applicable) and Phase 5 (tech stack).

Coverage floor: state the numeric coverage requirement from `phase_9.1.1` exactly as
written. Do NOT invent a number if the spec doesn't give one — instead, derive the
appropriate floor from NFR IDs in the provided ledger that encode quality or correctness
requirements. If an NFR states a measurable bar (e.g., "determinism: identical hash on
100 runs"), that NFR ID must appear here as a concrete acceptance criterion.

Test types in scope: reproduce `phase_9.1.2` and expand it with project-specific detail.
Name the actual test types (unit, integration, E2E, contract, LLM eval if applicable)
and ground each type in the project's architecture from Phase 3 and Phase 5. For any NFR
ID in the ledger that encodes a measurable quality bar, state which test type will verify
it and what the acceptance threshold is (e.g., "NFR-3 p95 latency < 200 ms — verified
by integration test against staging infra").

Pyramid: state the three tiers (unit / integration / E2E) with realistic targets grounded
in the project's scale. Tie percentage targets and runtime budgets to Phase 5 stack
characteristics. If the project has an LLM or ML component (visible in Phase 9.3), add
a fourth tier for model evals and reference EVALS_PLAN.md.

Pre-merge gates: reproduce `phase_9.2.1` verbatim, then annotate each gate with the NFR
ID it enforces where a match exists in the ledger. Do NOT leave gate items unannotated if
a corresponding NFR is present.

Framework: name the canonical test framework for `phase_5.2.1` stack — pick the specific
tool (e.g., pytest, Jest, go test, cargo test) not just the language. State the test
command; it is run by the slice's `auto:` demo criteria and the scaffold-dev
`/impl-check` verification gate. If phase_9.3 signals LLM eval tooling, name that
framework too.

What we deliberately don't test: list 3–5 concrete exclusions grounded in this project
(e.g., generated code from specific tools, third-party SDK internals, infrastructure
provisioning scripts). Provide a rationale for each exclusion so future contributors
don't re-add coverage for excluded areas.
