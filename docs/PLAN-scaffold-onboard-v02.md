# scaffold-onboard v0.2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. TDD non-negotiable per `superpowers:test-driven-development`.

**Goal:** Implement the `scaffold-onboard` v0.2 retrofit per `docs/SPEC-scaffold-onboard-v02.md` — 7 skills + 4 slash command handles + manifest-aware routing + R1/R2/R3 contract + in-conversation critic invocation. Preserve all 163 v0.1.0 tests in single-repo mode.

**Architecture:** Skill-first composition (per Pass D principle). Skills in `skills/<skill-name>/SKILL.md`. Bash bookkeeping in `lib/*.sh`. Templates as data. 12 bash test suites (7 existing + 5 new). Target: ~257 tests / ~1,960 lines.

**Tech stack:** Bash 3.2 macOS-portable subset (per v0.1.0 portability notes — BSD awk, parallel arrays, no `trap RETURN`). `jq` for state files. `$ARGUMENTS` env-var bridge for slash commands (never `$1`/`$2`/`$N`).

---

## Implementation Status — IN PLANNING (2026-05-22)

Phase 0 not started. SPEC + PLAN authored 2026-05-22; pending architect-critic critique + user lock-in.

Once locked, implementation branch: `implementation-scaffold-onboard-v02`.

---

## File structure (locked from SPEC §4.2)

Additions over v0.1.0 (new files marked NEW):

```
scaffold-onboard/
├── skills/                                          (NEW directory)
│   ├── onboarding-project/SKILL.md                  (NEW — twin of /onboard)
│   ├── scaffolding-memory-bank/SKILL.md             (NEW — twin of /scaffold-project)
│   ├── scaffolding-governance-docs/SKILL.md         (NEW — twin of /scaffold-docs)
│   ├── planning-project-roadmap/SKILL.md            (NEW capability)
│   ├── authoring-machine-checkable-rules/SKILL.md   (NEW capability)
│   ├── authoring-vertical-slice-demo/SKILL.md       (NEW capability)
│   └── validating-master-spec/SKILL.md              (NEW)
├── commands/plan-roadmap.md                         (NEW)
├── lib/routing.sh                                   (NEW — sf_resolve_output_path)
├── lib/roadmap.sh                                   (NEW — R1 hierarchy)
├── lib/rules.sh                                     (NEW — R2 mcrule DSL)
├── lib/demo-criteria.sh                             (NEW — R3 auto:/user:)
├── templates/roadmap/ROADMAP.md.tmpl                (NEW)
├── templates/roadmap/vs-block.md.tmpl               (NEW — vertical slice fragment)
├── tests/test-roadmap.sh                            (NEW)
├── tests/test-rules.sh                              (NEW)
├── tests/test-demo-criteria.sh                      (NEW)
├── tests/test-manifest-routing.sh                   (NEW)
├── tests/test-hook-marker.sh                        (NEW)
└── evals/                                           (NEW directory)
    ├── onboarding-project.md
    ├── planning-project-roadmap.md
    ├── authoring-machine-checkable-rules.md
    ├── authoring-vertical-slice-demo.md
    ├── validating-master-spec.md
    ├── scaffolding-memory-bank.md
    └── scaffolding-governance-docs.md
```

Modifications to existing files: per SPEC §4.2 (lib/compose.sh REWRITE, lib/state.sh + lib/render.sh + lib/memory-bank.sh + lib/docs.sh extend; hooks-handlers/session-start.sh extend; templates/memory-bank/03-code-patterns.md.tmpl extend; commands/onboard.md + scaffold-project.md + scaffold-docs.md become thin wrappers).

---

## Test infrastructure (shared, unchanged from v0.1.0)

Every test suite sources `tests/_helpers.sh` (per v0.1.0). New suites inherit:
- `assert_eq <label> <expected> <actual>`
- `assert_file_exists <path>` / `assert_file_missing <path>`
- `assert_file_contains <path> <pattern>`
- `assert_exit_code <expected_code> <command...>`
- `setup_tmp_repo` / `cleanup`

Tests increment PASS/FAIL counters; exit non-zero if FAIL > 0.

