# Eval: scaffold-onboard:onboarding-project

> Behavior eval for the `onboarding-project` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-onboard:onboarding-project` skill (per SPEC §5.1) drives the 10-phase guided conversation, manages state correctly, invokes architect-critic at the documented moments, and respects manifest-aware output routing. Establishes the eval-doc pattern reused by the other 6 skill evals in this directory.

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp repo, `.claude/` state, composition manifest, marketplace cache directories, and any preexisting MASTER-SPEC fragments described in the scenario.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input, the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**Reproducibility note:** the orchestrator MUST clear the project-scoped `${CLAUDE_PLUGIN_DATA}/<project-id>/onboarding-state.json` and any `.claude/marker-*` files between scenarios. Scenarios are independent; ordering does not matter.

## Scenarios

### S1 — Fresh `/onboard` on empty repo (happy path)

**Setup:**
- Empty tmp directory; `git init`.
- No `.claude/` directory present.
- No composition.json (so ai-mentor / superpowers / architect-critic all read as absent for in-conversation calls).
- No `MASTER-SPEC.md`, no `EXECUTIVE-SUMMARY.md`.
- `${CLAUDE_PLUGIN_DATA}` points to a fresh empty dir.

**Trigger:** target subagent user message: `/onboard`

**Expected behavior:**
- Skill triggers on `/onboard` (slash command resolves through the wrapper to `scaffold-onboard:onboarding-project`).
- Skill creates project-scoped `onboarding-state.json` with `schema_version=2`, `current_phase=1`, valid `created_at` / `updated_at` timestamps, `answers={}`, `phase_records={}`, and `touched_this_run=[]`.
- Skill begins Phase 1 by asking the first question from `phases.yaml`.
- Skill does NOT attempt to invoke architect-critic at this turn (Phase 5 close not yet reached).
- Skill does NOT render `MASTER-SPEC.md` yet (Phase 10 close not yet reached).
- Skill's first assistant turn is a phase-1 question, not a generic greeting.

**Assertion (judge subagent verifies):**
- `onboarding-state.json` is present after the turn and parses as valid JSON with the expected schema keys (`schema_version`, `current_phase`, `answers`, `phase_records`, `touched_this_run`, `created_at`, `updated_at`).
- Target subagent's final assistant message is a phase-1 question matching the v0.1.0 phases.yaml prompt vocabulary (not improvised wording).
- No `Skill(architect-critic:*)` invocations appear in the target subagent's tool-call log.
- No `MASTER-SPEC.md` or `EXECUTIVE-SUMMARY.md` was written.
- No errors or warnings emitted.

---

### S2 — `/onboard --resume` after mid-phase interrupt

**Setup:**
- Tmp repo with `git init`.
- Pre-seed project-scoped `onboarding-state.json` with `schema_version=2`, `status=in_progress`, `current_phase=4`, populated `phase_records` for phases 1-3, partially populated `answers` for phases 1-3 + first 2 questions of phase 4, valid `created_at` / `updated_at` timestamps.
- No MASTER-SPEC.md yet.

**Trigger:** target subagent user message: `/onboard --resume`

**Expected behavior:**
- Skill detects existing state file.
- Skill does NOT re-ask Phase 1-3 questions or overwrite existing answers.
- Skill does NOT call `sf state_run_reset`; any existing `touched_this_run` values from an interrupted session are preserved (the tracker is retained dormant for the deferred #58 reconcile work).
- Skill restates current position (states current phase and approximate progress).
- Skill asks the next unanswered question (phase 4, question 3).
- State file is not reset; `current_phase` value remains 4.

**Assertion (judge subagent verifies):**
- Target subagent's first assistant message acknowledges the resume + states current phase/position.
- The question asked is the next unanswered phase-4 question per phases.yaml.
- `onboarding-state.json` `answers` field shows pre-seeded entries unchanged (no overwrite).
- No phase-1 / phase-2 / phase-3 questions appear in the transcript.
- No architect-critic invocation (Phase 5 close not reached).

---

### S3 — `/onboard --regenerate` on existing MASTER-SPEC

**Setup:**
- Tmp repo with completed v0.1.0-style `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md` already on disk at routing destination (single-repo cwd, no manifest).
- Project-scoped `onboarding-state.json` present with `schema_version=2`, `status=complete`, `current_phase=10`, prior `answers`, and prior `phase_records`.

**Trigger:** target subagent user message: `/onboard --regenerate`

**Expected behavior:**
- Skill treats `--regenerate` as a **full re-walk + first-author re-synthesis**, not a destructive wipe (true partial reconcile is deferred to #58).
- Skill acquires the lock, then sets `current_phase=1` and `status=in_progress` — it does NOT call `sf state_init`, so prior `answers` and `phase_records` are kept as editable defaults (a wipe requires `--fresh` + `confirm discard`).
- Skill announces it will re-walk all phases with existing answers shown as defaults, then re-enters at Phase 1 and proceeds through the normal per-phase loop.
- At close, skill backs up existing `MASTER-SPEC.md` to `MASTER-SPEC.md.bak-*` and runs §8 in **first_author** mode (re-synthesizes the whole spec from the re-walked state).

**Assertion (judge subagent verifies):**
- Target subagent's first assistant message announces a full re-walk re-synthesis (existing answers shown as defaults) and does NOT ask "which phases to revisit" (partial reconcile is deferred) nor demand a destructive-reset confirmation (that is `--fresh`).
- A backup file matching `MASTER-SPEC.md.bak-*` exists before the re-synthesized `MASTER-SPEC.md` is written.
- `onboarding-state.json` retains prior `answers` and `phase_records` as the starting point (NOT wiped — wiping is the `--fresh` path).
- `current_phase` is reset to 1 and `status` is `in_progress` (re-walk in flight); the skill re-enters at Phase 1.
- No `sf state_init` / discard occurs unless the user explicitly runs `--fresh` and confirms `confirm discard`.

---

### S4 — Trigger-phrase match without explicit `/onboard`

**Setup:**
- Empty tmp directory; `git init`.
- No `.claude/`, no state, no MASTER-SPEC.md.
- Composition.json absent.

**Trigger:** target subagent user message: `I want to start onboarding a new project — can you walk me through it?`

**Expected behavior:**
- Skill triggers via description-match on the trigger phrase "start onboarding" (per SPEC §5.1 triggers list).
- Skill behavior from this point is identical to S1 (fresh state init, Phase 1 question asked).
- Target subagent does NOT respond with a generic "sure, what's your project about?" — it should engage the structured skill flow.

**Assertion (judge subagent verifies):**
- `onboarding-state.json` is created with `schema_version=2` and `current_phase=1`.
- Target subagent's first assistant message references the structured onboarding (e.g., names the 10-phase flow, or asks the canonical Phase 1 question).
- The question asked matches phases.yaml Phase 1 prompt vocabulary (skill body invoked, not improvised conversation).
- No improvised free-form project-discussion flow — the target stays on rails.

---

### S5 — architect-critic invocation at Phase 5 (filesystem-probe detection)

**Setup:**
- Tmp repo with `git init`.
- Pre-seed project-scoped `onboarding-state.json` with `current_phase=5`, all answers for phases 1-4 populated, corresponding `phase_records` for phases 1-4, and all phase-5 questions answered except the final-confirmation step.
- **No composition.json file at all** in this scenario (no architect-critic entry per v0.2 ac settlement #1; ai-mentor / superpowers also absent to isolate the filesystem-probe path).
- Mock the plugin cache filesystem: create `${HOME}/.claude/plugins/cache/test-marketplace/architect-critic/0.2.0/skills/critiquing-spec/SKILL.md` (stub content) so the filesystem probe per SPEC §12.2 returns `v0.2`. (`test-marketplace` is an arbitrary fixture name; the real marketplace slug doesn't matter for this probe.)

**Trigger:** target subagent user message: (the final phase-5 confirmation answer, completing phase 5 — e.g., `yes, that's the full project scope`)

