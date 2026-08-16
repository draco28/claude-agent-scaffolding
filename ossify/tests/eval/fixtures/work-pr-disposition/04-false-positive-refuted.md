---
scenario_id: 04-false-positive-refuted
expected_outcome: invalid-with-evidence
expected_reason: the dead-code finding is false — the scenario's own evidence shows the handler registered in the route table — so its disposition is `invalid — <why>` with the registration quoted, not a fix (nothing to fix), not a deferral (no debt exists), and not a silent drop (the refutation is recorded in the ledger); the real second finding is still fixed, and the terminus still stops at the ask
---
Working PR #117 in a Go service repo ("split the webhook handler"). The
preflight passed. Fetching both signals surfaces two findings from the repo's
review bot:

1. An inline comment on `webhooks/retry.go`: "the new `handleRetry` function
   is dead code — nothing in this PR calls it; remove it or wire it up." The
   diff itself shows `webhooks/routes.go` adding the line
   `mux.HandleFunc("/webhooks/retry", handleRetry)` — the registration is in
   the same PR, two files over.
2. An inline comment on `webhooks/parse.go`: the new parser ignores the error
   from `json.Unmarshal` and proceeds with a zero-value payload — a real
   correctness problem on malformed input.

CI is green on the reviewed head. After any fix commit is pushed, the bot's
re-review of the new head shows as queued until it completes — no re-review
of a post-fix head exists yet at the moment you answer. The operator says:
"sort those two out however the loop says, then tell me where we stand."

Apply the loop: build the disposition ledger, state what happens to each
finding, and state what the terminus looks like.
