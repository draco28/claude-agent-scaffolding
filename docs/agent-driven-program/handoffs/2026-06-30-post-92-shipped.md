# Session Handoff — #92 SHIPPED (SS-9 `/work-pr`) · 4 issues left

**Date:** 2026-06-30 · **Author:** prior session (shipped #92 → PR #94) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§1 North Star + §5 SS-9 + §6 ledger), this handoff, `specs/SS-9-work-pr.md`. **Delta vs last handoff: #92 shipped; backlog 5 → 4.**

---

## 0. ✅ Repo fully synced — no pending push

`main` is **fully synced with origin** (`git rev-list --left-right --count origin/main...main` → `0 0`), tip `4de49af`. PR #94 (`1b0eebb`), tag `scaffold-dev-v0.14.0`, and the post-merge bookkeeping commit (`4de49af`: SPEC §5/§6 SHIPPED flip + `SS-9-work-pr.md` §1/§4/§5/§10 accuracy + CHANGELOG + this handoff) are all on origin. **#92 CLOSED. 0 open PRs.** Start the next task clean.

> This session confirmed the auto-mode classifier blocks **both `gh pr merge` AND `git push origin main`** — each required an explicit per-action user authorization ("merge it" / "push it"), and the classifier explicitly noted the "user runs `! git push`" memory convention is **not** consent. Expect to authorize both at every closeout, or add scoped permission rules for `gh pr merge` + `git push origin main`.

---

## 1. What this session did

**Shipped #92** → PR **#94** squash-merged (`1b0eebb`), tag `scaffold-dev-v0.14.0`. The **`/work-pr <PR>`** command + **`working-pull-request`** skill (SS-9) — the standalone, slice-decoupled form of the #82 pre-merge gate.

- **scaffold-dev v0.14.0** (13 skills, 7 commands): new `skills/working-pull-request/SKILL.md` (184 lines) + `commands/work-pr.md`; the only deterministic change is an optional `--repo-root DIR` on `sd_pr_state`/`sd_pr_review_comments`/`sd_pr_merge`/`sd_remote_check` via a shared `_sd_repo_target` parser (`sd_issue_create`/`sd_issue_list` retrofitted onto it). `specs/SS-9-work-pr.md` design-of-record.
- **The loop (agent-driven, zero determinism):** preflight (resolve repo manifest-free, `sd remote_check`, dirty-guard + `gh pr checkout` + head-OID verify) → fetch (`sd pr_state` + `sd pr_review_comments`) → disposition (P1 must-fix / non-blocking fix-or-defer per `git-workflow.md` §7) → drive fixes → re-review on new head → defer leftovers (single owner) → merge on explicit ack. **Run end-to-end by whichever agent invokes it (Claude or Codex) — no cross-agent hand-off.**
- **Brainstorm-first**, settled **two forks** with the user (AskUserQuestion): (1) **full review-fix-merge loop, invoking-agent-does-all** (no cross-provider dispatch; the Codex-vs-Claude choice is the user's at invocation time, for context-window management); (2) **manifest-free targeting** (current repo via `git rev-parse --show-toplevel`, or `--repo-root`; no `manifest_require`).
- **Key design fact:** the gate was already PR-generic — its contract lives once in `planning-vertical-slice/references/git-workflow.md` §7 (both close skills point at it). `/work-pr` **reuses** it, no forked copy.

---

## 2. Two things worth remembering

1. **The Codex-runs-fix-cycle / Claude-reviews-and-merges split worked cleanly again ([[feedback_codex_runs_pr_fix_cycle]]).** The user's Codex companion pushed **3 commits** to PR #94 that fixed **real first-draft bugs** I'd missed: (a) `sd_pr_review_comments` resolved `{owner}/{repo}` from cwd, so a full PR URL for a *different* repo queried the wrong repo — now it parses owner/repo from the URL; (b) §5 deferral **double-filed** the issue (the draft called `sd issue_create` *and then* `/defer`, which itself files) — now exactly one owner; (c) the skill preflight gained dirty-repo refusal + `gh pr checkout` + `headRefName`/`headRefOid` verification (fixes land on the right, current branch) + a `gh repo view` resolution check in `sd_remote_check`. I reviewed all 3 on the real HEAD (`cd8fb08`) and re-verified (suite 23/0, dual-publish 155/0, line-cap 14/0, 0 unresolved threads) **before** squash-merge — not on the summary.

2. **Lesson — SKILL prose that *comments* an intent without showing the code can ship incomplete.** My draft preflight said "use `--repo-root` if passed" in a comment but had no parse loop; the deferral step described two filers without noticing they collide. For agent-driven skills the prose *is* the implementation — make the load-bearing branch explicit, and seam-lint the safety-critical lines (Codex added `test_work_pr_skill_safety_prose`).

---

## 3. Program state snapshot

**Plugin versions (current `main`):** workspace-init **0.4.0** · scaffold-onboard **0.12.0** · scaffold-dev **0.14.0** · architect-critic **0.4.0** · claude-security-audit **0.1.3** · ai-mentor **2.1.0**.

**Open backlog (4):** **#85** (small chore — `wi_trace_filter_install` `.git`-must-be-a-dir check rejects `--separate-git-dir`/submodule canonicals; `git rev-parse --git-path hooks` rewrite) · **#38**, **#37**, **#10** (reconsider-first). All enhancement/chore — **zero correctness bugs.**

**Repo state:** `main` **fully synced with origin** at `0 0` (tip `4de49af`; PR #94 `1b0eebb` + tag `scaffold-dev-v0.14.0` + bookkeeping `4de49af` all on origin); #92 CLOSED; 0 open PRs. Clean tree (only `.claude/` + `docs/superpowers/` untracked).

---

## 4. Recommended next-session entry points

1. **Decision session (#38 / #37 / #10)** — value-reconsideration before any build ([[feedback_reconsider_deferred_before_building]]). These have sat as "reconsider-first" across several handoffs; a `/council` or `/grill-me` pass to decide build-vs-wontfix would shrink the backlog honestly.
2. **#85** — fold the `--separate-git-dir`-canonical hook-path fix into a future workspace-init touch (low priority; narrow).
3. **Dogfood `/work-pr`** — the next PR in any manifest-paired (or manifest-less) repo is the first real-world exercise of the new command; watch for friction in the preflight checkout + the merge ask.

**Above all: keep the Codex-runs-fix-cycle / Claude-reviews-and-merges split, verify on the real HEAD (not the summary), and keep agent-driven skills free of unnecessary determinism.**
