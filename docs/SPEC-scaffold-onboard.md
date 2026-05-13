# SPEC: scaffold-onboard plugin

**Status:** v0.1 design (brainstormed 2026-05-03 → 2026-05-12) · not yet implemented
**Owner:** Praveen Kumar Singh
**Repo home:** `claude-agent-scaffolding` marketplace (this repo)
**Companion plugins:** `scaffold` (implementation phase, v1.0.0, already shipped) · `ai-mentor` (cognitive partner, v1.3.0, already shipped) · `architect-critic` (anti-sycophancy reviewer, v0.1 design pending) · `superpowers` (third-party skills library)
**Platforms:** Linux, macOS (Windows deferred — matches `scaffold` and `ai-mentor`)
**Provenance:** Refinement of `docs/SPEC-scaffold-onboarding.md` (the original 10-phase vision that was never built). This document supersedes that one for the onboarding plugin specifically and applies the dual-axis (dev cycle / product) and "custom over adapted" decision frames established during the skill-shopping conversation.

---

## 1. TL;DR

A run-once Claude Code plugin that turns a fresh `git init` into a fully-scaffolded, agentically-governed project in 30–45 minutes. The plugin's entry point is a 10-phase guided conversation (`/onboard`) that authors `MASTER-SPEC.md`; two deterministic derivation commands (`/scaffold-project`, `/scaffold-docs`) materialize 11 memory-bank files, a tiered `CLAUDE.md` session-start router, and 5 default (or 14 with `--full`) governance docs from that single source of truth.

The plugin **soft-composes** with three cross-cutting plugins:
- **`ai-mentor`** — emits `/z2-decide` hint at Phase 5 and Phase 7 entry (judgment-dense phases)
- **`architect-critic`** — auto-fires premise audit at Phase 5 and Phase 7 recap (claude-only), full gap sweep + Codex fresh-frame review at MASTER-SPEC close
- **`superpowers`** — surfaces `brainstorming` sub-skill availability at Phase 5/7

All cross-cutting integration is opportunistic: scaffold-onboard works fully without any of them; richer behavior unlocks when each is installed.

---

## 2. Motivation

Three pains observed in the user's daily project-start workflow:

**P1 — Onboarding ceremony is unstructured.** Today the user spins up Claude Code in an empty repo and starts talking — vision, core idea, user stories — but nothing reusable is produced. The conversation has value but no artifact survives.

**P2 — Memory-bank derivation is manual.** The user has a proven memory-bank pattern (the wabash 9-file taxonomy) but every project re-authors them by hand. The pattern is generic; only the content is project-specific. A deterministic derivation from a single source of truth would eliminate the re-authoring.

**P3 — AI is too agreeable during architecture decisions.** Pre-`/onboard`, the user has no mechanical gate that challenges premises before they're cemented. Architectural mistakes made in Phase 5 (shape, tech choices) propagate silently through every slice that follows. Catching them mid-onboarding is cheap; catching them three slices later is expensive.

This plugin formalizes the conversation as a 10-phase questionnaire, derives the memory-bank deterministically from the resulting `MASTER-SPEC.md`, and gates judgment-dense phases with a cross-cutting anti-sycophancy reviewer.

---

## 3. Goals & non-goals

### Goals

- **G1.** Run on every new project (and selectively on existing ones) — guided conversation produces `MASTER-SPEC.md`.
- **G2.** Deterministic derivation: `MASTER-SPEC.md` → 11-file memory-bank + tiered `CLAUDE.md` + 5/14 governance docs.
- **G3.** Resume safety: any interruption mid-onboarding resumes at the last incomplete question.
- **G4.** Idempotency: re-running `/scaffold-project` after MASTER-SPEC edits regenerates derived files while preserving live files (`05-active-context.md`, `06-progress.md`, `WORKFLOW.md`).
- **G5.** Soft composition with `ai-mentor`, `architect-critic`, `superpowers` — onboarding works alone but unlocks richer behavior when these are installed.
- **G6.** Anti-sycophancy: the architect-critic auto-fires at Phase 5, Phase 7, and MASTER-SPEC close; can't be silenced session-wide (only skipped per phase via `--skip-critic`).
- **G7.** Bash-orchestrated, no Python runtime, no MCP server (deterministic derivation needs neither).

### Non-goals

- **NG1.** Slice workflow, governance commands (ADR/CHANGELOG/runbook), memory-bank MCP search. Those are the implementation phase's job, owned by the existing `scaffold` plugin (v1.0.0).
- **NG2.** Architect-critic internals. This spec defines the *interface* between `scaffold-onboard` and `architect-critic`; the critic plugin's own design (Codex CLI dispatch, consolidator, principles file management) is a separate brainstorming session.
- **NG3.** ai-mentor adjustments. ai-mentor v1.3 already works as-is. If onboarding-specific hooks emerge, they're a separate plugin upgrade.
- **NG4.** Automatic source-of-truth synchronization (file watcher). The user is responsible for re-running `/scaffold-project` after material edits to MASTER-SPEC.md. No daemon.
- **NG5.** Cross-platform Windows support — Linux and macOS only, matching sibling plugins.
- **NG6.** Auto-detection of project class. The user states it in Phase 1.3.1 as an enum answer; we don't infer it from filesystem signals.

