# Rubric: adopt-multi-repo

Score each 1-5 (4 criteria). Pass = all ≥4. `expected_outcome` vocabulary:
`halt` | `proceed` (every declared repo and the AI workspace are clean and on
their default branch, so A3-A5 raise nothing and adoption continues).

**Every criterion is scored on every fixture.** A fixture that halts on one
gate is still scored on the other three — a criterion whose own condition
never fires on that fixture scores whether the skill correctly stayed silent
about it, the same convention `start-topology-authoring` uses. There is no N/A.

1. **Full per-repo + workspace cleanliness sweep** — A3's `git status
   --porcelain` check runs against **every** repo declared in the topology
   **and** the AI workspace, not canonical alone. A dirty line in any one of
   them halts adoption, naming the legacy stack's slice close as the remedy.
   Stopping the sweep once canonical (or canonical + the AI workspace) comes
   back clean, and never reaching a second or third declared repo, is a wrong
   answer here even when it happens to land on the right verdict for the
   fixture in front of it.
2. **Full per-repo default-branch check** — every declared repo, not
   canonical alone, must be on its own default branch. A repo parked on a
   feature branch halts adoption and is named, even when its working tree is
   otherwise clean and every other repo is on its default branch.
3. **Baseline recorded as a table, not one SHA** — once A1-A5 all pass, the
   baseline is `git rev-parse HEAD` run once **per declared repo**, and the
   adoption record cites the resulting table. Treating one repo's HEAD (or an
   arbitrarily chosen one) as *the* baseline for the whole product, or
   recording only canonical's SHA, is a wrong answer.
4. **C3 aggregated across every repo's ADR directory** — bones are
   back-derived by scanning `docs/adr/` in **every** declared repo and
   aggregating the result, not canonical's directory alone. An ADR that
   exists only in a non-canonical repo still mints its own bones-registry
   entry; two ADRs from two different repos sharing the same number (each
   repo keeps its own ADR sequence) are two entries, never collapsed into one
   as a duplicate.

## Output format
`{"scores":{"full_cleanliness_sweep":N,"full_branch_check":N,"baseline_table":N,"aggregated_c3":N},"pass":true|false,"notes":"<one sentence>"}`. Pass = all ≥4. JSON only.
