---
doc: DEMO_RUNBOOK
routes_to: process_adrs
wave: 4
required_sections:
  - "Setup"
  - "Demo flow"
  - "Common questions + answers"
  - "Recovery"
mints: []
consumes: [UC, FR, NFR, BACKLOG]
model: sonnet
---
## Synthesis guidance

This document synthesizes a step-by-step demo runbook from MASTER-SPEC Phase 6 (UX /
DX surface), Phase 8 (environments), and Phase 1 (users, value proposition).

Setup: ground each setup step in the actual project environment. Use `phase_8.3.1` for
the environment target (staging, local, demo cluster). Describe the specific test-data
or fixture state needed for a clean demo — derive this from Phase 3 (domain entities)
and the UC IDs in the ledger (each UC represents a demonstrable capability that requires
a known starting state). Name the actual user roles or accounts required, drawn from
`phase_1.2.1` (user personas) and `phase_4.2.1` (auth model). Do NOT use fill-in
markers for any setup step.

Demo flow: write the demo as a numbered, ordered walkthrough of the primary user value
loop. Ground each step in the project's actual UI surface (`phase_6A.1.1` / `phase_6A.1.2`
for UI-branch projects) or CLI/API surface (`phase_6B.1.1` / `phase_6B.1.2` for DX-branch
projects). Each step should correspond to a demonstrable UC from the ledger — cite the
UC ID in a note. Highlight the features that deliver the most differentiated value per
Phase 1 (problem statement, vision). The flow must cover at minimum the core use case
(the UC-1 equivalent) and at least one secondary capability. Write concrete actions
("Click 'New project' → enter project name → press Enter") not vague descriptions.

Common questions + answers: seed with 3–5 real questions a stakeholder or evaluator
would ask given this project's domain, constraints, and competitive context (visible in
Phase 1–4). Answers should be project-specific and grounded in the spec. Frame questions
around known decision points (e.g., why a specific auth model, data model constraints,
pricing tier) so the table is useful in a real demo context.

Recovery: write 2–4 concrete fallback paths for likely failure modes in this project's
demo environment. Ground them in the actual tech stack (Phase 5) and environment
(Phase 8). Each recovery instruction should be specific: name the fallback action
("switch to the pre-recorded screen capture at `demo/fallback.mp4`") and when to use it.
Include a graceful escape clause that names an alternative feature to demonstrate while
the primary flow recovers.
