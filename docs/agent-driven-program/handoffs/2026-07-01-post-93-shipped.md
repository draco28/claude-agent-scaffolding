# Session Handoff — #93 SHIPPED (recommend-by-default policy) · 4 issues left

**Date:** 2026-07-01 · **Author:** prior session (shipped #93 → PR #95) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§1 North Star + §6 ledger row #93), this handoff, `docs/conventions/recommendation-policy.md`. **Delta vs last handoff: #93 filed + shipped; backlog stays 4 (#93 was extra, now closed).**

---

## 0. Repo state — bookkeeping commit + tags

`main` tip `0692dad` (PR #95 squash). **#93 CLOSED, 0 open PRs, `feat/93-recommend-policy` deleted.** Three tags pushed: `ai-mentor-v2.2.0`, `architect-critic-v0.5.0`, `scaffold-dev-v0.15.0` (all on `0692dad`). This post-merge bookkeeping commit carries the SPEC §6 `#93` ledger row + this handoff. Clean tree (only `.claude/` + `docs/superpowers/` untracked).

> Same closeout guardrail as always: the auto-mode classifier blocks `gh pr merge` **and** `git push origin main` unless the user gives explicit in-turn authorization. This session the user clarified they do **not** merge for this repo — the agent does all git ops (merge/push/tag) — so expect to run them yourself, but only after the user has authorized (a standing "you do all git ops" statement counts).

---

## 1. What this session did

**Shipped #93** → PR **#95** squash-merged (`0692dad`). A single **recommend-by-default decision policy** across the four decision-surfacing skills: every surfaced decision now carries **one firm, vision-grounded recommendation** + one-line rationale by default, with `accept`/`rebut`/`defer` dispositions and a `--neutral` opt-out.

- **New marketplace convention** `docs/conventions/recommendation-policy.md` — the human-facing single source of truth — shipped as a **byte-identical copy inside each of the 3 plugins** (`ai-mentor/references/`, `architect-critic/templates/`, `scaffold-dev/skills/planning-vertical-slice/references/`), guarded by a new repo-root parity test `tests/test-recommendation-policy-parity.sh` (wired into CI). **Why copies, not one referenced doc:** repo-root `docs/` does **not** ship on `/plugin install`, so a single referenced path would dangle for installed users ([[reference_cross_plugin_shared_doc_pattern]]).
- **ai-mentor v2.1.0 → 2.2.0:** `grill-me` Rule #3 flipped from "recommend only when asked" to recommend-by-default (one cited lean per question); `council` proposes a Chairman synthesis by default (five voices still first). **Stays orthogonal** — grounds via its existing soft orientation-derivation chain (issue/PR → memory-bank → handoffs), **no manifest dependency added**.
- **architect-critic v0.4.0 → 0.5.0:** each challenge carries a recommended disposition; the rebuttal triple was reframed `accept|rebut|dismiss` → `accept|rebut|defer` (`defer` = valid/unresolved but tracked; `lib/scorer.sh` internals unchanged). Async path persists `neutral_mode` + deferred bookkeeping across resume.
- **scaffold-dev v0.14.0 → 0.15.0:** every orchestrate gate (§4/§5/§7.2/§8.5/§8.7) carries a MASTER-SPEC-cited recommendation (additive; §15 user-authority stance preserved). `--neutral` parsed in `orchestrate-args`, forwarded into nested architect-critic **and** grill-me gates. SKILL.md at 490/500.

---

## 2. Two things worth remembering

1. **Distrust the fix-cycle summary; verify unresolved threads by GraphQL count, not the report ([[feedback_codex_runs_pr_fix_cycle]], [[feedback_bot_review_convergence_judgment]]).** Codex ran the initial fix cycle (`9ff7128`) and reported "0 unresolved threads / MERGEABLE." It was **inaccurate** — 3 P2 threads were already open, and the re-review of each fix round surfaced more, for **9 valid findings total across 2 rounds**. The independent real-HEAD review is what caught them: a **data-loss path** (`critiquing-spec` Step 9 led with the positional `state_append_run` that has no deferred slots → deferred challenges silently dropped), a **stale-arg leak** (`ARCHITECT_CRITIC_ARGS="${ARCHITECT_CRITIC_ARGS:-} --neutral"` inheriting prior `--spec`/`--close`/`--async`), a **final-round phantom** ("recommend the next round" when there is no K+1), a **semantic mis-alias** (`"you synthesize"` — a request *for* synthesis — treated as a neutral opt-out), plus `--neutral` not forwarded to grill-me gates, a missing best-practice label, a backtick command-substitution test bug, and defer not exposed at gates. All fixed, reviewed on the real HEAD, re-verified green, threads replied-to + resolved before merge.

2. **A seam test that pins exact prose will fight a valid prose fix — update the pin in the same commit.** Codex's added assertion pinned the literal `"Recommended: proceed to the next round"` — which is exactly the buggy phrasing CodeRabbit (correctly) flagged. Fixing the prose broke the test. When a bot-added test pins a string a later finding invalidates, correct the assertion to match the fixed phrasing (here → `"proceed to round K"`), don't revert the fix.

---

## 3. Program state snapshot

**Plugin versions (current `main`):** workspace-init **0.4.0** · scaffold-onboard **0.12.0** · scaffold-dev **0.15.0** · architect-critic **0.5.0** · claude-security-audit **0.1.3** · ai-mentor **2.2.0**.

**Open backlog (4):** **#85** (small chore — `wi_trace_filter_install` `.git`-must-be-a-dir check rejects `--separate-git-dir`/submodule canonicals) · **#38**, **#37**, **#10** (reconsider-first). All enhancement/chore — **zero correctness bugs.**

**Repo state:** `main` tip `0692dad` + this bookkeeping commit; #93 CLOSED; 0 open PRs; 3 tags pushed. Clean tree (only `.claude/` + `docs/superpowers/` untracked).

---

## 4. Recommended next-session entry points

1. **Decision session (#38 / #37 / #10)** — value-reconsideration before any build ([[feedback_reconsider_deferred_before_building]]). These have sat as "reconsider-first" across several handoffs; now is a good moment to **dogfood the new recommend-by-default policy** — run `/council` or `/grill-me` on build-vs-wontfix and watch whether the vision-grounded recommendation actually speeds the call.
2. **#85** — fold the `--separate-git-dir`-canonical hook-path fix into a future workspace-init touch (low priority; narrow).
3. **Dogfood the policy end-to-end** — the next `/critique` or `/orchestrate` is the first real exercise of recommended dispositions + `--neutral`; watch that `--neutral` genuinely suppresses at every gate and that recommendations stay cited (never fabricated).

**Above all: verify on the real HEAD and by GraphQL thread-count (not the fix-cycle summary), keep agent-driven skills free of unnecessary determinism, and keep the shared policy doc byte-identical across the 3 plugins (the parity test enforces it).**
