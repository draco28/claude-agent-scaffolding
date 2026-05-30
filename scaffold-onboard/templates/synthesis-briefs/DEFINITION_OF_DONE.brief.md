---
doc: DEFINITION_OF_DONE
routes_to: process_adrs
wave: 4
required_sections:
  - "Code"
  - "Tests"
  - "Pre-merge gates"
  - "Documentation"
  - "Operations"
  - "Release readiness"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document synthesizes the project's Definition of Done from MASTER-SPEC Phase 9
(quality gates, coverage) and Phase 10 (operations, observability, rollout).

Code: reproduce the standard Code checklist from the template. Ensure the reference to
`03-code-patterns.md` is present. If Phase 5 or Phase 6 signals project-specific coding
constraints (e.g., type safety requirements, linting rules, specific style guides), add
those as project-specific items below the standard checklist.

Tests: reproduce the standard Tests checklist. In the coverage floor item, link to
TEST_STRATEGY.md and reference the specific coverage number from `phase_9.1.1`. If the
ledger contains NFR IDs that encode test-ably measurable quality bars, list them
explicitly as done criteria (e.g., "NFR-4 determinism: green" rather than a generic
"tests pass").

Pre-merge gates: reproduce `phase_9.2.1` exactly. These are the hard gates that block
merge. Annotate each gate with the NFR ID it enforces where a match is visible in the
ledger. Do NOT leave gates unannotated if a corresponding NFR exists.

Documentation: reproduce the standard Documentation checklist. If Phase 6 or Phase 7
signals a docs-site or API reference requirement, add a project-specific item (e.g.,
"API reference updated in docs/api/"). Reference the `/changelog` and `/adr`
scaffold-dev commands.

Operations: reproduce the standard Operations checklist. Ground the observability item in
`phase_10.2.1` (what metrics/logs are required). Add any project-specific observability
requirement visible in Phase 10 (e.g., specific alerting thresholds from `phase_10.2.2`
or on-call runbook from `phase_10.3.1`).

Release readiness: reproduce the release readiness checklist with `phase_10.1.1` as the
rollout strategy label. Include the on-call/response plan reference from `phase_10.3.1`
and the deprecation/retirement note from `phase_10.3.2`. These items must be
project-specific text, not placeholder brackets.
