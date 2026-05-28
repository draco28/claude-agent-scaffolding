---
doc: BACKLOG
routes_to: backlog
wave: 3
required_sections:
  - "Story format"
  - "Initial stories (seeded from MASTER-SPEC.md)"
  - "Backlog conventions"
mints: [BACKLOG]
consumes: [UC, FR]
model: sonnet
---
## Synthesis guidance

Story format: use the prescribed template — "As a <persona>, I want to <capability>,
so that <outcome>." Every story must map to a real user persona from the PRD Users
section.

Initial stories (seeded from MASTER-SPEC.md): author real, project-specific backlog
items — do NOT emit generic placeholders. Derive stories directly from the UC and FR
IDs in the provided ledger slice. Every `BACKLOG-N` entry must:
  - Have a descriptive slug after the dash (e.g. `BACKLOG-1 — Core login flow`)
  - Include an **Acceptance** criterion that is observable and test-able
  - Reference at least one `traces_fr` or `traces_uc` ID from the ledger slice
  - Cover the MVP core use case (UC-1 equivalent) and then the remaining UCs and
    FRs in priority order (highest user value first)

Do NOT emit `BACKLOG-N` items for infrastructure/DevOps concerns unless they have
an explicit FR or NFR that requires them. Do NOT pad the backlog with aspirational
or out-of-scope features.

Backlog conventions: echo the canonical conventions block from the template — IDs
are `BACKLOG-N`, slices cite those IDs, one slice may cover multiple stories, done
stories are moved to the bottom with strikethrough + completion date.

Number BACKLOG IDs from 1 continuously. Cite only UC and FR IDs present in the
provided ledger slice.