---

## 4. Architecture overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                       scaffold-onboard plugin                              │
│              user-level install · per-project state in repo                │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  /onboard · interactive · stateful · resumable · ~30–45 min        │    │
│  │   ┌─ Phase 1 Foundation ── … ── Phase 10 Operations ── close ──┐   │    │
│  │   │  per-phase loop · ask Qs · recap · accept (or critic gate) │   │    │
│  │   └─────────────────────────────────────────────────────────────┘   │    │
│  │   output: MASTER-SPEC.md + EXECUTIVE-SUMMARY.md                    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                  │                                         │
│                                  ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  /scaffold-project · deterministic · idempotent · ~10s             │    │
│  │   reads MASTER-SPEC.md · derives:                                   │    │
│  │     · .claude/memory-bank/ (9 derived + 2 live + 1 static)         │    │
│  │     · CLAUDE.md (Tier 0 + branch routing)                          │    │
│  │     · .claude/settings.json                                         │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                  │                                         │
│                                  ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  /scaffold-docs [--full] · deterministic · idempotent · ~10s       │    │
│  │   reads MASTER-SPEC.md · derives docs/PRD.md, SRS.md, BACKLOG.md,  │    │
│  │   PROJECT_PLAN.md, adr/0001-*.md  (default · 5 files)              │    │
│  │   --full: +9 (RISK_REGISTER, THREAT_MODEL, TEST_STRATEGY, ...)     │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                            │
│  Cross-cutting integration (soft-composed via lib/compose.sh):             │
│   · ai-mentor          → /z2-decide hint at Phase 5/7 entry               │
│   · architect-critic   → premise audit at Phase 5/7 recap + close          │
│   · superpowers        → brainstorming sub-skill visibility hint           │
└────────────────────────────────────────────────────────────────────────────┘

State partition:
  ${CLAUDE_PLUGIN_DATA}/                       (plugin-update-safe)
  ├── onboarding-state.json                    (current phase, answered Qs)
  └── composition.json                         (detected cross-cutting plugins)

  <repo>/                                      (working tree)
  ├── MASTER-SPEC.md                           (source of truth, committed)
  ├── EXECUTIVE-SUMMARY.md                     (committed)
  ├── CLAUDE.md                                (generated, gitignored)
  ├── .claude/
  │   ├── settings.json                        (committed)
  │   ├── .onboarding-state.json               (symlink to plugin-data; gitignored)
  │   └── memory-bank/                         (11 files, generated)
  └── docs/                                    (governance docs)
      ├── PRD.md, SRS.md, BACKLOG.md, PROJECT_PLAN.md
      └── adr/0001-record-architecture-decisions.md
```

### 4.1 Plugin manifest (`.claude-plugin/plugin.json`)

```json
{
  "name": "scaffold-onboard",
  "version": "0.1.0",
  "description": "Project onboarding via 10-phase guided conversation. Authors MASTER-SPEC.md as source of truth; derives 11-file memory-bank and 5/14 governance docs. Composes with ai-mentor (cognitive mode) and architect-critic (anti-sycophancy reviews) at Phase 5, Phase 7, and MASTER-SPEC close.",
  "author": { "name": "Pras" },
  "category": "workflow"
}
```

Three slash commands · one SessionStart hook (source-aware) · no MCP server · no install-time dependencies on other plugins.

### 4.2 Directory layout

```
scaffold-onboard/
├── .claude-plugin/plugin.json
├── commands/
│   ├── onboard.md                        # /onboard
│   ├── scaffold-project.md               # /scaffold-project
│   └── scaffold-docs.md                  # /scaffold-docs
├── hooks/hooks.json                      # SessionStart (source-aware)
├── hooks-handlers/
│   └── session-start.sh                  # detects in-progress onboarding; refreshes composition.json
├── lib/
│   ├── state.sh                          # onboarding-state read/write; phase progress
│   ├── parser.sh                         # MASTER-SPEC.md parser
│   ├── render.sh                         # template substitution
│   ├── memory-bank.sh                    # 11-file derivation
│   ├── docs.sh                           # 5/14 doc derivation
│   └── compose.sh                        # cross-cutting plugin detection + invocation
├── templates/
│   ├── onboarding-questions/phases.yaml  # 10 phases · ~54 Qs · branching rules
│   ├── master-spec/{MASTER-SPEC,EXECUTIVE-SUMMARY}.md.tmpl
│   ├── memory-bank/{00..08}-*.md.tmpl + index.md.tmpl + WORKFLOW.md
│   ├── claude-md/CLAUDE.md.tmpl
│   ├── docs-minimal/{PRD,SRS,BACKLOG,PROJECT_PLAN}.md.tmpl + adr/0001-*.md.tmpl
│   ├── docs-full/{RISK_REGISTER,THREAT_MODEL,TEST_STRATEGY,DEFINITION_OF_DONE,
│   │              EVALS_PLAN,MODEL_CARD,PROMPT_GOVERNANCE,CUTOVER_PLAN,DEMO_RUNBOOK}.md.tmpl
│   └── settings/claude-settings.json.tmpl
├── tests/
│   ├── test-parser.sh                    # MASTER-SPEC parsing + validation
│   ├── test-state.sh                     # resume + idempotency + lock-file
│   ├── test-memory-bank.sh               # 11-file derivation correctness
│   ├── test-docs.sh                      # 5/14 doc derivation
│   ├── test-compose.sh                   # cross-cutting detection + handshake
│   └── test-e2e.sh                       # empty repo → MASTER-SPEC → derivations
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## 5. The three commands

