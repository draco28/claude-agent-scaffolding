---
doc: THREAT_MODEL
routes_to: product_adrs
wave: 4
required_sections:
  - "Scope"
  - "STRIDE checklist"
  - "Trust boundaries"
  - "Open threat items"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document synthesizes a project-specific threat model from MASTER-SPEC Phase 4
(security, auth, sensitive data, external surface) and Phase 3 (domain model, entity
relationships, data flows).

Scope: fill every placeholder field from the matching MASTER-SPEC phase variables —
`phase_4.1.1` (sensitive data handled), `phase_4.1.2` (regulated domain),
`phase_4.3.1` (external attack surface), `phase_4.2.1` (auth model), `phase_4.2.2`
(tenancy model). State the scope concisely but concretely — name the actual data
classes, actual external integrations, and actual auth mechanism from the spec.

STRIDE checklist: for each of the six STRIDE categories, make a project-specific
assessment. Do NOT leave all rows as `TBD`. For each category:
  - Set "In scope?" to Yes or No, grounded in the project's actual attack surface.
  - Write a Mitigation strategy that names the concrete control from the spec (e.g.,
    the specific auth model from phase_4.2.1, data-validation approach from FR IDs
    in the ledger, rate-limiting if visible in phase_4.3.1 or NFR IDs).
  - If the project has no external users (pure CLI/internal tool), mark client-spoofing
    as lower priority and explain why — do NOT fabricate threats that don't apply.

Trust boundaries: write a paragraph (or small diagram in text form) identifying where
untrusted input enters the system. Name the specific entry points from Phase 4 and Phase 3
(e.g., API endpoints, file uploads, webhook payloads, user-supplied prompts for LLM
projects). Describe validation / sanitization approaches visible in the spec. This must be
project-specific prose, not a generic "validate all inputs" sentence.

Open threat items: seed with 1–3 concrete threat items that are not yet mitigated, drawn
from signals in Phase 4 and Phase 3. Each item should reference the MASTER-SPEC phase
section or a FR/NFR ID where the exposure originates. These items are living — note they
should be addressed during slice work and linked to mitigation slices.
