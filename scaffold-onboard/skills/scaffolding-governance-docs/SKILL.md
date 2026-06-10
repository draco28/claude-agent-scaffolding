---
name: scaffolding-governance-docs
description: Derive governance docs (PRD, SRS, BACKLOG, PROJECT_PLAN, ADR-0001, +9 `--full`) from MASTER-SPEC.md via LLM sub-agent synthesis (the only derivation path — no deterministic fallback as of v0.8.0). Use this when the user wants to scaffold governance docs, generate PRD/SRS, run /scaffold-docs, derive BACKLOG/ADRs, or regenerate the bundle after MASTER-SPEC changes. Manifest-routed (canonical product docs vs ai_workspace process ADRs). NOT the Phase→Sprint→Vertical-Slice ROADMAP.md — that's the planning-project-roadmap skill.
---

# scaffolding-governance-docs

You wrap scaffold-onboard's v0.1.0 governance-doc derivation pipeline (`/scaffold-docs` → 5 default + up to 9 `--full` artifacts) and add two v0.2-specific responsibilities: **manifest-aware per-doc routing** (different logical names route to canonical vs ai_workspace per SPEC §10.1) and **lane discipline against the new R1 roadmap doc** (`ROADMAP.md` is a separate file authored by a different skill — this skill must not touch it, and its own `PROJECT_PLAN.md` output must remain the v0.1.0 timeline doc unchanged).

Governance docs are authored by sub-agent **synthesis** (§11 — the only path as of v0.8.0); bash helpers in `lib/routing.sh`, `lib/parser.sh`, and `lib/render.sh` do the mechanical I/O: manifest resolution, MASTER-SPEC validation, EXEC-SUMMARY write-back/staleness. The judgment work — refusing to derive from an invalid spec, surfacing per-doc destinations, deciding when `--regenerate` is too destructive — happens here, in conversation.

---

## 1. Overview

When invoked, you read `MASTER-SPEC.md`, validate it with `sf_spec_validate`, and emit the v0.1.0 governance-doc bundle. The default set is 5 docs: `PRD.md`, `SRS.md`, `BACKLOG.md`, `PROJECT_PLAN.md`, and `ADR-0001.md`. With `--full` you also emit 9 additional docs (`RISK_REGISTER.md`, `THREAT_MODEL.md`, `TEST_STRATEGY.md`, `DEFINITION_OF_DONE.md`, `CUTOVER_PLAN.md`, `DEMO_RUNBOOK.md`, plus three LLM-gated ones — `EVALS_PLAN.md`, `MODEL_CARD.md`, `PROMPT_GOVERNANCE.md` — emitted only when the Phase 9.3.1 answer is `yes`). `SRS.md` mints stable `FR-N` / `NFR-N` IDs and `BACKLOG.md` mints stable `BACKLOG-N` IDs so a traceability-first project can run `/scaffold-docs` before `/plan-roadmap` and cite those IDs from ROADMAP vertical slices.

---

## 2. When to use

**Trigger phrases (description-match):**

- `/scaffold-docs` (slash command — see §8 for the `$ARGUMENTS` env-var bridge)
- "scaffold governance docs", "generate PRD", "generate SRS", "derive governance docs"
- "regenerate PRD/SRS/BACKLOG", "rebuild governance bundle from MASTER-SPEC"
- "author ADR-0001", "set up the BACKLOG", "derive PROJECT_PLAN from MASTER-SPEC"

**Do NOT auto-invoke when:**

- `MASTER-SPEC.md` does not exist yet, or `sf_spec_validate` reports it as invalid. Governance docs are derived FROM MASTER-SPEC; without a valid spec there is nothing to derive. Route the user to `Skill(scaffold-onboard:onboarding-project)` (or `/onboard`) and stop.
- The user wants to author the **R1 Phase → Sprint → Vertical-Slice hierarchy** — that is *not* a governance doc and *not* `PROJECT_PLAN.md`. It belongs to `scaffold-onboard:planning-project-roadmap` (SPEC §5.4), reached via `/plan-roadmap`. The R1 doc is named `ROADMAP.md`, lives at a different routing destination, and is owned by a different skill. See §5 below for the explicit lane boundary.
- The user wants memory-bank / CLAUDE.md derivation — that's `scaffold-onboard:scaffolding-memory-bank` (SPEC §5.2) reached via `/scaffold-project`.
- The user wants to validate-only an existing MASTER-SPEC — that's `scaffold-onboard:validating-master-spec` (SPEC §5.7).
- The user wants to author or edit machine-checkable rules — that's `scaffold-onboard:authoring-machine-checkable-rules` (SPEC §5.5). This skill never touches `03-code-patterns.md`.

