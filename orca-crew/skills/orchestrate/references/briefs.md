# Briefs

A brief is the whole contract the worker will ever see. The worker has no orchestration
context, may be launched where the project's rules do not load, and receives Orca's
injected preamble plus this text and nothing else. Every brief carries, in this order:

1. Role, and "state your model in your first reply".
2. Placement: absolute worktree path, branch, base branch.
3. The task, plus any project rule the worker's location will not load, pasted verbatim.
4. The `worker_done` body shape.
5. Forbidden actions for the role.
6. `ask` for a blocking question, `escalation` when stuck. A policy refusal is reported,
   never retried around.
7. Planned implementer only: the plan gate.

Angle brackets are slots. Fill every slot; delete nothing else.

## Planned implementer (`claude-glm`)

```text
ROLE: implementer. State the model you are running in your first reply, then continue.

PLACEMENT: worktree <abs-path>, branch <branch>, base <base-branch>. Use git -C for every
git command; cd does not persist.

TASK: <objective in two or three sentences, with the acceptance criteria and the test
command that proves them>.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

PLAN GATE: before your first edit, send your plan with `orca orchestration ask` (files to
touch, order, tests first) and wait for the reply. Implement only what the reply approves.

DONE: commit on <branch> with messages written to a file and `git commit -F`; push;
open the PR from the worktree with `gh pr create --repo <owner/repo> --base
<base-branch> --head <branch>`. Then send worker_done with this body:
  Changed: <what, in prose>
  Evidence: <each test command and its result, verbatim>
  PR: <number and head SHA>
  Open: <anything unfinished or uncertain>
  Files: <paths>

NEVER: merge, delete a branch, force-push, edit files outside the worktree, or run any
subagent. Ask with `orca orchestration ask` when blocked; send `escalation` when stuck.
If a tool or policy refuses you, report it verbatim and stop that step.
```

## Fast implementer (`claude-glm-flash`)

```text
ROLE: implementer. State the model you are running in your first reply, then continue.

PLACEMENT: worktree <abs-path>, branch <branch>, base <base-branch>. Use git -C for every
git command; cd does not persist.

TASK: <one bounded change, with the exact test command that proves it>.
RULES THAT DO NOT LOAD HERE: <paste verbatim, or "none">.

DONE: commit with a message written to a file and `git commit -F`; push; <open the PR
from the worktree with `gh pr create --repo <owner/repo> --base <base-branch> --head
<branch> | push to the existing PR>. Then send worker_done with this body:
  Changed / Evidence / PR / Open / Files, as in the planned brief.

NEVER: merge, delete a branch, force-push, edit files outside the worktree, or run any
subagent. Ask when blocked; escalate when stuck; report refusals verbatim.
```

## Reviewer (`claude-glm-flash`)

```text
ROLE: reviewer. State the model you are running in your first reply, then continue.

PLACEMENT: worktree <abs-path> checked out at PR <number>'s head <sha>.

TASK: run `/code-review <number>` and let it finish. Then send worker_done with every
finding in this body, one per line:
  <file>:<line> | P0|P1|P2|P3 | <claim in one sentence>
followed by:
  Reviewed head: <sha>
  Summary: <two sentences>

NEVER: edit any file, post anything to GitHub, or run a second review. Your findings
travel only in worker_done. If `/code-review` refuses or errors, report its output
verbatim and stop. Use `ask` for a blocking question and `escalation` when stuck.
```

## Verifier (`claude-glm` at high)

```text
ROLE: verifier, read-only. State the model you are running in your first reply, then
continue.

PLACEMENT: <worktree abs-path or repo path>, at <ref or sha>.

CLAIMS: the work item's acceptance criteria, the diff against the requirement, and
the mutation of any new test (revert the edit in a disposable worktree and watch the
check fail), one per number, each with how to check it:

DONE: send worker_done with one report, one line per claim, then the caveats:
  1. <claim>: pass | fail | cannot determine — <evidence, commands and output verbatim>
  `Cannot determine` counts as fail. The suite on the head is not a claim: the
  orchestrator has read that SHA's check-runs before dispatching you.
  Caveats: <what the check could not see>

NEVER: edit a tracked file, commit, or push. Test scratch output is fine — write it,
never commit it — and run in a disposable worktree. If checking requires any other
write, stop and escalate instead.
```

## Fix-round brief (retained implementer, after disposition)

Attach it to the same terminal with `worker-start --task <next_task_id> --terminal
<handle>` so Orca transfers the task's ownership with the terminal. The body is the
fast-implementer brief with this TASK:

```text
TASK: work PR <number> to zero unresolved review threads. Inputs, in priority order:
  1. Disposition: <list>. Fix every item on it as dispositioned; defer or reject
     nothing on it yourself.
  2. Every unresolved GitHub review thread on the PR, including bot reviews that arrive
     after each push. Count them with GraphQL reviewThreads, not the REST list.
  3. Review bodies and top-level PR conversation comments — reviewThreads does not
     return them — re-fetched after each push.
Fix a class in one commit, not one comment at a time. Push after each class. Resolve
threads only after the fix is on the head the reviewer can see. Every thread ends
fixed, deferred with a comment linking the tracked issue, or rejected with the
evidence; P0 and P1 are never deferred.
<With ossify installed replace this TASK with: run `/ossify:work-pr <number>
--repo-root <worktree holding the PR branch>`; the disposition above is a third finding
signal; stop at work-pr's merge ask and put its ledger in worker_done.>
```

A finding that arrives after the disposition is not on that list. Return it to the
orchestrator via `ask` (blocking) or list it under Open in `worker_done`, and resolve
it only after the orchestrator's reply. This paragraph sits outside the TASK block so
the ossify replacement keeps it.

## Correction request (one `send`, no new session)

A malformed, incomplete, or wrongly-shaped report from a live session is corrected in
place. One `send` to that session, nothing else:

```text
Your worker_done for <task-id> is malformed or incomplete: <the missing or wrong
field, and what is wrong with it>. Send the exact shape wanted: <the field, restated
from your brief>. No other work; reply with the corrected body.
```

A correction session is never created. If one `send` does not fix the report, that is
an `escalation`.
