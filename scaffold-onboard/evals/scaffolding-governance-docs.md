# Eval: scaffold-onboard:scaffolding-governance-docs

> Behavior eval for the `scaffolding-governance-docs` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-onboard:scaffolding-governance-docs` skill (per SPEC §5.3 + §10) emits the documented default and `--full` doc sets from a valid MASTER-SPEC.md, preserves v0.1.0's `PROJECT_PLAN.md` semantics byte-for-byte (Phase-2-Strategy-derived timeline — NOT the R1 hierarchy, which lives in `ROADMAP.md` and is emitted by a different skill, §5.4 `planning-project-roadmap`), and respects manifest-aware output routing per the §10.1 routing table.

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp repo, `.claude/` state, composition manifest, marketplace cache directories, and any preexisting MASTER-SPEC fragments described in the scenario.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input, the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**Reproducibility note:** the orchestrator MUST clear any `${CLAUDE_PLUGIN_DATA}/scaffold-docs-*` markers and remove any pre-existing governance doc outputs (PRD.md, SRS.md, BACKLOG.md, PROJECT_PLAN.md, ROADMAP.md, ADR-*.md, RISK_REGISTER.md, TEST_STRATEGY.md, CUTOVER_PLAN.md, EVALS_PLAN.md, etc.) from both the canonical and ai_workspace roots between scenarios. Scenarios are independent; ordering does not matter.

**Fixture MASTER-SPEC.md:** scenarios assume a valid, schema-clean MASTER-SPEC.md (passes `sf_spec_validate` from lib/parser.sh) is present at the routing destination. The fixture is the v0.1.0 reference MASTER-SPEC from `scaffold-onboard/fixtures/master-spec-reference.md` (or equivalent), reused across scenarios.

## Scenarios

### S1 — Default `/scaffold-docs` emits 5 docs

**Setup:**
- Tmp repo with `git init`; valid fixture `MASTER-SPEC.md` present at cwd (no manifest → single-repo mode).
- No composition.json (architect-critic / ai-mentor / superpowers all absent).
- No pre-existing governance doc outputs in cwd.
- `${CLAUDE_PLUGIN_DATA}` points to a fresh empty dir.

**Trigger:** target subagent user message: `/scaffold-docs`

**Expected behavior:**
- Skill triggers on `/scaffold-docs` (slash command resolves through the wrapper to `scaffold-onboard:scaffolding-governance-docs`).
- Skill validates MASTER-SPEC.md (via `sf_spec_validate`); validation succeeds.
- Skill emits exactly the 5 default docs per SPEC §5.3:
  - `PRD.md`
  - `SRS.md`
  - `BACKLOG.md`
  - `PROJECT_PLAN.md` (v0.1.0 Phase-2-Strategy-derived timeline output — NOT R1 hierarchy)
  - `ADR-0001.md` (initial architecture decision per v0.1.0 convention)
- Skill does NOT emit any of the 9 `--full`-gated docs (RISK_REGISTER.md, TEST_STRATEGY.md, CUTOVER_PLAN.md, EVALS_PLAN.md, etc.).
- Skill does NOT emit `ROADMAP.md` (that's planning-project-roadmap's responsibility per §5.4).
- Skill writes outputs to cwd (single-repo fallback per §10.3).

**Assertion (judge subagent verifies):**
- Exactly 5 new files exist after the run: `PRD.md`, `SRS.md`, `BACKLOG.md`, `PROJECT_PLAN.md`, `ADR-0001.md`.
- File count of governance docs in cwd is exactly 5 — no extras.
- `PROJECT_PLAN.md` content structure matches v0.1.0 baseline: contains timeline / milestones / resources / risks sections derived from MASTER-SPEC §Strategy (Phase 2). It does NOT contain a `Phase → Sprint → Vertical Slice` hierarchy, demo criteria skeletons, or `auto:`/`user:` grammar (those belong in `ROADMAP.md`).
- No `ROADMAP.md` was written by this skill.
- No `RISK_REGISTER.md`, `TEST_STRATEGY.md`, `CUTOVER_PLAN.md`, `EVALS_PLAN.md` (or any other `--full`-gated artifact) was written.
- No errors or warnings emitted.

---

### S2 — `/scaffold-docs --full` emits 14 docs

**Setup:**
- Tmp repo with `git init`; valid fixture `MASTER-SPEC.md` present at cwd (no manifest → single-repo mode).
- No composition.json.
- No pre-existing governance doc outputs in cwd.
- `${CLAUDE_PLUGIN_DATA}` points to a fresh empty dir.

**Trigger:** target subagent user message: `/scaffold-docs --full`

**Expected behavior:**
- Skill triggers on `/scaffold-docs --full` (slash command resolves through the wrapper; `$ARGUMENTS` carries `--full`).
- Skill validates MASTER-SPEC.md (via `sf_spec_validate`); validation succeeds.
- Skill emits the 5 default docs (per S1) PLUS the 9 `--full`-gated docs per SPEC §5.3, for 14 total.
- The 9 additional docs include (per §5.3 enumeration): `RISK_REGISTER.md`, `TEST_STRATEGY.md`, `CUTOVER_PLAN.md`, `EVALS_PLAN.md`, plus 5 additional governance artifacts as enumerated in the skill body per the doc catalog (e.g., `ADR-0002.md` and beyond, `STAKEHOLDER_MAP.md`, `GLOSSARY.md`, `COMPLIANCE_NOTES.md`, `RELEASE_PLAN.md` — exact filenames per the skill's documented `--full` catalog).
- Of the 9 `--full` docs, 3 are LLM-gated per Phase 9.3.1 of the build sequence (the LLM-content-heavy ones, e.g., `RISK_REGISTER.md`, `EVALS_PLAN.md`, `CUTOVER_PLAN.md` — final assignment per skill body). When the LLM-gating condition is satisfied in this fixture (MASTER-SPEC has the required source sections populated), all 3 SHOULD emit; when not satisfied, the skill MUST emit a skip-with-reason marker rather than silently omit.
- Skill does NOT emit `ROADMAP.md` even under `--full` (still §5.4's responsibility).
- Skill writes outputs to cwd (single-repo fallback).

**Assertion (judge subagent verifies):**
- The 5 default docs from S1 are all present.
- 9 additional `--full` docs are present, bringing the total to 14 governance doc files written by this skill in this run.
- The 3 LLM-gated docs (per Phase 9.3.1 of the build sequence) are EITHER present with non-empty content OR accompanied by an explicit skip-with-reason marker line in the transcript naming the gate that wasn't satisfied. Silent omission is a FAIL.
- No `ROADMAP.md` was written.
- `PROJECT_PLAN.md` content under `--full` is still the v0.1.0 Phase-2-derived timeline (the `--full` flag expands the doc *set*, not the contents of `PROJECT_PLAN.md`).
- No errors or warnings emitted (except the documented skip-with-reason markers for LLM-gated docs, if any apply).

---

### S3 — `PROJECT_PLAN.md` unchanged from v0.1.0 (no R1 hierarchy leakage)

**Setup:**
- Tmp repo with `git init`; valid fixture `MASTER-SPEC.md` present at cwd (no manifest).
- Fixture MASTER-SPEC has a richly populated Phase 2 Strategy section (so PROJECT_PLAN.md has real content to derive).
- A v0.1.0 golden reference of the expected `PROJECT_PLAN.md` is available to the judge at `scaffold-onboard/fixtures/PROJECT_PLAN.golden.md` (derived from the same fixture MASTER-SPEC under the v0.1.0 skill build). The judge compares structure (not byte-identical — wording may have stylistic drift across runs) using a normalized section-skeleton match.

**Trigger:** target subagent user message: `/scaffold-docs`

**Expected behavior:**
- Skill emits `PROJECT_PLAN.md` with the v0.1.0 structure: timeline (milestones, dates / horizons), resources, risks summary, no R1 hierarchy.
- The R1 Phase → Sprint → Vertical Slice hierarchy is NOT written into `PROJECT_PLAN.md` by this skill.
- No `auto:`/`user:` demo criteria grammar appears in `PROJECT_PLAN.md`.
- `ROADMAP.md` is NOT written by this skill (it's a separate file emitted by `planning-project-roadmap` per §5.4; running `/scaffold-docs` alone should not produce a `ROADMAP.md`).

**Assertion (judge subagent verifies):**
- `PROJECT_PLAN.md` structure matches the v0.1.0 golden reference at section-skeleton granularity: same top-level section headings in same order (timeline / milestones / resources / risks per the v0.1.0 template).
- `PROJECT_PLAN.md` does NOT contain headings or bulleted entries shaped like `Phase N: <name>`, `Sprint N.M:`, `VS-N.M:`, or `## Roadmap overview` (these are the R1 hierarchy markers per §7).
- `PROJECT_PLAN.md` does NOT contain any `auto:` or `user:` demo-criteria lines (these are R3 grammar per §9, owned by `authoring-vertical-slice-demo` writing into `ROADMAP.md`).
- No file named `ROADMAP.md` was created in this run. (Confirms separation of skill responsibilities: governance-docs does not author the R1 hierarchy file.)
- The judge MAY note acceptable wording drift in PROJECT_PLAN.md prose but MUST FAIL if the section skeleton diverges from the v0.1.0 golden.

