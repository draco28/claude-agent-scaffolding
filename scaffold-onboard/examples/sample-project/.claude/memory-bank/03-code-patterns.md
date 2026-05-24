# 03 — Code Patterns

> Conventions, idioms, and machine-checkable rules for `todo-cli`. The `## Machine-checkable rules` section below is enforced by scaffold-dev v0.1+'s `implementation-checking` skill on every slice close.

## Conventions

- Module layout: `src/<area>/<file>.rs` where area is one of `storage`, `cli`, `digest`, `recur`.
- Error handling: `anyhow::Result` at the CLI boundary, `thiserror`-derived enums for library-internal errors.
- Time handling: `chrono::Utc` everywhere; user-facing strings convert to local timezone only at the render boundary.
- SQLite: single connection per command (no pool); use `?` parameter binding always — never string-format SQL.

---

## Machine-checkable rules

The blocks below are **HTML-sentinel `mcrule` blocks** consumed by scaffold-dev's `implementation-checking` skill. The HTML-sentinel format is REQUIRED — fenced code blocks (` ```mcrule `) are explicitly rejected per scaffold-onboard SPEC §8.4 because fence boundaries are invisible to Claude in rendered markdown. Author new rules via `Skill(scaffold-onboard:authoring-machine-checkable-rules)` to ensure the grammar is right.

### Rule 1: No raw-string SQL anywhere

We forbid the `format!` and `concat!` macros inside SQL-handling code because string-built SQL is the canonical pathway to injection. Always use `?`-parameter binding via `rusqlite`.

<!-- mcrule:start type=banned_imports -->
in: src/storage/**/*.rs
where: any_function_marked_async
forbid: [format!, concat!]
<!-- mcrule:end -->

### Rule 2: Storage layer coverage floor

The SQLite layer is where bugs hide. We hold `src/storage/` to a 70% coverage floor (per Phase 4.1 of the MASTER-SPEC).

<!-- mcrule:start type=coverage_floor -->
paths: [src/storage/]
threshold: 70
<!-- mcrule:end -->

### Rule 3: No `println!` outside `src/cli/` or tests

User-facing output flows through `src/cli/render.rs`. `println!` calls anywhere else indicate a leak of presentation concerns into business logic.

<!-- mcrule:start type=style_invariants -->
in: src/**/*.rs
exclude: src/cli/**/*.rs
where: outside_tests
forbid_pattern: \bprintln!\(
<!-- mcrule:end -->

### Rule 4: Every public CLI subcommand needs a doc comment

Every `pub fn` in `src/cli/commands/` must carry a `///` doc comment — this feeds the `--help` output via `clap` derive macros.

<!-- mcrule:start type=required_pattern -->
in: src/cli/commands/**/*.rs
where: pub_fn
require_pattern: ^///\s+\w
<!-- mcrule:end -->

---

## Notes for future rules

When v0.3 adds new rule types (e.g., `cyclomatic_complexity`, `module_boundary`), scaffold-onboard's `authoring-machine-checkable-rules` skill will surface them. Until then, unknown types in this file warn-and-skip per SPEC §8.5 — they do not block evaluation of the rules above.

For rule authoring help: invoke `Skill(scaffold-onboard:authoring-machine-checkable-rules)` conversationally or via the description trigger (e.g., "add a project rule that forbids X in Y").
