# SS-9 — `/work-pr`: standalone, slice-decoupled PR review-fix-merge gate (closes #92)

**Status:** Design-locked for `scaffold-dev v0.14.0` (sub-spec of `docs/agent-driven-program/SPEC-agent-driven-program.md` → SS-9) · **Date:** 2026-06-27
**Closes:** `#92` (the #82 pre-merge gate was reachable only from slice/sprint close). Demand-validated by the hand-maintained Codex "PR-fix prompt" this collapses ([[feedback_codex_runs_pr_fix_cycle]]).
**Plugins touched:** `scaffold-dev` only (new `working-pull-request` skill + `/work-pr` command + a backward-compatible `lib/pr.sh` extension).

> **Design settled with user 2026-06-27** (brainstorm). Two forks locked via AskUserQuestion (§3). Binding constraint reaffirmed: **skill-first / agent-driven — no deterministic code where reasoning belongs** (program North Star §1). Determinism stays only in the mechanical `sd`/`gh` primitives.

---

## 1. The problem

The #82 multi-reviewer pre-merge gate (finding-disposition loop + reviewer-completeness) is strong, but it lives **only** inside slice/sprint close — `closing-vertical-slice` §10a and `writing-sprint-retrospective` §8a, gated on `merge_mode == pr_hierarchical`. There is no way to run it against an **arbitrary** PR: an ordinary feature PR like #91 (`/amend-spec`), which lived in *this* scaffolding repo — a plain GitHub repo with **no** workspace-init manifest and no slice hierarchy. The contract existed; the user re-derived it by hand in a Codex prompt each time. `/work-pr` is the missing front door.

## 2. Key finding — the gate is already PR-generic

Exploration (2026-06-27) confirmed the gate logic depends on **only**: a PR ref, `sd pr_state`, `sd pr_review_comments`, and agent judgment. Everything else at slice close (VS-id, worktree, slice branch, review bundle, retrospective, ROADMAP) merely *composes the PR body* — none of it is consumed by the gate. The disposition contract is already a single source of truth in `planning-vertical-slice/references/git-workflow.md` §"Agent-driven pre-merge gate", which both close skills *point at* rather than embed. So the extraction is clean: a new skill that **reuses** that contract and adds standalone preflight + fix-driving around it — **no forked copy.**

## 3. Settled forks (brainstorm 2026-06-27)

1. **Job boundary → full review-fix-merge loop, run by the invoking agent itself.** (vs. disposition-only / advisory, or a cross-provider hand-off.) The loop — fetch findings → disposition (P1 must-fix / non-blocking fix-or-defer) → **drive the fixes** → re-review on the new head → defer leftovers → merge on explicit ack — runs end-to-end inside whichever agent invoked `/work-pr`. **No cross-agent hand-off** ("invoke in Claude → implement in Codex" complexity is explicitly excluded). The Codex-vs-Claude choice is the user's *at invocation time*, purely to keep the fix-heavy back-and-forth off a session's context window. The skill is therefore **provider-agnostic** (dual-publish: identical behavior in Claude Code and Codex) and **skill-driven, zero determinism in the loop**.
2. **Targeting → manifest-free, current repo.** (vs. hybrid manifest-then-cwd, or the standard manifest-required-canonical-default guard.) `/work-pr` resolves the repo from `git rev-parse --show-toplevel` (or an explicit `--repo-root DIR`) and does **not** call `manifest_require` — so it runs on any gh repo, including the manifest-less one PR #91 lived in. `gh` resolves owner/repo from that repo's `origin`.

## 4. The flow (`working-pull-request` SKILL.md — all agent reasoning; ⚙️ = mechanical reuse via `sd`)

1. **Preflight** ⚙️ — resolve `REPO_ROOT` from `git rev-parse --show-toplevel` (or `--repo-root`); `sd remote_check --repo-root "$REPO_ROOT"` (origin + authed gh, generic — NOT canonical); `sd pr_state <PR> --repo-root "$REPO_ROOT"` to confirm the PR exists. No `manifest_require`. Fail fast with an actionable message.
2. **Fetch** ⚙️ — `sd pr_state` (CI rollup + review summaries + conversation + commits) **and** `sd pr_review_comments` (inline line-level findings) — both, because each alone misses findings the other carries. Build a disposition ledger.
3. **Disposition + fix loop** — apply `git-workflow.md` §7 verbatim: P1/blocking → must fix (never ack-to-merge, never deferrable); non-blocking → fix or defer (`deferred → #N`, never silent); **the agent drives the fix itself** (edit, commit, push) then re-fetches and re-reviews on the new head (staleness); reviewer-completeness (green check ≠ ran; skipped ≠ approval; pending → wait). Loop until every finding is dispositioned, every P1 fixed, and the reviewer signal current. No busy-wait.
4. **Defer leftovers** ⚙️ — `sd issue_create --repo-root "$REPO_ROOT" --label tech-debt` files a tracked issue for each accepted non-blocking finding; in a paired workspace, *additionally* add the `[TD]` index line via `deferring-work-item`; in a manifest-less repo the issue IS the record. Label setup never blocks the debt (`sd label_ensure`).
5. **Terminus** ⚙️ — surface the ledger + CI/reviewer status + mergeability verdict; ask merge/wait/leave-open; `sd pr_merge <PR> --repo-root "$REPO_ROOT"` **only on explicit ack**. Never auto-merge over an unresolved P1, stale/incomplete reviewer signal, or red gate.

## 5. Reuse vs. new

- **Reused, no new behavior:** the `git-workflow.md` §7 disposition contract (single source of truth — pointed at, not forked); `sd_pr_state`, `sd_pr_review_comments`, `sd_pr_merge`, `sd_remote_check`, `sd_issue_create`, `sd_label_ensure`; the `deferring-work-item` skill; the `$ARGUMENTS` env-var bridge (`commands/defer.md` pattern); `bin/sd` auto-discovery.
- **New:** `skills/working-pull-request/SKILL.md` (prose, 139 lines); `commands/work-pr.md` (thin `$ARGUMENTS` bridge); the **only deterministic change** — an optional `--repo-root DIR` target on the four PR helpers, extracted to a shared `_sd_repo_target` parser (the `--repo-root` parse + canonical-fallback resolve, previously duplicated inline in `sd_issue_create`/`sd_issue_list`, which are retrofitted onto it). 9 new `tests/test-pr.sh` cases.

## 6. Backward compatibility (load-bearing)

`_sd_repo_target` resolves **explicit `--repo-root` → else `.canonical.root`**. Every existing slice/sprint caller passes no `--repo-root`, so it falls through to canonical exactly as before — byte-identical. The retrofit of `sd_issue_create`/`sd_issue_list` preserves their arg-forwarding and the #48 missing-value/empty-value guards (verified by the pre-existing tests 31–37). `sd_pr_open` and the positional-`repo-root` `sd_label_ensure` are left untouched.

## 7. Out of scope (deferred)

- **Remote `--repo owner/repo` (gh `-R`) targeting** — current-repo / `--repo-root DIR` covers the motivating cases (you are in, or can `cd` to, the PR's repo) without touching the test gh-shim. A clean follow-up if a no-clone remote workflow is needed.
- Relocating the §7 gate contract to a neutral shared home — unnecessary; the pointer model is consistent with the existing slice/sprint callers and avoids churning the seam-lint string pins.
- Any change to slice/sprint-close behavior — strictly additive.

## 8. Testing

`tests/test-pr.sh` gains 9 cases for `--repo-root` on the PR helpers: cwd-routing for `pr_state`/`pr_review_comments`/`pr_merge` (via the gh-shim's `$PWD` log), canonical-default fall-through, `--repo-root` stripped from the gh passthrough, default strategy still injected, the missing-value guard (rc 1), and `remote_check --repo-root` honoring the target (rc 1 on a no-origin target even when canonical has one; rc 0 on an origin'd target). The skill body is agent prose (no behavioral unit test) — covered by the 500-line cap guard (`test-skill-line-cap.sh`) and the dual-publish frontmatter validation (`tests/test-codex-dual-publish.sh`).

## 9. Ledger placement

SS-9 is its own sub-spec line (the standalone-command strategic item, parallel to SS-8) and ships as **one PR** → `scaffold-dev v0.14.0`. Closes #92.
