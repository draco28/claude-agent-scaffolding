# Handoff: scaffold-onboard v0.2 SPEC authoring

**Purpose:** seed a fresh Claude Code session to author `docs/SPEC-scaffold-onboard-v02.md` — the v0.2 retrofit of scaffold-onboard that satisfies the input contract scaffold-dev v0.1 + workspace-init v0.1 + the skill-first principle require.

**Author:** carried over from the session that completed scaffold-dev v0.1 SPEC brainstorm (2026-05-20 → 2026-05-22), including a spec review pass that surfaced concrete requirements.

**Context:** scaffold-onboard v0.1.0 ships today (~163 tests, mechanical bash derivation of MASTER-SPEC → 11 memory-bank files + 5/14 governance docs). v0.2 is a substantial retrofit driven by three forces:
1. The dual-repo workspace topology (workspace-init manifest contract; routing per file class)
2. Skill-first principle (per Pass D) — current v0.1 is CLI-tool-shaped with mechanical bash derivation
3. scaffold-dev v0.1 requires specific outputs from scaffold-onboard that v0.1.0 doesn't produce (R1/R2/R3)

---

## 1. Goal of the next session

Author `docs/SPEC-scaffold-onboard-v02.md` and `docs/PLAN-scaffold-onboard-v02.md`. Then implement via subagent-driven dev (mirror of how scaffold-onboard v0.1.0 was built).

The build follows these stages (per established workflow):

1. **Brainstorm** — invoke `superpowers:brainstorming`. Drive the open questions in §3 below. Output: settled decisions captured in SPEC stub.
2. **SPEC** — full design doc.
3. **PLAN** — task-by-task TDD breakdown.
4. **Implement** — subagent-driven (per `superpowers:subagent-driven-development`).

---

## 2. What's already settled (consume these as constraints)

### 2.1 Skill-first restructuring (Pass D principle)

**v0.1.0 was wrong for the skill-first direction.** It uses bash to mechanically derive outputs from MASTER-SPEC; the `/onboard` slash command is the primary surface; skills don't exist. **v0.2 must redesign to skill-first** (per cross-cutting Pass D principle settled 2026-05-17):

- **P1** — Every plugin capability ships as a skill (description-matched auto-invocation)
- **P2** — Logic in markdown bodies that Claude reads + acts on; bash reserved for bookkeeping (state writes, file copies, atomic mv, jq transforms)
- **P3** — Three-layer: hooks (ambient) + skills (auto-invocable capabilities) + slash commands (explicit handles)

Reference: [project_skill_first_retrofit_queue memory] — scaffold-onboard v0.2 is queued for skill-first retrofit alongside architect-critic v0.2 + ai-mentor v1.4.

### 2.2 Dual-repo workspace topology

scaffold-onboard v0.2 runs inside an AI workspace (created by workspace-init). It reads the pairing manifest at `<ai-workspace>/.workspace/pairing.json` to learn:

- Routing rules (which output goes to AI workspace vs canonical)
- Path resolution (`${var}` and `${PLUGIN_DATA:<plugin-name>}` syntax — both resolved via workspace-init's shared `mi_manifest_resolve` helper)
- Project-type (personal / work)
- git_policy (every git op respects this)

scaffold-onboard v0.2's outputs route per the manifest. If manifest absent: fall back to single-repo behavior (preserves v0.1.0 capability for users who haven't adopted workspace-init).

Reference: `docs/SPEC-workspace-init.md` §6 for the full manifest schema.

### 2.3 Input contract: R1, R2, R3 (scaffold-dev's requirements)

scaffold-dev v0.1 consumes specific outputs from scaffold-onboard. v0.2 MUST produce these:

#### R1 — Project plan with Phase → Sprint → Vertical-Slice hierarchy

**Discovered:** 2026-05-20 (scaffold-dev B1).
**Current state (v0.1.0):** `PROJECT_PLAN.md` derived from MASTER-SPEC's Phase 2 (Strategy: timeline / resources / risks). NO phase-sprint-vertical-slice decomposition.
**v0.2 must produce:** `PROJECT_PLAN.md` (or successor doc) decomposing the project into:
1. **Phases** (high-level milestones, typically ~4)
2. **Sprints** within each phase (multiple per phase)
3. **Vertical slices** within each sprint (multiple per sprint; each must be **demoable end-to-end**)

The hierarchy is what scaffold-dev's orchestrator session reads when starting work on "phase 1, sprint 1, vertical slice 1." Without this structure, scaffold-dev cannot orient.

