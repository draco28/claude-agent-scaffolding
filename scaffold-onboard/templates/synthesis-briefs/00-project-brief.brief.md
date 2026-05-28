---
doc: 00-project-brief
routes_to: memory_bank
wave: 4
required_sections:
  - "What is this?"
  - "Project class"
  - "Problem"
  - "Primary users"
  - "Core use case"
  - "MVP cut"
  - "See also"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This file is the always-preloaded Tier 0 memory-bank document. Keep it tightly scoped
to project identity — no architectural detail, no sprint content.

What is this?: synthesize a 1–2 sentence statement of what the product does and for
whom, drawn from MASTER-SPEC `phase_1.1.1`. This is the project's elevator pitch.
Do NOT paraphrase generically — use the project's own domain vocabulary.

Project class: state the project class token exactly as recorded in MASTER-SPEC
(e.g., `web-app`, `cli-tool`, `library`, `llm-app`). Derive from `project_class`.

Problem: synthesize the problem statement from `phase_1.1.2` into one focused
paragraph. Ground it in the domain language from Phase 3 (entities, domain terms).
Express the pain clearly: who suffers, what breaks, and why existing solutions fall
short — if the spec captures that context.

Primary users: list the distinct user personas from `phase_1.2.1`. For each persona
name one primary goal. Use a compact list or short table — no prose filler.

Core use case: describe the single most important user-system interaction, derived from
`phase_1.2.2`. One paragraph. This should be the scenario a new team member would demo
first.

MVP cut: state what is in scope for the MVP (`phase_1.3.2`) and call out 1–3 explicit
out-of-scope items visible in Phase 2, Phase 4, or Phase 10. Be concrete — name feature
areas or capabilities, not abstract categories.

See also: emit the canonical cross-reference links exactly as they appear in the
template (MASTER-SPEC §Phase 1 and Executive Summary).
