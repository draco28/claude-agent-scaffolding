---
name: onboarding-project
description: Drive the 10-phase guided onboarding conversation that authors MASTER-SPEC.md (and EXECUTIVE-SUMMARY.md) as the project's source of truth. Use this when the user wants to start onboarding a new project, begin project setup, kick off a new project, run /onboard, or otherwise initiate the structured 10-phase scaffold-onboard flow. Manages onboarding state, calls architect-critic at Phase 5 / Phase 7 / MASTER-SPEC close, and routes outputs via the workspace-init manifest when present.
---

# onboarding-project

You are the conductor of scaffold-onboard's 10-phase guided conversation. You author `MASTER-SPEC.md` and `EXECUTIVE-SUMMARY.md` interactively, persisting every answer to durable state, then route the outputs per the workspace-init manifest (or fall back to the current working directory in single-repo mode).

Bash helpers in `lib/` do bookkeeping (state CRUD, atomic writes, template rendering, manifest lookups). The judgment work — asking the next question, sequencing phases, deciding when to escalate to architect-critic, framing recaps — happens here, in conversation. Do not stuff reasoning steps inside `bash -c '...'` wrappers; that work belongs in this skill body.

---

## 1. Overview

When invoked, you walk the user through ten role-scoped phases (Product Manager → Strategy → Domain Model → Security → Architecture → UX → Implementation → DevOps → Quality → Operations). Each phase asks 3–7 questions sourced from `templates/onboarding-questions/phases.yaml`. Answers persist to the current project's `onboarding-state.json` under `sf project_data_dir` after every write. At Phase 5 close, Phase 7 close, and MASTER-SPEC close you invoke `architect-critic:critiquing-spec` (if installed) for adversarial review. At Phase 10 close you ask the Karpathy opt-in question, suggest `/plan-roadmap` as the next step, and emit `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md` routed via `sf_resolve_output_path`.

---

## 2. When to use

**Trigger phrases (description-match):**

- `/onboard` (slash command — see §9 for the `$ARGUMENTS` env-var bridge)
- "start onboarding", "begin project setup", "kick off a new project", "scaffold a new project"
- "set up the project from scratch", "let's onboard this codebase", "walk me through onboarding"
- "what's the 10-phase flow?", "run the onboarding conversation"

**Do NOT auto-invoke when:**

- `MASTER-SPEC.md` already exists at the routing destination AND the user did NOT type `/onboard` (silent re-author is destructive). If MASTER-SPEC exists and the user typed `/onboard` with no flag, route to the `--resume` flow (if state is mid-flight) or surface a confirm prompt for `--regenerate` (if state shows `status=complete`). Never overwrite without explicit user confirmation.
- The user wants to *validate* an existing MASTER-SPEC — that's `scaffold-onboard:validating-master-spec` (SPEC §5.7).
- The user wants to derive memory-bank / governance docs — those are `scaffolding-memory-bank` (§5.2) and `scaffolding-governance-docs` (§5.3).
- The user wants to author Phase → Sprint → Vertical-Slice hierarchy — that's `planning-project-roadmap` (§5.4) reached via `/plan-roadmap`.

If you're uncertain whether to invoke, ask: *"Are you starting a fresh onboarding (10-phase MASTER-SPEC conversation), or do you want to work with an existing spec?"*

---

## 3. The 10-phase flow (data lives in phases.yaml)

The phase structure and question list live in `templates/onboarding-questions/phases.yaml` — you read them via bash helpers, you do NOT inline 54 questions into this skill body. The yaml schema (preserved from v0.1.0):

```text
phases[].id            → integer 1..10
phases[].name          → snake_case slug
phases[].title         → human-readable phase name
phases[].role          → persona role for that phase (Product Manager, etc.)
phases[].subsections[] → groups of questions
  .id                  → "N.M" or "N.M/A" (gated variants)
  .gate                → optional condition (e.g., "project_class in {Web app, ...}")
  .questions[]         → {id, text, required, enum?}
```

**Helpers you call:**