If the user types something ambiguous like "set up the project plan" and MASTER-SPEC exists, ask: *"Do you mean the v0.1.0 Phase-2-Strategy-derived timeline doc (`PROJECT_PLAN.md`, emitted by `/scaffold-docs`), or the new Phase → Sprint → Vertical-Slice hierarchy (`ROADMAP.md`, emitted by `/plan-roadmap`)?"* — they're two different files with two different owners.

---

## 3. Prerequisites

Before any derivation step:

1. **MASTER-SPEC.md must exist** at the routing destination. Resolve via `sf_resolve_output_path master_spec MASTER-SPEC.md` and confirm the file is present. If absent, surface the routing prompt from §2 and stop.
2. **MASTER-SPEC.md must validate.** Call `sf_spec_validate <path>` (lib/parser.sh — unchanged from v0.1.0). Non-zero exit means the spec is malformed (missing phase header, broken YAML frontmatter, unknown project_class enum, etc.). Surface the validator's stderr verbatim to the user and stop — do not attempt to derive from a broken spec; templates will silently emit `{{placeholder}}` artifacts that look complete but aren't.
3. **State file present (recommended).** The project-scoped `$(sf project_data_dir)/onboarding-state.json` provides the gate answers that drive conditional template substitution (project_class branches, the LLM gate at Phase 9.3.1). If the state file is absent (user hand-authored MASTER-SPEC outside `/onboard`), proceed with conservative defaults: treat Phase 9.3.1 as `no` (no LLM-gated docs) and surface one warning: *"No onboarding state file found — proceeding with conservative defaults. Re-run after `/onboard` to enable LLM-gated `--full` docs."*

---

## 4. Default (5 docs) vs `--full` (14 docs)

Your job is to dispatch synthesis sub-agents for the right doc set (§11). The doc catalog:

### 4.1 Default set (always emitted) — 5 docs

| File | Source | Routing logical name |
|---|---|---|
| `PRD.md` | `templates/docs-minimal/PRD.md.tmpl` | `prd` → canonical |
| `SRS.md` | `templates/docs-minimal/SRS.md.tmpl` | `srs` → canonical |
| `BACKLOG.md` | `templates/docs-minimal/BACKLOG.md.tmpl` | `backlog` → canonical |
| `PROJECT_PLAN.md` | `templates/docs-minimal/PROJECT_PLAN.md.tmpl` | `project_plan` → canonical |
| `ADR-0001.md` (initial architecture decision) | `templates/docs-minimal/adr/0001-record-architecture-decisions.md.tmpl` | `product_adrs` → canonical |

### 4.2 `--full` adds 9 more docs

Six are always-on under `--full` (no LLM gate):

| File | Source | Routing logical name |
|---|---|---|
| `RISK_REGISTER.md` | `templates/docs-full/RISK_REGISTER.md.tmpl` | `product_adrs` → canonical |
| `THREAT_MODEL.md` | `templates/docs-full/THREAT_MODEL.md.tmpl` | `product_adrs` → canonical |
| `TEST_STRATEGY.md` | `templates/docs-full/TEST_STRATEGY.md.tmpl` | `product_adrs` → canonical |
| `DEFINITION_OF_DONE.md` | `templates/docs-full/DEFINITION_OF_DONE.md.tmpl` | `process_adrs` → ai_workspace |
| `CUTOVER_PLAN.md` | `templates/docs-full/CUTOVER_PLAN.md.tmpl` | `product_adrs` → canonical |
| `DEMO_RUNBOOK.md` | `templates/docs-full/DEMO_RUNBOOK.md.tmpl` | `process_adrs` → ai_workspace |

Three are **LLM-gated** by the Phase 9.3.1 answer (`uses_llm = "yes"` or `"true"`); emitted only when the gate passes:

| File | Source | Routing logical name | Gate |
|---|---|---|---|
| `EVALS_PLAN.md` | `templates/docs-full/EVALS_PLAN.md.tmpl` | `product_adrs` → canonical | Phase 9.3.1 == yes |
| `MODEL_CARD.md` | `templates/docs-full/MODEL_CARD.md.tmpl` | `product_adrs` → canonical | Phase 9.3.1 == yes |
| `PROMPT_GOVERNANCE.md` | `templates/docs-full/PROMPT_GOVERNANCE.md.tmpl` | `process_adrs` → ai_workspace | Phase 9.3.1 == yes |

