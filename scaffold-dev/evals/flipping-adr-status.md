# Eval: scaffold-dev:flipping-adr-status

> Behavior eval for the `flipping-adr-status` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:flipping-adr-status` skill (issue #6, the second half of the `proposed-then-flip` ADR lifecycle) resolves an ADR via the manifest-routed product/process dirs (by number or absolute path), **gates on the ADR currently being `Status: Proposed`**, prompts for an empirical signal, then makes a **targeted edit** — flips `- Status: Proposed` → `- Status: Accepted` and appends an `## Empirical validation` section with the operator's signal + date — without re-authoring the ADR body. Also verifies the gate refuses an already-`Accepted` ADR (no edit) and disambiguates a number that matches both series.

This eval validates the *flip skill's* behavior — not ADR authoring (covered by `evals/recording-architecture-decision.md`) nor supersede/deprecate lifecycles (deferred).

## Harness

Each scenario runs inside a single Claude Code subscription session via an orchestrator that runs three steps:

1. **Setup** — prepares a tmp dual-repo workspace (canonical + AI workspace siblings, `.workspace/pairing.json` manifest at the parent), the manifest-routed ADR dirs, and the pre-existing `adr-NNNN-*.md` files described in the scenario (each with a real `- Status: …` metadata line + the four MADR-lite sections).
2. **Trigger** — dispatches a fresh **target subagent** with the trigger phrase as the user message; captures its tool calls, transcript, and final filesystem state.
3. **Judge** — dispatches a **judge subagent** with the scenario's `Expected behavior` + `Assertion` text, the target's full transcript, and the before/after diff of the target ADR file. Returns `PASS` or `FAIL: <deviation>`.

**No external CLI.** Evaluation is LLM-judged against natural-language assertions. **Multi-turn dialogs:** the empirical-signal response (and any disambiguation pick) is pre-injected into the dispatch prompt. **Reproducibility:** scenarios are independent; the ADR fixtures are reset between runs.

## Scenarios

### S1 — Flip a Proposed ADR by number (happy path)

**Setup:**
- Dual-repo fixture; `routing.product_adrs` → `<canonical>/docs/adr/`, `routing.process_adrs` → `<ai-workspace>/docs/adr/`.
- `<canonical>/docs/adr/adr-0003-use-redis-for-session-cache.md` exists with `- Status: Proposed` (authored via `status_protocol: proposed-then-flip`) + the four MADR-lite sections + a `## References` section. No process ADR numbered `0003`.
- Pre-injected user follow-up: empirical signal = `"Redis session cache ran 14 days in staging with p99 read < 2ms, no eviction storms."`

**Trigger:** target subagent user message: `flip ADR 3`

**Expected behavior:**
- Skill discovers the manifest, resolves both ADR dirs, scans for `adr-0003-*.md`, finds the single match in the product dir.
- Reads it; confirms `- Status: Proposed`.
- Prompts for the empirical signal; captures the pre-injected response.
- Edits `- Status: Proposed` → `- Status: Accepted` (one-line surgical replace) and appends an `## Empirical validation` section carrying the signal + today's date.
- Emits a final message naming the absolute path, the new Status, and the recorded signal.

**Assertion (judge):**
- Manifest read goes through a `lib/manifest.sh` helper (`sd manifest_get` / `sd manifest_resolve`), not raw `jq` (tool-call log).
- The directory scan for `adr-0003-*.md` appears in the tool-call log before any edit.
- The final ADR file contains exactly `- Status: Accepted` (no remaining `- Status: Proposed`); the Context / Decision / Consequences / References sections are **byte-for-byte unchanged** (only the Status line + an appended section differ).
- The ADR ends with an `## Empirical validation` section containing the verbatim pre-injected signal text and a date.
- The skill did NOT re-render the ADR from the template, renumber it, or reorder sections.
- Final assistant message names the absolute path + the Proposed→Accepted transition + the signal.

---

### S2 — Refuse an already-Accepted ADR (gate, no edit)

**Setup:**
- Dual-repo fixture; `<canonical>/docs/adr/adr-0002-postgres-over-sqlite.md` exists with `- Status: Accepted`.
- No pre-injected follow-up (the skill should refuse before any signal prompt).

**Trigger:** target subagent user message: `mark ADR 2 accepted`

**Expected behavior:**
- Skill resolves `adr-0002-*.md`, reads it, finds `- Status: Accepted`.
- Refuses with a message stating the ADR is already Accepted and the flip is one-way; makes **no edit**.

**Assertion (judge):**
- Target's transcript surfaces a refusal naming the already-`Accepted` status; the message conveys the flip is one-way (Proposed → Accepted).
- **No `Edit` / `Write` of the ADR file appears in the tool-call log** — the before/after file diff is empty.
- The skill does NOT prompt for an empirical signal (it refused at the gate, upstream of §6).

---

### S3 — Number matches both series → disambiguate (ask, don't guess)

**Setup:**
- Dual-repo fixture; BOTH `<canonical>/docs/adr/adr-0001-…​.md` (product, `Status: Proposed`) AND `<ai-workspace>/docs/adr/adr-0001-…​.md` (process, `Status: Proposed`) exist.
- Pre-injected user follow-ups: (a) disambiguation pick = `"process"`; (b) empirical signal = `"Subagent routing change held across two sprints with no nesting violations."`

**Trigger:** target subagent user message: `flip ADR 1`

**Expected behavior:**
- Skill scans both dirs, finds `adr-0001-*.md` in BOTH series.
- Surfaces both absolute paths and asks which one (does NOT guess). Captures the pre-injected `process` pick.
- Proceeds to flip the **process** ADR only (Proposed → Accepted + Empirical validation), leaving the product `adr-0001` untouched.

**Assertion (judge):**
- Target's transcript shows BOTH `adr-0001-*.md` absolute paths surfaced and an explicit which-one question before any edit — no silent guess.
- Only the **process** `adr-0001` is edited (Status flipped + section appended); the **product** `adr-0001` file is unchanged (before/after diff empty for it).
- The process ADR's body sections are unchanged apart from the Status line + appended `## Empirical validation`.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>`.

The full eval is GREEN when all 3 scenarios PASS.

## Out of scope for this eval

- ADR authoring + the `status_protocol` creation-time choice — covered by `evals/recording-architecture-decision.md`.
- Supersede / Deprecate lifecycles — deferred (this skill only flips Proposed → Accepted).
- Auto-commit of the flipped ADR — the skill never commits; the operator commits alongside the validating change.
