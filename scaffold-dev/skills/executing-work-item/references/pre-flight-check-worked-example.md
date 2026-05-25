# Pre-flight check worked example — work-3.2.01

The implementer-agent subagent's FIRST turn is always a pre-flight check (SPEC §6.2). This reference walks through a complete pre-flight that detects gaps and returns in `gaps-surfaced` mode.

## Subagent input (from orchestrator Task tool prompt)

```
Read handoff at /Users/draco/projects/insight-platform-ai/docs/specs/sprint-3/VS-3.2-insights-action-needed-card/work-3.2.01-backend-query-endpoint/handoff.md and execute the work item per its instructions.

Your worktree: /Users/draco/projects/insight-platform/.worktrees/work-3.2.01-backend-query-endpoint
Use this path for all git operations and file edits in canonical.

First turn must be PRE-FLIGHT CHECK: ...
```

## Step 1 — Read handoff end-to-end

Subagent reads handoff at the given path. The handoff (per SPEC §10) contains:
- Section 1: How to use this handoff
- Section 2: Vertical slice context
- Section 3: Work item identifiers (incl. worktree absolute path)
- Section 4: Pre-flight calibration questions
- Section 5: What's already merged
- Section 6: Memory bank pointers
- Section 7: ACs embedded
- Section 8: Verification commands embedded
- Section 9: Constraints (git_policy + STAGE-not-commit + return format)
- Section 10: Report template

Subagent ALSO reads the linked spec at `work-3.2.01-backend-query-endpoint/spec.md` for full Wabash Format B content.

## Step 2 — Verify worktree state

```bash
git -C /Users/draco/projects/insight-platform/.worktrees/work-3.2.01-backend-query-endpoint status --porcelain
```

Expected: empty output (clean worktree). Subagent confirms.

```bash
git -C /Users/draco/projects/insight-platform/.worktrees/work-3.2.01-backend-query-endpoint branch --show-current
```

Expected: `work/3.2.01-backend-query-endpoint` (per `during_dev.branch_naming` template). Subagent confirms.

## Step 3 — Read memory-bank pointers

Handoff section 6 names:
- `.claude/memory-bank/02-system-patterns.md` (system patterns — DB access conventions)
- `.claude/memory-bank/03-code-patterns.md` (machine-checkable rules; relevant rule: `banned_imports: type=sqlalchemy.orm.Session in db/queries/*.py — use the project's typed Session wrapper`)

Subagent reads both files. Notes the banned-imports rule applies to the work item's target file (`db/insights.py`).

## Step 4 — Identify ambiguity

Subagent walks ACs in spec section 5:

- **AC-1:** "`select_action_needed_for_user(user_id: UUID) -> list[ActionNeededRow]` exists in `db/insights.py` and returns rows from the action_needed table filtered by user_id." -> Clear.
- **AC-2:** "FastAPI endpoint `GET /api/insights/action-needed` wraps the query and returns JSON." -> Clear path + method.
- **AC-3:** "Endpoint is authenticated; unauthenticated requests return 401." -> Authentication mechanism unspecified.
- **AC-4:** "Endpoint returns 200 with `[]` when no rows exist for the user." -> Clear.
- **AC-5:** "Integration test in `tests/integration/test_insights_endpoint.py` covers AC-1..AC-4." -> Clear.

**AC-3 has a gap.** The spec says "authenticated" but doesn't say WHICH auth mechanism. Memory bank `02-system-patterns.md` doesn't pin this — patterns covered are DB-layer conventions, not API auth. Memory bank `04-tech-context.md` mentions both session-cookie auth (for web routes) and bearer-token auth (for API routes) exist in the codebase.

The subagent CANNOT decide which auth applies without orchestrator/user input. This is a blocking ambiguity.

## Step 5 — Return gaps-surfaced

Subagent EXITS pre-flight without doing work. Return value:

```json
{
  "mode": "gaps-surfaced",
  "gaps": [
    {
      "section": "spec §5 AC-3",
      "question": "AC-3 says endpoint is authenticated; unauthenticated returns 401. Which auth mechanism — session cookie (web pattern) or bearer token (API pattern)? Both exist in the codebase per memory-bank/04-tech-context.md.",
      "severity": "blocking"
    }
  ]
}
```

## What the subagent does NOT do at gaps-surfaced

- Does NOT make any file edits.
- Does NOT run any tests.
- Does NOT stage or commit anything.
- Does NOT author report.md.
- Does NOT attempt to guess the answer to the gap.

## Orchestrator handling (SPEC §6.3 multi-call protocol)

Orchestrator receives the gaps-surfaced response. It:
1. Surfaces the gap to the user in conversation.
2. User clarifies: "Bearer token auth — same pattern as other /api/ routes. Add to spec."
3. Orchestrator amends `handoff.md` — appends:
   ```
   ## Clarifications

   ### From orchestrator session at <timestamp>
   - AC-3 auth mechanism: bearer token (matches existing /api/ pattern). Validate via the `verify_bearer_token` dependency in `api/auth.py`. Return 401 with `{"detail": "unauthorized"}` body on failure.
   ```
4. Orchestrator re-invokes the subagent with the SAME handoff path (Task tool, same prompt).
5. Subagent's new pre-flight reads the appended Clarifications section, finds AC-3 fully specified, and proceeds to TDD loop (see `tdd-loop-per-ac-example.md`).

## Pre-flight pass example (alternate path)

If the spec had pinned auth in section 3 ("Decisions baked in: bearer-token auth via api/auth.py:verify_bearer_token"), pre-flight would pass on first turn. Subagent proceeds directly to the TDD loop. Pre-flight does NOT return a separate `mode: pre-flight-passed` message — it just continues into work and returns at the end with `mode: complete`.

## Common pre-flight gap patterns

- **Undefined contract.** "Return JSON" but no shape; "authenticate" but no mechanism; "handle errors" but no error format.
- **Conflicting deps.** "Use the typed Session wrapper" in spec but file imports raw `sqlalchemy.orm.Session` — banned-imports rule conflict surfaced.
- **Stale worktree.** Worktree branch was advanced by an earlier failed run; commits exist that the orchestrator doesn't know about.
- **Missing referenced files.** Spec references `tests/integration/test_insights_endpoint.py` as the test file, but the parent directory `tests/integration/` doesn't exist yet — need clarity on whether the subagent should create it.

Each surfaces as a separate gap entry in the return array.
