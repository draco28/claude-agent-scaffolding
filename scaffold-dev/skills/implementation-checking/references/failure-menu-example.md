# Failure response menu worked example — implementation-checking

The implementation-checking skill (SPEC §12) gates each work item with AC verification + report cross-check + project rule checks. On failure, it surfaces the menu in SPEC §12.2. This walks through each row with concrete examples.

## Setup

Work item: work-3.2.01. Subagent returned `mode: complete`; report.md exists; orchestrator invoked `implementation-checking` skill. The skill runs its three checks.

## Row 1 — AC verification fail

**Scenario:** Skill body re-runs the AC-3 test (auth: 401 on unauthenticated). Expected: pass. Actual: the test file references `client` (unauthenticated client fixture) but the fixture wasn't defined in `conftest.py` — pytest fails with `fixture 'client' not found`.

**Skill body surfaces:**

```
AC-3 verification FAILED.

Test:    tests/integration/test_insights_endpoint.py::test_get_action_needed_returns_401_without_auth
Error:   fixture 'client' not found (conftest.py defines `authed_client` but not `client`)

The report claims AC-3 passed, but the underlying test fixture is missing.

Menu:
  1. Re-spawn implementer-agent subagent with a fix-up handoff
     (append `## Fix-up iteration 1` to existing handoff.md describing the missing fixture)
  2. Accept partial-with-deferred (mark AC-3 as deferred; create backlog item)
  3. Replan work item (return to spec authoring; reset handoff)

Choose: 1 / 2 / 3
```

**Likely user choice:** 1. The fix is small (add `client` fixture to conftest.py) and well-scoped.

**Orchestrator action on choice 1:**
- Appends to `work-3.2.01-*/handoff.md`:
  ```markdown
  ## Fix-up iteration 1

  AC-3 verification failed: `tests/integration/test_insights_endpoint.py::test_get_action_needed_returns_401_without_auth` references fixture `client` that is not defined in `conftest.py`.

  Fix: define an unauthenticated `client` fixture in `tests/conftest.py` (parallel to existing `authed_client`). Re-run AC-3 verification. Re-author the relevant report sections.

  Other ACs should remain green; re-run full verification suite to confirm no regressions from the fix.
  ```
- Re-invokes Task tool with same handoff path.
- Subagent's pre-flight reads the fix-up section, fixes, re-runs, re-authors report.
- Subagent returns `mode: complete` again.
- Skill body re-runs implementation-checking. If clean -> proceed to commit + merge.

## Row 2 — Report cross-check mismatch

**Scenario:** Report's "Files changed" section lists `db/insights.py` modified +28 / -0. Actual `git diff --stat`: shows `db/insights.py` modified +35 / -2. The numbers don't match — the report inflated; specifically, the subagent included a small refactor (renaming an internal helper) that the report didn't mention.

**Skill body surfaces:**

```
Report cross-check MISMATCH.

Report claims: db/insights.py +28 / -0
Actual diff:   db/insights.py +35 / -2

Likely cause: the subagent made an unmentioned refactor (a helper rename, perhaps). The
report is technically inaccurate. Whether the refactor itself is acceptable depends on
your judgement.

