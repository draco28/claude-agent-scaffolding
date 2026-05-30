---
doc: 01-product-context
routes_to: memory_bank
wave: 4
required_sections:
  - "Primary users"
  - "Core use case"
  - "Domain entities"
  - "Entity identity & description"
  - "Key relationships"
  - "Aggregates / invariants"
  - "Ubiquitous language"
  - "See also"
# Branch-gated sections — included ONLY when the project class activates the gate
# (see synthesis guidance). The validator does NOT hard-require these: omitting a
# gated section whose branch is false is correct, not a failure (#26 Slip 1).
# Surfaces / Primary user flow are UI-branch; the two DX rows are DX-branch.
gated_sections:
  - "Surfaces"
  - "Primary user flow"
  - "Developer experience — discovery & learning"
  - "Error and output style"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This file is the branch-loaded product/UX context document. It is loaded when a
conversation touches product, UX, or domain-model concerns. Keep content grounded
in MASTER-SPEC — no speculative additions.

Primary users: restate the personas from `phase_1.2.1` with their primary goals.
Consistent with `00-project-brief.md` — do NOT contradict it.

Core use case: one concise paragraph describing the primary user-system interaction
(`phase_1.2.2`). Consistent with `00-project-brief.md`.

Domain entities: enumerate all domain entities from `phase_3.1.1`. Use a list. Each
entity name should use the ubiquitous language term from the spec.

Entity identity & description: for each entity in the list above, give a 1–2 sentence
description of its identity and role in the domain (`phase_3.1.2`). Use a definition-
list or table format.

Key relationships: describe the relationships between entities (`phase_3.2.1`). For
each relationship state the cardinality and the semantic meaning (e.g., "Project
owns many Slices; a Slice belongs to exactly one Project").

Aggregates / invariants: list domain invariants and aggregate boundaries from
`phase_3.2.2`. Express each invariant as a must-hold constraint in plain language.

Ubiquitous language: produce a glossary of key domain terms from `phase_3.3.1`.
Format as a definition list. Include only terms that appear in the domain model or
that differ from common usage.

Surfaces (UI branch only): if the project has a UI surface, synthesize from
`phase_6A.1.1`. Name the screens or views and their purpose. Omit this section
entirely for non-UI projects (DX branch projects replace it with the DX sections).

Primary user flow (UI branch only): describe the primary user flow step-by-step from
`phase_6A.1.2`. Write as a numbered sequence of user actions and system responses.
Omit for non-UI projects.

Developer experience — discovery & learning (DX branch only): synthesize from
`phase_6B.1.1`. Describe how a new developer discovers and learns the tool/library.
Omit for non-DX projects.

Error and output style (DX branch only): synthesize from `phase_6B.1.2`. Describe the
conventions for error messages, output formatting, and exit codes. Omit for non-DX
projects.

**Conditional sections note:** emit only the surface sections that match the project's
branch (UI or DX). Do not emit both UI and DX sections for the same project. If the
spec does not explicitly record a surface type, default to emitting both section pairs
with a clear note that only one applies.

See also: emit the canonical cross-reference links exactly as they appear in the
template (MASTER-SPEC §Phase 3 and §Phase 6).