**New test helpers for v0.2** (added to `tests/_helpers.sh`):
- `setup_tmp_workspace_init <project_type>` — creates AI workspace + canonical pair with pairing.json manifest
- `assert_routed_to <logical_name> <expected_root>` — verifies output landed in routed destination
- `assert_skill_invoked <plugin:skill> <marker_path>` — checks skill-invocation marker file (used to test in-conversation critic calls)

---

## Test impact matrix (per SPEC §15.1)

Reproduced here for build-time reference:

| Test file | Lines (v0.1.0) | Tests (v0.1.0) | v0.2 disposition | Δ lines | Δ tests |
|---|---|---|---|---|---|
| test-compose.sh | 394 | 31 | REWRITE | ~-200/+60 | -15/+8 |
| test-docs.sh | 131 | 23 | EXTEND | +30 | +6 |
| test-e2e.sh | 226 | 41 | EXTEND | +80 | +12 |
| test-memory-bank.sh | 122 | 22 | EXTEND | +25 | +5 |
| test-parser.sh | 209 | 13 | KEEP unchanged | 0 | 0 |
| test-render.sh | 105 | 10 | EXTEND | +20 | +4 |
| test-state.sh | 213 | 23 | EXTEND | +30 | +6 |
| test-roadmap.sh | 0 | 0 | NEW | +200 | +25 |
| test-rules.sh | 0 | 0 | NEW | +150 | +18 |
| test-demo-criteria.sh | 0 | 0 | NEW | +120 | +14 |
| test-manifest-routing.sh | 0 | 0 | NEW | +100 | +12 |
| test-hook-marker.sh | 0 | 0 | NEW | +80 | +9 |

**v0.2 target:** ~257 tests across 12 suites (~1,960 lines).

---

## Portability notes (carried forward from v0.1.0)

All three adaptations remain mandatory in v0.2:

1. **BSD awk `sub()` chains** instead of gawk 3-arg `match($0, /…/, arr)`. Applies to: new lib/rules.sh (regex extraction), new lib/demo-criteria.sh (line parsing), new lib/roadmap.sh (phase/sprint/slice extraction).
2. **bash 3.2 parallel indexed arrays** instead of `declare -A`. Applies to: lib/roadmap.sh (phase/sprint/slice indices), lib/rules.sh (rule type → field list mapping).
3. **No `trap RETURN`** — use explicit cleanup after each function.

Additional v0.2 portability concerns:
4. **jq array iteration patterns** — favor `jq -c '.[]'` over bash array assignment for complex JSON manipulation in lib/roadmap.sh's state CRUD.
5. **Cross-plugin path resolution** — when sourcing workspace-init's mi_manifest_resolve, fall back to local minimal resolver if workspace-init absent (don't hard-fail).

---

## Phase 0 — Evals (1-2 days)

**Goal:** Before writing any SKILL.md body, define what success looks like for each skill. Evals are integration tests that dispatch each skill to a subagent against fixture inputs and assert expected outputs.

**Eval harness convention** (per [feedback_claude_code_sessions_only]): all eval dispatches use the `Agent` tool from within a Claude Code subscription session. No external CLI wrappers (no `claude-judge`, no `anthropic` API, no third-party providers). LLM-judge style evaluation runs as: orchestrator skill reads eval doc → dispatches Agent subagent against fixture → second Agent subagent acts as judge against expected output → result aggregated by bash helper (jq) → PR-attached report. Manual-trigger until Claude Code ships unattended-eval mode.

### Task T0.1 — `evals/onboarding-project.md`

- [ ] Author eval doc with 5 scenarios:
  - Fresh /onboard on empty repo (happy path)
  - /onboard --resume after mid-phase interrupt
  - /onboard --regenerate on existing MASTER-SPEC
  - Trigger-phrase match without explicit /onboard (e.g., "start onboarding")
  - architect-critic invocation at Phase 5 (composition.json present)
- [ ] Each scenario specifies: input, expected behavior, assertion
- [ ] Commit: `scaffold-onboard: evals for onboarding-project skill (v0.2 Phase 0)`

### Task T0.2 — `evals/planning-project-roadmap.md`

