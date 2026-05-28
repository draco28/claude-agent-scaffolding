---
doc: RISK_REGISTER
routes_to: product_adrs
wave: 4
required_sections:
  - "Phase 2.2.2 source text"
  - "Conventions"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document seeds the project risk register from MASTER-SPEC Phase 2.2.2 and the
broader technical landscape visible in Phases 3–5.

Phase 2.2.2 source text: reproduce the Phase 2.2.2 text verbatim from MASTER-SPEC (it
records the known risks the team entered during onboarding). Do NOT paraphrase.

Risk table: above the source text block, emit the seeded risk table. Populate each row
with a project-specific risk drawn directly from Phase 2.2.2 and from technical signals
in the rest of MASTER-SPEC (e.g., novel integrations in Phase 4/5, domain constraints in
Phase 3, timeline pressure in Phase 2.1). For each risk:
  - Assign a unique ID `R-001`, `R-002`, … in order.
  - State the risk as a concrete, project-specific sentence — NOT generic placeholders
    like "scope creep" or "unknown unknowns". Reference the phase or FR/NFR that exposes it.
  - Set Category to one of: `tech`, `market`, `resource`, `integration`, `security`.
  - Set Likelihood and Impact to one of: Low / Medium / High.
  - Write a one-sentence Mitigation that is actionable.
  - Leave Owner and Status as `TBD` / `open` for initial seeding.

Include at least as many risks as there are distinct risk signals in Phase 2.2.2. If Phase
2.2.2 names additional risk classes (e.g., vendor API limits, regulatory compliance), add
rows for each. Do NOT omit project-specific risks to keep the table short.

Conventions: echo the conventions block from the template exactly — IDs `R-NNN`, never
reused; Status values `open · mitigated · accepted · closed`; hand-edit instructions.
