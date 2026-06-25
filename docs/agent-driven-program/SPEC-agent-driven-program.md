# Program Spec — Agent-Driven Scaffold Ecosystem (zero-backlog roadmap)

**Status:** Draft (program-level) · **Date:** 2026-06-01 · **Supersedes the planning role of:** `docs/SPEC-issue-backlog-triage.md` (tiers folded in below)
**Scope:** `workspace-init` + `scaffold-onboard` + `scaffold-dev` (three-plugin refactor)
**Why this doc exists:** A durable, cross-session plan. Any new orchestration session resumes from here: the north-star model, the three root anti-patterns, the phased sub-specs, and a per-issue ledger that drives the GitHub backlog to **zero**.

> **Decision provenance:** Settled with the user 2026-06-01 (Option C — full mechanical→agent-driven refactor; `#45` is the *wedge*, not the job). Memory: `project_agent_driven_first_class_pivot`. Builds on the promoted principle `feedback_agent_review_over_deterministic_gates` (architect-critic `pp-e72993dfb626c518`).

---

## 1. North Star

**Agent-driven is the first-class workflow. Bash/deterministic code is reserved exclusively for non-reasoning facts.**

- **Reason / judge / author content → dispatch a sub-agent (or reason in-conversation).** Deriving a spec, a doc, a memory-bank file, a slice decomposition, a review verdict — all reasoning.
- **Mechanical-only (KEEP) → bash.** File I/O, path resolution, `git`/`gh` invocation, exit-code checks, JSON state read/write, parse-validity, idempotent fixed-format appends, atomic writes, locking. No judgment.
- **Derivation is reconciliation, not regeneration.** Re-deriving any artifact **merges** new source-of-truth with the existing file — refresh spec-derived prose, **preserve** accumulated learnings (harvest entries, machine-checkable rules, user edits). An agent can do this 3-way merge; a template `>` redirect cannot. This is the single idea that dissolves `#45` and its whole blast radius.
- **One source of truth per job.** Never a mechanical parser *and* an agent path both claiming the same extraction with no authority. Pick one (prefer the agent per the agent-review principle); the other becomes an explicit, labeled fallback.
- **SSoT = `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md`, themselves agent-synthesized and reconcilable.** Not template fill-in.

**Non-goal:** ripping out bash wholesale. Most of `workspace-init` and all the git/state plumbing is *correctly* mechanical and stays. The refactor targets reasoning-forced-into-mechanism, not mechanism itself.

---

## 2. The three root anti-patterns (audit, 2026-06-01)

A six-stream audit of the full flow (`workspace-init → /onboard → /scaffold-docs → /plan-roadmap → /scaffold-project → scaffold-dev`) collapsed every flagged site into three classes. **This is the spec's backbone — each sub-spec kills one or more.**

### A · Regeneration, not reconciliation
Re-derive overwrites wholesale instead of merging accumulated knowledge.
- `scaffold-onboard/lib/memory-bank.sh:84-88` — the 8 derived files render unconditionally (no skip-check even without `--regenerate`). Only `AGENTS.md` gets a managed-section merge (`sf_agents_merge_managed_section`).
- Harvest (`closing-vertical-slice`) + machine-checkable rules (`authoring-machine-checkable-rules`) write into derived `03`/`04` → **clobbered** on next `/scaffold-project`.
- `/scaffold-docs` re-derive is skip-if-exists or `--regenerate` wholesale clobber; merge is a documented non-goal.
- **This is `#45`'s root**, and the same defect at the docs layer.

### B · Mechanical transcription where synthesis belongs
Raw answers slotted into `{{placeholders}}`; reasoning assumed to have happened "in the conversation" and stored as flat strings.
- `MASTER-SPEC.md` is built by `sf_master_spec_update_phase` substituting raw phase answers into `{{phase_1.1.1}}` slots — **transcription, not synthesis.**
- `EXECUTIVE-SUMMARY.md` has a `{{executive_summary}}` placeholder with **no source question and no implemented render function** — a hole (`sf_render_executive_summary` is referenced in SKILL.md but does not exist).
- `/scaffold-docs` default run appears to emit template stubs carrying literal `TODO:` / `*(populate after planning)*` markers.

