# SPEC: Claude Agent Scaffolding Plugin

> **Provenance.** This is the original full-vision spec for the scaffolding plugin, copied verbatim from `/home/pras/Documents/claude-agent-scaffolding/SPEC.md` on 2026-05-03. It describes the `/onboard` → `/scaffold-project` → `/scaffold-docs` bootstrap flow and a richer 9-section slice template. **None of this onboarding flow was shipped.** The shipped `scaffold` plugin (v1.0.0, see `SPEC-scaffold.md`) implemented the slice workflow + governance + memory MCP, but skipped the entire onboarding phase. Treat this file as the source-of-truth for the unbuilt vision; do not assume any of it is implemented.
>
> **What's actually shipped today:** `/scaffold-init` (silent automation — LICENSE / .gitignore / README skeleton / docs dirs / CLAUDE.md generation; no questions asked). Everything between bootstrap and the first slice is the gap this spec was designed to fill.
>
> Cross-references inside this file (e.g., `docs/archive/SPEC-v1.md`, `SPEC-ai-mentor.md`) point to the **source repo**, not this one. They are not authoritative here.

**Status:** Draft v0.8 — for iteration, not implementation
**Date:** 2026-04-26
**Owner:** Praveen Kumar Singh
**Replaces:** `SPEC.md` v1 (5-plugin marketplace design — archived at `docs/archive/SPEC-v1.md`).
**Companion spec:** `SPEC-ai-mentor.md` (separate user-level plugin).

---

## 1. TL;DR