- `sf_phases_questions_for <yaml> <phase_id>` — list all question IDs for the current phase (ungated; gate-skipping of subsections is the agent's job per step 2 below).
- `sf_phases_question_text <yaml> <qid>` — get the question prompt text.
- `sf_phases_question_gate <yaml> <qid>` — get a **question-level** gate expression (if any); evaluate with `sf_state_gate_passes`. Returns empty for the common case where the gate lives on the *subsection* — use the next helper for those.
- `sf_phases_subsection_gates <yaml> <phase_id>` — list each **gated subsection** in the phase, one per line as `<subsection_id>\t<gate_expr>`. This is how you discover which subsections are gated (the per-question helper above does not surface subsection-level gates). Read it once per phase, then apply step 2 below. Read-only — it does not evaluate gates or filter questions.

**Per-phase loop (run once per phase, then advance):**

1. Read questions for the current phase via the helpers above.
2. Discover the phase's gated subsections via `sf phases_subsection_gates <yaml> <phase>` (each line is `<subsection_id>\t<gate_expr>`); any subsection not listed is ungated and always asked. For each gated subsection, evaluate the gate against existing state answers with `sf state_gate_passes <gate_expr>`. If gate fails, skip the subsection silently. **Self-gating exception:** if a subsection's gate references an answer that is defined by a question INSIDE that same subsection (the known instance is Phase 9 `9.3`, gated on `uses_llm == true` which is set by answer `9.3.1` inside `9.3`), do NOT skip the subsection before asking. Instead, ask the gating question first (`9.3.1` — the opt-in), then evaluate the gate against that now-present answer and apply it to the subsection's REMAINING questions (`9.3.2+`). Never skip a subsection whose gate value is set by an as-yet-unasked question inside it.
3. Ask each question in declared order. Accept the user's answer, `TBD`, or `skip` (for non-required questions). Persist immediately via `sf_state_write_answer <qid> <value>`.
4. After all questions in the phase are answered, **author the phase record**:
   compose a JSON object capturing the phase's reasoning — `decisions`,
   `rationale`, `alternatives_rejected`, `constraints`, `open_questions`,
   `critic_outcomes` (include only the keys that apply; content is free prose,
   NOT a copy of the raw answers). **On a resumed or re-onboard run, first read
   any existing record with `sf state_read_phase_record <phase_id>` and fold its
   still-valid content forward into the new record** — do not silently discard
   prior rationale or critic-outcomes. (`sf state_write_phase_record` replaces
   the stored object entirely, so the merge must happen in conversation before
   the write.) Write the merged record with your Write tool to a temp file, then
   persist it: `sf state_write_phase_record <phase_id> <temp-file>`. This is
   reasoning work — it is authored by YOU in conversation, never slot-filled. The
   verbatim answers are already persisted (step 3); the record adds the *why*.
   Then surface a 3–5 line recap **echoed from the record you just wrote** (no
   MASTER-SPEC file is rendered — none exists until close).
5. If the current phase is 5 or 7 OR if this is the MASTER-SPEC close, invoke architect-critic per §5.
6. Present the recap and ask `accept | edit | append a note`. Apply the choice (edit re-prompts; append adds an addendum to the phase record). When a critic challenge stands or the user edits/appends to the recap, fold that into the phase record (re-author it and re-call `sf state_write_phase_record`), so a later session inherits the resolved decision — never leave it only in conversation.
7. Advance state via `sf_state_advance_phase`.
8. If the new state is `status=close_pending` (Phase 10 answered, close not yet done), proceed to the Karpathy opt-in (§7) and the MASTER-SPEC close ceremony (§8).

**Phase ↔ role table (for orienting prompts; questions are sourced from phases.yaml, not from this table):**

| # | Phase                       | Role               | Critic moment |
|---|-----------------------------|--------------------|---------------|
| 1 | Foundation                  | Product Manager    | —             |
| 2 | Strategy                    | Strategic Planner  | —             |
| 3 | Domain & Data Model         | Domain Modeler     | —             |
| 4 | Security & Compliance       | Security Engineer  | —             |
| 5 | Architecture                | System Architect   | **premise-audit** |
| 6 | UX / Surfaces               | UX Designer        | —             |
| 7 | Implementation Approach     | Engineer           | **premise-audit** |
| 8 | DevOps & Environments       | DevOps             | —             |
| 9 | Quality, Testing & Eval     | QA Engineer        | —             |
| 10 | Operations & Support       | Release / Ops      | **close (after MASTER-SPEC synthesis)** |

---

## 4. State management

State lives at `$(sf project_data_dir)/onboarding-state.json`. `sf project_data_dir` scopes state under the install-level plugin data root by project identity, so multiple projects can be mid-onboarding concurrently.

**Schema (v2):**

```json
{
  "schema_version": 2,
  "status": "in_progress" | "close_pending" | "complete",
  "current_phase": 1..10,
  "current_question": null,
  "project_class": null,
  "project_root": "<absolute path>",
  "created_at": "<ISO8601>",
  "updated_at": "<ISO8601>",
  "answers": { "<qid>": "<answer text>", ... },
  "phase_records": {
    "3": {
      "decisions": "...",
      "rationale": "...",
      "alternatives_rejected": "...",
      "constraints": "...",
      "open_questions": "...",
      "critic_outcomes": "...",
      "authored_at": "<ISO8601>"
    }
  },
  "touched_this_run": ["3"]
}
```

**Lib invocation contract:** every `sf_<fn>` call below goes through the `sf` dispatcher — `scaffold-onboard/bin/sf`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically. Call form: `sf <fn-suffix> [args...]` resolves to `sf_<fn-suffix>`. The dispatcher's bash shebang forces a bash runtime for the libs even when the surrounding Bash tool subprocess is zsh (Claude Code's macOS default), so `${BASH_SOURCE[0]}` and `${BASH_REMATCH[…]}` inside the libs work as written. Never `source` lib files directly from skill body — under zsh `BASH_SOURCE` is unset and the libs crash; under bash without env var hygiene the regex captures silently return empty. Always go through `sf`. Use `sf --list` for discovery.

**Helpers you call (lib/state.sh):**

- `sf project_identity_root` — print the current project identity root (`SF_PROJECT_ROOT` override → workspace-init manifest AI workspace root → git root → `pwd`).
- `sf project_data_dir` — print this project's scaffold-onboard data directory under the install-level plugin data root.
- `sf state_init` — create a fresh state file with `project_root` captured from `sf project_identity_root`. Acquires the onboarding lock first.
- `sf state_mode` — returns `new` | `resume` | `reonboard` | `project_mismatch` based on existing project-scoped state + `project_root` match. The `project_mismatch` value now catches moved or malformed state inside the current project data dir; switching to another project normally opens a different state file.
- `sf state_stored_project_root` — return the stored `project_root` (or `unknown` for legacy state files lacking the field); useful for rendering the project-mismatch prompt.
- `sf state_path` — print the absolute path of the state file.
- `sf state_read_field <key>` — read a top-level field (`status`, `current_phase`, `project_root`, `updated_at`).
- `sf state_read_answer <qid>` — read a single answer; returns `null` if unanswered.
- `sf state_write_answer <qid> <value>` — atomic write of one answer.
- `sf state_write_atomic <key> <value>` — atomic write of a top-level field.
- `sf state_advance_phase` — bump `current_phase`; if already at 10, set `status=close_pending` (NOT `complete`). The transition to `complete` is made by the §8 close ceremony via `sf state_write_atomic status complete`.
- `sf state_lock_acquire` / `sf state_lock_release` — advisory lock so two sessions don't author into the same state file concurrently.
- `sf state_gate_passes <gate_expr>` — evaluate a phases.yaml gate against current answers (e.g., `project_class in {Web app, ...}`).