### C · Dual-path / grammar-collision
A mechanical parser *and* an agent path both claim one job; prose that doesn't match the assumed grammar is silently dropped, or the two paths simply disagree.
- `scaffold-dev/lib/harvest.sh` AWK parser assumes `- target_file: X / suggestion: Y` bullets, but `executing-work-item`'s report template lets implementers write free-form prose → real suggestions silently lost. Meanwhile `closing-vertical-slice` SKILL.md describes harvest as *agent-judged*. Two harvests, no authority.
- Bash `sf_memory_bank_derive` (always overwrite) vs SKILL.md §13 synthesis prose (skip-if-exists) **disagree** on re-derive semantics.
- Work-item AC grammar is author-validated only; malformed `auto:` lines pass authoring and misfire at the verification gate.

---

## 3. Per-flow audit verdict (durable record)

| Flow | Verdict | Anti-patterns present |
|---|---|---|
| **workspace-init** (init/pair) | **Legitimately mechanical — leave it.** Git/repo plumbing, `jq` manifest, rollback. Only soft flag: 3 static stub templates (boilerplate, low stakes). | — (B-lite, deferred) |
| **/onboard → MASTER-SPEC** | Q&A + critic moments are agent; **MASTER-SPEC is mechanical transcription**; EXEC-SUMMARY is an unimplemented hole. | **B** |
| **/scaffold-docs** | Synthesis briefs + `synthesis-agent` exist & are tested, but the default likely **falls through to template stubs** (synthesis "shipped but not exercised end-to-end" — corroborated by memory `project_scaffold_onboard_v03_synthesis_design`). No merge on re-derive. | **A, B** |
| **/plan-roadmap** | **~95% agent-driven and correct.** User dictates, Claude judges; only state-I/O + ROADMAP render are mechanical (legit). Slice content interactive-not-synthesized *by design*. | — (minor; v0.3 synthesis hook optional) |
| **/scaffold-project** (memory bank) | **The epicenter.** Bash path overwrites 8 derived files + CLAUDE.md unconditionally; harvest + mcrules clobbered; phantom target files. | **A, C** |
| **scaffold-dev** (slices/work-items/close) | Substantially **agent-driven** (decomposition, dispatch, demo-judging, critic). Plumbing legit-mechanical. Flags are grammar-collision seams. | **C** |

---

## 4. Target model (what "fixed" looks like)

1. **Reconciliation primitive.** A reusable mechanism: given `(source-of-truth, existing-artifact)`, an agent produces a merged artifact that refreshes SoT-derived prose and preserves accumulated/append zones. Used by memory-bank derive, governance derive, and MASTER-SPEC enhancement re-runs. The deterministic template render becomes the explicit `--fast` fallback, never the silent default.
2. **Agent-first derivation, on by default.** `/scaffold-project` and `/scaffold-docs` dispatch synthesis sub-agents by default; bash render is `--fast` opt-in. Verified by an actual invocation trace (see OQ-1).
3. **Synthesized, resumable, reconcilable SSoT.** Onboarding persists a phased-discussion file (resumable across sessions); at completion an agent synthesizes MASTER-SPEC + EXEC-SUMMARY via a **tool-agnostic plugin prompt** (Claude *or* Codex); scratch file deleted; enhancement re-runs reconcile a new phased-answer file into the existing SSoT.
4. **Single authority per extraction.** Harvest, deferrals, suggestions, spec-citations: the agent reads and judges; any bash helper is a labeled fallback, not a competing parser.
5. **Mechanical boundary, explicit.** A short "what stays bash" list lives in the memory bank / governance so future work doesn't re-litigate it (exit codes, `gh`/git rc, path resolution, parse-validity, atomic writes, locking, fixed-format appends).

---

## 5. Phased sub-specs

Each sub-spec gets its own `brainstorm → writing-plans → build → bot-review → release` cycle later. Sequencing respects dependencies; cleanup interleaves.

