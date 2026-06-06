# SS-3 — Agent-synthesized, resumable onboarding

**Status:** Design-locked (sub-spec of `docs/agent-driven-program/SPEC-agent-driven-program.md` → SS-3) · **Date:** 2026-06-06
**Closes:** `#51`/N3 (MASTER-SPEC mechanical transcription → agent synthesis).
**Plugins touched:** `scaffold-onboard` only (`onboarding-project` skill, `lib/state.sh`, `lib/render.sh`, a new MASTER-SPEC synthesis brief, tests). scaffold-dev untouched; workspace-init untouched.
**Depends on:** SS-1 (shipped — ownership classification / live-seed pattern) and SS-2 (shipped — `synthesis-agent`, EXEC-SUMMARY synthesis at onboarding-close, brief assembly + write-back).
**Enables:** SS-5 (Codex synthesis backend — inherits a tool-agnostic MASTER-SPEC brief). **Pioneers:** OQ-5's agent-unavailable answer (SS-7 adopts it program-wide).

> **Design settled with user 2026-06-06** (SS-3 brainstorm). Scope chosen: the broadest live path — full MASTER-SPEC synthesis + main-agent per-phase enrichment + reconciliation on re-run, with **no deterministic MASTER-SPEC renderer at all**. Design-locked.