- [ ] 5 scenarios:
  - Fresh /plan-roadmap with MASTER-SPEC present (happy path R1.A → R1.B → R1.C)
  - /plan-roadmap --resume mid-R1.B
  - 60-min checkpoint trigger
  - 3-timelines prompt framing (R1.A intro language)
  - architect-critic invocation at /plan-roadmap close

### Task T0.3 — `evals/authoring-machine-checkable-rules.md`

- [ ] 6 scenarios, one per DSL feature:
  - banned_imports rule authoring
  - coverage_floor rule authoring
  - style_invariants rule authoring
  - required_pattern rule authoring
  - Append-to-existing-rules-section (no overwrite)
  - Unknown rule type warning (extensibility test)

### Task T0.4 — `evals/authoring-vertical-slice-demo.md`

- [ ] 5 scenarios:
  - Initial 1-3 lines per slice during /plan-roadmap
  - Top-up by scaffold-dev (idempotent append)
  - Auto-line grammar (cmd → expected: exit 0)
  - Auto-line grammar (cmd → expected: pattern)
  - User-line grammar (action → expected: outcome)

### Task T0.5 — `evals/validating-master-spec.md`

- [ ] 3 scenarios: valid spec (success), invalid project_class enum (error + remediation), missing phase marker (error + line number).

### Task T0.6 — `evals/scaffolding-memory-bank.md`

- [ ] 4 scenarios: fresh derivation, R2 rules section seeded as empty, manifest-present routing to ai_workspace, manifest-absent to cwd.

### Task T0.7 — `evals/scaffolding-governance-docs.md`

- [ ] 4 scenarios: default 5 docs, --full 14 docs, PROJECT_PLAN.md unchanged from v0.1.0 (R1 hierarchy emitted as ROADMAP.md by skill 5.4 instead), manifest routing.

**Phase 0 closure:** All 7 eval docs committed. Update PLAN.Implementation Status section.

---

## Phase 1 — Skill bodies (2-3 days)

**Goal:** Write SKILL.md for all 7 skills. Each must pass its own eval. Test-first: fixture-based test BEFORE body authored.

### Task T1.1 — `skills/onboarding-project/SKILL.md`

- [ ] Red test: `tests/test-e2e.sh` extended with skill-invocation marker assertion (skill body must be readable + match trigger phrases)
- [ ] Green impl: SKILL.md frontmatter (description, trigger phrases) + body per SPEC §5.1 responsibilities
- [ ] Body length ≤500 lines per Pass D
- [ ] Regression: full 163-test suite still green
- [ ] Commit: `scaffold-onboard: skill body for onboarding-project (v0.2 Phase 1)`

### Task T1.2 — `skills/scaffolding-memory-bank/SKILL.md`

- [ ] Red test: marker assertion + R2 rules section seeded check
- [ ] Green impl: body per SPEC §5.2
- [ ] Regression + commit

### Task T1.3 — `skills/scaffolding-governance-docs/SKILL.md`

- [ ] Red test: marker + PROJECT_PLAN.md unchanged-from-v0.1.0 check (no rename per SPEC §5.3)
- [ ] Green impl: body per SPEC §5.3
- [ ] Regression + commit

### Task T1.4 — `skills/planning-project-roadmap/SKILL.md` (NEW)

- [ ] Red test: trigger-phrase coverage (multiple variants) + R1.A/B/C state checkpoint asserts
- [ ] Green impl: body per SPEC §5.4, ≤500 lines
- [ ] Includes 3-timelines framing prompt text verbatim
- [ ] Regression + commit

### Task T1.5 — `skills/authoring-machine-checkable-rules/SKILL.md` (NEW)

- [ ] Red test: DSL emission for all 4 rule types via fixtures
- [ ] Green impl: body per SPEC §5.5
- [ ] Regression + commit

### Task T1.6 — `skills/authoring-vertical-slice-demo/SKILL.md` (NEW)

- [ ] Red test: auto:/user: grammar emission + idempotence
- [ ] Green impl: body per SPEC §5.6
- [ ] Regression + commit

### Task T1.7 — `skills/validating-master-spec/SKILL.md`

- [ ] Red test: error surfacing for invalid spec
- [ ] Green impl: body per SPEC §5.7, wraps lib/parser.sh
- [ ] Regression + commit

**Phase 1 closure:** All 7 SKILL.md files committed. 163 tests still green.

