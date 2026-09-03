# Roles

One session owns each active role. A session's name or suffix is not its identity: when
resuming, ask each candidate to state its role and assignment and wait for the reply
before sending work.

| Role | Alias | Effort | Lifetime | Class |
|---|---|---|---|---|
| Orchestrator | `claude` (Fable) or `claude-sol` | alias default | one per Run; the operator launches it | always |
| Implementer, planned | `claude-glm` | high by default; `--effort max` on demand | retained across work items and the PR's fix rounds, to the threshold below | `contract`: an interface, schema, contract, or architectural change, or a plan gate needed; the default when unclassified |
| Implementer, fast | `claude-glm-flash` | alias default | retained if a fix round follows, else released | `bounded`: one-file, mechanical, read-heavy |
| Reviewer | `claude-glm-flash` | alias default | disposable; released after `worker_done` | once per PR; first task `/code-review <PR>`; never implements |
| Verifier | `claude-glm` | high | retained until its item passes or escalates to the operator | the work-item verify, whose claims include judgment; `claude-glm-flash` covers read-only probes and mechanical runs outside it (a suite, a count, a fact) |
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

The session that built the PR fixes the PR, and an implementer is retained across
consecutive work items. Attach its next task with `worker-start --task <next>
--terminal <handle>` so Orca transfers ownership. At each task boundary send
`/context` to the live terminal and read the one reply — the orchestrator's one
context source: past half its window, as `/context` reports, or an auto-compact, the
next item goes to a fresh implementer. The implementer returns its handoff inputs in
`worker_done`; the orchestrator writes the handoff into the next brief. Rotation
happens between work items, never mid-PR: the retained implementer finishes the PR's
fix rounds unless the harness auto-compacts. The reviewer
owns nothing durable and is released the moment its `worker_done` is processed; the
verifier seat is retained across a fail-and-fix cycle on the same item — the re-check
attaches its task to the same verifier — and is released only when the item passes or
goes to the operator. If `worker-release` retains a terminal you created with `terminal create`,
close it with `orca terminal close`; read the release receipt rather than assuming.

## Session budget

One implementer seat and one verifier seat per work item; one reviewer per PR. A fix
round may re-use the verifier seat, and a context-rotation replacement occupies the
seat it replaces. Any session outside those seats is a planning defect: stop and
re-plan the item. A further read-only question goes to the existing verifier or
implementer by `send`, never to a new session.

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
