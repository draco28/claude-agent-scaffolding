# ossify spine execution — assignments, the nested Run, and who owns what

A spine's work items each deserve their own model and effort; one dispatched lane driver
cannot give them that, because whatever it spawns inherits its runtime.

> **Editing note.** This file, `ossify-nested-run.md` and `ossify-briefs.md` are asserted
> to hold no subagent invocation form and to stay under 200 lines. Never paste the
> call shape.

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

The nested Run's mechanics — depth, routing, the round procedure and the close — are
in `references/ossify-nested-run.md`.

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
them rather than choose among them. No reviewer row, no spine-session row — §5 says why.

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


## 4. Scope of the fresh-pair rule

Fresh-per-item pairs are scoped to **activated ossify spines**. Outside them
`roles.md`'s class routing and retention remain authoritative — a retained implementer
across ordinary consecutive work items is still correct.

## 5. Two profiles are chosen at the PR, not before

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

## 6. Briefs

This phase's four briefs are in `references/ossify-briefs.md`; `references/briefs.md`'s
templates are unchanged and still apply elsewhere, its fix-round brief included (§5).