### 5.1 `/onboard` — guided 10-phase conversation

**Trigger:** user invokes `/onboard` from any git-initialized working directory. No args; resume is implicit from state.

**Mode detection:**
- `onboarding-state.json` not found → **new** · validates repo is git-initialized · creates initial state
- `status=in_progress` → **resume** · picks up at last incomplete phase + question
- `status=complete` → **re-onboard** · prompts user to confirm overwrite of MASTER-SPEC.md (default cancel)

**Per-phase loop** (runs once per phase 1..10):

```
1. load phases.yaml[N] · check branching gates against state.project_class (Phase 1 answer)

2. if N ∈ {5, 7}:
   → emit ai-mentor hint if ai-mentor installed: "/z2-decide recommended"
   → emit superpowers hint if installed: "brainstorming sub-skill available"

3. ask phase questions sequentially:
   loop over phases.yaml[N].questions:
     if branch-gate fails → skip
     print question · capture answer or "TBD"
     write answer to onboarding-state.json (atomic; safe to interrupt)

4. render this phase's section into MASTER-SPEC.md
   (append or replace based on whether the section already exists)

5. generate 3–5 line recap of this phase's section · display to user

6. if N ∈ {5, 7} AND architect-critic installed:
   → announce: "Running architect-critic premise audit on Phase N recap. Type 'skip' to bypass this fire."
   → if user types 'skip' before the dispatch starts: skip this single fire (log "skipped by user")
   → else: dispatch critic premise audit (claude-only, ~30s)
       user reviews critique · may edit recap before accepting

7. user accepts / edits / appends "and also..." note → recap locked into MASTER-SPEC.md

8. state.current_phase ← N+1 · save state · loop to 1 (next phase)

— after Phase 10 accepted —

9. generate EXECUTIVE-SUMMARY.md (~500 words synthesized)

10. if architect-critic installed:
    → announce: "Running architect-critic close audit (claude + codex). Type 'skip' to bypass."
    → if user types 'skip': log "skipped by user"; proceed to step 11 without critic output
    → else: invoke architect-critic --depth=close:
        · critic-claude in-session: full gap sweep
        · critic-codex external: fresh-frame review (CLI dispatch)
        · consolidator merges, surfaces divergence

11. user reviews · edits MASTER-SPEC.md if needed · may re-run critic at close

12. state.status ← complete · onboarding-state.json sealed
    report: "MASTER-SPEC.md authored. Next: /scaffold-project"
```

**State machine:** every state transition (after every Q answer, every recap acceptance, every critic dispatch) is persisted atomically to `onboarding-state.json`. The state file is the resume contract — re-invoking `/onboard` after any interruption picks up at exactly the last successful state.

**Outputs:** `<repo>/MASTER-SPEC.md` · `<repo>/EXECUTIVE-SUMMARY.md` · state at `${CLAUDE_PLUGIN_DATA}/onboarding-state.json` plus symlink `<repo>/.claude/.onboarding-state.json` for in-repo visibility.

### 5.2 `/scaffold-project` — deterministic memory-bank + CLAUDE.md derivation

**Trigger:** `/scaffold-project [--force]`. Repo root.

**Prerequisites:** `<repo>/MASTER-SPEC.md` exists AND passes `sf_spec_validate` (all 10 phase markers present; executive summary present; project_class enum valid).

**Algorithm:**

```
1. validate: MASTER-SPEC.md exists + parses
   └─ on failure: print parse error, exit non-zero, suggest /onboard

2. compute derivation timestamp ts := iso8601(now())

3. for each derived file [00, 01, 02, 03, 04, 07, 08, index]:
   parse the relevant phase sections from MASTER-SPEC.md
   render templates/memory-bank/<file>.md.tmpl with substitutions
   prepend stamp: "Last derived from MASTER-SPEC.md @ {ts}"
   write to .claude/memory-bank/<file>.md (overwrite)

4. for each live file [05-active-context, 06-progress]:
   if file does not exist:
     render template with seed content
     write
   else:
     skip · log "preserved live file"

5. WORKFLOW.md:
   if file does not exist · copy template verbatim
   else · skip

6. render CLAUDE.md (always overwrite):
   substitute project_class-aware branch routing
   inject ai-mentor / architect-critic / superpowers awareness from composition.json
   write to <repo>/CLAUDE.md

7. render .claude/settings.json if not exists (never overwrite)

→ report what was written, preserved, skipped · suggest /scaffold-docs
```

**`--force`** overrides live-file preservation (prompts for confirmation; used only after material MASTER-SPEC changes).

**Idempotency:** safe to run after every MASTER-SPEC edit. Derived files rewritten (with new timestamp); live files preserved unless `--force`.

### 5.3 `/scaffold-docs [--full]` — deterministic governance doc derivation

**Trigger:** `/scaffold-docs` or `/scaffold-docs --full`. Repo root.

