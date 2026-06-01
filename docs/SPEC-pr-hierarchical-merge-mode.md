# SPEC — PR-hierarchical merge mode (scaffold-dev #40)

**Date:** 2026-05-31 · **Plugin:** `scaffold-dev` · **Target release:** v0.2.0 (minor — new opt-in feature)
**Issue:** [#40](https://github.com/draco28/claude-agent-scaffolding/issues/40) — *support PR-per-slice merge mode instead of hardcoded direct-merge to default_branch*
**Status:** Design approved (brainstorm 2026-05-31). Next: `writing-plans` → implementation.

> **Scope note — this expands #40.** The filed issue proposed `merge_mode ∈ {direct, pr_per_slice, pr_per_work_item}` with `pr_per_slice` merging the slice branch straight into `default_branch`. During brainstorming the design grew into a **three-tier sprint-integration hierarchy** (work-item → slice → sprint → main) with PR gates at the two upper boundaries. `pr_per_work_item` is explicitly **not** built (work-item→slice is a direct local merge). This SPEC is the authoritative design; #40's original sketch is superseded here.

---

## 1. Problem

scaffold-dev v0.1 **always direct-merges**: `lib/merge.sh::sd_merge_work_item` does a local `--no-ff` merge of each work-item branch into `.canonical.default_branch`. There is **no PR / CI-gate / review boundary** anywhere in the contract, and (confirmed during exploration) **no `git push` either** — the merge is purely local; the user pushes manually afterward.

Consequences:
- CI (if it triggers on push) runs **after** commits already land on `default_branch` — a red commit can reach the protected branch; you learn post-hoc.
- GitHub branch protection (required status checks) is unusable — there is no PR to gate.
- No reviewable, CI-gated, durable per-slice / per-sprint unit (diff + discussion + linked issues + review-bot findings).

This bites hardest in correctness-critical work where **green-before-merge** is the whole point.

## 2. Goal

An **opt-in, manifest-configured** merge mode that routes slice and sprint integration through CI-and-review-gated PRs, while leaving the default (`direct`) behavior **byte-for-byte unchanged**. The git workflow is **agent-driven where decisions are judgment calls, deterministic only for mechanical git/`gh` operations**, and documented once as a shared, CLAUDE.md-ready reference.

### Non-goals (v0.2.0)
- `pr_per_work_item` mode (enum stays extensible; not implemented).
- A per-project CLAUDE.md/WORKFLOW.md surfacing of the workflow (noted as a small scaffold-onboard follow-up; out of scope here).
- A `during_dev.review_apps` config naming specific bots (the pre-merge gate is generic over all review sources; YAGNI).
- Auto-polling / blocking the conversation on CI completion (the gate surfaces state and asks; it never busy-waits).

---

## 3. Branch topology (`pr_hierarchical`)

```text
main  ───────────────────────────────────────────────●   PR: sprint-N → main   (protected; real CI + review gate)
  └─ sprint-N                       (off main; lives the whole sprint)
       ├─ slice/VS-N.M.1            (off sprint-N)
       │    ├─ work-item branches  → DIRECT local --no-ff merge → slice branch
       │    └─ then  PR: slice/VS-N.M.1 → sprint-N   (CI + review gate)
       └─ slice/VS-N.M.2            (off sprint-N, started after slice-1's PR merges)
```

- `sprint-N` branches off `main` at the **first slice of the sprint**; it is the integration branch for the entire sprint and persists until sprint close.
- Each vertical slice branches off `sprint-N`. Work items happen on work-item branches/worktrees beneath the slice branch.
- **work-item → slice:** direct local `--no-ff` merge (already gated by `implementation-checking`; fast inner loop; no PR).
- **slice → sprint-N:** PR, opened at slice close (CI + review gate).
- **sprint-N → main:** PR, opened at sprint close (the protected, real gate).

### 3.1 Slice-ordering rule
A slice's PR into `sprint-N` is **expected to merge before the next slice branches off `sprint-N`**. If a prior slice PR is still open when the next slice starts, the orchestrator **surfaces it** — *"VS-N.M.1's PR is still open; merge it before branching VS-N.M.2 off sprint-N, or proceed knowing slice-2 won't include slice-1's commits"* — and waits for the user. Never silently branches off a stale `sprint-N`.

### 3.2 Worktree-cleanup decoupling
Because work items merge **locally** into the slice branch, the slice branch already holds all their commits. Work-item worktree/branch cleanup is therefore **decoupled from the slice PR** — the existing "cleanup after harvest" (M2 marker) order in `closing-vertical-slice` is unchanged and does **not** need to gate on PR merge. (This dissolves the async-cleanup tension #40 anticipated, which assumed work-items PR'd straight to the protected branch.)

---

## 4. Configuration — manifest `during_dev`

| Key | Default | Values / meaning |
|---|---|---|
| `merge_mode` | `direct` | `direct` (unset = this) \| `pr_hierarchical` |
| `sprint_branch_naming` | `sprint-{sprint_id}` | template; `{sprint_id}` is the dotted id, e.g. `sprint-1.1` |
| `slice_branch_naming` | `slice/{vs_id}` | template; `{vs_id}` is the 3-part id, e.g. `slice/VS-1.1.1` |
| `branch_naming` *(existing)* | unchanged | work-item branch template; **base** changes to the slice branch under `pr_hierarchical` |

- All reads go through `sd_manifest_get` / `sd_manifest_resolve` (binding repo convention; never raw `jq`).
- Unknown/absent `merge_mode` → treated as `direct`.

---

## 5. Deterministic primitives — `lib/pr.sh` (mechanical only)

New library. Each function performs **one** mechanical git/`gh` operation, returns a clean exit code and/or raw JSON, and does **zero semantic parsing**. (This is the "deterministic where it is a mechanical fact" half of the hybrid — git/`gh` exit codes and `--json` enums are unambiguous, unlike the fuzzy text gates that caused prior bugs.)

| Function | Contract |
|---|---|
| `sd_sprint_branch_name <sprint_id>` | Resolve the sprint branch name from `during_dev.sprint_branch_naming` (default `sprint-{sprint_id}`). Dispatcher-accessible so skills never hard-code configured branch names. |
| `sd_slice_branch_name <vs_id>` | Resolve the slice branch name from `during_dev.slice_branch_naming` (default `slice/{vs_id}`). Dispatcher-accessible so skills never hard-code configured branch names. |
| `sd_branch_create_from <base> <new>` | Ensure `<base>` exists in canonical; create `<new>` off it. **Idempotent** — no-op (rc 0) if `<new>` already exists. |
| `sd_branch_push <branch>` | Push `<branch>` to `origin`, set upstream. Clean error if no remote configured. |
| `sd_pr_open <head> <base> <title> <body-file>` | Wraps `gh pr create --head <head> --base <base> --title <title> --body-file <body-file>`; echoes PR number/URL. Clean error if `gh` absent/unauthenticated. |
| `sd_pr_state <pr>` | Emits `gh pr view <pr> --json mergeStateStatus,statusCheckRollup,reviews,latestReviews,comments,reviewDecision,commits`. **No interpretation** — raw JSON for the agent to reason over. |
| `sd_pr_merge <pr> [--auto]` | Wraps `gh pr merge <pr> --merge [--auto]` by default; callers may pass `--rebase` or `--squash` explicitly. |
| `sd_remote_check` | Verify canonical has a remote **and** `gh` is authenticated. rc 0 / non-zero + actionable message. |

### 5.1 Signature changes to existing helpers
- `sd_merge_work_item <wt> <branch> [<target-branch>]` — new optional 3rd arg. When provided (the slice branch under `pr_hierarchical`), merge into it; when **omitted**, derive `.canonical.default_branch` exactly as today (back-compat preserved).
- `sd_worktree_add` — gains a **base-branch** parameter. Under `pr_hierarchical` the base is the slice branch; otherwise `default_branch` (today's behavior).

---

## 6. Skill changes (Approach A — extend the lifecycle skills in place)

`direct` mode in **every** skill below is the current path, untouched. All new behavior is gated on `merge_mode == pr_hierarchical`.

### 6.1 `planning-vertical-slice`
- **Pre-flight (pr_hierarchical):** call `sd_remote_check` and **refuse early** (mirroring the manifest-absent refusal style) if `gh`/auth/remote is missing — do not silently fall back to `direct`. Ensure `sprint-N` exists (`sd_branch_create_from main sprint-N` at first slice; reuse otherwise). Create the slice branch off `sprint-N` (`sd_branch_create_from sprint-N slice/VS-N.M.K`). Apply the §3.1 slice-ordering check.
- **§8.1 worktrees:** base off the **slice branch**.
- **§8.6 merge:** local `--no-ff` merge into the **slice branch** (`sd_merge_work_item <wt> <branch> <slice-branch>`). No push, no PR at this level.

### 6.2 `closing-vertical-slice`
- **Demos (Layer 1):** run on the **slice branch** in canonical (checkout the slice branch), not `default_branch`.
- **After harvest + worktree cleanup** (M2 order unchanged, §3.2 decoupling): `sd_branch_push slice/VS-N.M.K`, then `sd_pr_open slice/VS-N.M.K sprint-N <title> <body>`. PR body = slice README + architect-critic close-depth summary + linked issues. Then run the §7 pre-merge gate.

### 6.3 `writing-sprint-retrospective` (sprint close)
- After the sprint retro is authored: confirm all slice PRs into `sprint-N` are merged (surface any still open). `sd_branch_push sprint-N`, `sd_pr_open sprint-N main <title> <body>` (body = sprint retro summary + slice list + linked issues). Then the §7 pre-merge gate.
- Coordinates with `closing-vertical-slice` §11 (sprint-close handoff sweep on the final slice): the **sprint→main PR lives here**, the dedicated sprint-close skill, and runs after the final slice's slice→sprint PR has merged.

### 6.4 `references/git-workflow.md` (new, shared)
The single explicit write-up: topology (§3), mode semantics (§4), primitive contracts (§5), the pre-merge gate (§7), degradation (§8). All three skills cite it. Authored CLAUDE.md-ready (surfacing it into a *project's* CLAUDE.md is a deferred scaffold-onboard follow-up, not part of this release).

---

## 7. Agent-driven pre-merge gate (the hybrid seam)

Documented in `references/git-workflow.md`; invoked by both close skills before any merge. **No bash decides whether to merge.** The orchestrator (frontier model — Claude Code / Codex):

1. Calls `sd_pr_state <pr>` → obtains the CI rollup **and** review threads/comments in one raw JSON blob.
2. **Reasons over the full state**, not just `statusCheckRollup`/`mergeStateStatus`:
   - Review-app and human review **comments** usually are **not** modeled as required status checks, so `mergeStateStatus == CLEAN` can coexist with an unresolved review finding. The agent must account for review comments from **any review source** (the Codex GitHub app today; generic so it survives CodeRabbit's removal and absorbs future apps).
   - If the latest commit postdates the newest bot review, a re-review is likely still incoming — note that.
3. **Surfaces** unresolved review comments + CI state to the user and **asks**. **Never auto-merges over un-addressed review findings without explicit user acknowledgment.**
4. On the user's decision: `sd_pr_merge <pr> [--auto]`, leave the PR open, or wait. The gate **does not busy-wait / poll** the conversation on CI.

This is non-enforced guidance to the agent — not a deterministic block — exactly the principle's seam: *agent-driven for judgment, deterministic only for mechanical facts.*

---

## 8. Degradation & backward compatibility

- `merge_mode == pr_hierarchical` but missing `gh` / not authenticated / canonical has no remote → **refuse** at `planning-vertical-slice` pre-flight with an actionable error. No silent fallback to `direct`.
- `merge_mode` unset or `direct` → behavior **byte-for-byte unchanged**; `gh`/remote never required; `lib/pr.sh` never invoked.

---

## 9. Testing

- **`tests/test-pr.sh`** (new): exercise the primitives against a **local bare repo as `origin`** plus a **`gh` PATH-shim** — a fake `gh` on `$PATH` that records its args and emits canned JSON (no network). Cover: `sd_branch_create_from` (incl. idempotency), `sd_branch_push` to the bare remote, `sd_pr_open` argument-correctness (assert against the shim), `sd_pr_state` JSON shape, and `gh`-absent / no-remote degradation via `sd_remote_check`.
- **Extend `tests/test-merge.sh`:** `sd_merge_work_item` with an explicit target-branch arg; back-compat when the arg is omitted (→ `default_branch`).
- **Extend `tests/test-worktree.sh`:** the new base-branch parameter.
- **Agent-driven gates → eval scenarios (LLM-judge), not deterministic asserts** — consistent with the promoted *agent-review over deterministic gates* principle. Example scenario: under `pr_hierarchical`, slice-close opens the slice→sprint PR and **surfaces an outstanding Codex review comment before merging** rather than auto-merging on green CI.
- **All existing suites stay green** (the `direct` path is unchanged). Run the **full** suite, not just the touched suites.

---

## 10. Rollout

Feature → **minor bump: scaffold-dev v0.1.7 → v0.2.0**:
1. Bump `plugin.json` version (**Claude + Codex parity** — enforced by `tests/test-codex-dual-publish.sh`).
2. Bump the README plugin version table (+ directory-tree comment).
3. Merge.
4. `git tag scaffold-dev-v0.2.0`.

Installs update via `/plugin marketplace update` then `/plugin update` (version-keyed off `plugin.json`).

---

## 11. Open items carried into planning
- Exact PR-body templates (slice and sprint) — draft during `writing-plans`.
- Whether `sd_pr_open` should auto-detect an existing open PR for the same head/base and update it vs. erroring (lean: detect + reuse, surface to agent).
- The `gh` PATH-shim helper shape for `test-pr.sh` (canned-JSON fixtures live under `tests/fixtures/`).
