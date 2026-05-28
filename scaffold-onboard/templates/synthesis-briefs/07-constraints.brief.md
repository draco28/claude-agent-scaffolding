---
doc: 07-constraints
routes_to: memory_bank
wave: 4
required_sections:
  - "Timeline & resources"
  - "Budget"
  - "Risks (top 3)"
  - "Success metric"
  - "Compliance / regulation"
  - "Performance targets"
  - "Operations & support"
  - "See also"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This file is the branch-loaded hard-constraints document. It is loaded when a
conversation touches planning, scoping, or resource constraints. Express every
constraint as a concrete, test-able bound — no ranges or hedged phrasing.

Timeline & resources: synthesize from Phase 2:
  - Target weeks to MVP: from `phase_2.1.1` — a specific number of weeks.
  - Team size: from `phase_2.1.2` — headcount or FTE equivalent.
These are hard inputs. Do NOT adjust them or add hedging language.

Budget: state the monthly cost cap from `phase_2.2.1`. If the spec distinguishes
budget categories (infra vs. API vs. tooling), break them down as sub-items. Express
as a specific figure (e.g., "$200/month") not a range.

Risks (top 3): enumerate the top 3 project risks from `phase_2.2.2`. For each risk:
  - Name the risk concisely
  - State the likelihood/impact context visible in the spec
  - Provide a one-line mitigation strategy
Risks must be project-specific (technical unknowns, external dependencies, domain
complexity) — do NOT substitute generic risks like "scope creep" unless the spec
explicitly captures them.

Success metric: state the primary measurable success criterion from `phase_2.3.1`.
Express it as a concrete acceptance bar using the same phrasing as the PRD Success
metrics section. Must be specific and test-able (e.g., "p95 latency < 200 ms",
"≥ 80% monthly active retention at 90 days").

Compliance / regulation: synthesize the compliance regime from `phase_4.1.2`. State
the applicable regulations (GDPR, HIPAA, SOC 2, etc.) or explicitly state "None
identified" if the spec records no regulated domain. Do NOT leave this blank.

Performance targets: synthesize two sub-fields:
  - Scale (6 months): from `phase_5.3.1` — expected volume, users, or request rate
    at the 6-month horizon.
  - Latency: from `phase_5.3.2` — hot-path latency or throughput targets.
Express as test-able constraints.

Operations & support: synthesize two sub-fields from Phase 10:
  - On-call / response: from `phase_10.3.1` — who is on-call, SLA, response time.
  - Deprecation plan: from `phase_10.3.2` — how the product is retired or handed
    off if the project ends.

See also: emit the canonical cross-reference links exactly as they appear in the
template (MASTER-SPEC §Phase 2, §Phase 4, and §Phase 10).