**Prerequisites:** `<repo>/MASTER-SPEC.md` exists and parses. Independent of memory-bank state — `/scaffold-docs` can run before, after, or without `/scaffold-project`.

**Algorithm:**

```
1. validate MASTER-SPEC.md exists + parses

2. determine doc set:
   always: templates/docs-minimal/* (5 docs)
   --full: also templates/docs-full/* (+9 docs)

3. for each target doc:
   resolve target path: <repo>/docs/<name>.md (or adr/0001-*.md)
   if exists AND --regenerate not passed:
     skip · log "preserved"
   else:
     parse MASTER-SPEC sections relevant to this doc type
     render template
     write

4. report what was written, preserved, skipped
```

**LLM-gated docs:** in `--full` mode, `EVALS_PLAN`, `MODEL_CARD`, `PROMPT_GOVERNANCE` are only generated when Phase 9.3.1 = "yes" (uses LLMs/ML). Otherwise skipped with a log note.

---

## 6. MASTER-SPEC.md schema + parser

### 6.1 Source-of-truth invariant

**Downstream artifacts never become a second source of truth.** Memory-bank files and governance docs are derived; user hand-edits to derived files get overwritten on the next `/scaffold-project` or `/scaffold-docs` run. To change project facts, edit `MASTER-SPEC.md` and re-derive. This rule is what keeps the system coherent.

### 6.2 Schema

Plain markdown, no frontmatter, no YAML/JSON inside. Three parsing primitives:

**(1) Phase markers — HTML comment anchors** above every Phase heading:
```
<!-- master-spec:phase id=N name=<slug> -->
## Phase N: <Name>
```
Regex: `<!-- master-spec:phase id=(\d+) name=(\w+) -->`

**(2) Key-value lines — bold key, colon, value:**
```
**Project class:** CLI tool
```
Regex: `^\*\*([\w\s&/-]+):\*\*\s+(.+)$`

**(3) Subsection headers — level-3 numbered headings:**
```
### 1.3 Project class & MVP
```
Regex: `^### (\d+)\.(\d+) (.+)$`

Free-text paragraphs under bold keys are scooped up until the next bold key, the next `###`, or the next `##`.

### 6.3 Skeleton

```markdown
# <Project Name> — Master Specification

> Source-of-truth document produced by /onboard.
> Edit freely; downstream commands re-derive from this file.

**Spec version:** 1.0
**Created:** <YYYY-MM-DD>
**Last updated:** <YYYY-MM-DD>
**Project class:** <enum>

---

## Executive Summary
<~500-word narrative synthesized by Claude>

---

<!-- master-spec:phase id=1 name=foundation -->
## Phase 1: Foundation

### 1.1 Vision & Problem
**Pitch:** <one-sentence elevator pitch>

**Problem:**
<paragraph>

### 1.2 Users & Use cases
**Primary users:**
<paragraph>

**Core use case:**
<paragraph>

### 1.3 Project class & MVP
**Project class:** <enum>

**MVP cut:**
<paragraph>

---

<!-- master-spec:phase id=2 name=strategy -->
## Phase 2: Strategy
...

(continues for phases 3–10)
```

### 6.4 Parser API (`lib/parser.sh`)

| Function | Returns | Use |
|---|---|---|
| `sf_spec_validate <path>` | 0 if valid · non-zero + stderr otherwise | Run at start of `/scaffold-project` and `/scaffold-docs` |
| `sf_spec_phase <path> <phase_id>` | raw markdown content of that phase | Memory-bank derivation reads phase ranges |
| `sf_spec_kv <path> <key> [<scope>]` | value of the bold-key | Enum extraction |
| `sf_spec_subsection <path> <sec>` | content of e.g. `1.3` as raw markdown | Subsection-scoped derivation |
| `sf_spec_summary <path>` | content of `## Executive Summary` | For `00-project-brief` + CLAUDE.md preload |
| `sf_spec_project_class <path>` | enum value | Used by every derivation needing project-class branching |
| `sf_spec_phases_present <path>` | space-separated list of phase IDs found | Validation: requires `1 2 3 4 5 6 7 8 9 10` |

### 6.5 Validation rules (in order; fails on first ERROR)

| Rule | Severity |
|---|---|
| File exists at expected path | ERROR |
| Has top-level `# <name> — Master Specification` heading | ERROR |
| Has `## Executive Summary` section | ERROR |
| All 10 phase markers present (id=1..10) | ERROR |
| `**Project class:**` resolves to one of 9 valid enum values | ERROR |
| `**Spec version:**` recognized | WARNING |
| No truncated key-value lines (empty values for required keys) | WARNING |
| TBD count in required-question answers | INFO |

ERRORs block derivation (exit non-zero). WARNINGs log but proceed. INFOs report only.

---

## 7. Derivations

### 7.1 Memory-bank · 11 files

