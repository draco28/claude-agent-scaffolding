# scaffold-dev v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build scaffold-dev v0.1 — orchestrator-implementer workflow plugin for sprint-driven development on dual-repo workspaces. Skill-first composition with 8 orchestrator skills, 1 implementer-agent subagent definition, and the handoff escape valve.

**Architecture:** Orchestrator session (full VS lifecycle, high-effort model) dispatches per-work-item `implementer-agent` subagents (isolated context, multi-call protocol) via Claude Code's Task tool. Handoff escape valve for out-of-slice transitions. Manifest-aware (reads workspace-init `pairing.json`; never writes). Composes with architect-critic v0.2 (filesystem probe + `critiquing-spec` skill invocation), ai-mentor v2.0 (`grill-me` at 3 gates), and scaffold-onboard v0.2 (R1/R2/R3 contract).

**Tech Stack:** bash 3.2+ (macOS compat) for lib bookkeeping; markdown for skill bodies + spec/handoff/report templates; jq for JSON manipulation; git worktree CLI for canonical isolation; Claude Code Task tool + custom `subagent_type` registration for `scaffold-dev:implementer-agent`.

---

## Implementation status — IN PLANNING (2026-05-25)

Dependencies all shipped:
- workspace-init v0.1.0 (manifest contract + `routing.roadmap` + `.workspace/handoffs/` gitignore)
- scaffold-onboard v0.2.0 (R1/R2/R3 contract: `ROADMAP.md` + HTML-sentinel `mcrule` blocks + `auto:`/`user:` demo grammar)
- architect-critic v0.2.0 (`critiquing-spec` skill via filesystem probe per ac v0.2 settlement #1)
- ai-mentor v2.0.0 (`grill-me` skill)
- claude-security-audit v0.1.1 (standalone — not a dep, but in marketplace lineup)

scaffold-dev v0.1 is the FINAL plugin in the marketplace chain. ~140-160 tests target across ~13 suites; ~8-12 days focused work.

---

## File structure (locked from SPEC §4 + §7 + §10b + §6b)

```
scaffold-dev/
├── .claude-plugin/
│   ├── plugin.json                            # version: 0.1.0; composition.consumes + invokes + produces
│   ├── marketplace.json                        # plugin metadata
│   └── agents.json                             # custom subagent_type registration (NEW per Phase 3.5)
├── skills/                                     # 9 SKILL.md bodies (8 orchestrator + 1 executing-work-item dual-use)
│   ├── planning-vertical-slice/SKILL.md
│   ├── implementation-checking/SKILL.md
│   ├── closing-vertical-slice/SKILL.md
│   ├── recording-architecture-decision/SKILL.md
│   ├── appending-changelog-entry/SKILL.md
│   ├── authoring-runbook/SKILL.md
│   ├── writing-sprint-retrospective/SKILL.md
│   ├── handing-off-session/SKILL.md            # NEW per SPEC §6b
│   └── executing-work-item/SKILL.md            # dual-use: skill + subagent system prompt
├── commands/                                   # slash command wrappers ($ARGUMENTS bridge)
│   ├── orchestrate.md                          # wraps planning-vertical-slice
│   ├── work-item.md                            # wraps executing-work-item (manual fallback)
│   ├── impl-check.md                           # wraps implementation-checking
│   └── handoff.md                              # wraps handing-off-session (NEW)
├── hooks/
│   └── hooks.json                              # SessionStart only per SPEC §18
├── hooks-handlers/
│   └── session-start.sh                        # walk-up manifest discovery + Tier 0 marker coordination
├── lib/                                        # bash bookkeeping; logic lives in skill bodies
│   ├── _helpers.sh                             # logging, path canonicalization, jq wrappers
│   ├── manifest.sh                             # walk-up discovery; sources workspace-init's mi_manifest_resolve
│   ├── state.sh                                # cursor read/write to memory bank 05-active-context.md
│   ├── worktree.sh                             # git worktree add/remove with abs paths
│   ├── merge.sh                                # work-item branch → canonical main merge orchestration
│   ├── harvest.sh                              # slice-close memory-bank harvest (reports + handoffs)
│   ├── verify.sh                               # AC verification + report cross-check
│   ├── rules.sh                                # consumes scaffold-onboard's sf_rules_parse output
│   ├── render.sh                               # template filler ({{var}} substitution; ported from scaffold-onboard)
│   ├── handoff.sh                              # handoff file create/read/discover; lazily mkdir .workspace/handoffs/
│   └── compose.sh                              # filesystem probe for architect-critic + ai-mentor
├── templates/
│   ├── work-item-spec.md.tmpl                  # Wabash Format B 8-section
│   ├── vertical-slice-readme.md.tmpl
│   ├── implementation-handoff.md.tmpl          # heavy ~200-400 line shape per SPEC §10
│   ├── implementation-report.md.tmpl           # 9-section
│   ├── slice-retrospective.md.tmpl             # 7-section per SPEC §16b
│   ├── sprint-retrospective.md.tmpl            # 6-section per SPEC §16b
│   └── handoff.md.tmpl                         # NEW per SPEC §6b.5 — 10-section forward + return template
├── evals/                                      # subagent behavior evals per skill
│   ├── planning-vertical-slice.md
│   ├── implementation-checking.md
│   ├── closing-vertical-slice.md
│   ├── recording-architecture-decision.md
│   ├── appending-changelog-entry.md
│   ├── authoring-runbook.md
│   ├── writing-sprint-retrospective.md
│   ├── handing-off-session.md
│   └── executing-work-item.md
├── tests/
│   ├── _helpers.sh                             # ported from scaffold-onboard pattern
│   ├── test-helpers.sh                         # tests for lib/_helpers.sh
│   ├── test-manifest.sh                        # walk-up discovery + manifest field reads
│   ├── test-state.sh                           # cursor CRUD on 05-active-context.md
│   ├── test-worktree.sh                        # git worktree add/remove
│   ├── test-merge.sh                           # work-item merge orchestration + conflict halt
│   ├── test-harvest.sh                         # memory-bank harvest (reports + handoffs source-tagged)
│   ├── test-verify.sh                          # AC verification + report cross-check
│   ├── test-rules.sh                           # consumes mcrule output; v0.1 falls back to AC-only when rules absent
│   ├── test-render.sh                          # template {{var}} substitution
│   ├── test-handoff.sh                         # handoff file create/read; .workspace/handoffs/ auto-create; lifecycle
│   ├── test-compose.sh                         # filesystem probe (architect-critic + ai-mentor); graceful absence
│   ├── test-subagent.sh                        # subagent_type registration + return-mode parsing (Phase 3.5)
│   ├── test-hook.sh                            # SessionStart marker coordination with scaffold-onboard
│   ├── test-skills-pressure.sh                 # subagent-dispatched skill invocation pressure tests
│   └── test-e2e.sh                             # end-to-end fixture sprint
├── fixtures/                                   # test fixtures (sprint shapes for e2e)
│   ├── sprint-fixture-minimal/
│   ├── sprint-fixture-with-bugfix-detour/
│   └── handoff-fixture-chain/                  # forward + return handoff thread
├── CHANGELOG.md
├── LICENSE                                     # MIT (project convention)
└── README.md
```

**Test count target:** ~140-160 tests across ~13 suites.

---

## Test infrastructure (ported from scaffold-onboard's pattern)

`tests/_helpers.sh` provides:
- `setup_test_workspace()` — creates a temp dual-repo skeleton (mimics workspace-init output)
- `teardown_test_workspace()` — removes temp dirs
- `mock_architect_critic_v0_2()` — drops a fake `~/.claude/plugins/cache/.../architect-critic/0.2.0/skills/critiquing-spec/SKILL.md` for filesystem-probe tests
- `mock_ai_mentor_v2_0()` — same for ai-mentor
- `mock_scaffold_onboard_v0_2_output()` — pre-populates fixture `ROADMAP.md`, `03-code-patterns.md` (with mcrule blocks), `MASTER-SPEC.md`
- `assert_eq`, `assert_contains`, `assert_file_exists`, `assert_json_field` — standard

Each test file is independently runnable: `bash scaffold-dev/tests/test-<name>.sh`. Aggregate via `scaffold-dev/run-tests.sh`.

---

## Test impact matrix (per SPEC §20)

| Suite | Tests target | Coverage |
|---|---|---|
| `test-helpers.sh` | ~8 | logging, path canonicalization, jq wrappers |
| `test-manifest.sh` | ~12 | walk-up discovery, field reads, fallback when absent (refuses to start) |
| `test-state.sh` | ~10 | cursor CRUD on `05-active-context.md`; idempotent writes |
| `test-worktree.sh` | ~12 | `git worktree add` at `${canonical.root}/.worktrees/work-N.NN-<kebab>`; branch naming; cleanup at slice close |
| `test-merge.sh` | ~14 | work-item → main merge; halt on conflict; verify branch deletion ONLY at slice close |
| `test-harvest.sh` | ~12 | report sweep + handoff sweep; source-tagging `[report]`/`[handoff]`; provenance trailer |
| `test-verify.sh` | ~14 | AC verification (auto-step → exit-code or pattern); report cross-check; project rule check fallback |
| `test-rules.sh` | ~8 | consume scaffold-onboard's `sf_rules_*` JSON; v0.1 fallback to AC-only when rules absent or scaffold-onboard absent |
| `test-render.sh` | ~10 | `{{var}}` substitution; all 7 templates render with sample data |
| `test-handoff.sh` | ~16 | file create/read; `.workspace/handoffs/` auto-create via mkdir -p; naming convention validation; carry-forward exception; gitignored check |
| `test-compose.sh` | ~10 | filesystem probe for ac v0.2 + ai-mentor v2.0; graceful absence; warn-and-skip; cache dir traversal |
| `test-subagent.sh` | ~14 | `agents.json` registration; Task tool invocation; gaps-mode + complete-mode return parsing; multi-call clarification loop |
| `test-hook.sh` | ~6 | SessionStart marker coordination; manifest detection; Tier 0 emission control |
| `test-skills-pressure.sh` | ~10 | subagent-dispatched scenarios per skill (3+ per skill) |
| `test-e2e.sh` | ~12 | full fixture sprint flow; round execution; slice-close ceremony; handoff round-trip |
| **Total** | **~168** | (exceeds SPEC §20 target ~140-160) |

---

## Portability notes

- bash 3.2 compatibility (macOS native bash; no `declare -A`, no `mapfile`)
- No GNU `timeout` command (use portable bash background + kill pattern per architect-critic v0.2's `_ac_codex_run_with_timeout` at `lib/codex.sh:96-141`)
- `jq` availability checked at lib bootstrap; lib `_helpers.sh::sd_require_jq` fails early with clear message
- All git ops use `git -C <abs-path> <subcommand>` (NOT `cd` + git) for cross-repo correctness
- All lib files source `_helpers.sh` via `_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` pattern (matches architect-critic v0.2; verified non-fragile in issue #3 resolution)
- `{{var}}` template grammar matches scaffold-onboard's `render.sh` (port forward with shared logic)

---

## Phase 0 — Evals first (RED) (~1-2 days)

Author behavior evals for each skill per `superpowers:writing-skills` discipline. Each eval is a markdown doc with: trigger phrases, 3+ scenarios, expected behavior under each, green-light criteria. Evals fail until Phase 1 SKILL.md bodies land.

### Task T0.1 — `evals/planning-vertical-slice.md`

**Files:**
- Create: `scaffold-dev/evals/planning-vertical-slice.md`

**Trigger phrases:** "plan VS-3.2", "orchestrate VS-3.2", "start a new vertical slice", "let's plan the next slice"

**Scenarios:**
1. **Happy path decomposition** — user provides VS-id; skill reads `ROADMAP.md` for slice description, proposes 4-5 work-item decomposition, surfaces grill-me offer, identifies parallel-vs-sequential rounds via strict-layer DAG, authors all specs upfront in `docs/specs/sprint-N/VS-N.M-<kebab>/`, invokes architect-critic `critiquing-spec` skill on specs.
2. **Manifest absent** — fails fast: "scaffold-dev requires a workspace-init pairing manifest; run `/init-workspace` or `/pair-workspace` first."
3. **ROADMAP missing target VS** — surfaces error with hint: "VS-3.2 not found in `<ai-workspace>/ROADMAP.md`; run `/plan-roadmap --add-slice 3.2` first."
4. **Architect-critic absent** — emits warning per SPEC §16.3 ("adversarial review skipped"), proceeds without blocking.

**Green-light criteria:**
- Skill body invoked on each trigger phrase (no false negatives)
- All 4 scenarios produce the SPEC-defined behavior under subagent eval
- Manifest field reads use the `lib/manifest.sh` helpers (not raw jq inline)

- [ ] **Step 1:** Author eval doc with trigger phrases + 4 scenarios + green-light criteria
- [ ] **Step 2:** Commit
  ```bash
  git add scaffold-dev/evals/planning-vertical-slice.md
  git commit -m "scaffold-dev: planning-vertical-slice eval (v0.1 Phase 0 T0.1)"
  ```

### Task T0.2 — `evals/implementation-checking.md`

**Files:**
- Create: `scaffold-dev/evals/implementation-checking.md`

**Trigger phrases:** "verify work item 2.04", "check round 1", "is this work item done", "verify the implementation"

**Scenarios:**
1. **Happy path AC pass** — skill reads work-item spec, runs each `auto:` verification command (per SPEC §14.1 grammar), checks exit codes / output patterns, reports green.
2. **AC fail** — surfaces failing AC + verification output; presents §12.2 failure-response menu (re-spawn implementer subagent with fix-up handoff / accept partial-deferred / replan).
3. **Project rule check fail** — consumes scaffold-onboard's `sf_rules_filter` output; surfaces rule violation + presents §12.2 menu.
4. **Rules absent (R2 not authored)** — falls back to AC-only verification (per SPEC §12.1 + Q2 settlement).

**Green-light criteria:**
- Verification halts on first AC failure (does NOT continue silently)
- Failure-response menu always surfaces 3+ options
- Source-tags errors as `[AC]`, `[report cross-check]`, `[rule]`

- [ ] **Step 1:** Author eval doc
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: implementation-checking eval (v0.1 Phase 0 T0.2)"
  ```

### Task T0.3 — `evals/closing-vertical-slice.md`

**Files:**
- Create: `scaffold-dev/evals/closing-vertical-slice.md`

**Trigger phrases:** "close VS-3.2", "slice close", "wrap up the slice", "run slice-close ceremony"

**Scenarios:**
1. **Three-layer ceremony happy path** — skill executes auto-demo (per `auto:` lines in slice README), surfaces manual-demo steps to user, invokes architect-critic `critiquing-spec` skill at close depth, runs retrospective + memory-bank harvest (per §15.2 8-step flow including handoff sweep).
2. **Auto-demo step fails** — halts; surfaces failing step + command output; offers re-author demo step / accept-with-deferred / re-spawn implementer for fix-up.
3. **Architect-critic absent** — emits warning; proceeds with auto + manual demo only.
4. **Memory-bank harvest with handoffs** — sweeps `vs-3.2-*.md` from `.workspace/handoffs/`; source-tags promote candidates as `[handoff]` vs `[report]`.

**Green-light criteria:**
- Ceremony runs in correct order (auto → manual → critic → retrospective → harvest)
- Worktrees + branches NOT removed until ceremony completes successfully (per SPEC §11 M2)
- Harvest surfaces source-tagged items for user accept/edit/reject

- [ ] **Step 1:** Author eval doc
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: closing-vertical-slice eval (v0.1 Phase 0 T0.3)"
  ```

### Task T0.4 — `evals/executing-work-item.md`

**Files:**
- Create: `scaffold-dev/evals/executing-work-item.md`

**Trigger phrases:** "execute work item 2.04", "handoff at /path/to/handoff.md", "implement the work item"

This skill is the dual-use one: skill body + subagent system prompt. Eval covers both invocation modes.

**Scenarios:**
1. **Pre-flight clean → execute** — reads handoff + spec; verifies worktree branch + clean state; runs TDD loop per AC; runs verification commands; authors report.md; stages changes (no commit); returns `{mode: "complete", report_path, summary, stage_status}`.
2. **Pre-flight detects gaps** — returns `{mode: "gaps-surfaced", gaps: [...]}` without doing work.
3. **Worktree dirty** — refuses to execute; surfaces to caller via gaps-mode.
4. **Verification fails mid-execution** — completes report with failure notation; returns complete-mode with failure annotation; orchestrator's failure-response menu kicks in.

**Green-light criteria:**
- Subagent NEVER commits (no `git commit` in any flow)
- Return modes are strict JSON shape (orchestrator parses)
- Multi-call clarification loop terminates within 3 iterations (SPEC §6.6 failure mode)

- [ ] **Step 1:** Author eval doc
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: executing-work-item eval (v0.1 Phase 0 T0.4)"
  ```

### Task T0.5 — `evals/handing-off-session.md`

**Files:**
- Create: `scaffold-dev/evals/handing-off-session.md`

**Trigger phrases:** "hand this off", "handoff to next session", "fresh session for VS-3.2", "context bloated"

**Scenarios:**
1. **Forward handoff — sprint boundary** — composes `sprint-3-to-4-handoff-<short-id>.md`; survives sprint-N cleanup (carry-forward).
2. **Forward handoff — mid-slice bug-fix** — composes `vs-3.2-bugfix-auth-<short-id>.md`; populates 10 sections per SPEC §6b.5; includes return-handoff template stub.
3. **Return handoff** — composes `<original-name>-return.md`; populates results, deferrals, cautions.
4. **Mid-slice context bloat** — composes `sprint-3-context-bloat-<short-id>.md`; surfaces "next intended action" + "must read before doing anything" sections referencing current cursor.
5. **Auto-create `.workspace/handoffs/`** — first invocation triggers `mkdir -p`; subsequent invocations skip.

**Green-light criteria:**
- 10 sections always present (parser-friendly)
- File name matches `<scope>-<purpose>-<short-id>.md` pattern (4-char hex id)
- Section 4 ("What's NOT in memory bank yet") is NEVER empty (skill prompts user if blank)
- Gitignored check: `.gitignore` in AI workspace already excludes `.workspace/handoffs/` (verified at skill exit)

- [ ] **Step 1:** Author eval doc
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: handing-off-session eval (v0.1 Phase 0 T0.5)"
  ```

### Task T0.6 — Evals for remaining 4 skills (T0.6.1-T0.6.4)

**Files:**
- Create: `scaffold-dev/evals/recording-architecture-decision.md`
- Create: `scaffold-dev/evals/appending-changelog-entry.md`
- Create: `scaffold-dev/evals/authoring-runbook.md`
- Create: `scaffold-dev/evals/writing-sprint-retrospective.md`

Each eval: trigger phrases + 2-3 scenarios + green-light criteria. Lighter weight — these are simpler skills.

- [ ] **Step 1:** Author 4 eval docs (one per skill)
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: 4 remaining orchestrator-skill evals (v0.1 Phase 0 T0.6)"
  ```

---

## Phase 1 — Author SKILL.md bodies (~3-4 days)

Each skill body ≤500 lines per Pass D guidance. Tests-first: each skill addresses the Phase 0 eval scenarios.

### Task T1.1 — `skills/planning-vertical-slice/SKILL.md`

**Files:**
- Create: `scaffold-dev/skills/planning-vertical-slice/SKILL.md`

**Description (frontmatter):**
> Drive the full vertical-slice lifecycle: read MASTER-SPEC + memory bank + ROADMAP for VS context; decompose into 4-5 feature-sized work items (~200-500 LOC each); identify rounds via strict-layer DAG; author all work-item specs upfront in `docs/specs/sprint-N/VS-N.M-<kebab>/`; offer grill-me at decomposition + spec-authoring + fix-up gates; invoke architect-critic `critiquing-spec` skill on combined specs; per round, spawn worktrees + author handoffs + dispatch implementer-agent subagents via Task tool + process returns (`gaps-surfaced` → user clarification + re-invoke; `complete` → verify + commit + merge); halt and surface menu on failure per §12.2.

**Body sections:**
1. Read manifest via `lib/manifest.sh::sd_manifest_get` (refuses if absent per SPEC §16.1)
2. Read `ROADMAP.md` (path from manifest `routing.roadmap`), locate target VS via VS-id
3. Read `MASTER-SPEC.md`, memory bank Tier 0 (auto-loaded), cursor (`05-active-context.md`)
4. Propose decomposition (4-5 work items) with rationale; user iterates
5. Offer grill-me (composition.json probe via `lib/compose.sh`; user opt-in)
6. Identify rounds via topological sort on declared dependencies; user may loosen/tighten
7. Author at slice-init: `README.md`, all `spec.md` files, empty `handoff.md` + `report.md` placeholders
8. Offer grill-me on specs (gate 2)
9. Invoke architect-critic `critiquing-spec` skill in-conversation (per SPEC §16.3); challenges/concessions cycle
10. Per round (sequential): create worktrees via `lib/worktree.sh::sd_worktree_add`; author handoff per `templates/implementation-handoff.md.tmpl`; dispatch `Task(subagent_type="scaffold-dev:implementer-agent", prompt=<handoff-content+context>)`
11. Process subagent returns per §6.3 multi-call protocol
12. Run `implementation-checking` skill on each work item (§12.1 verification gate)
13. Commit + merge per `git_policy`; halt on conflict per §11
14. After all items in round: surface "Round K complete; ready for K+1 or close slice?"
15. On slice close, suggest invoking `closing-vertical-slice` skill

**Cross-references:**
- `lib/manifest.sh`, `lib/state.sh`, `lib/worktree.sh`, `lib/merge.sh`, `lib/compose.sh`, `lib/render.sh`
- Templates: `work-item-spec.md.tmpl`, `vertical-slice-readme.md.tmpl`, `implementation-handoff.md.tmpl`
- Composed skills: `architect-critic:critiquing-spec`, `ai-mentor:grill-me`, `executing-work-item` (via subagent)

**Acceptance:** Phase 0 T0.1 scenarios pass under subagent eval.

- [ ] **Step 1:** Author SKILL.md (≤500 lines)
- [ ] **Step 2:** Re-run T0.1 eval (manually, not subagent — Phase 6 does subagent pressure)
- [ ] **Step 3:** Commit
  ```bash
  git commit -m "scaffold-dev: author planning-vertical-slice SKILL.md (v0.1 Phase 1 T1.1)"
  ```

### Task T1.2 — `skills/implementation-checking/SKILL.md`

**Files:**
- Create: `scaffold-dev/skills/implementation-checking/SKILL.md`

**Description:**
> Per-work-item verification gate. Reads work-item spec, runs each `auto:` step (per SPEC §14.1 grammar) via `lib/verify.sh::sd_verify_auto_step`, runs report cross-check against report.md, consults `lib/rules.sh::sd_rules_check` for R2 rules if scaffold-onboard's `03-code-patterns.md` has mcrule blocks (falls back to AC-only if absent). Surfaces failure-response menu (§12.2) on any fail.

**Body sections:**
1. Parse work-item spec (locate Acceptance Criteria section)
2. For each AC with `auto:` step: invoke `sd_verify_auto_step <line>`; capture exit code + stderr
3. Cross-check report.md sections for completeness (§12.1)
4. If scaffold-onboard detected + `03-code-patterns.md` has mcrule blocks: consume `sf_rules_filter` output, run each rule against the work-item's modified files (use `lib/rules.sh::sd_rules_apply`)
5. On any fail: present §12.2 menu (4 options for AC fail; 3 for report mismatch; 3 for rule fail)
6. On all-pass: report green; return control to orchestrator

**Acceptance:** Phase 0 T0.2 scenarios pass.

- [ ] **Step 1:** Author SKILL.md
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: author implementation-checking SKILL.md (v0.1 Phase 1 T1.2)"
  ```

### Task T1.3 — `skills/closing-vertical-slice/SKILL.md`

**Files:**
- Create: `scaffold-dev/skills/closing-vertical-slice/SKILL.md`

**Description:**
> Three-layer slice-close ceremony (§14): auto-demo execution + manual-demo guided steps + architect-critic adversarial review. Then retrospective authoring + memory-bank harvest (§15.2: sweeps both work-item reports AND slice handoffs; source-tags promote candidates). Removes worktrees + branches ONLY after ceremony completes (per §11).

**Body sections:**
1. Read slice README for `auto:` + `user:` lines; parse via `lib/render.sh::sd_demo_parse_block`
2. **Layer 1 — auto-demo:** for each `auto:` line, run command, check exit code OR pattern match; record pass/fail in VS README
3. **Layer 2 — manual-demo:** present each `user:` step to user; capture pass/fail + notes
4. **Layer 3 — architect-critic adversarial review:** detect via `lib/compose.sh::sd_compose_detect_architect_critic`; if v0.2 present, invoke `critiquing-spec` skill in-conversation with slice diff + VS README + work-item specs; rebuttal cycle in conversation
5. **Retrospective:** author `retrospective.md` per `templates/slice-retrospective.md.tmpl` (7 sections per §16b)
6. **Memory-bank harvest (§15.2 8-step flow):**
   - Read all work-item `report.md`
   - Read all slice handoffs at `<ai-workspace>/.workspace/handoffs/vs-N.M-*.md`
   - Extract "Suggestions for memory bank" (reports) + section 4 "What's NOT in memory bank yet" (handoffs)
   - Categorize by target memory-bank file
   - Surface to user source-tagged `[report]` / `[handoff]`
   - User accept/edit/reject
   - Apply with provenance trailer
   - Record outcomes in retrospective.md
7. **Cleanup:** `lib/worktree.sh::sd_worktree_remove` for each slice worktree; delete branches (only after all above succeed)
8. **Sprint-close branch:** if this is the FINAL slice of the sprint, sweep + clear non-carry-forward handoffs (sprint-close cleanup per SPEC §6b.6); cleanup ownership locked here in v0.1 (vs separate `closing-sprint` skill)

**Acceptance:** Phase 0 T0.3 scenarios pass.

- [ ] **Step 1:** Author SKILL.md
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: author closing-vertical-slice SKILL.md (v0.1 Phase 1 T1.3)"
  ```

### Task T1.4 — `skills/executing-work-item/SKILL.md`

**Files:**
- Create: `scaffold-dev/skills/executing-work-item/SKILL.md`

**Critical:** this body is BOTH a skill (manual fallback per SPEC §6.4) AND the implementer-agent subagent system prompt (per Phase 3.5 agents.json). Single source of truth.

**Description:**
> Execute one work item per handoff doc. Pre-flight check (read handoff + spec end-to-end; verify worktree branch + clean state; identify ambiguity). If gaps detected: return `{mode: "gaps-surfaced", gaps: [...]}` without doing work. If pre-flight passes: TDD loop per Acceptance Criterion (write failing test → minimal impl → re-run → commit-staging-only; NEVER `git commit`). Run verification commands. Author report.md per template. Stage changes. Return `{mode: "complete", report_path, summary, stage_status}`.

**Body sections:**
1. **Pre-flight check (mandatory first action):**
   - Read handoff doc (path passed as arg)
   - Read work-item spec (path in handoff Header)
   - Verify worktree at handoff Header `Worktree:` path exists + is on declared branch + is clean (`git -C <abs> status --porcelain`)
   - Identify any ambiguity in spec ACs or Decisions
   - If gaps detected → return gaps-mode + EXIT
2. **TDD loop (per AC):**
   - Write failing test (use `superpowers:test-driven-development` discipline)
   - Verify test fails
   - Write minimal implementation
   - Verify test passes
   - Move to next AC
3. **Verification:** run all `auto:` verification commands from spec; halt on any failure (annotate in report)
4. **Author report.md:** 9 sections (header / objective / files changed / TDD log / verification results / deferrals / suggestions for memory bank / blockers if any / next-steps)
5. **Stage changes:** `git -C <worktree-abs-path> add .` (NO commit; commit is orchestrator's job per §17 write-conflict separation)
6. **Return:** structured JSON via stdout per SPEC §6.3 return modes

**Tools allowed when invoked as subagent (per agents.json registration):** Bash + Read + Write + Edit + Glob + Grep. NO Task (prevents nesting). NO commit ops.

**Acceptance:** Phase 0 T0.4 scenarios pass.

- [ ] **Step 1:** Author SKILL.md
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: author executing-work-item SKILL.md (v0.1 Phase 1 T1.4)"
  ```

### Task T1.5 — `skills/handing-off-session/SKILL.md`

**Files:**
- Create: `scaffold-dev/skills/handing-off-session/SKILL.md`

**Description (per SPEC §6b):**
> Compose a forward or return handoff doc capturing ephemeral pre-codification state for out-of-slice transitions. Writes to `<ai-workspace>/.workspace/handoffs/<scope>-<purpose>-<short-id>.md` per §6b.1 naming convention. 10 standardized sections per §6b.5. Lazily creates `handoffs/` subdir on first invocation. Detects type (forward / return) from invocation args + conversation context.

**Body sections:**
1. Parse args via `$ARGUMENTS` bridge: `--scope sprint|slice|mid-slice|bugfix|techdebt` + `--purpose "<slug>"` (optional `--return-of <forward-handoff-name>` for return handoffs)
2. Validate scope value; sanitize purpose to kebab-case
3. Generate 4-char hex short-id (random)
4. Compose target path: `${ai_workspace.root}/.workspace/handoffs/<scope>-<purpose>-<short-id>.md` (or `-return.md` suffix for return)
5. `mkdir -p` the `handoffs/` dir if absent (workspace-init seeded the parent `.workspace/` + gitignore)
6. Gather current state via `lib/state.sh::sd_state_read_cursor` (active sprint, slice, work-item position)
7. Gather workspace pointers via `lib/manifest.sh::sd_manifest_get`
8. Render template `templates/handoff.md.tmpl` (per §6b.5 10 sections) with `{{var}}` substitution
9. Prompt user for section 4 content ("What's NOT in memory bank yet — list slice-specific decisions, deviations, conversation deltas, anti-patterns") — REQUIRED, refuses empty
10. Prompt user for section 8 ("Next intended action(s)") — REQUIRED
11. Write file via atomic mv pattern
12. Print path + next-session prompt: `"Read the handoff at <abs-path> and proceed"`

**Acceptance:** Phase 0 T0.5 scenarios pass.

- [ ] **Step 1:** Author SKILL.md
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: author handing-off-session SKILL.md (v0.1 Phase 1 T1.5)"
  ```

### Task T1.6 — `skills/recording-architecture-decision/SKILL.md`

**Files:**
- Create: `scaffold-dev/skills/recording-architecture-decision/SKILL.md`

**Description:**
> Manifest-routed ADR authoring per §7.1. Product ADRs (architectural decisions about the user's project) → `canonical` (per manifest `routing.product_adrs`). Process ADRs (decisions about the agent-workflow itself) → `ai_workspace` (per `routing.process_adrs`). User declares type at invocation; skill chooses target via `lib/manifest.sh`. Format: MADR-lite (status, context, decision, consequences).

**Body:**
1. Prompt user: "Is this a product ADR (your project's architecture) or process ADR (agent-workflow / scaffold-dev's process)?"
2. Resolve target dir via manifest
3. Determine next ADR number (scan existing `adr-NNNN-*.md` files)
4. Prompt for title (kebab-case)
5. Render `templates/adr.md.tmpl` (NEW — add to Phase 2)
6. Write file

- [ ] **Step 1:** Author SKILL.md (smaller; ≤300 lines)
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: author recording-architecture-decision SKILL.md (v0.1 Phase 1 T1.6)"
  ```

### Task T1.7 — `skills/appending-changelog-entry/SKILL.md`

**Files:**
- Create: `scaffold-dev/skills/appending-changelog-entry/SKILL.md`

**Description:**
> Append a Keep-a-Changelog 1.1.0 entry to `CHANGELOG.md` under `[Unreleased]`. Categories: Added / Changed / Deprecated / Removed / Fixed / Security. Manifest-routed: changelog in canonical (production-facing).

- [ ] **Step 1:** Author SKILL.md (≤200 lines)
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: author appending-changelog-entry SKILL.md (v0.1 Phase 1 T1.7)"
  ```

### Task T1.8 — `skills/authoring-runbook/SKILL.md`

**Files:**
- Create: `scaffold-dev/skills/authoring-runbook/SKILL.md`

**Description:**
> SRE-style runbook template — overview, symptoms, immediate response, diagnosis, mitigation, postmortem-link slot. Stored in canonical's `docs/runbooks/`.

- [ ] **Step 1:** Author SKILL.md (≤250 lines)
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: author authoring-runbook SKILL.md (v0.1 Phase 1 T1.8)"
  ```

### Task T1.9 — `skills/writing-sprint-retrospective/SKILL.md`

**Files:**
- Create: `scaffold-dev/skills/writing-sprint-retrospective/SKILL.md`

**Description:**
> Aggregate all VS retrospectives from `docs/specs/sprint-N/VS-*/retrospective.md`; identify cross-slice patterns; harvest sprint-level memory-bank items; author `sprint-N/sprint-retrospective.md` per `templates/sprint-retrospective.md.tmpl` (6 sections per §16b). Invoked at sprint close (the final slice's close-vertical-slice triggers this OR user invokes manually via `/close-sprint N`).

- [ ] **Step 1:** Author SKILL.md (≤350 lines)
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: author writing-sprint-retrospective SKILL.md (v0.1 Phase 1 T1.9)"
  ```

---

## Phase 2 — Reference sub-docs + templates (~1-2 days)

Each skill gets supporting reference docs (worked examples, edge cases) one level deep under `skills/<name>/`. Also author the 7 templates.

### Task T2.1 — Reference docs for `planning-vertical-slice`

**Files:**
- Create: `scaffold-dev/skills/planning-vertical-slice/references/`
  - `decomposition-worked-example.md` (4-5 work-item decomposition for a sample VS)
  - `round-identification-DAG-example.md` (worked strict-layer DAG)
  - `architect-critic-invocation-example.md` (full request/response shape)

- [ ] **Step 1:** Author 3 reference docs (~100-200 lines each)
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: reference docs for planning-vertical-slice (v0.1 Phase 2 T2.1)"
  ```

### Task T2.2 — Reference docs for `executing-work-item`

**Files:**
- Create: `scaffold-dev/skills/executing-work-item/references/`
  - `pre-flight-check-worked-example.md`
  - `tdd-loop-per-ac-example.md`
  - `gaps-mode-return-example.md`
  - `complete-mode-return-example.md`

- [ ] **Step 1:** Author 4 reference docs
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: reference docs for executing-work-item (v0.1 Phase 2 T2.2)"
  ```

### Task T2.3 — Reference docs for `handing-off-session`

**Files:**
- Create: `scaffold-dev/skills/handing-off-session/references/`
  - `forward-handoff-bugfix-example.md`
  - `return-handoff-example.md`
  - `sprint-carry-forward-example.md`
  - `chain-model-vs-rejoin-explanation.md`

- [ ] **Step 1:** Author 4 reference docs
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: reference docs for handing-off-session (v0.1 Phase 2 T2.3)"
  ```

### Task T2.4 — Reference docs for closing-vertical-slice + remaining skills

**Files:**
- Create reference dirs for `closing-vertical-slice`, `implementation-checking`, `recording-architecture-decision`, `appending-changelog-entry`, `authoring-runbook`, `writing-sprint-retrospective`

Lighter weight — 1-2 docs each.

- [ ] **Step 1:** Author reference docs for remaining 6 skills
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: reference docs for remaining 6 skills (v0.1 Phase 2 T2.4)"
  ```

### Task T2.5 — Templates

**Files:**
- Create:
  - `scaffold-dev/templates/work-item-spec.md.tmpl` (Wabash Format B 8-section per SPEC §9)
  - `scaffold-dev/templates/vertical-slice-readme.md.tmpl` (per §9b)
  - `scaffold-dev/templates/implementation-handoff.md.tmpl` (heavy ~250-line shape per §10)
  - `scaffold-dev/templates/implementation-report.md.tmpl` (9 sections per §10)
  - `scaffold-dev/templates/slice-retrospective.md.tmpl` (7 sections per §16b)
  - `scaffold-dev/templates/sprint-retrospective.md.tmpl` (6 sections per §16b)
  - `scaffold-dev/templates/handoff.md.tmpl` (NEW; 10 sections per §6b.5; supports forward + return)
  - `scaffold-dev/templates/adr.md.tmpl` (MADR-lite)

All use `{{var}}` substitution grammar (matches scaffold-onboard's `render.sh`).

- [ ] **Step 1:** Author 8 templates
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: 8 templates (specs/handoffs/reports/retros) (v0.1 Phase 2 T2.5)"
  ```

---

## Phase 3 — Utility scripts (~3-5 days)

TDD per script: tests first, then implementation. Source `_helpers.sh` in each lib.

### Task T3.1 — `lib/_helpers.sh` + `tests/test-helpers.sh`

**Files:**
- Create: `scaffold-dev/tests/test-helpers.sh`
- Create: `scaffold-dev/lib/_helpers.sh`

**API:**
```bash
sd_log_info()   { echo "[scaffold-dev] $*" >&2; }
sd_log_warn()   { echo "[scaffold-dev WARN] $*" >&2; }
sd_log_error()  { echo "[scaffold-dev ERROR] $*" >&2; }

sd_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    sd_log_error "jq not in PATH; scaffold-dev requires jq. Install via brew install jq (macOS) or apt install jq (Linux)."
    return 1
  fi
}

sd_abs_path() {
  # $1 — possibly relative path
  # echo absolute path
  local p="$1"
  if [[ "$p" == /* ]]; then
    echo "$p"
  else
    echo "$(cd "$(dirname "$p")" 2>/dev/null && pwd)/$(basename "$p")"
  fi
}

sd_jq_get() {
  # $1 — file
  # $2 — jq expression
  jq -r "$2 // empty" "$1" 2>/dev/null
}
```

- [ ] **Step 1:** Write `test-helpers.sh` with 8 tests covering each function
- [ ] **Step 2:** Run tests — verify FAIL (lib not yet implemented)
- [ ] **Step 3:** Implement `_helpers.sh`
- [ ] **Step 4:** Run tests — verify all PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/_helpers.sh + test-helpers.sh (v0.1 Phase 3 T3.1)"
  ```

### Task T3.2 — `lib/manifest.sh` + `tests/test-manifest.sh`

**Files:**
- Create: `scaffold-dev/tests/test-manifest.sh`
- Create: `scaffold-dev/lib/manifest.sh`

**API:**
```bash
sd_manifest_discover() {
  # Walk up from $PWD looking for .workspace/pairing.json
  # Caches per-session via env var _SD_MANIFEST_PATH
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.workspace/pairing.json" ]]; then
      echo "$dir/.workspace/pairing.json"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

sd_manifest_get() {
  # $1 — jq path expression (e.g., ".ai_workspace.root", ".routing.roadmap")
  local manifest
  manifest="$(sd_manifest_discover)" || { sd_log_error "no manifest found"; return 1; }
  sd_jq_get "$manifest" "$1"
}

sd_manifest_resolve() {
  # Source workspace-init's mi_manifest_resolve for ${var} + ${PLUGIN_DATA:<name>} substitution
  # Cross-plugin source pattern:
  local mi_path="${HOME}/.claude/plugins/cache"/*/workspace-init/*/lib/manifest.sh
  if [[ ! -f $mi_path ]]; then
    sd_log_warn "workspace-init's manifest.sh not found; falling back to local minimal resolver"
    # Local fallback: just expand ${ai_workspace.root} and ${canonical.root}
    ...
  fi
  source $mi_path
  mi_manifest_resolve "$@"
}

sd_manifest_require() {
  # Refuses to start if absent. Call early in any skill body that needs manifest.
  if ! sd_manifest_discover >/dev/null; then
    sd_log_error "scaffold-dev requires a workspace-init pairing manifest. Run /init-workspace or /pair-workspace first."
    return 1
  fi
}
```

**Tests cover:** walk-up discovery (cwd, parent, grandparent); manifest absent → require fails; field reads; `${var}` substitution; `${PLUGIN_DATA:<name>}` substitution.

- [ ] **Step 1:** Write `test-manifest.sh` with 12 tests
- [ ] **Step 2:** Run tests — verify FAIL
- [ ] **Step 3:** Implement `manifest.sh`
- [ ] **Step 4:** Run tests — verify all PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/manifest.sh + test-manifest.sh (v0.1 Phase 3 T3.2)"
  ```

### Task T3.3 — `lib/state.sh` + `tests/test-state.sh`

**Files:**
- Create: `scaffold-dev/tests/test-state.sh`
- Create: `scaffold-dev/lib/state.sh`

**API:**
```bash
sd_state_read_cursor() {
  # Read 05-active-context.md from memory bank; extract active sprint/slice/work-item
  # Memory bank path via manifest's well_known_paths.memory_bank
  ...
}

sd_state_write_cursor() {
  # $1 — sprint id, $2 — slice id, $3 — work-item id
  # Update 05-active-context.md atomically (jq-then-mv pattern)
  ...
}

sd_state_active_sprint()    { sd_state_read_cursor | jq -r .sprint; }
sd_state_active_slice()     { sd_state_read_cursor | jq -r .slice; }
sd_state_active_work_item() { sd_state_read_cursor | jq -r .work_item; }
```

**Tests:** CRUD; atomic write under simulated failure; concurrent read safety; absence handling.

- [ ] **Step 1:** Write `test-state.sh` with 10 tests
- [ ] **Step 2:** Run tests → FAIL
- [ ] **Step 3:** Implement `state.sh`
- [ ] **Step 4:** Run tests → PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/state.sh + test-state.sh (v0.1 Phase 3 T3.3)"
  ```

### Task T3.4 — `lib/worktree.sh` + `tests/test-worktree.sh`

**Files:**
- Create: `scaffold-dev/tests/test-worktree.sh`
- Create: `scaffold-dev/lib/worktree.sh`

**API:**
```bash
sd_worktree_add() {
  # $1 — work-item id (e.g., "2.04")
  # $2 — slice id (e.g., "VS-3.2")
  # $3 — kebab-name
  # Creates: ${canonical.root}/.worktrees/work-N.NN-<kebab>
  # Branch: per manifest's during_dev.branch_naming
  local work_id="$1"; local slice_id="$2"; local kebab="$3"
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')"
  local branch_template
  branch_template="$(sd_manifest_get '.during_dev.branch_naming')"
  local branch="${branch_template/\{N\}/${slice_id#VS-}}"
  branch="${branch/\{NN\}/${work_id}}"
  branch="${branch/\{kebab-name\}/${kebab}}"
  local wt_path="${canonical}/.worktrees/work-${work_id}-${kebab}"
  git -C "$canonical" worktree add -b "$branch" "$wt_path" main
  echo "$wt_path"
}

sd_worktree_remove() {
  # $1 — worktree abs path
  # Removes worktree + deletes branch (called at slice close per SPEC §11)
  local wt_path="$1"
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')"
  local branch
  branch="$(git -C "$wt_path" rev-parse --abbrev-ref HEAD)"
  git -C "$canonical" worktree remove "$wt_path"
  git -C "$canonical" branch -D "$branch"
}

sd_worktree_list() { git -C "$(sd_manifest_get .canonical.root)" worktree list; }
```

**Tests:** add with correct branch name; remove cleans up; list returns expected; failure on dirty worktree.

- [ ] **Step 1:** Write `test-worktree.sh` (12 tests)
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Implement
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/worktree.sh + test-worktree.sh (v0.1 Phase 3 T3.4)"
  ```

### Task T3.5 — `lib/merge.sh` + `tests/test-merge.sh`

**Files:**
- Create: `scaffold-dev/tests/test-merge.sh`
- Create: `scaffold-dev/lib/merge.sh`

**API:**
```bash
sd_merge_work_item() {
  # $1 — worktree abs path
  # $2 — work-item branch name
  # Commits in worktree per git_policy; merges branch into canonical main
  # Halts on conflict
  local wt="$1"; local branch="$2"
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')"
  # Pre-merge: verify clean staged state
  if ! git -C "$wt" diff --cached --quiet; then
    git -C "$wt" commit -m "Implement ${branch}"   # commit policy: orchestrator-driven
  fi
  # Merge into main
  if ! git -C "$canonical" merge --no-ff "$branch"; then
    sd_log_error "merge conflict on $branch; halt and resolve manually"
    return 1
  fi
}

sd_merge_abort() {
  local canonical="$(sd_manifest_get .canonical.root)"
  git -C "$canonical" merge --abort
}
```

**Tests:** clean merge; conflict detection; abort path; idempotency.

- [ ] **Step 1:** Write `test-merge.sh` (14 tests)
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Implement
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/merge.sh + test-merge.sh (v0.1 Phase 3 T3.5)"
  ```

### Task T3.6 — `lib/harvest.sh` + `tests/test-harvest.sh`

**Files:**
- Create: `scaffold-dev/tests/test-harvest.sh`
- Create: `scaffold-dev/lib/harvest.sh`

**API:**
```bash
sd_harvest_reports() {
  # $1 — slice dir (docs/specs/sprint-N/VS-N.M-<kebab>/)
  # Sweeps all work-N.NN-*/report.md, extracts "Suggestions for memory bank" sections
  # Emits JSON array: [{source:"report", work_item:"...", target_file:"...", suggestion:"..."}]
  ...
}

sd_harvest_handoffs() {
  # $1 — slice id (e.g., "vs-3.2")
  # Sweeps <ai-workspace>/.workspace/handoffs/vs-N.M-*.md
  # Extracts section 4 "What's NOT in memory bank yet"
  # Emits JSON array: [{source:"handoff", handoff_file:"...", item:"..."}]
  ...
}

sd_harvest_apply() {
  # $1 — accepted-items JSON array
  # $2 — slice id (for provenance)
  # Writes each item to its target memory-bank file with trailer:
  # <!-- Added from VS-N.M retrospective, YYYY-MM-DD; source: report|handoff -->
  ...
}
```

**Tests:** report sweep; handoff sweep; source-tagging; provenance trailer; idempotent re-runs; empty case.

- [ ] **Step 1:** Write `test-harvest.sh` (12 tests)
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Implement
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/harvest.sh + test-harvest.sh (v0.1 Phase 3 T3.6)"
  ```

### Task T3.7 — `lib/verify.sh` + `tests/test-verify.sh`

**Files:**
- Create: `scaffold-dev/tests/test-verify.sh`
- Create: `scaffold-dev/lib/verify.sh`

**API:**
```bash
sd_verify_auto_step() {
  # $1 — line text, e.g., "- [ ] auto: `pytest tests/integration/test_x.py` → expected: exit 0"
  # Parse command + expected (exit code OR pattern)
  # Run command, check expectation, return 0/1
  local line="$1"
  # Extract command: between backticks
  local cmd="$(echo "$line" | sed -nE 's/.*auto: `([^`]+)`.*/\1/p')"
  local expected="$(echo "$line" | sed -nE 's/.*expected: (.*)/\1/p')"
  local output
  output="$(eval "$cmd" 2>&1)"
  local ec=$?
  case "$expected" in
    "exit 0")     [[ $ec -eq 0 ]] && return 0 || return 1 ;;
    "exit "*)     local code="${expected#exit }"; [[ $ec -eq $code ]] && return 0 || return 1 ;;
    "output contains "*) local needle="${expected#output contains }"; echo "$output" | grep -q "$needle" && return 0 || return 1 ;;
    *)            sd_log_error "unknown expected form: $expected"; return 2 ;;
  esac
}

sd_verify_report_cross_check() {
  # $1 — report.md path
  # $2 — spec.md path (with ACs)
  # Verify each AC has corresponding report section
  ...
}
```

**Tests:** auto-step parsing; exit-code expectation; pattern expectation; report cross-check; unknown expected → error.

- [ ] **Step 1:** Write `test-verify.sh` (14 tests)
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Implement
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/verify.sh + test-verify.sh (v0.1 Phase 3 T3.7)"
  ```

### Task T3.8 — `lib/rules.sh` + `tests/test-rules.sh`

**Files:**
- Create: `scaffold-dev/tests/test-rules.sh`
- Create: `scaffold-dev/lib/rules.sh`

**API:**
```bash
sd_rules_load() {
  # Source scaffold-onboard's sf_rules_* functions (via filesystem cache path)
  local sn_path="${HOME}/.claude/plugins/cache"/*/scaffold-onboard/*/lib/rules.sh
  if [[ ! -f $sn_path ]]; then
    sd_log_warn "scaffold-onboard v0.2 not in cache; R2 rule-checking disabled (fallback to AC-only)"
    return 1
  fi
  source $sn_path
}

sd_rules_check() {
  # $1 — list of changed files (newline-separated)
  # Returns 0 if all rules pass; 1 if any rule fails
  # Uses scaffold-onboard's sf_rules_parse + sf_rules_filter
  ...
}
```

**Tests:** load when scaffold-onboard present; graceful absence; rule check on file list; fallback to AC-only.

- [ ] **Step 1:** Write `test-rules.sh` (8 tests)
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Implement
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/rules.sh + test-rules.sh (v0.1 Phase 3 T3.8)"
  ```

### Task T3.9 — `lib/render.sh` + `tests/test-render.sh`

**Files:**
- Create: `scaffold-dev/tests/test-render.sh`
- Create: `scaffold-dev/lib/render.sh`

**API (ported from scaffold-onboard pattern):**
```bash
sd_render_template() {
  # $1 — template path
  # $2 — vars JSON (object with key-value pairs)
  # Replaces {{key}} with value in template; output to stdout
  local tmpl="$1"; local vars="$2"
  local content
  content="$(cat "$tmpl")"
  while IFS='=' read -r key value; do
    content="${content//\{\{${key}\}\}/${value}}"
  done < <(echo "$vars" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
  echo "$content"
}
```

**Tests:** simple substitution; missing key warns; nested `{{var}}` not supported (warn); HTML entities preserved.

- [ ] **Step 1:** Write `test-render.sh` (10 tests)
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Implement
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/render.sh + test-render.sh (v0.1 Phase 3 T3.9)"
  ```

### Task T3.10 — `lib/handoff.sh` + `tests/test-handoff.sh`

**Files:**
- Create: `scaffold-dev/tests/test-handoff.sh`
- Create: `scaffold-dev/lib/handoff.sh`

**API:**
```bash
sd_handoff_dir() {
  # Returns abs path to <ai-workspace>/.workspace/handoffs/
  local ai_workspace
  ai_workspace="$(sd_manifest_get '.ai_workspace.root')"
  echo "${ai_workspace}/.workspace/handoffs"
}

sd_handoff_ensure_dir() {
  # Auto-create handoffs/ subdir on first invocation (workspace-init owns .workspace/)
  local d
  d="$(sd_handoff_dir)"
  mkdir -p "$d"
}

sd_handoff_short_id() {
  # Generate 4-char hex random id
  printf '%04x' $(( RANDOM * RANDOM & 0xffff ))
}

sd_handoff_compose_path() {
  # $1 — scope (sprint|slice|mid-slice|bugfix|techdebt)
  # $2 — purpose (kebab-case)
  # $3 — short-id
  # $4 — optional --return (suffix -return.md)
  local scope="$1"; local purpose="$2"; local id="$3"; local suffix="${4:-}"
  local name="${scope}-${purpose}-${id}${suffix}.md"
  echo "$(sd_handoff_dir)/${name}"
}

sd_handoff_list() {
  # List all handoffs matching $1 prefix (e.g., "vs-3.2-" or "sprint-3-")
  local prefix="$1"
  ls "$(sd_handoff_dir)/${prefix}"*.md 2>/dev/null
}

sd_handoff_cleanup_sprint() {
  # $1 — sprint id (e.g., 3)
  # $2 — carry-forward exception (optional; e.g., "sprint-3-to-4-handoff-")
  # Removes all sprint-N-* and vs-N.*-* handoffs EXCEPT carry-forward
  ...
}
```

**Tests:** dir auto-create; short-id uniqueness; path composition; list with prefix; sprint cleanup with carry-forward exception.

- [ ] **Step 1:** Write `test-handoff.sh` (16 tests)
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Implement
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/handoff.sh + test-handoff.sh (v0.1 Phase 3 T3.10)"
  ```

### Task T3.11 — `lib/compose.sh` + `tests/test-compose.sh`

**Files:**
- Create: `scaffold-dev/tests/test-compose.sh`
- Create: `scaffold-dev/lib/compose.sh`

**API (filesystem probe per SPEC §16.3 / §16.4):**
```bash
sd_compose_detect_architect_critic() {
  local cache_dirs=(
    "${HOME}/.claude/plugins/cache"
    "${CLAUDE_PLUGINS_DIR:-}"
  )
  for cache in "${cache_dirs[@]}"; do
    [[ -z "$cache" || ! -d "$cache" ]] && continue
    for skill_md in "$cache"/*/architect-critic/*/skills/critiquing-spec/SKILL.md; do
      [[ -f "$skill_md" ]] && { echo "v0.2"; return 0; }
    done
  done
  echo "absent"
  return 1
}

sd_compose_detect_ai_mentor() {
  # Same pattern; looks for ai-mentor/skills/grill-me/SKILL.md
  ...
}

sd_compose_warn_critic_absent() {
  sd_log_warn "[scaffold-dev] architect-critic not installed; skipping adversarial review at this gate. Install via /plugin install architect-critic for adversarial review."
}

sd_compose_warn_grillme_absent() {
  sd_log_warn "[scaffold-dev] ai-mentor not installed; grill-me offer skipped. Install via /plugin install ai-mentor for stress-test-the-design dialogue."
}
```

**Tests:** mock cache dirs; detection v0.2 present / absent; same for ai-mentor; warn messages emitted to stderr.

- [ ] **Step 1:** Write `test-compose.sh` (10 tests)
- [ ] **Step 2:** Run → FAIL
- [ ] **Step 3:** Implement
- [ ] **Step 4:** Run → PASS
- [ ] **Step 5:** Commit
  ```bash
  git commit -m "scaffold-dev: lib/compose.sh + test-compose.sh (v0.1 Phase 3 T3.11)"
  ```

---

## Phase 3.5 — Subagent definition (~1 day)

### Task T3.5.1 — `.claude-plugin/agents.json` registration

**Files:**
- Create: `scaffold-dev/.claude-plugin/agents.json`

**Content:**
```json
{
  "subagent_types": [
    {
      "name": "scaffold-dev:implementer-agent",
      "description": "Execute a single work item per a handoff doc. Pre-flight check; if gaps detected, return gaps-mode. Else TDD loop per AC; verify; author report.md; stage changes (NO commit). Return structured JSON.",
      "system_prompt_skill": "skills/executing-work-item/SKILL.md",
      "tools_allowed": ["Bash", "Read", "Write", "Edit", "Glob", "Grep"],
      "tools_denied": ["Task"],
      "model": "inherit"
    }
  ]
}
```

**Note:** exact schema for `agents.json` may differ from Claude Code's actual subagent_type registration format; verify against Claude Code docs at implementation time. Adjust file name + schema accordingly. The conceptual content (skill body as system prompt, tool restrictions, no nesting) is what matters.

- [ ] **Step 1:** Author `agents.json`
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: agents.json subagent registration (v0.1 Phase 3.5 T3.5.1)"
  ```

### Task T3.5.2 — `tests/test-subagent.sh` — subagent return-mode parsing

**Files:**
- Create: `scaffold-dev/tests/test-subagent.sh`

Tests cover (without actually dispatching subagents — that's Phase 6):
- gaps-mode JSON shape parse
- complete-mode JSON shape parse
- malformed JSON detection
- stage_status field values (`all_staged`, `partial`, `none`)
- Multi-call clarification loop counter (max 3 iterations per SPEC §6.6)

```bash
#!/usr/bin/env bash
# Fixtures: pre-built subagent return JSON snippets
GAPS_RESPONSE='{"mode":"gaps-surfaced","gaps":[{"section":"spec §3","question":"AC-2 means X or Y?","severity":"blocking"}]}'
COMPLETE_RESPONSE='{"mode":"complete","report_path":"/abs/report.md","summary":"Implemented AC-1,2,3","stage_status":"all_staged"}'
MALFORMED='{"mode":"complete"'   # truncated

# Source orchestrator-side parser (will live in planning-vertical-slice skill body, but the parse logic lives here)
source ../lib/_helpers.sh

# Test: gaps-mode parse extracts gaps array
test_gaps_parse() {
  local mode
  mode="$(echo "$GAPS_RESPONSE" | jq -r '.mode')"
  assert_eq "$mode" "gaps-surfaced"
  local gaps_count
  gaps_count="$(echo "$GAPS_RESPONSE" | jq '.gaps | length')"
  assert_eq "$gaps_count" "1"
}

# Test: malformed JSON detected
test_malformed_rejected() {
  if echo "$MALFORMED" | jq . >/dev/null 2>&1; then
    fail "malformed JSON unexpectedly parsed"
  fi
}
# ... 14 total tests
```

- [ ] **Step 1:** Write `test-subagent.sh` (14 tests; fixture-based, no actual subagent dispatch)
- [ ] **Step 2:** Run tests; verify all PASS (parsing logic only — no impl needed; tests verify JSON shape contract)
- [ ] **Step 3:** Commit
  ```bash
  git commit -m "scaffold-dev: test-subagent.sh return-mode parsing fixtures (v0.1 Phase 3.5 T3.5.2)"
  ```

---

## Phase 4 — Hooks (~1 day)

### Task T4.1 — `hooks/hooks.json` + `hooks-handlers/session-start.sh` + `tests/test-hook.sh`

**Files:**
- Create: `scaffold-dev/hooks/hooks.json`
- Create: `scaffold-dev/hooks-handlers/session-start.sh`
- Create: `scaffold-dev/tests/test-hook.sh`

**`hooks/hooks.json`:**
```json
{
  "SessionStart": "hooks-handlers/session-start.sh"
}
```

**`hooks-handlers/session-start.sh`:**
```bash
#!/usr/bin/env bash
# Walk up for .workspace/pairing.json; if not in AI workspace, emit stderr warning;
# otherwise coordinate Tier 0 marker with scaffold-onboard (skip if marker exists; emit if not).

set -uo pipefail
_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)"
source "$_SD_LIB_DIR/_helpers.sh"
source "$_SD_LIB_DIR/manifest.sh"

TIER0_MARKER="${TMPDIR:-/tmp}/claude-code-tier0-${CLAUDE_SESSION_ID:-default}"

# First: check marker (coordinate with scaffold-onboard per SPEC §15.1)
if [[ -f "$TIER0_MARKER" ]]; then
  emitter="$(cat "$TIER0_MARKER" 2>/dev/null)"
  if [[ "$emitter" != "scaffold-dev" ]]; then
    # Another plugin already emitted Tier 0; we add a thin scaffold-dev cursor hint only
    if sd_manifest_discover >/dev/null 2>&1; then
      sprint="$(sd_state_active_sprint 2>/dev/null || echo unknown)"
      slice="$(sd_state_active_slice 2>/dev/null || echo unknown)"
      echo "[scaffold-dev] active sprint=${sprint} slice=${slice}"
    fi
    exit 0
  fi
fi

# We're first (or scaffold-dev re-emitted)
if ! sd_manifest_discover >/dev/null 2>&1; then
  echo "[scaffold-dev] not in an AI workspace; manifest discovery skipped" >&2
  exit 0
fi

# Emit Tier 0 + cursor; write marker
# (Tier 0 content sourced from memory bank's 00-overview.md per scaffold-onboard convention)
ai_workspace="$(sd_manifest_get .ai_workspace.root)"
[[ -f "${ai_workspace}/.claude/memory-bank/00-overview.md" ]] && head -50 "${ai_workspace}/.claude/memory-bank/00-overview.md"

sprint="$(sd_state_active_sprint 2>/dev/null || echo unknown)"
slice="$(sd_state_active_slice 2>/dev/null || echo unknown)"
echo "[scaffold-dev] active sprint=${sprint} slice=${slice}"

echo "scaffold-dev" > "$TIER0_MARKER"
exit 0
```

**`tests/test-hook.sh`:**
- Mock manifest absent → warning emitted, exit 0
- Manifest present, marker absent → emits Tier 0 + cursor + writes marker
- Marker exists with scaffold-onboard → emits cursor only
- Marker exists with scaffold-dev → re-emits full

- [ ] **Step 1:** Write `test-hook.sh` (6 tests)
- [ ] **Step 2:** Author `hooks.json` + `session-start.sh`
- [ ] **Step 3:** Run tests → PASS
- [ ] **Step 4:** Commit
  ```bash
  git commit -m "scaffold-dev: SessionStart hook + Tier 0 marker coordination (v0.1 Phase 4 T4.1)"
  ```

---

## Phase 5 — Slash command wrappers (~1 day)

### Task T5.1 — `commands/orchestrate.md`

**Files:**
- Create: `scaffold-dev/commands/orchestrate.md`

**Content (`$ARGUMENTS` env-var bridge per `feedback_slash_command_dollar_n_bug` memory):**
```markdown
---
description: Plan and orchestrate a vertical slice. Usage: /orchestrate VS-N.M
---

# /orchestrate

Bridge $ARGUMENTS into env var for the skill body to read.

```bash
export SCAFFOLD_DEV_ARGS="$ARGUMENTS"
```

Now invoke the skill: ask Claude to run the `planning-vertical-slice` skill on the slice referenced by `$SCAFFOLD_DEV_ARGS`.
```

- [ ] **Step 1:** Author command
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: /orchestrate slash command (v0.1 Phase 5 T5.1)"
  ```

### Task T5.2 — `commands/work-item.md`, `commands/impl-check.md`, `commands/handoff.md`

**Files:**
- Create: `scaffold-dev/commands/work-item.md` (wraps `executing-work-item` for manual fallback)
- Create: `scaffold-dev/commands/impl-check.md` (wraps `implementation-checking`)
- Create: `scaffold-dev/commands/handoff.md` (wraps `handing-off-session`)

Each follows the `$ARGUMENTS` bridge pattern.

- [ ] **Step 1:** Author 3 commands
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: 3 remaining slash commands (work-item, impl-check, handoff) (v0.1 Phase 5 T5.2)"
  ```

---

## Phase 6 — Subagent pressure tests (~2-3 days)

For each of the 9 skills, dispatch a subagent (via `Agent` tool, subagent_type=general-purpose) with realistic prompts; verify the skill auto-invokes correctly + body produces SPEC-defined behavior. Fixes the inevitable description-match weaknesses.

### Task T6.1-T6.9 — Pressure test each skill

Per skill, 3+ scenarios under subagent dispatch:
- T6.1 — `planning-vertical-slice` (decomposition, manifest-absent, ROADMAP-missing-VS, critic-absent)
- T6.2 — `implementation-checking` (AC pass, AC fail, rule fail, rules absent)
- T6.3 — `closing-vertical-slice` (ceremony happy path, demo step fail, critic absent, harvest with handoffs)
- T6.4 — `executing-work-item` (pre-flight clean, gaps detected, worktree dirty, verification mid-fail)
- T6.5 — `handing-off-session` (forward sprint, forward bugfix, return, mid-slice bloat, auto-create dir)
- T6.6 — `recording-architecture-decision`
- T6.7 — `appending-changelog-entry`
- T6.8 — `authoring-runbook`
- T6.9 — `writing-sprint-retrospective`

Output: per-skill summary doc at `scaffold-dev/evals/results/<skill>/<scenario>.md` with pass/fail + observed behavior.

- [ ] **Steps 1-9:** Run pressure tests for each skill; iterate on description text + body where matches fail
- [ ] **Step 10:** Aggregate results doc at `scaffold-dev/evals/results/SUMMARY.md`
- [ ] **Step 11:** Commit
  ```bash
  git commit -m "scaffold-dev: Phase 6 pressure-test summary across 9 skills (v0.1 Phase 6)"
  ```

Per `feedback_subagent_vs_inline_threshold` memory: if subagent dispatches reliably fail in this phase, pivot to inline reasoning-pass approach (matches scaffold-onboard's Phase 6).

---

## Phase 7 — Integration tests (~2-3 days)

### Task T7.1 — `tests/test-e2e.sh` minimal sprint fixture

**Files:**
- Create: `scaffold-dev/tests/test-e2e.sh`
- Create: `scaffold-dev/fixtures/sprint-fixture-minimal/`

Fixture: workspace-init'd dual-repo with scaffold-onboard outputs (MASTER-SPEC, ROADMAP with 1 sprint × 1 VS × 2 work items, 03-code-patterns.md with 1 mcrule).

Test flow:
1. `setup_test_workspace` creates fixture
2. Invoke `planning-vertical-slice` skill for VS-1.1
3. Verify decomposition + spec authoring + round identification
4. Invoke `executing-work-item` (via manual mode, NOT subagent — subagent dispatch tested separately) on work-item 1.01
5. Verify report.md authored + changes staged
6. Orchestrator runs `implementation-checking` → verify pass
7. Merge work-item; repeat for 1.02
8. Invoke `closing-vertical-slice` → verify ceremony + harvest
9. Verify worktrees removed + branches deleted

- [ ] **Step 1:** Author fixture + e2e test (12 assertions)
- [ ] **Step 2:** Run → ITERATE on lib bugs surfaced
- [ ] **Step 3:** Commit
  ```bash
  git commit -m "scaffold-dev: e2e test minimal sprint fixture (v0.1 Phase 7 T7.1)"
  ```

### Task T7.2 — `tests/test-e2e.sh` with bug-fix detour handoff

**Files:**
- Extend: `scaffold-dev/tests/test-e2e.sh`
- Create: `scaffold-dev/fixtures/sprint-fixture-with-bugfix-detour/`

Tests the full handoff chain (main → forward handoff → bug-fix session → return handoff → new main).

- [ ] **Step 1:** Author fixture + test extension
- [ ] **Step 2:** Run → ITERATE
- [ ] **Step 3:** Commit
  ```bash
  git commit -m "scaffold-dev: e2e test with bug-fix handoff chain (v0.1 Phase 7 T7.2)"
  ```

### Task T7.3 — `tests/test-e2e.sh` with architect-critic + ai-mentor composition

Extend e2e to invoke `critiquing-spec` via filesystem probe + `grill-me` offer at decomposition gate.

- [ ] **Step 1:** Extend
- [ ] **Step 2:** Run → ITERATE
- [ ] **Step 3:** Commit
  ```bash
  git commit -m "scaffold-dev: e2e composition with architect-critic + ai-mentor (v0.1 Phase 7 T7.3)"
  ```

### Task T7.4 — Regression sweep

Run all 13 test suites; verify total ~140-160 passing. Fix any cross-suite breakage.

- [ ] **Step 1:** `bash scaffold-dev/run-tests.sh` → verify all green
- [ ] **Step 2:** Commit any fixes
  ```bash
  git commit -m "scaffold-dev: Phase 7 regression sweep — all suites green (v0.1 Phase 7 T7.4)"
  ```

---

## Phase 8 — Publish (~1 day)

### Task T8.1 — `.claude-plugin/plugin.json` version + composition

**Files:**
- Create: `scaffold-dev/.claude-plugin/plugin.json`

```json
{
  "name": "scaffold-dev",
  "version": "0.1.0",
  "category": "workflow",
  "description": "Sprint-driven orchestrator-implementer workflow for dual-repo workspaces. 9 skills, 4 slash commands, custom implementer-agent subagent type via Task tool, handoff escape valve. Composes with workspace-init (manifest), scaffold-onboard (R1/R2/R3 contract), architect-critic (filesystem probe + critiquing-spec), ai-mentor (grill-me at 3 gates). Replaces scaffold v1.0.0.",
  "author": {"name": "Pras"},
  "composition": {
    "consumes": ["workspace-init.manifest", "scaffold-onboard.R1", "scaffold-onboard.R2", "scaffold-onboard.R3"],
    "invokes": ["architect-critic:critiquing-spec", "ai-mentor:grill-me"],
    "produces": ["docs/specs/sprint-N/VS-*/spec.md", "docs/specs/sprint-N/VS-*/handoff.md", "docs/specs/sprint-N/VS-*/report.md", "docs/specs/sprint-N/VS-*/retrospective.md", "docs/specs/sprint-N/sprint-retrospective.md", ".workspace/handoffs/*.md"]
  }
}
```

- [ ] **Step 1:** Author plugin.json
- [ ] **Step 2:** Commit
  ```bash
  git commit -m "scaffold-dev: bump plugin.json to v0.1.0 + composition (v0.1 Phase 8 T8.1)"
  ```

### Task T8.2 — `CHANGELOG.md`

**Files:**
- Create: `scaffold-dev/CHANGELOG.md`

Standard Keep-a-Changelog format. `[0.1.0] - 2026-MM-DD` with Added section listing 9 skills + 4 commands + 1 subagent_type + handoff escape valve.

- [ ] **Step 1:** Author
- [ ] **Step 2:** Commit

### Task T8.3 — Update root `README.md` plugin table

**Files:**
- Modify: `README.md` (project root)

Add row for scaffold-dev v0.1.0; mark scaffold v1.0.0 as deprecated.

- [ ] **Step 1:** Edit
- [ ] **Step 2:** Commit

### Task T8.4 — Update `.claude-plugin/marketplace.json`

**Files:**
- Modify: `.claude-plugin/marketplace.json`

Add scaffold-dev entry; verify ordering (workspace-init → scaffold-onboard → scaffold-dev → architect-critic → ai-mentor → claude-security-audit → ~~scaffold~~ deprecated).

- [ ] **Step 1:** Edit
- [ ] **Step 2:** Commit

### Task T8.5 — Tag + push

- [ ] **Step 1:** `git tag -a scaffold-dev-v0.1.0 -m "scaffold-dev v0.1.0 — orchestrator-implementer workflow + handoff escape valve"`
- [ ] **Step 2:** `git push origin main scaffold-dev-v0.1.0`
- [ ] **Step 3:** Verify on remote + `/plugin update scaffold-dev` locally → confirm install

### Task T8.6 — Update memories + close phase

**Files:**
- Modify: `~/.claude/projects/-Volumes-master-ssd-projects-claude-agent-scaffolding/memory/project_skill_first_retrofit_queue.md`

Mark scaffold-dev v0.1 SHIPPED; only scaffold-dev v0.x polish remains as future placeholder.

- [ ] **Step 1:** Update memory
- [ ] **Step 2:** Final commit
  ```bash
  git commit -m "scaffold-dev: v0.1.0 SHIPPED — memory updated"
  ```

---

## Self-review checklist (per `superpowers:writing-plans`)

After implementing, verify:

**Spec coverage:**
- §4 architecture: orchestrator+subagent execution contexts → Phases 1, 3, 3.5 ✓
- §5 VS lifecycle: planning-vertical-slice + components → Phase 1 T1.1 ✓
- §6 implementer-agent: subagent + multi-call protocol → Phase 3.5 T3.5.1, T3.5.2 ✓
- §6b handoff escape valve: handing-off-session skill + lib/handoff.sh → Phase 1 T1.5, Phase 3 T3.10 ✓
- §7 skill catalog: 9 skills → Phase 1 T1.1-T1.9 ✓
- §8 manifest consumption: lib/manifest.sh → Phase 3 T3.2 ✓
- §9, 9b spec format: templates → Phase 2 T2.5 ✓
- §10, 10b handoff/templating: templates + render.sh → Phase 2 T2.5, Phase 3 T3.9 ✓
- §11 worktree mechanics: lib/worktree.sh → Phase 3 T3.4 ✓
- §12 implementation-checking → Phase 1 T1.2, Phase 3 T3.7 (verify.sh) ✓
- §13 round-close: handled in planning-vertical-slice body → Phase 1 T1.1 ✓
- §14 slice-close ceremony: closing-vertical-slice → Phase 1 T1.3 ✓
- §15 memory bank: harvest.sh → Phase 3 T3.6 ✓
- §16 peer composition: compose.sh + skill bodies → Phase 1, Phase 3 T3.11 ✓
- §16b retrospective formats: templates → Phase 2 T2.5 ✓
- §17 state management: state.sh + write-conflict separation in skill bodies → Phase 3 T3.3 ✓
- §18 hooks: session-start.sh → Phase 4 T4.1 ✓
- §19 build sequence: this PLAN is the concretization ✓
- §20 testing strategy: ~168 tests across 13 suites → exceeds target ✓
- §23 risks: graceful degradation in compose.sh + manifest.sh ✓
- §25 DoD: Phase 8 publishing checklist ✓

**Placeholder scan:** none — every step has exact paths + code samples where critical.

**Type consistency:** function names follow `sd_<module>_<verb>` pattern uniformly; verified across T3.1-T3.11.

---

## Execution handoff

Plan complete and saved to `docs/PLAN-scaffold-dev.md`. Two execution options:

**1. Subagent-Driven (recommended)** — REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`. Dispatch a fresh subagent per task; review between tasks; fast iteration. Best for this PLAN given the ~50+ tasks and explicit TDD structure per phase. Per `feedback_subagent_vs_inline_threshold` memory: pivot to inline if subagent dispatches reliably fail.

**2. Inline Execution** — REQUIRED SUB-SKILL: `superpowers:executing-plans`. Execute tasks in this session; batch with checkpoints. Better if subagent infra is flaky.

Each phase produces a green test suite before advancing. No skipping ahead.

Phase 6 pressure tests are the highest-risk phase (subagent dispatch dependencies). If subagent reliability degrades, consolidate to inline reasoning-pass per scaffold-onboard's Phase 6 precedent.