---

## Phase 2 — Reference sub-docs (1-2 days)

**Goal:** Per-skill worked examples + edge cases. Lives in `skills/<skill-name>/references/` (or skill-internal section if shorter). Improves description match precision.

### Task T2.1 — Reference docs for `onboarding-project`

- [ ] `skills/onboarding-project/references/example-walkthrough.md` (10-phase example)
- [ ] `skills/onboarding-project/references/resume-handling.md`
- [ ] `skills/onboarding-project/references/critic-moments.md`

### Task T2.2 — Reference docs for `planning-project-roadmap`

- [ ] `skills/planning-project-roadmap/references/3-timelines-framing.md`
- [ ] `skills/planning-project-roadmap/references/example-hierarchy.md` (a sample 4-phase, 12-sprint, 30-slice project)
- [ ] `skills/planning-project-roadmap/references/checkpoint-protocol.md`

### Task T2.3 — Reference docs for `authoring-machine-checkable-rules`

- [ ] `skills/authoring-machine-checkable-rules/references/rule-types.md` (per type: example + edge cases)
- [ ] `skills/authoring-machine-checkable-rules/references/extensibility.md`

### Task T2.4 — Reference docs for `authoring-vertical-slice-demo`

- [ ] `skills/authoring-vertical-slice-demo/references/auto-grammar.md` (with examples)
- [ ] `skills/authoring-vertical-slice-demo/references/user-grammar.md`

### Tasks T2.5-T2.7 — Reference docs for other 3 skills

- [ ] One example walkthrough + one edge-case doc per skill (memory-bank, governance-docs, validating-master-spec)

**Phase 2 closure:** All reference docs committed. Phase 6 (subagent pressure tests) will validate they improve match precision.

---

## Phase 3 — Utility scripts (3-5 days)

**Goal:** Bash bookkeeping for skills. Test-first per task.

### Task T3.1 — `lib/routing.sh` + `tests/test-manifest-routing.sh`

- [ ] Red test (`test-manifest-routing.sh`):
  - `sf_discover_manifest` walks up from cwd; finds pairing.json
  - `sf_resolve_output_path master_spec MASTER-SPEC.md` returns `<ai_workspace.root>/MASTER-SPEC.md`
  - Single-repo fallback (no manifest): returns `$(pwd)/MASTER-SPEC.md`
  - Unknown logical name: warns + falls back to cwd
  - Cross-plugin mi_manifest_resolve sourcing works; falls back to local if absent
  - 12 assertions per test impact matrix
- [ ] Green impl: lib/routing.sh per SPEC §10.2
- [ ] Regression: 163 + 12 new = 175 tests
- [ ] Commit: `scaffold-onboard: lib/routing.sh + manifest routing tests (v0.2 Phase 3)`

### Task T3.2 — `lib/roadmap.sh` + `tests/test-roadmap.sh`

- [ ] Red test (`test-roadmap.sh`):
  - State file CRUD (open/init, write phase, write sprint, write slice, read checkpoint, write checkpoint)
  - ROADMAP.md rendering from state JSON
  - Phase/Sprint/Slice ID conventions (VS-N.M.K format)
  - Idempotent re-render (existing slices preserved)
  - Resume after R1.A checkpoint
  - **Re-run protocol (per SPEC §7.5):** all 5 modes — add-phase, add-sprint, add-slice, refine-slice, reorganize (stub for v0.3+)
  - **Size-class detection (per SPEC §7.3):** node count > 50 triggers prompt; > 100 triggers split-suggestion
  - **Mutations array:** each non-initial change appended to state.mutations
  - 25 assertions (5 base + 8 re-run + 6 size-class + 6 mutation-tracking)
- [ ] Green impl: lib/roadmap.sh with API: `sf_roadmap_init`, `sf_roadmap_write_phase`, `sf_roadmap_write_sprint`, `sf_roadmap_write_slice`, `sf_roadmap_render`, `sf_roadmap_get_checkpoint`, `sf_roadmap_count_nodes`, `sf_roadmap_add_mutation`, `sf_roadmap_detect_rerun_mode`
- [ ] Regression: 175 + 25 = 200 tests
- [ ] Commit

