# Session Handoff — #82 SHIPPED · 6 issues left (1 strategic + 1 build-ready + 1 chore + 3 reconsider)

**Date:** 2026-06-21 · **Author:** prior session (shipped #82 → PR #87, scaffold-dev v0.12.0; rescued a 9-round bot-review grind) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§1 North Star + §6 ledger), this handoff, and the two NEW process memories: `[[feedback_bot_review_batch_fix_one_pass]]` + `[[feedback_skill_first_avoid_overengineering]]`. **Delta vs last handoff: #82 shipped; backlog 6 (#86 is new, user-filed).**

---

## 1. What this session did (one line)

Shipped **#82** (multi-reviewer pre-merge gate) → PR **#87** squash-merged (`99740ba`), **scaffold-dev v0.12.0** tagged; **#82 CLOSED**. The gate is **lean agent-first prose** (finding-disposition loop + reviewer-completeness as binding agent judgment; prose-only, no new `sd` helper). SPEC §6 ledger + friction-log + memory updated; ledger commits on `main`.

---

## 2. ⚠️ Read this before picking the next item — the process lesson from this session

**#82 went 9 bot-review rounds for a minimal prose change.** The user (rightly) called it absurd. Two root causes, now saved as memory — **internalize these before opening the next PR:**

1. **[[feedback_bot_review_batch_fix_one_pass]]** — after the FIRST bot-review round, do NOT fix findings one-at-a-time and re-push. Reviewers surface *sibling instances* of each bug class one per round (fix the central doc → next round it's in the cross-refs), so the loop never converges. Instead: spin up Codex (`codex:codex-rescue`) / a sub-agent sweep keyed to the bug *classes*, fix every similar + future-flaggable instance, push ONCE. Target ≤2 rounds.
2. **[[feedback_skill_first_avoid_overengineering]]** — agent-first / skill-first is the vision. Over-**specifying** mechanical precision in prose (exact `commit_id` fetches, raw `gh` calls, fine taxonomies) IS over-engineering *even with no new code*, and it's what drew the 9 rounds. Keep contracts lean; let the agent reason over the data. Determinism only for mechanical facts.

The rescue: a single `codex:codex-rescue` consolidation pass simplified the gate (78→40 lines), swept all bug classes at once, and the confirm round was clean. **Apply this pattern proactively next time, not as a rescue.**

---

## 3. ⚠️ FIRST ACTION NEXT SESSION — pick the next item (backlog = 6)

| Pick | Issue | Why / scope | Ready? |
|---|---|---|---|
| **① ⭐ strategic** | **#86** | **NEW (user-filed 2026-06-21).** `/amend-spec` skill — incremental, **change-driven** MASTER-SPEC amendment for the post-MVP / vNext lifecycle (classify change → impact analysis → collision-safe ID mint → *targeted* spec edit + *diff-aware* governance update, vs today's greenfield whole-bundle re-derive). Demand-validated by PulseDB (v0.5.x→vNext, needed one reliability NFR). **The greenfield→full-lifecycle-tool gap — arguably the highest-value open item.** | ⚠️ **brainstorm-first** (larger design; likely a new sub-spec) |
| **②** | **#79** | Count-aware `auto:` form (`expected: ran ≥N`) — the #74 escape hatch for runners outside `sd_zero_tests_guard`'s allowlist. Cross-plugin minor: scaffold-onboard grammar (`sf_demo_parse_line`) + scaffold-dev runtime (`sd_verify_auto_step`, all 3 gate sites). | ✅ build-ready |
| **③ chore** | **#85** | `wi_trace_filter_install`'s `.git`-must-be-a-dir check rejects `--separate-git-dir`/submodule **canonicals** (pre-existing asymmetry). Fix = `git rev-parse --git-path hooks`, keeping #71's worktree-reject intact. Fold into a future workspace-init touch. | ✅ small |
| **④ DECISION** | **#38 + #37 + #10** | All `deferred`. #38/#37 = mattpocock-benchmark cherry-picks (handoff polish / grill enhancements); #10 = demand-gated parallel-slice coordination. **Triage each (build-subset / wontfix / keep-deferred) BEFORE building** — [[feedback_reconsider_deferred_before_building]]. | ⚠️ reconsider first |

**Suggested:** **#86** deserves a `superpowers:brainstorming` session first (it's a real capability area, not a bug-fix) — it's the most strategic. If you want a quick, contained win instead, **#79**. Save the #38/#37/#10 decision session and #85 chore for last.

---

## 4. Program state snapshot

**Plugin versions (current `main`, HEAD `cc636aa`+):** workspace-init **0.4.0** · scaffold-onboard **0.9.2** · scaffold-dev **0.12.0** · architect-critic **0.3.0** · claude-security-audit **0.1.3** · ai-mentor **2.0.0**.

**Tags this session:** `scaffold-dev-v0.12.0` (on merge commit `99740ba`).

**Open backlog (6):** **#86** (strategic, brainstorm-first) · #79 (build-ready) · #85 (small chore) · #38, #37, #10 (reconsider-first). All enhancement/chore — **zero correctness bugs.**

**Sub-spec status (SPEC §5):** SS-1…SS-5 ✅ · SS-5.1 ✅ · SS-7 ✅ · **SS-6 — final phase, in progress** (all correctness bugs done; remainder = these 6 + #59 SS-3 residual "future" polish). #86 may warrant a new sub-spec.

**Repo state:** local `main` = origin `main`, clean tree (only `.claude/` + `docs/superpowers/` untracked). 0 open PRs. CI green. #82 CLOSED.

### Carried-forward threads
- **Operator real-Codex smoke** of the #39 async review-gate path (manual; never exercised live end-to-end — the CI uses the gh-shim only).
- The #82 gate is now lean prose; the `sd pr_checks`/`sd pr_reviews` precision primitive was **considered and dropped** (the simplification removed the concern — don't re-add it; that's the determinism the user is steering away from).

---

## 5. Recommended next-session entry points

1. **#86** — `superpowers:brainstorming` the `/amend-spec` change-driven lifecycle skill (highest value; new design area; demand-validated by PulseDB). Likely a new sub-spec + a brainstorm-then-stage epic.
2. **#79** — count-aware `auto:` form; contained cross-plugin minor (good quick win).
3. **Decision session (#38/#37/#10)** — value-reconsideration before any build.
4. **#85** — fold the `--separate-git-dir`-canonical hook-path fix into a future workspace-init touch.

**Above all: open the next PR with the batch-fix-in-one-pass discipline. No more 9-round grinds.**