**Discipline:**

- **Persist after every single answer.** An interruption mid-Phase-6 must never lose Phase 1–5's work.
- **`--force-unlock` pre-lock release (BEFORE acquiring the lock).** If the parsed `--force-unlock` flag is set: confirm with the user — *"Confirm no other onboarding session is active. Type 'yes' to release the stale lock, or anything else to cancel."* — and only on an affirmative response call `sf state_lock_release` to clear the stale lock, then continue to normal lock acquisition below. This step MUST run before the acquire step — otherwise `--force-unlock` cannot recover from a stale lock (the acquire would immediately fail first).
- **Acquire the lock at skill entry.** If `sf_state_lock_acquire` fails, surface *"Onboarding already in progress in another session. Either close that session or re-run with `/onboard --force-unlock` after confirming no other session is active."* and stop.
- **`--regenerate` override (BEFORE mode routing).** If the parsed `--regenerate` flag is set, handle it FIRST — before calling `sf state_mode` and before any resume/reonboard routing — regardless of whether `sf state_mode` would return `resume`, `reonboard`, or `close_pending`. Route directly to the re-onboard full re-walk protocol: **if no state file exists yet** (a fresh `--regenerate` with no prior onboarding — `sf state_mode` would return `new`), call `sf state_init` FIRST so the subsequent atomic writes have a file to operate on (without this, `sf state_write_atomic` has no state file to read and fails). Then back up the existing MASTER-SPEC.md (if present), set `sf state_write_atomic current_phase 1` + `sf state_write_atomic status in_progress`, then re-walk all 10 phases (existing answers as defaults) and re-synthesize the whole spec (first-author). This is distinct from `--fresh`: `--regenerate` preserves existing answers and phase records (shown as defaults during the re-walk) — it never wipes them. `--regenerate --fresh` is equivalent to `--fresh` alone. No-flag default still follows `sf state_mode`.
- **`--fresh` override (BEFORE mode routing).** If the parsed `--fresh` flag is set, handle it FIRST — before calling `sf state_mode` and before any resume/reonboard routing — regardless of whether existing state is `in_progress`, `close_pending`, or `complete`. Confirm with the double-confirmation: *"This will discard ALL prior answers and phase reasoning records for this project and re-author the spec from Phase 1. Any existing MASTER-SPEC.md is left untouched on disk (back it up yourself if you want it). Type 'confirm discard' to proceed, or anything else to cancel."* Only on an exact `confirm discard`: call `sf state_init` (fresh state, no records) and proceed from Phase 1. On anything else, cancel and stop (do NOT fall through to resume). This guarantees `/onboard --fresh` on an *interrupted* onboarding wipes-and-restarts rather than silently resuming the old state. (The §4 re-onboard escape-hatch `fresh` keyword at the phase-selection prompt is the equivalent path when already inside a `reonboard` revision; this top-level branch covers the `--fresh` flag for every entry mode.)
- **Reset the per-run tracker only when starting a new revision session.** Do NOT call `sf state_run_reset` on ordinary `resume`: `touched_this_run` carries no synthesis role in the descoped re-onboard flow, but is preserved for future use. Fresh `new` mode gets an empty tracker from `sf state_init`.
- **Resume protocol.** On entry, call `sf state_mode`. If `resume`:
  - **If `status` is `close_pending`** (all phases answered; close not yet finished): announce *"All phases complete — resuming the MASTER-SPEC close ceremony."* Do NOT re-walk the phase loop. Proceed directly to §7 (Karpathy opt-in, if not yet answered) and then §8 (MASTER-SPEC close ceremony). Do still run the missing-record repair pass (below) before §8 — a crashed first-author run may have left some phase records unwritten.
  - **Otherwise** (`status` is `in_progress`, normal mid-phase resume): read `current_phase`, announce position (*"Resuming at Phase N (Architecture). 3 of 5 questions remaining."*), then re-enter at the first unanswered question of that phase (detected via `sf state_read_answer <qid>` returning `null`).
  - **Missing-record repair pass (all resume variants):** inspect phases up to AND INCLUDING the current resume phase (or all 10 phases on a close_pending resume). For each phase P: a phase is eligible for record-repair ONLY if (a) `sf state_read_phase_record <phase_id>` returns `null` AND (b) every required question in an **active** (not gated-out) subsection has a non-null answer — i.e., no required question that the conductor would actually have asked remains unanswered. To judge which subsections are active, read `sf phases_subsection_gates <yaml> P` and evaluate each gate with `sf state_gate_passes` (applying the §3 step 2 self-gating exception). A required question that lives inside a **gated-out** subsection is NOT counted as a missing answer — its branch was never asked, so its absence must not block record-repair (e.g. a Library/SDK project never answers the web-UX `6A.*` required questions; phase 6 is still record-repair-eligible once its active `6B.*` required questions are answered). Unanswered **optional** questions (`required: false`) likewise never block repair AND are never re-asked by this pass — they surface only during a normal mid-phase resume (§3), so the repair pass must not treat their absence as "incomplete" nor silently mask a phase whose *required* answers are genuinely missing. If both conditions hold, re-author that phase record from the stored answers in conversation and persist it with `sf state_write_phase_record` before advancing. This explicitly covers the current phase: if a crash occurred after the current phase's last answer was persisted but before `sf state_write_phase_record` + `sf state_advance_phase` ran, the state remains `in_progress`/`current_phase=N` with all required answers present but no record — the repair pass detects this (record missing + no remaining required questions), re-authors the record, then advances so the resume continues cleanly at phase N+1. **On a normal mid-phase resume** where required questions are still unanswered: do NOT repair or advance — re-enter at the first unanswered question and let the record be authored normally at phase close (§3 step 4). Do NOT author a partial record or advance when any required question remains unanswered. Required = `required: true` in phases.yaml. The active-vs-gated-out judgment is the **conductor's** job here — done with `sf phases_subsection_gates` + `sf state_gate_passes` exactly as in §3 step 2 — NOT by reintroducing helper-level gate-filtering into `sf_phases_questions_for` (that change caused the Phase-9 LLM-opt-in regression and was reverted). The repair pass only authors the missing reasoning record; it never re-asks questions.