---

### S4 — Manifest routing per §10.1 (canonical + ai_workspace destinations)

**Setup:**
- Dual-repo fixture: tmp parent dir with two sibling repos and a `.workspace/pairing.json` manifest at the parent.
  - `canonical/` — git-init'd repo intended as the source-of-truth product repo.
  - `ai_workspace/` — git-init'd repo intended for AI workspace artifacts.
  - `.workspace/pairing.json` carries `routing.backlog=canonical`, `routing.project_plan=canonical`, `routing.prd=canonical`, `routing.srs=canonical`, `routing.product_adrs=canonical`, `routing.process_adrs=ai_workspace` (per SPEC §10.1 routing table) plus the rest of the 15-key schema.
- Valid fixture `MASTER-SPEC.md` already routed to `ai_workspace/MASTER-SPEC.md` per §10.1.
- cwd for the target subagent is set to `canonical/` (manifest discovery walks up to find `.workspace/pairing.json`).
- No pre-existing governance doc outputs in either repo.

**Trigger:** target subagent user message: `/scaffold-docs --full`

**Expected behavior:**
- Skill discovers manifest via `sf_discover_manifest` (walks up from `canonical/` cwd, finds `.workspace/pairing.json`).
- For each emitted doc, skill resolves the destination via `sf_resolve_output_path` against the logical name in §10.1.
- canonical-routed docs land in `canonical/`: `BACKLOG.md`, `PROJECT_PLAN.md`, `PRD.md`, `SRS.md`, and any product ADR (`ADR-0001.md` mapped via `product_adrs`).
- ai_workspace-routed docs land in `ai_workspace/`: process ADRs (mapped via `process_adrs` logical name).
- No outputs from this skill land outside these two roots.