### Task T3.3 — `lib/rules.sh` + `tests/test-rules.sh`

- [ ] Red test (`test-rules.sh`):
  - Parse HTML-sentinel mcrule block of each type (4 types × ≥2 fixtures = 8) — sentinel grammar `<!-- mcrule:start type=<T> -->` ... `<!-- mcrule:end -->`
  - `sf_rules_validate_block` accepts valid; rejects malformed (missing type=, missing end sentinel)
  - `sf_rules_filter <json> banned_imports` returns only banned_imports rules
  - Unknown type → warn + skip (extensibility per SPEC §8.5)
  - 18 assertions
- [ ] Green impl: lib/rules.sh API: `sf_rules_parse`, `sf_rules_validate_block`, `sf_rules_filter`
- [ ] Parser uses sed/awk to extract content between sentinels; type attribute parsed from start sentinel
- [ ] BSD awk; bash 3.2 parallel arrays for type → field map
- [ ] Regression: 200 + 18 = 218 tests
- [ ] Commit

### Task T3.4 — `lib/compose.sh` refactor + `tests/test-compose.sh` REWRITE

- [ ] Red test (`test-compose.sh` rewritten):
  - composition.json probe still works (all v0.1.0 probe assertions preserved — 16 retained)
  - Source-aware refresh policy still works (startup/clear refresh; resume/compact preserve)
  - User-override toggles preserved (sticky)
  - File lock protection still works
  - **NEW: critic skill resolution + fallback (per SPEC §12.4)** — when composition.json shows architect-critic v0.2+, resolve `critiquing-spec`; when v0.1.x, resolve `critique`. 4 assertions for this.
  - **NEW: in-conversation critic invocation marker assertions** — skill body must include marker-write step at critic moments. 4 assertions.
  - DROPPED: `sf_compose_build_critic_request` + `sf_compose_read_critic_response` tests (functions removed) — 15 tests dropped from v0.1.0 baseline of 31
  - v0.2 count: 16 retained + 8 new = 24 tests in test-compose.sh
- [ ] Green impl: lib/compose.sh — remove lines 257-339 (`sf_compose_build_critic_request`) + lines 344-363 (`sf_compose_read_critic_response`); keep probe + caching + lock helpers; add `sf_compose_resolve_critic_skill` helper (returns `critiquing-spec` or `critique` based on detected version)
- [ ] Regression: 218 - 15 + 8 = 211 tests in this suite + others = check total
- [ ] Commit

### Task T3.5 — `lib/demo-criteria.sh` + `tests/test-demo-criteria.sh`

- [ ] Red test:
  - `sf_demo_parse_line "- [ ] auto: \`pytest\` → expected: exit 0"` returns JSON
  - User-grammar parsing
  - Pattern expected vs exit-code expected
  - `sf_demo_append` idempotent (no duplicate criteria)
  - `sf_demo_parse_slice <project_plan.md> VS-1.1.1` returns array of criteria
  - 14 assertions
- [ ] Green impl: lib/demo-criteria.sh per SPEC §9.3
- [ ] Regression
- [ ] Commit

**Phase 3 closure:** All 5 lib modules + 5 test suites committed. Total tests: ~225+ (depending on which compose tests survive).

---

## Phase 4 — Hook updates (1 day)

### Task T4.1 — `tests/test-hook-marker.sh` (NEW)

- [ ] Red test:
  - Marker absent → emit full Tier 0 + write marker with content "scaffold-onboard"
  - Marker present with content "scaffold-dev" → skip Tier 0; emit minimal hint
  - Marker present with content "scaffold-onboard" → emit full Tier 0 (this plugin owns it)
  - CLAUDE_SESSION_ID unset → use "default" suffix
  - Marker path resolves to `${TMPDIR:-/tmp}/claude-code-tier0-${session_id}`
  - 9 assertions

### Task T4.2 — `hooks-handlers/session-start.sh` extension

