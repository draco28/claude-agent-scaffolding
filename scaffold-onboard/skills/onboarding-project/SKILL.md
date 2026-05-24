---
name: onboarding-project
description: Drive the 10-phase guided onboarding conversation that authors MASTER-SPEC.md (and EXECUTIVE-SUMMARY.md) as the project's source of truth. Use this when the user wants to start onboarding a new project, begin project setup, kick off a new project, run /onboard, or otherwise initiate the structured 10-phase scaffold-onboard flow. Manages onboarding state, calls architect-critic at Phase 5 / Phase 7 / MASTER-SPEC close, and routes outputs via the workspace-init manifest when present.
---

# onboarding-project

You are the conductor of scaffold-onboard's 10-phase guided conversation. You author `MASTER-SPEC.md` and `EXECUTIVE-SUMMARY.md` interactively, persisting every answer to durable state, then route the outputs per the workspace-init manifest (or fall back to the current working directory in single-repo mode).

Bash helpers in `lib/` do bookkeeping (state CRUD, atomic writes, template rendering, manifest lookups). The judgment work — asking the next question, sequencing phases, deciding when to escalate to architect-critic, framing recaps — happens here, in conversation. Do not stuff reasoning steps inside `bash -c '...'` wrappers; that work belongs in this skill body.

---

## 1. Overview

When invoked, you walk the user through ten role-scoped phases (Product Manager → Strategy → Domain Model → Security → Architecture → UX → Implementation → DevOps → Quality → Operations). Each phase asks 3–7 questions sourced from `templates/onboarding-questions/phases.yaml`. Answers persist to `${CLAUDE_PLUGIN_DATA}/onboarding-state.json` after every write. At Phase 5 close, Phase 7 close, and MASTER-SPEC close you invoke `architect-critic:critiquing-spec` (if installed) for adversarial review. At Phase 10 close you ask the Karpathy opt-in question, suggest `/plan-roadmap` as the next step, and emit `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md` routed via `sf_resolve_output_path`.

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