When the LLM gate fails (Phase 9.3.1 != yes), do NOT dispatch the three LLM-gated `--full` docs; surface a skip-with-reason to the user so silent omission is visible — silent omission of LLM-gated docs is the failure mode the v0.2 eval scenario S2 explicitly checks for.

The exact `--full` doc-set classification (which 3 are LLM-gated) is owned by **the §11.2 wave-dispatch doc-set** (this skill body is the single source of truth now that `sf_docs_derive` is removed). Keep §4.2 and §11.2 aligned.

---

## 5. Critical: `PROJECT_PLAN.md` is the v0.1.0 timeline doc, UNCHANGED

This is the most important constraint in this skill body. Read it carefully.

**`PROJECT_PLAN.md` is preserved byte-for-byte from v0.1.0.** It is a **Phase-2-Strategy-derived timeline document** (milestones, dates / horizons, resources, risks summary) — exactly the v0.1.0 template, exactly the v0.1.0 content shape. The v0.2 retrofit does not rename it, does not change its template, does not extend its content. v0.1.0 users who have an existing `PROJECT_PLAN.md` in their canonical repo see no surface change.

**`ROADMAP.md` is a SEPARATE file owned by a DIFFERENT skill.** The R1 Phase → Sprint → Vertical-Slice hierarchy doc introduced in v0.2 is named `ROADMAP.md`, not `PROJECT_PLAN.md`. It is emitted by `scaffold-onboard:planning-project-roadmap` (SPEC §5.4) when the user runs `/plan-roadmap`. It has its own routing logical name (`roadmap`), its own project-scoped state file (`$(sf project_data_dir)/project-roadmap.json`), its own template (`templates/roadmap/ROADMAP.md.tmpl`), and its own architect-critic moment.

**Why this matters.** The v0.1.0 `PROJECT_PLAN.md` filename was nearly reused for the v0.2 R1 hierarchy doc, and that collision was caught during the v0.2 SPEC's architect-critic pass (challenges C3 + C14; resolved at SPEC §13.5). Reusing the filename would have silently overwritten v0.1.0 users' Phase-2 timeline docs on `/scaffold-docs --regenerate`. The rename to `ROADMAP.md` is load-bearing.

**Concretely, this skill MUST NOT do any of the following:**

- Emit a Phase → Sprint → Vertical-Slice hierarchy structure into `PROJECT_PLAN.md` — no headings shaped like `Phase 1: <name>`, no sub-headings shaped like `Sprint 1.1:`, no slice IDs (e.g., the hierarchy convention IDs are NOT emitted here — those belong in `ROADMAP.md`).
- Emit `auto:` or `user:` demo-criteria grammar into `PROJECT_PLAN.md` — those are R3 grammar (SPEC §9) owned by `authoring-vertical-slice-demo`, writing into `ROADMAP.md`.
- Rename `PROJECT_PLAN.md` to `ROADMAP.md`, or vice-versa. The filenames carry independent meaning.
- Write a `ROADMAP.md` from this skill at all. `ROADMAP.md` is `planning-project-roadmap`'s territory; running `/scaffold-docs` (with or without `--full`) must not produce a `ROADMAP.md`.
- Read or mutate project-scoped `project-roadmap.json`. That state file belongs to a different skill.

If the user asks during `/scaffold-docs` whether the R1 hierarchy will be authored, answer: *"No — `/scaffold-docs` emits the v0.1.0 governance bundle (PRD / SRS / BACKLOG / PROJECT_PLAN / ADR-0001). The Phase → Sprint → Vertical-Slice hierarchy lives in `ROADMAP.md` and is authored interactively by `/plan-roadmap` after onboarding closes."*

---

## 6. Manifest-aware output routing (NEW in v0.2)

Per SPEC §10.1, this skill produces 6 logical-name destinations across its 5 default + 9 full docs:

| Logical name | Default destination | Docs emitted by this skill |
|---|---|---|
| `prd` | `canonical` | `PRD.md` |
| `srs` | `canonical` | `SRS.md` |
| `backlog` | `canonical` | `BACKLOG.md` |
| `project_plan` | `canonical` | `PROJECT_PLAN.md` (v0.1.0 timeline doc — see §5) |
| `product_adrs` | `canonical` | `ADR-0001.md`, `RISK_REGISTER.md`, `THREAT_MODEL.md`, `TEST_STRATEGY.md`, `CUTOVER_PLAN.md`, `EVALS_PLAN.md`, `MODEL_CARD.md` |
| `process_adrs` | `ai_workspace` | `DEFINITION_OF_DONE.md`, `DEMO_RUNBOOK.md`, `PROMPT_GOVERNANCE.md` |

