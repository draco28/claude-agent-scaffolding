# scaffold-dev git workflow (merge modes)

Shared reference for `planning-vertical-slice`, `closing-vertical-slice`, and
`writing-sprint-retrospective`. Defines how slice/sprint work reaches `main`.
Behavior is selected by `during_dev.merge_mode` (read via `sd merge_mode`).

## Modes

- **`direct`** (default / unset) — today's behavior, **byte-for-byte unchanged**.
  Work-item branches merge locally (`--no-ff`) into `.canonical.default_branch`.
  No remote, no `gh`, no PR. Nothing in this doc's `pr_hierarchical` sections runs.
- **`pr_hierarchical`** — a three-tier integration hierarchy with PR gates:

```text
main  ───────────────────────────────●   PR: sprint-N → main   (protected; real CI + review gate)
  └─ sprint-N                  (off main; whole sprint)
       ├─ slice/VS-N.M.1       (off sprint-N)
       │    ├─ work-item branches → DIRECT local --no-ff merge → slice branch
       │    └─ then  PR: slice/VS-N.M.1 → sprint-N   (CI + review gate)
       └─ slice/VS-N.M.2       (off sprint-N, after slice-1's PR merges)
```

- work-item → slice: direct local merge (no PR; already gated by implementation-checking).
- slice → sprint-N: PR at slice close.
- sprint-N → main: PR at sprint close.

## Deterministic primitives (mechanical only — `lib/pr.sh`)

Invoke via the `sd` dispatcher. Each does ONE git/`gh` op; the agent reasons over output.

- `sd merge_mode` → `direct` | `pr_hierarchical`.
- `sd branch_create_from <base> <new>` → idempotent local-branch create. If
  `origin/<new>` exists (the integration branch already advanced remotely — fresh
  clone / deleted local), it REUSES `origin/<new>`; only falls back to `<base>` for
  the first slice (no `origin/<new>` yet).
- `sd branch_push <branch>` → push to origin; errors if no remote.
- `sd branch_sync <branch>` → fetch + fast-forward the local `<branch>` to
  `origin/<branch>` before reusing it as a base (an integration branch advances on
  the remote when a child PR merges); ff-only, no-op without a remote/remote-branch.
  **HARD-FAILS (rc 1)** if the local branch has diverged or can't be fast-forwarded —
  callers must halt rather than build off a stale/diverged base.
- `sd remote_check` → verify origin remote + authenticated `gh`.
- `sd sprint_branch_name <sprint_id>` / `sd slice_branch_name <vs_id>` → branch
  names from manifest templates.
- `sd pr_open <head> <base> <title> <body-file>` → `gh pr create`; echoes PR url.
- `sd pr_state <pr>` → raw `gh pr view --json …` (mergeStateStatus, statusCheckRollup,
  reviews, latestReviews, comments, reviewDecision, commits). NO interpretation.
  **Does NOT include line-level review comments** — `gh pr view` returns review
  summaries + conversation comments only.
- `sd pr_review_comments <pr>` → raw `gh api …/pulls/<pr>/comments` JSON — the
  INLINE (line-level) review comments where a bot (Codex/CodeRabbit) or human
  leaves findings. NO interpretation. The pre-merge gate MUST call this in addition
  to `sd pr_state`.
- `sd pr_merge <pr> [--auto]` → `gh pr merge --merge` by default; callers may pass
  `--rebase` or `--squash` explicitly.

Branch names: `sd sprint_branch_name <sprint_id>` (default `sprint-{sprint_id}`)
and `sd slice_branch_name <vs_id>` (default `slice/{vs_id}`),
configurable via `during_dev.sprint_branch_naming` / `during_dev.slice_branch_naming`.

## Slice-ordering rule (pr_hierarchical)

A slice's PR into `sprint-N` is expected to merge **before** the next slice branches
off `sprint-N`. If a prior slice PR is still open when the next slice starts, SURFACE
it — *"VS-N.M.1's PR is still open; merge it before branching VS-N.M.2 off sprint-N,
or proceed knowing slice-2 won't include slice-1's commits"* — and wait for the user.
Never silently branch off a stale `sprint-N`.

## Agent-driven pre-merge gate (BINDING — judgment, not bash)

Before merging ANY PR (slice→sprint or sprint→main), the orchestrator:

1. Calls **both** `sd pr_state <pr>` (CI rollup + review summaries + conversation
   comments) **and** `sd pr_review_comments <pr>` (the INLINE line-level review
   comments). Both are needed — `gh pr view` omits inline comments, so `pr_state`
   alone would miss exactly the findings bots leave. `sd pr_state` already gives
   `statusCheckRollup`, reviews, comments, and commits; the agent reads those signals
   and reasons over them.
2. Resolves every reviewer finding through the loop below before merge. P1/blocking
   findings are fixed first; non-blocking findings accepted at merge become a tracked
   deferral, not a silent pass.
3. Checks reviewer-completeness from the actual review/comment signal. A green check is
   not proof a reviewer ran, a skipped reviewer is not approval, and a queued or
   in-progress reviewer must be waited for. If a fix commit lands after a review, that
   stale verdict needs re-review on the new head; it is not absent or ackable.
4. Surfaces the disposition ledger, CI state, and reviewer status to the user, then asks
   whether to merge, wait, or leave the PR open. The gate does NOT busy-wait / poll the
   conversation on CI.

CodeRabbit's default configuration is the common illustration: it may skip auto-review
on a slice→sprint PR because that base is non-default, while sprint→main targets the
default branch and receives normal review. Confirm CodeRabbit ran by finding its actual
review/comment on the PR, not by trusting CI status alone; repositories can configure
base branches differently.

### Finding-disposition loop (every PR with findings)

Each reviewer finding (inline or summary) gets a recorded disposition before merge:

- A P1/blocking finding (correctness, security, data loss, broken contract) MUST be
  fixed before merge. It is never ack-to-merge and never eligible for deferral.
- A non-blocking finding is fixed or deferred. Deferral means a tracked issue or explicit
  note, recorded as `deferred → #N`; it is not waved through.
- A fix pushes a new commit and records `fixed in <sha>` only after the reviewer signal
  is current on that head.

This is binding agent judgment, not a script. Deterministic checks stay only for mechanical git/`gh` facts; do not grow this gate into bash reviewer semantics.

## Degradation

`pr_hierarchical` but missing `gh` / not authenticated / no origin remote → the
orchestrator REFUSES at planning pre-flight (`sd remote_check`) with the actionable
message. No silent fallback to `direct`.
