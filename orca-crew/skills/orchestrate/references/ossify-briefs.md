# ossify spine briefs

The four briefs `ossify-execution.md` needs. Same rules as `briefs.md`: a brief
is the whole contract its reader will ever see, angle brackets are slots, fill
every slot and delete nothing else.

> **Editing note.** Asserted to contain no subagent invocation form
> (`tests/test-ossify-spine-contract.sh`). Say the prohibition; never paste the
> call shape.

---

## Spine session (one per spine, dispatched by the top orchestrator)

The lane driver, launched by this skill's existing lane-driver policy. It is
also a coordinator, which is why its brief carries parent identities it could
not otherwise know.

```text
ROLE: ossify spine session and nested coordinator. State the model you are
running in your first reply, then continue.

PLACEMENT: <abs path of the repo or worktree the lane runs from>.

INJECTED IDENTITIES — use these verbatim; do not rediscover them:
PARENT_RUN_ID=<run id>
SPINE_TASK_ID=<task id>
SPINE_DISPATCH_ID=<dispatch id>
SPINE_ID=<spine id>
ORCA_EXECUTION_PATH=<abs path to $SPINE_DIR/orca-execution.md>

TASK: drive spine SPINE_ID to its final round barrier.
  1. Read ORCA_EXECUTION_PATH and validate it against SPINE.md before anything
     else: `git hash-object "$(dirname "$ORCA_EXECUTION_PATH")/SPINE.md"` (the
     plan's blob id beside the sidecar) must equal spine_plan_oid; every planned
     item must have exactly one complete row; no row may name an item the plan
     does not; ratification must read exactly `operator-approved`;
     ratified_in_run must equal PARENT_RUN_ID; and spine_id must equal SPINE_ID.
     Any failure halts — ask, never substitute.
  2. Create and bind a CHILD Run for item tasks. Every child task-create,
     worker-start, dispatch and check names --run <child run id>. Every question
     for the top names --run PARENT_RUN_ID. Replies to item questions go on each
     original child message id.
  3. Run `/ossify:run-spine $SPINE_ID --external-executor`. When it hands you a
     round's execution requests, launch one fresh IMPLEMENTER terminal per item
     from that item's exact sidecar command — never a substitute command, model
     or effort. The verifier is not created here; step 5 creates it, once there
     is a complete return to verify. Confirm each model from the launch banner
     and the first reply; the effort is the launch argument you were given.
  4. Gather the round's implementation plans into ONE ordered ask to the top and
     wait. Relay the top's per-item decision to each implementer on its own
     original message id before any edit starts.
  5. On each complete return, create and dispatch that item's fresh VERIFIER
     terminal from its exact sidecar command and run the fixed all-claims
     procedure; `cannot determine` counts as fail. On failure send one
     consolidated correction to the SAME implementer, then the full recheck to
     the SAME verifier. A second failure escalates to the top.
  6. Return accepted results to the lane in declared decomposition order. Keep
     each pair until its item closes or escalates; never move a terminal to
     another item.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: release every item pair first — no terminal of yours outlives the spine —
then one worker_done using SPINE_TASK_ID and SPINE_DISPATCH_ID, the injected
parent ids, so the top's Dispatch settles while your child Run stays bound:
  Changed / Evidence / Open / Files, as in the planned-implementer brief, and
  name the child Run id you bound so the top can find it afterwards.
The spine is at its final round barrier when you finish; the close ceremony is
the top's and runs after this worker_done — and if the top attaches that close
here as a follow-up task, its return names EVERY PR the close opened, repo and
number, one per hosting repo.

NEVER: launch an item terminal in the parent Run; run a Claude subagent for a
work item; fall back to the default nested dispatch after a depth error;
restart the lane; select the reviewer; run `/ossify:close` on your own — the top
dispatches that close as a task, and you run it only when it attaches one. On
`nested_worker_depth_exceeded`, stay alive, report it to the top, and wait for
the operator's decision.
```

---

## Item implementer (one fresh terminal per work item)

Launched from the sidecar row's `implementer_terminal_command` exactly.

```text
ROLE: ossify work-item implementer for <work-item-id>. State the model you are
running in your first reply, then continue.

PLACEMENT: worktree <abs path>, branch <branch>, base <base-branch>. Use git -C
for every git command; cd does not persist.

BEFORE ANY EDIT, in this order:
  1. Confirm the model you are running is <expected model>. If it is not, stop
     and report — do not continue on a substitute.
  2. Read <handoff path>, <spec path>, and the relevant source and tests. Change
     nothing.
  3. Send your implementation plan with `orca orchestration ask`: the files you
     will touch, the ordered steps, the RED test you will write per acceptance
     criterion, the verification commands, and the risks or deviations you
     expect. Then WAIT.
  4. Apply the decision that comes back — approved as written, or amended. Do
     not start on your own reading of it.

TASK: then run `/ossify:work-item <handoff path>` and let it complete. Its
contract binds you: stage, never commit; return its structured JSON.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: worker_done carrying the work-item return verbatim, plus:
  Changed / Evidence / Open / Files.

NEVER: commit, push, merge, edit outside this worktree, run a subagent, or work
a second work item. Ask when blocked; escalate when stuck; report a refusal
verbatim.
```

---

## Item verifier (one fresh terminal per work item, retained through corrections)

Launched from the sidecar row's `verifier_terminal_command` exactly. The
procedure is this skill's existing all-claims work-item verification — the
`briefs.md` verifier body, with these placements and this retention.

```text
ROLE: verifier for <work-item-id>, read-only. State the model you are running in
your first reply, then continue.

PLACEMENT: worktree <abs path>, at <head sha>, staged tree <tree oid>.

CLAIMS: <the numbered all-claims list from briefs.md's verifier template, filled
from this item's spec>.

DONE: worker_done with one line per claim — pass | fail | cannot determine, with
commands and output verbatim — then the caveats. `Cannot determine` counts as
fail.

NEVER: commit, push, or edit a tracked file outside the mutation check. Do not
verify a second work item; you are retained for this one until it passes or
escalates.
```

---

## Correction (a message to the live implementer, never a new session)

A verifier failure does not re-run the slash command — its clean-tree pre-flight
would correctly refuse the staged output. Send this to the same implementer
terminal, once, with every finding consolidated:

```text
OSSIFY CORRECTION CONTINUATION v1
handoff_path: <abs path>
work_item_id: <work-item-id>
expected_branch: <branch from the item's execution request>
expected_head_sha: <head oid from the accepted result>
expected_tree_oid: <tree oid from the accepted result>
failures:
- <one finding per line>
```

The implementer's own contract says what to do with it. Do not restate that
contract here, and do not send a second packet while the first is being worked.
