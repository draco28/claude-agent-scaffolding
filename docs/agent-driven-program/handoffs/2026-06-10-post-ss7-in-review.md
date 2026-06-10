# Session Handoff — #59 + #58 shipped · SS-7 implemented & in bot-review

**Date:** 2026-06-10 · **Author:** prior session (SS-3 follow-ups + SS-7 build) · **For:** next orchestration session
**Read first:** `docs/agent-driven-program/SPEC-agent-driven-program.md` (north star + §5 sub-spec sequence + §6 ledger). This handoff is the delta on top of it, and on top of `2026-06-08-post-ss3-shipped.md`.

---

## 1. What this session did (one line)

Shipped the two SS-3 follow-ups (**#59 → v0.6.1**, **#58 → v0.7.0 wontfix-decommission**), then designed + planned + **fully implemented SS-7** (remove the deterministic `--fast` fallback, **#56 → v0.8.0**) — now **open as PR #62, in bot review** (not yet merged).

---

## 2. ⚠️ FIRST ACTION NEXT SESSION: finish shipping SS-7 (PR #62)

SS-7 is **code-complete and green** but **NOT merged**. The next session's first job is to babysit PR #62 to merge.

- **PR:** #62 `feat(scaffold-onboard): SS-7 — remove deterministic --fast fallback (v0.8.0, #56)`. Branch `feat/ss7-remove-fast-fallback`. State: OPEN, MERGEABLE.
- **Status at handoff:** CodeRabbit posted its walkthrough (no findings yet); Codex was **manually triggered** (`@codex review`) but had not posted a verdict yet. A background watcher (`bc7uuyu1v`) was polling — it will NOT survive into the new session, so **re-check the PR fresh**: `gh pr view 62`, `gh api repos/draco28/claude-agent-scaffolding/pulls/62/comments`.
- **Codex does NOT auto-fire on this repo's PRs** (observed on #61 and #62) — you must comment `@codex review` and wait.
- **Merge rule (durable, `feedback_bot_review_convergence_judgment`):** merge on **Codex "no major issues" + green suite + no product bug**. Triage each finding (don't trust badges), fix genuine bugs + cheap wins, push back on false positives, defer scope-y items to a follow-up issue. Reply in-thread + re-trigger each round.
- **On merge:** squash-merge, `git tag -a scaffold-onboard-v0.8.0 <merge-commit>` + push tag, confirm **#56 auto-closes** (PR body says `Closes #56`), and verify the SPEC ledger N6 row + SS-7 header already say SHIPPED (they were updated in this branch — double-check they landed on main).
- **Local verification commands** (suites are slow, 55-75s/file — background + generous windows):
  - Full suite: `cd scaffold-onboard && bash run-tests.sh` → `18 files / 0 failed`.
  - Repo-root dual-publish: `bash tests/test-codex-dual-publish.sh` → `148 / 0` (version parity guard — NOT under the plugin's own `tests/`).
  - Residue sweep: `grep -rnE 'SF_SYNTH_FAST|sf_synth_mode' scaffold-onboard/{lib,skills,commands,templates,tests,agents}` → only intentional removal-notes / inverted-guard assertions.

### Codex round-1 findings on PR #62 (5 × P2 — ALL triaged GENUINE, NOT yet fixed)

Codex posted 5 inline P2s on the SS-7 skill prose (after the first version of this handoff was written). They are real (2 are data-loss/correctness class) and **must be addressed before merge**. Triage + fix direction:

1. **`scaffolding-memory-bank` §13 migration/seed subshells — DATA-LOSS (comment id 3386006483).** `--regenerate` runs `_sf_mb_migrate_harvested` in one subshell `( cd … && … )` (§13.2, ~line 310) and `sf_memory_bank_seed_live_static --force` in a *separate* subshell (~line 396). The `_SF_MB_MIGRATED_TO_KNOWN_ISSUES` guard set inside the migration subshell never reaches the seed subshell → the just-migrated `09-known-issues.md` is overwritten. **Fix:** run the migration with `pushd/popd` (non-forking) so the flag persists into the parent shell; the seed subshell then inherits it. (Pre-existing in the synthesize path; SS-7 makes it the only `--regenerate` path. Add `test-memory-bank` migrate+force coverage.)
2. **`onboarding-project` §8 inline EXEC-SUMMARY too narrow (comment id 3386006485).** The headless inline fallback says author `EXECUTIVE-SUMMARY.md` from MASTER-SPEC's *pinned `## Executive Summary` section* — but at close that's a thin placeholder; the EXEC-SUMMARY brief synthesizes from broader spec fields. **Fix:** word it "author inline from the full MASTER-SPEC following the EXEC-SUMMARY brief," not the pinned section.
3. **`planning-project-roadmap` §16 conflicting failure model (comment id 3386006487).** The new §16 intro (~line 457) says "re-draft once → hard-fail," but §16.2 (~lines 537, 558) still says "fall back to interactive authoring." **Fix:** reconcile — for roadmap, interactive authoring is *human-driven* (not a deterministic renderer), so it is a legitimate fallback under SS-7. Soften the §16 intro to: dispatch → re-draft once → fall back to the standard R1.C **interactive** authoring (human authors the slice). Do NOT impose hard-fail on roadmap.
4. **`scaffolding-memory-bank` §3/§6 Karpathy lost under synthesis-only CLAUDE — CORRECTNESS (comment id 3386006492).** §13 dispatches `CLAUDE.md` as a synthesized artifact via `CLAUDE.brief.md`, which has **zero** `phase_10.4.include_karpathy` / Behavioral-Discipline handling — so the frontmatter + §6 promise of conditional Karpathy emission breaks. **Fix (recommended):** make `CLAUDE.md` **mechanically generated** by the kept `sf_claude_md_generate` (handles Karpathy + composition conditionals deterministically) — drop it from the synthesized "9 artifacts" and emit it in the §13 finalize alongside `sf_claude_settings_generate` / `sf_agents_md_generate` (CLAUDE.md is a structured/conditional router file, not prose — belongs with settings.json/AGENTS.md as mechanical). Update the §13 artifact list + "9 artifacts" count + dispatch tests. *(Small design adjustment — confirm with user if unsure.)*
5. **`onboarding-project` §8 write-back rejection only warns (comment id 3386006498).** The snippet `if ! sf render_executive_summary_from_synthesized …; then echo "warn…"; fi` only warns then falls through — inconsistent with the re-dispatch-once → hard-fail prose right below. **Fix:** make the snippet surface + stop (capture an rc the prose acts on), consistent with the hard-fail.

**Process:** fix all 5 in one round on `feat/ss7-remove-fast-fallback`, push, reply in-thread to each comment id, re-trigger `@codex review`, re-run full suite + dual-publish. None blocks the *approach* — they're correctness/consistency fixes on the new prose.

---

## 3. Shipped this session ✅

### #59 — SS-3 residual review polish → scaffold-onboard **v0.6.1** (PR #60 merged, tag `scaffold-onboard-v0.6.1`)
8 non-product-bug polish items: new `sf_phases_subsection_gates` helper (exposes subsection-level gates to the conductor) + gate-value unescaping; `sf_state_synthesis_digest` jq fail-fast; gate-aware record-repair (active-subsection eligibility); fresh-`--regenerate` state-init; §8 prompt-assembly error surfacing; eval `onboarding.lock` cleanup; resume-handling doc-sync. Plus 4 bot-review-round fixes (empty-digest guard, §8 hard-stop on digest failure, errexit-leak in a new test). Codex took 3 rounds → clean; CodeRabbit 1 Major (errexit) → fixed.

### #58 — true reconcile → **WONTFIX + decommission** → scaffold-onboard **v0.7.0** (PR #61 merged, tag `scaffold-onboard-v0.7.0`, **#58 closed wontfix**)
Brainstormed; user chose **"neither worth it — reconsider"** → closed #58 wontfix and **removed the dormant reconcile machinery** SS-3 had retained: `sf_synth_master_spec_prompt` reconcile mode (simplified to a **3-arg first-author-only signature** `<brief> <digest_file> <out_path>` + arg-count guard), `sf_state_mark_touched`/`sf_state_run_reset`/`sf_state_phases_touched_this_run`/`touched_this_run`, the reconcile binding in `synthesis-agent.md` + brief, dormant tests. Net **−272/+68**. **No current behavior lost** (reconcile was never wired live). **Accepted limitation (documented, no follow-up):** a `--regenerate` that switches `project_class` (e.g. Web app → Library or SDK) leaves stale inactive-branch answers in the digest (the close critic + accept/edit review catch contradictions). Lesson saved: `feedback_reconsider_deferred_before_building`.

---

## 4. SS-7 — what was built (the in-review delta) 🔧

**Spec/plan:** `docs/agent-driven-program/specs/SS-7-remove-fast-fallback.md` + `…/plans/SS-7-remove-fast-fallback-plan.md` (already on main via #58? NO — committed on the SS-7 branch; they merge with #62).

**The decision:** agent synthesis is the **only** derivation path. **No deterministic content fallback anywhere** — not on a missing Task tool, not on LLM/token-cost failure, not on structurally-bad output.

**Uniform agent-unavailable model** (replaces `--fast` on every content surface): dispatch sub-agent → **main-context-inline** synthesis (headless) → **re-dispatch once** with a corrective instruction → **hard-fail with remediation**.

**Removed:**
- `--fast` flag, `sf_synth_mode`, `SF_SYNTH_FAST` (5 surfaces: memory-bank, governance, onboarding, MASTER-SPEC, roadmap).
- `sf_memory_bank_derive` (lib/memory-bank.sh) — derived files agent-synthesized; **kept** the mechanical helpers `sf_memory_bank_seed_live_static`, `_sf_mb_migrate_harvested`, `_sf_mb_extract/reinject_preserve_zone`.
- `sf_docs_derive`/`_docs_args`/`_write_or_skip` — **`lib/docs.sh` reduced to a header-only stub**; the doc-set catalog + LLM-gate now live in `scaffolding-governance-docs` §11 (skill-owned).
- `sf_render_executive_summary` (extract) + `sf_render_executive_summary_from_state` (bootstrap) — **kept** `sf_render_executive_summary_from_synthesized` (mechanical guarded write-back, the SS-2 SSoT-corruption safeguard).

**Durable design decisions made during SS-7 (settle points):**
1. **"Purest" removal** (user's call): remove ALL deterministic renderers, not just the flag.
2. **EXEC-SUMMARY consumer produce-once-if-missing** (legacy projects via `/scaffold-project`, `/scaffold-docs`) now **dispatches a synthesis agent** from MASTER-SPEC → `_from_synthesized` write-back (was deterministic extract). This gap surfaced mid-execution and was settled with the user.
3. **`03` mcrules-zone on missing-sentinel synthesis:** the orchestrator **mechanically re-attaches** the saved zone (it already includes its sentinels) — never a deterministic re-render. Rules are never lost.
4. **Test strategy** (the bulk of the work): bash can't run a live agent, so memory-bank/governance/e2e tests assert the **mechanical layer** (seed live/static, manifest routing, mcrules-zone, migration, doc-set selection) via **canned-synthesis fixtures** (`seed_memory_bank_synth_fixture` + `seed_governance_docs_fixture` in `tests/_helpers.sh`). `test-docs` became a governance doc-set **contract** (doc-grep on §11). **Derived-content correctness is owned by the `evals/` LLM-judge** (which already covered it — synthesis has been the default since v0.3; only the deterministic `--fast` content was bash-asserted). Dispatch-test fast-flag guards **inverted** to assert absence; new **R3 guard** asserts every content skill documents the inline-fallback model.

**Scale:** net **−970/+811** across 26 files. Full suite 18/0, dual-publish 148/0.

**Key files touched:** `lib/{synthesis,render,memory-bank,docs}.sh`; skills `scaffolding-memory-bank` §13, `scaffolding-governance-docs` §11, `planning-project-roadmap` §16, `onboarding-project` §8; `commands/{scaffold-project,scaffold-docs}.md`; `tests/{_helpers,test-memory-bank,test-docs,test-e2e,test-synthesis-dispatch,test-synthesis,test-master-spec-synthesis}.sh`; `evals/{scaffolding-memory-bank,scaffolding-governance-docs}.md`.

---

## 5. Program state snapshot

**Sub-spec status (SPEC §5):**
- SS-1 ✅ (#45) · SS-2 ✅ (#50/#49/#42) · SS-3 ✅ (#51) · **#59 ✅ (v0.6.1)** · **#58 ✅ wontfix (v0.7.0)** · **SS-7 🟡 IMPLEMENTED, PR #62 in review (#56 → v0.8.0)**
- **SS-4** — agent-review of verification seams (#52, #7, #5, #48-F). Independent. Designed-not-started.
- **SS-5** — Codex implementer/synthesizer backend (#47). Independent. **Inherits SS-3's + SS-7's tool-agnostic synthesis prompts** — natural next for the synthesis side.
- **SS-6** — standalone cleanup to zero (#8, #9, #6, #10, #37, #38, #39, #48-remainder, #53/CI). Interleave.

**Plugin versions (current main, pre-#62-merge):** workspace-init 0.1.2 · **scaffold-onboard 0.7.0** (→ **0.8.0** when #62 merges) · scaffold-dev 0.3.0 · architect-critic 0.2.2 · claude-security-audit 0.1.2 · ai-mentor 2.0.0.

**Open backlog (14, will be 13 after #56 closes on #62 merge):** #56 (SS-7, closing) · #53 (CI/SS-6) · #52 (SS-4) · #48 (F→SS-4, routing→SS-6) · #47 (SS-5) · #39/#38/#37 (SS-6 external-benchmark trio) · #10/#9/#8/#7/#6/#5 (SS-4/SS-6 buckets).

---

## 6. Critical process notes / lessons (apply next session)

- **SS-7's test-strategy shift is the template for future determinism-removals:** when you delete a deterministic renderer, bash tests lose their content source. Convert them to **mechanical-layer assertions + canned-output fixtures**, and move content-correctness to the `evals/` LLM-judge. Don't try to assert agent-authored content in bash.
- **Surface design gaps mid-execution, don't paper over them.** The EXEC-SUMMARY consumer produce-once path was under-specified in the SS-7 spec; stopping to settle it with the user (agent-dispatch vs deterministic extract) was correct (`executing-plans` "stop on plan gaps").
- **Codex doesn't auto-trigger here** — always `@codex review`. **Bot-review convergence** (`feedback_bot_review_convergence_judgment`): Codex "no major issues" is the merge signal; CodeRabbit nit-streams are asymptotic on prose-heavy PRs.
- **Reconsider deferred work before building it** (`feedback_reconsider_deferred_before_building`, new this session): a dormant/deferred feature deserves a fresh value-reconsideration — wontfix + decommission (negative LOC) can beat completion. Evidence: #58.
- **Run the FULL suite + repo-root dual-publish**, and distrust "stale" intermediate background runs (a large coupled refactor leaves the branch red between phases; the gate is at the end). Two stragglers (`test-synthesis` sf_synth_mode, `test-master-spec-synthesis` SS-2 intact-guard) were caught only by the final clean run.
- **`bin/sf` sources all `lib/*.sh`** — a renderer reduced to a stub must stay a valid (function-free) sourced file, or be removed cleanly; don't leave a half-file.
- Handoffs in this **source repo** are manual `docs/agent-driven-program/handoffs/` (the `/handoff` skill refuses — no `.workspace/pairing.json`).

---

## 7. Recommended next-session entry points

1. **Finish SS-7 (PR #62)** — babysit → merge on Codex-clean + green → tag `scaffold-onboard-v0.8.0` → confirm #56 closed. **This is the required first action** (§2).
2. **SS-5** (#47, Codex backend) — strongest *new* candidate: SS-3 + SS-7 left the synthesis prompts fully tool-agnostic, so wiring the Codex implementer/synthesizer backend (`implementer_backend ∈ {claude_subagent, codex}`, `codex-companion.mjs`) is the natural follow-on for the synthesis side.
3. **SS-4** (#52/#7/#5/#48-F) — agent-review of the verification seams (anti-pattern C); makes the agent the single authority over bash dual-paths.
4. **SS-6** (#8/#9/#6/#10/#37/#38/#39/#48-rem/#53) — standalone cleanup-to-zero; interleave, breadth over depth.

Pick one (after #62 lands), run its own `brainstorm → writing-plans → executing-plans → bot-review → release` cycle. Target: zero open backlog. The "agent-driven-only" stance is now nearly complete (SS-7 finishes it for scaffold-onboard derivation); SS-5 extends it cross-tool (Codex), SS-4 extends the principle to scaffold-dev's verification seams.