**Mechanical template approach won't work for this.** The hierarchy must be authored interactively / skill-driven, not extracted from a single MASTER-SPEC phase. This is the most foundational v0.2 change.

#### R2 — Machine-checkable project rules in memory bank

**Discovered:** 2026-05-21 (scaffold-dev B3 Q2 settlement).
**Current state:** `.claude/memory-bank/03-code-patterns.md` + `08-governance.md` are prose markdown. Rules are human-readable but not machine-checkable.
**v0.2 must produce:** memory-bank patterns include a **machine-checkable rules section** that scaffold-dev's `implementation-checking` skill mechanically evaluates per work item.

Concrete shape (TBD in v0.2 brainstorm; candidates):
- Structured section in `03-code-patterns.md`: `## Machine-checkable rules` with a documented mini-DSL (e.g., `banned_imports: [requests, urllib3]; coverage_floor: 80%; style_invariants: [no print statements outside tests]`)
- Dedicated file `.claude/memory-bank/rules.json` or `rules.yaml`
- Hybrid: human-readable rules in 03-code-patterns.md with machine-readable rules embedded in fenced code blocks

scaffold-dev v0.1's `implementation-checking` skill consumes these rules at round close, runs them against the work item's diff, surfaces violations as part of the verification gate.

Without machine-checkable rules, scaffold-dev v0.1 falls back to AC-verification-only mode (still functional, less rigorous). v0.2 unlocks full rule-check verification.

#### R3 — Demo criteria captured per vertical slice with auto:/user: grammar

**Discovered:** 2026-05-21 (scaffold-dev B2 Q6) + refined 2026-05-22 (spec review H1).
**Current state:** scaffold-onboard's vertical-slice output doesn't have a defined demo criteria field.
**v0.2 must produce:** each vertical slice in the project plan includes **concrete executable demo criteria** with this grammar:

```markdown
## Demo criteria
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

scaffold-dev's `closing-vertical-slice` skill at slice close parses each step:
- `auto:` → runs command in canonical (post-merge); checks exit code (default success) OR matches output pattern
- `user:` → presents step + expected; user reports pass/fail

### 2.4 architect-critic invocation: skill-based, not inbox/outbox

scaffold-onboard v0.1.0 currently invokes architect-critic via file-IPC inbox/outbox (per scaffold-onboard SPEC §8.3 + scaffold-onboard's `lib/compose.sh`). That was the wrong architecture; v0.2 should invoke architect-critic via **in-conversation skill invocation** (same as scaffold-dev's pattern):

- composition.json probe for detection (lazy; cached per session)
- When architect-critic moment reached (e.g., MASTER-SPEC close audit), invoke architect-critic's `critiquing-spec` skill (v0.2 entry skill) in-conversation
- architect-critic's skill runs, produces challenges, user resolves, control returns

Drop the inbox/outbox protocol. Drop `lib/compose.sh`'s critic-related code (`sf_compose_build_critic_request`, `sf_compose_read_critic_response`). architect-critic v0.2 will be skill-first (per the parallel handoff doc — `HANDOFF-architect-critic-v02-spec.md`).

This simplifies scaffold-onboard v0.2 significantly. The complex `inbox/outbox` protocol becomes a no-op — just call the skill.

### 2.5 Manifest-routing patch (already specified in scaffold-onboard v0.1 SPEC's revisions to v0.2)

When manifest present: scaffold-onboard outputs route per `manifest.routing.*`:
- master_spec → AI workspace
- executive_summary → canonical
- memory_bank → AI workspace
- claude_md → AI workspace
- agents_md → AI workspace
- scaffold_project_outputs (the 11 memory-bank files + CLAUDE.md) → AI workspace
- backlog, project_plan, prd, srs, executive_summary, product_adrs → canonical
- process_adrs → AI workspace
- sprint_specs, implementation_handoffs, brainstorm_artifacts → AI workspace

When manifest absent (single-repo mode preserved): scaffold-onboard outputs route to `<cwd>` as today.

New helper: `sf_resolve_output_path(logical_name)` — manifest-aware path resolver. Uses workspace-init's `mi_manifest_resolve` for `${var}` + `${PLUGIN_DATA:<name>}` expansion.

### 2.6 Memory bank: no MCP, plain markdown, tiered loading

scaffold-onboard v0.2 must NOT introduce MCP or any external indexing for the memory bank. Plain markdown only. Retrieval via the tiered loading pattern scaffold-onboard already has (Tier 0 always preloaded by SessionStart hook; Tier 1 branch-loaded by query type).

Memory bank file count stays at 11 (no new files).

Reference: scaffold-dev SPEC §15.1.

---

## 3. What's open — questions to brainstorm

### Q1 — How does v0.2's `/onboard` produce R1's hierarchy?

The current 10-phase conversation derives MASTER-SPEC. R1 requires phase/sprint/vertical-slice decomposition. Two design paths:

- **Extend the 10-phase conversation** with new phases for sprint planning + vertical-slice decomposition (e.g., Phase 11 — Sprint Decomposition; Phase 12 — Vertical Slice Authoring)
- **Spin off a separate skill** (`planning-project-roadmap` or similar) that's invoked AFTER `/onboard` completes. /onboard produces MASTER-SPEC + initial PROJECT_PLAN draft; the new skill iterates on the hierarchy.

Pros/cons each. Trade-offs around when the user has enough information to decompose into vertical slices (might need MASTER-SPEC done first; might need partial code already; varies by project).

### Q2 — Where do machine-checkable rules live, and what's the DSL?

R2 says memory-bank patterns must include machine-checkable rules. Three candidate shapes:
- Structured section in `03-code-patterns.md`
- Dedicated `.claude/memory-bank/rules.json`/yaml file
- Hybrid embedded code blocks in human-readable doc

DSL design: what rule types? At minimum:
- `banned_imports`: list of import patterns to forbid
- `coverage_floor`: minimum test coverage percentage
- `style_invariants`: list of regex-based style checks
- (more?)

Who authors the rules? User during `/onboard`? User updates manually as patterns emerge? Auto-derived from existing code?

### Q3 — Skill surface for v0.2 (full skill catalog)

If v0.2 is skill-first, what skills ship? Candidates derived from v0.1.0's 3 commands + R1 needs + R2 needs:

- `onboarding-project` — twin of `/onboard`; drives the multi-phase guided conversation
- `scaffolding-memory-bank` — twin of `/scaffold-project`; derives memory bank files
- `scaffolding-governance-docs` — twin of `/scaffold-docs`; derives PRD/SRS/etc.
- `planning-project-roadmap` (Q1) — authors the hierarchical project plan with vertical slices
- `authoring-machine-checkable-rules` (Q2) — interactive rule authoring for R2
- `validating-master-spec` — pre-derivation sanity check
- (more?)

How many skills? ~6-10 target. Each ≤500 lines body per Pass D guidance.

### Q4 — Build sequence for v0.2 retrofit

v0.1.0 has 163 passing tests across 9 suites. v0.2 must:
- Add new skill surfaces (Phase 1 — author SKILL.md bodies)
- Add manifest-aware output routing (modify lib/memory-bank.sh + lib/docs.sh)
- Add R1 hierarchy authoring (likely new lib + new templates)
- Add R2 rule authoring + storage (new template + new memory-bank file or section)
- Drop critic file-IPC code (simplification)
- Maintain backwards compatibility (single-repo mode when manifest absent → existing 163 tests still pass)

Build sequence likely:
1. Phase 0 — Evals for new skill behaviors
2. Phase 1 — New SKILL.md bodies
3. Phase 2 — Reference sub-docs (Wabash-flavored examples)
4. Phase 3 — Utility scripts (manifest resolver, R1 hierarchy renderer, R2 rule parser)
5. Phase 4 — Hook updates (Tier 0 emission coordination with scaffold-dev's hook per scaffold-dev SPEC §15.1)
6. Phase 5 — Slash command wrappers (preserve existing 3 + maybe add `/plan-roadmap` for Q1)
7. Phase 6 — Subagent pressure tests
8. Phase 7 — Integration tests (manifest-present + manifest-absent modes)
9. Phase 8 — Drop inbox/outbox critic code; verify scaffold-onboard no longer depends on architect-critic's file-IPC
10. Phase 9 — Publish v0.2.0

### Q5 — Backwards compatibility policy

v0.1.0 users have memory-bank state and possibly invocation patterns built on the existing /onboard. v0.2 must:
- Not break existing test suites (163 must still pass with maybe minor adaptations)
- Preserve single-repo mode (manifest absent → behave as v0.1.0)
- Document migration path for v0.1.0 → v0.2 users
- Possibly: `/onboard --legacy-mode` flag for users who don't want the v0.2 hierarchy authoring

### Q6 — Composition with workspace-init beyond manifest reads

Does scaffold-onboard v0.2 know anything about workspace-init beyond reading the manifest? E.g.:
- Does scaffold-onboard's SessionStart hook check if manifest exists and surface a one-line note like "scaffold-onboard: manifest detected; routing outputs per workspace-init's manifest"?
- If user runs `/onboard` in a non-workspace-init'd directory, does scaffold-onboard suggest running workspace-init first, or just proceed in single-repo mode?

### Q7 — Composition with architect-critic v0.2

When does scaffold-onboard invoke architect-critic? v0.1.0 invokes at Phase 5 + Phase 7 + MASTER-SPEC close. v0.2 should preserve these moments but via skill invocation:
- Probe composition.json on /onboard start
- At each architect-critic moment, invoke `critiquing-spec` skill in-conversation
- User resolves challenges; control returns to onboard

No inbox/outbox.

---

## 3.5 External content to integrate (from spec review + research synthesis, 2026-05-22)

In addition to R1/R2/R3, scaffold-onboard v0.2 integrates the following content surfaced during the spec review pass:

### Karpathy CLAUDE.md behavioral principles (cherry-pick with attribution)

When generating the full tiered CLAUDE.md (in `/scaffold-project`), append an optional **"Behavioral Discipline"** section adapted from `forrestchang/andrej-karpathy-skills` (community-derived from Karpathy's Jan 2026 X-post observations, MIT). Four principles:

1. **Think Before Coding** — state assumptions, surface ambiguity, ask before guessing
2. **Simplicity First** — minimum code, no speculative abstractions
3. **Surgical Changes** — touch only what's needed, no orthogonal refactors
4. **Goal-Driven Execution** — vague asks → verifiable success criteria

**Attribution language:** *"Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)"* — NOT *"Karpathy's CLAUDE.md"* (the repo is community-derived, not authored by Karpathy).

**User opt-out:** offer at `/onboard` time (e.g., Phase 10 question: "include behavioral discipline section in CLAUDE.md? yes/no"). Default: yes.

These principles are **orthogonal** to our existing tiered-router CLAUDE.md (project-facts navigation). They define HOW the agent should BEHAVE; the tiered router defines WHERE things ARE. Both belong in CLAUDE.md, as separate sections.

### 3-timelines framing for R1 hierarchy (from `.claude/ghost-notes.md` transcript)

Per [project_thinking_discipline_content memory], the "Hidden Rules of Success" transcript principle #4 maps R1's hierarchy to a 3-timelines framing:
- **Phase** ≈ 5-year-ish vision (be a visionary)
- **Sprint** ≈ 12-18 month value (be valuable)
- **Vertical slice** ≈ 90-day visibility (be visible)

Use this framing when authoring the `/onboard` phases that elicit hierarchy decomposition. Example prompt: *"Your Phases are your visionary horizon — what's the project's 5-year shape? Sprints are your value-building windows — what gets built over 12-18 months that compounds? Vertical slices are your visibility cycles — what ships demoably in 90-day-ish windows?"*

Reference: `.claude/ghost-notes.md` lines 90-122 + `project_thinking_discipline_content` memory.

### ECC memory-persistence hook (study before finalizing hook coordination)

scaffold-dev SPEC §15.1 requires coordination between scaffold-onboard's SessionStart hook and scaffold-dev's hook to avoid Tier 0 token duplication. Study `affaan-m/everything-claude-code`'s `hooks/memory-persistence` for design ideas before finalizing scaffold-onboard v0.2's hook. Don't copy wholesale; treat as reference. Note: ECC is a mega-plugin (~232 skills) — our composable thesis differs, so adopt patterns not packaging.

Reference: [project_post_spec_exploration_queue memory] for full ECC context.

---

## 4. Reference material the new session should read

Order matters.

1. **This document** — full briefing
2. **`docs/SPEC-workspace-init.md`** — manifest schema (§6) + integration §11; required to understand what scaffold-onboard v0.2 reads from manifest
3. **`docs/SPEC-scaffold-dev.md`** — orchestrator-implementer architecture; understand what scaffold-dev needs from scaffold-onboard (R1/R2/R3 specifically). Read §16.2 + §4.1 chain + §14.1 (auto/user grammar)
4. **`docs/SPEC-scaffold-onboard.md`** — v0.1.0 spec (the current shipping plugin)
5. **`docs/PLAN-scaffold-onboard.md`** — v0.1.0 implementation plan (study build sequence patterns)
6. **`scaffold-onboard/lib/compose.sh`** — current critic IPC code (to be removed in v0.2)
7. **`scaffold-onboard/lib/memory-bank.sh`** + **`scaffold-onboard/lib/docs.sh`** — current derivation logic (to be augmented with manifest-aware routing in v0.2)
8. **Auto-memory** (always loaded; relevant individual files):
   - `project_scaffold_onboard_v02_contract_from_dev.md` — the R1/R2/R3 contract this handoff captures (authoritative reference)
   - `project_skill_first_retrofit_queue.md` — broader retrofit context
   - `project_workspace_init_v02_deferrals.md` — what workspace-init defers (not scaffold-onboard's responsibility)
   - `feedback_v01_full_over_minimal.md` — prefer richer v0.1.0 over deferred-then-iterate (apply to v0.2)
   - `feedback_two_axis_skill_eval.md` — always evaluate skills on (A) dev cycle + (B) product integration
   - `feedback_subagent_vs_inline_threshold.md` — when to pivot from subagent to inline
   - `feedback_plugin_version_bump_required.md` — bump version on every published change
   - `feedback_slash_command_dollar_n_bug.md` — never use bash `$1`/`$2`/etc. inside slash command bodies; use `$ARGUMENTS` env-var bridge

---

## 5. Workflow conventions (mirror of scaffold-onboard's v0.1.0 build)

- **Subagent-driven dev** per `superpowers:subagent-driven-development`
- **TDD non-negotiable**: red → green → regression → commit
- **Commit format**: `scaffold-onboard: <description> (v0.2 Phase X)`. Single-line `git commit -m`. **No `Co-Authored-By:` trailer.** No HEREDOC for routine commits.
- **macOS portability adaptations**: BSD awk `sub()` chains, bash 3.2 parallel arrays, no `trap RETURN` (per existing scaffold-onboard portability notes)
- **Slash command bodies use `$ARGUMENTS` env-var bridge** (never bash `$1`/`$2`)
- **Phase-close commits update CHANGELOG + PLAN's Implementation Status section**
- **Never amend, never `--no-verify`, never force-push** without explicit consent

---

## 6. First-session game plan

### Step 1 — Orient (10-15 min)

Read this document end-to-end. Spot-read SPEC-workspace-init.md §6 + SPEC-scaffold-dev.md §16.2 + §14.1. Verify the marketplace baseline still green: `bash scaffold-onboard/tests/test-e2e.sh` (expect ~163 passing).

### Step 2 — Brainstorm (1-2 hours)

Invoke `superpowers:brainstorming`. Drive Q1-Q7 in §3 above. Visual artifacts where genuinely visual (per `feedback_brainstorm_artifacts_only_when_visual` — prose-first by default).

### Step 3 — Author SPEC (1-2 hours)

Create `docs/SPEC-scaffold-onboard-v02.md`. Mirror structure of `SPEC-scaffold-onboard.md` (v0.1.0) with v0.2-specific additions.

### Step 4 — Author PLAN (1-2 hours)

Create `docs/PLAN-scaffold-onboard-v02.md` with full task-by-task TDD breakdown.

### Step 5 — Begin implementation (multi-session)

`git checkout -b implementation-scaffold-onboard-v02`. Subagent-driven workflow.

---

## 7. Definition of done (scaffold-onboard v0.2.0)

- All build phases complete
- v0.1.0's 163 tests still pass (regression) PLUS new v0.2-specific tests (target: ~50-80 new tests, total ~210-240)
- `scaffold-onboard-v0.2.0` tag pushed
- Marketplace entry updated
- Root README plugin table reflects v0.2
- R1/R2/R3 contract demonstrably satisfied (sample project plan with hierarchy + machine-checkable rules + auto/user demo criteria)
- inbox/outbox critic code removed; skill-based critic invocation working
- scaffold-dev v0.1 build can proceed (this is the gate)

---

## 8. Opening message for the new session

To start the fresh session, paste this:

> Read `docs/HANDOFF-scaffold-onboard-v02-spec.md` end-to-end. The marketplace currently has 4 plugins; workspace-init + scaffold-dev are at SPEC stage (their builds gated on this work + architect-critic v0.2). scaffold-onboard v0.1.0 ships today; v0.2 is a substantial retrofit driven by skill-first principle + dual-repo workspace topology + scaffold-dev's R1/R2/R3 input contract. Use `superpowers:brainstorming` to drive Q1-Q7 in §3 to settled state, then author `docs/SPEC-scaffold-onboard-v02.md` and `docs/PLAN-scaffold-onboard-v02.md`, then begin implementation on a fresh `implementation-scaffold-onboard-v02` branch.
