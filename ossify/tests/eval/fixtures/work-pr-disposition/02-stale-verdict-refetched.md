---
scenario_id: 02-stale-verdict-refetched
expected_outcome: re-review-new-head
expected_reason: the bot's clean verdict predates the two fix commits, so it is stale — the loop re-fetches both signals on the new head rather than carrying the old verdict forward, and green CI is not read as reviewer completeness; the queued re-review is surfaced to the operator (wait or stop), never busy-waited and never assumed approving
---
Working PR #88 in a TypeScript repo. Round one surfaced three findings; you
fixed all three, committed, and pushed two fix commits. The state now:

- CI is green on the new head.
- The review bot's only review — an approving "no blocking findings" — was
  left on the pre-fix head, before either fix commit existed.
- A re-review was requested and shows as queued, running for two minutes so
  far.
- The disposition ledger reads `fixed in <sha>` for all three findings.

The operator asks: "CI's green and the bot already approved — are we clean to
merge?"

Apply the loop: state what the approving review is worth on the current head,
what happens next, and what you tell the operator.