| # | File | Derived from | Load tier | Status |
|---|---|---|---|---|
| 00 | `00-project-brief.md` | Phase 1 | Tier 0 | derived |
| 01 | `01-product-context.md` | Phase 1.2 · Phase 3 · Phase 6 | branch · product/UX | derived |
| 02 | `02-system-patterns.md` | Phase 4 · Phase 5 | branch · architecture | derived |
| 03 | `03-code-patterns.md` | Phase 7 + user-global defaults | branch · implementation | derived |
| 04 | `04-tech-context.md` | Phase 5.2 · Phase 7.2/7.3/7.4 · Phase 8 | branch · tech | derived |
| 05 | `05-active-context.md` | seeded once · authored by slice work | Tier 0 | **live** |
| 06 | `06-progress.md` | seeded once · append-only | branch · history | **live** |
| 07 | `07-constraints.md` | Phase 2 · Phase 4 · Phase 5.3 · Phase 10 | branch · planning | derived |
| 08 | `08-governance.md` | filled by `/scaffold-docs` with doc pointers | branch · planning | derived |
| — | `index.md` | generated TOC | Tier 0 | derived |
| — | `WORKFLOW.md` | static copy from template | branch · workflow | **static** |

Three classes of behavior:
- **derived** · rewritten on every `/scaffold-project` run with new timestamp
- **live** · seeded once on first run; never auto-rewritten (owned by slice work)
- **static** · copied verbatim on first run; never auto-rewritten

### 7.2 CLAUDE.md · Tier 0 + branch routing

The generated `<repo>/CLAUDE.md` is the session-start router. Always preloads **Tier 0** files (~250–400 lines):
- CLAUDE.md itself
- `.claude/memory-bank/index.md`
- `.claude/memory-bank/00-project-brief.md`
- `.claude/memory-bank/05-active-context.md`
- `MASTER-SPEC.md` §Executive Summary + §Phase 1 only

**Branch routing** (loaded on demand based on first user message):
- Architecture / system-design → `02-system-patterns.md` + `04-tech-context.md`
- Implementation / coding → `03-code-patterns.md` + `04-tech-context.md`
- Product / UX → `01-product-context.md`
- Planning / scoping → `07-constraints.md` + `08-governance.md`
- Workflow / process → `WORKFLOW.md` + `06-progress.md`

CLAUDE.md also encodes:
- SSoT discipline rules
- Slash command index (incl. cross-cutting plugins detected at generation time)
- Plugin awareness section (lists ai-mentor / architect-critic / superpowers if `composition.json` shows them installed)

### 7.3 Governance docs · 5 default + 9 with `--full`

**Default (5 docs · always written):**

| # | File | Derived from |
|---|---|---|
| 1 | `docs/PRD.md` | Phase 1 (vision, MVP) · Phase 3 (entities) |
| 2 | `docs/SRS.md` (lite) | Phase 4 · 6 · 7 · 8 |
| 3 | `docs/BACKLOG.md` | Phase 1 user stories + Phase 4 features |
| 4 | `docs/PROJECT_PLAN.md` | Phase 2 (timeline, resources, risks) |
| 5 | `docs/adr/0001-record-architecture-decisions.md` | Michael Nygard template · seeded with key Phase 4/5 decisions |

**`--full` adds 9 more:**

| # | File | Derived from | Conditional? |
|---|---|---|---|
| 6 | `docs/RISK_REGISTER.md` | Phase 2.2.2 | always |
| 7 | `docs/THREAT_MODEL.md` | Phase 4 | always |
| 8 | `docs/TEST_STRATEGY.md` | Phase 9.1 | always |
| 9 | `docs/DEFINITION_OF_DONE.md` | Phase 9.2 · Phase 10 | always |
| 10 | `docs/EVALS_PLAN.md` | Phase 9.3 | **only if** uses_llm = true |
| 11 | `docs/MODEL_CARD.md` | Phase 5.2 · Phase 9.3 | **only if** uses_llm = true |
| 12 | `docs/PROMPT_GOVERNANCE.md` | Phase 9.3 | **only if** uses_llm = true |
| 13 | `docs/CUTOVER_PLAN.md` | Phase 8 · Phase 10.1 | always |
| 14 | `docs/DEMO_RUNBOOK.md` | Phase 6 · Phase 10 | always |

### 7.4 Template substitution grammar

Templates use `{{key}}` for single values, `{{#if cond}}...{{/if}}` for blocks, `{{#each list}}...{{/each}}` for repetition. Rendered by `lib/render.sh` in pure bash + `sed`/`awk`. Missing values render as `TODO: <original question>` placeholders.

---

## 8. Cross-cutting integration

scaffold-onboard never *requires* another plugin. It probes; if found, invokes; if missing, logs info-level note and proceeds.

### 8.1 Detection (`lib/compose.sh`)

Runs once per session via SessionStart hook. Caches results to `${CLAUDE_PLUGIN_DATA}/composition.json`. Subsequent invocations read cache.

```json
{
  "detected_at": "<iso timestamp>",
  "plugins": {
    "ai-mentor":         { "installed": true, "version": "...", "state_file": "..." },
    "architect-critic":  { "installed": true, "version": "...", "principles_file": "...", "command": "/critique" },
    "superpowers":       { "installed": true, "version": "...", "brainstorming_available": true }
  },
  "user_overrides": {
    "disable_mentor_suggestions": false,
    "disable_critic": false,
    "disable_superpowers_subskill": false
  }
}
```

### 8.2 ai-mentor contract

