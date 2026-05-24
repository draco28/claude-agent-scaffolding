# Example walkthrough: `/scaffold-docs` on `todo-cli`

A concrete trace of `/scaffold-docs` deriving the v0.1.0 governance-doc bundle from a closed `MASTER-SPEC.md`. Same **todo-cli** project as the other walkthroughs (Rust CLI, `project_class = "CLI tool"`, `phase_9.3.1 = no` in the default scenario — toggled to `yes` in the variant section to demonstrate the LLM gate).

Two variants are shown: **default `/scaffold-docs`** (5 docs) and **`/scaffold-docs --full`** (14 docs total, with the 3 LLM-gated docs conditional on Phase 9.3.1). Both run in single-repo mode here; the manifest-routing edge cases live in `edge-cases.md`.

---

## Setup

```
$ cd ~/work/todo-cli
$ ls
MASTER-SPEC.md  EXECUTIVE-SUMMARY.md  CLAUDE.md  .claude/  README.md  Cargo.toml  src/
$ /scaffold-docs
```

`commands/scaffold-docs.md` exports `$ARGUMENTS=""` and routes to `scaffold-onboard:scaffolding-governance-docs`. Skill body runs §1–§9 in order.

---

## Step 1 — Validate MASTER-SPEC + read state

```bash
spec_path="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
# → /Users/<you>/work/todo-cli/MASTER-SPEC.md   (manifest absent → cwd fallback per §10.3)
sf_spec_validate "$spec_path"
# → exit 0
```

Read the LLM gate answer:

```bash
uses_llm="$(sf_state_read_answer phase_9.3.1)"
# → "no"   (todo-cli does not use LLM features)
```

`uses_llm=false` flows into `_docs_args`. The 3 LLM-gated `--full` docs (`EVALS_PLAN.md`, `MODEL_CARD.md`, `PROMPT_GOVERNANCE.md`) will be skip-with-reason'd on the `--full` variant; on the default run they're not in the doc set at all.

---

## Step 2 — Default run: 5 docs

Skill calls `sf_docs_derive` (no `--full`). For each of the 5 default docs, the helper resolves the destination via `sf_resolve_output_path <logical_name> docs/<file>`, renders the template, and writes atomically. In single-repo mode all 5 resolve to cwd:

| File | Logical name | Resolved path |
|---|---|---|
| `PRD.md` | `prd` → canonical | `/Users/<you>/work/todo-cli/docs/PRD.md` |
| `SRS.md` | `srs` → canonical | `/Users/<you>/work/todo-cli/docs/SRS.md` |
| `BACKLOG.md` | `backlog` → canonical | `/Users/<you>/work/todo-cli/docs/BACKLOG.md` |
| `PROJECT_PLAN.md` | `project_plan` → canonical | `/Users/<you>/work/todo-cli/docs/PROJECT_PLAN.md` |
| `ADR-0001.md` | `product_adrs` → canonical | `/Users/<you>/work/todo-cli/docs/adr/0001-record-architecture-decisions.md` |

The "canonical" routing destination in single-repo mode falls back to `$(pwd)` (per §6 resolution behavior + SPEC §10.3). In dual-repo mode it resolves to the canonical-repo root from the manifest's `routing.<logical_name>` entry.

**Content shape — `PROJECT_PLAN.md`:** this is the **v0.1.0 Phase-2-Strategy-derived TIMELINE document — UNCHANGED**. Sections (in order, from the v0.1.0 template):

1. `## Timeline / milestones` — 3 weeks to MVP, week-by-week breakdown sourced from `phase_2.1.1` and the MVP cut from `phase_1.3.2`.
2. `## Resources` — solo developer, $0/month budget (sourced from `phase_2.1.2` + `phase_2.2.1`).
3. `## Risks summary` — three top risks: sqlite schema migration, FTS5 ranking quality, non-cargo packaging (sourced from `phase_2.2.2`).
4. `## Success metric` — 100 cargo installs in 60 days (`phase_2.3.1`).

**Critical:** `PROJECT_PLAN.md` does NOT contain Phase → Sprint → Vertical-Slice hierarchy. No `Phase 1: <name>` headings shaped like the R1 grammar, no `Sprint 1.1:` sub-headings, no slice IDs, no `auto:`/`user:` demo-criteria grammar. That hierarchy lives in `ROADMAP.md` (a separate file emitted by `planning-project-roadmap`, SPEC §5.4). See §5 of the skill body — this constraint is load-bearing.

