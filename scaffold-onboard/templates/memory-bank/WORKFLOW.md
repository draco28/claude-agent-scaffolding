# Workflow

> Static file copied from scaffold-onboard. Not regenerated; edit by hand if your workflow diverges.

## Per-slice loop

Use the companion `scaffold-dev` plugin (implementation phase) for slice work. Slices
are planned and dispatched, not hand-stepped:

1. `/orchestrate VS-N.M` — plan the vertical slice: decompose into 4–5 work items,
   identify rounds via the dependency DAG, author specs upfront, then per round spawn
   worktrees and dispatch implementer subagents.
2. `/work-item <handoff>` — execute a single work item directly (manual fallback when
   you are not dispatching subagents).
3. `/impl-check` — per-work-item verification gate: runs the `auto:` acceptance
   criteria, cross-checks `report.md`, and checks machine-checkable rules.
4. `/handoff` — author a session handoff doc for out-of-slice transitions
   (sprint boundary, context bloat, bug-fix detour).
5. **Slice close** (say "close VS-N.M") — slice-close ceremony: auto-demo + manual-demo,
   architect-critic review, retrospective, memory-bank harvest, then worktree + branch cleanup.

At sprint boundaries, say `close sprint N` to aggregate the per-slice retrospectives.

## When to update memory-bank

- **05-active-context.md** — update as you switch slices or change focus. Hand-edit freely.
- **06-progress.md** — append after every commit (via `add changelog entry` or by hand). One line per change.
- **00–04, 07, 08, index** — never hand-edit; re-run `/scaffold-project` after editing MASTER-SPEC.md.

## When to update governance docs

- **ADRs** — say `record ADR` for each architectural decision.
- **Runbooks** — say `author runbook` for operational procedures.
- **PRD / SRS / BACKLOG / PROJECT_PLAN** — re-run `/scaffold-docs` after material MASTER-SPEC.md changes; otherwise hand-edit (existing files preserved).

## Composition with other plugins

- `ai-mentor` — cognitive modes (`/council`, `/grill-me`, `/eli10`, `/fool`). Use when decisions matter more than typing speed.
- `architect-critic` — anti-sycophancy reviews (`/critique`). Auto-fires at Phase 5/7 onboarding recaps and MASTER-SPEC close; can be invoked manually on slice specs and ADRs.
- `superpowers` — TDD, debugging, parallel agent dispatch, plan/execute discipline.