> **⚠️ DESCOPE 2026-06-07 (during PR #57 review).** Decision #4 below — **partial reconcile-on-re-onboard** — was **descoped to follow-up issue #58** after it generated a long tail of edge-case defects across review rounds, including a regression where helper-level subsection-gate filtering gated out Phase 9's LLM opt-in question (`9.3` gate `uses_llm == true` reads `9.3.1`, which lives inside `9.3`). **What ships in SS-3:** the first-author core (decisions 1/2/3/5/6/7) — agent-synthesized MASTER-SPEC at close, schema-v2 `phase_records`, `close_pending` resumability, tool-agnostic brief, no deterministic renderer. **Re-onboard does a clean full re-walk + first-author re-synthesis** (all phases re-walked with existing answers as defaults; whole spec re-synthesized; prior spec backed up) — NOT the partial touched-phase reconcile described in decision #4. Lib foundations (`sf_synth_master_spec_prompt` reconcile mode, `sf_state_mark_touched`, `touched_this_run`) are retained dormant for #58. Sections below describing reconcile mode reflect the *original* design; see #58 for the deferred work.

---

## 1. The core realization (what SS-2 already moved)

SS-3 was scoped 2026-06-01, before SS-2 shipped. SS-2 already delivered two things the original SS-3 text claimed:

- **EXEC-SUMMARY is already agent-synthesized** at Phase-10 close (`onboarding-project` dispatches `synthesis-agent` from the `EXECUTIVE-SUMMARY.brief.md`, writes the body back into MASTER-SPEC's pinned `## Executive Summary` section, with cksum-staleness). SS-3 does **not** re-touch this — it only ensures MASTER-SPEC (now synthesized) emits the fillable `## Executive Summary` section the SS-2 step slots into.
- **Onboarding is already resumable** — `onboarding-state.json` persists every answer per-qid with `resume` / `reonboard` / `project_mismatch` modes.

**What still matches anti-pattern B (the real SS-3 core):** MASTER-SPEC is built by `sf_master_spec_update_phase` substituting raw phase answers into `{{phase_1.1.1}}` slots — **transcription, not synthesis** — re-rendered per phase to an on-disk file. The state file stores only flat answer strings, so the *reasoning* behind each phase (rationale, rejected options, critic outcomes) lives only in the live conversation and is lost across session boundaries.

**Consequence:** SS-3 = (a) enrich the durable state so it captures per-phase reasoning, authored by the conducting agent; (b) synthesize the whole MASTER-SPEC from that state at close, in first-author or reconcile mode; (c) delete the deterministic transcription path entirely.

---

## 2. Settled decisions

1. **Synthesis at Phase-10 close, not per-phase.** One synthesis pass over the full enriched state produces the whole MASTER-SPEC at close (mirroring EXEC-SUMMARY). **No MASTER-SPEC exists on disk until close** — per-phase recaps become lightweight in-conversation echoes derived from state, not a progressively-rendered file. Phase 5/7 critic moments write a temporary phase recap artifact for architect-critic because there is no full spec yet. This makes MASTER-SPEC a **pure function of the durable state**, never of any single session's conversation context — which is precisely what guarantees multi-session resumability (abandon at Phase 6 → complete resumable state, no half-written spec).

2. **The "phased-discussion file" *is* the enriched `onboarding-state.json`** — no separate scratch file. (OQ-3 — file format/location/deletion-lifecycle — therefore dissolves: nothing to delete or archive.) Schema bumps `1.0 → 2.0`:
   - `answers: {qid: raw_text}` — **kept verbatim**, lossless ground truth (unchanged from v1.0).
   - **New** `phase_records: {phase_id: {decisions, rationale, alternatives_rejected, constraints, open_questions, critic_outcomes, authored_at}}`. Fields are a *suggested* shape; their **content is free agent prose**, not slot-fills. A phase record may omit keys that don't apply.

3. **Capture is non-deterministic; persistence is mechanical.** The **main conducting agent** (not a sub-agent) authors each phase record at phase close — it already holds the rejected options + critic outcomes in live context, so a sub-agent dispatch would only cost a context round-trip and risk losing nuance. The *act* of writing JSON stays bash (`sf_state_write_phase_record`); the *content* is reasoning. **Both** raw answers and rich records are kept — close-synthesis reads the rich records and can fall back to raw answers, so there is no telephone-game (we never synthesize from an already-interpreted summary).

4. **Enhancement re-runs reconcile (in SS-3).** A re-onboard re-answers some phases → their phase records are re-authored → close runs in **reconcile mode**: the synthesis agent **merges** the updated records into the existing MASTER-SPEC, *refreshing only the phases touched this run and preserving untouched sections + any human edits to the spec file*. The merge *judgment* is the agent's; **which phases were touched this run is a mechanical fact** handed to it (`sf_state_phases_touched_this_run`). The pre-existing spec is backed up to `MASTER-SPEC.md.bak-<ISO8601>` as a safety net. This realizes §4 target-model item 1 (the "reconciliation primitive") that SS-1 deliberately skipped for the memory bank (file-separation solved it there; MASTER-SPEC has no such escape hatch).

5. **Tool-agnostic brief, Claude dispatch only.** The new MASTER-SPEC synthesis brief carries **zero Claude-isms** (no Claude-specific tool references in its body), so Codex can run it unchanged later. SS-3 wires the shared `synthesis-agent` to support MASTER-SPEC first-author/reconcile prompts + the main-context-inline fallback (§6). Actual Codex backend wiring (manifest `implementer_backend`, `codex-companion.mjs`) stays in SS-5, which inherits a ready prompt.

6. **No deterministic MASTER-SPEC renderer — two agent paths, zero deterministic paths (OQ-5 precedent).** Building a deterministic MASTER-SPEC renderer in SS-3 only for SS-7 to delete would be the exact wasted-work anti-pattern that motivated #56. So MASTER-SPEC synthesis ships **synthesis-only** from day one. Execution order at close:
   1. **Dispatch a synthesis sub-agent** (`scaffold-onboard:synthesis-agent`) — preferred, for isolation.
   2. **If dispatch is unavailable → synthesize inline in the main orchestration context**, reading the *same plugin brief*. The host (Claude Code or Codex) is itself a capable synthesizer because the brief is a plugin asset. Still fully agentic, still non-deterministic.
   3. **Validate the synthesized MASTER-SPEC** with `sf_spec_validate` before close-depth critic, EXEC-SUMMARY, or any downstream derivation. Invalid synthesis stops with state preserved for resume/retry.
   4. **Retry-later** (state fully preserved) only if the host runtime itself is broken — which is not a case SS-3 mitigates with a degraded deterministic output. There is **no minimal-scaffold fallback.**

   This is the answer SS-7 generalizes to EXEC-SUMMARY + memory-bank + governance under OQ-5.

7. **Legacy state migrates gracefully (upgrade input class).** A pre-2.0 state file (flat `answers`, no `phase_records`) resumes without error: already-completed phases simply lack rich records, and close-synthesis falls back to their raw answers; enrichment applies to phases authored from the upgrade forward. This is tested by *feeding the migration path a legacy-format state file* (per the "test the upgrade input class" lesson — fresh-derive-first tests miss data-loss-on-upgrade bugs).

---

## 3. What "fixed" looks like (target behavior)

| Aspect | Today | After SS-3 |
|---|---|---|
| MASTER-SPEC authorship | `sf_master_spec_update_phase` transcribes raw answers into `{{phase_N.M.K}}` slots, per phase, on disk | Agent **synthesizes** the whole spec from enriched state at close; nothing on disk until close |
| State content | flat `answers: {qid: text}` | `answers` (verbatim) **+** agent-authored `phase_records` (decisions/rationale/alternatives/constraints/critic-outcomes) |
| Reasoning across sessions | rationale + critic outcomes live only in conversation → lost at session boundary | persisted into `phase_records` at each phase close → a resumed session inherits real synthesized context |
| Per-phase recap | re-rendered MASTER-SPEC section | in-conversation echo derived from the phase record (no file) |
| Re-onboard | `--regenerate` wholesale reset to Phase 1, spec clobbered (backup) | **reconcile**: refresh touched phases, preserve untouched sections + human edits; old spec backed up |
| Determinism | deterministic transcription is the only path | **no deterministic MASTER-SPEC path**; sub-agent dispatch → main-context-inline fallback |
| Tool-agnosticism | n/a (bash render) | brief is Claude/Codex-agnostic; SS-5 wires Codex |

---

## 4. Work breakdown

- **W1 (state schema 2.0 + enrichment helpers):** bump `onboarding-state.json` schema to `2.0`; add `phase_records`. New `lib/state.sh` helpers: `sf_state_write_phase_record <phase_id> <json>`, `sf_state_read_phase_record <phase_id>`, `sf_state_write_phase_artifact <phase_id> <path>`, `sf_state_phases_touched_this_run` (mechanical reconcile hint — tracks which phases were (re)answered in the current run). Legacy-state migration: a v1.0 file loads as v2.0 with empty `phase_records` (no data loss; raw answers intact).

- **W2 (per-phase enrichment in `onboarding-project`):** rewrite the per-phase loop step 4 — instead of `sf_master_spec_update_phase` rendering a section, the conducting agent **authors the rich phase record** from the live discussion and persists it via `sf_state_write_phase_record`, then surfaces a recap **echo** derived from that record. Phase 5/7 premise audits write and pass a local phase artifact via `sf_state_write_phase_artifact`, so architect-critic does not heuristically audit an unrelated spec/plan. Capture architect-critic outcomes and user recap edits **into the phase record** (so session boundaries never drop them). Update §3 / §10 / §12 of the skill (retire transcription references).

- **W3 (MASTER-SPEC synthesis brief — tool-agnostic):** add `templates/synthesis-briefs/MASTER-SPEC.brief.md` with zero Claude-isms; it consumes the full enriched state (rich records, raw-answer fallback) and emits the full MASTER-SPEC including a fillable `## Executive Summary` section for the SS-2 EXEC-SUMMARY step. The brief carries **first-author** vs **reconcile** instructions (reconcile = merge into the supplied existing spec, refresh only the listed touched phases, preserve the rest + human edits).

- **W4 (close ceremony — synthesis dispatch + fallback):** rework the Phase-10 close in `onboarding-project` to: (1) assemble the MASTER-SPEC brief prompt (passing the touched-phases hint + existing spec in reconcile mode), (2) dispatch `synthesis-agent`, (3) **fallback to main-context-inline synthesis** of the same brief if dispatch is unavailable, (4) back up any existing spec to `.bak-<ts>` before write, (5) validate the synthesized MASTER-SPEC with `sf_spec_validate`, (6) run the close-depth critic against that artifact, and (7) then run the existing SS-2 EXEC-SUMMARY synthesis from the new MASTER-SPEC. No deterministic renderer is invoked anywhere.

- **W5 (retire the deterministic transcription path):** remove `sf_master_spec_update_phase` and any deterministic `sf_render_master_spec_*` MASTER-SPEC renderers from `lib/render.sh`; remove their template (`templates/master-spec/…{{phase_*}}` slot machinery) and references in the skill body / walkthrough. Confirm no remaining caller (grep guard in tests).

- **W6 (tests):** see §5.

---

## 5. Verification

- **Dispatch integration test (stubbed agent return).** Exercise the close path with a faked `synthesis-agent` return written to the resolved MASTER-SPEC path; assert the close consumes it and runs the EXEC-SUMMARY step. A broken dispatch must not merge green (the SS-2 lesson).
- **Validation gate test.** Assert the close instructions run `sf_spec_validate` after synthesis and before close-depth critic/EXEC-SUMMARY so malformed agent output cannot be treated as a successful onboarding close.
- **Main-context-inline fallback test.** With dispatch made unavailable in the fixture, assert the close still produces a MASTER-SPEC via the inline path (no deterministic renderer engaged).
- **Resumability test across a simulated session boundary.** Enrich phases 1–3, drop context (new state load), resume at Phase 4, close; assert synthesis used the **persisted phase records** (not raw-only) for phases 1–3.
- **Reconcile test (upgrade input class).** Feed an existing MASTER-SPEC + a human edit to an untouched section; re-answer one phase; close in reconcile mode; assert the edited untouched section is **preserved verbatim** and only the re-answered phase's section is refreshed.
- **Legacy-migration test (upgrade input class).** Load a v1.0 state file (flat `answers`, no `phase_records`); assert it resumes without error and close-synthesis falls back to raw answers for un-enriched phases.
- **No-deterministic-path assertion.** Grep/behavioral guard: no `sf_render_master_spec*` deterministic function survives or is called; `sf_master_spec_update_phase` is gone.

Run the **full** `scaffold-onboard` suite (not just named suites) and distrust "pre-existing failure" claims; suites are slow (55–75s+ each) — run in background with generous windows.

---

## 6. Open questions

- **OQ-3 (was: phased-discussion file format/location/lifecycle):** **DISSOLVED** — the enriched `onboarding-state.json` is the discussion file; no separate scratch file, so no deletion/archive lifecycle.
- **OQ-5 (agent-unavailable behavior):** **RESOLVED for MASTER-SPEC** here (sub-agent dispatch → main-context-inline fallback → retry-later only if host broken; never a deterministic/minimal-scaffold path). SS-7 adopts this program-wide.
- **(settle in plan) Phase-record key set.** §2.2 proposes `decisions / rationale / alternatives_rejected / constraints / open_questions / critic_outcomes / authored_at`. Free-prose content; keys may be refined during W1 if the synthesis brief needs a different cut.

---

## 7. Out of scope (explicit non-goals)

- **Re-touching EXEC-SUMMARY synthesis** — done in SS-2; SS-3 only guarantees MASTER-SPEC emits the section it fills.
- **Codex backend wiring** — SS-5 (SS-3 only makes the brief Codex-ready).
- **Memory-bank / governance `--fast` removal** — SS-7 (#56).
- **Per-phase incremental on-disk synthesis** — rejected in favor of close-only synthesis (§2.1).
- **A deterministic MASTER-SPEC renderer of any kind** — rejected (§2.6).
