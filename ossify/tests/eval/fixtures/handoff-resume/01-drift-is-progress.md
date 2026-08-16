---
scenario_id: 01-drift-is-progress
expected_verdict: proceed with adjustments — steps 1 and 2 are done by the merge; step 3 is the remaining work
expected_drifts: PR #88 merged (was open), branch payments-retry deleted (was 4 ahead), main moved 23 commits, suite now 230 assertions (was 212)
expected_reason: every drift is detected and reported, the merge is read as the expected progress rather than a defect in the handoff, and the assertion-count movement is real drift reported without alarm; no drift is invented and none is punished
---
Resume from `docs/handoffs/2026-08-07-payments-retry.md`, written 9 days ago.
Its State section claims, each with a check command: branch `payments-retry` 4
commits ahead of `main`; HEAD at `abc1234`; suite green at 212 assertions;
PR #88 open awaiting review. Its §4 cites `docs/specs/retry-policy.md`. Its
Next-actions sequence: (1) address review feedback on PR #88, (2) merge PR #88
once approved, (3) start the notification follow-up described in issue #91.

Running the checks today: PR #88 was merged 6 days ago and its branch
`payments-retry` was deleted; `main` has moved 23 commits since `abc1234`; the
suite is green at 230 assertions; `docs/specs/retry-policy.md` exists,
modified last week by the merge. Issue #91 is open and unassigned.

Produce the resume read-out: which claims hold, which drifted and how each
drift reads, the state of the cited references, whether step 1 still applies,
and the verdict.
