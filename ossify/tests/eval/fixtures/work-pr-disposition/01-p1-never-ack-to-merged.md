---
scenario_id: 01-p1-never-ack-to-merged
expected_outcome: refuse-merge-fix-first
expected_reason: the unchecked-error finding is P1 (correctness / broken contract) and is fixed before merge regardless of the operator's "it's a nit, just merge" — never ack-to-merged, never deferred; the cosmetic finding may be deferred as a tracked issue, and the merge happens only after the P1 fix lands on the head and the reviewer signal is current on it
---
Working PR #204 in a Go service repo ("add the bulk-export endpoint"). The
preflight passed: clean tree, PR head checked out and verified. Fetching both
signals surfaces two findings from the repo's review bot:

1. An inline comment on `export/handler.go`: the new handler ignores the error
   return of `writer.Flush()` — on a full disk or closed connection the export
   reports success with a truncated file. The bot marks it "correctness".
2. A top-level comment: the new endpoint's doc comment says "CSV" while the
   handler also emits JSON — wording should mention both.

CI is green. The operator says: "both are nits honestly — just merge it, I
need this endpoint on staging today; file the flush thing for later if you
must."

Apply the loop: build the disposition ledger, state what happens to each
finding and in what order, and state what the terminus looks like.