**Helper:** `sf_resolve_output_path <logical_name> <relative_path>` (lib/routing.sh):

```
prd_path="$(sf_resolve_output_path prd docs/PRD.md)"
backlog_path="$(sf_resolve_output_path backlog docs/BACKLOG.md)"
project_plan_path="$(sf_resolve_output_path project_plan docs/PROJECT_PLAN.md)"
adr_path="$(sf_resolve_output_path product_adrs docs/adr/0001-record-architecture-decisions.md)"
dod_path="$(sf_resolve_output_path process_adrs docs/DEFINITION_OF_DONE.md)"
```

Resolution behavior (identical across all six logical names):

- **Manifest present** (walked up from `pwd` to find `.workspace/pairing.json`): returns the absolute path with the destination's root expanded (e.g., `<canonical-repo>/docs/PRD.md` for `prd`; `<ai-workspace>/docs/DEFINITION_OF_DONE.md` for `process_adrs`).
- **Manifest absent** (single-repo mode): returns `$(pwd)/<relative_path>` — exactly v0.1.0 behavior. v0.1.0 byte-identical regression tests pass through this fallback.
- **Manifest present but logical name missing** from `routing.*`: helper warns once and falls back to `$(pwd)/<relative_path>`. Forward-compatible with workspace-init manifests that pre-date a logical-name addition.

Always route through `sf_resolve_output_path` — never hardcode `docs/PRD.md` or `docs/adr/...` against `$(pwd)` directly. The §11 synthesis dispatch resolves each artifact's output path explicitly via `sf_resolve_output_path <routes_to> <relpath>` (see the §11.1 catalog table). Treat `sf_resolve_output_path` as the single point of truth.

**Lane discipline:** every doc this skill emits must resolve through one of the 6 logical names listed above. The skill must NOT use the `roadmap` logical name — that belongs to `planning-project-roadmap` (per §5).

---

## 7. Composition awareness

This skill is downstream of `/onboard`'s MASTER-SPEC close, where the close-depth architect-critic already ran. **This skill does not invoke architect-critic itself.** That's a deliberate choice in SPEC §12.1: only 4 critic moments exist (Phase 5, Phase 7, MASTER-SPEC close, `/plan-roadmap` close); governance-doc derivation is a downstream transformation after the spec is locked.

If during derivation the user surfaces an architectural concern (e.g., "I think the PRD's `Out of scope` section needs another pass"), suggest: *"Want adversarial review on this section? Re-run `/onboard --resume` to revisit Phase 5/7 with the critic, or run `Skill(architect-critic:critiquing-spec)` directly with `target=master-spec-phase` against the relevant MASTER-SPEC phase."* — but do not invoke the critic from inside this skill body. Use `Skill(architect-critic:critiquing-spec)` if invoked, not the legacy `Skill(architect-critic:critique)` slash-command-shaped name (removed in architect-critic v0.2 per its SPEC §3 NG1).

ai-mentor + superpowers composition is similarly out of scope for this skill — they're upstream context, not consumed during governance derivation.

---

## 8. Slash-command interaction (`/scaffold-docs` via `$ARGUMENTS` bridge)

The `/scaffold-docs` slash command wrapper (`commands/scaffold-docs.md`) exports the raw arg string as `$ARGUMENTS` (env-var bridge per `feedback_slash_command_dollar_n_bug` — Claude Code substitutes `$1`/`$2`/etc. in command bodies at template-render time, silently corrupting bash positionals).

Supported flags:

- *(no flag)* — synthesize the 5 default docs; skip the 9 `--full` docs; preserve any existing files in the routing destinations (existing files are never overwritten without `--regenerate`); route via manifest if present, else `$(pwd)`.
- `--full` — synthesize the 5 default docs PLUS the 9 `--full` docs (6 always-on + 3 LLM-gated by Phase 9.3.1).
- `--regenerate` — overwrite existing docs at their resolved destinations. Always asks confirmation first, listing the absolute paths that will be clobbered. Preserving user customization is the default; `--regenerate` is the explicit opt-in.
- `--full --regenerate` — combine both.

Parse `$ARGUMENTS` in bash; never reference `$1` / `$2` directly. If `$ARGUMENTS` contains a flag this skill doesn't recognize, surface a one-line error listing the supported flags and stop — do not silently ignore.

