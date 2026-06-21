# Session Handoff — Batch C (#71) SHIPPED · 6 issues left (5 enh/chore + 1 narrow follow-up)

**Date:** 2026-06-21 · **Author:** prior session (shipped Batch C → PR #84; closed #71; filed #85) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§1 North Star + §6 issue ledger), the prior handoff `2026-06-21-post-batch-a-shipped.md` (the batch strategy + the build-ready issue details for #82/#79), and `[[project_friction_log_first_realtest]]` (Batch C closeout + 3 durable lessons). **This handoff is the delta: Batch C shipped; backlog is 6 (#85 #82 #79 #38 #37 #10).**

---

## 1. What this session did (one line)

Built + shipped **Batch C** (#71, the PR-#70 review-followup hardening grab-bag) → PR **#84** squash-merged (`7ba4a5b`), **workspace-init v0.4.0** + **claude-security-audit v0.1.3** tagged/bumped; **#71 CLOSED**; one deferred pre-existing asymmetry filed as **#85**; SPEC ledger + friction-log + memory updated; ledger commit `9ea2d31` pushed to `main`.

---

## 2. ⚠️ FIRST ACTION NEXT SESSION — pick the next item

**6 issues remain. Backlog count is unchanged from last session (closed #71, opened #85) but composition improved**: a 5-item grab-bag shipped, replaced by one narrow low-priority follow-up. **Still zero correctness bugs.**

### Recommended order (build-ready first)

| Pick | Issue | Why / scope | Build-ready? |
|---|---|---|---|
| **① ⭐ do next** | **#82** | **Complete the multi-reviewer pre-merge gate** — demand-validated (user hit it live on PulseTrader PR #54) AND **freshly re-validated by THIS session** (see §4). Two enhancements to `scaffold-dev/skills/planning-vertical-slice/references/git-workflow.md`: (Gap 1) codified finding-disposition loop + severity bar (P1 must-fix, P2 fix-or-defer-to-issue, record per-finding disposition); (Gap 2) **reviewer-completeness detection** — a review app posting `SUCCESS` + "Review skipped" (CodeRabbit on non-default base branches → every `pr_hierarchical` PR) must be treated as not-green; re-review must confirm on the new head sha. Possibly a small `sd` helper to classify per-reviewer terminal state. | ✅ yes |
| **②** | **#79** | Count-aware `auto:` form (`expected: ran ≥N`, N default 1) — the #74 escape hatch for runners outside `sd_zero_tests_guard`'s allowlist. Cross-plugin **minor on both**: scaffold-onboard grammar (`sf_demo_parse_line` + `auto-grammar.md` §2 + two-mode eval) + scaffold-dev runtime (`sd_verify_auto_step`, all 3 gate sites). Heavier, distinct surface. | ✅ yes (larger) |
| **③ DECISION** | **#38 + #37 + #10** | All `deferred`. #38/#37 = mattpocock-benchmark cherry-picks (handoff polish / grill enhancements); #10 = demand-gated parallel-slice coordination. **Triage each (build-subset / wontfix / keep-deferred) BEFORE building** — [[feedback_reconsider_deferred_before_building]]. | ⚠️ reconsider first |
| **— chore** | **#85** | NEW low-priority: `wi_trace_filter_install`'s `.git`-must-be-a-dir check rejects `--separate-git-dir`/submodule **canonicals** (pre-existing asymmetry surfaced by #84's now-precise worktree helper). Fix = `git rev-parse --git-path hooks`, keeping #71's worktree-reject intact. Exotic setup; fold into a future workspace-init touch. | ✅ small |

**Suggested:** lead with **#82** (highest real pull, demand-validated, and you'll have fresh live evidence from this very session's PR #84 review). Then #79. Then the #38/#37/#10 decision session. #85 can ride along with any future workspace-init change.

---

## 3. Batch C (#71) — what shipped (detail)

**workspace-init 0.3.0 → 0.4.0; claude-security-audit 0.1.2 → 0.1.3** (both publish targets; README rows corrected — csa was stale at 0.1.0). Five items:
1. **`created_by` → provenance.** Stamps `workspace-init@<running version>` from the sibling `.claude-plugin/plugin.json` via new `wi_plugin_version` helper (was frozen `@0.1.0`). Test asserts shape + parity → bump-proof.
2. **`--ai-git-tracked <bool>` flag** on `wi_manifest_write` (default `true`); Scenario-C `pairing-existing-dual` threads it so a non-git AI workspace records `false` honestly. Dropped the stale "known limitation" note.
3. **CI `actions/checkout`** SHA-pinned to `34e1148…` (v4.3.1) + `persist-credentials: false`.
4. **Reject a linked-worktree canonical** in BOTH preflights (`wi_skeleton_preflight_existing_dual` + `wi_skeleton_preflight --pair-with`) via new `wi_git_is_linked_worktree`.
5. **`CSA_SKIP_PERF`** env-gates the 30s wall-clock perf benchmark out of shared-runner CI (ran 19s even locally → real flake risk); still runs locally/homelab.

**Bot-review fixes folded in (PR #84, base=`main` so CodeRabbit reviewed):** `wi_manifest_read` boolean-`false` contract fix (Devin); precise worktree detection not over-matching `--separate-git-dir`/submodules (CodeRabbit); nested-AI detection via `[[ -d .git ]]` (Codex P2). Devin's `--separate-git-dir`-canonical/trace-filter asymmetry deferred → **#85**.

---

## 4. Durable lessons from Batch C ⭐ (carry into every PR)

1. **🆕 `jq // empty` AND `jq -e` both swallow boolean `false`/`0`.** When a jq read must distinguish "present-but-falsy" from "missing", use `jq "try (<field>) catch null | if . == null then empty else . end"` — never `//` or `-e`. (Fixed `wi_manifest_read`; latent since it also affected `allow_ai_*: false`.)
2. **🆕 Precise linked-worktree detection = `--git-dir != --git-common-dir`, NOT `.git`-is-a-file.** The `.git`-is-a-file shortcut over-rejects standalone `--separate-git-dir` repos and submodules (whose `.git` is a file too, but `--git-dir == --git-common-dir`).
3. **🆕 Git-status detection must use the EXACT gate the consumer uses.** The Scenario-C skill detected via `git rev-parse --git-dir` (true for a subdir nested in a parent repo) → would record `git_tracked:true` then fail hook install. Fixed to `[[ -d "$ai_root/.git" ]]` — the identical gate `wi_trace_filter_install` checks. (Same class as #74/#63 "enforce the invariant on every branch".)
4. **🆕 This session is fresh live evidence for #82.** Working PR #84's review surfaced the exact gaps #82 codifies: **Codex posts its review ~4 min AFTER CodeRabbit/Devin settle** (I missed a Codex P2 on the first comment-fetch — *fetch comments after all three have posted, not at first "settled"*); threads need explicit disposition (one fixed, one deferred-to-#85); and **Codex is not a required status check** (it posts a review, not a check) so "all checks green" ≠ "Codex reviewed". Pull these into #82's reviewer-completeness design.
5. **README version rows are NOT CI-guarded** (re-confirmed: csa row was stale 0.1.0 vs actual 0.1.2). The dual-publish parity test guards manifest↔manifest only. Bump README rows by hand + sanity-check neighbors.
6. **Source-repo flow** (no `.workspace/pairing.json` → slice/handoff skills refuse): plain `writing-plans → inline TDD → bot-review → release`. Stage specific paths (never `git add -A` — `.claude/` is untracked). Direct `git push origin main` stays blocked by the auto-mode classifier; commit ledger/docs locally and ask the user to push (they approve per-time).

---

## 5. Program state snapshot

**The program is NOT done.** "Closing the agent-driven program" = SPEC §6 ledger at **zero open backlog** (North Star §1). 6 remain — each must be **built** or **consciously wontfix'd**. All correctness bugs cleared; remainder = enhancement/chore.

**Open backlog (6 — all enhancement/chore, zero bugs):** #82, #79 (build-ready) · #85 (small chore) · #38, #37, #10 (reconsider-value-first).

**Sub-spec status (SPEC §5):** SS-1…SS-5 ✅ · SS-5.1 ✅ · SS-7 ✅ · **SS-6 — final phase, in progress** (all correctness bugs done; remainder = these 6 + #59 SS-3 residual "future" polish).

**Plugin versions (current `main`, HEAD `9ea2d31`):** workspace-init **0.4.0** · scaffold-onboard **0.9.2** · scaffold-dev **0.11.0** · architect-critic **0.3.0** · claude-security-audit **0.1.3** · ai-mentor **2.0.0**.

**Tags this session:** `workspace-init-v0.4.0` (on merge commit `7ba4a5b`).

**Repo state:** local `main` = origin `main` = `9ea2d31`, clean tree (only `.claude/` untracked). 0 open PRs. CI green. #71 CLOSED, #85 filed.

### ⚠️ Unfinished thread still carried forward
- **Operator real-Codex smoke** of the #39 async review-gate path (manual; see `2026-06-20-post-74-shipped.md` §2). CI uses the gh-shim only; the live Codex fresh-frame path has never been exercised end-to-end. (#76 added a real direct-mode slice diff to that bundle, so the smoke has more to exercise.)

---

## 6. Recommended next-session entry points

1. **#82** — complete the multi-reviewer pre-merge gate; demand-validated + freshly re-validated by this session's PR #84 review. scaffold-dev `references/git-workflow.md` (+ maybe a small `sd` helper). Highest real pull. One PR.
2. **#79** — count-aware `auto:` form; cross-plugin minor on both. Heavier.
3. **Decision session (#38/#37/#10)** — value-reconsideration before any build; for each decide build-subset / wontfix / keep-deferred.
4. **#85** — fold the `--separate-git-dir`-canonical hook-path fix into a future workspace-init touch.

**Target remains zero open backlog (6 → 0).** No bugs, no blockers — program end-game.
