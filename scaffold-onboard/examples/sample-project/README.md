# Sample Project — `todo-cli`

> Illustrative end-to-end demonstration of the v0.2 R1 + R2 + R3 contracts. Lives under `scaffold-onboard/examples/sample-project/`.

This directory is a **fictional sample project** demonstrating what a project looks like after running scaffold-onboard v0.2's three new contracts end-to-end:

- **R1** — Phase → Sprint → Vertical Slice hierarchy in `ROADMAP.md` (authored via `/plan-roadmap`)
- **R2** — machine-checkable rules in `.claude/memory-bank/03-code-patterns.md` (authored via the `authoring-machine-checkable-rules` skill)
- **R3** — `auto:` / `user:` demo criteria per vertical slice in `ROADMAP.md` (authored via the `authoring-vertical-slice-demo` skill, or inline during R1.C)

The fictional project is **`todo-cli`** — a single-user terminal todo manager with SQLite storage, tag filters, and a recurring-task scheduler. Deliberately small (one CLI, one local datastore, four phases) so a reader can absorb the full shape in 5-10 minutes.

## Files in this sample

| File | Demonstrates |
|---|---|
| `MASTER-SPEC.md` | Illustrative MASTER-SPEC structure — **NOT** intended to pass `sf_spec_validate` (no phase-marker HTML comments, abbreviated 10-phase content). Reads as prose for human absorption of project shape. See note below. |
| `ROADMAP.md` | **R1** — 4 phases × 2 sprints × 2-3 slices ≈ 20 slices. **R3** — each slice carries 2 demo criteria mixing `auto:` and `user:` forms with the literal U+2192 (→) arrow. |
| `.claude/memory-bank/03-code-patterns.md` | **R2** — `## Machine-checkable rules` section with 4 HTML-sentinel `<!-- mcrule:start -->` blocks demonstrating all 4 v0.2 rule types (`banned_imports`, `coverage_floor`, `style_invariants`, `required_pattern`). |
| `README.md` | This file. |

## Note on MASTER-SPEC.md validity

The `MASTER-SPEC.md` in this directory is **illustrative**, not validatable. A real MASTER-SPEC authored by `/onboard` carries:

- `<!-- master-spec:phase id=N name=<slug> -->` HTML comments for all 10 phases (required by `sf_spec_validate` per `lib/parser.sh:96-116`)
- A `**Project class:**` line with one of the 9 enum values
- A `**Spec version:** 1.0` line

This sample's MASTER-SPEC.md is a condensed narrative — useful as a reading aid for what *shape* of project drives the ROADMAP.md content — but is intentionally **not** a working input to `sf_spec_validate`. To produce a real MASTER-SPEC, run `/onboard` against a real project.

## How a reader should use this sample

1. **Start with `MASTER-SPEC.md`** — understand the fictional project's vision and shape (~2 minutes).
2. **Skim `ROADMAP.md`** — see how Phase → Sprint → Vertical Slice cascades. Note the `## Demo criteria` blocks under each slice (R1 + R3) (~3 minutes).
3. **Read `.claude/memory-bank/03-code-patterns.md`** — see how four real rules encode as HTML-sentinel `mcrule` blocks (R2) (~2 minutes).
4. **Cross-reference with the skill docs** — `scaffold-onboard/skills/planning-project-roadmap/SKILL.md` (R1), `scaffold-onboard/skills/authoring-machine-checkable-rules/SKILL.md` (R2), `scaffold-onboard/skills/authoring-vertical-slice-demo/SKILL.md` (R3).

For a fuller-scale example (4 phases × 3 sprints × ~30 slices, PipelinePulse fictional product), see `scaffold-onboard/skills/planning-project-roadmap/references/example-hierarchy.md`.
