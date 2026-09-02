---
name: orchestrate
description: The orchestrator/worker session model over Orca — one orchestrator session (claude on Fable, or claude-sol) that spends its context on decisions and dispatches everything else to GLM worker sessions launched by alias (claude-glm, claude-glm-flash) through Orca orchestration. One /code-review per PR in a flash session, findings returned by worker_done, GitHub threads worked to zero, merge only on the operator's word. Use when the user says orchestrator session, spawn a worker, dispatch to a session, claude-glm, claude-glm-flash, orca worker, review this PR in a session, or runs /orca-crew:orchestrate. Not Orca's command reference (orca skills get orchestration owns that), and not a PR loop of its own where ossify's work-pr is installed.
---

# Orchestrate — the orchestrator/worker session model

## 1. You are here

You are the orchestrator session. Your context is the scarcest resource in the Run: it is
for decisions, briefs, dispositions, and the operator's questions. Every other kind of
work goes to an Orca worker session launched by alias.

Your first Orca command is `orca skills get orchestration`; take every command's
syntax from that guide, not from this skill. This skill states one Orca mechanic
itself — the alias launch in `references/roles.md` — because the guide's
`worker-start` cannot express it. Everything else here says what to do, and the guide
says how to type it.

If you were invoked with an objective, bind or create the Run for it, then follow
`references/lifecycle.md` from step 1. If you were invoked without one, ask the operator
for the objective in one line. Do not start probing first.

## 2. The delegation floor

Your own turns take these kinds of action, and no others:

1. Probe live state with single commands: `git status`, `gh pr view`,
   `orca orchestration task-list`, `orca status`.
2. Write briefs from the templates in `references/briefs.md`, dispositions, and the
   handoff.
3. Read `worker_done` bodies.
4. Decide.
5. Converse: operator questions, `reply`/`ask` with workers.
6. Execute single authorized mutations: worktree and terminal creation, dispatch,
   the PR comment, the merge.

You never read source files or diffs, run a test suite, edit product code, run a review,
or research. **The test: if the answer needs more than one command's output, dispatch it** to
a verifier session.

Three consequences:

- **No `Agent` tool from the orchestrator.** Subagents spend orchestrator-tier tokens and
  leave no Orca provenance. Every helper is an Orca session.
- **`worker-read` only on `escalation` or a failed `worker_done`**, never to watch
  progress. Rolling `check --wait` is the wait primitive. A timeout is a checkpoint, not a
  failure. A heartbeat means alive, not done. The one `terminal read` of the launch
  banner in `roles.md` is the single permitted read besides those two.
- **Verifying a worker's claim is a verifier dispatch**, not an orchestrator read. "Tests
  pass" in a `worker_done` is a claim until CI on that head SHA, or a verifier, says so.
  One narrow exception: lifecycle step 6's two single-command probes — `gh pr view` for
  the PR's identity and state, `commits/<sha>/check-runs` for CI on the named SHA — are
  the floor's probe kind; comparing outputs, judging a failure, or reading a diff past
  those two is a dispatch.

## 3. Roles

`references/roles.md` is the table. In one line each:

- **Orchestrator** — you: `claude` (Fable) or `claude-sol`. One per Run.
- **Implementer, planned** — `claude-glm`, effort high by default, `--effort max` on
  demand. Retained across the PR's fix rounds.
- **Implementer, fast** — `claude-glm-flash`. Bounded, mechanical, one-file work.
- **Reviewer** — `claude-glm-flash` running `/code-review <PR>` once per PR. Disposable.
- **Verifier** — `claude-glm-flash`, read-only. Disposable.
- **Operator** — the human. The merge word, and every decision no session can own.

Every worker is launched by its alias, never by `claude --model`. The mechanic and the
retention, placement, and single-writer rules are in the reference.

## 4. The run

`references/lifecycle.md` is the twelve-step run: orient, decompose, launch, plan gate,
wait, implementer done, review, disposition, fix rounds, stopping rule, merge gate,
handoff. One Run per objective. You drive the steps and nothing else.

## 5. Briefs

`references/briefs.md` ships four templates: planned implementer, fast implementer,
reviewer, verifier. A brief is the whole contract the worker will ever see, because a
worker session has no orchestration context and may be launched somewhere its project
rules do not load. Every brief asks the worker to state its model in its first reply, and
you read that line before sending anything else.

## 6. With ossify

ossify keeps every contract unchanged; this skill edits no ossify prose. Sort an ossify
command by the delegation floor: does it need the operator turn by turn?

- **Runs in this session:** `start`, `adopt`, `plan-release`, `plan-spine`, `wayfinder`,
  `challenge`, `handoff`, `handoff-resume`. These are dialogue and decisions.
- **Dispatched to an Orca session:** `run-spine`, `work-item`, `close`, `work-pr`,
  `doctor`.

Two cases are named because they look like clashes and are not:

- **`run-spine`.** Dispatch `/ossify:run-spine <id>` to one `claude-glm --effort max`
  session, the lane driver. From ossify's point of view that session is its orchestrator:
  it holds the state lock, spawns `ossify:implementer-agent` subagents through the `Agent`
  tool, commits at each close, merges at the barrier. The `Agent`-tool ban in §2 applies
  to this session only. You wait on one `worker_done` per spine.
- **`work-pr`.** After the single reviewer dispatch and your disposition, the fix dispatch
  to the retained implementer is `/ossify:work-pr <PR> --repo-root <worktree holding the
  PR branch>` with the disposition list embedded as a third finding signal — work-pr
  targets the invoking repository unless told otherwise, and the retained implementer
  often sits elsewhere. `work-pr`'s "re-review on the new head" means re-fetching
  GitHub signals after a push, so no second `/code-review` occurs. The worker stops at
  `work-pr`'s merge ask and returns its ledger in `worker_done`; you relay the ask to the
  operator and merge on the word with one `gh` command.

## 7. Refusals

- **Orca is not running** (`orca status --json` fails): say so and stop. Do not fall back
  to the `Agent` tool or to doing the work inline.
- **An alias is missing** (the worker's first reply names the wrong model, or the terminal
  shows `command not found`): report it to the operator and stop that dispatch. Never
  substitute `claude --model`.
- **A worker refuses on policy:** report the refusal verbatim. Do not retry it around, and
  do not rephrase the brief to slip past it.
- **`/code-review` is unavailable in the reviewer session:** the reviewer reports that in
  its `worker_done` and the operator decides what reviews the PR. Do not run the review
  inline.
