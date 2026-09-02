# Roles

One session owns each active role. A session's name or suffix is not its identity: when
resuming, ask each candidate to state its role and assignment and wait for the reply
before sending work.

| Role | Alias | Effort | Lifetime | Pick when |
|---|---|---|---|---|
| Orchestrator | `claude` (Fable) or `claude-sol` | alias default | one per Run; the operator launches it | always |
| Implementer, planned | `claude-glm` | high by default; `--effort max` when the brief needs a plan first, touches an interface or contract, or a prior attempt failed | retained across the PR's fix rounds | multi-file work, new behaviour, anything that needs a plan |
| Implementer, fast | `claude-glm-flash` | alias default | retained if a fix round follows, else released | bounded, mechanical, one-file, fast |
| Reviewer | `claude-glm-flash` | alias default | disposable; released after `worker_done` | once per PR; first task `/code-review <PR>`; never implements |
| Verifier | `claude-glm-flash`; `claude-glm` only when the check needs judgment across many files | alias default | disposable; released after `worker_done` | any read-only research, check, audit, or claim verification the orchestrator would otherwise do itself |
| Operator | the human | | | the merge word, and decisions no session can own |

## The launch

**Alias, never `--model`.** Bare `claude --model glm-*` routes to the Anthropic default
and fails or silently serves the wrong model. `worker-start --agent claude` launches bare
`claude` and takes no custom alias. The launch is therefore this sequence, and it is the
one Orca mechanic this skill states itself (take the exact flags from
`orca skills get orchestration`):

```bash
orca terminal create --worktree <selector> --command "<alias> [--effort max]" --json
orca terminal wait --for tui-idle --terminal <handle> --json
orca terminal read --terminal <handle> --json
orca orchestration dispatch --task <task_id> --to <handle> --inject --json
```

Read `agentTerminalHandle` (or `startupTerminal.handle` on older runtimes) from the
create receipt for `--to`. The `wait` parks until the banner is up; the single `read`
of that banner confirms the model before anything is dispatched. Every brief also asks
the worker to state its model in its first reply — a second check, not the only one.
A wrong model is a failed launch: release the terminal and report it. Do not correct
it with `--model`.

## Retention follows artifacts

The session that built the PR fixes the PR. Attach its next task with
`worker-start --task <next> --terminal <handle>` so Orca transfers ownership. Reviewer
and verifier own nothing durable and are released the moment their `worker_done` is
processed. If `worker-release` retains a terminal you created with `terminal create`,
close it with `orca terminal close`; read the release receipt rather than assuming.

## Placement

In a dual-repo workspace, the orchestrator and implementers launch from the AI workspace
and address canonical worktrees explicitly, because a session launched inside the
canonical repo never loads the workspace's rules, memory, or handoffs. Reviewer and
verifier may launch inside a canonical worktree for a fresh frame, which is why their
briefs are self-contained. Single-repo projects launch everything in the repo or a
worktree of it.

## Writers

- **One writer per artifact.** A correction to a peer's file travels as `send`, never as
  a direct edit.
- **One implementer per worktree.** Two writers never share a checkout. Parallel items
  get parallel worktrees.
- **The orchestrator writes briefs, dispositions, and handoffs.** It writes no product
  file.
