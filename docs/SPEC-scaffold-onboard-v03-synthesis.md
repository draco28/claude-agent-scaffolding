# SPEC — scaffold-onboard v0.3: LLM Sub-Agent Synthesis Layer

**Status:** Design (brainstormed 2026-05-28; pending implementation plan)
**Issues:** Closes #17 (supersedes #16 and the synthesis-relevant part of #14)
**Plugin:** scaffold-onboard (current 0.2.3 → target 0.3.0)
**Author:** Pras (design via Claude Code brainstorming)

---

## 1. Context & motivation

Everything scaffold-onboard derives *after* `MASTER-SPEC.md` — governance docs
(`/scaffold-docs`), the roadmap (`/plan-roadmap`), and the memory-bank + CLAUDE.md
(`/scaffold-project`) — is currently produced by **deterministic `{{placeholder}}`
template substitution** in bash (`sf_render`, `lib/render.sh:11-110`). That model
has a hard quality ceiling: it can only fill sections that map 1:1 to a captured
phase answer, and leaves literal human-fill-in markers (`*(steps in order…)*`,
`### Sprint 1 *(populate after planning)*`) everywhere synthesis is required.

Concrete evidence (PulseTrader, v0.2.2 `/scaffold-docs --full`):
- **Broken titles** — `project_name` extracted as `${raw_pitch%% — *}` produces a
  garbage H1 whenever the pitch contains an em-dash (`render.sh:140`, `docs.sh:14`,
  `memory-bank.sh:132` — three copies).
- **Literal markers left verbatim** in `CUTOVER_PLAN.md`, `PROJECT_PLAN.md`,
  `BACKLOG.md` — substitution cannot synthesize cutover steps, sprint breakdowns, or
  real backlog items.
- **Mis-sourced requirements (#16):** SRS `FR-*` are mapped from Phase 7
  (implementation) and `NFR-*` from Phase 8 (devops) — so "FRs" are impl decisions
  and "NFRs" are dev-ops decisions, and nothing traces SRS → PRD use cases. The PRD
  itself captures only a *single* use case (`{{phase_1.2.2}}`).

For a workflow where these artifacts drive all downstream planning and build, the
ceiling is too low. This spec moves **content synthesis** to LLM sub-agents while
keeping **structure, routing, and validation** deterministic.

### Relationship to #16 and #14
- **#16** (FR/NFR mis-sourced; PRD single use case) becomes a *synthesis-brief
  concern* rather than a template-mapping bug — resolved in §7.
- **#14**'s traceability *plumbing* (trace arrays in roadmap state + work-item specs,
  the two-sequence contract) already shipped in commit `01ca8a5`. This spec supplies
  the **content** that makes those traces real (slices cite IDs that actually exist
  in synthesized SRS/BACKLOG) and the coverage-rollup that #14 deferred here.

---

## 2. Goals / non-goals