**Assertion (judge subagent verifies):**
- At least 2 docs (e.g., `BACKLOG.md`, `PROJECT_PLAN.md`, `PRD.md`, `SRS.md`) land at the `canonical/` destination per `routing.<name>=canonical` in the manifest.
- At least 1 process-ADR-class doc (per `routing.process_adrs=ai_workspace`) lands at the `ai_workspace/` destination.
- No governance doc from this skill was written to the cwd (`canonical/`'s root in a way that bypasses the manifest), to `${CLAUDE_PLUGIN_DATA}`, or to any path outside `canonical/` and `ai_workspace/`.
- For each emitted doc, the judge can map the produced absolute path back to the `routing.<logical_name>` entry in the §10.1 table; any path that doesn't match its documented routing is a FAIL.
- `MASTER-SPEC.md` is not duplicated, moved, or overwritten by this skill (read-only consumer).

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 4 scenarios PASS.

## Out of scope for this eval

- `planning-project-roadmap` skill behavior (covered by `evals/planning-project-roadmap.md`, T0.2). This eval only asserts that `scaffolding-governance-docs` does NOT trespass on planning-project-roadmap's output (`ROADMAP.md`).
- Content quality of the 3 LLM-gated `--full` docs — this eval verifies emission (or explicit skip-with-reason), not prose quality. LLM-content-quality evals belong in a separate suite.
- `--regenerate` flag behavior on top of pre-existing governance docs — covered by integration tests (PLAN T7.1) alongside `/onboard --regenerate` patterns.
- architect-critic invocation moments — this skill is downstream of MASTER-SPEC close (the critic already ran during `/onboard` per §12.1). `scaffolding-governance-docs` does not itself invoke architect-critic.
- ai-mentor + superpowers composition (orthogonal; this eval keeps them absent to isolate the scaffolding-governance-docs skill behavior).
- Workspace-init manifest schema extension for `routing.roadmap` (per §10.4) — irrelevant to this skill, which does not write `roadmap`.
- v0.1.0 byte-identical regression of all 5 default docs — covered by retained v0.1.0 test suite (per §13.1 test baseline). This eval focuses on v0.2 behavioral contracts: doc-set cardinality, PROJECT_PLAN non-trespass, manifest routing.
