# ossify spine execution — assignments, the nested Run, and who owns what

A spine's work items each deserve their own model and effort; one dispatched lane driver
cannot give them that, because whatever it spawns inherits its runtime.

> **Editing note.** This file and `ossify-briefs.md` are asserted to hold no subagent
> invocation form and to stay under 200 lines. Never paste the call shape.

## 1. Activation

Four facts, **all** of them, and each about the session you are in right now:

1. orca-crew is the current top orchestrator;
2. a parent Run is bound;
3. this session has just completed `/ossify:plan-spine`;
4. a concrete spine directory exists on disk.

Absent any one, this file does not apply and ossify runs as `SKILL.md` §6 says.
**None of these activates it**: orca-crew or ossify merely installed; an environment
variable; an `orca-execution.md` on disk; a `/plan-spine` in a session that is not the
top. Discovery is not authority — the phase begins because *this* session planned
*this* spine.

## 2. The three layers

| Layer | Owns | Never |
|---|---|---|
| **Top orchestrator** (you) | ratifying one implementer/verifier profile per item, writing the sidecar, starting one spine session, approving or amending each relayed worker plan, running the spine close, the PR-transition reviewer and PR-fix decisions, the merge | launching or supervising an item terminal; reading raw child completion traffic |
| **Spine session** | the ossify lane, a nested child Run, launching and supervising both item terminals per item, relaying plans up, item-local corrections | changing any ossify contract; moving item tasks into the parent Run |
| **Item terminals** | one item each: implement, verify | crossing into another item |

ossify owns worktrees, handoffs, closes, merges and the round barrier, and knows
nothing about the above.

## 3. The sidecar

`$SPINE_DIR/orca-execution.md`. **You are its only writer.**

```markdown
# Orca execution assignments

schema: orca-execution/v1
spine_id: r7.s2
spine_plan: ./SPINE.md
spine_plan_oid: 1111111111111111111111111111111111111111
ratification: operator-approved
ratified_in_run: run_parent123

## Fixed procedures

implementation_plan_gate: worker-authored/top-orchestrator-approved
implementer_entrypoint: /ossify:work-item $HANDOFF_PATH
verifier_procedure: all-claims-work-item-verify/v1

## Binding assignments

| work_item_id | implementer_terminal_command | implementer_expected_model | implementer_effort | verifier_terminal_command | verifier_expected_model | verifier_effort |
|---|---|---|---|---|---|---|
| r7.s2.w1 | claude --model claude-opus-5 --effort xhigh | claude-opus-5 | xhigh | claude-glm --effort high | glm-5.3 | high |

## Recommendation record

- r7.s2.w1 — interface work justifies Opus 5 xhigh; GLM high checks it independently.

## Excluded decisions

The spine-session profile follows this skill's lane-driver policy. Reviewer profile
and `/code-review` level are selected when the spine PR reaches review.
```

**Only the terminal command, expected model and effort vary.** The three procedures
above are fixed for every item on every spine, recorded so the spine session can check
them rather than choose among them. No reviewer row, no spine-session row — §8 says why.

**Authoring it.** After `/plan-spine`, recommend one implementer and one verifier
profile per item from its scope, risk and cost. Present **every** row to the operator in
one ratification phase and write nothing until every row is decided — a half-ratified
sidecar looks binding and is not. Record the recommendation and any override.

**Reading it.** Before dispatching the spine session, and again before every
item launch, the reader checks: the plan's blob id **at its real path** —
`git hash-object "$(dirname "$ORCA_EXECUTION_PATH")/SPINE.md"`, which resolves
`spine_plan` against the sidecar's own directory exactly as authoring did — equals
`spine_plan_oid`; every planned item has exactly one complete row; no row names
an item the plan does not; `ratification` reads exactly `operator-approved`;
`ratified_in_run` equals the injected `PARENT_RUN_ID`; `spine_id` equals the
spine being run. **Those last three are value checks, not presence checks** — a field
that merely exists admits `rejected`, another Run's ratification, and another spine's
sidecar, each reading as authority it never had. Any failure halts; a profile that needs
to change is a new operator decision and a rewrite by you, never a substitution.

## 4. Nested depth is a prerequisite, not a fallback

Orca's `Settings → Orchestration → Nested worker depth` must be `2`, because the spine
session dispatches item sessions of its own. No CLI read exposes that setting, so get
the operator's confirmation before starting the spine session; the first real child
dispatch is the runtime proof.

If a child dispatch returns `nested_worker_depth_exceeded`, the spine session stays
the lane owner, reports the blocker, and waits for an operator decision. It does not
substitute a Claude subagent, move item tasks into the parent Run, create a
replacement writer, or restart the lane.

## 5. The nested Run

Your brief injects the spine session's identities explicitly (`ossify-briefs.md`); that
session then creates and binds a **child Run** for item tasks, which does not reset
nested depth.

- child `task-create`, `worker-start`/`dispatch` and `check` always name
  `--run $CHILD_RUN_ID`;
