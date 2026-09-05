# Rubric: external-executor

Score each 1-5 (5 criteria). Pass = all ≥4. `expected_outcome` vocabulary:
`nested` | `external` | `halt` | `gap-loop`. `nested` = the lane dispatches its
own `ossify:implementer-agent` per work item. `external` = the lane hands the
round to the caller-supplied in-session procedure and processes the results it
returns. `halt` = the lane stops the round, naming the failing check, without
falling back to the nested path. `gap-loop` = the item re-enters
`round-orchestration.md` §6 (clarifications appended to the handoff, then one
new single-item request through the caller, under the 3-iteration cap) rather
than halting or reaching close.

**Every criterion is scored on every fixture.** A criterion whose own condition
never fires on a fixture is scored on whether the output stayed correctly silent
about it — and an unexercised criterion **caps at 4** (consistent with the
contract, not demonstrated by this scenario). **5 requires the scenario to have
actually exercised it.** There is no N/A.

**Score only what the scenario supplies.** If the fixture body does not state a
fact, an output that does not decide it is not penalised; an output that invents
that fact and decides on it is.

1. **The mode split is exact, and the default is untouched.** `/run-spine
   <spine-id>` with no flag keeps dispatching `ossify:implementer-agent`;
   `/run-spine <spine-id> --external-executor` hands execution to a
   caller-supplied procedure and calls no subagent. The flag is never inferred
   from context, an installed tool, or the presence of a caller; a malformed,
   reordered, duplicated or unknown argument is refused **before** the
   spine-branch cut, any worktree, and any state write. Treating external mode
   as a degraded variant of the nested path, or letting either mode silently
   become the other, is a wrong answer even when the fixture's verdict is
   otherwise right.
2. **Round sequencing and ordering survive the seam.** In external mode every
   same-round worktree is created and journaled and every handoff authored — in
   declared decomposition order — **before** any request is built; then one
   request per item, and the caller procedure is invoked once for the round.
   The caller may execute a round concurrently. Accepted results are processed
   into close in **declared decomposition order, never arrival order**; closes
   and merges stay serial; the round barrier is unchanged. An output that closes
   items in the order their results arrived is a wrong answer even if every item
   eventually closes.
3. **Validating a COMPLETE result is a real gate, and every one of its checks
   is terminal.** A finished item returns the §4 record, and all five checks
   apply to that record alone: exactly one per request with no extras and no
   duplicates; every declared field and no other, with `implementer_return`
   carrying exactly the four complete-return keys; `coordinator_verdict` is
   `accepted`; `mode` is `complete`; and the four-part fingerprint (staged tree,
   HEAD, report, spec) is **recomputed** and compared, not trusted from the
   result — **and `head_oid`, the recomputed `HEAD` and the request's `base_sha`
   must all three be equal**, because an executor that commits its work and then
   stages more passes a freshness check while having crossed the commit boundary
   that belongs to close. Branching this list on `mode` is a wrong answer: the
   two shapes are separate records (criterion 4), not one record checked two
   ways. A failure of any
   of these halts the round and never degrades into the nested dispatch, and
   there is no stop-and-reinvoke path. Accepting a result because it "looks
   complete", or reading the declared fingerprint back as if it were the
   recomputed one, is a wrong answer.
4. **A gaps-surfaced return is its own record, and it routes rather than
   halting.** An item stopped at pre-flight produced no report, no staged tree
   and no commit, so it comes back under a **separate marker** carrying only
   `work_item_id`, `coordinator_verdict` and an `implementer_return` in the gaps
   shape — **no `*_oid` of any kind**, and a record carrying one is describing
   work that did not happen. It enters `round-orchestration.md`
   §6's gap loop **with that loop's dispatch step replaced**: gaps surfaced,
   clarifications appended to **that item's handoff**, then **one new
   single-item request** issued through the caller-supplied procedure, counted
   against the 3-iteration cap — and it never reaches close as a result.
   Calling it a halt, a malformed result, or a reason to abandon the round is a
   wrong answer; so is routing it past the gap loop straight into close. **In
   this mode the lane dispatches nothing itself**, and it does not say which
   executor the caller reuses — an answer that has ossify re-dispatching "the
   same live implementer" is describing the default nested path, not this one.
5. **Correction is same-executor, and Layer 4 goes inline under this mode.** A
   rejected item is repaired by a continuation sent to the **same** executor
   that produced it, because the ordinary command's clean-tree pre-flight would
   correctly refuse the staged output; the continuation re-reads
   handoff/spec/report, refuses on any item/branch/HEAD/staged-tree mismatch,
   writes the targeted regression before the fix, reruns every verification
   command, updates the same report, stages, and returns the **existing**
   `complete` shape — no third return mode and no commit. Separately, external
   mode runs Layer 4 **inline** even where the delegated path's own conditions
   are otherwise satisfied, while the no-flag path's choice of the delegated
   path is unchanged. Inventing a new return mode, sending the correction to a
   fresh executor, or spending the delegated six-agent pass under external mode
   is a wrong answer.

## Output format
`{"scores":{"mode_split":N,"round_sequencing":N,"result_validation":N,"gaps_routing":N,"correction_and_layer4":N},"pass":true|false,"notes":"<one sentence; where any criterion scores below 5, name the cause>"}`. Pass = all ≥4. JSON only.
