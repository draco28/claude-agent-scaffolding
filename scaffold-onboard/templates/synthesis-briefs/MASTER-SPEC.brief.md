---
doc: MASTER-SPEC
routes_to: master_spec
wave: 0
required_sections:
  - "Executive Summary"
mints: []
consumes: []
model: sonnet
---
## Synthesis guidance

You are authoring `MASTER-SPEC.md`, the project's source-of-truth specification,
from the onboarding discussion digest provided in the prompt. The digest holds,
per phase (1–10): the participant's verbatim answers AND a synthesized phase
record (decisions, rationale, rejected alternatives, constraints, open questions,
critic outcomes). SYNTHESIZE — do not transcribe. Turn the raw answers and the
phase records into coherent specification prose in the project's own domain
vocabulary. Never emit fill-in markers, `TODO:`, or `{{placeholder}}` tokens.

Cover the ten role-scoped phases as top-level `## <Phase Name>` MASTER-SPEC sections (peers of the Executive Summary section): Foundation, Strategy,
Domain & Data Model, Security & Compliance, Architecture, UX / Surfaces,
Implementation Approach, DevOps & Environments, Quality/Testing/Eval, Operations
& Support. Omit a phase section only when its digest has no answers and no record.

You MUST include a `## Executive Summary` section. Emit it as a single real sentence describing the project's purpose (a temporary
placeholder — a separate step synthesizes the authoritative summary and pins it
into this section). Do NOT emit a meta-note like "to be filled in". Keep it
prose-only here: NO `##`
subheadings, NO `---`/`***`/`___` horizontal rules, NO HTML comments inside it.

### Mode

The prompt states the mode:

- **first-author** — no existing MASTER-SPEC. Author the whole document fresh.
- **reconcile** — an existing MASTER-SPEC is provided (read it in full). Refresh
  ONLY the phases listed as "touched this run"; reproduce every other section
  verbatim, preserving any human edits. Do not reorder or restyle untouched
  sections. The Executive Summary section is owned by the separate summary step —
  carry it through unchanged in reconcile mode.
