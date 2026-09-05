---
scenario_id: 02-item-traffic-stays-in-child
expected_outcome: proceed
expected_reason: 'Routing, in both directions. The two item plan questions arrived
  on the CHILD Run and are answered there — but not by the spine session on its own
  authority: it gathers the round''s available plans into ONE ordered parent ask,
  the top returns an INDEPENDENT approve-or-amend per item, and the spine session
  replies to each ORIGINAL child message id. No edit starts before that reply lands.
  The verifier''s per-item worker_done settles in the child and never reaches the
  parent inbox. The spine session''s own final completion uses the INJECTED parent
  task and dispatch ids, which settles the top''s Dispatch while the child Run stays
  bound. The wrong answers this fixture falsifies are: the spine session approving
  the plans itself because it can read them; relaying two separate asks when one ordered
  ask carries the round; answering both child questions on one message id; and forwarding
  the verifier completion up as progress'
---

You are the spine session for `r5.s2`. Your brief injected these parent
identities and you created and bound a child Run, `run_child77`, for item tasks:

    PARENT_RUN_ID=run_parent41
    SPINE_TASK_ID=task_spine08
    SPINE_DISPATCH_ID=ctx_spine08
    ORCA_EXECUTION_PATH=/repos/product-ai/docs/specs/r5/r5.s2-ledger-export/orca-execution.md

Round 1's two items are live. Both implementer terminals have confirmed their
models and read their handoffs, and both have now posted implementation plans as
blocking questions on the child Run: `r5.s2.w1`'s on child message `msg_c31`,
`r5.s2.w2`'s on child message `msg_c34`. Neither has edited anything yet.

Separately, `r5.s2.w2`'s verifier terminal has finished a read-only probe you
attached to it earlier and sent a `worker_done` on the child Run.

State what you do with each of these three messages: where each one goes, what
you send up and in what shape, what comes back, and how each implementer learns
it may start. Then state which ids you will use for your own final completion at
the end of the spine, and what the top orchestrator will and will not have seen
by then.
