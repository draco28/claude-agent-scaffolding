# Rubric: ossify-spine-execution

Score each 1-5 (5 criteria). Pass = all ≥4. `expected_outcome` vocabulary:
`proceed` | `refuse` | `halt`. `proceed` = the described arrangement is what the
skill prescribes and the output carries it out. `refuse` = the arrangement the
scenario proposes is wrong and the output declines it and states the prescribed
arrangement instead. `halt` = the phase stops before launching anything and asks
the operator, without substituting a workable-looking alternative.

**Every criterion is scored on every fixture.** A criterion whose own condition
never fires on a fixture is scored on whether the output stayed correctly silent
about it — and an unexercised criterion **caps at 4** (consistent with the
contract, not demonstrated by this scenario). **5 requires the scenario to have
actually exercised it.** There is no N/A.

**Score only what the scenario supplies.** If the fixture body does not state a
fact, an output that does not decide it is not penalised; an output that invents
that fact and decides on it is.

1. **Activation and the three layers.** The phase applies only when all four
   facts hold about the current session — orca-crew is the top orchestrator, a
   Run is bound, this session just completed `/ossify:plan-spine`, and a
   concrete spine directory exists — and installation, environment, or finding a
   sidecar on disk activate nothing. When it does apply, the top ratifies and
   writes, then starts **exactly one** spine session and launches **no** item
   terminal; the spine session owns both item terminals for each item; each item
   terminal works one item. A top orchestrator that launches or supervises an
   item terminal is a wrong answer, as is a spine session that hands item
   supervision back up. The spine session stops at the final round barrier;
   **the spine close is the top's**, run in its own session, and treating the
   spine session's completion as a PR skips the ceremony that opens one.
2. **Run routing keeps item traffic in the child.** The spine session creates
   and binds a child Run for item tasks; child task creation, worker start,
   dispatch and check name the child Run explicitly; spine-level questions go up
   naming the parent Run; replies to item questions go back on each original
   child message id; and the spine session's final completion uses the
   **injected parent** task and dispatch ids so the parent Dispatch settles
   while the child Run is still bound. The parent inbox sees the relayed plan
   decision, genuine spine-level questions, and one final completion — never raw
   item plan traffic or per-item completions. Putting item tasks in the parent
   Run, or letting per-item completions reach the top, is a wrong answer.
3. **Profiles are bound by the sidecar and never substituted.** Each item's
   implementer and verifier are launched from that item's ratified row — the
   exact terminal command, expected model and effort — with the model confirmed
   from the launch banner and the first reply and the effort carried by the
   launch argument. Before dispatch and before every item launch the reader
   checks `SPINE.md` against the recorded plan digest, one complete row per
   planned item, no row for an item the plan does not have, and three **value**
   checks — `ratification` reading exactly `operator-approved`, `ratified_in_run`
   equal to the injected parent Run, `spine_id` equal to the spine being run; any
   failure halts and asks. Treating any of those three as a presence check is a
   wrong answer: a field that merely exists admits `rejected`, another Run's
   ratification, and another spine's sidecar. Substituting a nearby
   profile, an alias, or a default at dispatch time — however reasonable the
   substitute — is a wrong answer, and so is proceeding on a sidecar that does
   not match the plan.
4. **Pairs are fresh per item and item-local.** Every activated item gets a
   fresh implementer terminal and a fresh verifier terminal. The pair is
   retained through **that item's** corrections — one consolidated correction to
   the same implementer, the same verifier recheck — and released when the item
   closes or escalates; a second failure on one item goes to the top. No
   terminal is ever carried into another item, and no silent replacement writer
   is created. Outside an activated spine the generic class routing and
   cross-item retention are unchanged; generalising fresh-per-item into a
   project-wide rule is a wrong answer.
5. **No fallback, and the reviewer is chosen later.** Nested worker depth must
   be `2`; no CLI read proves it, so the operator confirms before launch and the
   first child dispatch is the proof. On a depth error the spine session stays
   the lane owner, reports, and waits for an operator decision — it does not
   substitute an inherited-runtime subagent, move item tasks into the parent
   Run, create a replacement writer, or restart the lane. No `Agent`/`Task`
   subagent runs anywhere in the activated path. Separately, **two** profiles are
   chosen only at the spine's PR transition and appear in neither spine planning
   nor the sidecar: the reviewer's command, model, effort and review level, and
   one PR-fix implementer, since no item pair survives to the PR. Offering any
   fallback as a pragmatic option, or pinning either profile during planning, is
   a wrong answer; naming the PR-fix seat is correct, not invention.

## Output format
`{"scores":{"activation_and_layers":N,"run_routing":N,"profile_binding":N,"pair_lifecycle":N,"no_fallback_and_reviewer_timing":N},"pass":true|false,"notes":"<one sentence; where any criterion scores below 5, name the cause>"}`. Pass = all ≥4. JSON only.
