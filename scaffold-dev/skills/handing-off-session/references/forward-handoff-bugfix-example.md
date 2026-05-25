# Forward handoff — mid-slice bug-fix detour (worked example)

A complete worked example of a forward handoff for the mid-slice bug-fix use case (SPEC §6b.2 row 4). User is mid-VS-3.2 and discovers a pre-existing auth bug that's blocking the slice's work-3.2.03 dashboard integration. They invoke `/handoff --scope mid-slice --purpose bugfix-auth` to fork the bug-fix to a separate session.

## Resulting handoff file

Path: `<ai-workspace>/.workspace/handoffs/vs-3.2-bugfix-auth-a1b2.md`

```markdown
# Handoff — vs-3.2-bugfix-auth

## 1. Header

- Type: forward
- Scope: mid-slice (VS-3.2 in sprint-3)
- Purpose: bug-fix detour for auth-cookie expiry mishandling discovered during work-3.2.03 integration testing
- Source session metadata:
  - Author: orchestrator session running VS-3.2 planning
  - Authored at: 2026-05-25T11:42Z
  - Source session context-budget usage at authoring time: ~28% (handoff invoked by judgment, not threshold)
  - Short-id: a1b2

## 2. Purpose

While integrating the action-needed card on the dashboard (work-3.2.03), I discovered that
the `verify_bearer_token` dependency at `api/auth.py:34` silently returns None for expired
tokens instead of raising 401. The dashboard never sees the auth failure — it just gets
empty results — which masks the real failure mode AND breaks AC-3 for work-3.2.01 retroactively.

This is out-of-slice (the bug exists in pre-merged code, predates VS-3.2). Forking to a
separate session so the bug-fix can land cleanly without blocking VS-3.2's main thread.

## 3. State pointers

- AI workspace: `/Users/draco/projects/insight-platform-ai`
- Canonical: `/Users/draco/projects/insight-platform`
- Active sprint: sprint-3
- Active slice: VS-3.2 (paused mid-round-2; work-3.2.03 and work-3.2.04 dispatched but VS now waiting on this bug-fix)
- Worktree for bug-fix: NEW — create at `/Users/draco/projects/insight-platform/.worktrees/bugfix-auth-token-expiry`
- Branch for bug-fix: `bugfix/auth-token-expiry` off canonical main HEAD at handoff time (commit sha `f3a7c81`)

## 4. What's NOT in memory bank yet

- The bug was discovered via an oddity in the integration test transcript: AC-3 test passed,
  but only because the test token was fresh. With an expired token, the endpoint returns 200
  with `[]` (looks like "no rows" indistinguishable from a true empty result). This negative-space
  observation is NOT codified anywhere yet.
- We tried setting the token expiry to 1 second and re-running — confirmed the 200-with-empty path.
- Considered hot-patching in the work-3.2.01 worktree but rejected: the patch needs to land on
  canonical main BEFORE work-3.2.01 merges, otherwise the AC-3 test will be retroactively wrong.
- A related concern (NOT addressed in this bug-fix): the frontend has no way to detect "auth
  expired" vs. "genuinely no data." That UX gap is its own work — backlog candidate, not this fix.

## 5. Workflow deviations

None. Standard mid-slice detour pattern.

## 6. In-flight state

- work-3.2.03 subagent: NOT dispatched yet (was about to be when bug was found).
- work-3.2.04 subagent: NOT dispatched yet.
- work-3.2.01, work-3.2.02: merged to canonical at `f3a7c81`.
- No partial commits anywhere.

## 7. Must read before doing anything

- `api/auth.py` — full file (~80 lines)
- `tests/integration/test_auth.py` — existing auth tests
- `.claude/memory-bank/02-system-patterns.md` lines 110-140 — API auth conventions section
- This handoff file (start here)

## 8. Next intended action(s)

Primary (ranked):
1. Create worktree at `/Users/draco/projects/insight-platform/.worktrees/bugfix-auth-token-expiry` off `main`.
2. Add failing test in `tests/integration/test_auth.py` reproducing: expired token -> endpoint returns 401, not 200.
3. Fix `verify_bearer_token`: raise `HTTPException(status_code=401, detail="token expired")` instead of returning None on `ExpiredSignatureError`.
4. Verify all existing auth tests still pass.
5. Commit + push branch (manual session, NOT subagent — implementer-agent doesn't have commit cap).
6. Open canonical PR (or merge directly per git_policy) before resuming VS-3.2.
7. Write the return handoff (see template in §10) so a fresh main session can resume VS-3.2 with confidence the auth path is fixed.

## 9. Anti-actions

- Do NOT modify any files inside `docs/specs/sprint-3/VS-3.2-*/` — that's VS-3.2 territory; this detour is canonical-only.
- Do NOT advance VS-3.2's work-item statuses in the slice README; the main thread owns those updates.
- Do NOT dispatch implementer-agent subagents in this session — it's a manual bug-fix session, not slice work.
- Do NOT extend scope to the related "auth-expired vs. empty-data" UX gap (backlog it instead; one detour, one concern).

## 10. Return-handoff template stub

When this bug-fix is done, write the return handoff at the same handoffs/ dir, named:
`vs-3.2-bugfix-auth-a1b2-return.md`

Use the standard 10-section structure with:
- §1 type = return; reference back to a1b2 short-id.
- §4 "What's NOT in memory bank yet" — distill what the bug-fix surfaced that should be promoted to memory-bank/02-system-patterns.md at the next slice-close harvest.
- §6 "In-flight state" — the merged commit sha for the bug-fix; instruct that VS-3.2 can resume.
- §8 "Next intended action" — point at: "Open a fresh main session; read THIS forward handoff (a1b2.md) AND this return file; resume VS-3.2 round-2 dispatch."
```

## What the source orchestrator session does after writing

1. Writes the handoff file (above) to `<ai-workspace>/.workspace/handoffs/vs-3.2-bugfix-auth-a1b2.md`.
2. Surfaces to user:
   > "Forward handoff written. Source session can now terminate or pause. To execute the bug-fix, open a fresh Claude session and prompt with: 'Read /Users/draco/projects/insight-platform-ai/.workspace/handoffs/vs-3.2-bugfix-auth-a1b2.md and execute the next intended action.'"
3. The source session does NOT dispatch a subagent for this — the bug-fix is OUT of the slice's planned subagent boundary (SPEC §6b.7 subagent boundary rule). User opens a fresh manual session.

## What gets promoted from section 4 at slice close

When VS-3.2 closes and `closing-vertical-slice` runs the memory-bank harvest (SPEC §15.2 step 2), the harvest skill sweeps `vs-3.2-*.md` handoffs in `.workspace/handoffs/`. The section-4 items that promote-worthy here:

- "verify_bearer_token returning None on expired token is a silent-failure anti-pattern" -> proposed target: `memory-bank/02-system-patterns.md` section "API auth conventions"; user accepts.
- "auth-expired vs. empty-data is a UX gap" -> proposed target: backlog (NOT memory bank); user accepts.
- The test-with-fresh-token observation -> proposed target: `memory-bank/03-code-patterns.md` mcrule candidate (auth tests must include expired-token cases); user defers (low frequency).

Provenance trailer added per SPEC §15.2 step 7: `<!-- Added from VS-3.2 retrospective, 2026-05-26; source: handoff -->`.
