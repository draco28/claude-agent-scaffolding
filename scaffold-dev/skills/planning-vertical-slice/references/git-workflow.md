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
   alone would miss exactly the findings bots leave. Fetch **after every configured
   reviewer has had time to post** — some apps post minutes after the others settle
   (the Codex app lands ~minutes late), so a first-glance read taken the moment CI
   goes green misses a still-incoming review.
2. Reasons over the FULL state — **not just** `statusCheckRollup` / `mergeStateStatus`:
   - Review-app and human review **comments** (including the **inline** ones from
     `sd pr_review_comments`) are usually NOT modeled as required status checks, so
     `mergeStateStatus == CLEAN` can coexist with an unresolved review finding.
     Account for review comments from **any review source** (the Codex GitHub app
     today; generic so it survives any reviewer change).
   - **Reviewer completeness — a `SUCCESS` check is NOT proof a reviewer ran.** A
     configured/expected review app can report green while having **skipped** the
     review. Judge each reviewer by its actual terminal signal on the **head commit**,
     not a bare check `conclusion`: read the **review / conversation comment body**
     (returned by `sd pr_state` in `reviews` + `comments`). A **terminal** non-verdict —
     *skipped / disabled* — is **absent (not green)**, never approval. A **transient**
     one — *queued / pending / in-progress* — is **not yet a verdict**: wait for or
     re-trigger it and confirm on the head; never treat it as approval *nor* ack it as
     absent. Canonical case (CodeRabbit's **default** config):
     **CodeRabbit disables auto-review** on any base branch other than the repo default
     (a repo can widen this via `reviews.auto_review.base_branches` — confirm from the
     actual signal), so a `slice/* → sprint-N` PR (non-default base) is normally **not
     auto-reviewed**; CodeRabbit leaves the comment
     *"Review skipped — auto reviews are disabled on base branches other than the
     default branch."* (The `sprint-N → main` PR has the default base, so it IS
     auto-reviewed.) Remediation: surface for ack and/or trigger the reviewer
     (`@coderabbitai review`, `@codex review`) and wait for its terminal verdict on the
     head commit before merge.
   - **Staleness — a review counts only on the head sha.** Once a fix commit lands (see
     the disposition loop below), a verdict made against an earlier commit is stale; a
     fresh re-review must confirm on the **new head sha**. Detect it from `sd pr_state`:
     a review whose `submittedAt` predates the head `commits[-1].committedDate` is stale.
     This timestamp proxy can over-count freshness in one edge case — a commit authored
     before a review but **pushed after** it (the reviewer never saw the new head) — that
     an exact per-review `commit_id` comparison would catch; `sd pr_state` surfaces
     neither that commit id nor the per-check `description`, so closing that edge needs a
     dedicated `sd` primitive (deferred follow-up). When the proxy is ambiguous,
     **re-trigger the reviewer and confirm on the head** rather than trust the dates. A
     latest commit with no review yet ⇒ re-review still incoming — note it; don't treat
     absence as approval.
3. SURFACES unresolved review comments + CI state + any absent/stale reviewer to the
   user and ASKS. A **P1/blocking finding is NEVER ack-to-merge — it MUST be fixed
   first** (severity bar below). A non-blocking finding the user accepts at merge is
   **deferred, not waved through** — record it `deferred → #N` via the disposition loop
   below. An **absent / skipped reviewer** (never ran) may be acked; a **stale verdict**
   (a fix commit landed after it) is **NOT** ackable — it needs a fresh re-review on the
   new head per the loop's Fix step. **Never auto-merge over an un-dispositioned finding,
   an un-acked absent/skipped reviewer, a stale verdict awaiting re-review, or a blocking
   finding.**
4. On the user's decision: `sd pr_merge <pr> [--auto]`, leave open, or wait.
   The gate does NOT busy-wait / poll the conversation on CI.

### Finding-disposition loop (every PR with findings)

Each reviewer finding (inline or summary) gets a **recorded disposition** before merge —
the merge decision must stay auditable, not a vague "looks green":

- **Severity bar.** Classify each finding P1/blocking vs P2/nit. A **P1/blocking**
  finding (correctness, security, data-loss, a broken contract) **MUST be fixed before
  merge** — it is NOT eligible for merge-time deferral. Only **non-blocking (P2/nit)**
  findings are eligible for fix-or-defer.
- **Fix** → push a new commit, then trigger a re-review and **confirm it resolves on the
  new head sha** (a verdict on a prior sha is stale — see step 2). Record `fixed in <sha>`.
- **Defer** (P2/nit only) → file a tracked issue via **`deferring-work-item`** (it writes
  the `[TD] … → #N` index line). Record `deferred → #N`.
- Carry the per-finding dispositions (`fixed in <sha>` / `deferred → #N`) into the
  step-3 surface so the user acks a complete ledger.

This is non-enforced guidance to the agent — deterministic checks stay only for the
mechanical git/`gh` facts above.

## Degradation

`pr_hierarchical` but missing `gh` / not authenticated / no origin remote → the
orchestrator REFUSES at planning pre-flight (`sd remote_check`) with the actionable
message. No silent fallback to `direct`.