- plan, gap, depth and other spine-level questions come up as `ask --run $PARENT_RUN_ID`;
- replies to item questions go back on each original child message id;
- its final completion uses the **injected parent** task and dispatch ids, settling
  your Dispatch while the child Run is still bound;
- the spine session is the only waiter on the child Run; you, on the parent.

The child Run keeps item plan traffic and item `worker_done` out of your inbox: you see
a batched plan relay, genuine spine-level decisions, and one final completion.

**Teardown is the pairs, not the Run.** The spine session releases every item pair
before its final `worker_done` and names the child Run id in that body. There is no
close-the-Run step: the CLI exposes none.

## 6. The round procedure, as the spine session runs it

1. Validate `SPINE.md`, the sidecar and the round's item set (§3).
2. Invoke the ossify lane in external-executor mode. ossify prepares every
   same-round worktree and handoff first, then hands over one request per item.
3. For each item, launch a **fresh implementer terminal** from that row's exact command
   — the verifier is not created yet; it has nothing to verify until step 5. Where a
   custom alias is required, create the terminal directly and inject the Dispatch.
4. Each implementer confirms its model, reads, and posts a detailed plan, then waits.
   Gather the round's plans into **one** ordered ask to you; return an independent
   approve-or-amend per item; reply on each original child id, before which no edit
   starts.
5. On each complete return, capture the item's four-part fingerprint, then create and
   dispatch that item's **fresh verifier terminal** from its row's exact command, in the
   same worktree, against the fixed all-claims procedure. `cannot determine` = fail.
6. On a verifier failure, send one consolidated correction to the **same** implementer
   terminal, then the full recheck to the **same** verifier. A second failure escalates
   to you; a replacement writer is never created silently.
7. Initial gaps are handled inside the spine session: it asks you for the operator's
   answers, remains the handoff writer, appends clarifications, and re-requests the item
   within ossify's three-attempt cap.
8. Feed accepted results into the lane in declared decomposition order. Keep each pair
   until its item closes or escalates, then release it. **No terminal is ever
   transferred to another item.**

Same-round pairs may run concurrently. Closes and merges stay serial and the
round barrier is ossify's, unchanged.

## 6b. The spine close is dispatched, and it comes next

The spine session stops at the final round barrier — where `/ossify:run-spine` hands
the baton to `/close <spine-id>` — and never runs the close on its own initiative.
When its `worker_done` lands, **you dispatch** `/ossify:close <spine-id>` as a task. You
do not run it here: SKILL.md §6 lists `close` among the dispatched commands, and the
delegation floor keeps suites out of your session. **Target:** a follow-up task on the
spine session's own terminal while it is under `roles.md`'s retention threshold — it
holds the state lock and the context — else a fresh lane-driver session.

**That close runs in two passes, and you dispatch it twice.** The first runs the
cumulative demo, the harvest and the retro and opens **one PR per hosting repo**, then
reaches its named halt state: while any of them is open it halts, recording nothing
(`close/references/spine-close.md`). Its `worker_done` returns at that halt naming
**every** PR it opened, repo and number, and `lifecycle.md` steps 8-12 then run for
**each** of them. **Once all of them have merged you dispatch `/ossify:close
<spine-id>` a second time** for the record pass, which halts again on any PR still open.

## 7. Scope of the fresh-pair rule

Fresh-per-item pairs are scoped to **activated ossify spines**. Outside them
`roles.md`'s class routing and retention remain authoritative — a retained implementer
across ordinary consecutive work items is still correct.

## 8. Two profiles are chosen at the PR, not before

Reviewer profile is absent from spine planning and from the sidecar on purpose: the PR
does not exist yet, and a profile chosen before there is a diff to read is a guess
recorded as a decision. At the PR transition ask for the reviewer's command, expected
model, effort and `/code-review` level, and put **all four** in the reviewer task's brief
— the reviewer launches from the decided command and its model is confirmed from the
banner and first reply exactly as an item row is; step 8's `claude-glm-flash` is the
default only outside such a spine. Neither the spine session nor the sidecar selects it.

**Decide the PR-fix implementer in the same breath.** Every item pair was released at
its item's close and the spine session was a coordinator, not a writer — so step 10's
*retained implementer* does not exist here. Ask for one PR-fix profile (command,
expected model, effort) alongside the reviewer's. The seat is **decided** now and may be
launched now, but **its fix task is dispatched only once step 9's disposition ledger
exists**. Dispatch it in the **parent** Run on `briefs.md`'s **fix-round brief**, never
the planned-implementer brief, whose DONE opens a new PR: this worker works the PR that
already exists, returns its fix ledger, and stops at the merge ask. One seat per PR,
released at merge.

## 9. Briefs

This phase's four briefs are in `references/ossify-briefs.md`; `references/briefs.md`'s
templates are unchanged and still apply elsewhere, its fix-round brief included (§8).
