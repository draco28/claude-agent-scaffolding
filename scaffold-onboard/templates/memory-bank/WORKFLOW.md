# Workflow

> Static file copied from scaffold-onboard. Not regenerated; edit by hand if your workflow diverges.

## Per-slice loop

Use the companion `scaffold` plugin (implementation phase) for slice work:

1. `/slice-new <name>` — author the slice spec
2. `/slice-contract` — scaffold failing tests for each acceptance criterion
3. `/slice-scaffold` — write skeletons (types, glue, structure)
4. `/slice-implement` — fill in the logic until tests pass
5. `/slice-verify` — run all tests; mark complete when green

## When to update memory-bank

- **05-active-context.md** — update as you switch slices or change focus. Hand-edit freely.
- **06-progress.md** — append after every commit (via `/changelog` or by hand). One line per change.
- **00–04, 07, 08, index** — never hand-edit; re-run `/scaffold-project` after editing MASTER-SPEC.md.

## When to update governance docs

- **ADRs** — `/adr-new` for each architectural decision.
- **PRD / SRS / BACKLOG / PROJECT_PLAN** — re-run `/scaffold-docs` after material MASTER-SPEC.md changes; otherwise hand-edit (existing files preserved).

## Composition with other plugins

- `ai-mentor` — cognitive mode (`/z1`, `/z2-decide`, `/z2-build`). Use when decisions matter more than typing speed.
- `architect-critic` — anti-sycophancy reviews. Auto-fires at Phase 5/7 onboarding recaps and MASTER-SPEC close; can be invoked manually on slice specs and ADRs.
- `superpowers` — TDD, debugging, parallel agent dispatch, plan/execute discipline.
