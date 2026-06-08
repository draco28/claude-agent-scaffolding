# Session Handoff — Post-SS-3 (shipped) + SS-7 placement

**Date:** 2026-06-08 · **Author:** prior session (SS-3 build + ship) · **For:** next orchestration session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (north star + §5 sub-spec sequence + §6 ledger). This handoff is the delta on top of it.

---

## 1. What this slice did (one line)

Created **SS-7** (placed #56), then took **SS-3** brainstorm → design-lock → 12-task plan → subagent-driven build → 10-round Codex/CodeRabbit review → **shipped scaffold-onboard v0.6.0** (PR #57, #51 closed). Reconcile-on-re-onboard was **descoped to #58** mid-review; residual polish → **#59**.

---

## 2. Shipped: SS-3 — agent-synthesized, resumable onboarding ✅

**Release:** PR #57 squash-merged `3193308`; tag `scaffold-onboard-v0.6.0`; **#51 CLOSED**; ledger flip `3f0d1b8`. scaffold-onboard **0.6.0** (Claude+Codex parity). Full suite 18/0, repo-root dual-publish 148/0.

**What it delivers (the #51 value):**
- **MASTER-SPEC is agent-synthesized at Phase-10 close** — replaces the mechanical `sf_master_spec_update_phase` `{{phase_*}}` transcription. Execution: dispatch `scaffold-onboard:synthesis-agent` → **main-context-inline fallback** if no Task tool → retry-later only if host runtime broken. **No deterministic MASTER-SPEC renderer exists** (the transcription fns + `MASTER-SPEC.md.tmpl` were deleted).
- **State schema v2** (`onboarding-state.json`): `phase_records` (agent-authored decisions/rationale/alternatives/constraints/critic-outcomes) beside verbatim `answers`; `touched_this_run`. Legacy v1 migrates gracefully.
- **`close_pending` lifecycle:** `sf_state_advance_phase` sets `close_pending` at Phase 10; `sf_state_mode` maps it → `resume`; `complete` is set **only** by §8 close-success. So a failed/interrupted close (synth/validate failure) is resumable, not stuck in `reonboard`.
- **Tool-agnostic MASTER-SPEC synthesis brief** (`templates/synthesis-briefs/MASTER-SPEC.brief.md`, zero Claude-isms) → Codex-ready, feeds SS-5.
- **Digest-via-file** (`sf_synth_master_spec_prompt` reads digest from a temp file, ARG_MAX-safe; temp file cleaned up after assembly).
- **EXEC-SUMMARY** synthesis (SS-2) unchanged; MASTER-SPEC emits the fillable `## Executive Summary` section it pins into.
- **Re-onboard (`--regenerate`)** = full re-walk (existing answers as defaults) + first-author re-synthesis; prior spec backed up to `MASTER-SPEC.md.bak-<ts>`. (NOT partial reconcile — see deferrals.)

**Key files:** `scaffold-onboard/lib/state.sh` (schema + phase_records + digest + close_pending), `lib/synthesis.sh` (`sf_synth_master_spec_prompt`), `skills/onboarding-project/SKILL.md` (§3 per-phase record authoring, §4 resume/re-onboard/`--fresh`/`--force-unlock`, §8 close ceremony), `templates/synthesis-briefs/MASTER-SPEC.brief.md`, `agents/synthesis-agent.md` (first-author/reconcile binding rules), tests `test-phase-records.sh` + `test-master-spec-synthesis.sh`.

---

## 3. Decisions made this slice (durable)

**SS-3 brainstorm settlements (2026-06-06):**
1. Synthesis runs **once at Phase-10 close**, not per-phase. No MASTER-SPEC on disk until close; per-phase recaps are in-conversation echoes from state.
2. The "phased-discussion file" **IS** the enriched `onboarding-state.json` — no separate scratch file (**OQ-3 dissolved**).
3. Per-phase records are authored by the **main conducting agent** (not a sub-agent), alongside verbatim raw answers (no telephone-game).
4. **No deterministic MASTER-SPEC renderer** — two agent paths, zero deterministic (**pioneers OQ-5**; SS-7 adopts program-wide).
5. Brief is **tool-agnostic**; only Claude dispatch wired (Codex backend = SS-5).
6. Enhancement re-runs originally settled as **reconcile** — **later descoped** (see §4).

**SS-7 placement (2026-06-07):** #56 (remove deterministic `--fast` fallback) got its **own sub-spec SS-7** (SPEC §5 + N6 ledger + **OQ-5** agent-unavailable behavior), rather than folding into SS-3 — the `--fast` engine spans memory-bank/governance/onboarding/MASTER-SPEC/roadmap, too broad for SS-3.

**Mid-review course-correction (2026-06-07, user-approved):** revert the gate-filtering experiment + descope partial reconcile (see §4).

**Merge decision (2026-06-08, user-approved):** merge on **Codex-clean + green suite + no product bug**, capturing residual CodeRabbit nits in a follow-up — rather than chase CodeRabbit-zero. See lesson in §6.

---

## 4. What we deferred / are differing on (READ THIS)

> **Partial reconcile-on-re-onboard was DESCOPED from SS-3 → #58.** The original SS-3 §2.4 promised "reconcile mode" (re-run refreshes only touched phases, preserves untouched sections + human edits). It was descoped after it generated a multi-round defect tail and a **first-author regression**: a round-4 attempt to make `sf_phases_questions_for` gate-aware (to filter the reconcile digest) gated out Phase-9's LLM opt-in — `9.3`'s gate `uses_llm == true` reads answer `9.3.1` which lives *inside* `9.3` (self-referential gate). We **reverted** the gate-filtering experiment and **descoped reconcile**. SS-3 ships **full re-walk + first-author re-synth** instead.
>
> - **Retained DORMANT in the lib for #58:** `sf_synth_master_spec_prompt` reconcile mode, `sf_state_mark_touched`, `touched_this_run`. They're tested but not driven by the live skill flow.
> - **#58** = true reconcile done right: gate-aware digest (handling self-referential gates), partial/touched refresh, preserve human edits, multi-phase revise UX, stale-inactive-branch-answer filtering.
> - **#59** = SS-3 residual review polish (non-product-bug): gate-in-repair refinements, "don't skip optional Qs in repair", check prompt-assembly before dispatch, expose subsection gates to the conductor, init state for fresh `--regenerate`, eval lock-clear, `jq` fail-fast in digest, resume-handling doc-sync. Codex was clean on all of these; deferred to avoid asymptotic churn.

**Spec/plan docs are marked accordingly:** the SS-3 spec doc has a `⚠️ DESCOPE` banner (decision #4 marked `→ #58`); the plan has a `⚠️ SUPERSEDED` banner; both keep the original reconcile design as historical record. **Do not re-implement reconcile from the spec/plan body without reading #58.**

---

## 5. Program state snapshot

**Sub-spec status (SPEC §5):**
- SS-1 ✅ SHIPPED 2026-06-04 (#45) · SS-2 ✅ SHIPPED 2026-06-05 (#50/#49/#42) · **SS-3 ✅ SHIPPED 2026-06-08 (#51)**
- **SS-4** — agent-review of verification seams (#52, #7, #5, #48-F). Independent. Designed-not-started.
- **SS-5** — Codex implementer/synthesizer backend (#47). Independent. **Inherits SS-3's tool-agnostic brief** — natural next for the synthesis side.
- **SS-6** — standalone cleanup to zero (#8, #9, #6, #10, #37, #38, #39, #48-remainder, #53/CI). Interleave.
- **SS-7** — remove deterministic `--fast` fallback (#56). Depends on SS-2 (shipped). scaffold-onboard-only. **Created, design-pending** (OQ-5 already answered by SS-3's precedent: dispatch → main-context-inline → retry-later; no deterministic path).

**Plugin versions:** workspace-init 0.1.2 · **scaffold-onboard 0.6.0** · scaffold-dev 0.3.0 · architect-critic 0.2.2 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Open backlog (16):** #59, #58 (SS-3 follow-ups) · #56 (SS-7) · #53 (CI/SS-6) · #52 (SS-4) · #48 (SS-1-C/D/E done; F→SS-4, routing→SS-6) · #47 (SS-5) · #39/#38/#37/#10/#9/#8/#7/#6/#5 (SS-4/SS-6 buckets).

---

## 6. Critical process notes / lessons (apply next session)

- **Bot-review convergence (NEW lesson, saved as `feedback_bot_review_convergence_judgment`):** on prose-heavy PRs (skills/specs), the Codex/CodeRabbit loop does **not** reach an empty pass — each push spawns new fine-grained findings, and some fixes spawn the next round's findings. **Codex's "no major issues" verdict is the reliable bug signal; CodeRabbit's "Major"-labeled items are mostly doc/test/robustness on prose.** Triage-verify each (don't trust badges), fix genuine bugs + cheap wins, push back on false positives, **defer scope-y/non-product items to a follow-up issue**, and merge on Codex-clean + green suite. Surface the asymptote to the user for an explicit merge call. SS-3 went **10 rounds** before this call.
- **The gate-filtering trap:** `phases.yaml` gates live on **subsections**, and at least one (`9.3`/`uses_llm`) is **self-referential**. Keep gate-skipping the **conducting agent's job in the per-phase loop** — do NOT make `sf_phases_questions_for` gate-filter (it caused the LLM-opt-in regression). #58 must solve self-referential gates properly.
- **Test the upgrade input class** (standing lesson, `feedback_test_upgrade_input_class`): the genuine bugs review caught were on legacy-state / interrupted-resume / re-onboard paths, not fresh-derive. Feed those shapes.
- **Run the FULL suite** (`bash scaffold-onboard/run-tests.sh`, 18 files) + the **repo-root** `bash tests/test-codex-dual-publish.sh` (148; version-parity + SKILL frontmatter — NOT under the plugin's own tests/, a subagent got this wrong). Suites are slow (55-75s+) — background with generous windows.
- **`gh` in `while-read` loops** fails under the zsh Bash-tool shell ("command not found: gh") — use explicit per-item calls or a `for` loop, not `while ... done < file`.
- **GraphQL `resolveReviewThread`** needs the thread node id; reply in-thread via `gh api repos/.../pulls/57/comments/<databaseId>/replies` (per receiving-code-review).
- Handoffs in this **source repo** are manual `docs/agent-driven-program/handoffs/` (the `/handoff` skill refuses — no `.workspace/pairing.json`).

---

## 7. Recommended next-session entry points

1. **SS-7** (#56, remove `--fast`) — design-lock + build. OQ-5 already answered (SS-3 precedent). scaffold-onboard-only, well-bounded, removes a whole deterministic surface. **Strong candidate** — completes the "agent-driven only" stance SS-3 pioneered.
2. **SS-5** (#47, Codex backend) — inherits SS-3's tool-agnostic brief; natural follow-on for the synthesis side.
3. **SS-4** (#52/#7/#5/#48-F) — agent-review of the verification seams (anti-pattern C).
4. **#58 / #59** — only if you want to finish the reconcile story / polish before moving the program forward (lower leverage than a new sub-spec).

Pick one, run its own `brainstorm → writing-plans → subagent-driven build → bot-review → release` cycle. Update the §6 ledger as issues close (target: zero).