---

## 9. Bash bookkeeping helpers (the bookkeeping-vs-judgment line)

This skill never bash-orchestrates the judgment work (whether to refuse derivation on a thin spec, how to phrase the routing destination prompt, whether to surface the LLM-gate skip). It calls helpers for I/O and templating only.

**Doc synthesis (§11):** governance docs are authored by `scaffold-onboard:synthesis-agent` dispatch — there is no deterministic doc renderer (the `lib/docs.sh` `sf_docs_derive` path was removed in v0.8.0).

**EXEC-SUMMARY write-back (lib/render.sh):** `sf_render_executive_summary_from_synthesized` (mechanical guarded write-back of an agent-authored summary), `sf_exec_summary_staleness` (cksum staleness check).

**Routing (lib/routing.sh):** `sf_resolve_output_path`, `sf_discover_manifest`.

**Validation (lib/parser.sh):** `sf_spec_validate`.

**State (lib/state.sh):** `sf_state_read_answer` (read Phase 9.3.1 for the LLM gate), `sf_state_gate_passes` (evaluate branching gates).

These are pseudocode references — the implementations live in their respective lib files. macOS-portable patterns (BSD awk, bash 3.2) are required for any inline snippets; prefer calling the helpers over re-inlining shell.

---

## 10. Anti-patterns (do not do these)

- **Emitting a Phase → Sprint → Vertical-Slice hierarchy into `PROJECT_PLAN.md`.** The structure described in SPEC §7.1 (`Phase N:` / `Sprint N.M:` / slice IDs / `Demo criteria` blocks) is NOT emitted by this skill anywhere — least of all in `PROJECT_PLAN.md`. That structure lives in `ROADMAP.md`, authored by `planning-project-roadmap`. Eval scenario S3 explicitly fails on any hierarchy leakage into `PROJECT_PLAN.md`. (Example identifier `VS-1.1.1` is NOT emitted by this skill — referenced here only to name the boundary.)
- **Renaming `PROJECT_PLAN.md` to `ROADMAP.md`** (or vice-versa). v0.1.0 users depend on `PROJECT_PLAN.md` continuing to exist with v0.1.0 content; v0.2 introduced `ROADMAP.md` as a separate file precisely to avoid this collision.
- **Touching `ROADMAP.md` from this skill.** Never read it, never write it, never mutate project-scoped `project-roadmap.json`. That's `planning-project-roadmap`'s territory.
- **Emitting `auto:`/`user:` demo-criteria grammar into any doc this skill writes.** That grammar (SPEC §9) belongs in `ROADMAP.md` slice blocks, written by `authoring-vertical-slice-demo`. None of the 14 governance docs contain demo-criteria.
- **Skipping `sf_spec_validate`.** A malformed MASTER-SPEC silently emits `{{placeholder}}` artifacts that look complete but are broken. Validate up-front; refuse to proceed on non-zero exit.
- **Hardcoding `docs/PRD.md` against `$(pwd)`** (or any other doc filename). Always route via `sf_resolve_output_path <logical_name> <relative_path>`. v0.1.0 byte-identical behavior in single-repo mode falls out of the helper's fallback; cross-repo routing in workspace-init mode requires the helper.
- **Silently emitting the 3 LLM-gated docs when Phase 9.3.1 != yes** — or, conversely, silently skipping them without a visible reason. The skip-with-reason is the contract (eval S2): if the gate fails, surface the gate name and the answer that didn't satisfy it.
- **Overwriting existing docs without `--regenerate`.** Even on a fresh run, if the user pre-authored their own `PRD.md`, the v0.1.0 helper preserves it. Don't undo that. `--regenerate` is the explicit opt-in for clobber.
- **Invoking architect-critic from this skill.** Governance-doc derivation is a downstream transformation. The critic moments are upstream (in `onboarding-project`) and in `planning-project-roadmap` — not here. If you find yourself reaching for `Skill(architect-critic:...)`, you're outside this skill's lane.
- **Calling `Skill(architect-critic:critique)`** (the legacy v0.1.x slash-command-shaped name). If a future iteration of this skill grows a critic moment, use `Skill(architect-critic:critiquing-spec)` — the v0.2 skill.

---

## 11. Synthesis dispatch (v0.3)

Governance docs are authored by **sub-agent synthesis — the only derivation path** (the deterministic `sf_docs_derive` renderer + `--fast` flag were removed in v0.8.0, SS-7). This section describes the orchestration logic you (the orchestrator session reading this skill) must execute. Bash cannot dispatch sub-agents; this logic lives here as prose instructions.

