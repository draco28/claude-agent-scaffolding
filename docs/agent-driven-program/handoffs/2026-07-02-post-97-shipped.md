# Session Handoff — #96/#85/#37 SHIPPED (batch) · 1 issue left

**Date:** 2026-07-02 · **Author:** prior session (shipped the batch → PR #97) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§1 North Star + §6 ledger rows #96/#85/#37/#38), this handoff, `docs/agent-driven-program/reconsideration-decision-38-37-10.md` (why #38 is shaped as a full 5-leg build). **Delta vs last handoff: batch #96/#85/#37 shipped; backlog `#85 #38 #37 #96` → `#38` only.**

---

## 0. Repo state — post-merge + tags

`main` tip `c29ddfb` (PR #97 squash) + this bookkeeping commit. **#96, #85, #37 CLOSED · 0 open PRs · `fix/batch-96-85-37` deleted.** Four tags pushed (all on `c29ddfb`): `architect-critic-v0.5.1`, `workspace-init-v0.4.1`, `ai-mentor-v2.3.0`, `scaffold-dev-v0.16.0`. This commit carries the SPEC §6 ledger updates + this handoff. Clean tree (only `.claude/` + `docs/superpowers/` untracked — leave both; never `git add -A`).

> Same closeout guardrail: the auto-mode classifier blocks `gh pr merge` **and** `git push origin main` unless the user gives explicit in-turn authorization. This repo the agent does all git ops (merge/push/tag); a standing "you do all git ops" counts, but this session's merge/tags were explicitly authorized in-turn.

---

## 1. What this session did

Ran the batch the prior handoff planned: three small backlog items in one cycle (**PR #97**, squash `c29ddfb`), across four plugins. #38 was deliberately left for its own context.

- **#96 → architect-critic v0.5.0 → 0.5.1 (bug, agent-first).** `critiquing-spec` Step 8 prescribed a phantom `arc scorer_score`. Resolved the deeper F2/F3 the **agent-first** way (user call via AskUserQuestion): **removed the deterministic lexical scorer entirely** — deleted `lib/scorer.sh` (`ac_scorer_score_rebuttal` + unused `ac_scorer_decide`) and its unit tests, dropped the phantom `bin/arc` header line, and rewrote Step 8 so the agent scores the rebuttal 1–5 inline against the existing rubric. Honors `pp-e72993dfb626c518` ([[feedback_agent_review_over_deterministic_gates]]). Added a repro guard in `tests/integration/test-bug-repros.sh` (SKILL prescribes no `arc scorer_score*`; `arc --list` advertises none) — the end-to-end coverage whose absence let it ship.
- **#85 → workspace-init v0.4.0 → 0.4.1 (chore).** `wi_trace_filter_install` now resolves the hooks dir via `git rev-parse --git-dir` behind a new `wi_trace_filter_is_installable_repo_root` predicate; a `--separate-git-dir`/submodule canonical (whose `.git` is a *file*) installs instead of erroring. Scenario-C AI-git detection uses the same predicate for parity. #71's linked-worktree reject stays at preflight (now also enforced inside install).
- **#37 legs 2+3 → ai-mentor v2.2.0 → 2.3.0 + scaffold-dev v0.15.0 → 0.16.0 (feature).** Leg 2 = grill-me **Rule 5**: when explored facts contradict the user's premise, surface it, then resolve by mode (development → **code** authoritative; vision-aligned planning → **vision/spec** authoritative). Leg 3 = `recording-architecture-decision` §2 **strict three-part ADR threshold** (hard-to-reverse AND surprising AND real-tradeoff). Legs 1/4/5 wontfix (recorded on issue).
- **Version-table sync** — root README rows + dir-tree comments had drifted (ai-mentor/scaffold-dev/architect-critic stale from prior ships); corrected all four to current.

---

## 2. Three things worth remembering

1. **An issue's state can lie — verify against the code, not the label.** #96 was **closed-as-COMPLETED with no fix ever in the code** (closed at ~handoff-commit time while the handoff itself said "OPEN"). The bug was genuinely present (`SKILL.md:389` still had the phantom). Reopened before building so the PR closed it honestly. On any "already done" issue, confirm the fix exists in `main` before trusting the state.

2. **Codex's PR-fix rework was better-scoped than my original — and this time its "0 unresolved" was accurate (verified by GraphQL, not the summary).** My first #85 fix used `git rev-parse --git-path hooks`, which silently (a) started *respecting* `core.hooksPath` (a behavior change beyond the bug) and (b) left a latent Scenario-C inconsistency — a separate-git-dir AI workspace would be detected `git_tracked:false` by `[[ -d .git ]]` but install-accepted. Codex (`5ae05bb`) reverted to repo-local `--git-dir`+`/hooks` (deliberately ignoring `core.hooksPath`, matching the *original* behavior) and fixed the paired detection predicate. **Lesson: a "robustness" fix can change behavior beyond the bug and force a paired detection-path change — check both.** I still verified independently ([[feedback_codex_runs_pr_fix_cycle]]): real-HEAD diff read, all suites re-run (workspace-init 27/0, dual-publish 155/0, policy 7/0, architect-critic 15/0, scaffold-dev 24/0), 0 unresolved by GraphQL count.

3. **GitHub's comma-list `Closes #A, #B, #C` is unreliable — it closed #96 + #37 but *missed* #85.** Auto-close silently dropped one. Use a keyword per issue (`Closes #A, closes #B, closes #C`) or verify each issue's state post-merge and close the stragglers manually (I closed #85 by hand with a PR reference).

**Noted tradeoff (not a bug):** the #85 fix now installs into repo-local `.git/hooks` even when `core.hooksPath` is set → the hook silently won't fire in that (uncommon) case. Documented + tested (`test_S4`), flagged by Codex as a "future tracked-hooksPath variant." No follow-up issue filed; file one if hooksPath-aware install is ever wanted.

---

## 3. Program state snapshot

**Plugin versions (current `main`):** workspace-init **0.4.1** · scaffold-onboard **0.12.0** · scaffold-dev **0.16.0** · architect-critic **0.5.1** · claude-security-audit **0.1.3** · ai-mentor **2.3.0**.

**Open backlog (1):** **#38** — improve scaffold-dev handoffs (suggested-skills, artifact-references, redaction, next-session-focus, ephemeral non-dual-repo mode). Decided **build all 5 legs** (user override of council's cherry-pick-only). Enhancement — **zero correctness bugs open.** The North Star (SPEC §1/§6) reaches zero after #38.

**Repo state:** `main` tip `c29ddfb` + this bookkeeping commit; #96/#85/#37 CLOSED; 0 open PRs; 4 tags pushed. Clean tree (only `.claude/` + `docs/superpowers/` untracked).

---

## 4. Recommended next-session entry points

1. **Open #38 in a fresh, brainstorm-first context — it's a real feature, not a fix.** Legs 3 (redaction) and 5 (lightweight/ephemeral non-dual-repo handoff mode) carry genuine design: leg 3 needs its own failure-mode design (false-pos/neg, hard-block vs warn-and-confirm), leg 5 needs handoffs that work outside the dual-repo/slice topology. Brainstorm before building; touches `scaffold-dev/skills/handing-off-session/`. Decision-of-record: `reconsideration-decision-38-37-10.md`.
2. **Dogfood the newly-shipped #37 surfaces** — the next real grill-me is the first exercise of Rule 5 (does the mode-dependent code-vs-doc resolution fire cleanly?); the next `/adr`-worthy moment tests the three-part threshold (does it actually steer below-bar decisions to a lighter record?).

**Above all: verify on the real HEAD and by GraphQL thread-count (not the fix-cycle summary), keep the agent-driven skills free of unnecessary determinism (#96 F3 is the live reminder — a lexical gate mis-scored a strong rebuttal), and re-run `tests/test-recommendation-policy-parity.sh` (7/0) after any touch near the policy copies.**
