# workspace-init v0.1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Context

`workspace-init` is the first run-once plugin in the `claude-agent-scaffolding` marketplace chain (`workspace-init` → `scaffold-onboard` → `scaffold-dev` → `architect-critic` + `ai-mentor`). It bootstraps a **dual-repo workspace**: an AI workspace (git-tracked, holds memory bank / specs / agent scaffolding) paired with a canonical repo (production code, zero AI traces in commit history). Writes a JSON pairing manifest at `<ai-workspace>/.workspace/pairing.json` that every downstream plugin reads, installs a `commit-msg` git hook in both repos that blocks AI-trace patterns, and supports a `--pair-with <existing-canonical>` flow (Scenario A).

**Why this plugin exists:** P1 — AI traces (`Co-Authored-By: Claude`, `🤖 Generated with`, `<noreply@anthropic.com>`) aren't shareable in work-laptop canonical history; the trace filter unlocks AI-assisted local commits without compromising downstream-visible state. P2 — `git worktree` from single-repo setups starts cold because `.claude/`/`CLAUDE.md` are gitignored; splitting them into a sibling AI workspace keeps canonical worktrees clean. P3/P4 — scaffold-dev's parallel-slice orchestration and scaffold-onboard's PRD-vs-MASTER-SPEC routing only work cleanly with structural separation.

**Source SPEC:** [`docs/SPEC-workspace-init.md`](../../../Volumes/master_ssd/projects/claude-agent-scaffolding/docs/SPEC-workspace-init.md) — v0.1, adversarial-review revisions applied 2026-05-22; cross-check pass 2026-05-25.

**Goal:** Ship workspace-init v0.1.0 as a skill-first plugin: 2 gerund-named auto-invocable skills + 2 thin `$ARGUMENTS` slash command wrappers, bash bookkeeping in `lib/` (manifest read/write/resolve, transactional rollback, hook install), a `commit-msg` hook template with baked AI workspace path, and ~123 tests across 9 suites.

**Architecture:** Per SPEC §5, primary surface is SKILL.md bodies Claude reads + executes (skill-first per Pass D). Bash in `lib/` is reserved for bookkeeping: JSON manifest manipulation, transactional init-log + rollback, commit-msg hook rendering with baked per-repo paths, and `git symbolic-ref` fallback chain for default-branch detection. Slash commands (`/init-workspace`, `/pair-workspace`) are thin wrappers using the `$ARGUMENTS` env-var bridge.

**Tech Stack:** Bash 3.2+ (macOS-portable), `jq`, `git`, Claude Code skill + command layers. No SessionStart hook (run-once plugin).

**Branch:** `implementation-workspace-init-v01`