**Expected behavior:**
- Skill detects phase-5 close.
- Skill runs `sf_compose_detect_architect_critic` (filesystem probe per §12.2) — NOT a composition.json lookup.
- Probe returns `v0.2`.
- Skill writes a concrete phase recap artifact via `sf state_write_phase_artifact 5 "$phase_artifact"`.
- Skill invokes `Skill(architect-critic:critiquing-spec)` with `target=master-spec-phase`, `depth=premise-audit`, `phase_id=5`, and `artifact_path="$phase_artifact"` (per §12.1 row 1). architect-critic infers adversary availability internally — adversary selection is NOT a caller-passed argument and must NOT be asserted.
- Skill does NOT use the legacy file-IPC pattern (`sf_compose_build_critic_request` / `sf_compose_read_critic_response` — both dropped per §12.3).
- After critic returns control, skill advances to Phase 6 and asks the first phase-6 question.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log contains exactly one `Skill(architect-critic:critiquing-spec)` invocation at this turn.
- Invocation args carry `target=master-spec-phase`, `phase_id=5`, `depth=premise-audit`, and an `artifact_path` pointing at the generated phase recap artifact.
- The generated artifact exists and contains both the Phase 5 verbatim answers and the persisted Phase 5 record.
- No file writes to any `inbox/` or `outbox/` paths in the transcript (legacy IPC must not be used).
- Target made zero `composition.json` reads in this scenario (file is absent per setup); all critic detection went via filesystem probe per §12.2.
- After the critic returns, the next assistant message is a Phase 6 question per phases.yaml.
- `onboarding-state.json` `current_phase` field is updated to 6.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 5 scenarios PASS.

## Out of scope for this eval

- Multi-session interrupts (covered separately in `evals/scaffolding-memory-bank.md` resume tests)
- architect-critic v0.1.3 fallback path — removed from SPEC §12 in the 2026-05-24 drift-resolution pass (v0.1.3 had no skills directory, so the fallback was dead code). Detection is now binary v0.2-present vs absent; only the latter case is tested in S5
- Single-repo vs manifest-mode routing distinction at Phase 10 close — covered by integration tests (PLAN T7.1)
- ai-mentor + superpowers composition (orthogonal; this eval keeps them absent to isolate the onboarding-project skill behavior)
