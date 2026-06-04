# Eval: scaffold-onboard:scaffolding-memory-bank

> Behavior eval for the `scaffolding-memory-bank` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-onboard:scaffolding-memory-bank` skill (per SPEC §5.2 + §10 routing + §14 Karpathy section) deterministically derives the 14-file memory bank from MASTER-SPEC.md, seeds the R2 `## Machine-checkable rules` section in `03-code-patterns.md` as empty (heading + invitation comment, zero rule blocks), routes outputs per manifest, and conditionally emits the Karpathy "Behavioral Discipline" section in CLAUDE.md based on the Phase 10.4 opt-in state answer.

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp repo, `.claude/` state, composition manifest, marketplace cache directories, MASTER-SPEC.md content, workspace pairing manifest (when applicable), and any preexisting memory-bank files described in the scenario.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input, the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**Reproducibility note:** the orchestrator MUST clear `${CLAUDE_PLUGIN_DATA}/onboarding-state.json` and any `.claude/marker-*` files between scenarios. Scenarios are independent; ordering does not matter.

## Scenarios

### S1 — Fresh derivation from MASTER-SPEC (single-repo, no manifest, Karpathy opted in)

**Setup:**
- Tmp directory; `git init`.
- A complete, v0.1.0-style `MASTER-SPEC.md` is present at the repo root (the orchestrator copies a known-good fixture covering all 10 phases of content used by the derivation templates).
- No `.claude/memory-bank/` directory exists yet.
- No `.workspace/pairing.json` manifest anywhere up the tree (single-repo mode → routing falls back to `$(pwd)` per SPEC §10.3).
- No composition.json (ai-mentor / superpowers / architect-critic all absent).
- `${CLAUDE_PLUGIN_DATA}/onboarding-state.json` present with `phase=10` (completed) and `answers["phase_10.4.include_karpathy"] = "yes"`.

**Trigger:** target subagent user message: `/scaffold-project`

**Expected behavior:**
- Skill triggers on `/scaffold-project` (resolves to `scaffold-onboard:scaffolding-memory-bank`).
- Skill validates MASTER-SPEC.md via `sf_spec_validate` (no errors raised on the fixture).
- Skill derives and emits all 14 memory-bank files under `$(pwd)/.claude/memory-bank/`:
  - **8 derived from MASTER-SPEC** — `00-project-brief.md`, `01-product-context.md`, `02-system-patterns.md`, `03-code-patterns.md`, `04-tech-context.md`, `07-constraints.md`, `08-governance.md`, `index.md`. Content is materialized from the corresponding `.tmpl` files with MASTER-SPEC-derived substitutions.
  - **4 live-seed (preserve on re-derive)** — `05-active-context.md`, `06-progress.md`, `09-known-issues.md`, `10-decisions-log.md`. On fresh derivation these are emitted with their initial seeded content (effectively starter scaffolding the user will fill in).
  - **1 static (copy-once)** — `WORKFLOW.md`. Copied verbatim from the template.
  - **1 seeded index** — `tech-debt.md`. Rendered header-only from template; scaffold-dev appends entries over time.
- `03-code-patterns.md` contains a `## Machine-checkable rules` section heading near the end, with a seeded invitation comment (e.g., a comment line inviting the user to add rules manually or via the `authoring-machine-checkable-rules` skill) and **zero** populated `<!-- mcrule:start ... -->` blocks.
- Skill emits `CLAUDE.md` at the routing destination (single-repo: `$(pwd)/CLAUDE.md`). Because `phase_10.4.include_karpathy = "yes"`, CLAUDE.md contains the Karpathy "Behavioral Discipline" section with the verbatim attribution language *"Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)"* and all four principles (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution).
- Skill emits `.claude/settings.json` at the routing destination (single-repo: `$(pwd)/.claude/settings.json`).
- No legacy IPC file writes (no `inbox/` / `outbox/` activity).

