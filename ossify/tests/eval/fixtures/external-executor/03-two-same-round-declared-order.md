---
scenario_id: 03-two-same-round-declared-order
expected_outcome: gap-loop
expected_reason: 'Two things at once, and both are order-of-processing facts. First,
  arrival order is not processing order - w2''s result arrived first but w1 is declared
  first, so w1 is validated and closed and merged before w2 is touched at all; an
  output that closes w2 first because it arrived first is wrong even though both items
  eventually close. Second, w2''s return is mode gaps-surfaced, and that is NOT a
  halt and NOT a malformed result - it routes into round-orchestration.md section
  6''s existing gap loop (surface the gaps, append clarifications to w2''s OWN handoff,
  re-dispatch the same live implementer, count the dispatch against the 3-iteration
  cap) and never reaches close as a result. The round barrier holds: round 2 does
  not start while w2 is still open. The wrong answer this fixture falsifies is a model
  that reads the round''s validation checks as uniformly terminal and halts the whole
  round on the gaps return, stranding w1''s completed work'
---

Spine `r3.s4` ("retry policy") has one round with two work items in this
declared decomposition order: `r3.s4.w1` (`target_repo: canonical`, "backoff
calculator") and `r3.s4.w2` (`target_repo: canonical`, "retry budget config").
There is a second round behind this one, `r3.s4.w3`, which the plan declares
depends on both.

The lane is running under `--external-executor`. Both worktrees exist and are
journaled, both handoffs are authored, and both requests were handed to the
caller in one call. The caller ran the two items concurrently.

The caller returns two results. `r3.s4.w2`'s arrives first: `coordinator_verdict:
accepted`, and its `implementer_return` reports `mode: gaps-surfaced` with one
blocking gap — *"AC-2 does not say whether an exhausted budget raises or returns
a sentinel."* `r3.s4.w1`'s arrives second: `coordinator_verdict: accepted`, its
`implementer_return` reports `mode: complete` with `stage_status: all_staged`,
and its four declared `*_oid` values match what the lane recomputes.

`r3.s4.w2` has been dispatched once so far.

State what the lane does with each of the two returns, in what order it does it,
and what has to be true before `r3.s4.w3` starts.