- **When invoked:** Phase 5 entry · Phase 7 entry
- **What scaffold-onboard does:** reads ai-mentor's `state.json`; if `zone != "2"`, emits `/z2-decide` hint
- **Coupling:** one-way (read only, never writes ai-mentor state)
- **Fallback when not installed:** no hint; phase proceeds normally; logged

### 8.3 architect-critic contract

- **When invoked:** Phase 5 recap · Phase 7 recap · MASTER-SPEC close
- **What scaffold-onboard does:** writes JSON request to `${CLAUDE_PLUGIN_DATA}/architect-critic/inbox/<request-id>.json`; invokes `/critique`; reads response from `outbox/<request-id>.json`
- **Per-phase fires:** depth=`premise-audit`, adversaries=`["claude"]`, ~30s
- **MASTER-SPEC close:** depth=`close`, adversaries=`["claude", "codex"]`, ~2–3 min
- **Concession threshold:** 4/5 (firm), baked into request payload
- **Principle sources:** user-global `${CLAUDE_PLUGIN_DATA}/architect-critic/principles.md` + accumulated MASTER-SPEC phases up to current point
- **Fallback when not installed:** no critic dispatch; phase recap shown to user for inspection; logged
- **Fallback when Codex unavailable at close:** falls back to claude-only; warns user

**Request envelope:**

```json
{
  "request_id": "crit-<iso>-<phase|close>",
  "depth": "premise-audit" | "close",
  "adversaries": ["claude"] | ["claude", "codex"],
  "target": {
    "type": "master-spec-phase" | "master-spec-full",
    "path": "<path to MASTER-SPEC.md>",
    "phase_id": <int>,
    "phase_section_range": [<start_line>, <end_line>]
  },
  "sources": {
    "principles": "<path to principles.md>",
    "accumulated_phases": [<int>, ...]
  },
  "concession_threshold": 4,
  "project_class": "<enum>"
}
```

**Response envelope:**

```json
{
  "request_id": "<matching id>",
  "adversaries_used": [...],
  "challenges": [
    {
      "severity": "premise" | "gap" | "alternative",
      "text": "<challenge>",
      "references": ["<phase or section ref>", ...]
    }
  ],
  "gaps": [
    { "text": "<gap>", "severity": "info" | "warning" }
  ],
  "divergences": [
    { "between": ["claude", "codex"], "text": "<where they disagreed>" }
  ],
  "elapsed_ms": <int>
}
```

### 8.4 superpowers contract

- **When invoked:** Phase 5 entry · Phase 7 entry — visibility hint only
- **What scaffold-onboard does:** if `brainstorming_available: true` in composition.json, emits hint that the brainstorming sub-skill is available
- **Coupling:** zero programmatic invocation — Skill loads conversationally if user wants it
- **Fallback when not installed:** no hint

### 8.5 Behavior matrix

| Installed | Phase 5/7 entry hint | Premise audit | Close audit | Visual brainstorm | Onboarding works? |
|---|---|---|---|---|---|
| none | no hint | skipped | skipped | terminal-only | **YES** (core onboarding) |
| ai-mentor only | /z2-decide | skipped | skipped | terminal-only | **YES** |
| architect-critic only | no hint | claude-only | claude + codex | terminal-only | **YES** |
| superpowers only | brainstorm hint | skipped | skipped | available | **YES** |
| ai-mentor + critic | /z2-decide | claude-only | claude + codex | terminal-only | **YES** (recommended minimum) |
| all three | both hints | claude-only | claude + codex | available | **YES** (recommended) |

---

## 9. Architect-critic decisions (Q1–Q5 settled)

These five questions were resolved during brainstorming and constrain how `scaffold-onboard` interacts with `architect-critic`. The critic plugin's own implementation is deferred to its own design session.

### Q1 · Insertion point — settled: **selective per-phase + final pass**

Critic auto-fires after Phase 5 (Architecture) and Phase 7 (Implementation) recaps (claude-only premise audit, ~30s each), plus full pass at MASTER-SPEC close (claude gap sweep + Codex fresh-frame, ~2–3 min). Phases 1–4, 6, 8–10 rely on user inspection only. Rationale: Phase 5 and 7 are load-bearing for everything downstream; other phases are mostly enum-driven and theatre to critique.

### Q2 · Cross-model adversary — settled: **Codex only**