**Assertion (judge subagent verifies):**
- After the turn, the directory `$(pwd)/.claude/memory-bank/` exists and contains exactly these 14 files: `00-project-brief.md`, `01-product-context.md`, `02-system-patterns.md`, `03-code-patterns.md`, `04-tech-context.md`, `05-active-context.md`, `06-progress.md`, `07-constraints.md`, `08-governance.md`, `09-known-issues.md`, `10-decisions-log.md`, `index.md`, `WORKFLOW.md`, `tech-debt.md`.
- The 8 derived files contain content shaped by MASTER-SPEC (judge spot-checks at least 2 of them for substituted project-specific content rather than raw template placeholders like `{{project_name}}`).
- The 4 live-seed files (`05-active-context.md`, `06-progress.md`, `09-known-issues.md`, `10-decisions-log.md`) are present and contain initial seeded scaffolding (judge verifies they read as a starter file, not as a copy of MASTER-SPEC content).
- `WORKFLOW.md` is byte-equivalent to the static template (judge spot-checks first heading + opening paragraph match).
- `03-code-patterns.md` contains the literal heading `## Machine-checkable rules` AND contains an invitation comment pointing the user at the `authoring-machine-checkable-rules` skill (or equivalent natural-language invitation), AND contains zero `<!-- mcrule:start` sentinels (the section is seeded as empty by design).
- `CLAUDE.md` exists at `$(pwd)/CLAUDE.md` and contains the verbatim string `Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)` and all four principle names (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution).
- `.claude/settings.json` exists at `$(pwd)/.claude/settings.json` and parses as valid JSON.
- Target subagent's tool-call log shows no writes to any `inbox/` or `outbox/` paths.
- No errors or warnings emitted by the skill.

---

### S2 — R2 rules section seeded as empty (heading + invitation, zero rules)

**Setup:**
- Tmp directory; `git init`.
- Valid `MASTER-SPEC.md` at the repo root (same fixture style as S1).
- No `.claude/memory-bank/` directory yet.
- No manifest (single-repo fallback).
- `${CLAUDE_PLUGIN_DATA}/onboarding-state.json` present with `phase=10` (completed) and `answers["phase_10.4.include_karpathy"] = "no"` (Karpathy off — isolates the R2 assertion).

**Trigger:** target subagent user message: `/scaffold-project`

**Expected behavior:**
- Skill derives the memory bank as in S1.
- `03-code-patterns.md` is emitted with the `## Machine-checkable rules` section present at the documented placement.
- That section contains a human-readable invitation (prose or HTML comment) telling the user how to add machine-checkable rules — directly editing the section using the §8.2 sentinel grammar, or invoking the `scaffold-onboard:authoring-machine-checkable-rules` skill (per SPEC §5.5).
- The section contains **zero** `<!-- mcrule:start` / `<!-- mcrule:end -->` blocks. The skill seeds the section; it does NOT populate any rules. Populating rules is the responsibility of skill 5.5 (out of scope for this eval).
- The rest of `03-code-patterns.md` (code-pattern prose derived from MASTER-SPEC) is unaffected by the seeding.

**Assertion (judge subagent verifies):**
- `03-code-patterns.md` exists at `$(pwd)/.claude/memory-bank/03-code-patterns.md`.
- The file contains the exact literal heading `## Machine-checkable rules`.
- Within that preserve zone (between `<!-- mcrules:preserve:start -->` and `<!-- mcrules:preserve:end -->`), the count of occurrences of the substring `<!-- mcrule:start` is exactly zero.
- Within that section, an invitation to author rules is present — either prose text mentioning "add rules" / "machine-checkable" / "rules can be authored" or an HTML comment such as `<!-- TODO: add machine-checkable rules ... -->`. The invitation references the `authoring-machine-checkable-rules` skill, the §8.2 sentinel grammar, or both.
- The remainder of `03-code-patterns.md` (content outside the `## Machine-checkable rules` section) still contains MASTER-SPEC-derived code-pattern content (judge spot-checks for substituted content rather than raw `{{...}}` placeholders).
- CLAUDE.md does NOT contain the Karpathy attribution line `Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)` (opt-in was "no" in this scenario).

---

### S3 — Manifest-present routing to ai_workspace

**Setup:**
- Two sibling tmp directories representing a dual-repo workspace:
  - `<tmp>/canonical/` — `git init`, contains a valid `MASTER-SPEC.md` at its root.
  - `<tmp>/ai_workspace/` — `git init`, empty.
