# ossify spine PR briefs — the close and the work-PR sessions

The two briefs the PR lane needs (`ossify-execution.md` §2, `ossify-nested-run.md`
§4). Same rules as `briefs.md`: a brief is the whole contract its reader will ever
see, angle brackets are slots, fill every slot and delete nothing else.

> **Editing note.** Asserted to contain no subagent invocation form
> (`tests/test-ossify-spine-contract.sh`). Say the prohibition; never paste the
> call shape.

---

## Close session (one fresh terminal per dispatch, created by the top)

It creates nothing and returns a list. Dispatched twice per spine at most: once
for the ceremony, once for the record pass.

```text
ROLE: ossify spine close for SPINE_ID. State the model you are running in your
first reply, then continue.

PLACEMENT: <abs path of the worktree the spine's lane ran from>.

INJECTED IDENTITIES — use these verbatim; do not rediscover them:
PARENT_RUN_ID=<run id>
CLOSE_TASK_ID=<task id>
CLOSE_DISPATCH_ID=<dispatch id>
SPINE_ID=<spine id>
CLOSE_REVIEW_LEDGER=<verbatim ledger from the first close, or "none">

TASK: run `/ossify:close SPINE_ID` and let it complete or halt. Whatever it hands
off, you do not drive: if it opens PRs and halts, that halt is your result.
The ceremony's own steps are yours to perform, including
the close review the ceremony itself runs over the accumulated diff before any PR
opens and the fix-now edits its findings require — that is `/ossify:close` doing
its job, not a `/code-review` you dispatch. On a record pass, write the accepted
findings CLOSE_REVIEW_LEDGER carries into the retrospective's carried-and-lessons
section, by class.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: one worker_done on CLOSE_TASK_ID and CLOSE_DISPATCH_ID carrying exactly one
of three results: EVERY PR the close opened — one line per hosting repo, `<repo>
#<number> <url>`; the single word `closed` when it recorded the spine with no PR
open; or `halted: <step> — <evidence>` when it stopped, naming the failing step and
repo and, on its own line, what it had already opened: `opened: <repo> #<n> <url> …`
or `opened: none`. A multi-repo close can open in one repo and halt on the next, so
a halt that hides those PRs strands them. A halt is a result, not a PR list with
none in it, and the top settles it without advancing the lifecycle. Whenever the
close review ran, carry its ledger verbatim too — each finding, its decision and
the reason — because the record pass runs in a different session and cannot
reconstruct it. Then:
  Changed / Evidence / Open / Files.

NEVER: create a terminal, merge, ask the operator anything (questions go up to the
top with `ask`), or re-invoke `/ossify:close` yourself — a halt settles this
dispatch, and once the blocker is remediated
the top dispatches a fresh close session. Report a refusal verbatim.
```

---

## Work-PR session (one fresh terminal per returned PR)

Created by the top **in that PR's hosting-repo worktree** — the one the close
landed from — so REPO_ROOT is the path this terminal already sits in, never a
fixed canonical path. It owns both PR seats inside a child Run of its own.

```text
ROLE: work-PR session for PR PR_NUMBER in PR_REPO, and coordinator of its two
seats. State the model you are running in your first reply, then continue.

PLACEMENT: REPO_ROOT — the worktree holding this PR's branch.

INJECTED IDENTITIES — use these verbatim; do not rediscover them:
PARENT_RUN_ID=<run id>
WORKPR_TASK_ID=<task id>
WORKPR_DISPATCH_ID=<dispatch id>
PR_REPO=<owner/repo>
PR_NUMBER=<number>
REPO_ROOT=<abs path of this terminal's worktree>
REVIEWER_COMMAND=<exact launch command>
REVIEWER_EXPECTED_MODEL=<model id the banner must show>
REVIEWER_EFFORT=<exact launch argument>
REVIEW_LEVEL=<the /code-review level the top decided>
PRFIX_COMMAND=<exact launch command>
PRFIX_EXPECTED_MODEL=<model id the banner must show>
PRFIX_EFFORT=<exact launch argument>
STOPPING_RULE=<the rule agreed before the PR opened>

TASK: drive PR_NUMBER to a merge on the top's word.
  1. Bind a CHILD Run for your two seats. Every seat's task-create,
     worker-start, dispatch and check names --run <child run id>; every question
     for the top names --run PARENT_RUN_ID.
  2. Create the reviewer FIRST, from REVIEWER_COMMAND at REVIEWER_EFFORT, confirm
     REVIEWER_EXPECTED_MODEL from its banner and first reply, and brief it to run
     `/code-review PR_NUMBER REVIEW_LEVEL`. Read the findings from its
     worker_done; it posts nothing itself, so that body is the only copy. Validate
     it against the reviewer brief's schema — `Findings: none`, or finding lines
     plus `Reviewed head:` and `Summary:` — before you pass anything on; on a
     malformed body send ONE bounded correction request to that reviewer and
     re-validate, and escalate a second malformed body to the top.
  3. THEN run `/ossify:work-pr $PR_NUMBER --repo-root $REPO_ROOT`,
     carrying those findings in as its disposition inputs.
     It owns the whole review-fix-merge
     loop, so starting it first would let it reach its merge ask on pre-existing
     signals with your review never run. In this seat its "drive the fixes" is a
     dispatch to the PR-fix seat — you edit nothing yourself — and its merge ask
     is the `ask` to the top in step 5.
  4. Disposition every finding — the reviewer's, the bot threads, and the
     review bodies and top-level PR comments that `reviewThreads` does not
     return — post the ledger, file deferrals as tracked issues in PR_REPO, and
     dispatch fix tasks to a PR-fix seat you create from PRFIX_COMMAND at
     PRFIX_EFFORT — confirm PRFIX_EXPECTED_MODEL from its banner and first reply
     before the first fix task, a mismatch being a failed launch to stop and ask
     about, never to work around. The reviewer seat is **retained until merge**:
     each time the PR-fix seat pushes, the head it reviewed is stale, so re-run
     `/code-review PR_NUMBER REVIEW_LEVEL` on the new head and feed those findings
     into the next disposition round. That is per head, not once per PR —
     `roles.md`'s once-per-PR reviewer governs the generic path, not this seat. Relay ONE batched summary per round to the top. STOPPING_RULE decides
     when fixing stops.
  5. When the gate is clean, `ask` the top for the merge word. On the reply,
     re-fetch the whole gate set once more and
     merge bound to the named SHA, as a merge commit. Then release both seats.

RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: one worker_done on WORKPR_TASK_ID and WORKPR_DISPATCH_ID returning PR_REPO,
PR_NUMBER, the merge SHA and every ledger comment id — checkable artifacts, never
narrative. Then: Changed / Evidence / Open / Files.

NEVER: talk to the operator — every question goes up to the top; squash; merge
without the top's relayed word; delete a branch; or review a head twice.
```
