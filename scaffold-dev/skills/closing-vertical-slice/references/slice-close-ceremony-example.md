# Slice-close ceremony worked example — VS-3.2

The 3-layer slice-close ceremony (SPEC §14) on a fictional slice. Walks through automated demo, manual demo, architect-critic adversarial review, then retrospective + harvest + cleanup.

## Pre-conditions

- All rounds complete; all work items merged to canonical main.
- Slice README's "Demo verification" subsection is empty (placeholder waiting for ceremony output).
- Worktrees + branches for the slice's work items still exist (deferred from round-close per SPEC §11).

## Layer 1 — Automated demo criteria

The skill body parses the slice README's "Demo criteria" subsection. For VS-3.2:

```
- [ ] auto: `pytest tests/integration/test_insight_pipeline.py` -> expected: exit 0
- [ ] user: Navigate to localhost:3000/insights -> expected: action-needed card visible with real data
- [ ] user: Click chatbot icon and type "what's overdue?" -> expected: response within 5s
```

For each `auto:` step, skill body runs the command in canonical (which now contains all merged work-item code):

```bash
cd /Users/draco/projects/insight-platform && pytest tests/integration/test_insight_pipeline.py
```

Records result in README "Demo verification":

```markdown
## Demo verification

### Automated

- [x] auto: `pytest tests/integration/test_insight_pipeline.py` -> exit 0 (5 tests passed, 0 failed; run at 2026-05-26T10:14Z)
```

If automated demo FAILS, skill body HALTS the ceremony and surfaces options (per SPEC §14.4 failure path): re-open VS with fix-up round, close-with-deferred, or abandon.

## Layer 2 — Manual demo criteria

For each `user:` step, skill body surfaces:

```
User demo step 1 of 2:

  Action:   Navigate to localhost:3000/insights
  Expected: action-needed card visible with real data

Execute this manually. Report back: passed / failed / partial. Add note if useful.
```

User executes (opens browser, navigates, observes). User responds in conversation:

> "passed. Card showed 3 action-needed items for my logged-in user, severity badges rendering correctly."

Skill body records:

```markdown
### Manual

- [x] user: Navigate to localhost:3000/insights -> action-needed card visible with real data
  - Result: passed. Card showed 3 action-needed items for the logged-in user; severity badges render correctly.
```

Repeat for step 2:

> "user: Click chatbot icon and type 'what's overdue?' -> response within 5s. Result: partial — response came in 3.2s (within budget), but the response text said 'no overdue items' which is wrong (there ARE overdue items in the test DB for this user)."

Skill body records partial + the discrepancy. Surfaces decision: continue ceremony (and capture the chatbot bug as a follow-up backlog item), or halt? User decides: continue; backlog the chatbot wording bug.

## Layer 3 — Architect-critic adversarial review (SPEC §14.3)

Skill body probes for architect-critic (lazy filesystem probe). If present:

```
Invoking architect-critic moment-2 (slice-close adversarial review).
Context: full slice diff (VS-start commit to current canonical HEAD), slice README, all 5 work-item specs + reports.
Depth: claude-self-audit + Codex close-depth if Codex installed.
```

Critic runs in-conversation. Sample challenges surfaced:

```
C1. The slice ships a backend query (work-3.2.01) that selects ALL action_needed rows for a
    user with NO pagination. If a user has thousands of rows, the endpoint will return a
    large JSON payload + render lag. Should the endpoint paginate?

C2. work-3.2.05's integration test runs against a seeded fixture with 2 action_needed rows.
    The test would still pass if the query returned ANY non-empty list (e.g., a SQL injection
    that returns all rows from a different table happens to have rows). The test is too weak
    relative to the AC.

C3. The chatbot manual-demo failure ("said no overdue items when there ARE overdue items") —
    is this in scope for VS-3.2 or punted to a follow-up? The slice's demo criterion says
    "response within 5s" and the partial result satisfied THAT criterion narrowly, but the
    spirit of the criterion is that the response is CORRECT, not just fast.
```

User rebuttal cycle:

> C1: Defer. Pagination is in backlog (VS-4.x admin scope); slice scope was deliberately narrow.
> C2: Concede. Strengthen test to assert exact row count + specific row content. Will add to backlog as a tightening item before sprint close.
> C3: Concede. The chatbot wording bug is in scope for VS-3.2 — it's the demo criterion spirit. Re-open VS with a fix-up round.

Critic scores: C1=2 (defer logged), C2=5, C3=5. Two concessions; one rejected as expected from spec context.

## Decision point (SPEC §14.4)

Skill body surfaces:

> "Layer 1 passed. Layer 2 1-of-2 passed, 1 partial (chatbot wording). Layer 3 surfaced 3 challenges, 2 conceded. C3 requires re-opening VS-3.2 with a fix-up round. Proceed? (alternatives: close-with-deferred treating chatbot wording as a known caveat; or abandon VS — not recommended given 4 of 5 work items shipped cleanly)."

User decides: re-open with fix-up round. Slice does NOT close yet. Ceremony halts; skill body exits.

(In a happy-path scenario where all layers pass cleanly, control would proceed to retrospective + harvest below.)

## Happy-path tail — if all layers had passed

Skill body proceeds to:

1. **Author retrospective** — see `memory-bank-harvest-example.md` for the harvest step which writes results back to retrospective.md and memory bank.
2. **Memory bank harvest** — per SPEC §15.2. Sweep work-item reports + slice handoffs; surface promote-worthy items.
3. **Cleanup** — remove worktrees + delete branches for VS-3.2's work items (deferred from round-close per SPEC §11):
   ```bash
   for wt in /Users/draco/projects/insight-platform/.worktrees/work-3.2.*; do
     git -C /Users/draco/projects/insight-platform worktree remove "$wt"
   done
   git -C /Users/draco/projects/insight-platform branch -d work/3.2.01-backend-query-endpoint work/3.2.02-frontend-card work/3.2.03-dashboard-integration work/3.2.04-chatbot-intent work/3.2.05-integration-test
   ```
4. **Surface** — "VS-3.2 closed. Ready for VS-3.3 (or close sprint)."

## Anti-patterns

- **Skipping a layer.** Skill body must run all 3 layers in order; halt-on-fail is the correct response, not skip-and-continue.
- **Treating "partial" as passed.** Partial requires explicit user decision: backlog or fix-up. Default behavior is to surface for decision, never silently treat as passed.
- **Running architect-critic moment-2 if moment-1 was skipped.** If moment-1 was skipped (architect-critic absent at spec-author time), moment-2 still runs IF critic is present now — the two moments are independent invocations.