- [ ] Green impl: marker-aware Tier 0 logic per SPEC §11.2
- [ ] **Race-window discipline (per SPEC §11.4):** marker check + write block sits at lines 1-15 (post-shebang); all other logic follows
- [ ] Preserve existing source-aware composition refresh logic (per v0.1.0)
- [ ] Cross-platform `TMPDIR` handling (macOS has `/var/folders/...`; Linux usually `/tmp`)
- [ ] **Timing test:** test-hook-marker.sh adds assertion that marker decision completes within 50ms of hook entry (date +%s%N start/end)
- [ ] Regression: 9 new + all previous
- [ ] Commit: `scaffold-onboard: marker-aware Tier 0 hook (v0.2 Phase 4)`

**Phase 4 closure:** Hook tests + impl committed.

---

## Phase 5 — Slash command wrappers (1 day)

### Task T5.1 — `commands/onboard.md` (modified)

- [ ] Update body to invoke `scaffold-onboard:onboarding-project` skill via `$ARGUMENTS` env-var bridge
- [ ] Preserve argument-hint frontmatter (--resume, --regenerate)
- [ ] No bash `$1`/`$2`/`$N` per `feedback_slash_command_dollar_n_bug`
- [ ] Regression: e2e tests still work
- [ ] Commit

### Task T5.2 — `commands/scaffold-project.md` (modified)

- [ ] Invoke `scaffold-onboard:scaffolding-memory-bank`
- [ ] Preserve --regenerate flag handling
- [ ] Commit

### Task T5.3 — `commands/scaffold-docs.md` (modified)

- [ ] Invoke `scaffold-onboard:scaffolding-governance-docs`
- [ ] Preserve --full + --regenerate flags
- [ ] PROJECT_PLAN.md output unchanged from v0.1.0 (no rename — per SPEC §5.3 + §13.5; R1 hierarchy uses ROADMAP.md instead)
- [ ] Commit

### Task T5.4 — `commands/plan-roadmap.md` (NEW)

- [ ] Frontmatter: description + argument-hint (--resume, --phase-only, --sprint-only)
- [ ] Body invokes `scaffold-onboard:planning-project-roadmap` via $ARGUMENTS
- [ ] Commit

**Phase 5 closure:** All 4 commands wired to skills.

---

## Phase 6 — Subagent pressure tests (2-3 days)

**Goal:** Stress each skill via subagent with adversarial prompts. Validate description matching + body correctness. Iterate descriptions per `feedback_two_axis_skill_eval`.

### Task T6.1 — Pressure test `onboarding-project`

- [ ] Subagent: try to invoke /onboard mid-project (existing MASTER-SPEC) — does skill refuse correctly?
- [ ] Subagent: vague prompts ("set up my project") — does description match correctly?
- [ ] Adversarial: phrase that should NOT trigger (e.g., "scaffold the auth code") — verify no-match
- [ ] Iterate description text until pass rate ≥90%
- [ ] Commit description revisions

### Task T6.2-T6.7 — Pressure test other 6 skills

- [ ] Same pattern per skill
- [ ] Document description revisions in `evals/<skill>-iterations.md` for trace

**Phase 6 closure:** Subagent dispatch logs reviewed; description-match precision ≥90% per skill.

---

## Phase 7 — Integration tests (2-3 days)

### Task T7.1 — `tests/test-e2e.sh` extension: full flow manifest-present

- [ ] Red test scenarios:
  - Setup: workspace-init pair (AI workspace + canonical) with pairing.json
  - Run /onboard → MASTER-SPEC lands in ai_workspace.root
  - Run /scaffold-project → memory-bank lands in ai_workspace.root
  - Run /scaffold-docs → governance docs route per manifest (PRD/SRS to canonical, process_adrs to ai_workspace)
  - Run /plan-roadmap → ROADMAP.md lands in canonical
  - 12 new assertions

### Task T7.2 — `tests/test-e2e.sh` extension: R1/R2/R3 contract demo

- [ ] Red test scenarios:
  - ROADMAP.md from /plan-roadmap contains all 3 hierarchy levels
  - 03-code-patterns.md has machine-checkable rules section with valid fenced blocks (R2)
  - Each vertical slice in ROADMAP.md has ≥1 demo criterion (R3)
  - lib/rules.sh successfully parses the emitted rules
  - lib/demo-criteria.sh successfully parses the emitted criteria
  - Sample assertions matching scaffold-dev contract

### Task T7.3 — Single-repo fallback regression