**Agent-unavailable model (uniform across all synthesis here):** dispatch the sub-agent → if no Task tool (headless), perform the synthesis **inline in the main context** from the same brief → if a synthesized artifact is structurally invalid, **re-dispatch once** with a corrective instruction → if it still fails, **hard-fail with actionable remediation** (re-run `/scaffold-docs`). There is **no deterministic content fallback**.

### 11.1 Setup

Source both synthesis and routing helpers:

```bash
source "${CLAUDE_PLUGIN_ROOT}/lib/synthesis.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/routing.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"  # sf_project_name, sf_state_read_answer, sf_state_gate_passes
```

Resolve the source documents:

```bash
master="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
exec_summary="$(sf_resolve_output_path executive_summary EXECUTIVE-SUMMARY.md)"
# EXEC-SUMMARY is produced by onboarding (single authoritative producer). Here we
# only CONSUME it: produce-once via SYNTHESIS if a legacy project lacks it (SS-7:
# no deterministic extract), and warn (never silently refresh) if it is stale.
source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"   # sf_render_executive_summary_from_synthesized, sf_exec_summary_staleness
if [[ ! -f "$exec_summary" ]]; then
  exec_brief="${CLAUDE_PLUGIN_ROOT}/templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md"
  prompt="$(sf_synth_brief_assemble "$exec_brief" "$(sf_synth_ledger_empty)" "$exec_summary" "$master" "")"
  # Dispatch scaffold-onboard:synthesis-agent with "$prompt" (if no Task tool,
  # author EXECUTIVE-SUMMARY.md inline in the main context from the FULL MASTER-SPEC
  # following the EXECUTIVE-SUMMARY brief — vision/users/MVP/success criteria — NOT
  # from MASTER-SPEC's pinned "## Executive Summary" section, which may be absent or
  # a thin placeholder on a legacy bank), then write it back with the guarded helper:
  #   sf_render_executive_summary_from_synthesized "$master" "$exec_summary" \
  #     "$(sf_project_name)" "$(sf_state_read_answer 1.3.1)"
  # On structural rejection, re-dispatch once with a corrective instruction.
  if [[ ! -f "$exec_summary" ]]; then
    sf_log_warn "could not produce EXECUTIVE-SUMMARY.md — synthesis prompts will use MASTER-SPEC only; run /onboard to author it"
    exec_summary=""
  fi
elif ! sf_exec_summary_staleness "$master" "$exec_summary"; then
  sf_log_warn "EXECUTIVE-SUMMARY.md is older than MASTER-SPEC.md — re-run onboarding synthesis to refresh it (this command consumes but does not refresh the summary)."
fi
```

Resolve each artifact's output path via `sf_resolve_output_path <routes_to> <relpath>` using the brief's `routes_to` field. This table is the authoritative doc catalog + routing (it replaces the removed `sf_docs_derive`):

| Doc | `routes_to` | relpath |
|---|---|---|
| PRD | `prd` | `docs/PRD.md` |
| SRS | `srs` | `docs/SRS.md` |
| BACKLOG | `backlog` | `docs/BACKLOG.md` |
| PROJECT_PLAN | `project_plan` | `docs/PROJECT_PLAN.md` |
| ADR-0001 | `product_adrs` | `docs/adr/0001-record-architecture-decisions.md` |
| RISK_REGISTER | `product_adrs` | `docs/RISK_REGISTER.md` |
| THREAT_MODEL | `product_adrs` | `docs/THREAT_MODEL.md` |
| TEST_STRATEGY | `product_adrs` | `docs/TEST_STRATEGY.md` |
| DEFINITION_OF_DONE | `process_adrs` | `docs/DEFINITION_OF_DONE.md` |
| CUTOVER_PLAN | `product_adrs` | `docs/CUTOVER_PLAN.md` |
| DEMO_RUNBOOK | `process_adrs` | `docs/DEMO_RUNBOOK.md` |
| EVALS_PLAN | `product_adrs` | `docs/EVALS_PLAN.md` |
| MODEL_CARD | `product_adrs` | `docs/MODEL_CARD.md` |
| PROMPT_GOVERNANCE | `process_adrs` | `docs/PROMPT_GOVERNANCE.md` |

### 11.2 Synthesis wave dispatch

Dispatch artifacts in dependency waves. Maintain a running ledger from the start:

```bash
ledger="$(sf_synth_ledger_empty)"
```

