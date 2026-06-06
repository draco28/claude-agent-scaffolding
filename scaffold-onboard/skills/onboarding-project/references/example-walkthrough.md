# Example walkthrough: onboarding `todo-cli` end-to-end

A concrete trace of the 10-phase `/onboard` flow against an imaginary project: **todo-cli**, a single-binary command-line task manager written in Rust. Use this to anchor what each phase's conversation actually *feels like* — the question vocabulary, the recap shape, the critic invocations, and the state JSON evolution.

This walkthrough uses `project_class = "CLI tool"` (one of the nine v0.1.0 enum values). All bash invocations, state JSON shapes, and critic calls are runnable in spirit — they match the helpers in `lib/` and the SKILL.md contract verbatim.

---

## Setup

```bash
$ cd ~/work/todo-cli
$ git init
$ /onboard
```

Skill triggers via `/onboard` → `commands/onboard.md` exports `$ARGUMENTS=""` → routes to `scaffold-onboard:onboarding-project`. Lock acquired via `sf_state_lock_acquire`; `sf_state_init` writes a fresh project-scoped state file at `$(sf project_data_dir)/onboarding-state.json`.

Skill announces:

> Starting onboarding for `todo-cli`. We'll walk 10 role-scoped phases (Foundation → Operations). Answers persist after every question, so you can stop and resume anytime with `/onboard --resume`. Phase 1 of 10 — Product Manager hat on.

---

## Phase 1 — Foundation (Product Manager)

**Skill asks 1.1.1:** *"One-sentence elevator pitch: what are you building?"*

**User:** A fast offline-first CLI for managing personal todos with tagging, due dates, and full-text search.

`sf_state_write_answer 1.1.1 "<answer>"` persists immediately.

**Skill asks 1.1.2:** *"What problem does this solve, and for whom?"*

**User:** Developers who live in the terminal and want todo capture without leaving the shell. Existing tools either bloat (Todoist, OmniFocus) or lack search (taskwarrior). Target: solo developers, terminal-resident.

**Skill asks 1.1.3 (optional):** *"What does success look like 6 months from launch?"*

**User:** TBD.

**Skill asks 1.2.1, 1.2.2** (Users & Use cases) → answers persisted.

**Skill asks 1.3.1 (enum):** *"Project class — pick one"*

**User:** CLI tool.

**Skill asks 1.3.2:** *"MVP cut — smallest thing that demos value end-to-end?"*

**User:** `todo add`, `todo ls`, `todo done <id>`, `todo search <query>` — all persisting to a single sqlite file under `~/.todo-cli/db.sqlite`.

Skill authors the Phase 1 record (decisions, rationale, etc.) and persists it via `sf state_write_phase_record 1 <temp-file>`, then surfaces the recap echoed from that record:

> **Phase 1 recap (Foundation)**
> - Vision: offline-first CLI for terminal-resident developers managing personal todos with tagging, due dates, search.
> - Primary user: solo dev, terminal-resident, frustrated by GUI bloat or feature-poor existing CLIs.
> - Project class: **CLI tool**.
> - MVP: `add` / `ls` / `done` / `search` over a local sqlite file.
>
> accept | edit | append a note?

**User:** accept.

`sf_state_advance_phase` → `current_phase` becomes 2.

---

## Phase 2 — Strategy (Strategic Planner)

Skill asks the Phase 2 questions per phases.yaml (2.1.1 weeks-to-MVP, 2.1.2 team size, 2.2.1 budget, 2.2.2 top 3 risks, 2.3.1 success metric). User answers: 3 weeks, solo, $0/month (local-only), risks = [sqlite schema migration story, full-text-search ranking quality, packaging story for non-cargo users], success = "100 cargo installs in first 60 days." Recap → accept → advance.

---

## Phase 3 — Domain & Data Model (Domain Modeler)

Entities: `Todo`, `Tag`, `TodoTag` (join). Relationships: many-to-many Todo↔Tag, optional one-to-many Todo→Subtask (cut for MVP). Aggregate invariant: completed todos cannot be re-tagged (TBD whether to enforce in code or DB). Ubiquitous language: "todo" (not "task"), "tag" (not "label"), "done" (not "complete"). Recap → accept → advance.

