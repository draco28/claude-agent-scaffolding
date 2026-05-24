# SPEC: scaffold-onboard v0.2 (skill-first retrofit)

**Status:** DRAFT — pending architect-critic + user lock-in
**Predecessor:** scaffold-onboard v0.1.0 SHIPPED 2026-05-14 (163 tests, 7 suites)
**Driven by:** [HANDOFF-scaffold-onboard-v02-spec.md](HANDOFF-scaffold-onboard-v02-spec.md) (348-line seed) + critique findings
**Companion:** [PLAN-scaffold-onboard-v02.md](PLAN-scaffold-onboard-v02.md)

---

## 1. TL;DR

scaffold-onboard v0.2 retrofits the v0.1.0 shipping plugin to a **skill-first composition** that:

1. Restructures three slash commands into **seven skills + four slash command handles** (per Pass D skill-first principle).
2. Adds **manifest-aware output routing** when workspace-init's pairing.json is present; falls back to single-repo mode otherwise.
3. Produces the **R1/R2/R3 input contract** that scaffold-dev v0.1 consumes:
   - **R1** — `ROADMAP.md` with Phase → Sprint → Vertical-Slice hierarchy *(renamed from PROJECT_PLAN.md to avoid collision with v0.1.0's `/scaffold-docs` output; see §13.5)*
   - **R2** — machine-checkable rules in `03-code-patterns.md` (HTML-sentinel `mcrule` DSL)
   - **R3** — `auto:`/`user:` demo criteria per vertical slice
4. Replaces architect-critic file-IPC with **in-conversation skill invocation** (target: `architect-critic:critiquing-spec` when ac v0.2 ships; fallback: `architect-critic:critique` from ac v0.1.3 — see §12.4).
5. Preserves v0.1.0 behavior in single-repo mode — **148 of 163 v0.1.0 tests still pass byte-identical**; the 15 dropped tests are IPC-specific (functions removed). New v0.2 suite ~257 tests total.

Target ship: v0.2.0 with ~250-275 tests across ~12 suites; 3-4.5 weeks focused work.

---

## 2. Motivation

Three forces drive this retrofit:

**2.1 Skill-first principle (Pass D, settled 2026-05-17).** v0.1.0 is CLI-tool-shaped: three slash commands as the primary surface, bash mechanically derives outputs from MASTER-SPEC. Skill-first inverts this — every capability is a description-matched skill; logic lives in markdown bodies Claude reads + acts on; bash is reserved for bookkeeping (state writes, atomic file ops, jq transforms).

**2.2 Dual-repo workspace topology (workspace-init v0.1).** When the user has run workspace-init, a pairing.json manifest at `<ai-workspace>/.workspace/pairing.json` declares routing rules per file class. scaffold-onboard must consume this manifest and route its outputs accordingly.

**2.3 scaffold-dev v0.1 input contract (R1/R2/R3).** scaffold-dev v0.1 cannot start its orchestrator-implementer cycle without specific outputs from scaffold-onboard: a hierarchy to orient on, machine-checkable rules for verification, and demo criteria for slice-close ceremony.

Without v0.2, scaffold-dev v0.1 cannot ship.

---

## 3. Non-goals

v0.2 will NOT do any of the following:

1. **MCP integration for memory bank** — plain markdown only; tiered loading via SessionStart hook (Tier 0) + branch routing in CLAUDE.md (Tier 1).
2. **Multi-project workspaces** — one /onboard per workspace; multi-project deferred to v0.4+.
3. **Memory-bank file-count change** — stays at 11 files (00-08 + index + WORKFLOW).
4. **User-global rules registry** — project-scoped rules only in v0.2; cross-project rule libraries defer to v0.3+.
5. **Auto-derived rules from existing code** — R2 rules are manually authored. LLM-extractive rule discovery defers to v0.3+.
6. **Rule violation auto-fixing** — R2 detects; scaffold-dev surfaces; user fixes.
7. **Auto-decomposing MASTER-SPEC into Phase→Sprint→VS** — `planning-project-roadmap` is interactive, not LLM-extractive. User authors hierarchy with skill guidance; skill doesn't try to infer from MASTER-SPEC text.
8. **Cross-repo project plans** — one PROJECT_PLAN.md per project.
9. **Demo-criteria auto-execution from scaffold-onboard** — execution is scaffold-dev's `closing-vertical-slice` skill's job. scaffold-onboard authors criteria; doesn't run them.
10. **Migration tooling beyond a manual MIGRATION.md** — no `/onboard --migrate-from-v01` wizard. Manual doc.

---

## 4. Architecture overview

### 4.1 Plugin manifest (`.claude-plugin/plugin.json`)

```json
{
  "name": "scaffold-onboard",
  "version": "0.2.0",
  "category": "workflow",
  "description": "Project onboarding via skill-first composition. Authors MASTER-SPEC + project roadmap (Phase → Sprint → Vertical Slice) + machine-checkable rules + demo criteria. Composes with workspace-init (manifest routing), ai-mentor (cognitive mode), architect-critic (in-conversation review), superpowers (workflow).",
  "principles_export": "principles/scaffold-onboard.md",
  "composition": {
    "consumes": ["workspace-init.manifest"],
    "invokes": ["architect-critic:critiquing-spec", "ai-mentor:grill-me"],
    "produces": ["MASTER-SPEC.md", "EXECUTIVE-SUMMARY.md", "memory-bank/*", "CLAUDE.md", "governance-docs/*", "PROJECT_PLAN.md"]
  }
}
```

### 4.2 Directory layout

```
scaffold-onboard/
├── .claude-plugin/plugin.json
├── skills/                    (NEW — 7 SKILL.md bodies)
│   ├── onboarding-project/SKILL.md
│   ├── scaffolding-memory-bank/SKILL.md
│   ├── scaffolding-governance-docs/SKILL.md
│   ├── planning-project-roadmap/SKILL.md             (NEW capability)
│   ├── authoring-machine-checkable-rules/SKILL.md    (NEW capability)
│   ├── authoring-vertical-slice-demo/SKILL.md        (NEW capability)
│   └── validating-master-spec/SKILL.md
├── commands/                  (4 slash command thin wrappers)
│   ├── onboard.md
│   ├── scaffold-project.md
│   ├── scaffold-docs.md
│   └── plan-roadmap.md        (NEW)
├── hooks/hooks.json
├── hooks-handlers/session-start.sh  (extended — marker-aware Tier 0 protocol)
├── lib/
│   ├── _helpers.sh            (unchanged)
│   ├── state.sh               (extended — roadmap state)
│   ├── parser.sh              (unchanged — MASTER-SPEC parser survives)
│   ├── render.sh              (extended — R1 hierarchy templates)
│   ├── memory-bank.sh         (extended — manifest routing + R2 rules section)
│   ├── docs.sh                (extended — manifest routing)
│   ├── compose.sh             (REWRITE — IPC removed, probe retained)
│   ├── routing.sh             (NEW — sf_resolve_output_path manifest helper)
│   ├── roadmap.sh             (NEW — R1 hierarchy renderer + parser)
│   ├── rules.sh               (NEW — R2 mcrule DSL parser)
│   └── demo-criteria.sh       (NEW — R3 auto:/user: parser)
├── templates/                 (extended)
│   ├── master-spec/          (unchanged)
│   ├── memory-bank/          (03-code-patterns.md gains rules section)
│   ├── governance/           (unchanged)
│   └── project-plan/          (NEW — PROJECT_PLAN.md template + VS block)
└── tests/
    ├── test-compose.sh        (REWRITTEN — probe tests retained, IPC tests dropped)
    ├── test-docs.sh           (extended)
    ├── test-e2e.sh            (extended)
    ├── test-memory-bank.sh    (extended)
    ├── test-parser.sh         (unchanged)
    ├── test-render.sh         (extended)
    ├── test-state.sh          (extended)
    ├── test-roadmap.sh        (NEW)
    ├── test-rules.sh          (NEW)
    ├── test-demo-criteria.sh  (NEW)
    ├── test-manifest-routing.sh (NEW)
    └── test-hook-marker.sh    (NEW)
```

### 4.3 Skill-first principle as applied (honest framing)

Per Pass D principle (P1/P2/P3) — with v0.2 as **structural skill-first**, not full re-architecture:

- **P1 — every capability is a skill** (discoverable via description match). Slash commands are thin handles.
- **P2 — skill bodies orchestrate; bash modules execute.** Skills decide flow + dialogue + composition; lib/*.sh modules handle file I/O, jq transforms, atomic mv, parsing. This is a deliberate v0.2 compromise: the v0.1.0 bash engine is mature (163 tests) and rewriting all logic into SKILL.md bodies would multiply scope. v0.3+ may push more logic into skill bodies (e.g., embed the 10-phase conversation directly in `onboarding-project` SKILL.md, eliminating phases.yaml as a data file).
- **P3 — three layers**:
  - **Hooks** (ambient): SessionStart for composition refresh + Tier 0 emission.
  - **Skills** (auto-invocable): 7 capabilities discoverable via description matching; bodies drive conversation + invoke architect-critic + select bash helpers.
  - **Slash commands** (explicit handles): 4 commands for users who want explicit invocation.

**Why not full skill-first in v0.2:** the 10-phase conversation has 54 runtime questions across phases.yaml; encoding that in markdown bodies inflates SKILL.md beyond the ≤500-line guidance. Phasing the transition lets v0.2 ship the contract scaffold-dev needs (R1/R2/R3) without a multi-month engine rewrite.

---

## 5. Skill catalog

Each skill ≤500 lines body (per Pass D guidance). Skill names are namespaced as `scaffold-onboard:<skill-name>` per cross-plugin convention.

### 5.1 `scaffold-onboard:onboarding-project`

**Description:** Drives 10-phase guided conversation authoring MASTER-SPEC.md + EXECUTIVE-SUMMARY.md as project source of truth.

**Triggers on:** "start onboarding", "begin project setup", "/onboard", "kick off a new project", project-creation phrases.

**Body responsibilities:**
- Open onboarding-state.json (or create if absent)
- Walk 10 phases per phases.yaml (existing v0.1.0 schema; preserved)
- Per phase: ask questions, write answers via `sf_state_write_answer`
- At Phase 5 close + Phase 7 close + MASTER-SPEC close: invoke architect-critic (per §12)
- Final: render MASTER-SPEC.md + EXECUTIVE-SUMMARY.md via `sf_render_master_spec_init` + `sf_render_executive_summary`
- Route outputs per manifest (per §10) or single-repo cwd if manifest absent
- Suggest next step at Phase 10 close: "Run `/plan-roadmap` next to decompose into sprints + vertical slices"

**Bash bookkeeping:** state CRUD via lib/state.sh; rendering via lib/render.sh; composition probe via lib/compose.sh.

### 5.2 `scaffold-onboard:scaffolding-memory-bank`

**Description:** Deterministically derives 11-file memory bank + CLAUDE.md + .claude/settings.json from MASTER-SPEC.md.

**Triggers on:** "scaffold the memory bank", "derive memory bank", "/scaffold-project", "set up project memory".

**Body responsibilities:**
- Validate MASTER-SPEC.md via `sf_spec_validate` (lib/parser.sh — unchanged)
- Derive 8 files from MASTER-SPEC + 2 live-seed (preserve on re-derive) + 1 static (copy-once)
- 03-code-patterns.md now includes `## Machine-checkable rules` section seeded with comments inviting user to author rules (or via skill 5.5)
- Route outputs per manifest (per §10)
- Compose with ai-mentor v2.0 (suggest `ai-mentor:grill-me` at Phase 5 / Phase 7 echo when decisions feel under-stress-tested) + superpowers detection per scaffold-onboard's composition.json; architect-critic detection via filesystem probe (per §12.2)

### 5.3 `scaffold-onboard:scaffolding-governance-docs`

**Description:** Derives 5 default + 9 with `--full` governance docs (PRD, SRS, BACKLOG, PROJECT_PLAN, ADR-0001 + optional RISK_REGISTER, TEST_STRATEGY, CUTOVER_PLAN, EVALS_PLAN, etc.) from MASTER-SPEC.md.

**Triggers on:** "scaffold governance docs", "generate PRD/SRS", "/scaffold-docs".

**No filename change for backcompat:** v0.2 keeps `/scaffold-docs`'s `PROJECT_PLAN.md` output unchanged (Phase-2-Strategy-derived timeline). The R1 hierarchy doc (per §7.1) is named `ROADMAP.md`, not `PROJECT_PLAN.md`. This avoids any v0.1.0 user file collision. scaffold-dev's contract (§16.2) is updated to consume `ROADMAP.md` for orientation; coordinated with scaffold-dev SPEC author.

### 5.4 `scaffold-onboard:planning-project-roadmap` (NEW)

**Description:** Interactive authoring of Phase → Sprint → Vertical Slice hierarchy into ROADMAP.md. Each vertical slice gets demo criteria skeleton (auto:/user:).

**Triggers on:** "/plan-roadmap", "decompose into sprints", "author project roadmap", "build out the phase plan", "what comes after onboarding?".

**Body responsibilities:**
- Open project-roadmap.json (new state file at `${CLAUDE_PLUGIN_DATA}/project-roadmap.json`)
- Read MASTER-SPEC.md (must exist; error if not)
- Walk three sub-phases per B2 checkpoints:
  - **R1.A — Phases** (~10-20 min): 3-6 high-level milestones. Frame via "3-timelines" prompt (per HANDOFF §3.5): "Your Phases are your visionary horizon — what's the project's 5-year shape?"
  - **R1.B — Sprints per phase** (~30-50 min): 2-4 sprints per phase. Frame: "Sprints are your value-building windows — what gets built over 12-18 months that compounds?"
  - **R1.C — Vertical slices per sprint** (~40-60 min): 2-5 slices per sprint, each demoable end-to-end. Frame: "Vertical slices are your visibility cycles — what ships demoably in 90-day-ish windows?" For each slice: ask for 1-3 demo criteria skeleton via `authoring-vertical-slice-demo` skill.
- After each sub-phase: write state checkpoint; offer "save progress and resume later?"
- After R1.C complete: invoke critic skill (per §12.4) with target=roadmap, depth=close
- Emit final ROADMAP.md at routing destination (canonical per manifest, or cwd if single-repo)
- **Re-run protocol** (per §7.5): if ROADMAP.md exists, skill reads existing state + offers incremental modes (add phase / add sprint / add slice / refine slice) before falling back to full re-author

**Hard time-budget:** ≤90 min total across R1.A + R1.B + R1.C. Skill watches elapsed time via state-file timestamps; at 60 min, offers "checkpoint and continue tomorrow?"

### 5.5 `scaffold-onboard:authoring-machine-checkable-rules` (NEW)

**Description:** Interactively authors machine-checkable rules into `03-code-patterns.md` per R2 mcrule DSL. Supports four rule types: banned_imports, coverage_floor, style_invariants, required_pattern.

**Triggers on:** "add a project rule", "author machine-checkable rules", "what rules should this project enforce?", post-onboarding rule-evolution phrases.

**Body responsibilities:**
- Detect if `03-code-patterns.md`'s `## Machine-checkable rules` section exists; if not, append it
- Walk user through rule authoring via question-driven prompts
- Generate fenced `mcrule` block per R2 DSL (per §8)
- Validate the generated block via `lib/rules.sh:sf_rules_parse` (round-trips through parser)
- Append to `## Machine-checkable rules` section

### 5.6 `scaffold-onboard:authoring-vertical-slice-demo` (NEW)

**Description:** Authors `auto:`/`user:` demo criteria for a named vertical slice in PROJECT_PLAN.md. Invoked by `planning-project-roadmap` during R1.C, and by scaffold-dev's orchestrator at slice planning (top-up authoring).

**Triggers on:** "author demo criteria for slice X", "what should this slice demo?", "set up demo verification for VS-N.M".

**Body responsibilities:**
- Locate the named slice block in PROJECT_PLAN.md
- Read existing demo criteria (if any) to avoid duplication
- Prompt for 1-3 demo lines: each is `auto: <cmd> → expected: <code|pattern>` OR `user: <action> → expected: <outcome>`
- Validate format via `lib/demo-criteria.sh:sf_demo_parse_line`
- Write to slice block; idempotent — repeated invocations top-up, don't duplicate

### 5.7 `scaffold-onboard:validating-master-spec`

**Description:** Validates MASTER-SPEC.md against schema rules before any derivation runs. Surfaces validation errors with line numbers + remediation hints.

**Triggers on:** "validate MASTER-SPEC", "check the spec", "is my master spec ready for derivation?".

**Body responsibilities:**
- Run `sf_spec_validate` from lib/parser.sh (unchanged — 7 validation rules + 9 project-class enums)
- If errors: surface with line numbers + suggested fixes
- If clean: confirm "MASTER-SPEC valid. Ready for `/scaffold-project` and `/scaffold-docs`."

---

## 6. Slash command surface

Four commands; each thin wrapper that invokes the corresponding skill via `$ARGUMENTS` env-var bridge (per `feedback_slash_command_dollar_n_bug`).

| Command | Invokes | Args |
|---|---|---|
| `/onboard` | `scaffold-onboard:onboarding-project` | optional: `--resume`, `--regenerate` |
| `/scaffold-project` | `scaffold-onboard:scaffolding-memory-bank` | optional: `--regenerate` |
| `/scaffold-docs` | `scaffold-onboard:scaffolding-governance-docs` | optional: `--full`, `--regenerate` |
| `/plan-roadmap` (NEW) | `scaffold-onboard:planning-project-roadmap` | optional: `--resume`, `--phase-only`, `--sprint-only` |

Other skills (`authoring-machine-checkable-rules`, `authoring-vertical-slice-demo`, `validating-master-spec`) are skill-only; no slash handles. They're invoked from other skills or via description-match.

---

## 7. R1: Phase → Sprint → Vertical Slice hierarchy

### 7.1 ROADMAP.md data shape

```markdown
# ROADMAP — <project name>

> Derived from MASTER-SPEC.md by `/plan-roadmap` on YYYY-MM-DD.
> Co-edited by user + scaffold-dev orchestrator over time.

## Roadmap overview

<3-paragraph summary of project shape, with 3-timelines framing>

## Phase 1: <name> — <horizon estimate>

<1-2 paragraph phase summary>

### Sprint 1.1: <name>

<sprint goal — 2-3 sentences>

#### VS-1.1.1: <vertical slice name>

<what gets demoed at slice close — 1-2 sentences>

##### Demo criteria

- [ ] auto: `<command>` → expected: <exit code 0 | pattern>
- [ ] user: <action> → expected: <observable outcome>

#### VS-1.1.2: <vertical slice name>
...

### Sprint 1.2: <name>
...

## Phase 2: <name>
...
```

Vertical slice IDs follow `VS-<phase>.<sprint>.<slice>` (e.g., VS-2.3.1 = phase 2, sprint 3, slice 1). This convention matches scaffold-dev's `docs/specs/sprint-N/VS-N.M-<kebab>/` path schema (per scaffold-dev SPEC §5.2).

### 7.2 Authoring flow (`planning-project-roadmap` skill)

Three sub-phases R1.A/B/C as described in §5.4. Each sub-phase writes a checkpoint to `project-roadmap.json`:

```json
{
  "schema_version": "1",
  "started_at": "2026-05-22T...",
  "checkpoint": "R1.B",
  "elapsed_min": 38,
  "phases": [
    {"id": 1, "name": "Foundation", "horizon": "Q3 2026", "summary": "..."},
    {"id": 2, "name": "Launch", "horizon": "Q4 2026", "summary": "..."}
  ],
  "sprints": [
    {"phase_id": 1, "id": "1.1", "name": "...", "goal": "...", "vs_count_estimate": 3},
    ...
  ],
  "vertical_slices": [
    {"sprint_id": "1.1", "id": "VS-1.1.1", "name": "...", "summary": "...", "demo_criteria": ["auto: ...", "user: ..."]},
    ...
  ]
}
```

### 7.3 User-time budget + checkpoints (per B2)

- **Default budget:** ≤90 min for projects with ≤50 hierarchy nodes (typical: 4 phases × 3 sprints × 4 slices)
- **Size-class adaptation (NEW per C5):** at R1.A close, skill counts estimated hierarchy nodes. If estimate >50, skill surfaces one of three paths:
  1. **Continue** (user accepts >90 min budget; explicit acknowledgment recorded)
  2. **Split into product epics** (skill suggests breaking project into 2-3 epics; each runs separate `/plan-roadmap` with its own MASTER-SPEC slice; recommended for >100-node estimates)
  3. **Reduce scope** (push later sprints to v-next; only the first 2-3 phases get sprint+slice decomposition; later phases stay at sprint-level placeholders)
- **Checkpoint 1:** After R1.A (phases defined). Skill offers: "Phases captured. Continue to sprints, or pause here and resume with `/plan-roadmap --resume`?"
- **Checkpoint 2:** After R1.B for each phase (sprints defined for that phase).
- **Checkpoint 3:** After R1.C for each sprint (slices defined for that sprint).

At 60-min elapsed (from started_at): skill proactively offers checkpoint.

### 7.4 State file schema

`${CLAUDE_PLUGIN_DATA}/project-roadmap.json` (separate from `onboarding-state.json` to keep concerns separate). Schema in §7.2 above. Resume via `/plan-roadmap --resume` reads checkpoint field and re-enters at next sub-phase.

### 7.5 Re-run protocol (NEW per C6)

After initial authoring, ROADMAP.md exists. Re-running `/plan-roadmap` should not restart R1.A/B/C from scratch. Instead:

**Detection:** Skill checks for ROADMAP.md at routing destination + project-roadmap.json state file. If both exist with `checkpoint == "R1.C-complete"`: enter re-run mode.

**Re-run modes (skill prompts user to choose):**

| Mode | What it does | Use case |
|---|---|---|
| `--add-phase` | Walks R1.A for one new phase only; offers R1.B + R1.C for that phase | "Project scope grew — added Phase 5" |
| `--add-sprint <phase_id>` | Walks R1.B for one new sprint in named phase; offers R1.C for it | "Phase 2 needs another sprint between 2.2 and 2.3" |
| `--add-slice <sprint_id>` | Walks R1.C for one new slice in named sprint | "VS-1.1.3 emerged from VS-1.1.2 closing" |
| `--refine-slice <slice_id>` | Walks R1.C for one existing slice (rewrite name/summary; demo criteria via skill 5.6) | "VS-2.1.1 needs better demo criteria after Phase 1 closed" |
| `--reorganize` | Full re-walk; preserves existing items; user accepts/edits each | "Major project pivot; restructure" (defers most details to OQ4 v0.3+) |

**Default behavior** (no mode flag, ROADMAP.md exists): skill asks user which mode. Hard-fails on ambiguous re-author intent.

State file `project-roadmap.json` gains a `mutations` array tracking each non-initial add/refine for audit trail.

---

## 8. R2: Machine-checkable rules DSL

### 8.1 Storage

Rules live in `.claude/memory-bank/03-code-patterns.md` under a `## Machine-checkable rules` section. Each rule is delimited by **HTML sentinel comments** (visible to bash grep + invisible to rendered markdown + readable by Claude as semantic boundaries). Human-readable prose surrounds rule blocks for context.

This form satisfies:
- Markdown-native (no new file format)
- Human-authorable (prose context surrounds each rule)
- Machine-parseable (HTML comments are unambiguous to bash AND to Claude — fenced-block nesting was a v0.2 draft alternative rejected because Claude reads rendered markdown where fence boundaries are invisible)
- Coexists with non-machine-checkable patterns elsewhere in the file

### 8.2 Grammar (HTML-sentinel `mcrule` blocks)

```markdown
## Machine-checkable rules

We forbid synchronous HTTP libraries in async code paths because they block the event loop.

<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3, httpx.Client]
<!-- mcrule:end -->

API layer must maintain 80%+ test coverage.

<!-- mcrule:start type=coverage_floor -->
paths: [src/api/]
threshold: 80
<!-- mcrule:end -->

Never use `print()` outside test files.

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
exclude: tests/**/*.py
forbid_pattern: '\bprint\('
<!-- mcrule:end -->

All API handlers must have a docstring with `Args:` and `Returns:` sections.

<!-- mcrule:start type=required_pattern -->
in: src/api/handlers/*.py
require_pattern: 'Args:\s+.*\s+Returns:'
where: function_def
<!-- mcrule:end -->
```

Parser extracts content between `<!-- mcrule:start type=<T> -->` and `<!-- mcrule:end -->`. The `type=` attribute is on the start sentinel; body is YAML-like key:value pairs. Comments survive markdown rendering (they're literally HTML comments).

### 8.3 Rule types (v0.2 minimum viable set)

| Type | Required fields | Optional fields | Semantics |
|---|---|---|---|
| `banned_imports` | `forbid: [list]` | `in: glob`, `where: condition` | Diff must not introduce listed imports |
| `coverage_floor` | `paths: [list]`, `threshold: N` | — | Test coverage on listed paths ≥ N% |
| `style_invariants` | `forbid_pattern: regex` | `in: glob`, `exclude: glob`, `where: condition` | Diff lines must not match pattern |
| `required_pattern` | `require_pattern: regex` | `in: glob`, `exclude: glob`, `where: condition` | Specified files must contain match |

`where:` values (extensible): `any_function_marked_async`, `function_def`, `class_def`, `module_top_level`. Unknown values → warn + skip per extensibility (§8.5).

### 8.4 Parser API (`lib/rules.sh`)

```bash
# Parse 03-code-patterns.md and emit rules as JSON array.
sf_rules_parse <path_to_patterns_md>
# → emits JSON array of {type, fields...} objects

# Validate a single mcrule block body.
sf_rules_validate_block <block_body_text>
# → exit 0 if valid; exit 1 + stderr message if not

# Get all rules of a given type.
sf_rules_filter <rules_json> <type>
# → emits filtered JSON array
```

### 8.5 Extensibility

Each rule has `type:`. Parsers that encounter unknown types (forward-compat for v0.3+ rule types like `dependency_age` or `complexity_ceiling`) **warn and skip** — do not crash. This lets future scaffold-onboard versions add types without breaking older scaffold-dev consumers.

scaffold-dev's `implementation-checking` skill consumes the parser output. If rules absent or empty: scaffold-dev falls back to AC-only verification (per scaffold-dev SPEC §12.1 + Q2 settlement).

---

## 9. R3: Demo criteria with `auto:`/`user:` grammar

### 9.1 Grammar

Per scaffold-dev SPEC §14.1 (verbatim):

```markdown
##### Demo criteria

- [ ] auto: <bash command> → expected: <exit code 0 | pattern in output>
- [ ] user: <action description> → expected: <observable outcome>
```

Examples:
```
- [ ] auto: `pytest tests/integration/test_insight_pipeline.py` → expected: exit 0
- [ ] auto: `curl -s localhost:8000/api/insights | jq '.[]'` → expected: output contains "action_needed"
- [ ] user: Navigate to localhost:3000/insights → expected: action-needed card visible with real data
- [ ] user: Click chatbot icon → expected: chat panel opens within 5s
```

### 9.2 Authoring source (hybrid per I2)

- **Initial authoring:** during `/plan-roadmap` R1.C, `planning-project-roadmap` skill invokes `authoring-vertical-slice-demo` per slice to seed 1-3 demo lines (skeleton form).
- **Refinement:** scaffold-dev's orchestrator may invoke `authoring-vertical-slice-demo` again at slice planning (when more context is known) to top-up or refine.
- **Idempotence:** repeated invocations update the same slice's demo block; don't duplicate existing criteria (matched by text equality).

This balance avoids:
- (a) requiring full criteria up-front when user lacks slice-implementation context
- (b) leaving slices criteria-empty for scaffold-dev to author from scratch

### 9.3 Parser API (`lib/demo-criteria.sh`)

```bash
# Parse PROJECT_PLAN.md and emit demo criteria for a named slice.
sf_demo_parse_slice <project_plan_md> <slice_id>
# → emits JSON array of {prefix, body, expected} objects

# Validate a single criterion line (used by authoring skill before write).
sf_demo_parse_line <line_text>
# → exit 0 + emits parsed JSON; exit 1 if grammar violation

# Append a criterion to a named slice; idempotent.
sf_demo_append <project_plan_md> <slice_id> <criterion_line>
```

---

## 10. Manifest-aware output routing

### 10.1 Routing table

Per workspace-init manifest schema (cross-checked against §6 — all 15 keys present in workspace-init's manifest as-shipped):

| Logical name | Routes to | Produced by |
|---|---|---|
| `master_spec` | ai_workspace | `/onboard` |
| `executive_summary` | canonical | `/onboard` |
| `memory_bank` | ai_workspace | `/scaffold-project` |
| `claude_md` | ai_workspace | `/scaffold-project` |
| `agents_md` | ai_workspace | `/scaffold-project` |
| `scaffold_project_outputs` | ai_workspace | `/scaffold-project` (other) |
| `backlog` | canonical | `/scaffold-docs` |
| `project_plan` | canonical | `/scaffold-docs` (v0.1.0's Phase-2-derived PROJECT_PLAN.md — unchanged) |
| `roadmap` | canonical | `/plan-roadmap` (R1 hierarchy doc — NEW; workspace-init manifest schema extension required, see §10.4) |
| `prd` | canonical | `/scaffold-docs` |
| `srs` | canonical | `/scaffold-docs` |
| `product_adrs` | canonical | `/scaffold-docs` |
| `process_adrs` | ai_workspace | `/scaffold-docs` |
| `sprint_specs` | ai_workspace | (scaffold-dev) |
| `implementation_handoffs` | ai_workspace | (scaffold-dev) |
| `brainstorm_artifacts` | ai_workspace | (scaffold-dev or brainstorm sessions) |

Note: scaffold-onboard authors 8 of these 15 (others written by scaffold-dev or brainstorm sessions).

### 10.2 `sf_resolve_output_path` helper (lib/routing.sh)

```bash
# Resolve a logical output name to an absolute filesystem path.
#
# Arguments:
#   $1 — logical name (e.g., "master_spec", "memory_bank")
#   $2 — relative path within that destination (e.g., "MASTER-SPEC.md", "03-code-patterns.md")
#
# Behavior:
#   - If manifest present at <discovered>/.workspace/pairing.json:
#     Look up routing.<logical_name>, expand ${ai_workspace.root} or ${canonical.root}
#     via workspace-init's mi_manifest_resolve, return absolute path
#   - If manifest absent: return ${cwd}/$2 (single-repo fallback)
#
sf_resolve_output_path() {
  local logical_name="$1"
  local rel_path="$2"
  local manifest=$(sf_discover_manifest)
  if [[ -z "$manifest" ]]; then
    echo "$(pwd)/$rel_path"
    return 0
  fi
  local destination=$(jq -r ".routing[\"$logical_name\"]" "$manifest")
  if [[ "$destination" == "null" ]]; then
    sf_log_warn "logical name '$logical_name' not in manifest.routing; falling back to cwd"
    echo "$(pwd)/$rel_path"
    return 0
  fi
  local root_var="${destination}.root"   # e.g., "ai_workspace.root"
  local root=$(mi_manifest_resolve "$manifest" "$root_var")
  echo "${root}/${rel_path}"
}

# Discover manifest by walking up from cwd looking for .workspace/pairing.json
sf_discover_manifest() {
  local dir="$(pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.workspace/pairing.json" ]]; then
      echo "$dir/.workspace/pairing.json"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  return 1
}
```

`mi_manifest_resolve` is workspace-init's shared helper (per workspace-init SPEC §6.3). scaffold-onboard sources it via `${CLAUDE_PLUGIN_ROOT}/../workspace-init/lib/manifest.sh` if workspace-init is installed; falls back to a local minimal resolver if not (for tests/development).

### 10.3 Single-repo fallback

When `sf_discover_manifest` returns empty: scaffold-onboard routes outputs to `$(pwd)/<rel_path>` — exactly the v0.1.0 behavior. All v0.1.0 tests exercise this path; they continue to pass.

### 10.4 Workspace-init manifest schema extension (NEW)

The `roadmap` logical name is NEW in v0.2 — it doesn't exist in workspace-init v0.1's manifest schema as-shipped. scaffold-onboard v0.2 requires workspace-init to add `routing.roadmap` to its manifest schema (default value: `"canonical"`).

**Coordination:** filed as workspace-init issue / cross-plugin handoff. workspace-init v0.1.1 (point release) adds the key with default `"canonical"`. scaffold-onboard v0.2's `sf_resolve_output_path` gracefully handles missing key: if manifest lacks `routing.roadmap`, defaults to canonical destination. Forward-compatible with older workspace-init manifests.

---

## 11. SessionStart hook + Tier 0 marker protocol

Per B4 + scaffold-dev SPEC §15.1: scaffold-onboard's SessionStart hook must coordinate with scaffold-dev's hook to avoid Tier 0 token duplication.

### 11.1 Marker location

`${TMPDIR:-/tmp}/claude-code-tier0-${CLAUDE_SESSION_ID:-default}` (shared session-scoped path; both plugins can read/write without cross-plugin data-dir permissions).

Marker content: a single line `<plugin_name>` (the plugin that emitted Tier 0 first).

### 11.2 Hook logic

```bash
# hooks-handlers/session-start.sh (v0.2 extension)
TIER0_MARKER="${TMPDIR:-/tmp}/claude-code-tier0-${CLAUDE_SESSION_ID:-default}"

if [[ -f "$TIER0_MARKER" ]]; then
  emitting_plugin=$(cat "$TIER0_MARKER")
  if [[ "$emitting_plugin" != "scaffold-onboard" ]]; then
    # Another plugin already emitted Tier 0; we add only the onboarding-aware hint
    sf_session_emit_minimal_hint
    exit 0
  fi
fi

# We're first (or solo); emit full Tier 0 and write marker
sf_session_emit_full_tier0
echo "scaffold-onboard" > "$TIER0_MARKER"
```

scaffold-dev's hook does the symmetric logic. Race condition: if both hooks check the marker before either writes, both will emit Tier 0. This is acceptable for v0.2 — the race window is microseconds and only matters at session start; net cost is one extra Tier 0 emission, not catastrophic.

### 11.3 Single-plugin operation

If only scaffold-onboard is installed (no scaffold-dev): marker writes happen but no other plugin reads them. No-op overhead is ~1ms (single file write).

If scaffold-dev installs LATER in the same session: scaffold-dev's hook on next session start picks up the protocol. No mid-session re-coordination needed.

### 11.4 Race-window discipline (NEW per C9)

The "microseconds race window" assertion in §11.2 is true ONLY if the marker check is the **first** thing each hook does. To enforce:

- `hooks-handlers/session-start.sh` must check + write the marker BEFORE any other work (composition refresh, file I/O, env discovery).
- The marker check + write block sits at lines 1-15 of the hook script (post-shebang); all other logic follows.
- `tests/test-hook-marker.sh` includes an assertion: timing measurement shows marker decision completes within 50ms of hook entry (using `date +%s%N` start/end timestamps).
- If a future hook extension needs to add pre-marker work, the SPEC requires a discipline waiver documented in the iteration log + a measurement showing race remains <100ms.

---

## 12. architect-critic in-conversation invocation

Per Q7 + I3: drop file-IPC, use in-conversation skill calls.

### 12.1 Critic moments (4 total)

| # | Moment | Target | Depth | Adversaries |
|---|---|---|---|---|
| 1 | Phase 5 close | master-spec-phase | premise-audit | [claude] |
| 2 | Phase 7 close | master-spec-phase | premise-audit | [claude] |
| 3 | MASTER-SPEC close | master-spec-full | close | [claude, codex] |
| 4 | `/plan-roadmap` close (NEW) | project-plan | close | [claude, codex] |

Same cadence as v0.1.0 for moments 1-3; moment 4 is new for R1.

### 12.2 Plugin detection (mixed strategy per ac v0.2 settlement #1)

scaffold-onboard v0.2 uses **two complementary detection mechanisms** because architect-critic v0.2 drops the shared composition.json registry (per its settlement #1 — "consumers detect via skill auto-discovery + optional filesystem probe"):

**For ai-mentor v2.0 + superpowers** (composition.json probe retained):

```json
{
  "schema_version": "1",
  "refreshed_at": "2026-05-24T...",
  "plugins": {
    "ai-mentor": { "installed": true, "version": "2.0.x" },
    "superpowers": { "installed": true, "version": "5.1.0" }
  }
}
```

Refresh policy unchanged from v0.1.0 (per v0.1.0 SPEC §8.1): source-aware refresh on startup/clear, preserve on resume/compact.

**For architect-critic v0.2** (filesystem probe, NEW):

```bash
sf_compose_detect_architect_critic() {
  # Walk known plugin cache locations looking for the v0.2 entry skill
  local cache_dirs=(
    "${HOME}/.claude/plugins/cache"
    "${CLAUDE_PLUGINS_DIR:-}"
  )
  for cache in "${cache_dirs[@]}"; do
    [[ -z "$cache" || ! -d "$cache" ]] && continue
    # Glob: cache/<marketplace>/architect-critic/<version>/skills/critiquing-spec/SKILL.md
    for skill_md in "$cache"/*/architect-critic/*/skills/critiquing-spec/SKILL.md; do
      [[ -f "$skill_md" ]] && { echo "v0.2"; return 0; }
    done
  done
  echo "absent"
  return 1
}
```

**Why no v0.1.3 fallback:** verified via git history — architect-critic v0.1.3 shipped with ZERO skills directory (purely slash-command + bash orchestration). The `Skill(architect-critic:critique)` grammar can never resolve against v0.1.3. Combined with v0.2's hard breaking change (no backward compat per its SPEC §3 NG1), the cleanest contract is binary: detect v0.2 → invoke; detect absent → warn-and-skip.

scaffold-onboard composition.json no longer carries an `architect-critic` entry. Detection happens at skill-invocation time (lazy; per-skill-call) via filesystem probe. Probe is cheap (<5ms typical).

### 12.3 In-conversation invocation pattern

Skills (5.1 + 5.4) include at the relevant moment:

```markdown
At <critic moment>:
  1. Detect architect-critic via filesystem probe per §12.2 (`sf_compose_detect_architect_critic`). Returns "v0.2" | "absent".
     Note: this is NOT a composition.json read — per ac v0.2 settlement #1, architect-critic detection is filesystem-only. The composition.json file scaffold-onboard maintains for ai-mentor + superpowers detection does not carry an architect-critic entry in v0.2.
  2. If "absent": emit warning "[scaffold-onboard] architect-critic not installed;
     skipping <moment-name>. Install via /plugin install architect-critic for
     adversarial review at this phase." Continue.
  3. If "v0.2": invoke critiquing-spec skill per §12.4.
  4. Invoke architect-critic:critiquing-spec with target + depth args.
  5. architect-critic skill runs its challenge-resolution loop (it manages this internally).
  6. When control returns: continue with next phase / step.
```

**Drops:** `sf_compose_build_critic_request` + `sf_compose_read_critic_response` from lib/compose.sh. All inbox/outbox file ops removed. The composition probe stays.

### 12.4 Critic skill invocation + paired-release contract (REVISED 2026-05-24)

architect-critic v0.2 shipped 2026-05-24 with a dedicated `critiquing-spec` skill (per ac v0.2 settlement #13 — gerund naming convention). scaffold-onboard v0.2 is a **gated paired release** with architect-critic v0.2 (per ac v0.2 settlement #7).

**REVISED:** the original draft of this section had a v0.1.3 transitional fallback. Verified via git history that v0.1.3 architect-critic shipped with zero skills directory (purely slash-command + bash), so `Skill(architect-critic:critique)` never resolves. v0.1.3 fallback removed.

Resolution logic:

```
1. Filesystem probe per §12.2: sf_compose_detect_architect_critic
   - Returns "v0.2" | "absent"
2. If "v0.2":
     invoke Skill(architect-critic:critiquing-spec) with --spec PATH + --phase N + --depth (premise-audit|close)
     Note: ac v0.2 has Codex opt-in per audit (settlement #6); scaffold-onboard requests close depth at MASTER-SPEC + /plan-roadmap moments by passing --depth close in args
3. If "absent":
     warn-and-skip per §12.3 step 2; user can install architect-critic v0.2+ and retry
```

**Argument vocabulary alignment:** target = `master-spec-phase` | `master-spec-full` | `roadmap`. Depth = `premise-audit` | `close`. Adversaries inferred from depth per ac v0.2 settlement #6 (premise-audit = claude-only; close = claude + codex when user opts in via --close).

**Schema-version coupling:** scaffold-onboard v0.2's CHANGELOG documents the paired release. Users on architect-critic v0.1.3 who upgrade scaffold-onboard get the "absent" warning at critic moments and a hint to install architect-critic v0.2+.

Build sequence note: Phase 6 (subagent pressure tests) tests the binary path (v0.2 present vs absent) via fixture filesystem layouts (mock the architect-critic cache dirs).

---

## 13. Backwards compatibility (per Q5)

### 13.1 Single-repo mode preserved (with one honest exception)

When manifest absent: scaffold-onboard behaves as v0.1.0 for the user-visible surface — `/onboard`, `/scaffold-project`, `/scaffold-docs` produce byte-identical outputs to v0.1.0.

**Test baseline honesty (per C4):** 148 of v0.1.0's 163 tests pass byte-identical in v0.2. The 15 dropped tests target `sf_compose_build_critic_request` + `sf_compose_read_critic_response` — these functions are removed (IPC dropped per §12); the tests cannot pass against absent code and are not retained. The v0.2 test-compose.sh has 24 tests (8 new for the in-conversation invocation pattern + 16 retained probe/lock tests).

Net: v0.1.0 baseline → 148 preserved + 109 new ≈ 257 tests across 12 suites.

### 13.2 No `--legacy-mode` flag

v0.2's skill-first restructuring is transparent. /onboard, /scaffold-project, /scaffold-docs behave identically to v0.1.0 for users who don't invoke /plan-roadmap. Memory-bank file list unchanged; CLAUDE.md format unchanged; governance docs unchanged.

### 13.3 State file backward compat

v0.1.0's `onboarding-state.json` schema preserved. v0.2 adds a separate state file `project-roadmap.json` for R1 hierarchy (new file, no schema conflict). R2 rules live in 03-code-patterns.md (extends an existing file; doesn't break it).

### 13.4 MIGRATION doc

`docs/MIGRATION-scaffold-onboard-v01-to-v02.md` co-authored at v0.2.0 ship. Covers:
- New surfaces (skills + /plan-roadmap)
- How to opt into R1/R2/R3
- What changes for v0.1.0 users (zero unless they invoke new commands)
- New output: `/plan-roadmap` emits `ROADMAP.md` (new file, no v0.1.0 collision)

### 13.5 No filename collision (per C3 + C14 resolution)

The new R1 hierarchy doc is named `ROADMAP.md`, NOT `PROJECT_PLAN.md`. v0.1.0's `/scaffold-docs` continues to emit `PROJECT_PLAN.md` (Phase-2-derived timeline) unchanged. v0.1.0 users are unaffected.

This required updating scaffold-dev's contract: scaffold-dev v0.1 SPEC §16.2 must now reference `ROADMAP.md`, not `PROJECT_PLAN.md`. Coordination: scaffold-dev SPEC author updates §16.2 in parallel with this SPEC's lock-in. Cross-plugin handoff filed.

---

## 14. Karpathy behavioral discipline integration

Per HANDOFF §3.5 + P1: append an optional "Behavioral Discipline" section to CLAUDE.md (in `/scaffold-project`).

### 14.1 Source attribution

Source: `forrestchang/andrej-karpathy-skills` (MIT, community-derived from Karpathy's Jan 2026 X-post observations).

**Attribution language:** *"Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)"*. NOT *"Karpathy's CLAUDE.md"*.

### 14.2 Four principles included (all-or-nothing)

1. **Think Before Coding** — state assumptions, surface ambiguity, ask before guessing
2. **Simplicity First** — minimum code, no speculative abstractions
3. **Surgical Changes** — touch only what's needed, no orthogonal refactors
4. **Goal-Driven Execution** — vague asks → verifiable success criteria

Per P1 (polish): all-or-nothing opt-in for v0.2. Per-principle granularity defers to v0.3+ if user feedback requests it.

### 14.3 Opt-in moment

Phase 10 closing question: "Include behavioral discipline section in CLAUDE.md? This adds 4 cognitive principles (Karpathy-inspired) to your agent's behavior. (yes/no, default yes)"

User answer stored in state as `phase_10.4.include_karpathy = yes|no`. `scaffolding-memory-bank` skill reads this and emits/skips the section.

### 14.4 Placement in CLAUDE.md

After the tiered router + plugin-awareness blocks, before any project-specific content. Exact placement (per C10):

```markdown
# CLAUDE.md — <project name>

<!-- Tier 0: always preloaded -->
## Project at-a-glance
...

<!-- Branch routing -->
## When to load deeper context
...

<!-- Plugin awareness (v0.1.0 compositional blocks; preserved) -->
{{#if has_ai_mentor}}
## ai-mentor available
...
{{/if}}

{{#if has_architect_critic}}
## architect-critic available
...
{{/if}}

{{#if has_superpowers}}
## superpowers available
...
{{/if}}

<!-- Karpathy section (NEW in v0.2, opt-in per §14.3) -->
{{#if include_karpathy}}
## Behavioral Discipline (Karpathy-inspired)

*Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)*

1. **Think Before Coding** — ...
2. **Simplicity First** — ...
3. **Surgical Changes** — ...
4. **Goal-Driven Execution** — ...
{{/if}}

<!-- Project-specific content (user-edited) -->
## Project-specific guidance
...
```

The `{{#if include_karpathy}}` block uses the same conditional grammar as v0.1.0's plugin-awareness blocks (per v0.1.0 SPEC §7.4 template substitution). `scaffolding-memory-bank` skill emits or skips based on `state.answers["phase_10.4.include_karpathy"]`.

---

## 15. Testing strategy

### 15.1 Test impact matrix (per B1)

| Test file | v0.1.0 lines | v0.1.0 tests | v0.2 disposition | v0.2 line delta | v0.2 test delta |
|---|---|---|---|---|---|
| test-compose.sh | 394 | 31 | **REWRITE** — drop IPC tests; keep probe; add critic-skill-invocation marker tests | -200 / +60 = ~250 net | -15 / +8 = ~24 net |
| test-docs.sh | 131 | 23 | **EXTEND** — add manifest routing for governance docs | +30 | +6 |
| test-e2e.sh | 226 | 41 | **EXTEND** — add R1/R2/R3 e2e + manifest-present mode | +80 | +12 |
| test-memory-bank.sh | 122 | 22 | **EXTEND** — R2 rules section emission + manifest routing | +25 | +5 |
| test-parser.sh | 209 | 13 | **KEEP** unchanged | 0 | 0 |
| test-render.sh | 105 | 10 | **EXTEND** — R1 hierarchy templates | +20 | +4 |
| test-state.sh | 213 | 23 | **EXTEND** — roadmap state file CRUD | +30 | +6 |
| **NEW test-roadmap.sh** | 0 | 0 | NEW — `planning-project-roadmap` skill behavior + state schema | +200 | +25 |
| **NEW test-rules.sh** | 0 | 0 | NEW — R2 mcrule DSL parser + rule types | +150 | +18 |
| **NEW test-demo-criteria.sh** | 0 | 0 | NEW — auto:/user: parser + idempotent append | +120 | +14 |
| **NEW test-manifest-routing.sh** | 0 | 0 | NEW — sf_resolve_output_path + sf_discover_manifest | +100 | +12 |
| **NEW test-hook-marker.sh** | 0 | 0 | NEW — Tier 0 marker protocol | +80 | +9 |

**v0.1.0 baseline:** 163 tests / ~1,400 lines (7 suites)
**v0.2 projection:** ~257 tests / ~1,960 lines (12 suites)
**Net delta:** +94 tests / +560 lines

### 15.2 Skill behavior evals (per superpowers writing-skills)

Each new skill (5.4, 5.5, 5.6) gets a behavior eval in `scaffold-onboard/evals/` (new directory):
- `evals/onboarding-project.md` — trigger-phrase coverage + 10-phase flow happy path
- `evals/planning-project-roadmap.md` — 3-timelines prompt triggering + R1.A/B/C flow
- `evals/authoring-machine-checkable-rules.md` — DSL emission for all 4 rule types
- `evals/authoring-vertical-slice-demo.md` — auto:/user: grammar emission + idempotence
- `evals/validating-master-spec.md` — error surfacing + remediation hints
- `evals/scaffolding-memory-bank.md` — derivation correctness + R2 section emission
- `evals/scaffolding-governance-docs.md` — derivation correctness + manifest routing

Evals run as integration tests (subagent invocation against fixture MASTER-SPEC.md files).

### 15.3 Subagent pressure tests

Phase 6 (per build sequence, §16) dispatches each skill to a subagent with adversarial prompts to verify description matching + body correctness under realistic conditions. Lessons inform description-text refinement.

---

## 16. Build sequence

Per Q4 + my critique. Total ~15-22 days focused work.

- **Phase 0 — Evals (1-2 days):** author behavior evals for each new skill (per superpowers `writing-skills`). Define green-light criteria per skill BEFORE any SKILL.md body is written.
- **Phase 1 — Skill bodies (2-3 days):** write SKILL.md for all 7 skills. Tests-first: each skill has a fixture-based test before body authored.
- **Phase 2 — Reference sub-docs (1-2 days):** worked examples + edge cases per skill.
- **Phase 3 — Utility scripts (3-5 days):**
  - 3.1 lib/routing.sh (manifest-aware path resolver) — test-manifest-routing.sh first
  - 3.2 lib/roadmap.sh (R1 hierarchy renderer + parser) — test-roadmap.sh first
  - 3.3 lib/rules.sh (R2 mcrule DSL parser) — test-rules.sh first
  - 3.4 lib/compose.sh refactor (strip IPC, keep probe) — test-compose.sh rewritten
  - 3.5 lib/demo-criteria.sh (R3 parser) — test-demo-criteria.sh first
- **Phase 4 — Hook updates (1 day):** marker-aware Tier 0 protocol per §11; test-hook-marker.sh.
- **Phase 5 — Slash command wrappers (1 day):** preserve /onboard, /scaffold-project, /scaffold-docs; add /plan-roadmap. All use `$ARGUMENTS` env-var bridge (per `feedback_slash_command_dollar_n_bug`).
- **Phase 6 — Subagent pressure tests (2-3 days):** stress each skill with adversarial prompts; iterate on descriptions.
- **Phase 7 — Integration tests (2-3 days):** manifest-present + manifest-absent e2e; full flow `/onboard` → `/scaffold-project` → `/scaffold-docs` → `/plan-roadmap`.
- **Phase 8 — Drop inbox/outbox critic code (1 day):** lib/compose.sh surgery; verify no remaining IPC dependencies.
- **Phase 9 — Publish (1 day):**
  - 9.1 v0.2.0 tag
  - 9.2 plugin.json version bump (per `feedback_plugin_version_bump_required`)
  - 9.3 CHANGELOG completed
  - 9.4 root README plugin table updated
  - 9.5 marketplace entry updated
  - 9.6 MIGRATION-scaffold-onboard-v01-to-v02.md
  - 9.7 R1/R2/R3 demonstration (sample project plan)

Phase-close commit format: `scaffold-onboard: <description> (v0.2 Phase X)` — single-line, no HEREDOC, no Co-Authored-By trailer (per established feedback).

---

## 17. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| R1 hierarchy authoring exhausts users (90 min too long) | Medium | High (adoption) | Hard checkpoint after R1.A; explicit "resume tomorrow" prompts; subagent pressure test for fatigue patterns |
| R2 DSL doesn't fit users' real rules (4 types insufficient) | Medium | Medium | Extensibility built in (§8.5); warn-and-skip on unknown types; v0.3 adds types per user feedback |
| Manifest routing diverges from workspace-init's helper | Low | Medium | scaffold-onboard sources mi_manifest_resolve directly; integration test asserts cross-plugin contract |
| ~~Critic-skill invocation pattern fails when architect-critic v0.2 ships with different surface~~ RESOLVED | — | — | architect-critic v0.2 shipped 2026-05-24 with `critiquing-spec` skill; §12.4 simplified to binary v0.2-or-absent invocation. Verify vocab alignment during Phase 7 integration testing. |
| ~~PROJECT_PLAN.md filename collision breaks v0.1.0 users on regenerate~~ RESOLVED | — | — | Resolved at §13.5 by naming the new R1 doc `ROADMAP.md`; v0.1.0's `/scaffold-docs` PROJECT_PLAN.md output unchanged; zero collision. |
| Tier 0 marker race condition double-emits | Low | Negligible | Acceptable; microsecond race; net cost is ~600 tokens once per session |
| Subagent reliability degrades during Phase 6 pressure tests | High | Medium | Inline pivot per `feedback_subagent_vs_inline_threshold` if subagents reliably fail |

---

## 18. Decisions log

### 18.1 Blockers resolved

**B1 — Test impact matrix.** Resolved §15.1 with explicit per-file disposition + line/test deltas. Net: +94 tests, 12 suites.

**B2 — R1 authoring time budget.** Resolved §7.3: ≤90 min total; hard checkpoints at R1.A/B/C boundaries; proactive checkpoint at 60-min elapsed.

**B3 — R2 DSL selection.** Resolved §8: hybrid markdown-fenced `mcrule` block format in `03-code-patterns.md`. Four minimum-viable rule types. Extensibility via `type:` field + warn-and-skip on unknown types.
- Why not dedicated `.json`/`.yaml`: separates rules from human context; orphans the "why" prose; scaffold-dev's skill would need two-file reads.
- Why not all-prose structured section: brittle parsing; mixing prose and structured keys in one block.

**B4 — Hook coordination protocol.** Resolved §11: shared TMPDIR session-scoped marker (`${TMPDIR}/claude-code-tier0-${CLAUDE_SESSION_ID}`). Race condition acknowledged as acceptable.
- Why not scaffold-dev's data-dir path: cross-plugin write permissions get messy; shared session-scoped path is universally writable.

### 18.2 Importants resolved

**I1 — Skill namespacing.** `scaffold-onboard:<skill-name>` (full namespace, per Claude Code grammar). Verbose but unambiguous across plugins.

**I2 — R3 demo-criteria authoring source.** Hybrid (§9.2): `planning-project-roadmap` seeds 1-3 lines per slice; scaffold-dev refines/expands later via the same skill. Idempotent.

**I3 — architect-critic absent.** Warn-and-skip (§12.3). Visible degradation; user can install mid-session and next moment picks it up.

**I4 — composition.json probe.** Retained verbatim from v0.1.0 (§12.2). Only IPC functions removed from lib/compose.sh.

**I5 — Non-goals list.** §3 enumerates 10 explicit non-goals.

**I6 — MASTER-SPEC role.** §7.1 + flow: MASTER-SPEC stays primary; PROJECT_PLAN is "seeded from MASTER-SPEC, then co-edited" (new derived-once-then-evolves status).

### 18.3 Handoff questions resolved

**Q1 — R1 hierarchy production.** Spin-off skill `planning-project-roadmap` (§5.4), invoked AFTER /onboard's Phase 10 closes. /onboard suggests "Run /plan-roadmap next."
- Why not extend the 10-phase conversation: preserves /onboard's 30-45 min budget; lets MASTER-SPEC settle before hierarchy authoring.

**Q2 — R2 DSL.** Resolved via B3 (§8).

**Q3 — Skill catalog.** Seven skills (§5). Four slash command handles (§6). Three skills are skill-only (no slash handle).

**Q4 — Build sequence.** Resolved §16 (10 phases, ~15-22 days).

**Q5 — Backcompat policy.** Resolved §13. Single-repo mode preserved; no --legacy-mode flag; MIGRATION doc at ship.

**Q6 — Composition with workspace-init beyond manifest reads.** Minimal: SessionStart hook emits one-line "manifest detected" hint; no proactive nag if absent.

**Q7 — Composition with architect-critic v0.2.** Skill-based at 4 moments (§12.1): Phase 5, Phase 7, MASTER-SPEC close, /plan-roadmap close. In-conversation invocation; no IPC.

---

## 19. Open questions deferred to v0.3+

- **OQ1 — User-global rules registry.** Cross-project rule libraries (R2 rules shareable across projects).
- **OQ2 — LLM-extractive rule discovery.** Auto-derive R2 rules from existing code patterns.
- **OQ3 — Multi-project workspace.** One workspace contains multiple projects each with their own /onboard run.
- **OQ4 — `/plan-roadmap --reorganize`.** Mid-project restructuring of hierarchy after sprints have closed (v0.2 has incremental modes per §7.5; full reorganize defers).
- **OQ5 — Demo-criteria templates.** Library of common demo patterns by project class (web/cli/lib) for skill 5.6 to suggest.
- **OQ6 — Per-principle Karpathy opt-in.** v0.2 is all-or-nothing; v0.3+ may let user pick subset.
- **OQ7 — Memory-bank tier discovery refinement.** Currently Tier 0 = always preloaded; Tier 1 = branch-loaded by query type. v0.3+ may add Tier 2 (semantic search).
- **OQ8 — Integrate `/plan-roadmap` into `/onboard` flow (architect-critic C11).** Spin-off skill (v0.2 choice) creates a friction point — many users finish /onboard and never run /plan-roadmap. Integrated Phase 11-12 would force the hierarchy. Deferred for adoption data: if /plan-roadmap completion rate <60%, v0.3 integrates.
- **OQ9 — Linter passthroughs as R2 rule type (architect-critic C12).** Add `type: linter_passthrough` rule that invokes ruff/eslint/etc. with config; complements custom DSL for language-specific projects. Defers to v0.3+ when scaffold-dev's `implementation-checking` skill matures enough to handle external tool dispatch.
- **OQ10 — scaffold-dev hook becomes Tier 0 no-op (architect-critic C13).** Cleaner than marker-coordination dance. Requires scaffold-dev SPEC change; coordinated separately.
- **OQ11 — Full skill-first re-architecture.** v0.2 ships structural skill-first (per §4.3); v0.3+ may push 10-phase conversation into SKILL.md body and eliminate phases.yaml as a data file.

---

## 20. References

1. [HANDOFF-scaffold-onboard-v02-spec.md](HANDOFF-scaffold-onboard-v02-spec.md) — 348-line fresh-session seed
2. [SPEC-workspace-init.md](SPEC-workspace-init.md) §6 (manifest schema) + §11 (integration contract)
3. [SPEC-scaffold-dev.md](SPEC-scaffold-dev.md) §16.2 (R1/R2/R3 contract) + §14.1 (auto/user grammar) + §15.1 (hook coordination)
4. [SPEC-scaffold-onboard.md](SPEC-scaffold-onboard.md) — v0.1.0 SPEC (structural reference)
5. [PLAN-scaffold-onboard.md](PLAN-scaffold-onboard.md) — v0.1.0 PLAN (build-sequence reference)
6. `forrestchang/andrej-karpathy-skills` (MIT) — Karpathy behavioral principles source

---

## 21. Iteration log

- **2026-05-22 14:00 — DRAFT v1** authored from HANDOFF + critique findings. All B1-B4 + I1-I6 + Q1-Q7 settled with "why not the alternative" rationale per P2.
- **2026-05-22 16:00 — DRAFT v2** (post architect-critic pass crit-20260522T155948Z-close-929fan). 9 challenges accepted + applied:
  - C1 → §4.3 honest skill-first framing (structural, not full)
  - C2 → §8.1-8.2 HTML-sentinel mcrule DSL (replaces nested fenced blocks)
  - C3+C14 → ROADMAP.md naming (no v0.1.0 PROJECT_PLAN.md collision)
  - C4 → §13.1 honest test baseline (148/163 + 15 dropped IPC)
  - C5 → §7.3 size-class adaptation
  - C6 → §7.5 re-run protocol (5 modes)
  - C7 → §12.4 critic skill name fallback (v0.1.3 ↔ v0.2)
  - C9 → §11.4 race-window discipline
  - C10 → §14.4 template snippet
  - 4 deferred to OQ8-OQ11
- **2026-05-24 — DRAFT v3** aligned with locked architect-critic v0.2 settlements (memory: project_architect_critic_v02_grill_settlements):
  - §4.1 + §12.2 — architect-critic detection moves from composition.json to filesystem probe (per ac v0.2 settlement #1)
  - §12.4 — paired-release contract; ac v0.2 is the primary target (v0.1.3 transitional fallback was added here but later removed in the 2026-05-24 drift-resolution pass below — v0.1.3 had no skills directory, so the fallback could never resolve)
  - §4.1 + §5.2 — ai-mentor invocation updated for v2.0 surface (grill-me replaces z2-decide; aligned with [project_ai_mentor_v2_grill_settlements])
- **2026-05-24 — Phase 3 drift-resolution pass** (post architect-critic v0.2 ship; scaffold-onboard build paused at Phase 0):
  - §12.2 — removed dead v0.1.3 fallback probe (verified via git history: v0.1.3 had zero skills directory; `Skill(architect-critic:critique)` would never resolve)
  - §12.3 — invocation pattern simplified to binary v0.2-or-absent; v0.1.3 branch removed
  - §12.4 — paired-release contract simplified; removed dead transitional v0.1.3 fallback; binary detection (v0.2 present → invoke; absent → warn-and-skip)
  - §17 — two stale risks marked RESOLVED: PROJECT_PLAN.md collision (resolved at §13.5 by ROADMAP rename); critic-skill invocation pattern mismatch (resolved by ac v0.2 ship)
  - Eval harness via Agent dispatch from Claude Code session (per [feedback_claude_code_sessions_only]) — see PLAN Phase 0
- Pending: user lock-in → Stage B implementation.