**`ADR-0001.md`:** the v0.1.0 "Record architecture decisions in ADRs" initial ADR — boilerplate plus a stub for the first project-specific architectural decision (suggested topic surfaced from Phase 5 answers, e.g., "use sqlite + FTS5 for full-text search").

**Cross-skill boundary explicit:** `ROADMAP.md` is NOT written by this skill. Even running `/scaffold-docs --full` will not produce a `ROADMAP.md`. The user reaches `ROADMAP.md` via `/plan-roadmap` after `/onboard` closes (the v0.2 onboarding close-message suggests this as the next step). If the user asks during `/scaffold-docs` whether the R1 hierarchy will be authored, surface:

> No — `/scaffold-docs` emits the v0.1.0 governance bundle (PRD / SRS / BACKLOG / PROJECT_PLAN / ADR-0001). The Phase → Sprint → Vertical-Slice hierarchy lives in `ROADMAP.md` and is authored interactively by `/plan-roadmap` after onboarding closes.

---

## Step 3 — `--full` variant: 14 docs (9 added)

Same setup, but the trigger is `/scaffold-docs --full`. `$ARGUMENTS=" --full"`. Skill parses, calls `sf_docs_derive --full`. The 5 default docs are emitted as in Step 2, plus 9 more:

### 6 always-on `--full` docs

| File | Logical name | Resolved path (single-repo) |
|---|---|---|
| `RISK_REGISTER.md` | `product_adrs` → canonical | `<cwd>/docs/RISK_REGISTER.md` |
| `THREAT_MODEL.md` | `product_adrs` → canonical | `<cwd>/docs/THREAT_MODEL.md` |
| `TEST_STRATEGY.md` | `product_adrs` → canonical | `<cwd>/docs/TEST_STRATEGY.md` |
| `DEFINITION_OF_DONE.md` | `process_adrs` → ai_workspace | `<cwd>/docs/DEFINITION_OF_DONE.md` (single-repo fallback) |
| `CUTOVER_PLAN.md` | `product_adrs` → canonical | `<cwd>/docs/CUTOVER_PLAN.md` |
| `DEMO_RUNBOOK.md` | `process_adrs` → ai_workspace | `<cwd>/docs/DEMO_RUNBOOK.md` (single-repo fallback) |

Note `process_adrs` is the only logical name that routes to `ai_workspace` (not canonical) — in dual-repo mode `DEFINITION_OF_DONE.md` + `DEMO_RUNBOOK.md` land in the ai_workspace tree, separate from the rest of the bundle. In single-repo mode all 14 collapse to cwd.

### 3 LLM-gated docs (Phase 9.3.1 == yes)

For todo-cli, `phase_9.3.1 = "no"` (no LLM features). The gate fails. `sf_docs_derive` logs:

> LLM-gated --full docs skipped (phase 9.3.1 != yes): EVALS_PLAN.md, MODEL_CARD.md, PROMPT_GOVERNANCE.md

Skill body surfaces this **skip-with-reason** to the user (per §4.2 contract + eval S2):

> Skipped 3 LLM-gated docs because Phase 9.3.1 (`uses_llm`) = "no":
>   - `EVALS_PLAN.md` — would route to `product_adrs` → canonical
>   - `MODEL_CARD.md` — would route to `product_adrs` → canonical
>   - `PROMPT_GOVERNANCE.md` — would route to `process_adrs` → ai_workspace
>
> If your project will use LLM features, re-run `/onboard --resume` to flip Phase 9.3.1 to "yes", then re-run `/scaffold-docs --full`.

Silent omission is a FAIL per eval S2 — the skip-with-reason must be visible.

### Variant: Phase 9.3.1 == yes

Imagine a different project, **doc-summarizer-cli**, that uses an LLM for summarization. Its state has `phase_9.3.1 = "yes"`. On `/scaffold-docs --full`, all 3 LLM-gated docs ALSO emit:

| File | Logical name | Resolved path (single-repo) |
|---|---|---|
| `EVALS_PLAN.md` | `product_adrs` → canonical | `<cwd>/docs/EVALS_PLAN.md` |
| `MODEL_CARD.md` | `product_adrs` → canonical | `<cwd>/docs/MODEL_CARD.md` |
| `PROMPT_GOVERNANCE.md` | `process_adrs` → ai_workspace | `<cwd>/docs/PROMPT_GOVERNANCE.md` (single-repo fallback) |