---

## Phase 4 — Security & Compliance (Security Engineer)

4.1.1: handles no PII (purely local user data). 4.1.2: no regulated domain. 4.2.1: auth model = none (single-user local tool). 4.2.2: single-tenant. 4.3.1: external attack surface = none (file-local only, no network). Recap → accept → advance.

---

## Phase 5 — Architecture (System Architect)

**Skill asks 5.1.1:** Shape → `CLI` (already implied by project_class; recapture for the architecture section explicitly).

**5.1.2:** Async boundaries → none (synchronous CLI).

**5.2.1:** Primary language → Rust.

**5.2.2:** Primary data store → `relational` (sqlite via `rusqlite`).

**5.2.3:** External APIs → none.

**5.3.1, 5.3.2 (optional):** scale = ~10k todos per user, latency = sub-100ms for `ls` and `search`.

After the last 5.x answer is persisted, skill authors the Phase 5 record and triggers the **Phase 5 critic moment** (per SPEC §12.1 row 1).

### Phase 5 critic invocation

1. Skill calls `sf_compose_detect_architect_critic` (filesystem probe per SPEC §12.2). On the user's machine the probe finds `~/.claude/plugins/cache/anthropic-marketplace/architect-critic/0.2.0/skills/critiquing-spec/SKILL.md` and prints `v0.2`.
2. Skill announces:
   > Phase 5 close — invoking `architect-critic:critiquing-spec` for `premise-audit` on the Phase 5 recap. Type `skip` if you want to bypass this fire.
3. User responds: (anything other than `skip`).
4. Skill writes a concrete recap artifact and invokes the critic:
   ```bash
   phase_artifact="$(sf project_data_dir)/phase-5-critic-recap.md"
   sf state_write_phase_artifact 5 "$phase_artifact"
   ```
   ```text
   Skill(architect-critic:critiquing-spec,
         target=master-spec-phase,
         phase_id=5,
         depth=premise-audit,
         artifact_path="$phase_artifact")
   ```