Menu:
  1. Re-spawn (report likely inaccurate; have subagent re-author)
  2. Interrogate via subagent (re-invoke with prompt: "re-verify AC and re-author report.md;
     explain the 7 extra lines in db/insights.py")
  3. Override (treat as AC fail; apply AC-fail menu)

Choose: 1 / 2 / 3
```

**Likely user choice:** 2. The work likely landed correctly; the report just lost a detail. Interrogating is cheaper than re-spawning.

**Orchestrator action on choice 2:**
- Re-invokes Task tool with prompt: "Read your prior report.md; re-verify AC-1 through AC-5 against actual code in worktree; re-author report.md noting any prior omissions. Specifically explain the +7/-2 delta in db/insights.py vs. what the prior report claimed."
- Subagent returns updated report. Skill body re-runs cross-check.

## Row 3 — Project rule check fail

**Scenario:** Memory-bank `03-code-patterns.md` has an mcrule:

```html
<!-- mcrule:start type=banned_imports -->
banned_imports: type=sqlalchemy.orm.Session in db/queries/*.py -- use the project's typed Session wrapper from db/session.py
<!-- mcrule:end -->
```

Skill body checks `db/insights.py` (which is NOT in `db/queries/*.py` — it's in `db/insights.py`). Rule does not apply. Check passes.

But suppose the report also touched `db/queries/users.py` (it didn't here, but hypothetically). If that file had `from sqlalchemy.orm import Session` -> rule violation.

**Skill body surfaces (hypothetical):**

```
Project rule check FAILED.

Rule:      banned_imports: type=sqlalchemy.orm.Session in db/queries/*.py
Violation: db/queries/users.py:3 imports `sqlalchemy.orm.Session` directly
Hint:      Use `from db.session import Session` (the typed wrapper) instead.

Menu:
  1. Re-spawn with rule context in fix-up handoff
  2. Accept-with-deferred TODO (the violating import becomes a backlog item)
  3. Replan if rule is fundamental (rare; only when the rule contradicts the work-item spec)

Choose: 1 / 2 / 3
```

## Row 4 — Merge conflict

**Scenario:** Implementation-checking passed all 3 checks. Skill body proceeds to merge `work/3.2.01-backend-query-endpoint` -> `main`. The merge fails because work-3.2.02 (also in R1) already merged with conflicting changes to `api/__init__.py` (router registration line).

**Skill body surfaces:**

```
Merge conflict on `main` <- work/3.2.01-backend-query-endpoint.

Conflicting file: api/__init__.py (router registration block)

Menu:
  1. User resolves manually
     (you resolve in the worktree; `git -C <worktree> merge --continue` resumes orchestrator)
  2. Abort merge (`git merge --abort`; replan integration — likely a small refactor needed)

Choose: 1 / 2
```

**Likely user choice:** 1 for trivial conflicts; 2 if the conflict signals a deeper issue (e.g., the two parallel work items in R1 shouldn't have been parallel after all).

## Row 5 — Subagent crash / timeout / malformed return

**Scenario:** The subagent's return is malformed JSON — missing the closing brace, or `mode` field absent.

**Skill body surfaces:**

```
Subagent return malformed.

Received:
  {"report_path": "/Users/draco/.../report.md", "summary": "...", "stage_status": "all_staged"
  (no closing brace; no `mode` field)

Menu:
  1. Re-invoke (transient failure; many tool/transport issues self-resolve on retry)
  2. Extend timeout + re-invoke (if return suggests subagent was working but ran out of budget)
  3. Fall back to manual implementer session per SPEC §6.4
     (user opens fresh Claude session with handoff.md path as prompt)
  4. Abandon work item (mark cancelled; remove from slice plan; surface to user)

Choose: 1 / 2 / 3 / 4
```

**Likely user choice:** 1 first (transient is most common). If 2 retries fail -> 3 (manual fallback). 4 only when the work item is fundamentally infeasible.

## What implementation-checking does NOT do

- Does not commit. That's the orchestrator's job after this skill passes.
- Does not modify report.md. Re-authoring is the subagent's job on re-invoke.
- Does not advance the slice. It's strictly per-work-item; failed work item halts the round; orchestrator decides how to proceed via the menu.
- Does not run grill-me or architect-critic. Those are spec-time gates, not verification-time.

## v0.1 mcrule fallback

If memory-bank `03-code-patterns.md` has no machine-checkable rules (the R2 section is empty), skill body falls back to AC-only + report cross-check. The rule check step is skipped silently (no error). Project rules are an upstream contract from scaffold-onboard v0.2; absence is degraded operation, not failure.