Total: 14 docs emitted. No skip-with-reason — gate satisfied.

The LLM-gate classification (which 3 are gated) is **owned by `sf_docs_derive` in `lib/docs.sh`** — that's the authoritative list per §4.2. If a point release adds an always-on `--full` doc, update §4.2 in the same patch to keep skill body and helper aligned.

---

## Step 4 — Routing recap (the 6 logical-name destinations)

Per SPEC §10.1 routing table, this skill emits across exactly **6 logical names** spanning 14 docs:

| Logical name | Default destination | Docs |
|---|---|---|
| `prd` | canonical | `PRD.md` |
| `srs` | canonical | `SRS.md` |
| `backlog` | canonical | `BACKLOG.md` |
| `project_plan` | canonical | `PROJECT_PLAN.md` (v0.1.0 timeline doc) |
| `product_adrs` | canonical | `ADR-0001.md`, `RISK_REGISTER.md`, `THREAT_MODEL.md`, `TEST_STRATEGY.md`, `CUTOVER_PLAN.md`, `EVALS_PLAN.md`, `MODEL_CARD.md` |
| `process_adrs` | ai_workspace | `DEFINITION_OF_DONE.md`, `DEMO_RUNBOOK.md`, `PROMPT_GOVERNANCE.md` |

`process_adrs` is the unique destination — every other doc routes to canonical. This is deliberate: process ADRs (Definition of Done, demo runbook, prompt governance) describe how the team works rather than the product itself, so they live in the AI workspace alongside memory-bank / CLAUDE.md rather than in the canonical product repo (per SPEC §10.1 rationale).

**Lane discipline:** every doc this skill writes must resolve through one of the 6 logical names above. This skill **MUST NOT** use the `roadmap` logical name — that belongs to `planning-project-roadmap` (per §5 + §10 anti-patterns).

---

## Step 5 — Close summary

After all writes complete, skill emits a summary:

```
/scaffold-docs --full complete.

Default docs (5):
  /Users/<you>/work/todo-cli/docs/PRD.md
  /Users/<you>/work/todo-cli/docs/SRS.md
  /Users/<you>/work/todo-cli/docs/BACKLOG.md
  /Users/<you>/work/todo-cli/docs/PROJECT_PLAN.md
  /Users/<you>/work/todo-cli/docs/adr/0001-record-architecture-decisions.md

Full docs added (6 always-on):
  /Users/<you>/work/todo-cli/docs/RISK_REGISTER.md
  /Users/<you>/work/todo-cli/docs/THREAT_MODEL.md
  /Users/<you>/work/todo-cli/docs/TEST_STRATEGY.md
  /Users/<you>/work/todo-cli/docs/DEFINITION_OF_DONE.md
  /Users/<you>/work/todo-cli/docs/CUTOVER_PLAN.md
  /Users/<you>/work/todo-cli/docs/DEMO_RUNBOOK.md

LLM-gated docs SKIPPED (phase_9.3.1 = "no"): EVALS_PLAN.md, MODEL_CARD.md, PROMPT_GOVERNANCE.md.

ROADMAP.md is NOT emitted by /scaffold-docs. Run /plan-roadmap to author the
Phase → Sprint → Vertical-Slice hierarchy (R1 input for scaffold-dev).
```

The trailing `ROADMAP.md` note is load-bearing — users who ran `/scaffold-docs` looking for the R1 hierarchy need to be routed to `/plan-roadmap` without ambiguity.

---

## What this walkthrough demonstrates

- **5 default + 9 `--full` = 14 docs.** The 5 default docs are the always-on minimum; `--full` adds 6 always-on docs + 3 LLM-gated docs (gated on `phase_9.3.1 == yes`).
- **`PROJECT_PLAN.md` is the v0.1.0 timeline doc — UNCHANGED.** Phase-2-Strategy-derived (timeline / resources / risks / success metric). No R1 hierarchy. No `auto:`/`user:` demo-criteria grammar.
- **`ROADMAP.md` is a SEPARATE doc owned by `planning-project-roadmap`.** This skill does not emit it under any flag.
- **Routing flows through 6 logical names.** 5 route to canonical, 1 (`process_adrs`) routes to ai_workspace. `roadmap` is NOT this skill's territory.
- **LLM-gated docs are skip-with-reason, not silently omitted.** Surface the gate name + the answer that didn't satisfy it.
- Edge cases (manifest absent, re-generate over user edits, MASTER-SPEC missing) live in `references/edge-cases.md`.