5. architect-critic runs its sequential-rebuttal loop internally (claude-only adversary at `premise-audit` depth per ac v0.2 settlement #6). Returns a structured summary block per ac SPEC §10:
   > Audit complete for master-spec-phase phase_id=5. 2 challenges stood:
   > - C-5.1: sqlite chosen but full-text-search ranking quality risk in Phase 2 implies you need FTS5 — confirm FTS5 not stock sqlite_fts3.
   > - C-5.2: no Async boundaries declared, but `search` over 10k rows at sub-100ms may require an in-memory index — confirm sync-only is feasible at target scale.
6. Skill presents both challenges as edit candidates:
   > Two architect-critic challenges stood. Want to edit the Phase 5 recap to address either?
7. User: address C-5.1 — change data store note to "sqlite with FTS5 extension enabled at build time."
8. Skill re-authors the Phase 5 record to capture the revision (updated `decisions` / `critic_outcomes`) and re-calls `sf state_write_phase_record 5 <temp-file>`, then surfaces the updated recap, asks accept | edit | append.
9. User: accept. `sf_state_advance_phase` → `current_phase` = 6.

### Representative state.answers snapshot after Phase 5 close

```json
{
  "schema_version": 2,
  "status": "in_progress",
  "current_phase": 6,
  "current_question": null,
  "project_class": "CLI tool",
  "project_root": "/Users/me/projects/todocli",
  "created_at": "2026-05-24T13:40:00Z",
  "updated_at": "2026-05-24T14:02:11Z",
  "answers": {
    "1.1.1": "A fast offline-first CLI for managing personal todos with tagging, due dates, and full-text search.",
    "1.1.2": "Developers who live in the terminal and want todo capture without leaving the shell.",
    "1.1.3": "TBD",
    "1.2.1": "Solo developer, terminal-resident.",
    "1.2.2": "Capture-then-find: add a todo in <2s, retrieve it later via search in <100ms.",
    "1.3.1": "CLI tool",
    "1.3.2": "todo add / ls / done / search over local sqlite.",
    "2.1.1": "3 weeks",
    "2.1.2": "Solo",
    "2.2.1": "0",
    "2.2.2": "Migration story; FTS ranking quality; non-cargo packaging.",
    "2.3.1": "100 cargo installs in 60 days.",
    "3.1.1": "Todo, Tag, TodoTag",
    "3.1.2": "Todo(id PK); Tag(id PK, name unique); TodoTag(todo_id, tag_id composite).",
    "3.2.1": "Todo<->Tag many-to-many via TodoTag.",
    "3.2.2": "Completed todos are immutable wrt tags.",
    "3.3.1": "todo, tag, done (not task/label/complete).",
    "4.1.1": "none",
    "4.1.2": "none",
    "4.2.1": "none",
    "4.2.2": "single-tenant",
    "4.3.1": "none (file-local)",
    "5.1.1": "CLI",
    "5.1.2": "none (synchronous)",
    "5.2.1": "Rust",
    "5.2.2": "sqlite with FTS5 extension enabled at build time",
    "5.2.3": "none",
    "5.3.1": "~10k todos/user",
    "5.3.2": "sub-100ms for ls and search"
  },
  "phase_records": {
    "5": {
      "decisions": "Rust + sqlite with FTS5; CLI surface; synchronous I/O.",
      "rationale": "Rust provides the sub-100ms performance budget; FTS5 gives ranked full-text search without a separate process.",
      "alternatives_rejected": "Go considered; rejected — sqlite FTS5 binding less mature. TypeScript/Node rejected — startup latency.",
      "constraints": "Must ship as a single static binary; no daemon.",
      "critic_outcomes": "C-5.1 (data store ambiguity) stood — changed answer to 'sqlite with FTS5 extension enabled at build time'.",
      "authored_at": "2026-05-24T14:02:11Z"
    }
  },
  "touched_this_run": ["5"]
}
```

Note `current_phase=6` — Phase 5 closed and the state advanced. The `5.2.2` answer reflects the post-critic edit (FTS5 explicit, not "relational" as originally answered).

---

## Phase 6 — UX / Surfaces (UX Designer)

Skill evaluates the `6A.*` subsections — gate is `project_class in {Web app, Mobile app, CLI tool, ML or AI system, Agent or plugin, Other}` and our project_class is `CLI tool`, so 6A passes. The `6B.*` subsections (gated on `Library or SDK / Data pipeline / Web service`) are skipped silently. Questions 6A.1.1 (surface: CLI), 6A.1.2 (first-value flow: `todo add "buy milk" #shopping`), 6A.2.1 (a11y: not in scope for CLI), 6A.2.2 (design system: TBD) answered. Recap → accept → advance.

---

## Phase 7 — Implementation Approach (Engineer)

7.1.1: decomposition → `core/` (domain types + invariants), `db/` (sqlite repository), `cli/` (clap-based parser), `bin/` (entry point). 7.1.2: statically typed (Rust). 7.2.x, 7.3.x, 7.4.x are gated on project classes we don't match; skipped.

Phase 7 close → **second critic moment** (Phase 7 close, premise-audit). Same invocation pattern as Phase 5: filesystem probe → `sf state_write_phase_artifact 7 "$phase_artifact"` → `Skill(architect-critic:critiquing-spec, target=master-spec-phase, phase_id=7, depth=premise-audit, artifact_path="$phase_artifact")` → present challenges → edit / accept → advance.

---

## Phases 8, 9, 10

- **8** (DevOps): local tooling = `cargo`, fresh-dev target = 60s, CI = GitHub Actions, environments = dev-only, hosting = N/A (binary distribution via crates.io + Homebrew tap).
- **9** (QA): coverage floor 80% for `core/` + `db/`, test types = unit + integration + property (for sqlite invariants), pre-merge gates = `cargo test && cargo clippy -- -D warnings && cargo fmt --check`. 9.3.1 = no (no LLM), so 9.3.2 is gated off.
- **10** (Operations): rollout = direct (single-version cargo publish), no feature flags, support = GitHub issues.

After Phase 10's last question is persisted, skill asks the **Karpathy opt-in** (per SPEC §14 / SKILL.md §7):

> Include behavioral discipline section in CLAUDE.md? This adds 4 cognitive principles (Karpathy-inspired) to your agent's behavior. (yes/no, default yes)

User: yes. `sf_state_write_answer phase_10.4.include_karpathy yes`.

---

## MASTER-SPEC close (critic moment 3)

At Phase 10 close, the skill first synthesizes `MASTER-SPEC.md` from phase records + answers (see SKILL.md §8; there is no per-phase render step), then triggers the **MASTER-SPEC close critic** against that freshly authored artifact:

1. Produce `MASTER-SPEC.md` through the MASTER-SPEC synthesis prompt (sub-agent when available, inline host synthesis otherwise).
2. Validate the synthesized spec with `sf spec_validate "$master"`; if validation fails, stop and preserve state for `/onboard --resume`.
3. Filesystem probe → `v0.2`.
4. Invocation:
   ```text
   Skill(architect-critic:critiquing-spec,
         target=master-spec-full,
         depth=close,
         artifact_path="$master")
   ```
5. At `depth=close`, ac v0.2 adversaries are `[claude, codex]` (per ac settlement #6). Codex spawn happens inside architect-critic; scaffold-onboard does not manage it.
6. architect-critic returns the close-depth summary. Any standing challenges are surfaced as final edit candidates for the synthesized MASTER-SPEC.
7. User accepts or applies edits to `MASTER-SPEC.md`; if edits touch parser anchors or project class fields, the skill re-runs `sf spec_validate "$master"` before continuing.

EXECUTIVE-SUMMARY.md is produced at onboarding close — synthesized from MASTER-SPEC by default (the `EXECUTIVE-SUMMARY.brief.md` synthesis-agent), or deterministically via `sf_render_executive_summary` under `--fast`. Paths are resolved through `sf_resolve_output_path`:

```bash
master_spec_path="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
exec_summary_path="$(sf_resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"
```

For a single-repo todo-cli with no workspace-init manifest: both resolve to `$(pwd)/MASTER-SPEC.md` and `$(pwd)/EXECUTIVE-SUMMARY.md`.

---

## Close summary (SKILL.md §8)

Skill emits:

```text
MASTER-SPEC.md authored at /Users/<you>/work/todo-cli/MASTER-SPEC.md.
EXECUTIVE-SUMMARY.md authored at /Users/<you>/work/todo-cli/EXECUTIVE-SUMMARY.md.

Onboarding complete (Phase 10 / 10).

Next step:
  Run /plan-roadmap to decompose MASTER-SPEC into Phase → Sprint → Vertical Slice
  hierarchy (ROADMAP.md). This is the R1 input contract for scaffold-dev v0.1's
  orchestrator-implementer cycle.

You can also run:
  /scaffold-project  → derive memory bank + CLAUDE.md + .claude/settings.json from MASTER-SPEC
  /scaffold-docs     → derive PRD / SRS / BACKLOG / PROJECT_PLAN / ADR-0001 from MASTER-SPEC
```

Final state JSON: `status=complete`, `current_phase=10`, all 30+ answers populated, lock released.

---

## What this walkthrough demonstrates

- Question vocabulary is sourced from phases.yaml verbatim, not improvised.
- State persists *after every answer* — an interrupt at Phase 5 question 3 leaves Phases 1-4 + the first 2 questions of Phase 5 safely on disk.
- Gates (`6A.*` vs `6B.*`, `7.2/7.3/7.4`, `9.3`) silently skip non-matching subsections; the CLI walk never sees a backend-frontend-library question.
- Critic moments at Phase 5 / 7 / MASTER-SPEC close are *suggestions* the user can `skip`; absence of architect-critic warns-and-skips.
- Routing through `sf_resolve_output_path` works for both single-repo (manifest absent → cwd) and manifest-mode (resolved via `.workspace/pairing.json`).
- The Karpathy opt-in is *captured* here but emitted later by `scaffolding-memory-bank` when CLAUDE.md is derived.