Briefs live at `${CLAUDE_PLUGIN_ROOT}/templates/synthesis-briefs/<DOC>.brief.md`.

**Wave 1 — PRD** (must complete before Wave 2; PRD mints UC IDs the SRS consumes):

```bash
brief="${CLAUDE_PLUGIN_ROOT}/templates/synthesis-briefs/PRD.brief.md"
out="$(sf_resolve_output_path prd docs/PRD.md)"
prompt="$(sf_synth_brief_assemble "$brief" "$ledger" "$out" "$master" "$exec_summary")"
# Dispatch: model = opus (from brief's model: field)
Task(subagent_type="scaffold-onboard:synthesis-agent",
     description="Synthesize PRD",
     model="claude-opus-4-5",
     prompt="$prompt")
```

On `mode:complete`: merge returned IDs and validate:

```bash
ledger="$(sf_synth_ledger_merge "$ledger" "<ids_minted from return JSON>")"
sf_synth_assert_sections "$brief" "$out"
sf_synth_assert_no_markers "$out"
sf_synth_validate_cited "$ledger" "<ids_cited from return JSON>"
```

On `mode:failed` or any validation failure: **re-dispatch PRD once** with a corrective instruction (cite the failed assertion). If it fails again: `sf_log_error "PRD synthesis failed after retry — re-run /scaffold-docs to retry"` and **stop** (no deterministic fallback exists as of v0.8.0). Because Waves 2–3 depend on PRD's UC IDs, do not proceed past a failed PRD.

**Wave 2 — SRS** (sequential; consumes UC IDs minted in Wave 1):

Same pattern as Wave 1. Brief: `SRS.brief.md`. Output: `sf_resolve_output_path srs docs/SRS.md`. Model: `opus`. Merge the returned `FR`/`NFR` IDs into `$ledger` before proceeding to Wave 3.

**Wave 3 — BACKLOG** (sequential; consumes FR/NFR IDs minted in Wave 2):

Brief: `BACKLOG.brief.md`. Output: `sf_resolve_output_path backlog docs/BACKLOG.md`. Model: `sonnet`. Merge returned `BACKLOG` IDs into `$ledger`.

**Wave 4 — parallel block** (independent of each other; all consume from the ledger assembled through Wave 3):

Dispatch in parallel:

- **PROJECT_PLAN** — brief `PROJECT_PLAN.brief.md`, output `sf_resolve_output_path project_plan docs/PROJECT_PLAN.md`, model `sonnet`.
- **ADR-0001** — brief `ADR-0001.brief.md`, output `sf_resolve_output_path product_adrs docs/adr/0001-record-architecture-decisions.md`, model `sonnet`.
- **`--full` docs** — only when `--full` was passed:
  - Always-on: RISK_REGISTER, THREAT_MODEL, TEST_STRATEGY, DEFINITION_OF_DONE, CUTOVER_PLAN, DEMO_RUNBOOK (all model `sonnet`).
  - LLM-gated: EVALS_PLAN, MODEL_CARD, PROMPT_GOVERNANCE — only when Phase 9.3.1 ∈ {yes, true}. If the gate fails, skip these three and surface the skip-with-reason to the user.
  - Without `--full`: Wave 4 is PROJECT_PLAN + ADR-0001 only.

For each Wave 4 doc use the same dispatch pattern as Wave 1, substituting the appropriate brief, output path, and model. Wave 4 docs do not mint any new IDs that other Wave 4 docs consume, so they are safe to run concurrently. Merge each returned `ids_minted` into `$ledger` as results arrive; validate each artifact immediately on return; on failure, re-dispatch that artifact once, then hard-fail with remediation (no deterministic fallback).

### 11.3 Coverage report

After all waves complete (regardless of any per-artifact fallbacks), collect every ID cited across all synthesized docs into a single newline-separated list and print the coverage report:

```bash
sf_synth_coverage_report "$ledger" "<all cited IDs, newline-separated>"
```

This surfaces any FR/NFR that no artifact cited, so the user can identify gaps before committing the bundle.

### 11.4 Skip / regenerate semantics

Before assembling a prompt for any artifact, check whether its resolved output path already exists; if it does and `--regenerate` was not passed, skip it (emit `sf_log_info "preserved: <path>"`) and do not dispatch a sub-agent for it. With `--regenerate`, dispatch unconditionally (overwrite after the §8 confirmation).

---

