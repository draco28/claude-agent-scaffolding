# Complete-mode return example — work-3.2.01

Concrete shape of the implementer-agent subagent's `complete` return (SPEC §6.2 + §6.3) PLUS the report.md that the orchestrator reads from disk.

## When this fires

After:
- Pre-flight passed (no gaps)
- TDD loop completed for all ACs (see `tdd-loop-per-ac-example.md`)
- All verification commands ran green
- report.md authored
- Changes staged (`git add -A`); NOT committed

## Return shape

```json
{
  "mode": "complete",
  "report_path": "/Users/draco/projects/insight-platform-ai/docs/specs/sprint-3/VS-3.2-insights-action-needed-card/work-3.2.01-backend-query-endpoint/report.md",
  "summary": "Backend query layer + GET /api/insights/action-needed endpoint implemented with bearer-token auth; 4 tests passing; no regressions.",
  "stage_status": "all_staged"
}
```

## Field semantics

- **mode** — exactly `"complete"`. No variants.
- **report_path** — ABSOLUTE path to report.md (written by subagent to the path specified in handoff section 10). Orchestrator reads this file off disk; it's NOT in the return payload to avoid token bloat.
- **summary** — one-line summary, max ~120 chars. Used by orchestrator for the implementation-checking skill's intake banner and for the slice README work-items-table status cell.
- **stage_status** — one of:
  - `"all_staged"` — `git status --porcelain` shows ALL modified/added files staged (no unstaged content).
  - `"partial"` — some files staged, some unstaged. Subagent surfaces in report.md why (typically: a file was modified during refactor but the change was reverted; staging it would be incorrect).
  - `"none"` — nothing staged. Either no files were modified (work-item was a no-op?) or staging failed. Subagent must surface in report.md.

If `stage_status != "all_staged"`, orchestrator inspects report.md for the reason before deciding whether to override-stage and commit, or re-invoke the subagent to clean up.

## report.md template (9 sections per SPEC §10)

The report file the subagent writes to disk:

```markdown
# Implementation report — work-3.2.01

## 1. Work item

- ID: work-3.2.01
- Slice: VS-3.2 (insights-action-needed-card)
- Round: R1
- Worktree: /Users/draco/projects/insight-platform/.worktrees/work-3.2.01-backend-query-endpoint
- Branch: work/3.2.01-backend-query-endpoint

## 2. Summary

Implemented `select_action_needed_for_user(user_id)` in `db/insights.py` and wrapped it in
`GET /api/insights/action-needed` with bearer-token auth and empty-result handling. Added
unit + integration test coverage for AC-1 through AC-5. No regressions in pre-existing suite.

## 3. ACs — verification status

| AC | Status | Evidence |
|---|---|---|
| AC-1 | passed | `pytest tests/unit/test_insights.py::test_select_action_needed_returns_rows_for_user` -> 1 passed |
| AC-2 | passed | `pytest tests/integration/test_insights_endpoint.py::test_get_action_needed_returns_200_with_rows` -> 1 passed |
| AC-3 | passed | `pytest tests/integration/test_insights_endpoint.py::test_get_action_needed_returns_401_without_auth` -> 1 passed |
| AC-4 | passed | `pytest tests/integration/test_insights_endpoint.py::test_get_action_needed_returns_empty_for_user_with_no_rows` -> 1 passed |
| AC-5 | passed | `pytest tests/integration/test_insights_endpoint.py -v` -> 3 passed (test file exists; covers AC-1..AC-4 via endpoint contract) |

## 4. Files changed

- `db/insights.py` (modified; +28 lines, -0 lines)
- `api/routes/insights.py` (added; 14 lines)
- `tests/unit/test_insights.py` (added; 18 lines)
- `tests/integration/test_insights_endpoint.py` (added; 41 lines)

Total: 1 modified, 3 added; +101 / -0.

## 5. Verification commands run

```bash
pytest tests/unit/test_insights.py -v        # 1 passed
pytest tests/integration/test_insights_endpoint.py -v  # 3 passed
pytest                                       # 47 passed (0 regressions)
ruff check db/insights.py api/routes/insights.py       # no findings
```

mypy was specified in handoff section 8 but the project's mypy config was absent.
Per handoff Clarification 2026-05-22T14:11Z: skip mypy verification for this work item;
add backlog entry to introduce mypy config in a future tech-debt slice.

## 6. Decisions during execution

- **Bearer-token auth via `verify_bearer_token` dependency** (per handoff Clarifications; matches existing /api/ pattern).
- **Response shape: flat list of objects** (per handoff Clarifications; no envelope wrapper).
- **Dataclass for `ActionNeededRow`** vs. Pydantic model: chose dataclass because the row is internal to db/insights.py; api/routes/insights.py serializes via `__dict__`. If consumers need Pydantic validation, that's a future-slice concern.

## 7. Deviations from spec

None.

## 8. Suggestions for memory bank

- **02-system-patterns.md** — add note: "API routes that wrap a query function use `Depends(verify_bearer_token)` pattern; query function takes user_id (extracted from token) as its first argument." (Codifies a pattern visible across this slice + existing /api/ routes.)
- **04-tech-context.md** — note that mypy is NOT currently configured; mention the backlog item for introducing it.

## 9. Notes for orchestrator

- `stage_status = all_staged`. Ready to commit.
- No merge conflicts anticipated (no overlapping files with parallel work-3.2.02 in R1).
- If implementation-checking finds AC-3 verification weak (the test relies on the existing `verify_bearer_token` dependency rather than testing the dependency's logic itself), consider whether to: (a) accept (the dependency has its own unit tests elsewhere), (b) add a redundant assertion, or (c) flag for follow-up. My recommendation: (a) accept.
```

## What orchestrator does on `mode: complete`

Per SPEC §6.3 + §13 round-close flow:

1. Read report.md from disk at `report_path`.
2. Run `scaffold-dev:implementation-checking` skill on this work item.
   - AC verification (compare report's AC table claims against actual test output).
   - Report cross-check (does the report match files-changed actually staged?).
   - Project rule checks (R2 mcrules from memory-bank/03-code-patterns.md).
3. If implementation-checking passes -> commit in worktree per `git_policy` (typically a single commit with the report's summary as the message subject).
4. Merge work-item branch into canonical main.
5. Update slice README: work-3.2.01 status -> complete.
6. Move to next work item in the round (per declared decomposition order, NOT subagent return order).

If implementation-checking fails -> invoke failure-response menu §12.2.

## What the report MUST NOT do

- Don't omit AC-status table. If an AC is deferred or partial, name it explicitly with severity. Implementation-checking will halt on missing ACs.
- Don't conflate sections. Decisions during execution (§6) is for in-band judgement calls; deviations from spec (§7) is for spec divergence. Different review consequences.
- Don't promise more than was done. The summary, AC table, and files-changed list are cross-checked. Inflation here is the #1 root cause of report-cross-check failures.