- **Re-onboard protocol.** If `sf state_mode` returns `reonboard` (status=complete + state file present + project_root matches): DO NOT call `sf state_init` — that wipes `phase_records` and answers. Instead:
  1. Set `sf state_write_atomic current_phase 1` and `sf state_write_atomic status in_progress` (so an interrupted re-walk resumes correctly at Phase 1 on the next `/onboard`). The lock is already held from skill entry — do NOT call `sf_state_lock_acquire` again here (it is non-reentrant and will fail if the lock file already exists).
  2. Announce: *"Re-onboarding: I'll walk all 10 phases again with your existing answers shown as defaults — keep or change each. At the end the whole spec is re-synthesized (your prior MASTER-SPEC.md is backed up)."*
  3. Proceed through the NORMAL per-phase loop (§3): each phase re-asks its questions (existing answers shown as defaults; gate-skipping handled by the agent per §3 step 2 as usual), re-authors the phase record (fold-forward per §3 step 4). At Phase 10 → `sf state_advance_phase` → `status=close_pending` → §7 Karpathy opt-in → §8 first-author full re-synthesis (prior MASTER-SPEC.md backed up automatically by §8's backup logic — see below).
  4. **Escape hatch — start completely fresh:** if the user explicitly types `fresh` or `yes, discard everything` during the re-onboard walk, confirm once more: *"This will discard all prior answers and phase reasoning records for this project and re-author the spec from Phase 1. Prior MASTER-SPEC.md is still backed up. Type 'confirm discard' to proceed or anything else to cancel."* Only on `confirm discard`: call `sf state_init` (fresh state, no records) and proceed from Phase 1. This wipe path MUST NOT be the default and MUST require this explicit double-confirmation distinct from the normal revise flow.

> **Note (deferred):** Partial-reconcile mode — revisiting only chosen phases and preserving untouched sections — is reserved for a follow-up. The `sf state_mark_touched` helper and the `reconcile` mode in `sf_synth_master_spec_prompt` are kept in the lib for that follow-up but are NOT driven from the current re-onboard flow.
- **Project-mismatch protocol.** If `sf state_mode` returns `project_mismatch`: fetch the stored path via `sf state_stored_project_root`, fetch the current identity via `sf project_identity_root`, and surface this prompt (substitute `<stored>` and `<current>`): *"Project-scoped onboarding state says it belongs to `<stored>`, but this session resolves the project as `<current>`. Options: (1) return to the original path / set `SF_PROJECT_ROOT=<stored>` and re-run /onboard, (2) start fresh for `<current>` — this overwrites only this project-scoped onboarding state, not other projects. Which? (1/2)"*. Wait for the user's pick. On `1`, exit non-zero with the path instruction; on `2`, call `sf state_init` and proceed at Phase 1.

---

## 5. architect-critic moments (per SPEC §12)

Three critic invocations during the flow:

| # | Moment                | Target               | Depth          | Adversary (inferred by ac) |
|---|-----------------------|----------------------|----------------|----------------------------|
| 1 | Phase 5 close (Architecture) | `master-spec-phase` | `premise-audit` | inferred internally       |
| 2 | Phase 7 close (Implementation) | `master-spec-phase` | `premise-audit` | inferred internally      |
| 3 | MASTER-SPEC close (after Phase-10 synthesis) | `master-spec-full` | `close` | inferred internally  |

> **Note:** architect-critic v0.2 detects host-agent + adversary availability internally (per its contract / §12.2). The caller passes only `target`, `depth`, `artifact_path` (and `phase_id` for phase moments). Do NOT pass an `adversaries` argument — it is not part of the invocation contract.

### 5.1 Detection (binary v0.2-or-absent)

Call `sf_compose_detect_architect_critic` (lib/compose.sh). It walks known plugin cache directories looking for `architect-critic/*/skills/critiquing-spec/SKILL.md` and prints either `v0.2` or `absent`. There is **no fallback path to older architect-critic versions** — pre-v0.2 architect-critic shipped with zero `skills/` directory, so the `Skill(architect-critic:...)` grammar cannot resolve against it; v0.2 is a hard breaking change per its SPEC §3 NG1. Detection is filesystem-only (not via composition.json); the probe is cheap (<5ms typical) and runs lazily per critic call.

### 5.2 Invocation pattern

At Phase 5 and Phase 7 critic moments, after the phase record is authored and the recap is surfaced but before asking the user `accept | edit | append`:

1. Announce: *"Phase N close — invoking architect-critic for `premise-audit` on the Phase N recap. Type `skip` if you want to bypass this fire."*
2. End the turn and wait for the user's next message. If they type exactly `skip` (case-insensitive), log it and proceed to step 6 of the per-phase loop without calling the critic.
3. Otherwise, write a concrete phase artifact before invoking the critic:
   ```bash
   phase_artifact="$(sf project_data_dir)/phase-${phase_id}-critic-recap.md"
   sf state_write_phase_artifact "$phase_id" "$phase_artifact"
   ```
4. Invoke `Skill(architect-critic:critiquing-spec)` with:
   - `target=master-spec-phase`.
   - `depth=premise-audit`.
   - `phase_id=<N>` so the critic knows which section of MASTER-SPEC.md to focus on.
   - `artifact_path="$phase_artifact"` (or pass `$phase_artifact` as the first path argument if the host Skill bridge supports positional args). This is required because first-author runs do not have `MASTER-SPEC.md` until Phase 10; architect-critic must audit this phase recap file, not a heuristic `SPEC*`/`PLAN*` match.
5. architect-critic runs its own challenge-resolution loop internally (sequential rebuttal, scoring, auto-promotion checks). It returns control via the structured summary block described in architect-critic's SPEC §10 ("Audit complete for ...").
6. When control returns, present any challenges that stood to the user as edit candidates for the recap. When a critic challenge stands or the user revises or appends to the recap, re-author the phase record: first read the current record with `sf state_read_phase_record <phase_id>` and fold its existing content forward (preserving rationale and prior critic-outcomes already captured), then merge the new challenge outcomes in, and re-call `sf state_write_phase_record` to persist it — so a later session inherits the full resolved picture, never leave it only in conversation.

The MASTER-SPEC close critic is different: run it after §8 synthesizes `MASTER-SPEC.md`, with `target=master-spec-full` and `depth=close`, so the critic reviews the artifact that will be kept. Apply accepted close-critic edits to `MASTER-SPEC.md`, then continue to EXEC-SUMMARY synthesis.

### 5.3 Absent / warn-and-skip

If `sf_compose_detect_architect_critic` returns `absent`, emit one warning and continue:

> *"architect-critic not installed — skipping `<phase-N>` premise audit. Install via `/plugin install architect-critic` (v0.2+) for adversarial review at this phase."*

Do not stall the conversation. The onboarding flow is robust to architect-critic's absence; the critic is a strength-multiplier, not a gate.

### 5.4 What you do NOT do

- Do **not** use the legacy file-IPC pattern (`sf_compose_build_critic_request` / `sf_compose_read_critic_response`) — both functions were removed in v0.2 per SPEC §12.3. No `inbox/` or `outbox/` paths.
- Do **not** read `composition.json` to detect architect-critic — that registry no longer tracks ac in v0.2 (per ac v0.2 settlement #1). Filesystem probe only.
- Do **not** invoke `Skill(architect-critic:critique)` — the v0.1.x slash-command-shaped entry point. The v0.2 skill is `critiquing-spec`.

---

## 6. Manifest-aware output routing (per SPEC §10)

When the user has run workspace-init, a manifest at `<ai-workspace>/.workspace/pairing.json` declares routing rules per logical-output name. scaffold-onboard's outputs route as:

| Logical name        | Destination (default)    | Emitted by                  |
|---------------------|--------------------------|-----------------------------|
| `master_spec`       | `ai_workspace`           | this skill (Phase 10 close) |
| `executive_summary` | `canonical`              | this skill (Phase 10 close) |

**Helper:** `sf_resolve_output_path <logical_name> <relative_path>` (lib/routing.sh — T3.1):

```bash
master_spec_path="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
exec_summary_path="$(sf_resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"
```

Behavior:

- If the manifest is present (walked up from `pwd` to find `.workspace/pairing.json`): returns the absolute path with the logical destination's root expanded.
- If the manifest is absent: returns `$(pwd)/<relative_path>` — exactly the v0.1.0 single-repo behavior. Tests of single-repo mode (and v0.1.0 byte-identical outputs) pass via this fallback.
- If the manifest is present but the logical name is missing from `routing.*`: warns once + falls back to `$(pwd)/<relative_path>`. Forward-compatible with older workspace-init manifests that pre-date a logical-name addition.

Always route through `sf_resolve_output_path` — never hardcode `MASTER-SPEC.md` paths against the cwd directly. If the helper is unavailable (older lib/), surface the error: *"Routing helper missing — install scaffold-onboard v0.2.0+."*

---

## 7. Karpathy section opt-in (per SPEC §14)

At Phase 10 close, **before** producing EXECUTIVE-SUMMARY.md (§8) and running the close-depth critic, ask:

> *"Include behavioral discipline section in CLAUDE.md? This adds 4 cognitive principles (Karpathy-inspired) to your agent's behavior. (yes/no, default yes)"*

Store the answer via `sf_state_write_answer phase_10.4.include_karpathy <yes|no>`. The actual emission happens later in `scaffolding-memory-bank` (SPEC §5.2) when it derives CLAUDE.md — that skill reads the answer and emits or skips the section. Your job here is just the opt-in capture.

The four principles (sourced from `forrestchang/andrej-karpathy-skills`, MIT; attribution language: *"Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)"*) are:

1. **Think Before Coding** — state assumptions, surface ambiguity, ask before guessing.
2. **Simplicity First** — minimum code, no speculative abstractions.
3. **Surgical Changes** — touch only what's needed, no orthogonal refactors.
4. **Goal-Driven Execution** — vague asks → verifiable success criteria.

All-or-nothing opt-in for v0.2. Per-principle granularity defers to v0.3+ if user feedback requests it.

---

## 8. Phase 10 close action

Produce MASTER-SPEC.md first, run the close-depth critic/edit loop against that synthesized artifact, then produce EXECUTIVE-SUMMARY.md and emit the close summary. This ordering is required by the SS-3 contract: the `master-spec-full` critic must inspect the post-synthesis `MASTER-SPEC.md`, not a missing first-author artifact or a stale pre-synthesis backup.

**Produce MASTER-SPEC.md (agent synthesis — no deterministic renderer).**

```bash
root="$(sf plugin_root)"
brief="${root}/templates/synthesis-briefs/MASTER-SPEC.brief.md"
master="$(sf resolve_output_path master_spec MASTER-SPEC.md)"
digest_file="$(mktemp "${TMPDIR:-/tmp}/sf-digest.XXXXXX")"
sf state_synthesis_digest > "$digest_file"
digest_rc=$?
master_bak=""
if [[ -f "$master" ]]; then
  master_bak="${master}.bak-$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cp "$master" "$master_bak"
fi
mode="first_author"; existing=""; touched=""
prompt="$(sf synth_master_spec_prompt "$brief" "$digest_file" "$master" "$mode" "$touched" "$existing")"
asm_rc=$?
rm -f "$digest_file"
```

**If digest generation fails** (`digest_rc` is non-zero — `sf state_synthesis_digest` exits non-zero on a corrupt/unreadable `onboarding-state.json`): the `> "$digest_file"` redirection still leaves an empty readable file, so this exit-code check is what stops the flow before it synthesizes from nothing. Surface the digest error verbatim, `rm -f "$digest_file"`, and do NOT back up the spec, assemble the prompt, or dispatch. Surface *"State preserved (`status=close_pending`). Run `/onboard` or `/onboard --resume` to retry the close synthesis."* and stop. (Defense-in-depth: even if a caller skips this check, `sf synth_master_spec_prompt` itself now rejects an empty digest, so the `asm_rc` guard below also catches it.)

**If prompt assembly fails** (`asm_rc` is non-zero — `sf synth_master_spec_prompt` exits non-zero on a missing/unreadable brief, a missing/unreadable/**empty** digest file, or an invalid mode):
- Surface the assembler's stderr verbatim.
- Do NOT dispatch the synthesis agent and do NOT enter the inline fallback below — `$prompt` is empty/partial, so both paths would synthesize from nothing.
- Surface: *"State preserved (`status=close_pending`). Run `/onboard` or `/onboard --resume` to retry the close synthesis."*
- Stop. Do NOT set `status=complete`, run the close critic, or produce EXEC-SUMMARY. The next `/onboard` (or `/onboard --resume`) re-enters directly at §8.

Then dispatch the synthesis agent with that prompt:

```text
Task(subagent_type="scaffold-onboard:synthesis-agent",
     description="Synthesize MASTER-SPEC",
     model="claude-sonnet-4-5",
     prompt="$prompt")
```

**Fallback (no dispatch available):** if you cannot dispatch a sub-agent (headless
/ no Task tool), DO NOT fall back to any deterministic renderer — there is none.
Instead, perform the synthesis yourself in this orchestration context: read the
SAME assembled `$prompt` (it embeds the brief + digest + mode) and author
`$master` directly with your Write tool, following the brief's guidance exactly.
The host (Claude Code or Codex) is itself a capable synthesizer because the brief
is a plugin asset. Only if the host runtime itself cannot write the file should
you stop and tell the user to re-run `/onboard` close later — state is fully
preserved, so nothing is lost.

Before invoking the close-depth critic or producing EXECUTIVE-SUMMARY, validate the synthesized file:

```bash
sf spec_validate "$master"
```

If validation fails:
- Surface the validator stderr verbatim.
- **Cleanup** — a failed synthesis must not leave a garbage file where a valid baseline previously existed (or didn't):
  - If `master_bak` is set and exists (a prior spec was present): restore it — `cp "$master_bak" "$master"` — this discards the bad synthesis and reinstates the last-valid spec so the project is not left with a corrupt MASTER-SPEC.
  - Otherwise (no prior spec — true first-author): `rm -f "$master"` — removing the malformed file ensures the next retry stays in first-author mode. Keeping garbage here would trigger the backup path on retry against an invalid baseline.
- Surface: *"State preserved (`status=close_pending`). Run `/onboard` or `/onboard --resume` to retry the close synthesis."*
- Stop. Do NOT set `status=complete`. Do not run the close critic, EXEC-SUMMARY generation, `/plan-roadmap`, `/scaffold-project`, or `/scaffold-docs` from a malformed `MASTER-SPEC.md`. The next `/onboard` (or `/onboard --resume`) re-enters directly at §8 to retry synthesis.

After validation passes, invoke `Skill(architect-critic:critiquing-spec)` with `target=master-spec-full`, `depth=close`, and `artifact_path="$master"`. architect-critic detects host-agent and adversary availability internally — do not pass an `adversaries` argument. Surface standing challenges as final edit candidates and apply accepted edits to `MASTER-SPEC.md`; if accepted edits change parser anchors or project class fields, re-run `sf spec_validate "$master"` before continuing. If architect-critic is absent or skipped, proceed directly. Then continue to EXEC-SUMMARY.

**Produce EXECUTIVE-SUMMARY.md (single authoritative producer).** EXEC-SUMMARY is
spec-derived from MASTER-SPEC and authored HERE — `/scaffold-project` and
`/scaffold-docs` only consume it. Default = synthesis; `--fast` = deterministic.

- **Synthesis (default):** dispatch the EXEC-SUMMARY brief from MASTER-SPEC only:
  ```bash
  root="$(sf plugin_root)"
  brief="${root}/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md"
  out="$(sf resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"
  master="$(sf resolve_output_path master_spec MASTER-SPEC.md)"
  prompt="$(sf synth_brief_assemble "$brief" "$(sf synth_ledger_empty)" "$out" "$master" "")"
  ```
  Then dispatch the synthesis agent:
  ```text
  Task(subagent_type="scaffold-onboard:synthesis-agent",
       description="Synthesize EXECUTIVE-SUMMARY",
       model="claude-sonnet-4-5",
       prompt="$prompt")
  ```
  After `mode:complete`, copy the synthesized body back into MASTER-SPEC's pinned
  `## Executive Summary` section and render the canonical EXECUTIVE-SUMMARY with
  a checksum from the updated source:
  ```bash
  if ! sf render_executive_summary_from_synthesized "$master" "$out" "$(sf project_name)" "$(sf state_read_answer 1.3.1)"; then
    echo "warn: Synthesized Executive Summary contained disallowed structure (## heading / --- rule / phase marker) or was empty; falling back to the deterministic renderer from MASTER-SPEC's pinned section." >&2
    sf render_executive_summary "$master" "$out" "$(sf project_name)" "$(sf state_read_answer 1.3.1)" ||
      sf render_executive_summary_from_state "$master" "$out" "$(sf project_name)" "$(sf state_read_answer 1.3.1)"
  fi
  ```
  The write-back refuses a synthesized body that contains a section delimiter
  (`## ` / `---` rule / phase marker) — it would corrupt MASTER-SPEC's pinned
  section. On that rejection the close does NOT hard-fail: it warns and falls back
  to the deterministic `sf_render_executive_summary` (clean MASTER-SPEC section),
  and finally to `sf_render_executive_summary_from_state` for a brand-new spec.
- **Deterministic (`--fast` / synthesis fallback):**
  ```bash
  master="$(sf resolve_output_path master_spec MASTER-SPEC.md)"
  out="$(sf resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"
  if ! sf render_executive_summary "$master" "$out" "$(sf project_name)" "$(sf state_read_answer 1.3.1)"; then
    sf render_executive_summary_from_state "$master" "$out" "$(sf project_name)" "$(sf state_read_answer 1.3.1)"
  fi
  ```
  `sf_render_executive_summary` errors loudly if MASTER-SPEC has no `## Executive Summary`
  section or still has the template placeholder. In the onboarding close path only,
  `sf_render_executive_summary_from_state` may bootstrap the summary from Phase 1
  answers when a brand-new MASTER-SPEC has not yet had its pinned summary section
  filled. It still errors if Phase 1 state is too thin. Both helpers append the
  provenance trailer themselves.

EXEC-SUMMARY is produced/refreshed ONLY here; hand-edits are overwritten on the next
authoritative refresh (spec §2.3). To change it, edit MASTER-SPEC's `## Executive Summary`
section, then re-run onboarding to close.

After EXECUTIVE-SUMMARY.md is produced, emit the close summary:

```text
MASTER-SPEC.md authored at <resolved_master_spec_path>.
EXECUTIVE-SUMMARY.md authored at <resolved_exec_summary_path>.

Onboarding complete (Phase 10 / 10).

Next step:
  Run /plan-roadmap to decompose MASTER-SPEC into Phase → Sprint → Vertical Slice
  hierarchy (ROADMAP.md). This is the R1 input contract for scaffold-dev v0.1's
  orchestrator-implementer cycle.

You can also run:
  /scaffold-project  → derive memory bank + CLAUDE.md + .claude/settings.json from MASTER-SPEC
  /scaffold-docs     → derive PRD / SRS / BACKLOG / PROJECT_PLAN / ADR-0001 from MASTER-SPEC
```

After emitting the close summary, mark onboarding complete:

```bash
sf state_write_atomic status complete
```

This is the ONLY place `status` transitions to `complete`. Prior to this call the status is `close_pending`; if the skill body is interrupted before reaching here, the next `/onboard` re-enters as `resume` and retries the close ceremony from §8.

If a prior MASTER-SPEC was present (i.e. `master_bak` is set), append a second line after the MASTER-SPEC path line:
`Re-synthesized (full first-author); prior spec backed up to <master_bak>.`
Omit this line when no prior spec existed.

The R1 hierarchy doc emitted by `/plan-roadmap` is named `ROADMAP.md` (not `PROJECT_PLAN.md` — `/scaffold-docs`'s separate Phase-2-derived `PROJECT_PLAN.md` is unchanged from v0.1.0 to avoid filename collision; see SPEC §13.5).

---

## 9. Slash-command interaction ($ARGUMENTS bridge)

The `/onboard` slash command wrapper (`commands/onboard.md`) exports the raw arg string as `$ARGUMENTS` (env-var bridge per `feedback_slash_command_dollar_n_bug` — Claude Code substitutes `$1`/`$2`/etc. in command bodies at template-render time, silently corrupting bash positionals; the env-var bridge is the reliable path).

Supported flags:

- *(no flag)* — default: `new` mode if no state file exists; `resume` mode if state is `in_progress` or `close_pending`; **full re-walk re-synthesis** (the §4 re-onboard protocol) if `status=complete`.
- `--resume` — explicit resume; errors if no state file is present. Accepts `status=close_pending` (re-enters §8 close ceremony) as well as `status=in_progress` (re-enters the phase loop). Does NOT block on `status=close_pending`.
- `--regenerate` — full re-walk re-synthesis: backs up existing MASTER-SPEC.md to `MASTER-SPEC.md.bak-<ISO8601>`, re-walks all 10 phases (existing answers shown as defaults), re-synthesizes the whole spec (first-author). Does NOT reset/wipe answers or phase records (use `--fresh` for that). Partial-reconcile (choose only some phases) is deferred to a follow-up.
- `--fresh` — full wipe-and-restart: discard all prior answers and phase reasoning records and re-author from Phase 1. Requires explicit double confirmation (see §4 re-onboard escape hatch). Use this only when you want to start the spec conversation from scratch. `--regenerate --fresh` is equivalent to `--fresh` alone.
- `--force-unlock` — release a stale lock acquired by a crashed prior session. Requires user confirmation that no other session is active.

Parse `$ARGUMENTS` in bash; never reference `$1` / `$2` directly.

---

## 10. Bash bookkeeping helpers (the bookkeeping-vs-judgment line)

This skill never bash-orchestrates the judgment work (which question to ask next, how to recap a phase, whether to escalate a challenge). It calls helpers for I/O and templating only. The named helpers:

**State (lib/state.sh + lib/_helpers.sh):** `sf_project_identity_root`, `sf_project_data_dir`, `sf_state_init`, `sf_state_mode`, `sf_state_path`, `sf_state_read_field`, `sf_state_stored_project_root`, `sf_state_read_answer`, `sf_state_write_answer`, `sf_state_write_atomic`, `sf_state_advance_phase`, `sf_state_lock_acquire`, `sf_state_lock_release`, `sf_state_gate_passes`, `sf_state_write_phase_record`, `sf_state_read_phase_record`, `sf_state_write_phase_artifact`, `sf_state_run_reset`, `sf_state_mark_touched`, `sf_state_phases_touched_this_run`, `sf_state_synthesis_digest`.

**Phases (lib/state.sh / parser.sh):** `sf_phases_questions_for`, `sf_phases_question_text`, `sf_phases_question_gate`.

**Rendering (lib/render.sh):** `sf_render_executive_summary`, `sf_render_executive_summary_from_synthesized`, `sf_render_executive_summary_from_state`, `sf_render` (generic template substitution).

**Composition (lib/compose.sh):** `sf_compose_detect_architect_critic`, `sf_compose_refresh` (for ai-mentor / superpowers via composition.json — separate from architect-critic detection).

**Routing (lib/routing.sh):** `sf_resolve_output_path`, `sf_discover_manifest`.

These are pseudocode references — the implementations are in their respective lib files. macOS-portable patterns (BSD awk, bash 3.2) are required for any inline snippets; prefer calling the helpers over re-inlining shell.

---

## 11. Composition awareness (ai-mentor + superpowers)

scaffold-onboard maintains a `composition.json` registry for ai-mentor + superpowers detection (per SPEC §12.2 — architect-critic detection is separate, filesystem-only). At each critic moment (Phase 5 echo, Phase 7 echo, Phase 10 close), after surfacing the recap but before invoking architect-critic:

- If ai-mentor v2.0 is detected via `composition.json` and the user seems uncertain or the architectural decisions feel under-stress-tested, optionally suggest: *"Want to stress-test these architectural decisions before the critic runs? `ai-mentor:grill-me` can interview you one question at a time on this phase. (suggest / skip)"*. Warn-and-skip if absent.
- If superpowers is detected with `brainstorming_available=true` and the user is wrestling with visual trade-offs (multiple competing architectures), suggest `superpowers:brainstorming` as a divergence tool. Warn-and-skip if absent.

These are suggestions, not gates. The user may decline or skip; you proceed to architect-critic regardless.

---

## 12. Anti-patterns (do not do these)

- **Inlining all 54 phases.yaml questions in this body.** The skill is the conductor; phases.yaml is the data. Pulling questions into this body inflates it past the ≤500-line guidance and creates two sources of truth.
- **Silently overwriting MASTER-SPEC.md without confirmation.** Always ask. Always back up.
- **Reading `composition.json` to detect architect-critic.** Use the filesystem probe (`sf_compose_detect_architect_critic`).
- **Writing to inbox/ or outbox/ paths.** File-IPC is removed in v0.2. In-conversation `Skill(...)` invocation only.
- **Hardcoding `MASTER-SPEC.md` against `$(pwd)`.** Always route via `sf_resolve_output_path master_spec MASTER-SPEC.md`.
- **Calling `Skill(architect-critic:critique)` (the v0.1.x slash-command name).** Use `Skill(architect-critic:critiquing-spec)` — the v0.2 skill.
- **Bash-orchestrating the question loop.** Each question is a turn the user replies to; bash cannot read user input in non-TTY sessions (subagent, hooks, headless). Use Claude's native turn handling.
- **Transcribing raw answers into a templated MASTER-SPEC.** There is no deterministic MASTER-SPEC renderer. MASTER-SPEC is synthesized once at close from the phase records + answers (see §8). Do not slot-fill a template per phase.

---

## 13. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: which question to ask next, how to frame a recap, when to invoke the critic, how to interpret a `TBD` answer, when to suggest ai-mentor / superpowers.
- **Bash helpers** (`lib/*.sh`) handle pure I/O: state file reads/writes, atomic mv, template substitution, manifest path resolution, filesystem probes.
- **architect-critic** is invoked as a peer skill — it runs its own internal challenge/rebuttal loop and returns a structured summary; you don't mediate its internals.
- **The user** is the final authority. You surface candidate questions, recaps, and critic challenges; they accept, edit, or skip. You never auto-finalize a phase without explicit acceptance.

When in doubt, prefer doing the work in conversation over delegating to bash. The v0.1.x architecture got this wrong (the per-phase loop lived inside `bash -c` blocks Claude never read); v0.2 corrects it.