- A `.workspace/pairing.json` manifest exists at `<tmp>/canonical/.workspace/pairing.json` (per workspace-init v0.1's pairing schema), with:
  - `canonical.root` resolving to `<tmp>/canonical`
  - `ai_workspace.root` resolving to `<tmp>/ai_workspace`
  - `routing.memory_bank = "ai_workspace"`
  - `routing.claude_md = "ai_workspace"`
  - `routing.agents_md = "ai_workspace"`
  - `routing.scaffold_project_outputs = "ai_workspace"`
- `cwd` for the target subagent is `<tmp>/canonical/` at trigger time (manifest discovery walks up from cwd and finds `<tmp>/canonical/.workspace/pairing.json`).
- `${CLAUDE_PLUGIN_DATA}/onboarding-state.json` present with `phase=10` (completed) and `answers["phase_10.4.include_karpathy"] = "yes"`.

**Trigger:** target subagent user message: `/scaffold-project`

**Expected behavior:**
- Skill discovers the manifest via `sf_discover_manifest` (per SPEC §10.2).
- Skill resolves `memory_bank` → `<tmp>/ai_workspace/.claude/memory-bank/` (NOT `<tmp>/canonical/.claude/memory-bank/`).
- All 14 memory-bank files land under `<tmp>/ai_workspace/.claude/memory-bank/`.
- `CLAUDE.md` is emitted at `<tmp>/ai_workspace/CLAUDE.md` (routes per `claude_md` entry).
- `.claude/settings.json` is emitted under the ai_workspace destination per `scaffold_project_outputs`.
- The Karpathy "Behavioral Discipline" section appears in the emitted CLAUDE.md (opt-in was "yes" for this scenario, providing the cross-S1/S3 Karpathy attribution check).
- The canonical repo (`<tmp>/canonical/`) receives **no** memory-bank, CLAUDE.md, or scaffold-project outputs (routing must not double-write).

**Assertion (judge subagent verifies):**
- `<tmp>/ai_workspace/.claude/memory-bank/` exists and contains all 14 expected files (same names as S1).
- `<tmp>/canonical/.claude/memory-bank/` does NOT exist (no routing leakage to the canonical repo).
- `<tmp>/ai_workspace/CLAUDE.md` exists; `<tmp>/canonical/CLAUDE.md` does NOT exist.
- `<tmp>/ai_workspace/CLAUDE.md` contains the verbatim string `Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)` and all four principle names (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution).
- `<tmp>/ai_workspace/.claude/settings.json` exists and parses as valid JSON.
- Target subagent's tool-call log shows file writes targeting paths under `<tmp>/ai_workspace/`, with zero writes targeting `<tmp>/canonical/` (other than reads of MASTER-SPEC.md).
- No errors or warnings emitted by the skill.

---

### S4 — Manifest-absent routing to cwd (single-repo fallback)

**Setup:**
- Tmp directory; `git init`.
- Valid `MASTER-SPEC.md` at the repo root.
- No `.workspace/pairing.json` anywhere up the tree from cwd (single-repo mode).
- No `.claude/memory-bank/` directory yet.
- `${CLAUDE_PLUGIN_DATA}/onboarding-state.json` present with `phase=10` (completed) and `answers["phase_10.4.include_karpathy"] = "no"` (Karpathy off — keeps the focus on the routing fallback, not on conditional emission).

**Trigger:** target subagent user message: `/scaffold-project`

**Expected behavior:**
- Skill runs `sf_discover_manifest` (per SPEC §10.2); the walk reaches `/` without finding a pairing manifest and returns empty.
- Per SPEC §10.3 single-repo fallback, all outputs route to `$(pwd)/<rel_path>` — exactly the v0.1.0 behavior.
- 14 memory-bank files land under `$(pwd)/.claude/memory-bank/`.
- `CLAUDE.md` lands at `$(pwd)/CLAUDE.md`.
- `.claude/settings.json` lands at `$(pwd)/.claude/settings.json`.
- No writes to any path outside `$(pwd)`.

**Assertion (judge subagent verifies):**
- `$(pwd)/.claude/memory-bank/` exists and contains all 14 expected files.
- `$(pwd)/CLAUDE.md` exists.
- `$(pwd)/CLAUDE.md` does NOT contain the Karpathy attribution string (opt-in was "no" in this scenario).
- `$(pwd)/.claude/settings.json` exists and parses as valid JSON.
- Target subagent's tool-call log shows all file writes targeting paths under `$(pwd)` — no writes to any ancestor directory or sibling tree.
- No errors or warnings emitted by the skill (in particular, no "manifest not found" error — the single-repo path is the documented v0.1.0-equivalent behavior, not an error condition).

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 4 scenarios PASS.

## Out of scope for this eval

- Re-derivation behavior with preexisting live-seed files (`05-active-context.md`, `06-progress.md` preservation on re-run) — covered by integration tests (PLAN T7.x)
- Population of the `## Machine-checkable rules` section — that's the responsibility of the `scaffold-onboard:authoring-machine-checkable-rules` skill (SPEC §5.5), evaluated separately
- Governance docs derivation (PRD, SRS, BACKLOG, etc.) — covered by `evals/scaffolding-governance-docs.md` (T0.7)
- ROADMAP.md / Phase → Sprint → Vertical Slice hierarchy — covered by `evals/planning-project-roadmap.md`
- architect-critic in-conversation invocation at scaffolding-memory-bank time — composition is suggested per SPEC §5.2 but not invariant; isolated by keeping composition.json absent across all four scenarios
- Workspace-init manifest schema extension for `routing.roadmap` (SPEC §10.4) — orthogonal; this eval exercises `routing.memory_bank` / `routing.claude_md` / `routing.scaffold_project_outputs`, all of which are present in workspace-init v0.1's manifest as-shipped