A **single, opinionated Claude Code plugin** that turns an empty directory into a fully-scaffolded, agentically-governed project. The plugin's entry point is a guided onboarding conversation (modeled on ProjectPulse's 10-phase, ~50-question session); its outputs are a master spec, a `.claude/memory-bank/` runtime (modeled on the user's `wabash` repo), a default set of governance docs, and a per-sprint workflow that runs spec-driven + test-driven cycles with enforcement gates.

Three layers of capability:

1. **Bootstrap** (once per project): `/onboard` → `/scaffold-project` → `/scaffold-docs`
2. **Per-sprint** (once per slice): `/spec` → `/implement` → `/implementation-check` → `/code-review` → `/commit`
3. **Project-level skills bundled here**: `code-patterns`, `git-workflow` (mentor / pair-programming behavior is a separate user-level **AI Mentor** plugin — see `SPEC-ai-mentor.md`).

---

## 2. Motivation

The user's actual workflow when starting a project:

> "I spin up Claude Code in an empty repo and start talking — vision, core idea, user stories — there's no tech stack yet, nothing to detect."

That conversation today is unstructured: it produces value, but nothing reusable. The user's product **ProjectPulse** already proves a structured version works (10 expert-role phases, ~98 questions, generates 15 docs and an agent infra blueprint). And the user's `wabash` repo already proves what the *output* of good scaffolding looks like (memory-bank file taxonomy, slice-spec 7-section template, `/implementation-check` enforcement gate).

What's missing is the **glue plugin** that runs the ProjectPulse-shaped conversation inside Claude Code and produces a wabash-shaped scaffold. This spec defines that plugin.

Auto-detection of tech stack was explicitly ruled out — fragile, and at project start there's nothing to detect anyway. The only source of truth is the user's own articulated vision, captured through the onboarding conversation.

---

## 3. Goals & Non-goals

### Goals

- **G1.** One-command bootstrap from empty repo to scaffolded project, in a single Claude Code session.
- **G2.** A self-contained master spec authored *by the user* (via guided conversation), that all downstream artifacts derive from.
- **G3.** Slice specs that survive a session/model handoff (Opus authors → Sonnet implements in a fresh session, no clarifying questions needed).
- **G4.** Lean default doc set (PRD + SRS-lite + Backlog + ADR + Project Plan); heavyweight enterprise set behind an opt-in flag.
- **G5.** Enforcement, not exhortation: `/implementation-check` mechanically validates spec coverage and code-pattern guardrails.
- **G6.** Project-agnostic. Works for solo greenfield, small team, any stack.

### Non-goals

- **NG1.** Tech-stack auto-detection. Source of truth is the master spec, authored via conversation.
- **NG2.** Database / persistence layer. Markdown files are sufficient; no Postgres/SQLite needed (unlike ProjectPulse).
- **NG3.** Multi-plugin marketplace. One plugin, end-to-end.
- **NG4.** UI / web frontend. Plugin runs entirely inside Claude Code CLI.
- **NG5.** Replacing `~/.claude/`-level personal memory. The plugin's memory-bank lives in the project repo; personal preferences stay in user-level settings.

---

## 4. Architecture overview

```
┌──────────────────────────────────────────────────────────────────┐
│                    Layer 1: Project Bootstrap                    │
│          (run once in an empty repo; outputs derive serially)    │
│                                                                  │
│   /onboard ─────► MASTER-SPEC.md + EXECUTIVE-SUMMARY.md          │
│       │           (10 phases, ~50 Qs, conversational)            │
│       ▼                                                          │
│   /scaffold-project ──► .claude/memory-bank/, CLAUDE.md,         │
│       │                 .claude/settings.json                    │
│       ▼                                                          │
│   /scaffold-docs [--full] ──► docs/PRD.md, SRS.md, BACKLOG.md,   │
│                               PROJECT_PLAN.md, adr/0001-*.md     │
│                               (+9 more if --full)                │
└──────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Layer 2: Per-Sprint Workflow                  │
│            (run once per vertical slice / day / week)            │
│                                                                  │
│   /spec ──► docs/specs/sprint-N/slice-M.md (9-section template)  │
│       ▼                                                          │
│   /implement ──► TDD loop (red → green → refactor)               │
│       ▼                                                          │
│   /implementation-check ──► ERROR / WARNING / INFO report        │
│       ▼                                                          │
│   /code-review ──► uses code-patterns skill                      │
│       ▼                                                          │
│   /commit ──► disciplined commit (HEREDOC, secret scan)          │
└──────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│             Layer 3: Project-Level Skills (bundled here)         │
│                                                                  │
│   code-patterns  — modular, ≤80-LOC, FP-default; CP-1..CP-9      │
│   git-workflow   — stub (content TBD; configured per-project)    │
└──────────────────────────────────────────────────────────────────┘
                                +
                  ┌─────────────────────────────────┐
                  │  AI Mentor (separate plugin,    │
                  │  user-level; SPEC-ai-mentor.md) │
                  └─────────────────────────────────┘
```

---

## 5. Detailed design

### 5.1 `/onboard` — guided onboarding session

**Trigger.** User runs `/onboard` in an empty (or near-empty) repo.

**Mechanics.** Claude reads `templates/onboarding-questions/phases.yaml`, walks the user through 10 expert-role phases sequentially. ~54 questions total, variable per phase (3–7). Each question allows free text or "TBD"; questions are individually skippable. **Light branching** is supported: Phase 1's "project class" answer gates skips in Phases 6 and 7.

**Per-phase synthesize-and-confirm.** At the end of each phase, Claude generates a 3–5 line recap of what it heard ("you said the project is X, the primary user is Y, MVP is Z…"). The user can:
- Accept and proceed to the next phase.
- Edit any answer in place — Claude re-prompts that question, captures the new answer, regenerates the recap.
- Add a free-text "and also..." note that gets appended to the phase's section in `MASTER-SPEC.md`.

This catches misinterpretation early (cheaper than discovering it after `/scaffold-docs`).

**Project class enum** (asked in Phase 1; drives downstream skips):

```
CLI tool | Library or SDK | Web app | Web service (API only) |
Mobile app | ML / AI system | Agent or plugin | Data pipeline | Other
```

**Phase taxonomy** (refined from ProjectPulse):

| # | Phase | Role | Q count | Notes |
|---|---|---|---|---|
| 1 | Foundation | Product Manager | 7 | + project-class question |
| 2 | Strategy | Strategic Planner | 5 | timeline, budget, risks, metrics |
| 3 | Domain & Data Model | Domain Modeler | 5 | entities, relationships, ubiquitous language |
| 4 | Security & Compliance | Security Engineer | 5 | moved earlier — informs Phase 5 |
| 5 | Architecture | System Architect | 7 | shape, tech choices, scale, latency |
| 6 | UX / Surfaces | UX Designer | 4 (UI projects) / 2 (headless DX) | **conditional**: full UX path for UI projects, reduced "developer UX" path for Library / Data pipeline / Web service (API only) |
| 7 | Implementation Approach | Engineer | 6 | merged BE+FE; conditional subsections |
| 8 | DevOps & Environments | DevOps | 5 | merged former DevOps+Deployment |
| 9 | Quality, Testing & Eval | QA Engineer | 5 | eval subsection gated to LLM/ML projects |
| 10 | Operations & Support | Release/Ops | 5 | rollout, observability, support, deprecation |

**Total: ~54 questions** (varies with skips).

**Output.** Two files at repo root:
- `MASTER-SPEC.md` — structured doc, one section per phase, embedding all user answers verbatim.
- `EXECUTIVE-SUMMARY.md` — ~500-word synthesized narrative, generated by Claude from the answers.

**Resume.** State persisted in `.claude/.onboarding-state.json` (gitignored). Re-running `/onboard` after interruption picks up at the last unanswered question.

#### 5.1.1 Question bank (draft v0.2 — for review)

Each entry: `id` | question text | metadata. Metadata abbreviations: `req` (required) / `opt` (optional) / `gate:<expr>` (only asked if expr true).

**Phase 1 — Foundation** (Product Manager)

*1.1 Vision & Problem*
- `1.1.1` *req* — One-sentence elevator pitch: what are you building?
- `1.1.2` *req* — What problem does this solve, and for whom?
- `1.1.3` *opt* — What does success look like 6 months from launch?

*1.2 Users & Use cases*
- `1.2.1` *req* — Who are the primary users (1–3 personas, brief)?
- `1.2.2` *req* — The single core use case that, if missing, the product fails?

*1.3 Project class & MVP*
- `1.3.1` *req* — **Project class** (pick one): CLI tool / Library or SDK / Web app / Web service (API only) / Mobile app / ML or AI system / Agent or plugin / Data pipeline / Other
- `1.3.2` *req* — MVP cut — smallest thing that demos value end-to-end?

**Phase 2 — Strategy** (Strategic Planner)

*2.1 Timeline & Resources*
- `2.1.1` *req* — Target weeks-to-MVP?
- `2.1.2` *req* — Who's building (solo / team size)?

*2.2 Constraints*
- `2.2.1` *opt* — Monthly budget cap for hosting / APIs / services (USD)?
- `2.2.2` *req* — Top 3 risks (tech / market / resource)?

*2.3 Success*
- `2.3.1` *req* — How will you know it works — one metric, signal, or proof?

**Phase 3 — Domain & Data Model** (Domain Modeler)

*3.1 Core entities*
- `3.1.1` *req* — 3–7 core entities/objects in your domain?
- `3.1.2` *req* — For each entity: identity (key) + one-line description?

*3.2 Relationships*
- `3.2.1` *req* — Key relationships (one-to-many, many-to-many, hierarchies)?
- `3.2.2` *opt* — Aggregates or invariants — what must stay consistent together?

*3.3 Ubiquitous language*
- `3.3.1` *opt* — Domain terms to keep consistent across code & docs?

**Phase 4 — Security & Compliance** (Security Engineer)

*4.1 Sensitivity*
- `4.1.1` *req* — Handles PII / health / financial / payment data? (none / which)
- `4.1.2` *opt* — Regulated domain (GDPR / HIPAA / SOC 2 / PCI-DSS / other)?

*4.2 Auth & access*
- `4.2.1` *req* — Auth model: none / API keys / OAuth / SSO / custom?
- `4.2.2` *req* — Multi-tenant or single-tenant?

*4.3 Threat surface*
- `4.3.1` *req* — External attack surface: public internet / internal / air-gapped?

**Phase 5 — Architecture** (System Architect)

*5.1 Shape*
- `5.1.1` *req* — Shape: monolith / modular monolith / services / library / CLI / hybrid?
- `5.1.2` *opt* — Async/event-driven boundaries (queues, batch jobs, streams)?

*5.2 Tech choices*
- `5.2.1` *req* — Primary language(s)?
- `5.2.2` *req* — Primary data store(s): relational / document / kv / vector / search / file / none?
- `5.2.3` *opt* — External APIs / third-party services in scope?

*5.3 Performance & scale*
- `5.3.1` *opt* — Expected scale at 6 months: throughput, concurrent users, data volume?
- `5.3.2` *opt* — Latency targets for hot paths?

**Phase 6 — UX / Surfaces** (UX Designer) — *conditional: branch on project_class*

*Branch A — UI projects (project_class ∈ {Web app, Mobile app, CLI tool, ML or AI system, Agent or plugin, Other})*

*6A.1 Surfaces*
- `6A.1.1` *req* — Surfaces: web UI / mobile / CLI / TUI / multiple?
- `6A.1.2` *req* — Primary user flow from landing to first value (paragraph)?

*6A.2 Standards*
- `6A.2.1` *opt* — Accessibility floor: WCAG 2.1 A / AA / AAA / not in scope?
- `6A.2.2` *opt* — Design system: existing to adopt / build minimal / TBD?

*Branch B — Headless / DX projects (project_class ∈ {Library or SDK, Data pipeline, Web service (API only)})*

*6B.1 Developer experience*
- `6B.1.1` *req* — How will users discover and learn the interface? (README / generated API docs / interactive docs / examples-only / other)
- `6B.1.2` *req* — Error and output style: verbose human-readable / minimal / structured (JSON / structured logs) / mixed?

**Phase 7 — Implementation Approach** (Engineer)

*7.1 Decomposition (always)*
- `7.1.1` *req* — Module/package boundaries — how do you decompose?
- `7.1.2` *req* — Code style: statically typed (which) / dynamic / mixed?

*7.2 Backend (gate: project_class ∈ {Web app, Web service, ML or AI system, Agent or plugin, Data pipeline})*
- `7.2.1` *opt* — ORM / query builder / raw SQL — preference?
- `7.2.2` *opt* — API style: REST / GraphQL / RPC / tRPC / N/A?

*7.3 Frontend (gate: project_class ∈ {Web app, Mobile app})*
- `7.3.1` *opt* — State management: local / context / library (which) / server-state lib?

*7.4 Library/SDK (gate: project_class = Library or SDK)*
- `7.4.1` *opt* — Public API surface: what's exported? Versioning approach?

**Phase 8 — DevOps & Environments** (DevOps)

*8.1 Local dev*
- `8.1.1` *req* — Required local tooling (pkg mgr, docker, k8s, nothing fancy)?
- `8.1.2` *opt* — Fresh-dev clone-to-running target time?

*8.2 CI/CD*
- `8.2.1` *opt* — CI platform: GitHub Actions / GitLab / CircleCI / Jenkins / none yet?
- `8.2.2` *req* — Environments: dev-only / dev+staging+prod / preview branches?

*8.3 Hosting*
- `8.3.1` *req* — Hosting target: Vercel / Railway / AWS / GCP / Azure / self-hosted / TBD?

**Phase 9 — Quality, Testing & Eval** (QA Engineer)

*9.1 Test pyramid*
- `9.1.1` *req* — Coverage floor for core logic (% target)?
- `9.1.2` *req* — Test types in scope: unit / integration / e2e / contract / property?

*9.2 Quality gates*
- `9.2.1` *req* — Pre-merge gates — what must pass to merge a PR?

*9.3 Eval (gate: project_class ∈ {ML or AI system, Agent or plugin} OR uses_llm = true)*
- `9.3.1` *req* — Uses LLMs / ML models? (yes/no — gates 9.3.2)
- `9.3.2` *opt* — Eval dimensions (groundedness, factuality, latency, cost, format, safety)?

**Phase 10 — Operations & Support** (Release/Ops)

*10.1 Rollout*
- `10.1.1` *opt* — Rollout strategy: direct / staged / feature flags / canary?

*10.2 Observability*
- `10.2.1` *opt* — Logs/metrics/traces destination?
- `10.2.2` *opt* — Alerting target: email / Slack / pager / none?

*10.3 Support model*
- `10.3.1` *opt* — Who responds when it breaks — solo / on-call / business hours?
- `10.3.2` *opt* — Deprecation/retirement communication plan?

**Linear progression with light branching.** Phase 1's `1.3.1` (project class) is the only branching input. No question depends on a free-text answer to another question — only on enums.

### 5.2 `/scaffold-project` — derive runtime from master spec

**Trigger.** User runs `/scaffold-project`. Requires `MASTER-SPEC.md` to exist.

**Mechanics.** Pure derivation, no questions. Reads `MASTER-SPEC.md` per its known schema, instantiates the 11 memory-bank files + `CLAUDE.md` + `.claude/settings.json` from templates in `templates/memory-bank/` and `templates/claude-md/`.

#### 5.2.1 MASTER-SPEC.md schema

`MASTER-SPEC.md` is the **source of truth**. Everything downstream re-derives from it. The user can edit it freely after onboarding; re-running `/scaffold-project` regenerates the memory-bank.

**Format:** sectioned markdown with stable header text + key-value patterns for enum answers. No frontmatter (keeps it editable in any tool); no embedded YAML/JSON (keeps it readable). Parsing relies on:

1. Predictable header text: `## Phase N: <Name>` and `### N.M <Subsection>`.
2. **Key-value enum lines:** `**Project class:** Web app` — parsed by regex `^\*\*([\w\s]+):\*\*\s+(.+)$`.
3. Free-text paragraphs under known sub-headers.
4. HTML comment markers as parser-friendly anchors:

```html
<!-- master-spec:phase id=N name=<slug> -->
```

**Skeleton:**

```markdown
# <Project Name> — Master Specification

> Source-of-truth document produced by `/onboard`.
> Edit freely; downstream commands (`/scaffold-project`, `/scaffold-docs`) re-derive from this file.

**Spec version:** 1.0
**Created:** <YYYY-MM-DD>
**Last updated:** <YYYY-MM-DD>

---

## Executive Summary

<~500-word narrative synthesized by Claude from all phase answers. Edit by hand if Claude's synthesis is off.>

---

<!-- master-spec:phase id=1 name=foundation -->
## Phase 1: Foundation

### 1.1 Vision & Problem
**Pitch:** <one-sentence elevator pitch>

**Problem:**
<paragraph from question 1.1.2>

**6-month success:**
<paragraph from 1.1.3, or "TBD">

### 1.2 Users & Use cases
**Primary users:**
<paragraph from 1.2.1>

**Core use case:**
<paragraph from 1.2.2>

### 1.3 Project class & MVP
**Project class:** <enum from 1.3.1>

**MVP cut:**
<paragraph from 1.3.2>

---

<!-- master-spec:phase id=2 name=strategy -->
## Phase 2: Strategy
... <same structure: ## sub-sections + **Key:** value lines>

---

<!-- master-spec:phase id=3 name=domain -->
## Phase 3: Domain & Data Model
...

<!-- continues for phases 4–10 -->
```

**Convention:** every enum answer (anything from a fixed list — project class, accessibility, hosting target, etc.) is a `**Key:** value` line. Every free-text answer is a paragraph block under its sub-header. This gives parsers a clean way to extract structured data without abandoning markdown.

#### 5.2.2 Memory-bank file taxonomy

11 files under `.claude/memory-bank/`. Each has a defined purpose, a derivation source from `MASTER-SPEC.md`, and a load tier (Tier 0 = always preloaded, Branch = loaded only for specific query types).

| # | File | Purpose | Derived from | Load tier | Live? |
|---|---|---|---|---|---|
| 00 | `00-project-brief.md` | Vision, problem, users, MVP, project class — the "what is this" doc | Phase 1 | Tier 0 | No |
| 01 | `01-product-context.md` | Domain entities, user flows / DX, ubiquitous language | Phase 1.2, Phase 3, Phase 6 | Branch (product/UX queries) | No |
| 02 | `02-system-patterns.md` | Architecture invariants, security posture, async/sync rules | Phase 4, Phase 5 | Branch (architecture queries) | No |
| 03 | `03-code-patterns.md` | Code style invariants — typed/dynamic, function/class rules, comment policy | Phase 7 + `code-patterns` skill defaults | Branch (implementation queries) | No |
| 04 | `04-tech-context.md` | Languages, frameworks, data stores, external services, hosting, tooling | Phase 5.2, Phase 7.2/7.3/7.4, Phase 8 | Branch (tech queries) | No |
| 05 | `05-active-context.md` | What's happening *right now* — active sprint, active slice, recent decisions, blockers | Empty at scaffold; appended by per-sprint commands | Tier 0 | **Yes (LIVE)** |
| 06 | `06-progress.md` | Append-only log: dated entries by sprint/slice/decision/gotcha | Empty at scaffold; appended by `/commit` and `/implementation-check` | Branch (history queries) | **Yes (LIVE)** |
| 07 | `07-constraints.md` | Hard constraints — budget, timeline, compliance, perf targets | Phase 2, Phase 4, Phase 5.3, Phase 10 | Branch (planning/scoping queries) | No |
| 08 | `08-governance.md` | Pointers to governance docs (PRD, SRS, Backlog, etc.) + workflow rules | Filled by `/scaffold-docs` after running | Branch (planning queries) | No |
| – | `index.md` | Table of contents over the bank | Generated | Tier 0 | No |
| – | `WORKFLOW.md` | Per-sprint workflow — pointers to `/spec` → `/implement` → `/implementation-check` → `/commit` loop | Static (lifted from wabash) | Branch (workflow queries) | No |

**Per-file shape conventions:**

- Each non-live file starts with a short purpose blurb + `**Last derived from MASTER-SPEC.md @ <date>**` line so users can detect drift.
- Live files (`05`, `06`) have no derivation marker — they're authored by commands, not by `/scaffold-project`.
- Sections inside each file mirror the source phases (e.g., `02-system-patterns.md` has `## Architecture shape`, `## Security posture`, `## Boundaries`).
- Cross-references use markdown links: `[See MASTER-SPEC §3.2](../../MASTER-SPEC.md#32-relationships)`.

#### 5.2.3 Derivation rules — `/scaffold-project` algorithm

```
1. Validate MASTER-SPEC.md exists and parses (all 10 phase sections present).
2. For each non-live memory-bank file (00, 01, 02, 03, 04, 07):
   a. Read the source phases per the table above.
   b. Render the file from templates/memory-bank/<NN>.md.tmpl, substituting {{phase_N.M.K}} placeholders.
   c. Add the "Last derived from MASTER-SPEC.md @ <today>" stamp.
3. Create empty 05-active-context.md and 06-progress.md from templates with seed content ("no active sprint").
4. Render index.md from templates/memory-bank/index.md.tmpl listing all 11 files.
5. Copy WORKFLOW.md from templates as-is (project-agnostic).
6. Render CLAUDE.md from templates/claude-md/CLAUDE.md.tmpl per §5.2.4.
7. Render .claude/settings.json from templates/settings/settings.json.tmpl with minimal allowlist (matching detected tooling from Phase 5/8 — pure substitution, no detection).
8. Initialize 08-governance.md as a stub pointing at docs/ (filled by /scaffold-docs).
```

**Re-running `/scaffold-project`** is safe: it overwrites the non-live derived files (00–04, 07) and `index.md`, but **never** touches live files (`05-active-context.md`, `06-progress.md`) or `WORKFLOW.md` (project-agnostic, manually edited if at all). Users can edit MASTER-SPEC.md and re-run to refresh the bank.

#### 5.2.4 CLAUDE.md — session-start router

`CLAUDE.md` is the entry point Claude reads at session start. It defines the **tiered preload** strategy lifted from wabash:

**Tier 0 — always preloaded** (~250–400 lines total):
- `CLAUDE.md` itself
- `.claude/memory-bank/index.md`
- `.claude/memory-bank/00-project-brief.md`
- `.claude/memory-bank/05-active-context.md`
- `MASTER-SPEC.md` §Executive Summary + §Phase 1 only

**Tier 1 — branch by query type** (loaded on demand based on first user message):
- *Architecture / system-design queries* → `02-system-patterns.md`, `04-tech-context.md`, `MASTER-SPEC.md §Phase 4–5`
- *Implementation / coding queries* → `03-code-patterns.md`, `04-tech-context.md`, `02-system-patterns.md`
- *Product / UX queries* → `01-product-context.md`, `MASTER-SPEC.md §Phase 3, §Phase 6`
- *Planning / scoping queries* → `07-constraints.md`, `08-governance.md`, `docs/PROJECT_PLAN.md`, `docs/BACKLOG.md`
- *Workflow / process queries* → `WORKFLOW.md`, `06-progress.md`

CLAUDE.md template explicitly lists these branch rules so Claude knows what to load when. It also encodes:

- Project conventions (typed-vs-dynamic, framework choices, hosting) — substituted from MASTER-SPEC.md.
- Commit discipline (HEREDOC, secret scan, no co-author by default).
- SSoT discipline (MASTER-SPEC.md is canonical; memory-bank files derive from it; never hand-edit derived files without re-running `/scaffold-project`).
- Slash command index (`/spec`, `/implement`, `/implementation-check`, `/code-review`, `/commit`).

#### 5.2.5 Worked example excerpt

For a project where Phase 1 produced:

```
**Pitch:** todo-cli — a fast, local-first task manager for the terminal.
**Project class:** CLI tool
**MVP cut:** add/list/complete tasks; persist to ~/.todo.json; tab-complete in bash/zsh.
```

`00-project-brief.md` would render as:

```markdown
# Project Brief

**Last derived from MASTER-SPEC.md @ 2026-04-25**

## What is this?
todo-cli — a fast, local-first task manager for the terminal.

## Project class
CLI tool

## Problem
<paragraph from Phase 1.1.2>

## Primary users
<paragraph from Phase 1.2.1>

## Core use case
<paragraph from Phase 1.2.2>

## MVP cut
add / list / complete tasks; persist to `~/.todo.json`; tab-complete in bash/zsh.

## See also
- [MASTER-SPEC §Phase 1](../../MASTER-SPEC.md#phase-1-foundation)
```

And the corresponding entry in `index.md`:

```markdown
| File | Purpose | Tier |
|---|---|---|
| 00-project-brief.md | What this project is and for whom | 0 (always preloaded) |
| 01-product-context.md | Domain & UX context | branch: product/UX |
| ... | ... | ... |
```

This keeps the memory-bank thin and predictable — no clever transformations, just templated derivation from a known schema.

### 5.3 `/scaffold-docs` — derive governance docs

**Trigger.** User runs `/scaffold-docs` (default) or `/scaffold-docs --full`.

**Default output** (5 docs, lightweight):
- `docs/PRD.md` — derived from Phases 1, 3
- `docs/SRS.md` — derived from Phases 4, 6, 7, 8 (lightweight: requirements list, not 553-line wabash version)
- `docs/BACKLOG.md` — derived from Phase 1 user stories + Phase 4 features
- `docs/PROJECT_PLAN.md` — derived from Phase 2 timeline + sprint structure
- `docs/adr/0001-record-architecture-decisions.md` — Michael Nygard ADR template, seeded with key Phase 4 decisions

**`--full` adds** (9 more docs):
- `RISK_REGISTER.md`, `THREAT_MODEL.md`, `TEST_STRATEGY.md`, `DEFINITION_OF_DONE.md`, `EVALS_PLAN.md`, `MODEL_CARD.md`, `PROMPT_GOVERNANCE.md`, `CUTOVER_PLAN.md`, `DEMO_RUNBOOK.md` — all lifted from wabash.

The `--full` set is for projects where governance overhead is justified (regulated domains, multi-stakeholder teams). Default keeps doc rot manageable.

### 5.4 `/spec` — author a slice spec

**Mechanics.** Interactive. Asks the user (or infers from `BACKLOG.md`) which slice/sprint/feature is next. Walks the user through the 9-section template (or the 4-section `--lite` template for trivial slices). Saves to `docs/specs/sprint-N/slice-M.md`.

**Variants:**

- `/spec` — default, 9-section heavy template. For substantive slices (new features, multi-file changes, behavior changes).
- `/spec --lite` — 4-section template. For trivial slices (renames, one-line fixes, trivial config edits, single-file additions with no new deps). User-decided, not auto-detected.
- `/spec --check [path]` — lints an existing spec against discipline rules. Runs after authoring or as a pre-commit step.

**Critical property (load-bearing).** The spec must be **self-contained**: a fresh Claude session pointed *only* at this file (with read access to repo source but no other context) must be able to implement it without asking the user any clarifying question. The verification protocol is exactly that — a fresh-session smoke test.

**Slice spec template (9 sections, refined from wabash's 7):**

The 9 sections are: Traces, Inputs, Outputs, **Files**, Behavior, Acceptance, **Test plan**, Verification, Not-in-this-slice. Two new sections (**Files** and **Test plan**) were added because wabash's lightweight versions left these implicit, and implicit fields are exactly what fresh-session implementers ask the user about.

Each section has a **strict sub-schema** (sub-headers and shape):

```markdown
# Slice N.M — <one-line name>

## Traces
Bulleted list. ≥1 entry required. Each: `- {doc}#{anchor}: {what this slice satisfies}`.

## Inputs

### Pre-conditions
State / migrations / config that must already exist.

### Data shapes consumed
Type signatures or refs (link to schema files / interfaces).

### Dependencies
Upstream slices (by id) and external libs/services (by name + version).

## Outputs

### Data shapes produced
Type signatures or refs.

### Post-conditions
State that must exist after this slice runs.

### Side effects
User-visible side effects (logs, metrics, notifications, emitted events).

## Files

### Created
- `path/to/file.ext` — one-line purpose.

### Modified
- `path/to/file.ext` — what changes.

### Deleted
- `path/to/file.ext` — why.

## Behavior

### Happy path
Numbered steps describing the logic. Pseudocode allowed but not required.

### Edge cases
Bullet list of edge cases + handling for each.

## Acceptance
Numbered list. Each: `- AC-N: {criterion}. Test: {test_file} > "{test_name}"`.

## Test plan

### Unit
List of test files + test names + brief descriptions.

### Integration
List of test files + scenarios (or "none" with rationale).

### Existing tests not to break
Tests that should continue passing (catches regressions).

## Verification

### Setup
Shell commands to prepare the environment.

### Steps
Numbered manual steps (curl, CLI invocations, UI clicks).

### Expected outputs
Literal expected text/data for each step.

## Not-in-this-slice
Bullet list of explicitly out-of-scope items, ideally with forward refs to slices that will cover them.
```

**Optional sections** (the author can include if useful, no requirement):

```markdown
## Author notes
Context preserved for the implementer — alternatives considered, prior attempts, gotchas.

## Risks / unknowns
Things the author isn't sure about; flags for the reviewer.

## Estimate
XS / S / M / L (rough, for sprint planning).
```

**Discipline rules** for fresh-session implementability:

1. **No dangling pronouns** — every "this", "that", "it" must have an anchor.
2. **Every reference resolves** — file paths exist (or are listed in `Files > Created`); type names are defined inline or linked.
3. **Acceptance has tests** — every `AC-N` references a test name in `Test plan`.
4. **Files manifest is exhaustive** — if it's not in `Files`, the implementer doesn't touch it.
5. **No "should be obvious"** — anything obvious-to-author may not be obvious-to-implementer; spell it out.

#### 5.4.1 Worked example (sample slice spec)

Concrete example to validate the template:

```markdown
# Slice 2.3 — JWT auth middleware on API routes

## Traces
- `docs/SRS.md#fr-auth-001`: All API routes must authenticate via JWT bearer tokens.
- `docs/adr/0003-auth-strategy.md`: Decision to use JWT (vs session cookies).
- `docs/BACKLOG.md#story-12`: As an API consumer, I need stable token-based auth.

## Inputs

### Pre-conditions
- User table exists with `id`, `email`, `password_hash` columns (slice 2.1).
- `JWT_SECRET` provisioned in env (slice 1.4).

### Data shapes consumed
- HTTP request with `Authorization: Bearer <token>` header.
- JWT payload: `{ sub: uuid, iat: int, exp: int }`.

### Dependencies
- Upstream slices: 2.1 (User model), 2.2 (Login endpoint).
- External: `jsonwebtoken@^9.0.0` (in package.json from slice 2.2).

## Outputs

### Data shapes produced
- `req.user` populated with `{ id: uuid, email: string }` on authenticated requests.

### Post-conditions
- Unauthenticated requests to `/api/*` return 401 `{ error: "unauthorized" }`.
- Expired tokens return 401 `{ error: "token_expired" }`.

### Side effects
- Audit log entry on auth failure (existing logger from slice 1.6).

## Files

### Created
- `src/middleware/auth.ts` — JWT verification middleware.
- `tests/middleware/auth.test.ts` — unit tests.

### Modified
- `src/app.ts` — wire middleware on `/api/*` (after CORS, before route handlers).
- `src/types/express.d.ts` — augment Express `Request` with `user` property.

### Deleted
(none)

## Behavior

### Happy path
1. Extract `Authorization: Bearer <token>` header.
2. Verify token with `JWT_SECRET` via `jsonwebtoken.verify`.
3. On success, look up user by `payload.sub`, populate `req.user = { id, email }`.
4. Call `next()`.

### Edge cases
- Missing `Authorization` header → 401 `unauthorized`.
- Malformed token → 401 `unauthorized`.
- Expired token (`TokenExpiredError`) → 401 `token_expired`.
- Valid token but user not in DB → 401 `unauthorized`.
- Routes outside `/api/*` (e.g. `/health`) → middleware not invoked.

## Acceptance
- AC-1: Valid token reaches handler with `req.user` populated. Test: `auth.test.ts > "valid token populates req.user"`.
- AC-2: Missing auth header → 401 `unauthorized`. Test: `auth.test.ts > "missing auth header → 401"`.
- AC-3: Malformed token → 401 `unauthorized`. Test: `auth.test.ts > "malformed token → 401"`.
- AC-4: Expired token → 401 `token_expired`. Test: `auth.test.ts > "expired token → 401"`.
- AC-5: Valid token, unknown user → 401 `unauthorized`. Test: `auth.test.ts > "unknown user → 401"`.
- AC-6: `/health` route not affected. Test: `health.test.ts > "health requires no auth"`.

## Test plan

### Unit
- `tests/middleware/auth.test.ts` — 5 tests (one per AC except AC-6); mock JWT tokens generated inline; mock User model via `jest.mock`.

### Integration
(none — middleware scope is narrow enough for unit coverage)

### Existing tests not to break
- `tests/routes/login.test.ts` — login flow.
- `tests/routes/health.test.ts` — adds AC-6.

## Verification

### Setup
```
npm install
export JWT_SECRET="test-secret"
npm run dev   # starts on :3000
```

### Steps
1. `curl localhost:3000/api/users` (no auth)
2. `curl -X POST localhost:3000/auth/login -d '{"email":"...","password":"..."}'` — capture returned token.
3. `curl localhost:3000/api/users -H "Authorization: Bearer <token>"`
4. `curl localhost:3000/health`

### Expected outputs
1. `HTTP/1.1 401`, body `{"error": "unauthorized"}`
2. `HTTP/1.1 200`, body `{"token": "<jwt>"}`
3. `HTTP/1.1 200`, body `{"users": [...]}`
4. `HTTP/1.1 200`, body `{"status": "ok"}`

## Not-in-this-slice
- Refresh token flow → slice 2.4.
- Role-based authorization → slice 3.1.
- Rate limiting on auth failures → slice 3.7.
- Logout / session revocation → slice 2.5.
```

#### 5.4.2 `/spec --lite` template (4 sections, for trivial slices)

For slices where the 9-section ceremony is overhead — renames, one-line bug fixes, trivial config edits, single-file additions with no new dependencies. User-decided, not auto-detected.

```markdown
# Slice N.M-lite — <one-line name>

## Traces
≥1 ref into PRD/SRS/Backlog/ADR or upstream slice.

## Description
What changes, where (file paths inline), and why. File modifications listed inline.

## Acceptance
Bullet list. Each: criterion + how verified (test name or manual command).

## Verification
Quick verification commands (one or two lines).
```

**Worked example:**

```markdown
# Slice 4.2-lite — Rename `getUserById` → `findUserById` for symmetry with `findUsersByOrg`

## Traces
- `docs/adr/0007-naming-conventions.md`: prefer `find*` for nullable returns.

## Description
Rename `getUserById` to `findUserById` in `src/repositories/user.ts`; update 6 callers in `src/services/`. No behavior change.

## Acceptance
- AC-1: All callers updated; no `getUserById` references remain. Verified: `grep -r getUserById src/` returns nothing.
- AC-2: Existing tests pass. Verified: `npm test`.

## Verification
```
grep -r getUserById src/   # expect empty
npm test                   # expect green
```
```

A lite slice should fit comfortably in <30 lines. If it grows past that, promote to the full 9-section template.

#### 5.4.3 `/spec --check` — lint rules

Mechanical validation of discipline rules. Output mirrors `/implementation-check`: ERROR (must fix) / WARNING (should fix) / INFO (consider).

**Tier 1 — mechanical, ship in v1:**

| Rule | Severity | Description |
|---|---|---|
| L-1 | ERROR | All required sections present (full or lite, depending on detected variant). |
| L-2 | ERROR | All required sections non-empty. |
| L-3 | ERROR | `## Traces` has ≥1 entry matching pattern `- .+#.+: .+`. |
| L-4 | ERROR | Every `AC-N` line has a `Test:` reference (full template only). |
| L-5 | ERROR | Every test name in Acceptance appears in `## Test plan`. |
| L-6 | ERROR | `## Files` has `### Created` / `### Modified` / `### Deleted` sub-headers (any can be empty/`(none)`). |
| L-7 | WARNING | File paths mentioned in `## Behavior` appear in `## Files > Created` or `## Files > Modified`. |
| L-8 | WARNING | `## Inputs > Dependencies` items follow `slice <id>` or `<package>@<version>` shape. |
| L-9 | INFO | Spec author included optional sections (Author Notes / Risks / Estimate). |

**Tier 2 — heuristic, future work:**

| Rule | Severity | Description |
|---|---|---|
| L-10 | WARNING | Heuristic dangling-pronoun detection (no "this", "that", "it" within first 6 words of a sentence). |
| L-11 | INFO | Type names in `## Inputs / ## Outputs` either defined inline or referenced in repo. |
| L-12 | WARNING | `Verification > Steps` and `Verification > Expected outputs` have matching counts. |

Tier 1 is enough to enforce the load-bearing properties. Tier 2 is future work to layer on once we observe real failure modes.

**Pre-commit integration.** Optional: `/spec --check` can be wired into a git pre-commit hook so specs can't be committed with ERRORs. Off by default (opt-in via `.claude/settings.json`).

### 5.5 `/implement` — TDD execution

**Mechanics.** Reads the active slice spec. For each Acceptance criterion:
1. Writes a failing test (red).
2. Writes minimum code to pass (green).
3. Refactors against `code-patterns` (refactor).

**Escape hatch:** `/implement --spike` skips strict TDD for exploratory code, but flags the slice as "spike" in `06-progress.md` so it can be re-done properly later.

### 5.6 `/implementation-check` — enforcement gate

**Lifted directly from wabash.** Validates:
- Every Acceptance criterion has a passing test.
- Every Output declared in the spec exists.
- `code-patterns` rules: ≤80-LOC functions, no premature abstraction, FP-default, classes only when state demands.
- Hexagonal boundaries (if applicable per project).

Reports as ERROR (must fix) / WARNING (should fix) / INFO (consider).

### 5.7 `/code-review` and `/commit`

`/code-review` — runs `code-patterns` skill against staged changes; reports issues.
`/commit` — disciplined commit message via HEREDOC, secret scan, no co-author by default.

### 5.8 Skills bundled in this plugin

Two project-level skills ship with the scaffolding plugin. The mentor / pair-programming behavior previously listed here is **out of scope** — see `SPEC-ai-mentor.md` for the separate AI Mentor plugin (user-level, installed globally so it applies to every task and project).

#### 5.8.1 `code-patterns` (locked rule list)

Project-agnostic invariants. Wired into `/code-review` (advisory) and `/implementation-check` (enforcing). Each rule is configurable per-project via `.claude/settings.json` (e.g., raise CP-1's line limit).

| ID | Rule |
|---|---|
| CP-1 | Functions ≤80 lines; otherwise extract. |
| CP-2 | No premature abstraction — 3 similar lines beat extraction-for-2. |
| CP-3 | Functional by default; classes only when state must persist. |
| CP-4 | No comments unless the *why* is non-obvious. No "what" comments. |
| CP-5 | Don't add error handling for impossible scenarios; trust internal contracts. Validate only at system boundaries. |
| CP-6 | No half-finished implementations or commented-out code blocks. |
| CP-7 | No backwards-compat shims when you can just change the code. |
| CP-8 | Fix root causes, not symptoms. No `--no-verify` to silence hook failures. |
| CP-9 | Identifiers self-document; rename rather than comment. |

`/code-review` flags violations as suggestions; `/implementation-check` flags them as ERROR/WARNING per project policy. By default CP-1..CP-9 are all active in `/implementation-check`; per-project overrides in `.claude/settings.json` map rule IDs to severity (`error` / `warning` / `off`).

#### 5.8.2 `git-workflow` (stub)

Ships as a stub with frontmatter only and a comment block listing dimensions to fill in later: branching strategy (trunk-based / feature / GitFlow), commit format (conventional / freeform), merge strategy (squash / merge / rebase), PR review requirements. Content deferred to a future iteration session — the user is intentionally not committing to one workflow yet.

The `/commit` slash command provides commit-message discipline (HEREDOC, secret scan, no co-author by default) independently of `git-workflow`, so commit hygiene works even with the stub.

---

## 6. Plugin layout

```
claude-agent-scaffolding/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── code-patterns/SKILL.md
│   └── git-workflow/SKILL.md          # stub
├── commands/
│   ├── onboard.md
│   ├── scaffold-project.md
│   ├── scaffold-docs.md
│   ├── spec.md
│   ├── implement.md
│   ├── implementation-check.md
│   ├── code-review.md
│   └── commit.md
├── templates/
│   ├── onboarding-questions/phases.yaml
│   ├── master-spec/{MASTER-SPEC,EXECUTIVE-SUMMARY}.md.tmpl
│   ├── memory-bank/{00..08}-*.md.tmpl + index.md.tmpl + WORKFLOW.md.tmpl
│   ├── claude-md/CLAUDE.md.tmpl
│   ├── docs-minimal/{PRD,SRS,BACKLOG,PROJECT_PLAN}.md.tmpl + adr/0001-*.md.tmpl
│   ├── docs-full/{RISK_REGISTER,THREAT_MODEL,TEST_STRATEGY,DEFINITION_OF_DONE,EVALS_PLAN,MODEL_CARD,PROMPT_GOVERNANCE,CUTOVER_PLAN,DEMO_RUNBOOK}.md.tmpl
│   └── slice-spec/{README,slice-template}.md.tmpl
├── docs/
│   └── archive/SPEC-v1.md             # the old 1,016-line marketplace design
├── SPEC.md                            # this file
├── SPEC-ai-mentor.md                  # companion AI Mentor plugin spec
├── README.md                          # rewritten for single-plugin model
├── LICENSE
└── .gitignore
```

---

## 7. Load-bearing files

These three files determine whether the plugin works at all. Everything else is mechanical.

1. **`templates/onboarding-questions/phases.yaml`** — the 10-phase question bank. Wrong questions → wrong master spec → wrong everything downstream.
2. **`templates/master-spec/MASTER-SPEC.md.tmpl`** — schema the master spec resolves to. Has to encode every phase's answers cleanly so `/scaffold-*` can read it without ambiguity.
3. **`templates/slice-spec/slice-template.md.tmpl`** — the 9-section spec template. Determines whether Opus → Sonnet handoff works in a fresh session.

---

## 8. Workflows

### 8.1 Greenfield happy path

```
mkdir my-project && cd my-project && git init
claude
> /onboard                    # ~30 min conversation, 10 phases
> /scaffold-project           # produces .claude/memory-bank/ + CLAUDE.md
> /scaffold-docs              # produces docs/{PRD,SRS,BACKLOG,PROJECT_PLAN,adr/}
> /spec                       # author sprint-1/slice-1
> /implement                  # TDD loop
> /implementation-check       # passes
> /code-review                # clean
> /commit                     # commits
```

### 8.2 Spec-handoff path (Opus → Sonnet)

```
# Session A (Opus)
> /spec                       # author docs/specs/sprint-1/slice-3.md
# (session ends)

# Session B (Sonnet, fresh)
> /implement docs/specs/sprint-1/slice-3.md
# (Sonnet should NOT ask the user any clarifying questions)
> /implementation-check
> /commit
```

If Session B asks the user a clarifying question, the slice template failed.

---

## 9. Open questions / deferred decisions

| # | Question | Status / Notes |
|---|---|---|
| Q1 | **Z2 enforcement mechanism** | Moved to AI Mentor plugin spec (`SPEC-ai-mentor.md`). Out of scope here. |
| Q2 | **`git-workflow` skill content** | Stub deferred per user direction. Trunk-based vs GitFlow / conventional commits / merge strategy — to iterate later. |
| Q3 | **TDD strictness** | Open. Strict red/green/refactor with `--spike` escape hatch is currently the design. |
| Q4 | **Plugin distribution** | Open. Git URL? marketplace.json? Defer until plugin works locally. |
| Q5 | **Per-stack `code-patterns` variations** | Open. Currently project-agnostic; could specialize (Python/TS/Go) but adds maintenance. |
| Q6 | **AI Mentor plugin spec** | Tracked in `SPEC-ai-mentor.md` — needs its own iteration session. |

---

## 10. Risks

- **R1 (high):** Slice-spec template too loose → handoff fails. *Mitigation:* design verification specifically tests this seam.
- **R2 (medium):** Onboarding too long → users abandon mid-flow. *Mitigation:* 50 Qs over 5 Qs/phase; allow "TBD"; allow resume.
- **R3 (medium):** Master spec drift → docs become inconsistent with reality. *Mitigation:* `/implementation-check` could (future) verify master-spec invariants.
- **R4 (low):** Doc rot for `--full` set. *Mitigation:* it's opt-in; default is lean.
- **R5 (medium):** `code-patterns` rules too strict (e.g., 80-LOC limit) → friction. *Mitigation:* configurable in `.claude/settings.json`.

---

## 11. Verification

End-to-end smoke test in `/tmp/scaffolding-smoke`:

1. Empty dir + `git init` + plugin install.
2. Run full Layer 1 (`/onboard` → `/scaffold-project` → `/scaffold-docs`); verify expected files exist with non-empty content.
3. Run Layer 2 for one slice (`/spec` → `/implement` → `/implementation-check` → `/commit`).
4. **Handoff test:** open a new Claude session pointed at the slice spec only; have it implement; assert no clarifying questions.
5. Run `/scaffold-docs --full` in a separate test repo; verify all 14 docs.

---

## 12. Build sequence

Mostly mechanical once load-bearing files are right:

1. ~~Archive `SPEC.md` → `docs/archive/SPEC-v1.md`. Rewrite `README.md`.~~ *(Done; v1 archived. README rewrite still pending.)*
2. Author `templates/onboarding-questions/phases.yaml` *(load-bearing)*.
3. Author `templates/master-spec/MASTER-SPEC.md.tmpl` *(load-bearing)*.
4. Author `templates/slice-spec/{slice-template,README}.md.tmpl` *(load-bearing)*.
5. Author `templates/memory-bank/*` (lift wabash, generalize).
6. Author `templates/claude-md/CLAUDE.md.tmpl`.
7. Author `templates/docs-minimal/*`.
8. Author `templates/docs-full/*`.
9. Author Layer 1 commands (`onboard`, `scaffold-project`, `scaffold-docs`).
10. Author Layer 2 commands (`spec`, `implement`, `implementation-check`, `code-review`, `commit`).
11. Author skills (`code-patterns` with CP-1..CP-9, stub `git-workflow`).
12. Author `.claude-plugin/plugin.json`.
13. Verify (§11).

---

## Iteration log

- **v0.1 (2026-04-25):** Initial draft after exploration of `wabash` and ProjectPulse references.
- **v0.2 (2026-04-25):** Refined onboarding (§5.1) — restructured to 10 phases (Domain & Data Model and Operations promoted; Security moved earlier; BE+FE merged; DevOps+Deployment merged). Added project-class enum + light-branching gates. Drafted full question bank (~54 Qs) for review. Added resume mechanism via `.claude/.onboarding-state.json`.
- **v0.3 (2026-04-25):** Added per-phase synthesize-and-confirm step (Claude recaps, user edits in place). Phase 6 made conditional: 4-question UI path vs 2-question DX path for headless projects. Question count held at ~54.
- **v0.4 (2026-04-25):** Refined slice-spec template (§5.4) — 9 sections (added **Files** and **Test plan**), strict sub-schema per section, optional Author Notes / Risks / Estimate sections. Added 5 discipline rules for fresh-session implementability and a worked example (JWT auth middleware) to validate the template.
- **v0.5 (2026-04-25):** Added `/spec --lite` 4-section variant for trivial slices (with worked example: rename refactor) and `/spec --check` linter with 9 tier-1 rules + 3 tier-2 future heuristics. Wrote pre-commit integration as opt-in.
- **v0.6 (2026-04-25):** Fleshed out §5.2 — MASTER-SPEC.md schema (sectioned markdown + `**Key:** value` enums + HTML-comment phase markers); per-file memory-bank shapes with derivation table; `/scaffold-project` algorithm (8 steps, idempotent, never touches live files); CLAUDE.md tiered preload (Tier 0 + 5 branch rules); worked example for `todo-cli`. Aligned phase numbers in derivation rules with v0.2 phase taxonomy.
- **v0.7 (2026-04-26):** Removed `pair-program` from this plugin entirely after the user identified that the original skill is **AI Mentor** (4-pillar framework: Intelligent Laziness / Hill / Gym / Fool) and belongs in a separate user-level plugin. Locked `code-patterns` rule list (CP-1..CP-9) per-project configurable. Kept `git-workflow` as stub. Companion spec (`SPEC-ai-mentor.md`) tracks the AI Mentor plugin separately.
- **v0.8 (2026-04-26):** Promoted from plan-file embedded draft into a standalone `SPEC.md` file. Companion spec `SPEC-ai-mentor.md` created in parallel. Old marketplace design archived to `docs/archive/SPEC-v1.md`.