### SS-1 — Memory-bank ownership + single-point update cadence (anti-pattern A core) · **FOUNDATIONAL, FIRST** · ✅ SHIPPED 2026-06-04
**SHIPPED 2026-06-04** (PR #54, squash `237675d`; tags `scaffold-onboard-v0.4.0` + `scaffold-dev-v0.3.0`; closed #45). Built via subagent-driven-development; converged after a Codex/CodeRabbit review cycle that caught 4 real data-loss-on-upgrade defects the build missed (legacy-mcrule preserve, `--force` 09 carve-out, migrate-from-all-derived-files, 08-governance stale cadence). Design-locked in `docs/agent-driven-program/specs/SS-1-memory-bank-cadence.md` (2026-06-02). Key resolution: classify each bank by ownership (pure spec-derived / pure dev-authored / mixed) — which shrinks #45 to **two files**. Separate dev-authored learnings into **new live-seed files (`09-known-issues`, `10-decisions-log`)**; keep machine-checkable rules in `03` inside one **mechanically-preserved zone**. **OQ-2 resolved: no agent-merge engine needed** — file separation + mechanical zone-preservation suffices (preservation is a non-reasoning fact). Plus a **single-point cadence policy** (event × bank × who) with a de-contamination sweep so no skill restates the cadence.
**Closes:** `#45`. **Partially:** `#48` C/D/E.

### SS-2 — Synthesis Live & Verified + EXEC-SUMMARY + post-derivation review (anti-pattern A/B) · depends on SS-1 · ✅ SHIPPED 2026-06-05
**SHIPPED 2026-06-05** (PR #55, squash `90bcd19`; tag `scaffold-onboard-v0.5.0`; closed #50/#49/#42). Built via subagent-driven-development (implementer + two-stage spec/quality review per work item), then a Codex/CodeRabbit review cycle that caught real defects the build missed: a **MASTER-SPEC write-back corruption** (a synthesized summary containing `---`/`##` could silently truncate/corrupt the source-of-truth — found by an adversarial correctness review, not the green tests), a `--fast` finalize that **re-rendered (clobbered) the just-synthesized files** (now `sf_memory_bank_seed_live_static`), and the truncate-before-guard gap. EXEC-SUMMARY gained a single authoritative producer with **write-back into MASTER-SPEC** + cksum-staleness. The deterministic `--fast` routing on the path slated for removal was deferred to **#56** (agent-driven-only direction). Design-locked in `docs/agent-driven-program/specs/SS-2-synthesis-live-and-verified.md` (2026-06-04). OQ-1 resolved: synthesis is **LIVE-BUT-BUGGY + untested**, not dark — so SS-2 is a blend of "turn it on" and "fix the model." Make the wired dispatch *executable* on both surfaces (source the libs the dispatch/fallback bodies call — §13.1 currently sources only synthesis.sh+routing.sh → `set -u` abort; replace comment-only `# STOP`), synthesize EXEC-SUMMARY from MASTER-SPEC (onboarding-close + Wave-0 refresh), add an **advisory** whole-bundle post-derivation review sub-agent (`derivation-reviewer`), and add the **missing dispatch integration test** (stubbed agent return) so a broken dispatch can't merge green. `--fast` stays the explicit fallback. **Reconciliation-into-re-derive is a NON-GOAL** (SS-1 dissolved it). scaffold-onboard-only.
**Closes:** `#42`, **N2**/`#50` (dark-synthesis), **N1**/`#49` (EXEC-SUMMARY hole). Dissolves the `TODO:`-stub problem.

### SS-3 — Agent-synthesized, resumable onboarding (anti-pattern B + resumability) · parallel-eligible after SS-1 · ✅ SHIPPED 2026-06-08
Design-locked in `docs/agent-driven-program/specs/SS-3-agent-synthesized-resumable-onboarding.md` (2026-06-06). Scope refined post-SS-2: EXEC-SUMMARY synthesis + resumable state already shipped in SS-2, so SS-3's live core is **MASTER-SPEC transcription → agent synthesis**. Settlements: the "phased-discussion file" **is** the enriched `onboarding-state.json` (no separate scratch file → **OQ-3 dissolved**); per-phase records are authored by the **main conducting agent** (decisions/rationale/rejected-alternatives/critic-outcomes) alongside verbatim raw answers; MASTER-SPEC is synthesized **once at Phase-10 close** (no on-disk spec until close; recaps become echoes); **no deterministic MASTER-SPEC renderer** — sub-agent dispatch → main-context-inline fallback → retry-later only if host broken (**pioneers OQ-5**, SS-7 adopts it); enhancement re-runs **reconcile** (refresh touched phases, preserve untouched sections + human edits); the synthesis brief is **tool-agnostic** (Codex-ready) but only Claude dispatch is wired (SS-5 wires Codex).
**Closes:** **N3**/`#51` (MASTER-SPEC transcription→synthesis). **Enables:** Codex-run synthesis (SS-5). **Pioneers:** OQ-5 (adopted by SS-7). (N1/EXEC-SUMMARY hole already closed by SS-2.)

### SS-4 — Agent-review of the verification seams (anti-pattern C) · independent · ✅ SHIPPED 2026-06-12
Resolve dual-path/grammar-collisions by making the **agent the single authority** (per the promoted principle); bash becomes labeled fallback. Covers harvest suggestions/deferrals extraction, spec-citations (`#7`), RED-tests-gate framing (`#5`), lean-index linter (`#48` Part F).
**Closes / dissolves:** `#7`, `#5` (reframed agent-driven), `#48` Part F, **N4** (harvest grammar-collision).
**Shipped:** scaffold-dev v0.4.0 (2026-06-12). The "bash becomes labeled fallback" framing was superseded by the delete-semantic-bash disposition (dead-code AWK parsers removed entirely; see §4 agent-driven-first-class pivot).

### SS-5 — Codex implementer backend (`#47`) · independent · ✅ SHIPPED 2026-06-12
Manifest-configurable `implementer_backend ∈ {claude_subagent, codex}` via `codex-companion.mjs task`; the no-commit/stage-only contract is prompt-carried + orchestrator-verified (no hard block under `workspace-write`). SS-3's tool-agnostic synthesis prompts mean Codex can also run derivation.
**Scope narrowed to implementer-only** (settled in the SS-5 brainstorm 2026-06-12; see `specs/SS-5-codex-implementer-backend.md`): wires the Codex backend into scaffold-dev's `planning-vertical-slice §8.3` work-item dispatch via `lib/codex.sh` (resolve/preflight/dispatch/wait/result/verify_nocommit) + `lib/backend.sh` selector. The **synthesizer** backend (scaffold-onboard derivation) is a future fast-follow (SS-5.1), out of SS-5 scope. Liveness: background job + poll + stall/cap, with a clarification-stop surfacing as **gaps-mode** (the Mode-B implementer contract reused for an external async process); unavailable → hard-fail + remediation (no silent fallback).
**Closes:** `#47`. **Shipped:** scaffold-dev v0.5.0 (2026-06-12).

### SS-5.1 — Codex synthesizer backend (scaffold-onboard derivation) · fast-follow to SS-5 · scaffold-onboard-only · ✅ scaffold-onboard v0.9.0
The explicit fast-follow SS-5 deferred. Manifest-configurable `synthesizer_backend ∈ {claude_subagent, codex}`: when `codex`, the three synthesis-dispatch skills (`scaffolding-memory-bank §13`, `scaffolding-governance-docs §11`, `onboarding-project §8`) route each artifact to `codex-companion.mjs` instead of the Claude `synthesis-agent`, under the **same** assembled prompt + **same** post-validation. Reuses SS-5's `lib/codex.sh` async spine (resolve/preflight/dispatch/wait/result) **minus** worktree + no-commit verify (synthesis writes the artifact directly to the routed output path; `sf_codex_target_root` gives the per-artifact repo root for `sandbox=workspace-write`, handling the canonical/ai_workspace split) + `lib/backend.sh` selector + `sf_manifest_get`. No gaps-mode (synthesis is `complete|failed`). See `specs/SS-5.1-codex-synthesizer-backend.md`.
**Router-file boundary (load-bearing):** `CLAUDE.md` / `.claude/settings.json` / `AGENTS.md` stay mechanical (`sf_claude_md_generate` etc.) — never synthesized on the Codex path (SS-7 §2/§4), test-guarded. Default stays `claude_subagent`; existing projects byte-identical.
**Closes:** `#67`. **Shipped:** scaffold-onboard v0.9.0 (design-of-record `specs/SS-5.1-codex-synthesizer-backend.md`; folded from SS-5's deferred synthesizer scope).

### SS-6 — Standalone cleanup to zero (independent items) · interleave
Items unrelated to the derivation pivot — clear them to reach zero backlog:
`#8` (ban `git stash`; stays deterministic — legit), `#9` (Scenario C pairing), `#6` (ADR Proposed→Accepted flip), `#10` (coordinating-parallel-slices, demand-gated), `#37`/`#38`/`#39` (external-benchmark trio; `#38` redaction has standalone safety value), `#48` remainder (`/defer` marketplace routing, label auto-create), **N5** (repo CI for shell suites).
**Closes:** the 9 independent issues + N5.

### SS-7 — Remove the deterministic `--fast` fallback (fully agent-driven derivation) · depends on SS-2 · scaffold-onboard-only · ✅ SHIPPED 2026-06-10
**Direction change, settled with user 2026-06-05** (memory `project_agent_driven_first_class_pivot`; observation 2215). SS-2 left `--fast` as the explicit deterministic fallback per §4 target-model item 1/2; the user has since decided to **remove it entirely** — agent synthesis is the *only* derivation path, no deterministic render fallback. **This supersedes the "`--fast` stays the explicit fallback" stance in §4 and SS-2.**

Rationale: the `--fast` path was deferred-not-fixed in SS-2 precisely because it doesn't honor manifest routing (memory-bank §13.2; governance §11.2 split `product_adrs`→canonical / `process_adrs`→ai_workspace) — polishing a path slated for deletion was wasted work. Rather than make the deterministic fallback routing-correct, delete it.

**Scope** (the `SF_SYNTH_FAST` / `sf_synth_mode` *fast* branch spans five surfaces): `scaffolding-memory-bank` (§13 dispatch + `sf_memory_bank_seed_live_static`), `scaffolding-governance-docs` (§11), `onboarding-project`, MASTER-SPEC synthesis, and roadmap. Removal must define the **agent-unavailable behavior** (hard-fail with actionable remediation vs. block-and-prompt — settle in the sub-spec brainstorm) since there is no longer a silent deterministic path to fall through to.
**Closes:** **N6**/`#56`. Subsumes the deferred SS-2 `--fast`/governance split-routing findings.

---

## 6. Issue ledger → zero backlog

Every open issue + every new audit finding, mapped to a sub-spec. **Target: 0 open issues.**

| # | Title (short) | Pivot relation | Sub-spec | Target |
|---|---|---|---|---|
| ~~**#45**~~ | harvest ↔ derived-file SSoT contradiction | wedge / partial | **SS-1** | ✅ CLOSED 2026-06-04 (PR #54) |
| ~~**#42**~~ | agent-driven post-derivation doc review | **dissolved** (is the refactor) | **SS-2** | ✅ CLOSED 2026-06-05 (PR #55) |
| ~~**#7**~~ | verifying-spec-citations (agent-assisted) | **dissolved** | **SS-4** | ✅ CLOSED 2026-06-12 (SS-4, scaffold-dev v0.4.0) |
| ~~**#5**~~ | pre-flight RED-tests gate | partial (reframe) | **SS-4** | ✅ CLOSED 2026-06-12 (SS-4, scaffold-dev v0.4.0) |
| **#48** | #33 C–F + /defer routing + label auto-create | ✅ **CLOSED** | **SS-1** (C/D/E) + **SS-4** (F) + **SS-6** (routing/label) | Part F ✅ SHIPPED 2026-06-12 (SS-4, v0.4.0); **Stage 1 C/D/E ✅ SHIPPED 2026-06-20** (PR #80, scaffold-dev v0.9.0 + scaffold-onboard v0.9.2); **Stage 2 ✅ SHIPPED 2026-06-20** (PR #81, scaffold-dev v0.10.0 + workspace-init v0.3.0; `/defer --tooling` marketplace routing + optional `tooling_repo` manifest field + `sd_label_ensure` tech-debt label auto-create; `docs/SPEC-lean-index-CDEF.md` §3.5–§3.6). **#48 fully CLOSED.** |
| ~~**#47**~~ | Codex implementer backend | independent | **SS-5** | ✅ CLOSED 2026-06-12 (SS-5, scaffold-dev v0.5.0) |
| ~~**#67**~~ | Codex **synthesizer** backend (scaffold-onboard derivation) | fast-follow to SS-5 | **SS-5.1** | ✅ scaffold-onboard v0.9.0 (folded from SS-5's deferred scope) |
| ~~**#8**~~ | ban `git stash` in templates | independent (keep-mech) | **SS-6** | ✅ SHIPPED 2026-06-15 (SS-6, scaffold-dev v0.7.0) |
| ~~**#9**~~ | pairing-existing-dual (Scenario C) | independent | **SS-6** | ✅ SHIPPED 2026-06-15 (SS-6, workspace-init v0.2.0) |
| ~~**#6**~~ | ADR Proposed→Accepted flip | independent | **SS-6** | ✅ SHIPPED 2026-06-15 (SS-6, scaffold-dev v0.7.0) |
| **#10** | coordinating-parallel-slices | independent (demand-gated) | **SS-6** | v0.3 |
| **#37** | grilling domain-language + ADR thresholds | partial (principle) | **SS-6** | v0.3 |
| **#38** | handoff suggested-skills + redaction | partial | **SS-6** | v0.3 |
| ~~**#39**~~ | architect-critic async adversary (+ doctor, state v3, scaffold-dev gate) | independent | **SS-6** | **✅ SHIPPED (both phases).** Phase A 2026-06-18 (architect-critic v0.3.0) — async lifecycle + readiness doctor + size guidance + state.json v3 `external_runs[]` + defer-to-resume unified rebuttal; also added architect-critic to CI + fixed a pre-existing macOS suppression-date bug. **Phase B 2026-06-18 (scaffold-dev v0.8.0)** — opt-in `review_gate` (#6, `off`/`slice_close`/`spec_close`/`both`, default `off`) dispatching the close-depth audit async (dispatch-and-defer) at the two §7 gates, consuming the Phase A API; v0.3 capability detection + v0.2 graceful fallback. Spec: `specs/2026-06-18-architect-critic-async-adversary.md` |
| ~~**#66**~~ | `closing-vertical-slice` leaves `05-active-context.md` stale at close (no status-flip / Next-up advance) | independent (correctness bug) | **SS-6** | ✅ SHIPPED 2026-06-15 (SS-6, scaffold-dev v0.6.0) |
| ~~**#63**~~ | scaffold-onboard `03` mcrules-zone fallback can duplicate the `## Machine-checkable rules` section (silent rule loss on re-derive) | independent (correctness bug) | **SS-6** | ✅ SHIPPED 2026-06-16 (SS-6, scaffold-onboard v0.9.1) |
| ~~**#77**~~ | closing/planning vertical-slice SKILL.md over the self-declared 500-line cap (chore; #39-Phase-B / PR #75 follow-up) | independent | **SS-6** | ✅ SHIPPED 2026-06-21 (Batch A, PR #83, scaffold-dev v0.11.0; closing 660→490, planning 729→489 via `references/*.md` extraction + `test-skill-line-cap.sh` CI guard) |
| ~~**#76**~~ | slice-start baseline so direct-mode async review bundles get a real diff (enhancement; #39-Phase-B / PR #75 follow-up) | independent | **SS-6** | ✅ SHIPPED 2026-06-21 (Batch A, PR #83, scaffold-dev v0.11.0; `lib/slice_meta.sh` append-once VS-README sentinel, recorded at planning §8.1, read as bundle `--diff-base` at closing §7.2a) |
| ~~**#71**~~ | PR #70 review follow-ups grab-bag (`created_by` provenance, `--ai-git-tracked`, worktree-canonical reject, CI SHA-pin, perf-bench gate) | independent (chore/hardening) | **SS-6** | ✅ SHIPPED 2026-06-21 (Batch C, PR #84, **workspace-init v0.4.0** + **claude-security-audit v0.1.3**; `created_by` from sibling plugin.json, `--ai-git-tracked` honest non-git workspace, `wi_git_is_linked_worktree` preflight reject, `wi_manifest_read` boolean-`false` fix, nested-AI `[[ -d .git ]]` detection; CI `actions/checkout`→SHA `34e1148` + `persist-credentials:false` + `CSA_SKIP_PERF`; bot-review fixes Devin/CodeRabbit/Codex; trace-filter `--separate-git-dir` asymmetry → **#85**) |
| **#85** | workspace-init: `wi_trace_filter_install` `.git`-must-be-a-dir check rejects `--separate-git-dir`/submodule **canonicals** (pre-existing asymmetry surfaced by #84's precise worktree helper) | independent (deferred) | **SS-6** | open (low priority; `git rev-parse --git-path hooks` rewrite, keeping #71's worktree-reject intact) |
| ~~**#82**~~ | scaffold-dev: complete the multi-reviewer pre-merge gate (finding-disposition loop + reviewer-completeness) | independent (enhancement) | **SS-6** | ✅ SHIPPED 2026-06-21 (PR #87, **scaffold-dev v0.12.0**; lean agent-first contract in `git-workflow.md` — finding-disposition loop + reviewer-completeness as binding agent judgment, prose-only, no new `sd` helper; cross-refs reduced to pointers; seam-lint pins the contract. **Process lesson:** 9 bot-review rounds of over-specified-prose churn, collapsed via a Codex consolidation pass that simplified the gate section 78→40 lines → [[feedback_bot_review_batch_fix_one_pass]] + [[feedback_skill_first_avoid_overengineering]]) |
| ~~**#79**~~ | count-aware `auto:` demo form (`expected: ran ≥N`) for runners outside the zero-test allowlist | independent (enhancement) | **SS-6** | ✅ SHIPPED 2026-06-25 (PR #89, **scaffold-onboard v0.10.0** + **scaffold-dev v0.13.0**). **Brainstorm-first reframed the issue's deterministic proposal:** shipped as an **agent-judged demo-only form** joining `count > 0` (judged at slice-close), NOT a deterministic `sd_verify_auto_step` count-engine — you can't parse a count from unrecognized-runner output, so the honest impl is agent judgment ([[feedback_skill_first_avoid_overengineering]]). Semantics: judge confirms the run **passed AND ≥N tests executed** (the non-vacuous-green guarantee; Codex P1 caught the missing pass-check in review). Work-item ACs stay the deterministic `exit 0`/`exit N`/`output contains` gate. Clean 1-round bot review via batch-fix-in-one-pass ([[feedback_bot_review_batch_fix_one_pass]]). Design-of-record `docs/SPEC-slice-demo-agent-eval.md` |
| **#88** | ai-mentor + architect-critic: agent-driven "You-are-here" orientation preamble for dialogue skills (grill-me/council/critique/brainstorm open with **topic / where-it-sits + strategic-weight / why**) | independent (enhancement; **agent-driven, NO determinism**) | **SS-6** | open (user-filed 2026-06-25 during #79 brainstorm; ai-mentor owns, architect-critic adopts in `critiquing-spec`; re-grounds a user resuming after a break or juggling projects; [[feedback_orientation_preamble_dialogue_skills]]) |
| **#86** | scaffold-onboard: `/amend-spec` skill — incremental, **change-driven** MASTER-SPEC amendment for the post-MVP / vNext lifecycle (classify change → impact analysis vs MASTER-SPEC+SRS/BACKLOG → collision-safe ID mint from ledger → *targeted* spec edit + *diff-aware* governance-doc update, vs today's greenfield whole-bundle re-derive) | independent (enhancement; **larger design item** — likely brainstorm-first) | **SS-6** (candidate new sub-spec) | open (user-filed 2026-06-21, demand-validated by PulseDB v0.5.x→vNext; the strategic greenfield→full-lifecycle-tool gap — arguably the highest-value open item) |

**New issues filed from this audit** (2026-06-01, so the backlog reflects reality):

| ID | Issue | Title | Type | Sub-spec |
|---|---|---|---|---|
| **N1** | ~~**#49**~~ | scaffold-onboard: EXECUTIVE-SUMMARY placeholder has no source question / render fn (hole) | bug | ✅ CLOSED 2026-06-05 (SS-2, PR #55) |
| **N2** | ~~**#50**~~ | scaffold-onboard: verify synthesis path actually dispatches by default (possibly "dark" / never exercised end-to-end) | bug · critical | ✅ CLOSED 2026-06-05 (SS-2, PR #55) |
| **N3** | ~~**#51**~~ | scaffold-onboard: MASTER-SPEC is mechanical transcription — move to agent synthesis from phased-discussion | enhancement | ✅ CLOSED 2026-06-08 (SS-3, PR #57, squash `3193308`, tag `scaffold-onboard-v0.6.0`; reconcile→**#58**, polish→**#59**) |
| **N7** | ~~**#58**~~ | scaffold-onboard: true reconcile-on-re-onboard (gate-aware digest, partial/touched refresh, preserve human edits) — deferred from SS-3 | enhancement | ✅ CLOSED (wontfix) 2026-06-08 — partial reconcile evaluated as not worth the complexity; full re-walk + first-author re-synthesis is the permanent model; dormant foundations removed in scaffold-onboard v0.7.0 |
| **N8** | **#59** | scaffold-onboard: SS-3 residual review polish (re-walk/gate/repair prose + robustness + doc-sync) — from PR #57 | chore | future (non-product-bug; Codex-clean at merge) |
| **N4** | ~~**#52**~~ | scaffold-dev: harvest grammar-collision — AWK parser silently drops free-form Suggestions prose; single-authority agent read | bug | ✅ CLOSED 2026-06-12 (SS-4, scaffold-dev v0.4.0) |
| **N5** | ~~**#53**~~ | repo: no `.github/workflows` CI for shell test suites | ops | ✅ SHIPPED 2026-06-15 (SS-6, `.github/workflows/tests.yml`) |
| **N6** | ~~**#56**~~ | scaffold-onboard: remove deterministic `--fast` fallback (agent-driven only) — subsumes the deferred SS-2 `--fast`/governance split-routing findings | enhancement | ✅ CLOSED 2026-06-10 (SS-7, scaffold-onboard v0.8.0) |

---

## 7. Codex daily-run findings disposition (2026-06-01)

Codex ran against the **stale pre-merge branch** (reported "44 commits ahead of origin/main"; `gh` API unreachable). Verdicts:

| Finding | Disposition |
|---|---|
| `#44` slice-demo grammar "still open" | **STALE** — shipped & closed in PR #46. The "output contains / count > 0 vs hardened AC grammar" mismatch is now **intentional by design** (#44's resolution). One-line doc check that `SPEC-scaffold-dev.md` reflects the resolution. |
| README/manifests still v0.3.8 / v0.2.0 | **STALE** — those ARE the shipped, tagged versions (bumped during the merge). |
| Untracked `.claude/` | **Genuine but known hygiene** (standing don't-commit gotcha). Not a product bug. |
| No `.github/workflows` CI | **GENUINE** → **N5** (SS-6). |
| `gh` API unreachable | Environmental; resolved (we list issues fine now). |

---

## 8. Open questions (settle before/within the relevant sub-spec)

- **OQ-1 (gated SS-2): RESOLVED 2026-06-04.** Verdict: **LIVE-BUT-BUGGY + entirely untested** (not dark). The mechanism defaults to synthesize (`sf_synth_mode`; no wrapper forces `--fast`) and *would* attempt dispatch, but the dispatch prose aborts at the edges — decisively, `scaffolding-memory-bank/SKILL.md` §13.1 sources only `synthesis.sh`+`routing.sh` while the dispatch/fallback/finalize bodies call `memory-bank.sh`/`render.sh` helpers → `set -u` abort; `# STOP` short-circuits are comment-only; EXEC-SUMMARY is a #49 hole (phantom `sf_render_executive_summary`); and **no test exercises dispatch**. So SS-2 = blend of "turn it on" + "fix the model" (see SS-2 sub-spec).
- **OQ-2 (SS-1): RESOLVED 2026-06-02.** No agent-merge engine. Separating dev-authored learnings into their own pure-dev files makes derived files safely regenerable; the only in-place preservation is `03`'s machine-checkable-rules zone (deterministic marker extract/re-inject — a non-reasoning fact). See `docs/agent-driven-program/specs/SS-1-memory-bank-cadence.md`.
- **OQ-3 (SS-3): DISSOLVED 2026-06-06.** No separate phased-discussion file — the durable, resumable artifact *is* the enriched `onboarding-state.json` (schema 2.0 adds agent-authored `phase_records` beside verbatim `answers`). Nothing to locate, delete, or archive. See `docs/agent-driven-program/specs/SS-3-agent-synthesized-resumable-onboarding.md`.
- **OQ-4 (cross-cutting):** Codify the "what stays bash" boundary as a memory-bank/governance artifact so future sessions don't re-litigate.
- **OQ-5 (SS-7):** With `--fast` deleted, what is the **agent-unavailable behavior**? Hard-fail with actionable remediation, block-and-prompt, or a minimal non-synthesizing scaffold? No silent deterministic path may remain. Settle in the SS-7 brainstorm.

---

## 9. Cross-session usage

A new orchestration session resumes the program by:
1. Reading this spec (north star + ledger + sub-spec sequence).
2. Picking the next un-started sub-spec per §5 sequencing (SS-1 first).
3. Running its own `brainstorm → writing-plans → build → bot-review → release` cycle (plain superpowers flow — this is the plugin **source** repo, no `.workspace/pairing.json`, so scaffold-dev's slice skills refuse here; handoffs stay manual `docs/HANDOFF-*.md`).
4. Updating the ledger (§6) as issues close. Done when the table is all-closed.

**Release mechanics (per sub-spec):** bump `plugin.json` (Claude **and** Codex — parity enforced by `tests/test-codex-dual-publish.sh`) + README version table → merge → `git tag <plugin>-v<ver>` on the merge commit → push tags.