**Commit format:** `workspace-init: <description> (v0.1 Phase X)` — single line, no co-author trailer (the plugin's own trace filter would block it).

**Final PLAN destination:** `docs/PLAN-workspace-init.md` (matches `docs/PLAN-claude-security-audit.md` / `docs/PLAN-architect-critic-v02.md` repo convention). This plan file (`.claude/plans/...`) is the plan-mode draft; copy to `docs/` on entry to Pre-flight.

---

## Implementation Status

Filled in as phases close. Each row pins Phase | Status | Cumulative test count | Commit SHA | Notes.

| Phase | Status | Tests (cumulative) | Commit SHA | Notes |
|---|---|---|---|---|
| Pre-flight | pending | 0 | — | branch + plugin.json skeleton |
| 0 — Skills-pressure baseline (RED) | pending | ~10 (all FAIL) | — | per [Phase 0 shape choice: lightweight skills-pressure] |
| 1 — SKILL.md bodies | pending | ~10 (skill-trigger passes; e2e still RED) | — | |
| 2 — examples/ | pending | ~10 | — | |
| 3 — `lib/` utility scripts | pending | ~73 | — | manifest, skeleton, stubs, git-init, rollback, helpers |
| 4 — `commit-msg` hook template | pending | ~93 | — | |
| 5 — Slash command wrappers | pending | ~93 | — | |
| 6 — Pressure-test GREEN-REFACTOR | pending | ~93 | — | re-run Phase 0 scenarios with full plugin |
| 7 — Integration tests | pending | ~123 | — | fresh + pair-with end-to-end |
| 8 — Publish | pending | ~123 | — | v0.1.0 tag, marketplace.json, README, CHANGELOG |

---

## File Structure

Locked before tasks start. Each path lists owner phase.

```
workspace-init/                                # plugin root (created Pre-flight)
├── .claude-plugin/
│   └── plugin.json                            # Pre-flight (skeleton) → Phase 8 (v0.1.0 finalize)
├── skills/
│   ├── initializing-dual-repo-workspace/
│   │   ├── SKILL.md                           # Phase 1
│   │   └── examples/                          # Phase 2
│   │       ├── fresh-bootstrap.md
│   │       └── failure-rollback.md
│   └── pairing-canonical-repo/
│       ├── SKILL.md                           # Phase 1
│       └── examples/                          # Phase 2
│           ├── pair-with-existing-clean.md
│           └── pair-with-aborts-on-ai-scaffolding.md
├── commands/
│   ├── init-workspace.md                      # Phase 5 — thin $ARGUMENTS wrapper
│   └── pair-workspace.md                      # Phase 5
├── lib/
│   ├── _helpers.sh                            # Phase 3 — wi_log_*, wi_lock_*, wi_realpath, wi_guarded_jq_write
│   ├── manifest.sh                            # Phase 3 — write/read/validate; wi_manifest_resolve
│   ├── skeleton.sh                            # Phase 3 — dir creation + .gitkeep + init-log entry
│   ├── stubs.sh                               # Phase 3 — render CLAUDE.md/AGENTS.md/README.md
│   ├── git-init.sh                            # Phase 3 — git init + stage + default-branch fallback
│   ├── trace-filter.sh                        # Phase 3 — render + install commit-msg hook with baked path
│   └── rollback.sh                            # Phase 3 — init-log reader + inverse-op executor
├── hooks/
│   └── commit-msg.tmpl                        # Phase 4 — template per SPEC §7.3
├── templates/                                 # Phase 3 (used by lib/stubs.sh + lib/manifest.sh)
│   ├── pairing.json.tmpl
│   ├── CLAUDE.md.stub.tmpl
│   ├── AGENTS.md.stub.tmpl
│   ├── README.md.tmpl
│   └── gitignore.tmpl
├── tests/
│   ├── _helpers.sh                            # Phase 0 — assertion lib, tempdir, wi_test_run
│   ├── test-skills-pressure.sh                # Phase 0 (RED) → Phase 6 (GREEN) — ~10 tests
│   ├── test-helpers.sh                        # Phase 3 — ~10 tests for lib/_helpers.sh
│   ├── test-manifest.sh                       # Phase 3 — ~25 tests
│   ├── test-skeleton.sh                       # Phase 3 — ~12 tests
│   ├── test-stubs.sh                          # Phase 3 — ~10 tests
│   ├── test-default-branch-fallback.sh        # Phase 3 — ~6 tests
│   ├── test-rollback.sh                       # Phase 3 — ~10 tests
│   ├── test-trace-filter.sh                   # Phase 4 — ~20 tests
│   ├── test-init-fresh.sh                     # Phase 7 — ~15 tests, full bootstrap
│   └── test-pair-with-existing.sh             # Phase 7 — ~15 tests, Scenario A + abort
├── run-tests.sh                               # Phase 7 — runner at plugin root
├── CHANGELOG.md                               # Phase 8
├── LICENSE                                    # Phase 8 (MIT, matches repo)
└── README.md                                  # Phase 8

# Files modified outside workspace-init/:
.claude-plugin/marketplace.json                # Phase 8 — add workspace-init entry (top of chain)
README.md                                      # Phase 8 — plugin table update (5 → 6 plugins)
docs/PLAN-workspace-init.md                    # Pre-flight — copy of this plan
```

**Patterns reused from existing plugins (don't reinvent):**
- `wi_*` function prefix → matches `csa_*` (claude-security-audit), `ac_*` (architect-critic).
- `tests/_helpers.sh` → mirror claude-security-audit's `tests/_helpers.sh` (assertion lib + tempdir + `wi_test_run`).
- `lib/_helpers.sh` logging + atomic JSON write → architect-critic pattern (`ac_log_info`, `ac_guarded_jq_write`, `ac_lock_acquire`/`ac_lock_release`).
- `run-tests.sh` runner → claude-security-audit pattern: discover `tests/test-*.sh`, run via `bash`, count PASS/FAIL.
- Bash 3.2+ macOS portability rules: `shasum -a 256` not `sha256sum`; no `mapfile`; explicit return-code checks instead of `set -e` in hook scripts; `[[ ]]` is fine elsewhere.

---

## Pre-flight

### Task P1: Create implementation branch + copy plan into repo

**Files:**
- Create: `docs/PLAN-workspace-init.md` (copy of this plan file)
- Modify: git refs (branch creation)

- [ ] **Step 1: Create branch from main**

```bash
cd /Volumes/master_ssd/projects/claude-agent-scaffolding
git checkout main && git pull
git checkout -b implementation-workspace-init-v01
```

- [ ] **Step 2: Copy plan into repo at canonical location**

```bash
cp /Users/draco/.claude/plans/docs-spec-workspace-init-md-mossy-dawn.md docs/PLAN-workspace-init.md
```

- [ ] **Step 3: Verify SPEC still present + no other in-flight workspace-init changes**

```bash
test -f docs/SPEC-workspace-init.md || { echo "ABORT: SPEC missing"; exit 1; }
test ! -d workspace-init && echo "OK: greenfield" || echo "ABORT: workspace-init/ already exists"
```

Expected: both lines print `OK: greenfield` and SPEC exists.

- [ ] **Step 4: Commit branch start**

```bash
git add docs/PLAN-workspace-init.md
git commit -m "workspace-init: start v0.1 implementation branch + import PLAN (v0.1 Pre-flight)"
```

### Task P2: Scaffold plugin skeleton + minimal plugin.json

**Files:**
- Create: `workspace-init/.claude-plugin/plugin.json`
- Create: `workspace-init/{skills,commands,lib,hooks,templates,tests}/.gitkeep`

- [ ] **Step 1: Create directory tree**

```bash
mkdir -p workspace-init/.claude-plugin
mkdir -p workspace-init/skills/{initializing-dual-repo-workspace,pairing-canonical-repo}/examples
mkdir -p workspace-init/commands
mkdir -p workspace-init/lib
mkdir -p workspace-init/hooks
mkdir -p workspace-init/templates
mkdir -p workspace-init/tests
touch workspace-init/{skills,commands,lib,hooks,templates,tests}/.gitkeep
```

- [ ] **Step 2: Write minimal `plugin.json` skeleton (pre-v0.1.0)**

Create `workspace-init/.claude-plugin/plugin.json`:

```json
{
  "name": "workspace-init",
  "version": "0.1.0-dev",
  "description": "Bootstrap a dual-repo workspace (AI workspace + canonical) with pairing manifest and AI-trace commit-msg filter.",
  "author": {
    "name": "Praveen Kumar Singh",
    "email": "praveensingh2897@gmail.com"
  },
  "homepage": "https://github.com/draco28/claude-agent-scaffolding/tree/main/workspace-init",
  "repository": "https://github.com/draco28/claude-agent-scaffolding"
}
```

The schema follows the `claude-security-audit` v0.1.1 fix referenced in commit `501c341` (author as object; no skills/commands arrays per Claude Code's plugin manifest schema).

- [ ] **Step 3: Verify directory tree**

```bash
find workspace-init -type d | sort
```

Expected output (exact set, sorted):

```
workspace-init
workspace-init/.claude-plugin
workspace-init/commands
workspace-init/hooks
workspace-init/lib
workspace-init/skills
workspace-init/skills/initializing-dual-repo-workspace
workspace-init/skills/initializing-dual-repo-workspace/examples
workspace-init/skills/pairing-canonical-repo
workspace-init/skills/pairing-canonical-repo/examples
workspace-init/templates
workspace-init/tests
```

- [ ] **Step 4: Commit**

```bash
git add workspace-init/
git commit -m "workspace-init: scaffold plugin directory tree + plugin.json skeleton (v0.1 Pre-flight)"
```

---

## Phase 0 — Skills-pressure baseline (RED)

**Goal:** Per SPEC §12 Phase 0 + §13.1 (skills-pressure shape per user selection). Stand up a `tests/_helpers.sh` + `tests/test-skills-pressure.sh` (~10 tests). All tests FAIL initially (skills don't exist yet); they turn GREEN through Phases 1–5; Phase 6 confirms full GREEN.

**SPEC refs:** §12 Phase 0, §13.1 (test-skills-pressure.sh row, ~10 tests), §13.2 (RED scenario categories), §13.3 (edge cases).

### Task 0.1: Author `tests/_helpers.sh`

**Files:**
- Create: `workspace-init/tests/_helpers.sh`

Mirror claude-security-audit's `tests/_helpers.sh` shape. Pattern reference: `/Volumes/master_ssd/projects/claude-agent-scaffolding/claude-security-audit/tests/_helpers.sh`.

- [ ] **Step 1: Write the helpers file**

Provides: `assert_eq`, `assert_ne`, `assert_contains`, `assert_not_contains`, `assert_file_exists`, `assert_file_absent`, `assert_dir_exists`, `assert_exits_with`, `wi_tmpdir` (with EXIT-trap cleanup), `wi_test_run` (per-function PASS/FAIL printer with counters), `WI_PLUGIN_ROOT` resolution.

```bash
#!/usr/bin/env bash
# tests/_helpers.sh — shared test primitives for workspace-init
# Source from each test file via: source "$(dirname "$0")/_helpers.sh"

set -u  # NOT -e — explicit return-code checks per test

# --- resolve plugin root eagerly ---
WI_PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export WI_PLUGIN_ROOT
export WI_LIB_DIR="$WI_PLUGIN_ROOT/lib"
export WI_TEMPLATES_DIR="$WI_PLUGIN_ROOT/templates"
export WI_HOOKS_DIR="$WI_PLUGIN_ROOT/hooks"

# --- counters ---
WI_TESTS_PASSED=0
WI_TESTS_FAILED=0
WI_TESTS_FAIL_NAMES=()

# --- tempdir with EXIT-trap cleanup ---
wi_tmpdir() {
  local d
  d="$(mktemp -d -t "wi-test-XXXXXX")"
  # Register cleanup in caller's EXIT trap (additive)
  trap 'rm -rf "$d"' EXIT
  echo "$d"
}

# --- assertions ---
assert_eq() { # $1=expected $2=actual $3=desc
  if [[ "$1" == "$2" ]]; then return 0
  else echo "    expected: $1"; echo "    actual:   $2"; return 1
  fi
}
assert_ne() { [[ "$1" != "$2" ]] || { echo "    both equal: $1"; return 1; }; }
assert_contains() { [[ "$2" == *"$1"* ]] || { echo "    expected substring: $1"; echo "    in: $2"; return 1; }; }
assert_not_contains() { [[ "$2" != *"$1"* ]] || { echo "    forbidden substring present: $1"; return 1; }; }
assert_file_exists() { [[ -f "$1" ]] || { echo "    missing file: $1"; return 1; }; }
assert_file_absent() { [[ ! -f "$1" ]] || { echo "    unexpected file: $1"; return 1; }; }
assert_dir_exists() { [[ -d "$1" ]] || { echo "    missing dir: $1"; return 1; }; }
assert_exits_with() { # $1=expected_code $2...=command
  local expected="$1"; shift
  "$@"; local actual=$?
  [[ "$actual" == "$expected" ]] || { echo "    expected exit $expected, got $actual"; return 1; }
}

# --- test runner ---
wi_test_run() { # $1=test_function_name
  local fn="$1"
  if "$fn"; then
    echo "  PASS: $fn"
    WI_TESTS_PASSED=$((WI_TESTS_PASSED + 1))
  else
    echo "  FAIL: $fn"
    WI_TESTS_FAILED=$((WI_TESTS_FAILED + 1))
    WI_TESTS_FAIL_NAMES+=("$fn")
  fi
}

wi_test_summary() {
  echo ""
  echo "== Summary =="
  echo "Passed: $WI_TESTS_PASSED"
  echo "Failed: $WI_TESTS_FAILED"
  if [[ "$WI_TESTS_FAILED" -gt 0 ]]; then
    printf '  - %s\n' "${WI_TESTS_FAIL_NAMES[@]}"
    return 1
  fi
  return 0
}
```

- [ ] **Step 2: Smoke-test the helpers**

```bash
cat > /tmp/wi-smoke.sh <<'EOF'
#!/usr/bin/env bash
source workspace-init/tests/_helpers.sh
test_smoke_pass() { assert_eq "a" "a" "smoke"; }
test_smoke_fail() { assert_eq "a" "b" "smoke"; }
wi_test_run test_smoke_pass
wi_test_run test_smoke_fail
wi_test_summary
EOF
bash /tmp/wi-smoke.sh; echo "exit=$?"
rm /tmp/wi-smoke.sh
```

Expected: `PASS: test_smoke_pass`, `FAIL: test_smoke_fail`, summary `Passed: 1 / Failed: 1`, exit code `1`.

- [ ] **Step 3: Commit**

```bash
git add workspace-init/tests/_helpers.sh
git commit -m "workspace-init: tests/_helpers.sh — assertions, tempdir, test runner (v0.1 Phase 0)"
```

### Task 0.2: Write `tests/test-skills-pressure.sh` (RED baseline)

**Files:**
- Create: `workspace-init/tests/test-skills-pressure.sh`

Per SPEC §13.2 RED categories. ~10 scenarios. Each test dispatches a fresh subagent with a minimal user-shaped prompt (no skill hint) and inspects the resulting filesystem state. All tests FAIL now (no skills, no lib/) and turn GREEN as Phases 1–5 complete; Phase 6 closes loopholes.

- [ ] **Step 1: Author the file**

Structure: each test function (a) creates a wi_tmpdir, (b) writes a tiny subagent-driver script that captures what would-be Claude actions look like via grep-driven simulation OR (where deterministic) directly checks "would the skills' frontmatter description match this user phrase?". Use lightweight simulation since real subagent dispatch is reserved for Phase 6.

Scenarios (one test function each — see SPEC §13.2):

```bash
#!/usr/bin/env bash
# tests/test-skills-pressure.sh — RED baseline for skill-first behavior.
# Phase 0: ALL FAIL (no skills/lib exist).
# Phase 6: ALL PASS after skill bodies + lib/ + commands land.

source "$(dirname "$0")/_helpers.sh"

# --- Helper: does a skill's frontmatter `description` field contain a phrase? ---
# Surrogate for skill auto-invocation: real harness matches user message against description.
skill_description_matches() { # $1=skill_path $2=user_phrase
  local skill_md="$1"
  local phrase="$2"
  [[ -f "$skill_md" ]] || return 1
  # Extract description line(s) from frontmatter
  awk '/^---$/{f=!f; next} f && /^description:/{flag=1} flag{print} /^---$/ && flag{exit}' "$skill_md" \
    | grep -qiF "$phrase"
}

INIT_SKILL="$WI_PLUGIN_ROOT/skills/initializing-dual-repo-workspace/SKILL.md"
PAIR_SKILL="$WI_PLUGIN_ROOT/skills/pairing-canonical-repo/SKILL.md"

# 1. Skill exists at expected path
test_init_skill_file_exists() { assert_file_exists "$INIT_SKILL"; }
test_pair_skill_file_exists() { assert_file_exists "$PAIR_SKILL"; }

# 2. Skill descriptions match the documented natural-language triggers per SPEC §5.1/§5.2
test_init_triggers_on_create_workspace() { skill_description_matches "$INIT_SKILL" "create workspace"; }
test_init_triggers_on_bootstrap_project() { skill_description_matches "$INIT_SKILL" "bootstrap project"; }
test_init_triggers_on_set_up_dual_repo() { skill_description_matches "$INIT_SKILL" "set up dual repo"; }
test_pair_triggers_on_existing_canonical() { skill_description_matches "$PAIR_SKILL" "existing canonical"; }
test_pair_triggers_on_pair_workspace() { skill_description_matches "$PAIR_SKILL" "pair"; }

# 3. Skill body is within the 150–500 line target (SPEC §5.1)
test_init_skill_body_size_in_range() {
  local lines; lines=$(wc -l < "$INIT_SKILL")
  (( lines >= 150 && lines <= 500 )) || { echo "    init SKILL.md: $lines lines"; return 1; }
}
test_pair_skill_body_size_in_range() {
  local lines; lines=$(wc -l < "$PAIR_SKILL")
  (( lines >= 150 && lines <= 500 )) || { echo "    pair SKILL.md: $lines lines"; return 1; }
}

# 4. Slash command wrappers use $ARGUMENTS bridge (per feedback_slash_command_dollar_n_bug)
test_init_command_uses_arguments_bridge() {
  local cmd="$WI_PLUGIN_ROOT/commands/init-workspace.md"
  [[ -f "$cmd" ]] || return 1
  grep -q '\$ARGUMENTS' "$cmd" || return 1
  ! grep -nE '\$[1-9]' "$cmd" | grep -v '\$ARGUMENTS' | grep -v '^[^:]*:#' >/dev/null
}
test_pair_command_uses_arguments_bridge() {
  local cmd="$WI_PLUGIN_ROOT/commands/pair-workspace.md"
  [[ -f "$cmd" ]] || return 1
  grep -q '\$ARGUMENTS' "$cmd" || return 1
  ! grep -nE '\$[1-9]' "$cmd" | grep -v '\$ARGUMENTS' | grep -v '^[^:]*:#' >/dev/null
}

# --- run all ---
wi_test_run test_init_skill_file_exists
wi_test_run test_pair_skill_file_exists
wi_test_run test_init_triggers_on_create_workspace
wi_test_run test_init_triggers_on_bootstrap_project
wi_test_run test_init_triggers_on_set_up_dual_repo
wi_test_run test_pair_triggers_on_existing_canonical
wi_test_run test_pair_triggers_on_pair_workspace
wi_test_run test_init_skill_body_size_in_range
wi_test_run test_pair_skill_body_size_in_range
wi_test_run test_init_command_uses_arguments_bridge
wi_test_run test_pair_command_uses_arguments_bridge

wi_test_summary
```

That's 11 tests (close to the ~10 SPEC §13.1 target).

- [ ] **Step 2: Run and confirm RED baseline**

```bash
bash workspace-init/tests/test-skills-pressure.sh; echo "exit=$?"
```

Expected: all 11 FAIL with messages like `missing file: .../SKILL.md`. Exit code `1`. **This is the RED baseline — do not fix here.**

- [ ] **Step 3: Capture baseline output as evidence**

```bash
bash workspace-init/tests/test-skills-pressure.sh > /tmp/wi-phase0-baseline.txt 2>&1 || true
head -30 /tmp/wi-phase0-baseline.txt
```

Save this to the PR description / phase-close commit body so reviewers see the RED → GREEN transition.

- [ ] **Step 4: Commit Phase 0**

```bash
git add workspace-init/tests/test-skills-pressure.sh
git commit -m "workspace-init: tests/test-skills-pressure.sh — 11 RED-baseline scenarios (v0.1 Phase 0)"
```

Update `Implementation Status` row 0 to ✅ in the local plan: tests=11 (all FAIL), commit SHA, note "RED baseline captured".

---

## Phase 1 — Author SKILL.md bodies

**Goal:** Per SPEC §5.1, §5.2, §12 Phase 1. Write the two skill bodies (≥150, ≤500 lines each) that drive Claude's filesystem actions. Reference `lib/*.sh` helpers that Phase 3 will provide; Phase 1 is the contract.

**SPEC refs:** §5.1, §5.2 (skill frontmatter), §8 (8 pre-onboard tasks the init skill orchestrates), §9 (Scenario A pair-with), §6 (manifest), §7 (git policy + hook).

### Task 1.1: Author `skills/initializing-dual-repo-workspace/SKILL.md`

**Files:**
- Create: `workspace-init/skills/initializing-dual-repo-workspace/SKILL.md`

- [ ] **Step 1: Write SKILL frontmatter exactly per SPEC §5.1**

```markdown
---
name: initializing-dual-repo-workspace
description: Bootstrap a fresh dual-repo workspace — creates a new AI workspace repo (memory bank, specs, agent scaffolding) and a clean canonical repo (production code, zero AI traces) with a pairing manifest. Use when the user wants to start a new project with the dual-repo topology, mentions "create workspace", "bootstrap project", "new AI workspace", "set up dual repo", "init project workspace".
---
```

- [ ] **Step 2: Write the body — section outline**

The body is the procedure Claude follows when this skill auto-invokes. Sections (in order):

1. **Preconditions** — verify `jq` and `git` on PATH; verify parent dir writable; abort with clear message otherwise.
2. **Input collection** — prompt for project name (kebab-case `[a-z0-9-]+`); parent dir (default `cwd`); project_type (personal/work). Cite SPEC §8.1 + §7.1.
3. **Validate** — call `lib/skeleton.sh wi_skeleton_preflight <parent> <name>` to assert: parent writable, target dirs absent, name valid. Abort cleanly on failure (no rollback needed — nothing created yet).
4. **The 8 tasks (SPEC §8)** — execute each, instructing Claude to invoke specific `lib/` helpers. After each task, log to `<ai-workspace>/.workspace/init-log` via `lib/_helpers.sh wi_log_op`. On ANY failure, invoke `lib/rollback.sh wi_rollback <log-path>`.
   - 8.1 Take user input (already done above)
   - 8.2 Create `<parent>/<name>-ai` and `<parent>/<name>` → `lib/skeleton.sh wi_skeleton_create_root_pair`
   - 8.3 Seed AI workspace subdirs + `.gitignore` → `lib/skeleton.sh wi_skeleton_seed_subdirs` + render `templates/gitignore.tmpl`
   - 8.4 Write pairing manifest → `lib/manifest.sh wi_manifest_write` (renders `templates/pairing.json.tmpl`)
   - 8.5 Write `CLAUDE.md` stub → `lib/stubs.sh wi_stub_claude_md`
   - 8.6 Write `AGENTS.md` stub → `lib/stubs.sh wi_stub_agents_md`
   - 8.7 Write `README.md` → `lib/stubs.sh wi_stub_readme`
   - 8.8 Install commit-msg hooks + git init + stage → `lib/git-init.sh wi_git_init_pair` then `lib/trace-filter.sh wi_trace_filter_install` on both repos
5. **Print next-steps** — exact text per SPEC §8.8 final block.
6. **Discipline rules** — DO NOT auto-commit the bootstrap. DO stage-only. DO NOT push. DO NOT modify pair-with's working tree.
7. **Failure handling** — list the 6 failure modes from SPEC §13.3 edge cases + the rollback behavior.

Target: ~250 lines. Each section 30–50 lines.

- [ ] **Step 3: Verify line count in target range**

```bash
wc -l workspace-init/skills/initializing-dual-repo-workspace/SKILL.md
```

Expected: 150 ≤ lines ≤ 500.

- [ ] **Step 4: Re-run test-skills-pressure.sh**

```bash
bash workspace-init/tests/test-skills-pressure.sh
```

Expected: `test_init_skill_file_exists`, `test_init_triggers_on_*`, `test_init_skill_body_size_in_range` now PASS (5 of 11). Pair-skill + command tests still FAIL.

- [ ] **Step 5: Commit**

```bash
git add workspace-init/skills/initializing-dual-repo-workspace/SKILL.md
git commit -m "workspace-init: skills/initializing-dual-repo-workspace/SKILL.md (v0.1 Phase 1)"
```

### Task 1.2: Author `skills/pairing-canonical-repo/SKILL.md`

**Files:**
- Create: `workspace-init/skills/pairing-canonical-repo/SKILL.md`

- [ ] **Step 1: Frontmatter per SPEC §5.2**

```markdown
---
name: pairing-canonical-repo
description: Pair a new AI workspace with an existing canonical repository (Scenario A migration). Creates the sibling AI workspace and writes a manifest pointing at existing canonical. Does NOT modify the existing canonical except for installing the commit-msg hook. Use when user has existing repo without AI scaffolding and wants to add an AI workspace alongside.
---
```

- [ ] **Step 2: Body sections**

1. **Preconditions** — same as init skill.
2. **Input collection** — project name; parent dir; **existing canonical path** (required, absolute).
3. **Validate existing canonical (SPEC §9.4)** — must exist, must be a git repo, must NOT contain AI scaffolding markers: `.claude/memory-bank/`, `MASTER-SPEC.md`, `docs/MASTER-SPEC.md`, `.claude/.onboarding-state.json`. If any present, abort with Scenario B guidance message.
4. **Detect canonical metadata** — invoke `lib/git-init.sh wi_git_detect_default_branch <canonical>` (the SPEC §8.4 fallback chain) and `wi_git_detect_remote`.
5. **Execute 8 tasks (subset)** — same as init skill but:
   - Skip 8.2's canonical mkdir (only mkdir AI workspace)
   - Skip 8.8's canonical `git init` (already a repo)
   - Skip staging in canonical (do nothing in working tree)
   - DO install commit-msg hook in canonical's `.git/hooks/` (the only modification)
6. **Rollback discipline** — never undo ops on existing canonical (SPEC §8.9 step 3). Document exactly which ops are pair-with-safe.
7. **Print next-steps** — variant of SPEC §8.8 message tailored for pair-with.

Target: ~200 lines.

- [ ] **Step 3: Verify line count**

```bash
wc -l workspace-init/skills/pairing-canonical-repo/SKILL.md
```

- [ ] **Step 4: Re-run pressure tests**

```bash
bash workspace-init/tests/test-skills-pressure.sh
```

Expected: 7 of 11 PASS now (all skill-* tests). Only `*_command_uses_arguments_bridge` remain RED (Phase 5).

- [ ] **Step 5: Commit Phase 1**

```bash
git add workspace-init/skills/pairing-canonical-repo/SKILL.md
git commit -m "workspace-init: skills/pairing-canonical-repo/SKILL.md (v0.1 Phase 1)"
```

---

## Phase 2 — Reference sub-docs (examples/)

**Goal:** Per SPEC §12 Phase 2. Add `examples/` to each skill — one level deep, concrete walkthroughs of expected invocations. These are skill-loaded references (not run as tests), so they're prose + code blocks.

**SPEC refs:** §10 (each skill has `examples/` subdir).

### Task 2.1: Write examples for `initializing-dual-repo-workspace`

**Files:**
- Create: `workspace-init/skills/initializing-dual-repo-workspace/examples/fresh-bootstrap.md`
- Create: `workspace-init/skills/initializing-dual-repo-workspace/examples/failure-rollback.md`

- [ ] **Step 1: Author `fresh-bootstrap.md`**

Walk through a `/init-workspace foo` invocation: user inputs at each prompt, exact terminal output Claude prints, final directory tree, final manifest JSON contents (matching SPEC §6.2 v1.0 schema), next-steps block.

- [ ] **Step 2: Author `failure-rollback.md`**

Walk through a simulated failure mid-init (e.g., `mkdir` fails because parent isn't writable mid-stream): show init-log entries up to failure, rollback execution log, final clean state, error message printed to user. Cite SPEC §8.9 rollback semantics.

- [ ] **Step 3: Commit**

```bash
git add workspace-init/skills/initializing-dual-repo-workspace/examples/
git commit -m "workspace-init: examples/ for initializing-dual-repo-workspace (v0.1 Phase 2)"
```

### Task 2.2: Write examples for `pairing-canonical-repo`

**Files:**
- Create: `workspace-init/skills/pairing-canonical-repo/examples/pair-with-existing-clean.md`
- Create: `workspace-init/skills/pairing-canonical-repo/examples/pair-with-aborts-on-ai-scaffolding.md`

- [ ] **Step 1: Author `pair-with-existing-clean.md`**

`/pair-workspace /abs/path/foo` against a clean existing canonical: input prompts, default-branch detection output (showing fallback chain firing), manifest write, hook install in canonical's `.git/hooks/`, canonical working tree unchanged, AI workspace seeded.

- [ ] **Step 2: Author `pair-with-aborts-on-ai-scaffolding.md`**

`/pair-workspace /abs/path/foo` against a canonical that already has `.claude/memory-bank/`: abort message, Scenario B guidance (deferred to v0.2 per SPEC §9.1), manual workaround instructions.

- [ ] **Step 3: Commit Phase 2**

```bash
git add workspace-init/skills/pairing-canonical-repo/examples/
git commit -m "workspace-init: examples/ for pairing-canonical-repo (v0.1 Phase 2)"
```

---

## Phase 3 — `lib/` utility scripts (bookkeeping)

**Goal:** Per SPEC §10 (lib/ module list), §12 Phase 3. Build the bash bookkeeping the skills delegate to. TDD: write tests first per module, then minimal implementation, then commit. Each lib/ module gets its own test file (~5–25 tests).

**SPEC refs:** §6 (manifest schema), §7.3 (hook installation), §8 (8 tasks), §8.4 (default-branch fallback), §8.9 (rollback).

### Task 3.1: `lib/_helpers.sh` — logging, locking, atomic writes, realpath

**Files:**
- Create: `workspace-init/lib/_helpers.sh`
- Create: `workspace-init/tests/test-helpers.sh`

Mirror `architect-critic/lib/_helpers.sh` patterns. Functions to provide:
- `wi_log_info` / `wi_log_warn` / `wi_log_error` — stderr-routed with prefix
- `wi_realpath <path>` — symlink-resolving canonical-path with fallback (no `realpath` on stock macOS bash 3.2)
- `wi_lock_acquire <lockfile>` / `wi_lock_release <lockfile>` — file-based lock with 5×1s retry (per architect-critic pattern)
- `wi_guarded_jq_write <file> <jq-program> [args...]` — atomic write via tmpfile + mv
- `wi_log_op <log-file> <op-spec>` — append an init-log entry (one line, format `OP\tPATH[\tDETAIL]`)
- `wi_render_template <tmpl-path> <out-path> [VAR=val ...]` — env-var substitution into a template

- [ ] **Step 1: Write tests first**

Create `workspace-init/tests/test-helpers.sh` with ~10 tests covering each function. Pattern: tempdir → invoke helper → assert filesystem state.

- [ ] **Step 2: Run tests — confirm RED**

```bash
bash workspace-init/tests/test-helpers.sh; echo "exit=$?"
```

Expected: all FAIL (functions not defined).

- [ ] **Step 3: Implement `lib/_helpers.sh`**

Bash 3.2+ compatible. No `set -e`. Explicit return codes. Doc each function with a one-line `# Purpose:` comment.

- [ ] **Step 4: Run tests — confirm GREEN**

```bash
bash workspace-init/tests/test-helpers.sh; echo "exit=$?"
```

Expected: all PASS. Exit `0`.

- [ ] **Step 5: Commit**

```bash
git add workspace-init/lib/_helpers.sh workspace-init/tests/test-helpers.sh
git commit -m "workspace-init: lib/_helpers.sh + tests (~10 tests) (v0.1 Phase 3)"
```

### Task 3.2: `lib/manifest.sh` — write, read, resolve `${var}` + `${PLUGIN_DATA:<name>}`

**Files:**
- Create: `workspace-init/templates/pairing.json.tmpl`
- Create: `workspace-init/lib/manifest.sh`
- Create: `workspace-init/tests/test-manifest.sh`

Functions:
- `wi_manifest_write <ai-workspace-root> <canonical-root> <project-type> [--git-remote URL] [--default-branch NAME]` — renders template, writes to `<ai-workspace>/.workspace/pairing.json` atomically via `wi_guarded_jq_write`.
- `wi_manifest_read <ai-workspace-root> [<field-jq-path>]` — reads via `jq -r`. Returns full JSON or single field.
- `wi_manifest_resolve <ai-workspace-root> <string-with-vars>` — resolves both `${ai_workspace.root}` / `${canonical.root}` (manifest field refs) and `${PLUGIN_DATA:<plugin-name>}` (plugin-data dir lookup) and `${HOME}` / `${USER}` (env vars). See SPEC §6.3.
- `wi_manifest_validate <ai-workspace-root>` — verify schema_version + required fields present per SPEC §6.4.

**Test target: ~25 tests** per SPEC §13.1. Coverage:
- Schema validation: all required fields present (8 tests, one per required-field group from §6.4 table)
- `${var}` resolution: `${ai_workspace.root}`, `${canonical.root}` (3 tests)
- `${PLUGIN_DATA:<name>}` resolution: existing plugin, nonexistent plugin (returns null + warning per SPEC §13.3), invoking-plugin context (verifies named-form correctness) (4 tests)
- `${HOME}` / `${USER}` standard expansion (2 tests)
- Missing-field handling (3 tests)
- Reader/writer version-skew handling per SPEC §6.5 (3 tests — reader supports `1.0`; reading `2.0` fails clean; writer always emits ship-version)
- Round-trip: write then read returns equivalent JSON (2 tests)

- [ ] **Step 1: Write `templates/pairing.json.tmpl`** per SPEC §6.2 schema v1.0 (literal `${VAR}` substitution points).

- [ ] **Step 2: Write `tests/test-manifest.sh`** — RED baseline (~25 tests).

- [ ] **Step 3: Run tests, confirm RED.**

- [ ] **Step 4a: Discover Claude Code's plugin-data layout (one-time research, blocks Step 4b)**

The resolver's `${PLUGIN_DATA:<name>}` form is per-SPEC §6.3 + risk R5 dependent on Claude Code's layout. Discover the actual convention before writing the resolver — don't guess.

```bash
# Check whether any installed plugin in this repo references CLAUDE_PLUGIN_DATA or similar
grep -RIn 'CLAUDE_PLUGIN_DATA\|plugin_data\|\.local/share/claude' \
  architect-critic/lib/ scaffold-onboard/lib/ claude-security-audit/lib/ 2>/dev/null | head -20

# Inspect environment from inside a Claude Code session (run manually):
#   env | grep -i 'CLAUDE\|PLUGIN'
# Record the discovered path pattern (e.g. ${CLAUDE_PLUGIN_DATA} env var, or ${HOME}/.local/share/claude-code/<name>/).
```

Record the result inline in `lib/manifest.sh` as a comment and as the function `wi_plugin_data_dir <plugin-name>` that returns the per-plugin path. The resolver calls that function.

- [ ] **Step 4b: Implement `lib/manifest.sh`**

The resolver (`wi_manifest_resolve`) is the highest-stakes function — it's the cross-plugin contract per SPEC §6.3. Implementation sketch (replace `wi_plugin_data_dir` body with whatever Step 4a discovered):

```bash
wi_plugin_data_dir() { # $1=plugin-name → echo absolute data dir for that plugin
  local plugin="$1"
  # Layout-specific lookup discovered in Step 4a.
  # If Claude Code exports CLAUDE_PLUGINS_ROOT, use it; otherwise fall back to the discovered convention.
  if [[ -n "${CLAUDE_PLUGINS_ROOT:-}" ]]; then
    echo "${CLAUDE_PLUGINS_ROOT}/${plugin}/data"
  else
    echo "${HOME}/.local/share/claude-code/${plugin}"
  fi
}

wi_manifest_resolve() {
  local ai_root="$1"; local input="$2"
  local manifest="${ai_root}/.workspace/pairing.json"
  [[ -f "$manifest" ]] || { wi_log_error "manifest not found: $manifest"; return 1; }

  local result="$input"
  # Form 1: ${ai_workspace.root}, ${canonical.root}
  local aw_root cn_root
  aw_root="$(jq -r '.ai_workspace.root' "$manifest")"
  cn_root="$(jq -r '.canonical.root' "$manifest")"
  result="${result//\$\{ai_workspace.root\}/$aw_root}"
  result="${result//\$\{canonical.root\}/$cn_root}"
  # Form 2: ${PLUGIN_DATA:<name>}
  while [[ "$result" =~ \$\{PLUGIN_DATA:([a-z0-9-]+)\} ]]; do
    local plugin="${BASH_REMATCH[1]}"
    local data_dir; data_dir="$(wi_plugin_data_dir "$plugin")"
    result="${result//\$\{PLUGIN_DATA:${plugin}\}/$data_dir}"
  done
  # Form 3: ${HOME}, ${USER}, etc. via envsubst-style
  result="${result//\$\{HOME\}/$HOME}"
  result="${result//\$\{USER\}/$USER}"
  echo "$result"
}
```

- [ ] **Step 5: Run tests, confirm GREEN.**

- [ ] **Step 6: Commit**

```bash
git add workspace-init/templates/pairing.json.tmpl workspace-init/lib/manifest.sh workspace-init/tests/test-manifest.sh
git commit -m "workspace-init: lib/manifest.sh + tests (~25 tests) (v0.1 Phase 3)"
```

### Task 3.3: `lib/skeleton.sh` — dir creation + .gitkeep + init-log entries

**Files:**
- Create: `workspace-init/lib/skeleton.sh`
- Create: `workspace-init/templates/gitignore.tmpl`
- Create: `workspace-init/tests/test-skeleton.sh`

Functions:
- `wi_skeleton_preflight <parent> <name> [--pair-with <existing>]` — validate parent writable, name regex, target dirs absent OR pair-with path is git repo. Return 0/1.
- `wi_skeleton_create_root_pair <parent> <name>` — `mkdir <parent>/<name>-ai` and `<parent>/<name>`; log each via `wi_log_op`.
- `wi_skeleton_create_root_ai_only <parent> <name>` — pair-with variant: only mkdir AI workspace.
- `wi_skeleton_seed_subdirs <ai-root>` — create `.workspace/`, `.claude/`, `docs/`, `docs/specs/`, `.superpowers/`, `.archive/`; add `.gitkeep` to each; render `templates/gitignore.tmpl` → `.gitignore`; log each.

Per SPEC §8.3, the `.gitignore` content must include `.workspace/handoffs/` (scaffold-dev requirement).

**Test target: ~12 tests** per SPEC §13.1. Coverage:
- preflight: name regex valid/invalid (3 tests)
- preflight: parent writable/not (2 tests)
- preflight: target absent vs present (2 tests)
- create_root_pair: both dirs created, log entries (1 test)
- create_root_ai_only: only AI workspace created (1 test)
- seed_subdirs: all expected subdirs + .gitkeep + .gitignore (1 test)
- .gitignore contains `.workspace/handoffs/` (1 test, per SPEC §8.3 explicit requirement)
- Idempotency: second invocation doesn't re-log (1 test)

- [ ] **Step 1: Write `templates/gitignore.tmpl`** with SPEC §8.3 content:

```
# Onboarding session state (scaffold-onboard)
.claude/.onboarding-state.json

# Handoff escape valve files — per scaffold-dev §6b (durable per-machine; not synced)
.workspace/handoffs/

# OS-level cruft
.DS_Store
*.swp
```

- [ ] **Step 2: Write tests** (RED).

- [ ] **Step 3: Implement `lib/skeleton.sh`.**

- [ ] **Step 4: Run tests** — confirm GREEN.

- [ ] **Step 5: Commit**

```bash
git add workspace-init/lib/skeleton.sh workspace-init/templates/gitignore.tmpl workspace-init/tests/test-skeleton.sh
git commit -m "workspace-init: lib/skeleton.sh + gitignore.tmpl + tests (~12 tests) (v0.1 Phase 3)"
```

### Task 3.4: `lib/stubs.sh` — render CLAUDE.md, AGENTS.md, README.md

**Files:**
- Create: `workspace-init/templates/CLAUDE.md.stub.tmpl`
- Create: `workspace-init/templates/AGENTS.md.stub.tmpl`
- Create: `workspace-init/templates/README.md.tmpl`
- Create: `workspace-init/lib/stubs.sh`
- Create: `workspace-init/tests/test-stubs.sh`

Functions: `wi_stub_claude_md <ai-root> <project-name>`, `wi_stub_agents_md`, `wi_stub_readme`. Each renders the corresponding template via `wi_render_template` and logs the op.

**Test target: ~10 tests** — one per template's substitution + edge cases (missing var, special chars in project name, etc.).

- [ ] **Step 1: Write templates** with `${PROJECT_NAME}`, `${AI_WORKSPACE_ROOT}`, `${CANONICAL_ROOT}` substitution points.

- [ ] **Step 2: Write tests** (RED).

- [ ] **Step 3: Implement `lib/stubs.sh`.**

- [ ] **Step 4: Confirm GREEN.**

- [ ] **Step 5: Commit**

```bash
git add workspace-init/templates/CLAUDE.md.stub.tmpl workspace-init/templates/AGENTS.md.stub.tmpl workspace-init/templates/README.md.tmpl workspace-init/lib/stubs.sh workspace-init/tests/test-stubs.sh
git commit -m "workspace-init: lib/stubs.sh + 3 stub templates + tests (~10 tests) (v0.1 Phase 3)"
```

### Task 3.5: `lib/git-init.sh` — git init + default-branch fallback chain

**Files:**
- Create: `workspace-init/lib/git-init.sh`
- Create: `workspace-init/tests/test-default-branch-fallback.sh`

Functions:
- `wi_git_init <repo-root>` — `git init` with sensible defaults; log.
- `wi_git_init_pair <ai-root> <canonical-root>` — git init both repos.
- `wi_git_init_ai_only <ai-root>` — pair-with variant.
- `wi_git_detect_default_branch <repo>` — implement exact fallback chain per SPEC §8.4:
  1. `git symbolic-ref refs/remotes/origin/HEAD`
  2. `git symbolic-ref HEAD`
  3. `git branch --show-current`
  4. user prompt (fallback default `main`)
- `wi_git_detect_remote <repo>` — `git remote get-url origin` or null.
- `wi_git_stage_ai_workspace <ai-root>` — `git -C <root> add .` (stages skeleton; does NOT commit).

**Test target: ~6 tests** per SPEC §13.1. Coverage:
- Step 1 succeeds (remote HEAD set) (1 test — uses a local bare repo with `update-ref refs/remotes/origin/HEAD`)
- Step 1 fails, step 2 succeeds (1 test)
- Steps 1+2 fail, step 3 succeeds (1 test — uses `--show-current` on a branch-less HEAD)
- All 3 fail, prompt path triggered (1 test — pipe input)
- All 3 fail, prompt accepts empty → defaults `main` (1 test)
- Custom branch name (`develop`, `master`) survives roundtrip (1 test)

- [ ] **Step 1: Write tests** (RED).

- [ ] **Step 2: Implement `lib/git-init.sh`.**

- [ ] **Step 3: Confirm GREEN.**

- [ ] **Step 4: Commit**

```bash
git add workspace-init/lib/git-init.sh workspace-init/tests/test-default-branch-fallback.sh
git commit -m "workspace-init: lib/git-init.sh + default-branch fallback tests (~6 tests) (v0.1 Phase 3)"
```

### Task 3.6: `lib/trace-filter.sh` — render + install commit-msg hook with baked path

**Files:**
- Create: `workspace-init/lib/trace-filter.sh`

(Note: `hooks/commit-msg.tmpl` itself is authored + tested in Phase 4; `lib/trace-filter.sh` just renders + installs it.)

Functions:
- `wi_trace_filter_render <ai-workspace-root>` — read `hooks/commit-msg.tmpl`, substitute `${AI_WORKSPACE_PATH}` with the absolute path, echo to stdout.
- `wi_trace_filter_install <ai-workspace-root> <target-repo>` — render and write to `<target-repo>/.git/hooks/commit-msg` + `chmod +x`. Log.
- `wi_trace_filter_install_pair <ai-workspace-root> <canonical-root>` — install in both AI workspace and canonical.

No standalone test file for this module — its behavior is tested in `test-trace-filter.sh` (Phase 4) end-to-end via the rendered template, and in `test-init-fresh.sh`/`test-pair-with-existing.sh` (Phase 7).

- [ ] **Step 1: Implement `lib/trace-filter.sh`.**

- [ ] **Step 2: Smoke test manually**

```bash
mkdir -p /tmp/wi-trace-smoke
source workspace-init/lib/_helpers.sh
source workspace-init/lib/trace-filter.sh
# Pre-create the .tmpl manually for the smoke test (Phase 4 will write the real one)
cat > workspace-init/hooks/commit-msg.tmpl <<'EOF'
#!/usr/bin/env bash
# AI_WORKSPACE_PATH placeholder: __AI_WORKSPACE_PATH__
echo "$0 invoked"
EOF
wi_trace_filter_render /abs/path/foo-ai | head -3
rm -rf /tmp/wi-trace-smoke
rm workspace-init/hooks/commit-msg.tmpl  # will be re-authored in Phase 4
```

Expected: rendered output substitutes the path.

- [ ] **Step 3: Commit**

```bash
git add workspace-init/lib/trace-filter.sh
git commit -m "workspace-init: lib/trace-filter.sh — render + install commit-msg hook (v0.1 Phase 3)"
```

### Task 3.7: `lib/rollback.sh` — init-log reader + inverse-op executor

**Files:**
- Create: `workspace-init/lib/rollback.sh`
- Create: `workspace-init/tests/test-rollback.sh`

Functions:
- `wi_rollback <init-log-path> [--pair-with <existing-canonical>]` — read log in reverse, run inverse op per line, skip ops affecting existing canonical when `--pair-with` flag is set (per SPEC §8.9 step 3).

Init-log format (per `wi_log_op` in Task 3.1): `OP\tPATH[\tDETAIL]`. Op-to-inverse table:
- `MKDIR <path>` → `rmdir <path>` (only if empty)
- `WRITE_FILE <path>` → `rm <path>`
- `GIT_INIT <path>` → `rm -rf <path>/.git`
- `HOOK_INSTALL <repo>` → `rm <repo>/.git/hooks/commit-msg`
- `GIT_STAGE <repo>` → no-op (staging is not destructive)

**Test target: ~10 tests** per SPEC §13.1. Coverage:
- Fresh mode: full log → fully reverted (1 test)
- Pair-with: log includes both AI workspace + canonical ops → only AI workspace reverted (1 test)
- Empty log → no-op exit clean (1 test)
- Partial log (only first 3 of 8 tasks executed) → reverts only those 3 (1 test)
- Inverse of MKDIR on non-empty dir → skip + warn (1 test)
- Inverse of WRITE_FILE on already-missing file → idempotent (1 test)
- Hook install inverse: hook file removed but `.git/hooks/` dir kept (1 test)
- GIT_INIT inverse removes `.git/` (1 test)
- Log read in correct REVERSE order (1 test — assert deletion order matches stack semantics)
- User-facing message: "rolled back N ops; M skipped (pair-with safety)" (1 test)

- [ ] **Step 1: Write tests** (RED).

- [ ] **Step 2: Implement `lib/rollback.sh`.**

- [ ] **Step 3: Confirm GREEN.**

- [ ] **Step 4: Commit Phase 3**

```bash
git add workspace-init/lib/rollback.sh workspace-init/tests/test-rollback.sh
git commit -m "workspace-init: lib/rollback.sh + tests (~10 tests) — Phase 3 complete (v0.1 Phase 3)"
```

Update Implementation Status row 3: cumulative tests = 11 (Phase 0) + 10 + 25 + 12 + 10 + 6 + 10 = 84 (close to projected ~73; over-count is fine, target is ~123 total).

---

## Phase 4 — `commit-msg` hook template

**Goal:** Per SPEC §7.3 + §12 Phase 4. Author the hook template and exhaustively test its regex behavior with the ~20 tests per SPEC §13.1.

### Task 4.1: Author `hooks/commit-msg.tmpl`

**Files:**
- Create: `workspace-init/hooks/commit-msg.tmpl`

- [ ] **Step 1: Write the template exactly per SPEC §7.3**

Token: `__AI_WORKSPACE_PATH__` will be substituted by `wi_trace_filter_render`. Content per SPEC §7.3 block — anchored regex patterns, no `set -e`, fail-open on missing manifest, jq with safe-fallback.

```bash
#!/usr/bin/env bash
# workspace-init: commit-msg AI-trace filter (auto-installed)
# DO NOT EDIT — regenerated on workspace-init runs.
# Embedded AI workspace path: __AI_WORKSPACE_PATH__

AI_WORKSPACE_PATH="__AI_WORKSPACE_PATH__"
MANIFEST_PATH="${AI_WORKSPACE_PATH}/.workspace/pairing.json"

commit_msg_file="$1"
if [[ ! -f "$commit_msg_file" ]]; then exit 0; fi

if [[ ! -f "$MANIFEST_PATH" ]]; then
  echo "warning: workspace-init manifest not found at $MANIFEST_PATH; trace filter disabled. Re-run /init-workspace --repair." >&2
  exit 0
fi

enforce="$(jq -r '.git_policy.trace_filter.enforce // false' "$MANIFEST_PATH" 2>/dev/null || echo "false")"
if [[ "$enforce" != "true" ]]; then exit 0; fi

patterns="$(jq -r '.git_policy.trace_filter.blocked_patterns[]?' "$MANIFEST_PATH" 2>/dev/null || true)"
if [[ -z "$patterns" ]]; then exit 0; fi

while IFS= read -r pattern; do
  [[ -z "$pattern" ]] && continue
  if grep -qE "$pattern" "$commit_msg_file"; then
    echo "ERROR: commit message contains blocked AI-trace pattern: $pattern" >&2
    echo "       Edit the message and try again, or run with --no-verify to bypass (not recommended)." >&2
    exit 1
  fi
done <<< "$patterns"

exit 0
```

### Task 4.2: Author `tests/test-trace-filter.sh`

**Files:**
- Create: `workspace-init/tests/test-trace-filter.sh`

**Test target: ~20 tests** per SPEC §13.1. Coverage:

Positive (must block) — 6 tests, one per pattern + variants:
- `Co-Authored-By: Claude` at line start → block
- `Co-Authored-By: Human` at line start → block (broader catch per SPEC §7.3 note)
- `🤖 Generated with` at line start → block
- `<noreply@anthropic.com>` anywhere → block
- `<noreply@openai.com>` anywhere → block
- Multiple patterns in one message → block on first match

Negative (must allow) — 6 tests:
- Plain message "fix: bug" → allow
- Message containing "co-authored-by" mid-line (not anchored start) → allow (anchored pattern)
- Message containing "🤖 Generated with" mid-line → allow (anchored pattern)
- Message documenting the patterns (`docs: document that hook blocks 🤖 Generated with marker`) — allow per SPEC §7.3 note
- Bare email `noreply@anthropic.com` (no angle brackets) → allow (anchored within brackets)
- Empty message body → allow

Edge cases — 8 tests:
- Manifest missing → fail-open + stderr warning (SPEC §7.3 + §13.3) (1)
- Manifest present but `enforce: false` → exit 0 (1)
- Manifest `blocked_patterns: []` empty array → exit 0 (1)
- Manifest malformed JSON → `jq` returns null → exit 0 with no error (1)
- `--no-verify` bypass (verify by hand-running with the flag — actually this can only be tested at git level; mark as integration concern, do a smoke test) (1)
- Multi-line commit message; pattern only on body trailer line → block (1)
- Trailing-whitespace pattern doesn't false-match (1)
- Unicode handling: `🤖` matches both byte-form and grapheme-form (1)

- [ ] **Step 1: Write tests** (RED — hook template not yet rendered/installed in a real `.git/hooks/`; tests render via `lib/trace-filter.sh wi_trace_filter_render` to a tempfile + invoke directly).

- [ ] **Step 2: Run tests** — should PASS since `lib/trace-filter.sh` already exists from Task 3.6 and `hooks/commit-msg.tmpl` was just written.

- [ ] **Step 3: Commit Phase 4**

```bash
git add workspace-init/hooks/commit-msg.tmpl workspace-init/tests/test-trace-filter.sh
git commit -m "workspace-init: hooks/commit-msg.tmpl + tests (~20 tests) (v0.1 Phase 4)"
```

---

## Phase 5 — Slash command wrappers

**Goal:** Per SPEC §5.3 + §12 Phase 5. Thin `$ARGUMENTS` wrappers (per [[feedback_slash_command_dollar_n_bug]]). These exist so explicit invocation works; the skills are the primary surface.

### Task 5.1: `commands/init-workspace.md`

**Files:**
- Create: `workspace-init/commands/init-workspace.md`

- [ ] **Step 1: Author the command**

```markdown
---
description: Bootstrap a fresh dual-repo workspace (AI workspace + canonical). Wraps the initializing-dual-repo-workspace skill.
allowed-tools: ["Read", "Write", "Bash"]
---

Invoke the `initializing-dual-repo-workspace` skill from the workspace-init plugin.

Arguments: $ARGUMENTS

If $ARGUMENTS is non-empty, treat it as the project name and start the bootstrap procedure from SPEC §8.1 with that name. Otherwise, prompt for the project name interactively.

Follow the skill body exactly. Do not skip the 8 pre-onboard tasks. Do not auto-commit (stage only). Print the next-steps message verbatim.
```

The `$ARGUMENTS` env-var bridge survives Claude Code's template-render step (unlike bare `$1`).

- [ ] **Step 2: Re-run skills-pressure tests** — `test_init_command_uses_arguments_bridge` should PASS.

```bash
bash workspace-init/tests/test-skills-pressure.sh
```

Expected: 10 of 11 PASS now (only `test_pair_command_uses_arguments_bridge` still RED).

- [ ] **Step 3: Commit**

```bash
git add workspace-init/commands/init-workspace.md
git commit -m "workspace-init: commands/init-workspace.md (v0.1 Phase 5)"
```

### Task 5.2: `commands/pair-workspace.md`

**Files:**
- Create: `workspace-init/commands/pair-workspace.md`

- [ ] **Step 1: Author the command**

```markdown
---
description: Pair a new AI workspace with an existing canonical repository (Scenario A). Wraps the pairing-canonical-repo skill.
allowed-tools: ["Read", "Write", "Bash"]
---

Invoke the `pairing-canonical-repo` skill from the workspace-init plugin.

Arguments: $ARGUMENTS

If $ARGUMENTS is non-empty, treat it as the absolute path to the existing canonical repository. Otherwise, prompt for the path interactively.

Follow the skill body exactly. Validate per SPEC §9.4 abort conditions before touching anything. Do not modify the existing canonical's working tree — only `.git/hooks/commit-msg`.
```

- [ ] **Step 2: Re-run skills-pressure tests** — expect 11 of 11 PASS.

```bash
bash workspace-init/tests/test-skills-pressure.sh; echo "exit=$?"
```

Expected: exit `0`.

- [ ] **Step 3: Commit Phase 5**

```bash
git add workspace-init/commands/pair-workspace.md
git commit -m "workspace-init: commands/pair-workspace.md — Phase 5 complete (v0.1 Phase 5)"
```

---

## Phase 6 — Pressure-test GREEN-REFACTOR

**Goal:** Per SPEC §12 Phase 6. Re-run Phase 0's skills-pressure scenarios with full plugin in place. Dispatch real subagents (not the lightweight description-matching from Phase 0) and verify the filesystem state they produce.

### Task 6.1: Dispatch end-to-end subagent scenarios

**Files:** none (test execution + verification)

- [ ] **Step 1: Run baseline pressure tests one more time, confirm full GREEN**

```bash
bash workspace-init/tests/test-skills-pressure.sh; echo "exit=$?"
```

Expected: all 11 PASS, exit `0`.

- [ ] **Step 2: Dispatch real subagent for fresh-bootstrap scenario**

From a parent Claude Code session, invoke the Agent tool with: prompt = "set up a dual-repo workspace for project `foo`", `subagent_type=general-purpose`, working dir = a tempdir. Subagent should auto-invoke `initializing-dual-repo-workspace` skill and complete the 8 tasks. After completion, verify filesystem state:

```bash
TMPDIR=$(mktemp -d -t wi-e2e-XXXXXX)
# (subagent runs in $TMPDIR with name=foo)
# After:
test -d $TMPDIR/foo-ai && echo "OK: AI workspace created"
test -d $TMPDIR/foo && echo "OK: canonical created"
test -f $TMPDIR/foo-ai/.workspace/pairing.json && echo "OK: manifest written"
jq -e '.schema_version == "1.0"' $TMPDIR/foo-ai/.workspace/pairing.json
test -f $TMPDIR/foo-ai/.git/hooks/commit-msg && echo "OK: AI hook installed"
test -f $TMPDIR/foo/.git/hooks/commit-msg && echo "OK: canonical hook installed"
# Verify NO auto-commit happened
git -C $TMPDIR/foo-ai log --oneline 2>&1 | grep -q 'does not have any commits yet' && echo "OK: stage-only, no commit"
rm -rf $TMPDIR
```

- [ ] **Step 3: Dispatch pair-with scenario**

Create a fixture canonical via `git init`, then run subagent with "pair an AI workspace with /path/to/fixture-canonical". Verify only `.git/hooks/commit-msg` modified in canonical; AI workspace fully seeded.

- [ ] **Step 4: Dispatch failure-rollback scenario**

Create a parent dir with read-only middle subdir to force mid-init failure. Subagent should rollback all created paths.

- [ ] **Step 5: If any RED found** — fix skill bodies (close loopholes per SPEC §13.2 RED categories). Recommit affected SKILL.md.

- [ ] **Step 6: Commit Phase 6**

```bash
git commit --allow-empty -m "workspace-init: Phase 6 pressure-test passed — skills GREEN end-to-end (v0.1 Phase 6)"
```

---

## Phase 7 — Integration tests + test runner

**Goal:** Per SPEC §12 Phase 7 + §13.1 (`test-init-fresh.sh` ~15 + `test-pair-with-existing.sh` ~15). Replace the lightweight skills-pressure with full filesystem end-to-end tests that drive the bash directly (no subagent in the test loop — those live in Phase 6 manual validation). Add `run-tests.sh` runner.

### Task 7.1: `tests/test-init-fresh.sh` — full fresh-bootstrap end-to-end

**Files:**
- Create: `workspace-init/tests/test-init-fresh.sh`

**Test target: ~15 tests** per SPEC §13.1.

Each test: tempdir → directly invoke the bash bookkeeping pipeline (the same sequence the skill body would orchestrate: `wi_skeleton_preflight` → `wi_skeleton_create_root_pair` → `wi_skeleton_seed_subdirs` → `wi_manifest_write` → `wi_stub_*` → `wi_git_init_pair` → `wi_trace_filter_install_pair` → `wi_git_stage_ai_workspace`) → assert final state.

Coverage:
- Happy path: both dirs created, manifest valid JSON, schema 1.0, all expected paths exist (5 tests)
- Manifest content: routing table complete, git_policy values match user input, default_branch detected (3 tests)
- Hooks: both repos have `.git/hooks/commit-msg` with baked path matching AI workspace abs path; `chmod +x` set (2 tests)
- Staging: AI workspace has `M `/`?? ` entries from `git status --porcelain`; canonical has nothing (1 test)
- No auto-commit: `git log` on both shows zero commits (1 test)
- `.gitignore` content matches SPEC §8.3 verbatim (1 test)
- Personal vs work project_type both pass through to manifest (1 test)
- Failure mode: parent not writable → preflight aborts, no dirs created (1 test)

- [ ] **Step 1: Write tests** (most will PASS since lib/ is built).

- [ ] **Step 2: Run, fix any RED.**

- [ ] **Step 3: Commit**

```bash
git add workspace-init/tests/test-init-fresh.sh
git commit -m "workspace-init: tests/test-init-fresh.sh — full fresh bootstrap e2e (~15 tests) (v0.1 Phase 7)"
```

### Task 7.2: `tests/test-pair-with-existing.sh` — Scenario A end-to-end + abort

**Files:**
- Create: `workspace-init/tests/test-pair-with-existing.sh`

**Test target: ~15 tests** per SPEC §13.1.

Coverage:
- Happy path: existing canonical untouched in working tree; only `.git/hooks/commit-msg` added; AI workspace fully seeded (4 tests)
- Manifest: `canonical.root` points at existing absolute path; `canonical.default_branch` detected; `canonical.git_remote` detected if origin set (3 tests)
- Default-branch fallback: tested via mock git states (already in test-default-branch-fallback; integration coverage here is 1 test asserting full pipeline picks up `develop` correctly)
- Abort conditions (SPEC §9.4) — 5 tests, one per marker:
  - `.claude/memory-bank/` present → abort with Scenario B guidance
  - `MASTER-SPEC.md` at root → abort
  - `docs/MASTER-SPEC.md` → abort
  - `.claude/.onboarding-state.json` → abort
  - Combined: 2+ markers → abort with each named in message
- Abort: AI workspace path does NOT get created on abort (1 test — preflight failure leaves no half-state)
- Abort: existing canonical 100% unchanged after abort, including `.git/hooks/` (1 test — even hook isn't installed if preflight fails)

- [ ] **Step 1: Write tests, fix any RED.**

- [ ] **Step 2: Commit**

```bash
git add workspace-init/tests/test-pair-with-existing.sh
git commit -m "workspace-init: tests/test-pair-with-existing.sh — Scenario A e2e + 5 abort conditions (~15 tests) (v0.1 Phase 7)"
```

### Task 7.3: `run-tests.sh` runner at plugin root

**Files:**
- Create: `workspace-init/run-tests.sh`

Mirror `claude-security-audit/run-tests.sh`: discover `tests/test-*.sh`, run each via `bash`, count PASS/FAIL, exit non-zero on any failure.

- [ ] **Step 1: Write the runner**

```bash
#!/usr/bin/env bash
# run-tests.sh — workspace-init test runner.
# Discovers tests/test-*.sh, runs each, prints aggregate PASS/FAIL.

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PLUGIN_ROOT"

FILES=0
FAILED_FILES=()
TOTAL_PASSED=0
TOTAL_FAILED=0

for t in tests/test-*.sh; do
  FILES=$((FILES + 1))
  echo "=== $t ==="
  if bash "$t"; then
    : # captured in per-file summary
  else
    FAILED_FILES+=("$t")
  fi
  echo ""
done

echo "================================================================"
echo "Test files run: $FILES"
echo "Failed files:   ${#FAILED_FILES[@]}"
if [[ "${#FAILED_FILES[@]}" -gt 0 ]]; then
  printf '  - %s\n' "${FAILED_FILES[@]}"
  exit 1
fi
exit 0
```

- [ ] **Step 2: Run full suite — verify count target ~123**

```bash
chmod +x workspace-init/run-tests.sh
bash workspace-init/run-tests.sh
```

Expected: all 10 test files (`_helpers` isn't a test file; only `test-*.sh`) PASS. Aggregate test count via per-file summaries: roughly `11 + 10 + 25 + 12 + 10 + 6 + 10 + 20 + 15 + 15 = 134`. SPEC §13.1 projected ~123; the +11 surplus is fine (over-count > under-count).

- [ ] **Step 3: Commit Phase 7**

```bash
git add workspace-init/run-tests.sh
git commit -m "workspace-init: run-tests.sh runner — Phase 7 complete, ~134 tests passing (v0.1 Phase 7)"
```

---

## Phase 8 — Publish

**Goal:** Per SPEC §12 Phase 8 + §18 Definition of Done. Bump version, add marketplace entry, update root README, write CHANGELOG, regression-check scaffold-onboard, tag v0.1.0, merge.

### Task 8.1: Finalize `plugin.json` to v0.1.0

**Files:**
- Modify: `workspace-init/.claude-plugin/plugin.json`

- [ ] **Step 1: Bump version**

Change `"version": "0.1.0-dev"` → `"version": "0.1.0"`. Per [[feedback_plugin_version_bump_required]] — version-keyed for `/plugin update`.

- [ ] **Step 2: Verify schema (no `skills`/`commands` arrays — fixed in claude-security-audit v0.1.1 per commit `501c341`)**

```bash
jq -e 'has("skills") or has("commands") | not' workspace-init/.claude-plugin/plugin.json
```

Expected: `true`.

### Task 8.2: Add marketplace entry at TOP of chain

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Read current marketplace.json**

```bash
jq '.plugins | length' .claude-plugin/marketplace.json
```

Expected: `5`.

- [ ] **Step 2: Add workspace-init entry as first element of `plugins[]`**

Use `jq` to prepend (atomic via temp file):

```bash
jq '.plugins = [{
  "name": "workspace-init",
  "version": "0.1.0",
  "description": "Bootstrap a dual-repo workspace (AI workspace + canonical) with pairing manifest and AI-trace commit-msg filter. Run-once plugin; first in the scaffolding chain.",
  "source": "./workspace-init",
  "type": "project"
}] + .plugins' .claude-plugin/marketplace.json > /tmp/mp.json && mv /tmp/mp.json .claude-plugin/marketplace.json
```

- [ ] **Step 3: Verify**

```bash
jq '.plugins | length' .claude-plugin/marketplace.json
jq '.plugins[0].name' .claude-plugin/marketplace.json
```

Expected: `6` and `"workspace-init"`.

### Task 8.3: Update root README plugin table

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Find the plugin table**

```bash
grep -n '| Plugin |' README.md
```

- [ ] **Step 2: Add a row for workspace-init at the top** (or wherever the chain order puts it). Use the description from `plugin.json`. Match existing row format.

### Task 8.4: Write `workspace-init/CHANGELOG.md`

**Files:**
- Create: `workspace-init/CHANGELOG.md`

- [ ] **Step 1: Author CHANGELOG**

```markdown
# Changelog

## 0.1.0 — 2026-XX-XX

Initial release.

### Added
- Skills: `initializing-dual-repo-workspace`, `pairing-canonical-repo` (skill-first per Pass D).
- Slash commands: `/init-workspace`, `/pair-workspace` ($ARGUMENTS bridge).
- `lib/` bookkeeping: manifest read/write/resolve, skeleton, stubs, git-init w/ default-branch fallback, trace-filter hook install, transactional rollback.
- `commit-msg` git hook template with baked AI workspace path (per SPEC §7.3).
- Pairing manifest schema v1.0 at `<ai-workspace>/.workspace/pairing.json`.
- Scenario A migration (`--pair-with <existing-canonical>`).
- ~134 tests across 9 suites.

### Deferred to v0.2 (per SPEC §14)
- Git remotes auto-setup.
- User-global workspace registry.
- Scenario B migration (split existing scaffold-onboard'd single-repo).
- `/repair-workspace` command.
- `core.hooksPath`-based tracked hook (survives clones).
```

### Task 8.5: Regression-check scaffold-onboard's `test-compose.sh`

**Files:** none (test execution)

Per SPEC §18 — scaffold-onboard's existing test-compose.sh STILL PASSES.

- [ ] **Step 1: Run scaffold-onboard's compose test**

```bash
bash scaffold-onboard/tests/test-compose.sh
```

Expected: PASS (no regression). If FAIL, investigate before tagging — scaffold-onboard v0.2 was designed against this manifest contract.

### Task 8.6: Author plugin-level README

**Files:**
- Create: `workspace-init/README.md`

- [ ] **Step 1: Author README**

Sections: what it does, install (`/plugin install workspace-init@claude-agent-scaffolding`), quickstart (`/init-workspace foo` and `/pair-workspace /path/to/existing`), the manifest, the trace filter (and `--no-verify` escape hatch), pointers to SPEC + PLAN + CHANGELOG.

### Task 8.7: Add `LICENSE`

**Files:**
- Create: `workspace-init/LICENSE` (MIT, matches repo)

- [ ] **Step 1: Copy from existing plugin**

```bash
cp claude-security-audit/LICENSE workspace-init/LICENSE
```

### Task 8.8: Tag, merge, publish

- [ ] **Step 1: Final test run**

```bash
bash workspace-init/run-tests.sh && bash scaffold-onboard/tests/test-compose.sh
```

Expected: both exit `0`.

- [ ] **Step 2: Stage + commit Phase 8**

```bash
git add workspace-init/.claude-plugin/plugin.json workspace-init/CHANGELOG.md workspace-init/README.md workspace-init/LICENSE .claude-plugin/marketplace.json README.md
git commit -m "workspace-init: v0.1.0 publish — marketplace entry, README, CHANGELOG (v0.1 Phase 8)"
```

- [ ] **Step 3: Tag**

```bash
git tag -a workspace-init-v0.1.0 -m "workspace-init v0.1.0 — initial release"
```

- [ ] **Step 4: Merge to main**

```bash
git checkout main
git merge --no-ff implementation-workspace-init-v01 -m "Merge workspace-init v0.1.0"
git push origin main --tags
```

- [ ] **Step 5: Verify installable**

```bash
# In a tmpdir with a fresh Claude Code session:
# /plugin install workspace-init@claude-agent-scaffolding
# Then: /init-workspace test-project
# Confirm bootstrap completes per next-steps message.
```

- [ ] **Step 6: Update Implementation Status table** — mark all 9 rows complete with final commit SHAs.

---

## Verification (end-to-end checklist per SPEC §18)

After Phase 8, confirm Definition of Done:

- [ ] All 8 build phases complete (Pre-flight + 0–8 → 9 phase commits).
- [ ] `bash workspace-init/run-tests.sh` exits `0`, ~134 tests across 9+1 suites pass.
- [ ] `workspace-init-v0.1.0` tag pushed to origin.
- [ ] `.claude-plugin/marketplace.json` has 6 plugins; workspace-init is `plugins[0]`.
- [ ] Root `README.md` plugin table includes workspace-init.
- [ ] `bash scaffold-onboard/tests/test-compose.sh` passes (regression check).
- [ ] Installable: `/plugin install workspace-init@claude-agent-scaffolding` in a fresh Claude Code session works.
- [ ] Manual subagent pressure tests from Phase 6 confirm skill auto-invocation on natural phrases ("set up dual-repo workspace for foo", "pair an AI workspace with /path/to/foo").
- [ ] Manifest validates against schema v1.0 (§6.2) — `jq` checks all required fields present.
- [ ] `commit-msg` hook blocks all 4 anchored patterns (§7.3) and allows the 4 documented non-match cases.
- [ ] Rollback semantics verified: fresh-mode reverts everything; pair-with mode leaves existing canonical untouched (§8.9).

## Notes on cross-plugin contracts

This plugin's manifest is the integration surface for every downstream plugin. After v0.1.0 ships, three things in-flight will exercise it:

1. **scaffold-onboard v0.2.0 (already shipped 2026-05-25)** reads the manifest for routing decisions. If it's running today against single-repo fallback, that's the v0.1.0 behavior preserved per SPEC §11.1. v0.2's manifest-aware mode goes live the moment workspace-init writes a manifest in cwd's parent.
2. **scaffold-dev v0.1** (SPEC at `docs/SPEC-scaffold-dev.md`) refuses to start without a manifest — workspace-init shipping is its unblocker.
3. **architect-critic v0.2.0 (already shipped)** treats the manifest as a fast-path optimization; it falls back to standalone discovery if absent.

If the manifest schema needs a v1.1 additive field during execution (like the `routing.roadmap` addition that landed 2026-05-24 per SPEC §17), do it inline as an additive change — no schema_version bump per SPEC §6.5. Note in the iteration log.