**Goals**
- Production-grade artifacts by default — no fill-in markers, real content.
- Correct, traceable requirement IDs across artifacts (UC → FR/NFR → BACKLOG → ROADMAP).
- Context-safe orchestration (a large bundle never blows the main session's context).
- A clean deterministic escape hatch (`--fast`) and a non-LLM fallback on failure.
- Cover all three surfaces: `/scaffold-docs`, `/plan-roadmap`, `/scaffold-project`.

**Non-goals**
- Changing onboarding (the 10-phase MASTER-SPEC authoring) — unchanged except a small
  project-name capture (§7).
- Diff-merge / managed-region re-generation — explicitly out (§10): re-gen stays
  skip-if-exists + `--regenerate` clobber; git is the recovery net.
- API-based wrappers — all sub-agent work uses the `Task`/Agent tool from within
  Claude Code sessions (subscription-funded), per project convention.

---

## 3. Settled decisions

| # | Decision | Choice |
|---|----------|--------|
| D1 | Scope of this spec | **All three surfaces** (docs + roadmap + memory-bank) |
| D2 | Where structure comes from | **Deterministic skeleton + LLM content** (bash owns the structural contract + validation; sub-agent fills designated regions) |
| D3 | Cross-artifact ID consistency | **Shared ID ledger via return contract** — dependency waves; each agent returns a compact ID JSON; orchestrator threads the ledger into downstream briefs; bash validates cited IDs |
| D4 | Default mode | **Default-on synthesis + `--fast` deterministic escape** |
| D5 | Re-generation | **Skip-if-exists + `--regenerate` clobber** (current model retained) |
| D6 | Sub-agent model | **Sonnet default; Opus for the PRD and SRS waves** (reasoning-heavy ID minting) |

---

## 4. Architecture: deterministic shell, synthesized content

Two layers with a hard seam:

- **Deterministic shell (bash — stays):** artifact selection (minimal vs `--full`,
  the Phase-9.3.1-gated docs), output routing (`sf_resolve_output_path`), the
  per-artifact **structural contract** (required sections + order, frontmatter, ID
  format), ID validation, `--regenerate`/skip-if-exists, and the `--fast` path
  (today's `sf_render`).
- **Synthesis layer (LLM sub-agents):** the *content* of each artifact — prose,
  enumerated `UC`/`FR`/`NFR`/`BACKLOG`, real cutover steps, real sprint breakdowns —
  grounded in `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md`.

**The orchestrator is the skill-running main session**, not a bash script (bash
cannot call `Task`). Each derivation skill (`scaffolding-governance-docs`,
`planning-project-roadmap`, `scaffolding-memory-bank`) drives this loop:

1. Bash: select artifacts + resolve output paths + (per artifact) emit the structural
   contract / skeleton.
2. Session: dispatch synthesis sub-agents in dependency waves via `Task`.
3. Session: collect each agent's returned **ID ledger** (compact JSON) into a running
   ledger held in context — *not* the doc bodies.
4. Bash: after each wave, validate that every cited ID exists in the ledger; on
   violation, halt that artifact and fall back (§9).

The main session only ever holds the compact ledger + briefs, never the full text of
sibling documents → context stays bounded regardless of bundle size.

---

## 5. New components

- **`scaffold-onboard/lib/synthesis.sh`** — deterministic helpers:
  - `sf_synth_brief_assemble <doc> <ledger-json>` → composes the sub-agent brief
    (structural contract from the brief frontmatter + the relevant ledger slice +
    absolute source paths + output path).
  - `sf_synth_validate_ids <doc-path> <ledger-json>` → asserts every cited ID resolves
    and (for ID-producing docs) every minted ID matches the required format.
  - `sf_synth_ledger_merge <ledger-json> <returned-json>` → folds a wave's returned
    IDs into the running ledger.
  - `sf_synth_enabled` → resolves `--fast`/default + any host capability check
    (Task availability) into a synthesize-or-substitute decision.
- **`scaffold-onboard/agents/synthesis-agent.md`** — a registered
  `scaffold-onboard:synthesis-agent` (mirrors `scaffold-dev:implementer-agent`):
  - Tool allowlist: **Read, Write, Grep, Glob**. **No** Bash-git, **no `Task`**
    (no subagent nesting).
  - System prompt = the synthesis contract: read `MASTER-SPEC.md` +
    `EXECUTIVE-SUMMARY.md` + the brief; write the artifact to the given path honoring
    the section contract; mint/cite IDs per the brief; **never emit fill-in markers**;
    return the ID-ledger JSON (§6).
- **`scaffold-onboard/templates/synthesis-briefs/<doc>.brief.md`** — one per artifact.
  Migrated from the existing `.tmpl` files (the `.tmpl` becomes the brief's structural
  skeleton). Frontmatter is machine-readable (required sections, IDs to mint/cite +
  format); the body is prose synthesis guidance, quality bar, examples, anti-patterns.

---

## 6. Brief format & return contract

**Brief file** (`templates/synthesis-briefs/SRS.brief.md`, illustrative):

```markdown
---
doc: SRS
routes_to: srs                      # logical name for sf_resolve_output_path
wave: 2
required_sections:                  # bash validates these exist, in order
  - "Functional Requirements"
  - "Non-Functional Requirements"
  - "Traceability"
mints: [FR, NFR]                    # ID families this doc produces
mint_format: { FR: "FR-<n>", NFR: "NFR-<n>" }
consumes: [UC]                      # ledger families this doc reads
model: opus
---
## Synthesis guidance
Derive each functional requirement from a PRD **use case** (UC-N); every FR MUST
trace to at least one UC. Derive non-functional requirements from quality attributes
— latency (spec §5.3.2), determinism (Phase 3), security (Phase 4), coverage
(Phase 9) — NOT from Phase 7 (implementation) or Phase 8 (devops). …
```

**Sub-agent return contract** (compact — no doc body):

```json
{
  "mode": "complete",
  "output_path": "/abs/path/SRS.md",
  "ids_minted": {
    "frs":  [{"id": "FR-1", "title": "...", "traces_uc": ["UC-1"]}],
    "nfrs": [{"id": "NFR-1", "title": "...", "category": "latency", "traces_uc": ["UC-2"]}]
  },
  "ids_cited": ["UC-1", "UC-2"],
  "summary": "one line"
}
```

Failure shape: `{"mode": "failed", "reason": "...", "partial_output_path": null}`.
(Shapes mirror scaffold-dev's `gaps-surfaced | complete` convention.)

---

## 7. Dispatch & wave model

Dependency-ordered waves; the running ledger threads forward:

- **Wave 1 — PRD** (Opus) → mints `UC-1..UC-N` (full use-case set; fixes PRD's single
  `{{phase_1.2.2}}`).
- **Wave 2 — SRS** (Opus) → consumes UC; mints `FR-N` (each tracing a UC) + `NFR-N`
  from quality attributes. **This is the #16 fix.**
- **Wave 3 — BACKLOG** (Sonnet) → consumes UC+FR; mints `BACKLOG-N` tracing FR/UC.
- **Wave 4 — parallel fan-out** (Sonnet) — ROADMAP slices (cite FR/NFR/BACKLOG →
  realizes #14), PROJECT_PLAN, all `--full` docs, memory-bank, CLAUDE.md. Independent
  → dispatched in parallel.

After each wave, `sf_synth_validate_ids` confirms cited IDs resolve before the next
wave starts.

### project_name fix (companion, deterministic)
Replace `${raw_pitch%% — *}` in all three call sites with an **explicit project name**
captured during onboarding (add a dedicated field under Phase 1.1 in
`templates/onboarding-questions/phases.yaml`). Reliable titles in both `--fast` and
synthesis modes; no em-dash heuristic.

---

## 8. Surface application

- **`/scaffold-docs`** (`scaffolding-governance-docs`, `lib/docs.sh`): waves 1–3 +
  the doc portion of wave 4. `--full` adds the 9 extended briefs; the Phase-9.3.1 LLM
  gate still selects EVALS/MODEL_CARD/PROMPT_GOVERNANCE.
- **`/plan-roadmap`** (`planning-project-roadmap`, `lib/roadmap.sh`): wave 4 — slices
  synthesized with real, spec-grounded scope + demo criteria, citing the FR/NFR/BACKLOG
  ledger. Requires the doc ledger; in **lightweight** mode (no `/scaffold-docs` first)
  slices synthesize without trace IDs and warn (per the existing two-sequence contract).
- **`/scaffold-project`** (`scaffolding-memory-bank`, `lib/memory-bank.sh`): wave 4 —
  the 8 derived memory-bank files + CLAUDE.md synthesized from sources + ledger; the 2
  live files + static WORKFLOW.md keep today's seed-once behavior.

### Coverage rollup (#14 carry-over)
A deterministic `sf_synth_coverage_report` reads the ledger + ROADMAP slice trace
arrays and prints which FR/NFR are covered by a slice vs unassigned — the requirement-
anchored progress view #14 asked for.

---

## 9. Boundary, failure handling, `--fast`

- **Stays bash:** artifact selection, routing, structural-contract validation, ID
  validation, ledger assembly, coverage rollup, `--regenerate`/skip, `--fast`.
- **Moves to sub-agents:** all *content*.
- **Failure:** if a sub-agent returns `failed`, or its output misses required sections,
  or cited IDs don't validate → **fall back to the deterministic skeleton render for
  that artifact with a visible warning**; the run continues with the rest of the bundle.
- **`--fast`:** skips dispatch entirely → today's `sf_render` substitution (zero token
  cost, offline). Same flag semantics across all three commands.

---

## 10. Re-generation

Retain the current model: first run writes; a re-run **skips existing files** unless
`--regenerate` is passed, which **overwrites wholesale**. No diff-merge, no managed
regions. Rationale: artifacts land in git-tracked repos (canonical / ai-workspace), so
git history is the recovery net; the simplicity is worth more than in-doc sentinels.
The skills should remind the user to commit before `--regenerate`.

---

## 11. Testing

- **Deterministic helpers** (`brief_assemble`, `validate_ids`, `ledger_merge`,
  `enabled`/`--fast`, `coverage_report`, project-name extraction) → bash unit tests:
  extend `tests/test-docs.sh`; add `tests/test-synthesis.sh`.
- **Structural contract** → bash asserts required sections present, **no `*(…)*`
  fill-in markers remain**, all cited IDs resolve. This is the release gate for
  synthesized output (content quality is not unit-testable).
- **Optional LLM-judge eval** (Agent-tool, subscription-funded) scores doc quality for
  tuning; **not** a release gate.
- All existing suites (test-state, test-roadmap, test-manifest-routing, test-docs,
  test-codex-dual-publish) must stay green.

---

## 12. Migration & compatibility

- Each `templates/docs-minimal/*.tmpl` and `docs-full/*.tmpl` is migrated to a
  `synthesis-briefs/*.brief.md` whose frontmatter encodes the section contract and
  whose skeleton derives from the old template. `--fast` continues to render the old
  `.tmpl` (kept as the skeleton), so the deterministic path is preserved.
- Public `sf` command signatures unchanged; new flags `--fast` (all three commands)
  are additive.
- Version: scaffold-onboard 0.2.3 → **0.3.0** (Claude + Codex manifests); CHANGELOG +
  README updated; no version bump to other plugins (scaffold-dev already carries the
  #14 trace-block consumer).

---

## 13. Open items (for the implementation plan)

- Exact brief frontmatter schema + a validator (`sf_synth_brief_validate`) mirroring
  the mcrule-block validation style.
- Whether wave 4's parallel fan-out is dispatched as one `Task` batch or chunked to
  bound concurrency.
- Per-doc model overrides beyond the PRD/SRS=Opus default (brief `model:` key already
  allows this).
- The `synthesis-agent` system-prompt text (the behavioral contract) — authored during
  implementation, reviewed like `scaffold-dev:implementer-agent`.