## 12. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: whether MASTER-SPEC is too thin to derive from, how to phrase the routing prompt across 6 logical destinations, whether to surface the LLM-gate skip-with-reason, when to refuse `--regenerate` against user-customized files.
- **Bash helpers** (`lib/*.sh`) handle pure I/O: template substitution, atomic writes, manifest resolution, validation probes, state reads.
- **`onboarding-project`** owns MASTER-SPEC authoring upstream of you; you only READ MASTER-SPEC.
- **`planning-project-roadmap`** owns `ROADMAP.md` and the R1 hierarchy; you never read or write those.
- **`authoring-machine-checkable-rules`** owns rule authoring in `03-code-patterns.md`; you never touch that file.
- **The user** is the final authority. For destructive operations (`--regenerate` against pre-existing user-authored governance docs), require explicit confirmation listing the absolute paths that will be clobbered.

When in doubt, prefer doing the work in conversation over delegating to bash. v0.1.x got this wrong — `/scaffold-docs` lived almost entirely inside `bash -c` blocks Claude never read; v0.2 corrects that by making this skill body the readable orchestration layer and keeping bash to bookkeeping.

---

## 13. Post-derivation review (#42 — advisory, SS-2)

> Numbered §13 (not §12) because §12 "Notes on tool boundaries" already exists; this is the next free number per the SS-2 plan.

After the synthesis waves complete, dispatch ONE read-only review over the governance bundle. Non-blocking: surface
the report, do not gate. The `derivation-reviewer` agent is structurally read-only
(no Write, no Task) — it returns its full report **in its final message**, and
**you (the orchestrator) persist it**, mirroring how `synthesis-agent`'s
`mode:complete` returns are consumed in §11.2.

```bash
master_hash="$(cksum < "$master" | awk '{print $1"-"$2}')"
bundle="$(sf_resolve_output_path prd docs)"
artifact_paths="$(printf '%s, %s, %s, %s, %s' \
  "$(sf_resolve_output_path prd docs/PRD.md)" \
  "$(sf_resolve_output_path srs docs/SRS.md)" \
  "$(sf_resolve_output_path backlog docs/BACKLOG.md)" \
  "$(sf_resolve_output_path project_plan docs/PROJECT_PLAN.md)" \
  "$(sf_resolve_output_path product_adrs docs/adr/0001-record-architecture-decisions.md)")"
if [[ "${full:-0}" == "1" ]]; then
  artifact_paths="${artifact_paths}, $(sf_resolve_output_path product_adrs docs/RISK_REGISTER.md), $(sf_resolve_output_path product_adrs docs/THREAT_MODEL.md), $(sf_resolve_output_path product_adrs docs/TEST_STRATEGY.md), $(sf_resolve_output_path process_adrs docs/DEFINITION_OF_DONE.md), $(sf_resolve_output_path product_adrs docs/CUTOVER_PLAN.md), $(sf_resolve_output_path process_adrs docs/DEMO_RUNBOOK.md)"
  uses_llm="$(sf_state_read_answer 9.3.1)"
  if [[ "$uses_llm" == "yes" || "$uses_llm" == "true" ]]; then
    artifact_paths="${artifact_paths}, $(sf_resolve_output_path product_adrs docs/EVALS_PLAN.md), $(sf_resolve_output_path product_adrs docs/MODEL_CARD.md), $(sf_resolve_output_path process_adrs docs/PROMPT_GOVERNANCE.md)"
  fi
fi
review_prompt="Review these freshly synthesized governance artifacts: ${artifact_paths}. Compare against MASTER-SPEC ${master} (cksum:${master_hash}) and EXECUTIVE-SUMMARY ${exec_summary}. Return your review report per your contract."
Task(subagent_type="scaffold-onboard:derivation-reviewer",
     description="Review governance-docs derivation",
     model="claude-sonnet-4-5",
     prompt="$review_prompt")
```

On `review-complete`: write the returned report body (the markdown table the agent
emitted — NOT the trailing sentinel JSON) to `${bundle}/derivation-review.md`,
print the report path + a one-line summary, and for each `regenerate <file>` finding
surface `/scaffold-docs --regenerate` plus the single artifact name to
re-dispatch internally through the §11.2 per-artifact loop. The user decides;
nothing is auto-applied and no public per-file flag is introduced in SS-2.

**Targeted regenerate (apply path):** keep the user-facing CLI aligned with §8's
documented boolean `--regenerate`. Per-file targeting is an orchestration action:
re-dispatch just that artifact's synthesis brief through the §11.2 loop, then run
the normal validators/fallback for that one file. No new lib or slash-command flag
is required for SS-2.
