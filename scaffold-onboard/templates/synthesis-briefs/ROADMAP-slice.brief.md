---
doc: ROADMAP-slice
routes_to: roadmap
wave: 4
required_sections:
  - "Scope"
  - "Demo criteria"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document synthesizes one vertical slice entry in the roadmap. The agent receives
a specific slice name/number as its context; synthesize only that slice, not the full
roadmap.

Scope: write a single focused paragraph (3–6 sentences) grounded concretely in the
project spec. The paragraph must:
  - Name the slice's bounded capability in plain language
  - Identify the primary user persona(s) affected (from MASTER-SPEC Phase 1)
  - State the architectural boundary the slice touches (Phase 5 — module or service)
  - Reflect any relevant constraints from Phase 2 (timeline, budget) or Phase 4
    (security, compliance) that narrow what "done" means for this slice

If a ledger slice is provided, cite the FR/NFR/BACKLOG IDs this slice satisfies.
Pattern: "Satisfies: FR-1, FR-3 · NFR-2 · BACKLOG-4, BACKLOG-5." Do NOT invent IDs
not present in the ledger slice.

**Lightweight-mode note (no ledger):** If no ID ledger is provided (i.e. `/scaffold-docs`
was not run before this call), synthesize Scope grounded in MASTER-SPEC language and
note at the end of the paragraph: "Requirement coverage limited — run `/scaffold-docs`
to generate traceable IDs." Do NOT invent synthetic IDs (FR-N / BACKLOG-N) in this mode.

Demo criteria: emit exactly two lines:
  - `auto:` — the machine-verifiable check that confirms the slice's primary behaviour.
    Express as a concrete assertion ("returns HTTP 200", "row exists in DB", "CLI exits 0
    with output matching regex"). Ground this in the project's tech stack (Phase 5) and
    test strategy (Phase 9).
  - `user:` — the human-observable check a stakeholder performs during a demo review.
    Express as a one-sentence observable outcome tied to the project's UI or DX surface
    (Phase 6). Must be completable in ≤ 60 seconds during a live demo.

Do NOT use generic placeholders ("the feature works", "tests pass"). Both criteria must
be slice-specific and grounded in MASTER-SPEC language.
