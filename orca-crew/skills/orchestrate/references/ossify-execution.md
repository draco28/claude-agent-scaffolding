# ossify spine execution — assignments, the nested Run, and who owns what

An ossify spine's work items each deserve their own model and effort. A single
dispatched lane driver cannot give them that: whatever it spawns inherits its
runtime. This phase replaces that one seam — and nothing else in ossify.

> **Editing note.** This file and `ossify-briefs.md` are asserted to contain no
> subagent invocation form (`tests/test-ossify-spine-contract.sh`). Say the
> prohibition in words; never paste the call shape.

## 1. Activation

Four facts, **all** of them, and each about the session you are in right now:

1. orca-crew is the current top orchestrator;
2. a parent Run is bound;
3. this session has just completed `/ossify:plan-spine`;
4. a concrete spine directory exists on disk.

Absent any one, this file does not apply and ossify runs exactly as `SKILL.md`
§6 already says. **None of these activates it**: orca-crew or ossify merely
being installed; an environment variable; an `orca-execution.md` found on disk;
a `/plan-spine` run in a session that is not the top orchestrator. Discovery is
not authority — the phase begins because *this* session planned *this* spine.

## 2. The three layers

| Layer | Owns | Never |
|---|---|---|
| **Top orchestrator** (you) | ratifying one implementer/verifier profile per item, writing the sidecar, starting one spine session, approving or amending each relayed worker plan, the PR-transition reviewer decision, the merge | launching or supervising an item terminal; reading raw child completion traffic |
| **Spine session** | the ossify lane, a nested child Run, launching and supervising both item terminals per item, relaying plans up, item-local corrections | changing any ossify contract; moving item tasks into the parent Run |
| **Item terminals** | one item each: implement, verify | crossing into another item |

ossify itself owns what it always owned — worktrees, handoffs, closes, merges,
the round barrier — and knows nothing about any of the above.

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

- r7.s2.w1 — schema and interface work justify Opus 5 xhigh; GLM high provides
  an independent all-claims check.

## Excluded decisions

The spine-session profile follows this skill's existing lane-driver policy.
Reviewer profile and `/code-review` level are selected when the spine PR reaches
review.
```

**What varies is only the terminal command, the expected model, and the effort.**
The three procedures above are fixed for every item on every spine; they are
recorded so the spine session can check them, not so anyone can choose among
them. There is no reviewer row and no spine-session row — §8 and the excluded
block say why.

**Authoring it.** After `/plan-spine` finishes normally, recommend one
implementer and one verifier profile per item from that item's scope, risk and
cost. Present **every** row to the operator in one ratification phase and write
nothing until every row is decided — a half-ratified sidecar is a file that
looks binding and is not. Record the recommendation and any override.

**Reading it.** Before dispatching the spine session, and again before every
item launch, the reader checks: the current `SPINE.md` hashes to
`spine_plan_oid`; every planned item has exactly one complete row; no row names
an item the plan does not; `ratification` is present. The model reads this file
— no parser is added. Any failure halts. A profile that needs to change is a new
operator decision and a rewrite by you, never a substitution at dispatch time.

## 4. Nested depth is a prerequisite, not a fallback

Orca's `Settings → Orchestration → Nested worker depth` must be `2`, because the
spine session dispatches item sessions of its own. No CLI read exposes that
setting, so obtain the operator's confirmation before starting the spine
session; the first real child dispatch is the runtime proof.

If a child dispatch returns `nested_worker_depth_exceeded`, the spine session
stays the lane owner, reports the blocker, and waits for an operator decision.
It does not substitute a Claude subagent, move item tasks into the parent Run,
create a replacement writer, or restart the lane.

## 5. The nested Run

Your brief hands the spine session its parent identities explicitly
(`ossify-briefs.md`), and that session then creates and binds a **child Run** for
item tasks. Creating a Run does not reset nested depth.

- child `task-create`, `worker-start`/`dispatch` and `check` always name
  `--run $CHILD_RUN_ID`;
- plan, gap, depth and other spine-level questions come up to you as
  `ask --run $PARENT_RUN_ID`;
- replies to item questions go back on each original child message id;
- the spine session's final completion uses the **injected parent** task and
  dispatch ids, settling your Dispatch while the child Run is still bound;
- the spine session is the only waiter on the child Run; you are the only waiter
  on the parent.

The child Run is what keeps item plan traffic and item `worker_done` out of your
inbox. You see a batched plan relay, genuine spine-level decisions, and one
final spine completion.

## 6. The round procedure, as the spine session runs it

1. Validate `SPINE.md`, the sidecar and the round's item set (§3).
2. Invoke the ossify lane in external-executor mode. ossify prepares every
   same-round worktree and handoff first, then hands over one request per item.
3. For each item, launch a **fresh** implementer terminal and a **fresh**
   verifier terminal from that row's exact command. Where a custom alias is
   required, create the terminal directly and inject the Dispatch.
4. Each implementer confirms its model, reads, and posts a detailed plan, then
   waits. Gather the round's plans into **one** ordered ask to you; return an
   independent approve-or-amend per item; reply on each original child id. No
   edit starts before that reply lands.
5. On each complete return, capture the item's four-part fingerprint and launch
   that item's verifier in the same worktree against the fixed all-claims
   procedure. `cannot determine` counts as fail.
6. On a verifier failure, send one consolidated correction to the **same**
   implementer terminal, then the full recheck to the **same** verifier. A
   second failure escalates to you. A replacement writer is never created
   silently.
7. Initial gaps are handled inside the spine session: it asks you for the
   operator's answers, remains the handoff writer, appends clarifications, and
   re-dispatches the same live implementer within ossify's three-attempt cap.
8. Feed accepted results into the lane in declared decomposition order. Keep
   each pair until its item closes or escalates, then release it. **No terminal
   is ever transferred to another item.**

Same-round pairs may run concurrently. Closes and merges stay serial and the
round barrier is ossify's, unchanged.

## 7. Scope of the fresh-pair rule

Fresh-per-item pairs are scoped to **activated ossify spines**. Outside them,
`roles.md`'s generic class routing and retention are unchanged and remain
authoritative — an implementer retained across ordinary consecutive work items
is still correct there.

## 8. The reviewer is chosen later

Reviewer profile is absent from spine planning and from the sidecar on purpose:
the PR does not exist yet, and a profile chosen before there is a diff to read is
a guess recorded as a decision. At the spine PR transition, ask separately for
the reviewer's command, expected model, effort and `/code-review` level, record
it in the reviewer task's own brief, and run the review from there. Neither the
spine session nor the sidecar selects it.

## 9. Briefs

Every brief this phase needs — spine session, item implementer, item verifier,
and the correction message — is in `references/ossify-briefs.md`. The five
generic templates in `references/briefs.md` are unchanged and still apply
everywhere else.
