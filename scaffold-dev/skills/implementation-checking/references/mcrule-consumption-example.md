# mcrule consumption worked example — implementation-checking

How implementation-checking consumes the machine-checkable rules (R2) authored in `.claude/memory-bank/03-code-patterns.md`. The mcrule DSL is owned by scaffold-onboard v0.2's `authoring-machine-checkable-rules` skill; scaffold-dev is purely a consumer.

## The four v0.2 mcrule types

Per scaffold-onboard v0.2 §8.5:

1. **banned_imports** — forbid specific imports in specific path globs.
2. **coverage_floor** — minimum coverage % for a path glob.
3. **style_invariants** — regex-based style assertions (lint-adjacent).
4. **required_pattern** — files matching a glob must contain a regex match (positive form).

Each rule lives in a `<!-- mcrule:start type=<T> -->` ... `<!-- mcrule:end -->` block in `03-code-patterns.md`. v0.2 grammar is documented in scaffold-onboard v0.2 SPEC §8.5; scaffold-dev does NOT re-implement parsing.

## Example mcrule blocks

```markdown
## Machine-checkable rules

<!-- mcrule:start type=banned_imports -->
banned_imports: type=sqlalchemy.orm.Session in db/queries/*.py -- use the project's typed Session wrapper from db/session.py
<!-- mcrule:end -->

<!-- mcrule:start type=coverage_floor -->
coverage_floor: 80% in db/**/*.py
<!-- mcrule:end -->

<!-- mcrule:start type=style_invariants -->
style_invariants: regex=^from typing import \* must NOT match any file
<!-- mcrule:end -->

<!-- mcrule:start type=required_pattern -->
required_pattern: api/routes/*.py must contain `Depends(verify_bearer_token)`
<!-- mcrule:end -->
```

(Above shapes are illustrative — exact grammar is owned by scaffold-onboard v0.2.)

## Consumption flow

The implementation-checking skill body, on each invocation:

1. **Locate** `.claude/memory-bank/03-code-patterns.md` via manifest (`mi_manifest_resolve` for `memory_bank_path`).
2. **Parse** all `<!-- mcrule:start type=<T> -->...<!-- mcrule:end -->` blocks. Use scaffold-onboard v0.2's `sf_rules_parse` helper (lazy load from cache). If scaffold-onboard not present -> skip rule check entirely (degraded operation, v0.1 fallback).
3. **For each rule, identify applicable files** in the work item's diff:
   - `git -C <worktree> diff --name-only main..HEAD` -> list of changed files.
   - Filter by rule's glob (e.g., `db/queries/*.py` matches none of work-3.2.01's changed files since work-3.2.01 modified `db/insights.py` not `db/queries/*`).
4. **For applicable rules, run the check:**

### banned_imports check

For each changed file matching the rule's glob:
```bash
grep -nE '^(from|import) sqlalchemy\.orm.*\bSession\b' <file>
```
If any match -> rule violation. Surface file + line + import.

### coverage_floor check

Run coverage on the changed glob:
```bash
cd <worktree> && pytest --cov=db --cov-report=term-missing
```
Parse coverage % from output. If below floor -> rule violation. Surface % + floor.

### style_invariants check

For each style rule, grep across the work item's diff for the regex. If `must NOT match` form -> any match is violation. If `must match` form -> any miss is violation.

### required_pattern check

For each changed file matching the glob:
```bash
grep -q 'Depends(verify_bearer_token)' <file> || echo VIOLATION
```
If any match -> ok. If no match in a file that should have one -> violation.

5. **Collate violations.** If any rules failed -> surface failure-response menu row "Project rule check fail" (per SPEC §12.2).

## Worked check on work-3.2.01

Work-3.2.01's changed files:
- `db/insights.py` (modified)
- `api/routes/insights.py` (added)
- `tests/unit/test_insights.py` (added)
- `tests/integration/test_insights_endpoint.py` (added)

Run each rule:

| Rule | Glob | Files in scope | Result |
|---|---|---|---|
| banned_imports sqlalchemy.orm.Session | `db/queries/*.py` | none (no files in db/queries/) | n/a — skip |
| coverage_floor 80% | `db/**/*.py` | `db/insights.py` | run coverage: 92% -> pass |
| style_invariants `from typing import *` | (no glob; project-wide) | all 4 files | grep across all 4 -> 0 matches -> pass |
| required_pattern `Depends(verify_bearer_token)` | `api/routes/*.py` | `api/routes/insights.py` | grep -> matches at line 9 -> pass |

All applicable rules pass. Skill body proceeds with AC verification + report cross-check (the other two checks). Net result: implementation-checking passes work-3.2.01.

## What happens on a violation

Suppose `api/routes/insights.py` had NO `Depends(verify_bearer_token)`. The required_pattern rule would flag it. Surfaced as:

```
Project rule check FAILED.

Rule:      required_pattern: api/routes/*.py must contain `Depends(verify_bearer_token)`
Violation: api/routes/insights.py does NOT contain `Depends(verify_bearer_token)`

This rule exists because all API routes must be authenticated by default. See
memory-bank/02-system-patterns.md "API auth conventions" for the rationale.

Menu (from §12.2 row "Project rule check fail"):
  1. Re-spawn with rule context in fix-up handoff
  2. Accept-with-deferred TODO
  3. Replan if rule is fundamental
```

## Forward-compat: unknown rule types

Per scaffold-onboard v0.2 §8.5 extensibility contract: if `03-code-patterns.md` contains a rule with `type=` value scaffold-dev doesn't recognize (e.g., a v0.3 rule type that didn't exist when scaffold-dev was written), the skill body MUST warn-and-skip:

```
mcrule type='foo_bar' unrecognized — skipping. (This is forward-compat behavior; the rule
file is not corrupt. If 'foo_bar' is expected to be checked, upgrade scaffold-dev or
remove the rule.)
```

Never crash on unknown types. Never silently ignore (the warning is the user-visible signal).

## v0.1 degraded mode

If scaffold-onboard's `sf_rules_parse` helper is not available (scaffold-onboard not installed OR an older version without the v0.2 R2 layer):
- implementation-checking skips ALL rule checks entirely.
- Surfaces (once per session, not per work item) a soft warning: "Project rule checks skipped — scaffold-onboard v0.2 with R2 rules not detected."
- AC verification + report cross-check still run normally.

This is the v0.1 fallback path from SPEC §12.1: "v0.1 falls back to AC-only if rules absent."

## Composition note

scaffold-dev does NOT redefine the mcrule DSL. The grammar, parser, and the four current types are owned by scaffold-onboard v0.2's `authoring-machine-checkable-rules` skill. When scaffold-dev v0.2+ ships, additional rule types may be added in scaffold-onboard; scaffold-dev's consumption layer needs only to:
1. Recognize the new `type=<T>` value.
2. Implement the check logic for `<T>`.
3. Keep the warn-and-skip fallback for unknown types intact.
