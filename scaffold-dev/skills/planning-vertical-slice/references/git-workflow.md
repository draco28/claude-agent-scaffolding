# scaffold-dev git workflow (merge modes)

Shared reference for `planning-vertical-slice`, `closing-vertical-slice`, and
`writing-sprint-retrospective`. Defines how slice/sprint work reaches `main`.
Behavior is selected by `during_dev.merge_mode` (read via `sd merge_mode`).

## Modes

- **`direct`** (default / unset) — today's behavior, **byte-for-byte unchanged**.
  Work-item branches merge locally (`--no-ff`) into `.canonical.default_branch`.
  No remote, no `gh`, no PR. Nothing in this doc's `pr_hierarchical` sections runs.
- **`pr_hierarchical`** — a three-tier integration hierarchy with PR gates:

```
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
- `sd branch_create_from <base> <new>` → idempotent branch create in canonical.
- `sd branch_push <branch>` → push to origin; errors if no remote.
- `sd remote_check` → verify origin remote + authenticated `gh`.
- `sd pr_open <head> <base> <title> <body-file>` → `gh pr create`; echoes PR url.
- `sd pr_state <pr>` → raw `gh pr view --json …` (mergeStateStatus, statusCheckRollup,
  reviews, reviewThreads, latestReviews, comments). NO interpretation.
- `sd pr_merge <pr> [--auto]` → `gh pr merge`.

Branch names: `sd`-internal helpers `_sd_sprint_branch_name <sprint_id>` (default
`sprint-{sprint_id}`) and `_sd_slice_branch_name <vs_id>` (default `slice/{vs_id}`),
configurable via `during_dev.sprint_branch_naming` / `during_dev.slice_branch_naming`.

## Slice-ordering rule (pr_hierarchical)

A slice's PR into `sprint-N` is expected to merge **before** the next slice branches
off `sprint-N`. If a prior slice PR is still open when the next slice starts, SURFACE
it — *"VS-N.M.1's PR is still open; merge it before branching VS-N.M.2 off sprint-N,
or proceed knowing slice-2 won't include slice-1's commits"* — and wait for the user.
Never silently branch off a stale `sprint-N`.

## Agent-driven pre-merge gate (BINDING — judgment, not bash)

Before merging ANY PR (slice→sprint or sprint→main), the orchestrator:

1. Calls `sd pr_state <pr>` → full state (CI rollup **and** review threads/comments).
2. Reasons over the FULL state — **not just** `statusCheckRollup` / `mergeStateStatus`:
   - Review-app and human review **comments** are usually NOT modeled as required
     status checks, so `mergeStateStatus == CLEAN` can coexist with an unresolved
     review finding. Account for review comments from **any review source** (the
     Codex GitHub app today; generic so it survives any reviewer change).
   - If the latest commit postdates the newest bot review, a re-review is likely
     still incoming — note that.
3. SURFACES unresolved review comments + CI state to the user and ASKS.
   **Never auto-merge over un-addressed review findings without explicit user
   acknowledgment.**
4. On the user's decision: `sd pr_merge <pr> [--auto]`, leave open, or wait.
   The gate does NOT busy-wait / poll the conversation on CI.

This is non-enforced guidance to the agent — deterministic checks stay only for the
mechanical git/`gh` facts above.

## Degradation

`pr_hierarchical` but missing `gh` / not authenticated / no origin remote → the
orchestrator REFUSES at planning pre-flight (`sd remote_check`) with the actionable
message. No silent fallback to `direct`.