Single external lineage at close. Simplest dispatch; ~$0.05–0.20 per onboarding. Fresh-frame given just MASTER-SPEC + project class (no Claude reasoning context, so Codex anchors on the artifact, not on Claude's argument).

### Q3 · Activation default — settled: **always on, per-occurrence inline skip**

Critic auto-fires at every Q1-defined insertion point. Before each fire, scaffold-onboard announces "Running architect-critic [audit type]. Type 'skip' to bypass this fire." If the user types `skip` in that single turn, the critic is bypassed for that occurrence only (logged); otherwise it fires normally. There is **no session-wide kill switch** and **no ask-each-time `y/n` prompt** — the default is to fire; the skip path is explicit and single-use per occurrence. Anti-sycophancy is the skill's structural goal; making it opt-in or globally silenceable undercuts that.

### Q4 · Concession threshold — settled: **T = 4 (firm)**

Critic scores user rebuttals 1–5 against the specific challenge:
1. Bare contradiction
2. Cite-self (points to spec without new info)
3. Partial address
4. Material new info
5. Premise invalidated

Concedes only at score ≥4; otherwise restates the challenge. Single threshold (not adaptive). Borrowed verbatim from academic-research-skills.

### Q5 · Principle ingestion — settled: **user-global + project, accumulating**

- **User-global** principles live at `${CLAUDE_PLUGIN_DATA}/architect-critic/principles.md` (plugin-owned, user-editable, seeded on first install).
- **Project-specific** principles come from in-flight MASTER-SPEC during onboarding (only previously-answered phases visible at each gate), and from `.claude/memory-bank/03-code-patterns.md` + `08-governance.md` post-onboarding.
- **Bootstrap pattern:** audit only sees what exists at time of fire. Phase 5 audit sees user-global + Phases 1–4. Close audit sees full MASTER-SPEC. Slice-time audits (later, during implementation) see materialized memory-bank.
- **Auto-promotion (design intent yes, implementation deferred):** critic notices repeated patterns across projects and offers to promote them into `principles.md`. Builds the file organically from real decisions rather than forcing cold authorship.

---

## 10. Error handling

| Trigger | Severity | Behavior | Recovery |
|---|---|---|---|
| Not inside a git repo | FATAL | Exit before any file write | "Run `git init` first" |
| `${CLAUDE_PLUGIN_DATA}` not writable | FATAL | Exit with perms error | "Check perms on plugin data dir" |
| `onboarding-state.json` corrupt | ERROR | Refuse resume; suggest backup | "Move to .bak; run `/onboard --reset`" |
| User Ctrl-C mid-question | expected | State persisted up to last completed Q | Re-invoke `/onboard` to resume |
| `MASTER-SPEC.md` missing when `/scaffold-project` runs | ERROR | Exit non-zero | "Run `/onboard` first" |
| `MASTER-SPEC.md` fails validation | ERROR | Exit non-zero; list failures | "Fix MASTER-SPEC.md per error list" |
| Live file rewritten without `--force` | WARNING | Skip file; log "preserved" | Use `--force` to override |
| Codex CLI not installed at close | WARNING | Falls back to claude-only | "Install Codex CLI to enable" |
| Critic dispatch times out (>5 min) | WARNING | Proceeds without critique | "Re-invoke `/critique` manually later" |
| Template missing for derived file | ERROR | Exit non-zero | "Reinstall scaffold-onboard plugin" |
| `composition.json` stale | recoverable | Detect missing dir; re-probe | Transparent |
| Concurrent `/onboard` on same repo | WARNING | Lock file at `${CLAUDE_PLUGIN_DATA}/onboarding.lock`; second refuses | "Wait or remove lock" |
| User runs `/onboard` when status=complete | prompt | Interactive: re-onboard / resume Phase N / cancel | Default: cancel |
| Existing `CLAUDE.md` in repo before `/scaffold-project` | prompt | Three options: import / keep / replace | Default: import |

---

## 11. Edge cases

| Scenario | Behavior |
|---|---|
| Empty git repo (just `git init`, no commits) | OK; onboarding runs on unborn branch |
| Existing `MASTER-SPEC.md` from external source | Prompt: import as start / overwrite / cancel |
| Existing `docs/adr/0001-*.md` | Preserve; log "skipped"; `--regenerate` overrides |
| Existing `.claude/memory-bank/` from manual authoring | Rewrite derived only; preserve live files |
| Running in a git worktree | Same code path; state keyed by `git rev-parse --git-common-dir` (matches scaffold v1 pattern) |
| TBD on several required questions | Allowed; MASTER-SPEC records "TBD"; derived files include `TODO: <question>` placeholders; validation warns |
| User changes project class mid-onboarding | `/onboard --edit-phase 1` re-answers 1.3.1; subsequent phases re-evaluate gates from new project_class |
| User edits MASTER-SPEC mid-onboarding | `/onboard` resume detects edit; warns "spec edited outside onboarding; some recaps may be stale" |
| Schema version skew (v1.0 vs future v2.0) | Parser dispatches by `**Spec version:**`; old projects use v1.0 rules |
| Concurrent `/scaffold-project` in multiple worktrees | Acceptable; derivation deterministic; identical content; last-writer-wins |

---

## 12. Testing strategy

Six bash test suites mirroring scaffold v1.0's pattern. Pure bash, no Python or test framework dependencies, CI-friendly exit codes. Target: ~200 tests total.

| Suite | Target | Coverage |
|---|---|---|
| `test-parser.sh` | ~40 | MASTER-SPEC parsing primitives, phase marker extraction, key-value parsing, validation rules (all 7 cases), edge cases |
| `test-state.sh` | ~30 | Onboarding state CRUD, resume after interruption at every state transition, idempotent writes, lock-file behavior, concurrent-session refusal |
| `test-memory-bank.sh` | ~40 | 11-file derivation, phase-to-file routing, live-vs-derived preservation, `--force`, CLAUDE.md Tier 0 + branch rules, TBD placeholders |
| `test-docs.sh` | ~25 | 5 default + 9 `--full` docs, LLM-gated conditional rendering, existing-file preservation, `--regenerate`, ADR-0001 seed |
| `test-compose.sh` | ~30 | Detection of ai-mentor / architect-critic / superpowers at standard paths, `composition.json` caching, user-override toggles, soft-fail when missing, file-based critic handshake (mock outbox) |
| `test-e2e.sh` | ~25 | Empty repo → /onboard (scripted answers) → MASTER-SPEC.md → /scaffold-project → memory-bank populated → /scaffold-docs → docs populated; plus same on existing repo |

Run all suites: `for t in scaffold-onboard/tests/test-*.sh; do bash "$t"; done`.

---

## 13. Build sequence

Eight phases A–H, each one commit. Stop after any phase if priorities shift.

| Phase | Deliverable | Tests added |
|---|---|---|
| **A** | Plugin skeleton: `plugin.json` · empty command stubs · `lib/` skeleton · `templates/` populated · README + LICENSE + CHANGELOG | (none yet) |
| **B** | `lib/parser.sh` + `lib/render.sh` + `lib/state.sh`; MASTER-SPEC parser fully working; template substitution implemented | `test-parser.sh` · `test-state.sh` |
| **C** | `/onboard` implementation: 10-phase loop, resume, `phases.yaml` authored, MASTER-SPEC generation end-to-end (no cross-cutting yet) | (extend test-state with resume cases) |
| **D** | `/scaffold-project`: `lib/memory-bank.sh`, all 11 templates render, CLAUDE.md with Tier 0 / branch rules, idempotency + live preservation | `test-memory-bank.sh` |
| **E** | `/scaffold-docs [--full]`: `lib/docs.sh`, 5 default + 9 full templates, LLM-gated conditionals, existing-file preservation | `test-docs.sh` |
| **F** | `lib/compose.sh`, SessionStart hook, `composition.json` caching, ai-mentor + architect-critic + superpowers detection, file-based critic handshake | `test-compose.sh` |
| **G** | End-to-end smoke on fresh + existing repo; README polish; CHANGELOG entries | `test-e2e.sh` |
| **H** | Bump to v0.1.0; update SPEC docs; add to marketplace.json; push to GitHub | (all suites green) |

Phases A–E ship a working onboarding plugin with no cross-cutting integration. Phase F brings the composition story. G iterates on real-repo experience. H is the marketplace publish.

---

## 14. Risks

- **R1 (medium)** · Phase 5 / Phase 7 critic fire frequency feels noisy in real use → `--skip-critic` flag mitigates per-occurrence; revisit threshold if real-world friction surfaces.
- **R2 (medium)** · Codex CLI dispatch from inside Claude Code session has integration friction (PATH, auth) → architect-critic's own design handles this; scaffold-onboard's contract just expects the response file.
- **R3 (low)** · 11-file memory-bank feels heavy for one-day prototypes → cost is per-onboarding (run-once); acceptable trade-off for full coverage on bigger projects.
- **R4 (low)** · `phases.yaml` schema evolution breaks old MASTER-SPEC files → version-pin via `**Spec version:**` line; parser dispatches by version.
- **R5 (low)** · Composition cache (`composition.json`) goes stale when user installs/removes plugins between sessions → SessionStart hook refreshes on every session start (source=startup/clear); detect-missing-dir fallback at command invocation time.

---

## 15. Open questions (deferred)

These are not blockers. They surfaced during brainstorming and have a clear path forward:

| # | Question | Recommendation |
|---|---|---|
| OQ-1 | Auto-promotion mechanism implementation | Design intent locked (yes); implementation deferred to v0.2 |
| OQ-2 | Exact Claude Code plugin discovery paths used by `compose.sh` | Probe well-known patterns; document in implementation phase |
| OQ-3 | Should `/onboard` write commit message templates for the MASTER-SPEC commit? | Defer; user owns git workflow |
| OQ-4 | Naming `scaffold-onboard` vs `onboarding` alone | Settled `scaffold-onboard` (symmetry with `scaffold`) |
| OQ-5 | Whether to ship a `.archive/` convention for old MASTER-SPECs after re-onboard | Defer; document if user opts to re-onboard regularly |

---

## 16. Iteration log

- **v0.1 (2026-05-12):** Initial design after 6-section brainstorming session. Approach **B (spec-faithful)** selected from three alternatives. Architect-critic Q1–Q5 settled inside the brainstorming. Plugin separation locked: onboarding ≠ implementation. Cross-cutting placement for architect-critic confirmed. Auto-promotion design intent yes, implementation deferred.
- **v0.1 build progress (2026-05-13):** Phases A–E implemented on branch `implementation-scaffold-onboard` (45 commits, 91 tests passing across 5 suites). Phase F (cross-cutting integration), Phase G (E2E + polish), and Phase H (v0.1.0 publish) remain. See `docs/PLAN-scaffold-onboard.md` "Implementation Status" section for the canonical state. Three implementer-discovered adaptations were applied vs. the spec's original code references: (1) BSD awk `sub()` chains instead of gawk 3-arg `match()`, (2) bash 3.2 parallel indexed arrays instead of `declare -A`, (3) `project_name` derivation parses the prefix-before-em-dash from Phase 1.1.1 answer (with `basename "$PWD"` fallback) so MASTER-SPEC and CLAUDE.md agree regardless of cwd basename. macOS + Linux still v0.1's only platforms; Windows deferred to v0.2.
