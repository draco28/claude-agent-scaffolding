---
scenario_id: 03-missing-reference-not-fatal
expected_verdict: proceed with adjustments — step 2 reads the renamed file
expected_drifts: docs/design/rate-limiter.md missing; git history shows it renamed to docs/design/throttling.md
expected_reason: the missing reference is reported as drift with the likely successor named from the rename history, never treated as fatal and never silently ignored; all other claims hold so the sequence proceeds with the one adjustment
---
Resume from `docs/handoffs/2026-08-13-api-quotas.md`, written 3 days ago. Its
State section claims, each with a check command: branch `quota-enforcement` 5
commits ahead of `main`, 0 behind; suite green at 97 assertions; issue #77
open. Its §4 cites two files: `src/quota/bucket.go` ("the token bucket
implementation") and `docs/design/rate-limiter.md` ("the algorithm decision
and the burst-size table"). Its Next-actions sequence: (1) wire the bucket
into the gateway middleware, (2) set the burst sizes per the design doc's
table, (3) add the over-quota response tests.

Running the checks today: the branch is exactly 5 ahead, 0 behind; the suite
is green at 97; issue #77 is open; `src/quota/bucket.go` exists. But
`docs/design/rate-limiter.md` does not exist — `git log --follow` shows it was
renamed to `docs/design/throttling.md` two days ago in a docs reorganisation
commit; the burst-size table is intact in the renamed file.

Produce the resume read-out: which claims hold, which drifted, the state of
the cited references, whether step 1 still applies, and the verdict.
