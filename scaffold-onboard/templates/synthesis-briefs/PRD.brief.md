---
doc: PRD
routes_to: prd
wave: 1
required_sections:
  - "Vision"
  - "Problem"
  - "Users"
  - "Scope"
  - "Success metrics"
  - "Use cases"
mints: [UC]
consumes: []
model: opus
---
## Synthesis guidance

Vision: synthesize the project's core vision statement from MASTER-SPEC Phase 1
(phase_1.1.1). Express it in 1–3 sentences — what this product does and why it
matters. Do NOT paraphrase the spec verbatim; distil it into a coherent claim.

Problem: describe the concrete problem being solved (phase_1.1.2). Ground it in
the domain language found in MASTER-SPEC Phase 3 (entities, relationships). One
focused paragraph.

Users: enumerate the distinct user personas (phase_1.2.1). For each persona name
the primary goal and the key pain point the product resolves. Use a short table or
list.

Scope: state what is in scope for the MVP (phase_1.3.2) and explicitly call out
1–3 items that are out of scope. Derive out-of-scope boundaries from Phase 2 and
Phase 10 (rollout/phasing) context.

Success metrics: translate the 6-month success criteria (phase_1.1.3) and
Phase 2 success metric (phase_2.3.1) into measurable KPIs. Each metric must be
specific and test-able (e.g., "p95 latency < 200 ms", "≥ 80 % monthly active
retention").

Use cases: emit a numbered `UC-1` through `UC-N` set that covers the full scope
of the product — the core loop, all material features from the feature backlog
(Phase 4), and domain operations visible in Phase 3. Do NOT emit a single use
case; there must be at least as many UCs as there are distinct actor-goal pairs
discoverable in the spec. Each UC entry must include:
  - `actor` — the persona(s) from the Users section
  - `trigger` — what initiates the interaction
  - `outcome` — the observable result that satisfies the actor

Number UC IDs from 1. These IDs will be consumed by the SRS and BACKLOG agents,
so they must be stable and unique.