```
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

- `sf_phases_questions_for <yaml> <phase_id>` — list question IDs for the current phase, gates applied.
- `sf_phases_question_text <yaml> <qid>` — get the question prompt text.
- `sf_phases_question_gate <yaml> <qid>` — get the gate expression (if any); evaluate with `sf_state_gate_passes`.

**Per-phase loop (run once per phase, then advance):**

1. Read questions for the current phase via the helpers above.
2. For each gated subsection, evaluate the gate against existing state answers. If gate fails, skip the subsection silently.
3. Ask each question in declared order. Accept the user's answer, `TBD`, or `skip` (for non-required questions). Persist immediately via `sf_state_write_answer <qid> <value>`.
4. After all questions in the phase are answered, re-render the MASTER-SPEC section for this phase via `sf_master_spec_update_phase <tmpl> <phase_id>` and surface a 3–5 line recap.
5. If the current phase is 5 or 7 OR if this is the MASTER-SPEC close, invoke architect-critic per §5.
6. Present the recap and ask `accept | edit | append a note`. Apply the choice (edit re-prompts; append adds an addendum to the Phase N section).
7. Advance state via `sf_state_advance_phase`.
8. If the new state is `status=complete` (Phase 10 finished), proceed to the Karpathy opt-in (§7) and the MASTER-SPEC close ceremony (§8).

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
| 10 | Operations & Support       | Release / Ops      | **close (after rendering)** |

---

## 4. State management

State lives at `${CLAUDE_PLUGIN_DATA}/onboarding-state.json`. The v0.1.0 schema is preserved in v0.2.

**Schema (v0.1.0-compatible):**

```
{
  "schema_version": "1.0",
  "status": "in_progress" | "complete",
  "current_phase": 1..10,
  "started_at": "<ISO8601>",
  "answers": { "<qid>": "<answer text>", ... }
}
```

**Helpers you call (lib/state.sh):**

- `sf_state_init` — create a fresh state file (acquires the onboarding lock first).
- `sf_state_mode` — returns `new` | `resume` | `reonboard` based on existing state + filesystem.
- `sf_state_path` — print the absolute path of the state file.
- `sf_state_read_field <key>` — read a top-level field (`status`, `current_phase`, `started_at`).
- `sf_state_read_answer <qid>` — read a single answer; returns `null` if unanswered.
- `sf_state_write_answer <qid> <value>` — atomic write of one answer.
- `sf_state_write_atomic <key> <value>` — atomic write of a top-level field.
- `sf_state_advance_phase` — bump `current_phase`; if already at 10, set `status=complete`.
- `sf_state_lock_acquire` / `sf_state_lock_release` — advisory lock so two sessions don't author into the same state file concurrently.
- `sf_state_gate_passes <gate_expr>` — evaluate a phases.yaml gate against current answers (e.g., `project_class in {Web app, ...}`).

**Discipline:**

- **Persist after every single answer.** An interruption mid-Phase-6 must never lose Phase 1–5's work.
- **Acquire the lock at skill entry.** If `sf_state_lock_acquire` fails, surface *"Onboarding already in progress in another session. Either close that session or re-run with `/onboard --force-unlock` after confirming no other session is active."* and stop.
- **Resume protocol.** On entry, call `sf_state_mode`. If `resume`: read `current_phase`, announce position (*"Resuming at Phase N (Architecture). 3 of 5 questions remaining."*), and re-enter at the first unanswered question of that phase (detected via `sf_state_read_answer <qid>` returning `null`).
- **Re-onboard protocol.** If `sf_state_mode` returns `reonboard` (status=complete + state file present): ask explicit confirmation *"Re-onboarding will overwrite MASTER-SPEC.md (backed up to `MASTER-SPEC.md.bak-<timestamp>`) and reset state to Phase 1. Continue? (yes/no, default no)"*. Default is cancel. Only proceed on explicit `yes`.

---

## 5. architect-critic moments (per SPEC §12)

Three critic invocations during the flow:

| # | Moment                | Target               | Depth          | Adversaries        |
|---|-----------------------|----------------------|----------------|--------------------|
| 1 | Phase 5 close (Architecture) | `master-spec-phase` | `premise-audit` | `[claude]`        |
| 2 | Phase 7 close (Implementation) | `master-spec-phase` | `premise-audit` | `[claude]`        |
| 3 | MASTER-SPEC close (post-Phase-10) | `master-spec-full` | `close` | `[claude, codex]` |

### 5.1 Detection (binary v0.2-or-absent)

Call `sf_compose_detect_architect_critic` (lib/compose.sh). It walks known plugin cache directories looking for `architect-critic/*/skills/critiquing-spec/SKILL.md` and prints either `v0.2` or `absent`. There is **no fallback path to older architect-critic versions** — pre-v0.2 architect-critic shipped with zero `skills/` directory, so the `Skill(architect-critic:...)` grammar cannot resolve against it; v0.2 is a hard breaking change per its SPEC §3 NG1. Detection is filesystem-only (not via composition.json); the probe is cheap (<5ms typical) and runs lazily per critic call.

### 5.2 Invocation pattern

At each critic moment, after the recap is rendered but before asking the user `accept | edit | append`:

1. Announce: *"Phase N close — invoking architect-critic for `premise-audit` on the Phase N recap. Type `skip` if you want to bypass this fire."*
2. End the turn and wait for the user's next message. If they type exactly `skip` (case-insensitive), log it and proceed to step 6 of the per-phase loop without calling the critic.
3. Otherwise, invoke `Skill(architect-critic:critiquing-spec)` with:
   - `target=master-spec-phase` (for moments 1 + 2) or `target=master-spec-full` (for moment 3).
   - `depth=premise-audit` (moments 1 + 2) or `depth=close` (moment 3).
   - `phase_id=<N>` so the critic knows which section of MASTER-SPEC.md to focus on.
4. architect-critic runs its own challenge-resolution loop internally (sequential rebuttal, scoring, auto-promotion checks). It returns control via the structured summary block described in architect-critic's SPEC §10 ("Audit complete for ...").
5. When control returns, present any challenges that stood to the user as edit candidates for the recap. They may revise the recap; you re-render via `sf_master_spec_update_phase` to capture the revision.

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

```
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

At Phase 10 close, **before** rendering EXECUTIVE-SUMMARY.md and running the close-depth critic, ask:

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

After the close-depth critic returns (or is skipped) and EXECUTIVE-SUMMARY.md is rendered, emit the close summary:

```
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

The R1 hierarchy doc emitted by `/plan-roadmap` is named `ROADMAP.md` (not `PROJECT_PLAN.md` — `/scaffold-docs`'s separate Phase-2-derived `PROJECT_PLAN.md` is unchanged from v0.1.0 to avoid filename collision; see SPEC §13.5).

---

## 9. Slash-command interaction ($ARGUMENTS bridge)

The `/onboard` slash command wrapper (`commands/onboard.md`) exports the raw arg string as `$ARGUMENTS` (env-var bridge per `feedback_slash_command_dollar_n_bug` — Claude Code substitutes `$1`/`$2`/etc. in command bodies at template-render time, silently corrupting bash positionals; the env-var bridge is the reliable path).

Supported flags:

- *(no flag)* — default: `new` mode if no state file exists; `resume` mode if state is `in_progress`; `reonboard` confirm prompt if `status=complete`.
- `--resume` — explicit resume; errors if no state file is present.
- `--regenerate` — explicit reauthor; backs up existing MASTER-SPEC.md to `MASTER-SPEC.md.bak-<ISO8601>` and resets state to Phase 1. Always asks confirmation first.
- `--force-unlock` — release a stale lock acquired by a crashed prior session. Requires user confirmation that no other session is active.

Parse `$ARGUMENTS` in bash; never reference `$1` / `$2` directly.

---

## 10. Bash bookkeeping helpers (the bookkeeping-vs-judgment line)

This skill never bash-orchestrates the judgment work (which question to ask next, how to recap a phase, whether to escalate a challenge). It calls helpers for I/O and templating only. The named helpers:

**State (lib/state.sh):** `sf_state_init`, `sf_state_mode`, `sf_state_path`, `sf_state_read_field`, `sf_state_read_answer`, `sf_state_write_answer`, `sf_state_write_atomic`, `sf_state_advance_phase`, `sf_state_lock_acquire`, `sf_state_lock_release`, `sf_state_gate_passes`.

**Phases (lib/state.sh / parser.sh):** `sf_phases_questions_for`, `sf_phases_question_text`, `sf_phases_question_gate`.

**Rendering (lib/render.sh):** `sf_render_master_spec_init`, `sf_master_spec_update_phase`, `sf_render_executive_summary`, `sf_render` (generic template substitution).

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

---

## 13. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: which question to ask next, how to frame a recap, when to invoke the critic, how to interpret a `TBD` answer, when to suggest ai-mentor / superpowers.
- **Bash helpers** (`lib/*.sh`) handle pure I/O: state file reads/writes, atomic mv, template substitution, manifest path resolution, filesystem probes.
- **architect-critic** is invoked as a peer skill — it runs its own internal challenge/rebuttal loop and returns a structured summary; you don't mediate its internals.
- **The user** is the final authority. You surface candidate questions, recaps, and critic challenges; they accept, edit, or skip. You never auto-finalize a phase without explicit acceptance.

When in doubt, prefer doing the work in conversation over delegating to bash. The v0.1.x architecture got this wrong (the per-phase loop lived inside `bash -c` blocks Claude never read); v0.2 corrects it.
