# The run

One Run per objective. The orchestrator drives these thirteen steps and nothing else.
Every command's syntax comes from `orca skills get orchestration`.

1. **Orient.** Your first Orca command is `orca skills get orchestration`; every
   command's syntax comes from that guide. Single-command probes only: branch,
   `git status`, open PRs, `orca status --json`, `orca orchestration task-list --brief
   --json`. Then `run-create --objective "<objective>"`, or `run-use` when resuming a
   Run the operator names.
2. **Decompose.** One `task-create` per brief, `--deps` for the DAG, each carrying its
   complexity class — `contract` or `bounded` — in the spec; when ossify `plan-spine`
   wrote the class on the work item, copy it. One implementer per worktree. Items
   within a round may run in parallel; their merges are serial.
3. **Launch.** `terminal create --command "<alias>"` in the target worktree, then
   `terminal wait --for tui-idle`, then one `terminal read` of the banner to confirm
   the model, then `dispatch --inject` (the mechanic in `roles.md`). The "state your
   model" line in the worker's first reply is the second check. Wrong model: release
   and report.
4. **Plan gate, planned work only.** The `claude-glm` brief says: post your plan with
   `orca orchestration ask`, wait for the reply, then implement. Approve or amend via
   `reply`. Flash briefs skip this.
5. **Wait.** Rolling `check --wait --types worker_done,escalation,question`. Process the
   whole Delivery, answer every `question`, ack, wait again. A timeout is a checkpoint.
   `worker-read` only on `escalation` or a failed `worker_done`. At each task boundary
   for a retained implementer, send `/context` and read the one reply before attaching
   the next task (the threshold is in `roles.md`).
6. **Implementer finishes.** Its `worker_done` names the branch, head SHA, the test
   command with its result, and the PR it opened. Check the PR with one
   `gh pr view <number> --repo <owner/repo>` and read CI from
   `commits/<sha>/check-runs` plus the commit statuses when the repo's CI reports
   through the Status API instead of Checks, never the status rollup, both fetched
   against `--repo <owner/repo>`. These reads are the floor's PR-gate probes — identity
   and state from the first, CI for the named SHA from the rest — and anything beyond
   reading them becomes a verifier dispatch.
7. **Verify, once per work item.** One verifier session per work item, one brief
   listing every claim: the suite result on the head SHA, each acceptance criterion,
   the mutation of any new test, and the diff against the requirement. `claude-glm`
   at high unless every claim is mechanical. A fail returns to the implementer as one
   fix message; a second fail on the same item goes to the operator.
8. **Review.** A review runs exactly once per PR: `claude-glm-flash` in a fresh worktree
   at the PR head, brief `/code-review <PR>`, every finding returned in the `worker_done`
   body as file, line, severity, claim. The reviewer posts nothing to GitHub and edits
   nothing, so that body is the sole copy of the review. Release the reviewer only after
   its `worker_done` validates — findings lines present in the stated schema, reviewed
   head equal to the PR head; on a malformed body, send one bounded correction request
   before release.
9. **Disposition.** Each finding becomes **fix**, **defer** as a tracked issue, or
   **reject** with a reason. Post that list as one PR comment so it survives the session.
10. **Fix rounds.** The retained implementer gets the fix list plus the GitHub thread
    stream (Codex, CodeRabbit, humans) and works to zero unresolved threads by GraphQL
    `reviewThreads` count, pushing as it goes. Every surviving thread ends in exactly one
    terminal state: **fixed**, resolved only after the fix is on the head the reviewer
    can see; **deferred**, resolved with a comment linking the tracked issue; or
    **rejected**, resolved with the evidence. P0 and P1 findings are never deferred. A
    new bot or human finding that arrives after the disposition returns to the
    orchestrator via `ask` or `worker_done` — the implementer resolves a thread only
    after the orchestrator's decision (#410). No second `/code-review`. Bot comments
    after each push stay in this stream, and review bodies and top-level PR
    conversation comments are part of it too — `reviewThreads` does not return them —
    refreshed after each push alongside the thread count. With ossify installed, this
    dispatch is `/ossify:work-pr <PR> --repo-root <worktree holding the PR branch>`
    with the disposition embedded as a third signal.
11. **Stopping rule, agreed before the PR opens.** Default: when a round does not shrink
    or fixes generate new findings, stop fixing and defer the remaining P2s as tracked
    issues. A P1 is never deferred. A PR that reaches round five halts the deferrable
    work and examines process, not code; P0 and P1 remediation continues past round
    five until each is fixed or rejected with evidence.
12. **Merge gate.** Fetch the full gate set against `--repo <owner/repo>` for the head
    SHA immediately before asking: `isDraft`, `mergeable`, `mergeStateStatus`, every
    relevant check-run and status context — all must be successful — the unresolved
    threads, and the non-thread signals of review bodies and PR conversation comments.
    Ask only when every one is clean: a non-mergeable state is surfaced to the operator
    as the blocker instead of asking, and a new actionable finding returns to step 10.
    Ask the operator for the merge word naming that SHA.
    Merge only on that word, as a merge commit, never a squash, bound to the approved
    SHA: re-fetch the same full gate set for that SHA once more, then
    `gh pr merge <number> --repo <owner/repo> --merge --match-head-commit <sha>` —
    the orchestrator often sits in a checkout other than the PR's repository, so every
    read and the merge itself always name the repo. The read and the merge are two
    operations, so a signal can still land between them: the operator's ruleset
    requires conversation resolution, GitHub itself refuses the merge while any thread
    is open, and a merge refused that way returns to step 10, never a retry. Then
    release every worker, close the Run, and delete the branch only after confirming
    a merged PR exists whose head OID equals the branch tip.
13. **Handoff.** If the Run outlives the session, write a handoff naming the Run id,
    task ids, terminal handles, head SHA, and the next step. With ossify installed, that
    is `/ossify:handoff`.