- [ ] Verify v0.1.0 single-repo tests still pass byte-identical to v0.1.0 baseline
- [ ] Run full v0.1.0 test fixtures through v0.2 binary; diff output to v0.1.0 reference

### Task T7.4 — `test-memory-bank.sh`, `test-docs.sh`, `test-render.sh`, `test-state.sh` extensions

- [ ] Per test impact matrix: add manifest-routing assertions + R2 rules section + roadmap state CRUD
- [ ] Commits per file

**Phase 7 closure:** ~255+ tests passing across 12 suites.

---

## Phase 8 — Drop inbox/outbox critic code (1 day)

### Task T8.1 — lib/compose.sh final surgery

- [ ] Verify lib/compose.sh contains no remaining `_critic_request` / `_critic_response` references
- [ ] Verify no `inbox/` or `outbox/` directory writes in any code path
- [ ] Run `grep -r "critic_request\|critic_response\|inbox\|outbox" scaffold-onboard/` — should return only documentation/changelog mentions
- [ ] Document removal in CHANGELOG

### Task T8.2 — Final regression sweep

- [ ] All 12 test suites green
- [ ] No `Skill(architect-critic:` invocations attempt file-IPC fallback
- [ ] Commit: `scaffold-onboard: drop inbox/outbox critic IPC code (v0.2 Phase 8)`

**Phase 8 closure:** v0.2 fully skill-based for critic invocation; legacy IPC removed.

---

## Phase 9 — Publish (1 day)

### Task T9.1 — plugin.json version bump

- [ ] Bump from 0.1.0 → 0.2.0 (per `feedback_plugin_version_bump_required`)
- [ ] Add `composition` field per SPEC §4.1
- [ ] Add `principles_export` field if applicable

### Task T9.2 — CHANGELOG completion

- [ ] Move `## [Unreleased]` to `## [0.2.0] — 2026-MM-DD`
- [ ] List all v0.2 additions: 7 skills, 4 slash commands, manifest routing, R1/R2/R3, hook coordination, Karpathy section, IPC removal
- [ ] Document non-breaking nature: PROJECT_PLAN.md unchanged from v0.1.0; new ROADMAP.md is a new file (no collision)
- [ ] Document 15-test IPC removal (test-compose.sh: 31 → 24 tests; v0.1.0 baseline 163 → 148 preserved + 109 new = 257 v0.2 target)

### Task T9.3 — Root README plugin table update

- [ ] Update `/Volumes/master_ssd/projects/claude-agent-scaffolding/README.md` plugin table row for scaffold-onboard: version 0.2.0, surfaces "7 skills + 4 slash commands", composition list

### Task T9.4 — Marketplace entry update

- [ ] Update marketplace.json (or wherever marketplace metadata lives) for scaffold-onboard@0.2.0

### Task T9.5 — `docs/MIGRATION-scaffold-onboard-v01-to-v02.md`

- [ ] Author migration doc per SPEC §13.4
- [ ] Sections: what's new (7 skills + /plan-roadmap + ROADMAP.md + R2 rules), what changed for existing users (effectively nothing unless they opt into new commands), opt-in paths (R1/R2/R3), test baseline honesty (15 IPC tests dropped)

### Task T9.6 — R1/R2/R3 demonstration

- [ ] Author a sample project end-to-end via v0.2's /onboard + /scaffold-project + /scaffold-docs + /plan-roadmap
- [ ] Commit sample outputs to `scaffold-onboard/examples/sample-project/`
- [ ] Verify scaffold-dev v0.1 SPEC review: `implementation-checking` + `closing-vertical-slice` skills can consume these outputs

### Task T9.7 — Tag + push

- [ ] `git tag scaffold-onboard-v0.2.0`
- [ ] Push tag + main
- [ ] Verify `/plugin update scaffold-onboard@claude-agent-scaffolding` surfaces v0.2.0 to users

**Phase 9 closure:** v0.2.0 SHIPPED. scaffold-dev v0.1 build can proceed.

---

## Workflow conventions (apply to every phase)

