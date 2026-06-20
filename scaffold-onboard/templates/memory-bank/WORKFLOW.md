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

## Memory-bank update cadence

<!-- cadence-policy:canonical -->

> **This section is the single source of truth for when and by whom each memory-bank
> file is updated.** Every scaffold-onboard / scaffold-dev skill that touches the
> memory bank points here instead of restating the rule. Change the cadence here only.

Files fall into three ownership classes:

- **Spec-derived** — `00-project-brief`, `01-product-context`, `02-system-patterns`,
  `04-tech-context`, `07-constraints`, `08-governance`, `index`. Regenerated from
  `MASTER-SPEC.md` by `/scaffold-project`. Never hand-edit; edit MASTER-SPEC.md and
  re-derive.
- **Dev-authored** — `05-active-context`, `06-progress`, `09-known-issues`,
  `10-decisions-log`, `tech-debt`. Written while building; **preserved** across
  re-derive (seeded once if missing).
- **Mixed** — `03-code-patterns`. Spec-derived prose PLUS one preserved
  `## Machine-checkable rules` zone (between `<!-- mcrules:preserve:start/end -->`)
  that survives re-derive.

| Event | Files updated | By whom |
|---|---|---|
| `/onboard`, `/scaffold-project` | derive spec-derived files + `03` prose (preserve `03` rules zone); seed dev-authored files if missing | `scaffolding-memory-bank` |
| Work-item close | **none** — suggestions captured in `report.md` for later harvest | `implementer-agent` |
| Slice close | `05` cursor; `09-known-issues` + `10-decisions-log` (agent-judged harvest); `tech-debt` (auto-file sweep); `03` rules zone *only if* a discovered pattern is promoted to a rule | `closing-vertical-slice` |
| Sprint close | **none** — sprint retro is read-only aggregation | `writing-sprint-retrospective` |
| Continuous | `05` (focus changes); `06` (`add changelog entry` / by hand); `03` rules (`authoring-machine-checkable-rules`); `tech-debt` (`/defer`) | you / the named skill |
| Re-derive after MASTER-SPEC change | re-derive spec-derived files + `03` prose (rules zone preserved); dev-authored files untouched | `/scaffold-project` |

**Harvest routing (slice close):** caveats / gotchas / stack notes → `09-known-issues`;
decisions / advisory patterns → `10-decisions-log`; enforceable patterns → a
machine-checkable rule in `03` (via `authoring-machine-checkable-rules`). **Never**
append harvested prose into the spec-derived body of `03` / `04`.

## Lean-index pointer conventions

<!-- pointer-conventions:canonical -->

> The memory bank is a **thin index of pointers** — depth lives in addressable
> external stores, never re-stored as prose (#33/#48). This section is the single
> source of truth for the pointer forms; skills point here instead of restating them.

When a memory entry would restate content already tracked elsewhere, cite a **pointer**
instead of copying the prose:

- **Doc anchor** — `<DOC> §<anchor>` where the anchor is a section number, id, or
  heading title, e.g. `MASTER-SPEC.md §5.2`, `SRS.md §FR-5`. Resolves via
  `sd citations_check_anchor "<doc-file>" "<anchor>"` (heading must exist).
- **ADR** — `ADR-<NNNN>` (the id, never the decision prose), e.g. `ADR-0007`. Resolves
  via `sd citations_check_adr "ADR-NNNN" "<product-adr-dir>" "<process-adr-dir>"`
  (independent series → both dirs).
- **GitHub issue** — `#<N>` (filed via `/defer`; indexed in `tech-debt`).
- **claude-mem** *(only if the claude-mem plugin is present)* — a topic/corpus query,
  e.g. `claude-mem: "data-pipeline decisions" corpus <name>`, never a transcript. If
  claude-mem is absent, do not author a claude-mem pointer.

Slice-close harvest enforces this at write time (`closing-vertical-slice` §9.4): a
candidate that restates tracked content is surfaced as a pointer (resolution-checked),
not harvested as prose; an over-long entry is flagged by `sd harvest_lint_length`.

## When to update governance docs

- **ADRs** — say `record ADR` for each architectural decision.
- **Runbooks** — say `author runbook` for operational procedures.
- **PRD / SRS / BACKLOG / PROJECT_PLAN** — re-run `/scaffold-docs` after material MASTER-SPEC.md changes; otherwise hand-edit (existing files preserved).

## Composition with other plugins

- `ai-mentor` — cognitive modes (`/council`, `/grill-me`, `/eli10`, `/fool`). Use when decisions matter more than typing speed.
- `architect-critic` — anti-sycophancy reviews (`/critique`). Auto-fires at Phase 5/7 onboarding recaps and MASTER-SPEC close; can be invoked manually on slice specs and ADRs.
- `superpowers` — TDD, debugging, parallel agent dispatch, plan/execute discipline.
