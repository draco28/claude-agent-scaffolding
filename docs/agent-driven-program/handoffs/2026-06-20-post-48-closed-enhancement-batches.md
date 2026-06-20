# Session Handoff — #48 fully CLOSED · enhancement burn-down (batched) is what's left

**Date:** 2026-06-20 · **Author:** prior session (shipped #48 Stage 2 → PR #81; closed #48) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§1 North Star + §6 issue ledger), the prior handoff `2026-06-20-post-48-stage1-shipped.md`, and `[[project_friction_log_first_realtest]]` (#48 Stage 1 + Stage 2 closeouts — the durable lessons). This handoff is the delta: **#48 is fully CLOSED; the program is now pure enhancement/chore burn-down — 7 issues, ZERO bugs.**

---

## 1. What this session did (one line)

Built + shipped **#48 Stage 2** (the last piece of the lean-index epic) → PR **#81** merged (squash `2eba9cb`), **scaffold-dev v0.10.0 + workspace-init v0.3.0** tagged; **#48 fully CLOSED**; ledger + friction-log + memory updated (`831596c` on main). Bot review caught a real 🔴 infinite-loop bug (Devin) + 8 other findings — all fixed, regression-tested, resolved.

---

## 2. ⚠️ FIRST ACTION NEXT SESSION — pick an enhancement BATCH (not one-by-one)

7 issues remain, **all enhancement/chore, zero correctness bugs.** The plan (user's call) is to **batch 2–3 coherent issues per PR** rather than grind one at a time. Four of the seven are build-ready and well-specified; three are `deferred` and need a **value-reconsideration FIRST** (they may be wontfix / cherry-pick-a-subset, not full builds — [[feedback_reconsider_deferred_before_building]]).

### Recommended batches (coherence-first)

| Batch | Issues | Why these group | Plugins / PR | Build-ready? |
|---|---|---|---|---|
| **A — scaffold-dev vertical-slice pass** ⭐ do first | **#76 + #77** | Both are **#39 Phase-B / PR #75 follow-ups** that edit the **same two files** (`closing-vertical-slice` + `planning-vertical-slice` SKILL.md). #77 splits reference-grade prose out to `references/*.md` (both files are >500-line-cap: 682 / 729); #76 adds slice-start-baseline record/read. Doing #77 first **makes room** for #76's additions without re-breaching the cap. | scaffold-dev only · 1 PR · minor (0.10.0→0.11.0) | ✅ yes |
| **B — count-aware verify grammar** | **#79** | `auto: … → expected: ran ≥N` form (the #74 Option A escape hatch for runners outside the zero-tests allowlist). Distinct surface (verify/demo grammar), so keep it out of Batch A. | cross-plugin: scaffold-onboard grammar (`sf_demo_parse_line`, `auto-grammar.md`) + scaffold-dev runtime (`sd_verify_auto_step`, both gate sites) · 1 PR · **minor on BOTH** | ✅ yes (larger) |
| **C — hardening grab-bag** | **#71** | Already a 5-item checklist (CI SHA-pin, `--ai-git-tracked` flag, `created_by` version semantics, Scenario-C worktree-canonical edge, perf-bench CI exclusion). Small, mostly independent; one housekeeping PR. | workspace-init + `.github/workflows` · 1 PR | ✅ yes |
| **D — value-reconsideration (DECISION, not build)** | **#38 + #37 + #10** | All `deferred`. #38/#37 = mattpocock-benchmark **cherry-picks**; #10 = **demand-gated** ("depends on real parallel-slice usage signal"). Triage each: build-a-subset / wontfix / keep-deferred — THEN build only what survives. | mixed (scaffold-dev / ai-mentor) · brainstorm-style session | ⚠️ reconsider first |

**Suggested order:** A (tightest, lowest-risk) → C (quick housekeeping) → B (heavier cross-plugin) → D (decide, then maybe build). If you want a heavier single scaffold-dev sprint instead, **A+B together** (#76+#77+#79) is defensible — all scaffold-dev-centric — but it's a bigger PR + bot-review surface (scaffold-onboard grammar + eval changes ride along). I'd keep A pure.

### Continuity note
- **#71's `created_by` item is the SAME thing Devin re-flagged on #81** and we declined as out-of-scope (schema-origin-version vs writing-tool-version semantics — undecided). It lives in #71 now; decide the semantics there.

---

## 3. The 7 open issues (full detail)

**Build-ready (well-specified):**
- **#76** (`enhancement`, scaffold-dev) — record canonical default-branch HEAD at **slice start** (`planning-vertical-slice` §8.1 → slice state schema) and read it at **close** (`closing-vertical-slice` §7.2a), so **direct-mode** async review bundles get a real `<recorded-base>..HEAD` diff (today `merge-base==HEAD` in direct mode → empty diff → omitted). Opt-in gate already degrades gracefully.
- **#77** (chore, scaffold-dev) — `closing-vertical-slice` (682) + `planning-vertical-slice` (729) exceed the **500-line cap** they self-declare. Move reference-grade detail (eval-contract prose, extended gate rationale, harvest/handoff mechanics) into `references/*.md`; keep operative steps + seams in the body. Model = the already-extracted `lib/` helpers (`sd_review_gate_bundle`).
- **#79** (`enhancement`, scaffold-dev) — add `auto: \`<cmd>\` → expected: ran ≥N` (N defaults 1) as the deterministic escape hatch for runners **outside** #74's `sd_zero_tests_guard` allowlist (rspec/mocha/mvn/dotnet/ctest/… + wrapper scripts). scaffold-onboard: extend `sf_demo_parse_line` + `auto-grammar.md` §2 + the two-mode eval. scaffold-dev: parse `ran ≥N` + assert executed-count at all 3 sites. Guard stays the zero-config default; `ran ≥N` is opt-in.
- **#71** (chore/`enhancement`) — PR #70 deferred items: (a) `created_by` version semantics; (b) `--ai-git-tracked` flag (Scenario-C non-git AI workspace shows `git_tracked:true` cosmetically wrong); (c) **SHA-pin** `actions/checkout@v4` in `tests.yml`; (d) Scenario-C linked-worktree-canonical preflight decision; (e) exclude `claude-security-audit/test-perf.sh` from blocking PR CI if flaky.

**Reconsider-value-first (`deferred`):**
- **#38** (`enhancement`,`deferred`, scaffold-dev) — handoff quality controls cherry-picked from mattpocock's handoff skill: required `Suggested skills/plugins` section, artifact-reference discipline (reference don't duplicate), a **redaction pass** (stop on secrets/PII), human-readable `Next-session focus` field, optional ephemeral handoff mode. (`handing-off-session`.) *Note: our handoff system is already structurally stronger; this is selective polish.*
- **#37** (`enhancement`,`deferred`) — grill enhancements from mattpocock's grill-with-docs: `Terminology deltas` capture on `ai-mentor:grill-me` exit, a "code contradicts claim → inspect before accepting" rule, a stricter ADR threshold (hard-to-reverse / surprising / real-tradeoff) in `recording-architecture-decision`, a memory-bank-native domain map, docs-as-you-decide staging. Surface-not-auto-write by default. (ai-mentor + scaffold-dev.)
- **#10** (`enhancement`,`deferred`, scaffold-dev) — `coordinating-parallel-slices` skill (or extend `planning-vertical-slice`): file-set overlap detection (refuse to parallel-spawn slices touching the same files), testcontainer port-collision policy, single orchestrator-owned sprint-close merge gate. **Demand-gated** — explicitly "depends on real parallel-slice usage signal"; largest scope of the seven.

### ⚠️ Unfinished thread still carried forward
- **Operator real-Codex smoke** of the #39 async review-gate path (manual; see `2026-06-20-post-74-shipped.md` §2). CI uses the gh-shim only; the live Codex fresh-frame path has never been exercised end-to-end.

---

## 4. Durable lessons / caveats to carry into every next PR ⭐

1. **🆕 Direct `git push origin main` is now BLOCKED by the auto-mode classifier.** The Stage-2 *code* merged fine via PR #81, but the program's normal **direct-to-main ledger/handoff/docs commits** (e.g. `3125904`, `503b76d`, and this session's `831596c`) hit the guardrail. Commit locally, then **ask the user to `! git push origin main`** or grant a push-to-main Bash rule. Don't open a heavyweight PR for a one-line doc. (Same guardrail gated issue-filing on #74.)
2. **Stage specific paths, NEVER `git add -A`.** `.claude/` is untracked locally (user transcripts + `settings.local.json`); `git add -A` sweeps them in — Devin caught this on #74. (`git add scaffold-dev workspace-init …`, not `-A`.)
3. **README version rows are NOT CI-guarded** — `tests/test-codex-dual-publish.sh` guards claude↔codex *manifest* parity only. workspace-init's row was stale at v0.1.2 (2 minors behind) until this PR. **Bump the README table every release; sanity-check neighboring rows.**
4. **Both publish targets + parity test.** Every version bump touches `.claude-plugin/plugin.json` AND `.codex-plugin/plugin.json`; run `tests/test-codex-dual-publish.sh` after. Verify on the **full** suites (`<plugin>/run-tests.sh`), not named suites — scaffold-onboard suites are slow (55–75s).
5. **Flag-parser footgun (this PR's 🔴).** When adding a value-flag to a `while [[ $# -gt 0 ]]` loop, **guard `[[ $# -ge 2 && -n "$2" ]]` before `shift 2`** — a missing value makes `shift 2` a no-op and spins the loop forever. Mirror the existing guarded parser (`wi_manifest_write`); regression-test an infinite-loop guard with a `perl -e 'alarm N; exec @ARGV'` wrapper so a re-introduction fails fast, not hangs.
6. **A new optional field is also a new hand-edit surface** — validate its sub-schema defensively (type-check before indexing in jq; reject relative paths; require dependent flags together), even though the writer never emits the bad shape.
7. **Bot stack = Codex + CodeRabbit + Devin.** Codex's GitHub connector routinely **times out (~20 min)** on re-review; merge on the convergence judgment = `mergeStateStatus: CLEAN` + shell-suite/CodeRabbit/Devin SUCCESS + **0 unresolved threads** + every finding fixed-and-tested. Reply-and-resolve threads via GraphQL (`addPullRequestReviewThreadReply` + `resolveReviewThread`); poll **unresolved-count**, not commit_id. [[feedback_bot_review_convergence_judgment]]
8. **This is the plugin SOURCE repo** (no `.workspace/pairing.json`) — scaffold-dev slice/handoff skills **refuse here**; handoffs are **manual**, committed to `main`. Develop with the plain `writing-plans → inline TDD → bot-review → release` flow.

---

## 5. Program state snapshot

**The program is NOT done — closing #48 retired one issue, not the program.** "Closing the agent-driven program" = SPEC §6 ledger reaching **zero open backlog** (the North Star, §1). 7 remain — each must be **built** or **consciously wontfix'd/decommissioned**. All correctness bugs are cleared (#74/#66/#63/#48); what's left is pure enhancement/chore burn-down with **no architectural blockers**.

**Open backlog (7 — all enhancement/chore, zero bugs):** #79, #77, #76, #71 (build-ready) · #38, #37, #10 (reconsider-value-first).

**Sub-spec status (SPEC §5):** SS-1…SS-5 ✅ · SS-5.1 ✅ · SS-7 ✅ · **SS-6 — final phase, in progress** (all its correctness bugs done; remainder = these 7 enhancements + #59 SS-3 residual "future" polish).

**Plugin versions (current main, HEAD `831596c`):** workspace-init **0.3.0** · scaffold-onboard 0.9.2 · scaffold-dev **0.10.0** · architect-critic 0.3.0 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Tags this session:** `scaffold-dev-v0.10.0` + `workspace-init-v0.3.0` (both on merge commit `2eba9cb`).

**Repo state:** local `main` = origin `main` = `831596c`, clean tree (only `.claude/` untracked). 0 open PRs. CI green. #48 CLOSED.

---

## 6. Recommended next-session entry points

1. **Batch A (#76 + #77)** — the do-first scaffold-dev vertical-slice pass. Plain `writing-plans → inline TDD → bot-review → release`; one PR; scaffold-dev minor (0.10.0→0.11.0). Tightest coherence, lowest risk.
2. **Batch C (#71)** — quick housekeeping (CI SHA-pin + workspace-init writer flags + the deferred semantics calls). One PR.
3. **Batch B (#79)** — count-aware `auto:` form; cross-plugin, own PR, minor on both. Heavier (grammar + eval surface).
4. **Decision session D (#38/#37/#10)** — value-reconsideration before any build; for each decide build-subset / wontfix / keep-deferred. Then build only what earns it.

**Target remains zero open backlog (7 → 0).** No bugs, no blockers — this is the program end-game.