- **TDD non-negotiable** per `superpowers:test-driven-development` — red → green → regression → commit
- **Subagent-driven dispatch** per `superpowers:subagent-driven-development` (each task = one implementer subagent + one reviewer subagent)
- **Inline pivot threshold** per `feedback_subagent_vs_inline_threshold` — when subagents reliably fail (socket close / stream timeout / runaway runtime), switch to inline for that phase
- **Commit format:** `scaffold-onboard: <description> (v0.2 Phase X)` — single-line, no HEREDOC, no Co-Authored-By trailer
- **Phase-close commits update** CHANGELOG (under `## [Unreleased]`) + this PLAN's Implementation Status section
- **macOS portability:** BSD awk, bash 3.2, no `trap RETURN`
- **Slash command bodies:** $ARGUMENTS env-var bridge only; never bash $N
- **Never amend, never --no-verify, never force-push** without explicit user consent

---

## Verification gates (cumulative)

| Phase | Cumulative tests | Verification |
|---|---|---|
| 0 | 163 (baseline) | All evals committed |
| 1 | 163 | All SKILL.md files committed; description-match smoke checks |
| 2 | 163 | Reference docs committed |
| 3 | ~225 (depends on compose.sh test count) | 5 new lib modules + 5 new test suites |
| 4 | ~234 | Hook marker protocol |
| 5 | ~234 | 4 slash commands wired |
| 6 | ~234 | Subagent description-match precision ≥90% per skill |
| 7 | ~257 | E2E manifest-present + single-repo regression |
| 8 | ~257 | IPC code fully removed |
| 9 | ~257 | v0.2.0 tagged + published |

Final regression target: **257 tests across 12 suites in ≤25s wall-clock** (v0.1.0 was 163 in ~16s; new suites should add ~5-10s).

---

## Risks (carried from SPEC §17)

See SPEC §17 for full table. PLAN-specific build risks:

| Risk | Mitigation |
|---|---|
| compose.sh refactor breaks probe behavior | Test-first; preserve all v0.1.0 probe assertions verbatim before adding new ones |
| Subagent pressure tests reveal description-match failures requiring redesign | Reserve 1-2 day buffer in Phase 6 for description iteration |
| Tier 0 marker race condition surfaces in CI | Acceptable; race window is microsecond-scale |
| Cross-plugin sourcing of mi_manifest_resolve fails on partial install | Local fallback resolver in lib/routing.sh |
| Cross-plugin coordination — scaffold-dev SPEC §16.2 must update to consume `ROADMAP.md` (not PROJECT_PLAN.md) | Filed as cross-plugin handoff; scaffold-dev SPEC author updates §16.2 in lockstep with v0.2 ship |
| workspace-init manifest needs `routing.roadmap` key added | workspace-init v0.1.1 point release; scaffold-onboard v0.2 ships with graceful fallback for absent key |

---

## References

1. [SPEC-scaffold-onboard-v02.md](SPEC-scaffold-onboard-v02.md) — authoritative spec
2. [HANDOFF-scaffold-onboard-v02-spec.md](HANDOFF-scaffold-onboard-v02-spec.md) — original seed
3. [PLAN-scaffold-onboard.md](PLAN-scaffold-onboard.md) — v0.1.0 PLAN (structural reference)
4. [SPEC-scaffold-dev.md](SPEC-scaffold-dev.md) §16.2 — R1/R2/R3 contract
5. [SPEC-workspace-init.md](SPEC-workspace-init.md) §6, §11 — manifest schema + integration

---

## Iteration log

- **2026-05-22 14:00 — DRAFT v1** authored from SPEC + critique.
- **2026-05-22 16:00 — DRAFT v2** updated to match SPEC v2 (post architect-critic pass crit-20260522T155948Z):
  - ROADMAP.md naming (replaces PROJECT_PLAN.md repurpose; no v0.1.0 collision)
  - HTML-sentinel mcrule DSL in T3.3 (replaces fenced blocks)
  - Critic skill resolution + fallback in T3.4 (per SPEC §12.4)
  - Race-window discipline + 50ms timing test in T4.2 (per SPEC §11.4)
  - Re-run protocol modes + size-class detection in T3.2 (per SPEC §7.3 + §7.5)
  - Test baseline honesty in T9.2 (148/163 preserved + 109 new)
  - Cross-plugin coordination risks added
- Pending: user lock-in before Phase 0 begins.
