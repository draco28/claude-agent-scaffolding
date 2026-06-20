# Session Handoff — #74 SHIPPED (scaffold-dev zero-tests guard → v0.8.1); last SS-6 bug CLOSED

**Date:** 2026-06-20 · **Author:** prior session (fixed #74 → PR #78, scaffold-dev **v0.8.1**) · **For:** next session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (§5 sub-spec sequence + §6 issue ledger) and the prior handoff `2026-06-20-post-39-phaseB-shipped.md`. This handoff is the delta: **#74 is CLOSED; the SS-6 backlog now has NO open bugs — only enhancements/chores remain.**

---

## 1. What this session did (one line)

Fixed **#74** (`auto:` AC `exit 0` vacuous-pass / TDD false-green) via inline TDD + 3-bot review → PR **#78** merged (squash `f0cf79d`), **scaffold-dev v0.8.1** tagged, **#74 CLOSED**. Backlog **6 → 5** substantive (7 issues total, all enhancements/chores).

---

## 2. ⚠️ FIRST ACTION NEXT SESSION

**Pick the next SS-6 item. There are no open bugs left — all remaining are enhancements/chores.** Suggested order:

1. **#48 — scaffold-dev #33 follow-ups** (lean-index Parts C–F: doc-anchors / ADR+claude-mem pointers / linter + `/defer` marketplace routing + label auto-create). The most substantive remaining batch; C/F want agent-assisted validators.
2. **#77 — closing/planning SKILL.md over the 500-line cap** → extract reference detail to `references/*.md`. **This session's #74 edits grew both files a little more** (added the zero-tests-guard prose to `closing-vertical-slice` §5 and `implementation-checking` §6), so the cap overage is slightly worse — clean references/ extraction is the fix. Touches files we just edited.
3. **#76 — direct-mode async review-bundle diff baseline** (#39 Phase B follow-up): record canonical-HEAD-at-slice-start in planning §8.1 → slice state → read at close so `direct`-mode bundles get a real diff.
4. **#71 — PR #70 review follow-ups** incl. **CI SHA-pinning** (`actions/checkout@v4` → pin to SHA). Chore.
5. **#37 / #38 / #10** — deferred enhancements; cheap cherry-picks exist (#37 strict ADR threshold, #38 redaction leg). #10 (coordinating-parallel-slices) is demand-gated — park unless a real multi-slice need appears.

**Open backlog (8 issues, all enhancement/chore):**

| # | Title | Flavor |
|---|---|---|
| **#48** | #33 lean-index C–F + /defer routing + label auto-create | enhancement (substantive) |
| **#79** | count-aware `auto:` form `expected: ran ≥N` (#74 Option A) | enhancement (this-session follow-up; MINOR on both plugins) |
| **#77** | closing/planning SKILL.md > 500-line cap | chore (grew slightly this session) |
| **#76** | direct-mode async review-bundle diff baseline | enhancement (Phase-B follow-up) |
| **#71** | PR #70 review follow-ups (incl. CI SHA-pin) | chore |
| **#37** | grill domain-language + ADR thresholds | enhancement (partial / cherry-pick) |
| **#38** | handoff suggested-skills + artifact-refs + redaction | enhancement (redaction leg has standalone value) |
| **#10** | coordinating-parallel-slices | enhancement (demand-gated) |

### ⚠️ Two unfinished threads to action

1. ~~File the deferred #74 Option A issue.~~ **DONE — filed as [#79](https://github.com/draco28/claude-agent-scaffolding/issues/79)** (count-aware `auto:` form `expected: ran ≥N` for runners outside the zero-tests allowlist / wrapper scripts). CHANGELOG updated to cite it.
2. **Operator real-Codex smoke** of the #39 async path is still open (manual; see the prior handoff §2) — CI uses the shim only; no live Codex.

This is the plugin **source** repo (no `.workspace/pairing.json`) — scaffold-dev slice/handoff skills refuse here; develop with the plain `brainstorm → spec → writing-plans → inline TDD → bot-review → release` flow and **manual** handoffs committed to `main`.

---

## 3. What shipped this session 🔧 (scaffold-dev v0.8.1, PR #78)

- **`lib/verify.sh::sd_zero_tests_guard <cmd> [output]`** — new pure, side-effect-free helper (never executes `<cmd>`; inspects already-captured output). Returns 0 = SAFE, 1 = VACUOUS. **Allowlist-only + fail-soft**: recognized runners = pytest / go test / cargo test / cargo nextest / jest / vitest / node --test; any unrecognized runner or wrapper script → SAFE (today's behavior, no regression). Biased hard to false-negative-miss over false-positive-fire. Reads output from `$2` or, when omitted, **stdin** (the SKILL.md gates pipe the log via stdin to avoid `ARG_MAX`).
- **Wired into all three exit-code sites + the red gate** (all on the `exit 0` form only; `exit N` negative-test ACs exempt): `sd_verify_auto_step`, `implementation-checking` §6, `closing-vertical-slice` §5, and `sd_redgate_assert_red` (a vacuous green is treated as **RED / missing-test** so the implementer proceeds, not "already GREEN" / hard-block — this was the bug's own live-observed TDD-red scenario).
- **Doc:** `scaffold-onboard authoring-vertical-slice-demo/references/auto-grammar.md` §2.1 documents the guard (doc-only; **no scaffold-onboard version bump** — parity test doesn't require it).
- **Two user-settled design calls** (AskUserQuestion at plan time): **fail** not warn (gates run in agent loops that ignore stderr); **guard-only patch** (defer the explicit count-aware grammar form).
- 65 verify tests (pure helper + dispatcher + stdin + wired + red-gate); full scaffold-dev suite (21 files) + repo-root dual-publish parity (153/0) green.

**Review story:** 3 Codex rounds + Devin. **Devin caught a real defect** — an over-broad `git add -A` had swept 5 stray untracked `.claude/` files (transcripts + `settings.local.json`) into the commit; removed via `git rm --cached` + amend + force-push. Codex rounds each surfaced a deeper test-runner-output edge case (cargo options → go multi-package/-json → node default reporter → go -json test-level-vs-package-level evidence + go -C + red-gate parity). Codex re-review **timed out ~20 min** on the final round (same as #75); merged on green CI + CodeRabbit/Devin pass + 0 unresolved threads + all findings resolved.

---

## 4. Durable lessons (apply next session) ⭐

1. **Stage specific paths, never `git add -A`, when the working tree has unrelated untracked dirs.** Session start had `?? .claude/`; `git add -A` committed the user's local transcripts. Devin caught it. (See [[project_friction_log_first_realtest]] #74 closeout, lesson 1.)
2. **A heuristic that pattern-matches external-tool output invites deep iterative bot review** — expect a reviewer to probe each runner's edge cases. **The fail-soft bias is what makes each interim miss safe** (a missed runner = today's behavior, never a wrongly-failed green); ship the allowlist and let review extend it. [[feedback_extract_mechanical_prose_on_recurring_findings]].
3. **A guard added to one gate must be applied to sibling gates with shared semantics** (same class as the #63 "enforce the invariant on every branch" lesson). Codex caught the **red gate** needing the same `exit 0` zero-tests treatment. [[feedback_bot_review_convergence_judgment]].
4. **Poll bot re-review by `submittedAt` timestamp > push time, not commit_id** (commit_id lags HEAD). Codex re-review can time out ~20–25 min — merge on the resolved-state + green-suite convergence judgment when it does.

---

## 5. Program state snapshot

**Where the whole program stands (the strategic picture for the next session):** the agent-driven-program SPEC's North Star is **zero open backlog** via a planned sequence of sub-specs (SPEC §5). **Every architectural/derivation-pivot sub-spec is now SHIPPED** — SS-1 (memory-bank ownership), SS-2 (live synthesis + post-derivation review), SS-3 (agent-synthesized resumable onboarding), SS-4 (agent-review of verification seams), SS-5 (Codex implementer backend), SS-5.1 (Codex synthesizer backend), SS-7 (remove deterministic `--fast` fallback). **SS-6 — "standalone cleanup to zero" — is the FINAL sub-spec, and the program is now inside its end-game.** With #74 closed there are **no correctness bugs and no architectural work left anywhere in the program**: what remains is pure enhancement/chore burn-down toward zero backlog. So the next session is not picking up a feature thread — it's choosing which cleanup item to retire next on the way to closing the program out.

**Sub-spec status (SPEC §5):** SS-1…SS-5 ✅ · SS-5.1 ✅ · SS-7 ✅ · **SS-6 — final phase, in progress** (all correctness bugs cleared incl. #74/#66/#63; remaining are all enhancements/chores — see §2 backlog table). SS-6's original §5 scope ("Closes the 9 independent issues + N5") is largely done; the open items are the demand-gated/partial enhancements (#10/#37/#38), the #48 remainder, and chores/follow-ups (#71/#76/#77/#79) plus #59 (SS-3 residual polish, non-bug, "future").

**Plugin versions (current main, HEAD `f0cf79d`):** workspace-init 0.2.0 · scaffold-onboard 0.9.1 · **scaffold-dev 0.8.1** · architect-critic 0.3.0 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Tag this session:** `scaffold-dev-v0.8.1` (#74).

**Repo state:** local `main` = origin `main` = `f0cf79d`, clean tree. 0 open PRs. CI green (Linux). #74 CLOSED. (Note: `.claude/` remains untracked locally, as before.)

---

## 6. Recommended next-session entry points

1. **#48** mechanical batch (most substantive) — brainstorm → build → scaffold-dev patch/minor.
2. **#77** clean references/ extraction across the two now-oversized (and slightly-more-over after #74) skills.
3. **#79** (count-aware `expected: ran ≥N` form) — the cleanest companion to this session's #74 guard; MINOR bump on both plugins (grammar parser + runtime).
4. Else a cheap cherry-pick from #37 (ADR threshold) / #38 (redaction) / #71 (CI SHA-pin).

**Target remains zero open backlog.** No bugs remain — the work is now enhancement/chore burn-down.
