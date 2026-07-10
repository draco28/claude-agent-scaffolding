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

### Evidence fidelity and structural quality

The phase records are the evidence boundary. Preserve their reasoning, but do
not manufacture decisions, rationale, constraints, identifiers, deferrals,
questions, formulas, or future work to make a section look fuller.

- **Audit traces.** When `critic_outcomes` names a concrete challenge that
  changed a decision, annotate that decision inline using the recorded source,
  identifier, and outcome, for example `[Critic P5-C1 -- conceded]` or
  `[Grill Q3]`. Never invent an audit trace identifier, infer one from prose, or
  tag an outcome that did not change the decision. If the record has no concrete
  identifier, preserve the reasoning as normal prose without a synthetic tag.
- **Rejected alternatives.** When a phase record's `alternatives_rejected` is
  non-empty, include a `### Rejected Alternatives` subsection in that phase.
  Name each recorded alternative and give its recorded one-line rationale. Do
  not add plausible-but-unrecorded alternatives. Omit the subsection when the
  field is empty.
- **Cross-cutting constraints.** In Phase 1 include a
  `### Driving Architectural Constraints` subsection that consolidates
  constraints explicitly repeated across two or more phase records. Keep a
  one-phase constraint in its owning phase; repetition alone does not authorize
  a new constraint or stronger wording.
- **Entity depth.** In Phase 3, describe each core entity's identity and
  invariants plus its computational rules, propagation semantics, and
  type-level constraints where the digest records them. If one of those
  dimensions is inapplicable or absent, say so briefly rather than fabricating
  domain behavior, formulas, or change flows.
- **Post-MVP horizon.** After the Phase 10 section, always emit
  `## Appendix: Post-MVP Horizon`. Collect only deferred items, unresolved open
  questions, and candidate enhancements explicitly present in the phase
  records. Group those categories when populated. If there are none recorded,
  write `No post-MVP items or open questions were recorded.` Do not derive a
  roadmap or invent future work in this appendix. Keep the appendix heading
  exact: `lib/parser.sh` uses it as the Phase-10 extraction boundary.

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
