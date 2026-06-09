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

The emitted document MUST satisfy scaffold-onboard's parser contract:

- First line exactly follows `# <Project Name> — Master Specification`.
- Include `**Project class:** <enum>` near the top, using one of the allowed enum
  values from the digest: `CLI tool`, `Library or SDK`, `Web app`, `Web service
  (API only)`, `Mobile app`, `ML or AI system`, `Agent or plugin`, `Data
  pipeline`, or `Other`.
- Include `**Spec version:** 1.0`.
- Include exactly one marker before each phase section:
  `<!-- master-spec:phase id=N name=<Phase Name> -->`, for N = 1 through 10.
- Keep the marker comments on their own lines. Downstream `sf_spec_validate`
  requires these markers before `/validate-master-spec`, `/scaffold-project`,
  `/scaffold-docs`, and `/plan-roadmap` can consume the file.

Cover the ten role-scoped phases as top-level sections (peers of the Executive
Summary section) in this order:

1. `<!-- master-spec:phase id=1 name=Foundation -->`
2. `<!-- master-spec:phase id=2 name=Strategy -->`
3. `<!-- master-spec:phase id=3 name=Domain & Data Model -->`
4. `<!-- master-spec:phase id=4 name=Security & Compliance -->`
5. `<!-- master-spec:phase id=5 name=Architecture -->`
6. `<!-- master-spec:phase id=6 name=UX / Surfaces -->`
7. `<!-- master-spec:phase id=7 name=Implementation Approach -->`
8. `<!-- master-spec:phase id=8 name=DevOps & Environments -->`
9. `<!-- master-spec:phase id=9 name=Quality/Testing/Eval -->`
10. `<!-- master-spec:phase id=10 name=Operations & Support -->`

Do not omit phase markers. If a phase has no answers and no record, still emit
the marker and a short section noting that the phase was intentionally left
thin or deferred.

You MUST include a `## Executive Summary` section. Emit it as a single real sentence describing the project's purpose (a temporary
placeholder — a separate step synthesizes the authoritative summary and pins it
into this section). Do NOT emit a meta-note like "to be filled in". Keep it
prose-only here: NO `##`
subheadings, NO `---`/`***`/`___` horizontal rules, NO HTML comments inside it.

### Mode

The prompt states the mode:

- **first-author** — no existing MASTER-SPEC. Author the whole document fresh.
  The Executive Summary section is owned by the separate summary step — emit the
  fillable section as instructed above.
