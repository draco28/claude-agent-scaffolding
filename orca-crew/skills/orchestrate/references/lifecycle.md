# The run

One Run per objective. The orchestrator drives these twelve steps and nothing else. Every
command's syntax comes from `orca skills get orchestration`.

1. **Orient.** Your first Orca command is `orca skills get orchestration`; every
   command's syntax comes from that guide. Single-command probes only: branch,
   `git status`, open PRs, `orca status --json`, `orca orchestration task-list --brief
   --json`. Then `run-create --objective "<objective>"`, or `run-use` when resuming a
   Run the operator names.
2. **Decompose.** One `task-create` per brief, `--deps` for the DAG. One implementer per
   worktree. Items within a round may run in parallel; their merges are serial.
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
   `worker-read` only on `escalation` or a failed `worker_done`.
6. **Implementer finishes.** Its `worker_done` names the branch, head SHA, the test
   command with its result, and the PR it opened. Check the PR with one `gh pr view` and
   read CI from `commits/<sha>/check-runs`, never the status rollup. Anything CI does not
   cover becomes a verifier dispatch.
7. **Review.** A review runs exactly once per PR: `claude-glm-flash` in a fresh worktree
   at the PR head, brief `/code-review <PR>`, every finding returned in the `worker_done`
   body as file, line, severity, claim. The reviewer posts nothing to GitHub and edits
   nothing. Release it on receipt.
8. **Disposition.** Each finding becomes **fix**, **defer** as a tracked issue, or
   **reject** with a reason. Post that list as one PR comment so it survives the session.
9. **Fix rounds.** The retained implementer gets the fix list plus the GitHub thread
   stream (Codex, CodeRabbit, humans) and works to zero unresolved threads by GraphQL
   `reviewThreads` count, pushing as it goes. Every surviving thread ends in exactly one
   terminal state: **fixed**, resolved only after the fix is on the head the reviewer
   can see; **deferred**, resolved with a comment linking the tracked issue; or
   **rejected**, resolved with the evidence. P0 and P1 findings are never deferred. No
   second `/code-review`. Bot comments after each push stay in this stream. With ossify
   installed, this dispatch is `/ossify:work-pr <PR>` with the disposition embedded as
   a third signal.
10. **Stopping rule, agreed before the PR opens.** Default: when a round does not shrink
    or fixes generate new findings, stop fixing and defer the remaining P2s as tracked
    issues. A P1 is never deferred. A PR that reaches round five halts and examines
    process, not code.
11. **Merge gate.** Re-fetch check-runs and unresolved threads for the head SHA
    immediately before asking — the merge requires zero unresolved threads. Ask the
    operator for the merge word naming that SHA.
    Merge only on that word, as a merge commit, never a squash, bound to the approved
    SHA: re-fetch check-runs and unresolved threads for that SHA once more, then
    `gh pr merge <number> --repo <owner/repo> --merge --match-head-commit <sha>` —
    the orchestrator often sits in a checkout other than the PR's repository, so the
    PR and the repo are always named. The read and the merge are two operations, so a
    thread can still land between them: the operator's ruleset requires conversation
    resolution, GitHub itself refuses the merge while any thread is open, and a merge
    refused that way returns to step 9, never a retry. Then release every worker,
    close the Run, and delete the branch only after confirming a merged PR exists
    whose head OID equals the branch tip.
12. **Handoff.** If the Run outlives the session, write a handoff naming the Run id,
    task ids, terminal handles, head SHA, and the next step. With ossify installed, that
    is `/ossify:handoff`.
