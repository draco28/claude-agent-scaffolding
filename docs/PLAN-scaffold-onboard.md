# scaffold-onboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `scaffold-onboard` plugin per `docs/SPEC-scaffold-onboard.md` — a 10-phase guided `/onboard` flow that authors `MASTER-SPEC.md`, plus deterministic `/scaffold-project` and `/scaffold-docs` derivations, soft-composed with `ai-mentor`, `architect-critic`, and `superpowers`.

**Architecture:** Single Claude Code plugin under `scaffold-onboard/` in this marketplace. Bash orchestration end-to-end (no Python, no MCP server). Six `lib/` modules with single responsibilities. Templates as data. Six bash test suites mirroring `scaffold` v1.0's testing pattern. One SessionStart hook for cross-cutting plugin detection.

**Tech Stack:** Bash 4+ (`set -u`, `[[ ]]`), `sed`/`awk` for template rendering, `jq` for JSON manipulation (state files), plain bash assertions for tests. Templates in markdown + YAML. Source-of-truth file `MASTER-SPEC.md` authored interactively by `/onboard`. **Implementation uses macOS-portable subset:** BSD awk (no gawk `match(...)` 3-arg form — see Portability notes), bash 3.2 (no `declare -A` — parallel indexed arrays instead).

---

## Implementation Status — v0.1.0 SHIPPED 2026-05-14

> All 8 phases complete. This section preserves the final state for archaeology and a v0.2 baseline.

**Release tag:** `scaffold-onboard-v0.1.0` → commit `ab2e99a docs: surface scaffold-onboard in root README (Phase H)` on `main`. Pushed to `https://github.com/draco28/claude-agent-scaffolding`. Installable via `/plugin install scaffold-onboard@claude-agent-scaffolding`.

**Build history:** Feature branch `implementation-scaffold-onboard` (forked from `main` at `7e81c1e`, fast-forward-merged to `main` post-Phase H, then deleted locally). 68 commits total on main since fork point (2 setup + 66 implementation).

**Phase summary:**

| Phase | Status | Tasks | Cumulative tests | Phase-close commit |
|---|---|---|---|---|
| A · plugin scaffold | ✅ done | TA.1–TA.5 + polish | 0 (helpers seeded) | `9913bbf` |
| B · state + parser + render | ✅ done | TB.1–TB.11 | 28 | `6edc8cc` |
| portability backport | ✅ done | (doc edit) | 28 | `936a41d` |
| C · `/onboard` + MASTER-SPEC | ✅ done | TC.1–TC.10 | 46 | `ef1d77e` |
| D · `/scaffold-project` + memory-bank | ✅ done | TD.1–TD.9 + fix | 68 | `33767f7` |
| E · `/scaffold-docs` + governance | ✅ done | TE.1–TE.7 | 91 | `92fb618` |
| F · cross-cutting (compose + hook + critic handshake) | ✅ done | TF.1–TF.9 | 118 | `b9f1c44` |
| G · E2E + polish + hardening | ✅ done | TG.1–TG.6 (incl. 3 hardening commits) | 163 | `4bdef92` |
| H · v0.1.0 publish | ✅ done | TH.1–TH.3 | 163 | `ab2e99a` (release tip) |

**Final test status — 163 passed across 7 bash suites (~16s full regression):**

```
test-state.sh        23 passed, 0 failed
test-parser.sh       13 passed, 0 failed
test-render.sh       10 passed, 0 failed
test-memory-bank.sh  22 passed, 0 failed
test-docs.sh         23 passed, 0 failed
test-compose.sh      31 passed, 0 failed
test-e2e.sh          41 passed, 0 failed
                   ───────────────────
                    163 passed
```

**What's shipped end-to-end:**
- Full onboarding pipeline: `/onboard` runs the 10-phase 56-question conversation (54-question runtime path), authors `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md`, persists state atomically with lock-file refusal.
- Deterministic derivation: `/scaffold-project` writes 11 memory-bank files (9 derived + 2 live seeded + 1 static WORKFLOW), `CLAUDE.md` with Tier 0 preload + branch routing + plugin-awareness `{{#if has_ai_mentor}}` / `{{#if has_architect_critic}}` / `{{#if has_superpowers}}` blocks, and `.claude/settings.json`.
- Governance docs: `/scaffold-docs [--full] [--regenerate]` writes 5 default docs or 14 with `--full` (3 LLM-gated by Phase 9.3.1 = "yes").
- Cross-cutting integration (Phase F): `lib/compose.sh` with probe-path detection for `ai-mentor` / `architect-critic` / `superpowers`, `composition.json` caching with user-override toggles preserved across refresh, SessionStart hook (source-aware: refresh on startup/clear, preserve on resume/compact), mentor + brainstorming hint emitters at Phase 5/7, architect-critic file-based handshake per SPEC §8.3.
- Phase G hardening: jq-then-mv writes guarded against partial failure, critic `request_id` seeded with `$$.$RANDOM` entropy, file-lock protection on composition.json via `sf_compose_lock_*` helpers.
- E2E coverage on fresh + existing repos, resume after interruption, cross-cutting composition mocked (TG.1-TG.4); root README + marketplace.json + plugin manifest all wired for publish (TH.1-TH.3).

**Workflow used (subagent-driven development):**
- `superpowers:subagent-driven-development` pattern: one implementer subagent per task (verbatim PLAN body + full context + TDD discipline) → combined spec+quality reviewer subagent (independent Read of PLAN, judges against implementer summary + git diff) → mark complete → next.
- Sonnet model for TDD logic, haiku for reviews and stubs/templates.
- Pure template tasks (TF.9 CHANGELOG, TG.5 README, TH.1-2 inline) handled directly by orchestrator without subagent dispatch.
- 30+ subagent dispatches across Phases F–H of this build, zero reviewer-blocked tasks, zero spec violations.

**Adaptations applied throughout (codified in Portability notes section):**
1. BSD awk `sub()` chains instead of gawk 3-arg `match($0, /…/, arr)` — applied in parser.sh phase-marker extraction, parser.sh subsection-id extraction, render.sh `{{#if}}` block awk script, state.sh phases.yaml reader.
2. bash 3.2 parallel indexed arrays instead of `declare -A` — applied in render.sh's variable map (with `_lookup_var` helper) and the awk-via-ENVIRON pattern for passing var maps into awk.
3. `project_name` derivation parses the prefix-before-em-dash from answer 1.1.1 (with `basename "$PWD"` fallback) — applied in `sf_master_spec_update_phase` (TC.8), `sf_claude_md_generate` (TD.7), and `_docs_args` (TE.4).

**v0.2 candidates (deferred from v0.1):**
- **Architect-critic plugin itself** — scaffold-onboard implements the file-based contract; the counterparty plugin remains to be designed and built. SPEC §9 (Q1–Q5) settles the design intent but `docs/SPEC-architect-critic.md` and `docs/PLAN-architect-critic.md` are not yet authored.
- **Windows support** — currently macOS + Linux only; deferred per SPEC §15.
- **Test parallelization** — full regression at ~16s wall-clock (dominated by compose's 3.2s polling + e2e's 9.8s pipeline runs). Fine for v0.1; may warrant parallelization if v0.2 adds more polling or pipeline tests.

---

## File Structure (locked before tasks)

```
scaffold-onboard/
├── .claude-plugin/plugin.json
├── commands/
│   ├── onboard.md
│   ├── scaffold-project.md
│   └── scaffold-docs.md
├── hooks/hooks.json
├── hooks-handlers/session-start.sh
├── lib/
│   ├── _helpers.sh              # shared bash helpers used by all libs
│   ├── state.sh                 # onboarding-state read/write; lock-file; phase progress
│   ├── parser.sh                # MASTER-SPEC.md parser (phase markers, key-values, subsections)
│   ├── render.sh                # template substitution ({{key}}, {{#if}}, {{#each}})
│   ├── memory-bank.sh           # 11-file derivation
│   ├── docs.sh                  # 5/14 doc derivation
│   └── compose.sh               # cross-cutting plugin detection + critic dispatch
├── templates/
│   ├── onboarding-questions/phases.yaml
│   ├── master-spec/MASTER-SPEC.md.tmpl
│   ├── master-spec/EXECUTIVE-SUMMARY.md.tmpl
│   ├── memory-bank/00-project-brief.md.tmpl
│   ├── memory-bank/01-product-context.md.tmpl
│   ├── memory-bank/02-system-patterns.md.tmpl
│   ├── memory-bank/03-code-patterns.md.tmpl
│   ├── memory-bank/04-tech-context.md.tmpl
│   ├── memory-bank/05-active-context.md.tmpl
│   ├── memory-bank/06-progress.md.tmpl
│   ├── memory-bank/07-constraints.md.tmpl
│   ├── memory-bank/08-governance.md.tmpl
│   ├── memory-bank/index.md.tmpl
│   ├── memory-bank/WORKFLOW.md
│   ├── claude-md/CLAUDE.md.tmpl
│   ├── docs-minimal/PRD.md.tmpl
│   ├── docs-minimal/SRS.md.tmpl
│   ├── docs-minimal/BACKLOG.md.tmpl
│   ├── docs-minimal/PROJECT_PLAN.md.tmpl
│   ├── docs-minimal/adr/0001-record-architecture-decisions.md.tmpl
│   ├── docs-full/RISK_REGISTER.md.tmpl
│   ├── docs-full/THREAT_MODEL.md.tmpl
│   ├── docs-full/TEST_STRATEGY.md.tmpl
│   ├── docs-full/DEFINITION_OF_DONE.md.tmpl
│   ├── docs-full/EVALS_PLAN.md.tmpl
│   ├── docs-full/MODEL_CARD.md.tmpl
│   ├── docs-full/PROMPT_GOVERNANCE.md.tmpl
│   ├── docs-full/CUTOVER_PLAN.md.tmpl
│   ├── docs-full/DEMO_RUNBOOK.md.tmpl
│   └── settings/claude-settings.json.tmpl
├── tests/
│   ├── _helpers.sh               # shared assertion helpers
│   ├── test-parser.sh
│   ├── test-state.sh
│   ├── test-render.sh
│   ├── test-memory-bank.sh
│   ├── test-docs.sh
│   ├── test-compose.sh
│   └── test-e2e.sh
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## Test Infrastructure (shared)

Every test suite sources `tests/_helpers.sh`, which provides:

- `assert_eq <label> <expected> <actual>` — string equality
- `assert_file_exists <path>` — file exists
- `assert_file_missing <path>` — file does not exist
- `assert_file_contains <path> <pattern>` — file content matches regex
- `assert_exit_code <expected_code> <command...>` — command exits with code
- `setup_tmp_repo` — creates an isolated tmp dir, `cd`s into it, runs `git init`
- `cleanup` — registered with `trap` to remove tmp dir

Tests increment `PASS`/`FAIL` counters. At end: print summary; exit non-zero if `FAIL > 0`.

This shared file is implemented in **Task TA.5** below; every later test task assumes it exists.

---

## Portability notes (added 2026-05-12 after Phase B subagent discoveries)

**Target platforms:** macOS *and* Linux. Windows is deferred per `docs/SPEC-scaffold-onboard.md` §3 NG5 (matches sibling plugins `scaffold` and `ai-mentor`).

**Why macOS + Linux is free:** macOS ships BSD awk + bash 3.2 (oldest viable targets). Linux ships gawk + bash 4+ (strict supersets of the macOS subset). Code written against the macOS subset runs unchanged on Linux. Windows would require additional adaptations (jq install, mktemp quirks, line-ending discipline, path handling) — deferred.

Two real-world patterns were discovered during Phase B execution (commits `ec17b14`, `c58c4cf`, `ce93b2b`). They appear again in Phases C–F. **Apply these substitutions wherever the original pattern appears in later task code blocks.**

### Adaptation 1 · BSD awk → portable `sub()` chains

macOS's default awk does **not** support gawk's 3-arg `match($0, /pattern/, arr)`. Use `sub()` chains to peel substrings off the line. Works in both BSD awk and gawk.

**Avoid (gawk-only):**
```awk
match($0, /id=([0-9]+)/, arr)
pid = arr[1]
```

**Use instead (POSIX awk, works on both):**
```awk
line = $0
sub(/^.*id=/, "", line)
sub(/[^0-9].*$/, "", line)
pid = line
```

The general transform: identify the prefix to strip, then the suffix to strip, in two `sub()` calls.

### Adaptation 2 · bash 3.2 → parallel indexed arrays

macOS's default bash is 3.2 (Apple hasn't updated due to GPLv3). It does **not** support `declare -A` associative arrays. Use parallel indexed arrays with a lookup helper. Works in both bash 3.2 and bash 4+.

**Avoid (bash 4-only):**
```bash
declare -A vars=()
vars[$key]="$val"
v="${vars[$k]}"
```

**Use instead (bash 3.2+, works on both):**
```bash
var_keys=()
var_vals=()
var_keys+=("$key")
var_vals+=("$val")

_lookup_var() {
  local needle="$1"
  local i
  for ((i=0; i<${#var_keys[@]}; i++)); do
    if [[ "${var_keys[$i]}" == "$needle" ]]; then
      printf '%s' "${var_vals[$i]}"
      return 0
    fi
  done
  return 1
}
```

### Adaptation 3 · awk associative arrays via `ENVIRON[]`

When awk needs a key→value map, BSD awk has no associative-array literal syntax in `-v`. Pass via env vars and reconstruct in `BEGIN`:

```bash
AWK_KEYS=$(printf '%s\n' "${var_keys[@]}")
AWK_VALS=$(printf '%s\n' "${var_vals[@]}")
AWK_KEYS="$AWK_KEYS" AWK_VALS="$AWK_VALS" awk '
  BEGIN {
    n = split(ENVIRON["AWK_KEYS"], keys, "\n")
    split(ENVIRON["AWK_VALS"], vals, "\n")
    for (i = 1; i <= n; i++) varmap[keys[i]] = vals[i]
  }
  # ... script body uses varmap[key] ...
' input.txt
```

### Where these matter in later phases

| Phase | Task | Pattern in plan code | Adaptation |
|---|---|---|---|
| C | TC.6 (phases.yaml reader) | `match($0, /id: ([0-9]+)/, arr)` | Adaptation 1 |
| C | TC.6 | `match($0, /text: "(.*)"$/, arr)` | Adaptation 1 |
| C | TC.6 | `match($0, /required: (true\|false)/, arr)` | Adaptation 1 |
| D | TD.5 (memory-bank derive) | uses indexed `args=()` already — OK | (none) |
| D | TD.7 (CLAUDE.md generate) | uses indexed `args=()` already — OK | (none) |
| E | TE.4 (docs derive) | uses indexed `args=()` already — OK | (none) |
| F | TF.4 (SessionStart hook) | uses jq only — OK | (none) |

When implementing these tasks, subagents should apply the substitution **before writing the code** rather than discovering at test time. The orchestrator prompt for affected tasks will pre-flag the adaptation explicitly.

---

## Phase A — Plugin scaffold

Skeleton files only — no logic yet. Verifies the plugin manifest loads, directory structure is in place, license + readme exist.

### Task TA.1: Create plugin manifest

**Files:**
- Create: `scaffold-onboard/.claude-plugin/plugin.json`

- [ ] **Step 1: Create directory and write manifest**

```bash
mkdir -p scaffold-onboard/.claude-plugin
```

Write `scaffold-onboard/.claude-plugin/plugin.json`:

```json
{
  "name": "scaffold-onboard",
  "version": "0.1.0",
  "description": "Project onboarding via 10-phase guided conversation. Authors MASTER-SPEC.md as source of truth; derives 11-file memory-bank and 5/14 governance docs. Composes with ai-mentor (cognitive mode) and architect-critic (anti-sycophancy reviews) at Phase 5, Phase 7, and MASTER-SPEC close.",
  "author": { "name": "Pras" },
  "category": "workflow"
}
```

- [ ] **Step 2: Verify JSON is valid**

Run: `jq . scaffold-onboard/.claude-plugin/plugin.json`
Expected: prints the manifest formatted; exits 0.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/.claude-plugin/plugin.json
git commit -m "scaffold-onboard: plugin manifest skeleton (Phase A)"
```

### Task TA.2: Create LICENSE, README skeleton, CHANGELOG

**Files:**
- Create: `scaffold-onboard/LICENSE`
- Create: `scaffold-onboard/README.md`
- Create: `scaffold-onboard/CHANGELOG.md`

- [ ] **Step 1: Copy MIT LICENSE from existing scaffold plugin**

```bash
cp scaffold/LICENSE scaffold-onboard/LICENSE
```

- [ ] **Step 2: Write README.md**

```markdown
# scaffold-onboard

Run-once project onboarding plugin for Claude Code. Walks you through 10 expert-role phases (~54 questions) to author `MASTER-SPEC.md`, then deterministically derives a `.claude/memory-bank/` (11 files), a tiered `CLAUDE.md` session-start router, and 5 (or 14 with `--full`) governance docs.

Composes with `ai-mentor` (cognitive mode), `architect-critic` (anti-sycophancy review), and `superpowers` (visual brainstorming) if installed — but works fully standalone.

## Commands

- `/onboard` — guided 10-phase conversation; produces `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md`
- `/scaffold-project` — derives `.claude/memory-bank/` (11 files) + `CLAUDE.md` from `MASTER-SPEC.md`
- `/scaffold-docs [--full]` — derives `docs/PRD.md`, `SRS.md`, `BACKLOG.md`, `PROJECT_PLAN.md`, `adr/0001-*.md` (`--full` adds 9 more)

## Status

v0.1.0 — design spec at `docs/SPEC-scaffold-onboard.md`; implementation plan at `docs/PLAN-scaffold-onboard.md`.

## Platforms

Linux and macOS. Windows deferred (same as sibling plugins).

## License

MIT — see `LICENSE`.
```

- [ ] **Step 3: Write CHANGELOG.md**

```markdown
# Changelog

All notable changes to scaffold-onboard documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [Unreleased]

### Added
- Plugin scaffold (Phase A of the build sequence).
```

- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/LICENSE scaffold-onboard/README.md scaffold-onboard/CHANGELOG.md
git commit -m "scaffold-onboard: LICENSE + README + CHANGELOG (Phase A)"
```

### Task TA.3: Create empty command stubs

**Files:**
- Create: `scaffold-onboard/commands/onboard.md`
- Create: `scaffold-onboard/commands/scaffold-project.md`
- Create: `scaffold-onboard/commands/scaffold-docs.md`

- [ ] **Step 1: Create commands directory**

```bash
mkdir -p scaffold-onboard/commands
```

- [ ] **Step 2: Write `onboard.md` stub**

```markdown
---
description: Guided 10-phase onboarding conversation that authors MASTER-SPEC.md as source of truth for this project.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

[Stub — implementation in Phase C, Task TC.6]

This command will:
1. Detect mode (new / resume / re-onboard) from onboarding-state.json
2. Walk the user through 10 expert-role phases (~54 questions)
3. Author MASTER-SPEC.md section-by-section
4. Generate EXECUTIVE-SUMMARY.md after Phase 10
5. Invoke architect-critic at Phase 5 recap, Phase 7 recap, and MASTER-SPEC close (if installed)
```

- [ ] **Step 3: Write `scaffold-project.md` stub**

```markdown
---
description: Derive .claude/memory-bank/ (11 files) and CLAUDE.md from MASTER-SPEC.md. Deterministic and idempotent.
argument-hint: "[--force]"
allowed-tools: Bash(bash:*)
---

[Stub — implementation in Phase D, Task TD.10]

This command will:
1. Validate MASTER-SPEC.md exists and parses
2. Re-derive 9 derived memory-bank files (00-04, 07, 08, index)
3. Preserve 2 live files (05, 06) and WORKFLOW.md unless --force
4. Render CLAUDE.md with Tier 0 preload + branch routing
5. Write .claude/settings.json if it doesn't exist
```

- [ ] **Step 4: Write `scaffold-docs.md` stub**

```markdown
---
description: Derive governance docs (PRD, SRS, BACKLOG, PROJECT_PLAN, ADR-0001) from MASTER-SPEC.md. --full adds 9 more.
argument-hint: "[--full] [--regenerate]"
allowed-tools: Bash(bash:*)
---

[Stub — implementation in Phase E, Task TE.7]

This command will:
1. Validate MASTER-SPEC.md exists and parses
2. Render 5 default governance docs (PRD, SRS-lite, BACKLOG, PROJECT_PLAN, adr/0001)
3. With --full, also render 9 more (3 are LLM-project-gated)
4. Preserve existing files unless --regenerate
```

- [ ] **Step 5: Verify files exist**

Run:
```bash
ls scaffold-onboard/commands/
```
Expected: lists `onboard.md`, `scaffold-docs.md`, `scaffold-project.md`.

- [ ] **Step 6: Commit**

```bash
git add scaffold-onboard/commands/
git commit -m "scaffold-onboard: command stubs (Phase A)"
```

### Task TA.4: Create hook + lib skeletons

**Files:**
- Create: `scaffold-onboard/hooks/hooks.json`
- Create: `scaffold-onboard/hooks-handlers/session-start.sh`
- Create: `scaffold-onboard/lib/_helpers.sh`
- Create: `scaffold-onboard/lib/state.sh`
- Create: `scaffold-onboard/lib/parser.sh`
- Create: `scaffold-onboard/lib/render.sh`
- Create: `scaffold-onboard/lib/memory-bank.sh`
- Create: `scaffold-onboard/lib/docs.sh`
- Create: `scaffold-onboard/lib/compose.sh`

- [ ] **Step 1: Create directories**

```bash
mkdir -p scaffold-onboard/hooks scaffold-onboard/hooks-handlers scaffold-onboard/lib
```

- [ ] **Step 2: Write `hooks/hooks.json`**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact|resume",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks-handlers/session-start.sh\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3: Write `hooks-handlers/session-start.sh` stub**

```bash
#!/usr/bin/env bash
# SessionStart hook for scaffold-onboard.
# Phase A: stub only. Implementation in Phase F (Task TF.4).
# Responsibilities: refresh ${CLAUDE_PLUGIN_DATA}/composition.json detecting
# ai-mentor / architect-critic / superpowers; emit additionalContext if
# onboarding is in progress on this repo.

set -u
exit 0
```

```bash
chmod +x scaffold-onboard/hooks-handlers/session-start.sh
```

- [ ] **Step 4: Write `lib/_helpers.sh` (skeleton)**

```bash
#!/usr/bin/env bash
# Shared helpers used by every lib module.
# Phase A: skeleton. Concrete helpers added in Phase B (TB.2).

# Resolve the plugin root from CLAUDE_PLUGIN_ROOT env var, or by walking up
# from this script's location as a fallback (useful in tests).
sf_plugin_root() {
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    echo "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  # Fallback: walk up from this file's location to find .claude-plugin/
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "$d"
}

# Resolve the plugin data directory (writable state).
sf_data_dir() {
  if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    echo "$CLAUDE_PLUGIN_DATA"
    return 0
  fi
  # Fallback for shell-level testing: a temp dir under HOME
  echo "${HOME}/.scaffold-onboard-test-data"
}

# Log levels: info / warn / error. Always to stderr.
sf_log_info() { echo "[scaffold-onboard] $*" >&2; }
sf_log_warn() { echo "[scaffold-onboard:WARN] $*" >&2; }
sf_log_error() { echo "[scaffold-onboard:ERROR] $*" >&2; }
```

- [ ] **Step 5: Write empty `lib/*.sh` stubs for state, parser, render, memory-bank, docs, compose**

For each of `state.sh`, `parser.sh`, `render.sh`, `memory-bank.sh`, `docs.sh`, `compose.sh` write:

```bash
#!/usr/bin/env bash
# scaffold-onboard/lib/<filename>.sh
# Phase A: stub. Implementation arrives in the phase noted in the SPEC §13.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# (functions populated in later phases)
```

Replace `<filename>` with the actual filename per file.

- [ ] **Step 6: Verify directory tree**

Run:
```bash
find scaffold-onboard -maxdepth 3 -type f | sort
```
Expected: lists `.claude-plugin/plugin.json`, 3 commands, `hooks/hooks.json`, 1 hook handler, 7 lib files, `LICENSE`, `README.md`, `CHANGELOG.md`.

- [ ] **Step 7: Commit**

```bash
git add scaffold-onboard/hooks scaffold-onboard/hooks-handlers scaffold-onboard/lib
git commit -m "scaffold-onboard: hooks + lib skeletons (Phase A)"
```

### Task TA.5: Create test helpers

**Files:**
- Create: `scaffold-onboard/tests/_helpers.sh`

- [ ] **Step 1: Create tests directory**

```bash
mkdir -p scaffold-onboard/tests
```

- [ ] **Step 2: Write `tests/_helpers.sh`**

```bash
#!/usr/bin/env bash
# Shared assertion helpers for scaffold-onboard test suites.
# Source from each test-*.sh file; tests use assert_* and tmp-repo helpers.

set -u

PASS=0
FAIL=0
TMP_DIR=""

_color_pass() { printf "\033[32m%s\033[0m" "$1"; }
_color_fail() { printf "\033[31m%s\033[0m" "$1"; }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_file_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') file exists: $path"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file missing: $path"
  fi
}

assert_file_missing() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') file absent: $path"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file unexpectedly present: $path"
  fi
}

assert_file_contains() {
  local path="$1" pattern="$2"
  if [[ ! -e "$path" ]]; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file missing for contains-check: $path"
    return
  fi
  if grep -qE "$pattern" "$path"; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') $path contains /$pattern/"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $path does not contain /$pattern/"
  fi
}

assert_exit_code() {
  local expected="$1"; shift
  local label="exit code $expected for: $*"
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e 2>/dev/null || true
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $label (got $actual)"
  fi
}

setup_tmp_repo() {
  TMP_DIR="$(mktemp -d -t scaffold-onboard-test.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  mkdir -p "$TMP_DIR/repo"
  cd "$TMP_DIR/repo"
  git init -q
  git config user.email "test@example.com"
  git config user.name  "Test"
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

report_results() {
  echo ""
  echo "Results: $(_color_pass "$PASS passed"), $(_color_fail "$FAIL failed")"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}
```

- [ ] **Step 3: Sanity-check helpers by hand**

Run:
```bash
bash -c '
source scaffold-onboard/tests/_helpers.sh
assert_eq "1+1 is 2" "2" "$((1+1))"
assert_eq "string match" "hello" "hello"
report_results
'
```
Expected: prints two `✓` lines and `Results: 2 passed, 0 failed`; exits 0.

- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/tests/_helpers.sh
git commit -m "scaffold-onboard: test helpers (Phase A)"
```

---

## Phase B — Parser + state + render

The load-bearing layer. After Phase B: the plugin can read/write onboarding state, parse `MASTER-SPEC.md`, and render templates.

### Task TB.1: lib/state.sh — state file CRUD

**Files:**
- Modify: `scaffold-onboard/lib/state.sh`
- Create: `scaffold-onboard/tests/test-state.sh`

- [ ] **Step 1: Write failing test for state init**

Write `scaffold-onboard/tests/test-state.sh`:

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"

test_state_init() {
  echo "test_state_init:"
  setup_tmp_repo
  sf_state_init
  assert_file_exists "$(sf_state_path)"
  assert_file_contains "$(sf_state_path)" '"status": "in_progress"'
  assert_file_contains "$(sf_state_path)" '"current_phase": 1'
}

test_state_init
report_results
```

- [ ] **Step 2: Run test, see it fail**

Run: `bash scaffold-onboard/tests/test-state.sh`
Expected: FAIL — `sf_state_init: command not found`.

- [ ] **Step 3: Implement `sf_state_path` and `sf_state_init`**

Replace `scaffold-onboard/lib/state.sh` with:

```bash
#!/usr/bin/env bash
# scaffold-onboard/lib/state.sh
# Onboarding state CRUD. State file lives at $(sf_data_dir)/onboarding-state.json.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

sf_state_path() {
  echo "$(sf_data_dir)/onboarding-state.json"
}

sf_state_init() {
  local path
  path="$(sf_state_path)"
  mkdir -p "$(dirname "$path")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat > "$path" <<JSON
{
  "status": "in_progress",
  "current_phase": 1,
  "current_question": null,
  "project_class": null,
  "created_at": "$now",
  "updated_at": "$now",
  "answers": {}
}
JSON
}
```

- [ ] **Step 4: Run test, see it pass**

Run: `bash scaffold-onboard/tests/test-state.sh`
Expected: 3 `✓` lines, `Results: 3 passed, 0 failed`, exits 0.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-state.sh
git commit -m "scaffold-onboard: state init + sf_state_path (Phase B)"
```

### Task TB.2: state.sh — atomic write and read helpers

**Files:**
- Modify: `scaffold-onboard/lib/state.sh`
- Modify: `scaffold-onboard/tests/test-state.sh`

- [ ] **Step 1: Add failing tests for `sf_state_write_atomic` and `sf_state_read_field`**

Append to `tests/test-state.sh` before `report_results`:

```bash
test_state_atomic_write() {
  echo "test_state_atomic_write:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic 'current_phase' 5
  local val
  val="$(sf_state_read_field current_phase)"
  assert_eq "current_phase after write" "5" "$val"
}

test_state_read_missing_field() {
  echo "test_state_read_missing_field:"
  setup_tmp_repo
  sf_state_init
  local val
  val="$(sf_state_read_field nonexistent_key)"
  assert_eq "missing field reads as null" "null" "$val"
}

test_state_atomic_write
test_state_read_missing_field
```

- [ ] **Step 2: Run test, see new tests fail**

Run: `bash scaffold-onboard/tests/test-state.sh`
Expected: first 3 pass; new tests FAIL with `sf_state_write_atomic: command not found`.

- [ ] **Step 3: Implement atomic write and field read**

Append to `lib/state.sh`:

```bash
# Read a top-level field from the state file. Returns "null" if missing.
sf_state_read_field() {
  local key="$1"
  local path
  path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "null"
    return 0
  fi
  jq -r --arg k "$key" '.[$k] // "null"' "$path"
}

# Write a top-level field atomically: jq writes to tmp, then mv.
# Treats numeric strings as numbers; anything else as a JSON string.
sf_state_write_atomic() {
  local key="$1" value="$2"
  local path
  path="$(sf_state_path)"
  local tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Detect numeric value (integer only)
  if [[ "$value" =~ ^-?[0-9]+$ ]]; then
    jq --arg k "$key" --argjson v "$value" --arg now "$now" \
      '.[$k] = $v | .updated_at = $now' "$path" > "$tmp"
  else
    jq --arg k "$key" --arg v "$value" --arg now "$now" \
      '.[$k] = $v | .updated_at = $now' "$path" > "$tmp"
  fi
  mv "$tmp" "$path"
}
```

- [ ] **Step 4: Run all tests, see them pass**

Run: `bash scaffold-onboard/tests/test-state.sh`
Expected: 5 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-state.sh
git commit -m "scaffold-onboard: state atomic write + field read (Phase B)"
```

### Task TB.3: state.sh — nested answer write/read

**Files:**
- Modify: `scaffold-onboard/lib/state.sh`
- Modify: `scaffold-onboard/tests/test-state.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-state.sh` before `report_results`:

```bash
test_answer_write_read() {
  echo "test_answer_write_read:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "todo-cli — a fast task manager"
  local val
  val="$(sf_state_read_answer 1.1.1)"
  assert_eq "answer round-trip" "todo-cli — a fast task manager" "$val"
}

test_answer_with_special_chars() {
  echo "test_answer_with_special_chars:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.2.2" 'A "quoted" value with $special chars'
  local val
  val="$(sf_state_read_answer 1.2.2)"
  assert_eq "special chars preserved" 'A "quoted" value with $special chars' "$val"
}

test_answer_write_read
test_answer_with_special_chars
```

- [ ] **Step 2: Run, see them fail**

Run: `bash scaffold-onboard/tests/test-state.sh`
Expected: 5 prior pass; new 2 fail (`sf_state_write_answer: command not found`).

- [ ] **Step 3: Implement answer write/read**

Append to `lib/state.sh`:

```bash
# Write an answer to state.answers["<question_id>"]. value is treated as a
# raw string; jq handles escaping.
sf_state_write_answer() {
  local qid="$1" value="$2"
  local path
  path="$(sf_state_path)"
  local tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg q "$qid" --arg v "$value" --arg now "$now" \
    '.answers[$q] = $v | .updated_at = $now' "$path" > "$tmp"
  mv "$tmp" "$path"
}

# Read state.answers["<question_id>"]. Returns "null" if absent.
sf_state_read_answer() {
  local qid="$1"
  local path
  path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "null"
    return 0
  fi
  jq -r --arg q "$qid" '.answers[$q] // "null"' "$path"
}
```

- [ ] **Step 4: Run, all pass**

Run: `bash scaffold-onboard/tests/test-state.sh`
Expected: 7 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-state.sh
git commit -m "scaffold-onboard: answer write/read (Phase B)"
```

### Task TB.4: state.sh — lock file for concurrent-session refusal

**Files:**
- Modify: `scaffold-onboard/lib/state.sh`
- Modify: `scaffold-onboard/tests/test-state.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-state.sh` before `report_results`:

```bash
test_lock_acquire_release() {
  echo "test_lock_acquire_release:"
  setup_tmp_repo
  sf_state_init
  sf_state_lock_acquire
  assert_file_exists "$(sf_state_lock_path)"
  sf_state_lock_release
  assert_file_missing "$(sf_state_lock_path)"
}

test_lock_refusal() {
  echo "test_lock_refusal:"
  setup_tmp_repo
  sf_state_init
  sf_state_lock_acquire
  local ec
  set +e
  sf_state_lock_acquire 2>/dev/null
  ec=$?
  set -e 2>/dev/null || true
  assert_eq "second acquire exits non-zero" "1" "$ec"
  sf_state_lock_release
}

test_lock_acquire_release
test_lock_refusal
```

- [ ] **Step 2: Run, see failures**

Run: `bash scaffold-onboard/tests/test-state.sh`
Expected: 7 pass; 4 lock tests fail.

- [ ] **Step 3: Implement lock helpers**

Append to `lib/state.sh`:

```bash
sf_state_lock_path() {
  echo "$(sf_data_dir)/onboarding.lock"
}

# Acquire the onboarding lock. Exits 1 if already held.
# Lock contents: PID + iso-timestamp, for diagnostics.
sf_state_lock_acquire() {
  local path
  path="$(sf_state_lock_path)"
  mkdir -p "$(dirname "$path")"
  # Use noclobber redirection for atomic create-or-fail
  if ( set -o noclobber; echo "$$ $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$path" ) 2>/dev/null; then
    return 0
  else
    sf_log_error "onboarding lock already held: $path ($(cat "$path" 2>/dev/null || echo unknown))"
    return 1
  fi
}

sf_state_lock_release() {
  rm -f "$(sf_state_lock_path)"
}
```

- [ ] **Step 4: Run, all pass**

Run: `bash scaffold-onboard/tests/test-state.sh`
Expected: 11 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-state.sh
git commit -m "scaffold-onboard: lock-file for concurrent-session refusal (Phase B)"
```

### Task TB.5: parser.sh — phase marker extraction

**Files:**
- Modify: `scaffold-onboard/lib/parser.sh`
- Create: `scaffold-onboard/tests/test-parser.sh`

- [ ] **Step 1: Write failing test**

Write `scaffold-onboard/tests/test-parser.sh`:

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/parser.sh"

FIXTURE_DIR="$HERE/fixtures"
mkdir -p "$FIXTURE_DIR"

# Create a minimal MASTER-SPEC.md fixture
write_min_spec() {
  cat > "$1" <<'EOF'
# todo-cli — Master Specification

**Spec version:** 1.0

## Executive Summary

A fast local-first task manager.

<!-- master-spec:phase id=1 name=foundation -->
## Phase 1: Foundation

### 1.3 Project class & MVP
**Project class:** CLI tool

<!-- master-spec:phase id=2 name=strategy -->
## Phase 2: Strategy

Some content.

<!-- master-spec:phase id=3 name=domain -->
## Phase 3: Domain & Data Model

Domain content.
EOF
}

test_phases_present() {
  echo "test_phases_present:"
  local spec="$FIXTURE_DIR/min.md"
  write_min_spec "$spec"
  local phases
  phases="$(sf_spec_phases_present "$spec")"
  assert_eq "phases present" "1 2 3" "$phases"
}

test_phase_extract() {
  echo "test_phase_extract:"
  local spec="$FIXTURE_DIR/min.md"
  write_min_spec "$spec"
  local content
  content="$(sf_spec_phase "$spec" 2)"
  if echo "$content" | grep -q "Some content"; then
    PASS=$((PASS+1)); echo "  ✓ phase 2 contains 'Some content'"
  else
    FAIL=$((FAIL+1)); echo "  ✗ phase 2 missing 'Some content'"
  fi
  if echo "$content" | grep -q "Domain content"; then
    FAIL=$((FAIL+1)); echo "  ✗ phase 2 leaks into phase 3"
  else
    PASS=$((PASS+1)); echo "  ✓ phase 2 stops before phase 3 marker"
  fi
}

test_phases_present
test_phase_extract
report_results
```

- [ ] **Step 2: Run, see failures**

Run: `bash scaffold-onboard/tests/test-parser.sh`
Expected: `sf_spec_phases_present: command not found`.

- [ ] **Step 3: Implement parser primitives**

Replace `lib/parser.sh`:

```bash
#!/usr/bin/env bash
# scaffold-onboard/lib/parser.sh
# MASTER-SPEC.md parser. Three primitives: phase markers, key-value lines,
# subsection headers. Free-text is everything between known anchors.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Returns a space-separated list of phase IDs present in the spec.
sf_spec_phases_present() {
  local path="$1"
  grep -oE '<!-- master-spec:phase id=([0-9]+) name=' "$path" \
    | grep -oE 'id=[0-9]+' \
    | sed 's/id=//' \
    | tr '\n' ' ' \
    | sed 's/ $//'
}

# Print the content of phase N (markdown between marker N and marker N+1, or EOF).
sf_spec_phase() {
  local path="$1" pid="$2"
  awk -v target="$pid" '
    BEGIN { in_phase = 0 }
    /^<!-- master-spec:phase id=[0-9]+ name=.+ -->$/ {
      match($0, /id=([0-9]+)/, arr)
      pid = arr[1]
      if (pid == target) { in_phase = 1; next }
      else if (in_phase) { in_phase = 0 }
    }
    in_phase { print }
  ' "$path"
}
```

- [ ] **Step 4: Run, all pass**

Run: `bash scaffold-onboard/tests/test-parser.sh`
Expected: 3 passed, 0 failed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/parser.sh scaffold-onboard/tests/test-parser.sh
git commit -m "scaffold-onboard: parser phase markers + extraction (Phase B)"
```

### Task TB.6: parser.sh — key-value parsing

**Files:**
- Modify: `scaffold-onboard/lib/parser.sh`
- Modify: `scaffold-onboard/tests/test-parser.sh`

- [ ] **Step 1: Append failing test**

Append to `tests/test-parser.sh` before `report_results`:

```bash
test_kv_parse() {
  echo "test_kv_parse:"
  local spec="$FIXTURE_DIR/min.md"
  write_min_spec "$spec"
  local pclass
  pclass="$(sf_spec_kv "$spec" "Project class")"
  assert_eq "project class enum" "CLI tool" "$pclass"
  local sv
  sv="$(sf_spec_kv "$spec" "Spec version")"
  assert_eq "spec version" "1.0" "$sv"
}

test_kv_parse_missing() {
  echo "test_kv_parse_missing:"
  local spec="$FIXTURE_DIR/min.md"
  write_min_spec "$spec"
  local val
  val="$(sf_spec_kv "$spec" "Nonexistent")"
  assert_eq "missing key" "" "$val"
}

test_project_class_helper() {
  echo "test_project_class_helper:"
  local spec="$FIXTURE_DIR/min.md"
  write_min_spec "$spec"
  local pc
  pc="$(sf_spec_project_class "$spec")"
  assert_eq "project_class helper" "CLI tool" "$pc"
}

test_kv_parse
test_kv_parse_missing
test_project_class_helper
```

- [ ] **Step 2: Run, see failures**

Expected: 3 prior pass; new 4 fail (`sf_spec_kv` not found).

- [ ] **Step 3: Implement KV parser**

Append to `lib/parser.sh`:

```bash
# Read a bold-key colon-value line. Returns empty string if not found.
# Pattern: ^\*\*([\w\s&/-]+):\*\*\s+(.+)$
sf_spec_kv() {
  local path="$1" key="$2"
  # Escape regex specials in key
  local key_re
  key_re="$(printf '%s' "$key" | sed -e 's/[][\\.^$*+?(){}|]/\\&/g')"
  grep -m1 -oE "^\*\*${key_re}:\*\*[[:space:]]+.*$" "$path" 2>/dev/null \
    | sed -E "s/^\*\*${key_re}:\*\*[[:space:]]+//"
}

sf_spec_project_class() {
  sf_spec_kv "$1" "Project class"
}
```

- [ ] **Step 4: Run, all pass**

Expected: 7 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/parser.sh scaffold-onboard/tests/test-parser.sh
git commit -m "scaffold-onboard: parser key-value extraction (Phase B)"
```

### Task TB.7: parser.sh — subsection extraction

**Files:**
- Modify: `scaffold-onboard/lib/parser.sh`
- Modify: `scaffold-onboard/tests/test-parser.sh`

- [ ] **Step 1: Append failing test**

Append to `tests/test-parser.sh`:

```bash
test_subsection_extract() {
  echo "test_subsection_extract:"
  local spec="$FIXTURE_DIR/min.md"
  write_min_spec "$spec"
  local content
  content="$(sf_spec_subsection "$spec" "1.3")"
  if echo "$content" | grep -q "Project class:"; then
    PASS=$((PASS+1)); echo "  ✓ subsection 1.3 found"
  else
    FAIL=$((FAIL+1)); echo "  ✗ subsection 1.3 missing"
  fi
}

test_summary_extract() {
  echo "test_summary_extract:"
  local spec="$FIXTURE_DIR/min.md"
  write_min_spec "$spec"
  local content
  content="$(sf_spec_summary "$spec")"
  if echo "$content" | grep -q "fast local-first"; then
    PASS=$((PASS+1)); echo "  ✓ exec summary found"
  else
    FAIL=$((FAIL+1)); echo "  ✗ exec summary missing"
  fi
}

test_subsection_extract
test_summary_extract
```

- [ ] **Step 2: Run, fail**

Expected: 7 prior pass; 2 new fail.

- [ ] **Step 3: Implement subsection + summary helpers**

Append to `lib/parser.sh`:

```bash
# Print content of subsection `M.N` (### M.N Title) until the next ### or ##.
sf_spec_subsection() {
  local path="$1" sec="$2"
  awk -v target="$sec" '
    BEGIN { in_sec = 0 }
    /^### [0-9]+\.[0-9]+ / {
      match($0, /^### ([0-9]+\.[0-9]+) /, arr)
      sec = arr[1]
      if (sec == target) { in_sec = 1; print; next }
      else if (in_sec) { in_sec = 0 }
    }
    /^## / { if (in_sec) in_sec = 0 }
    in_sec { print }
  ' "$path"
}

# Print content of the executive summary section.
sf_spec_summary() {
  local path="$1"
  awk '
    BEGIN { in_sec = 0 }
    /^## Executive Summary[[:space:]]*$/ { in_sec = 1; next }
    /^## / && !/^## Executive Summary/ { if (in_sec) in_sec = 0 }
    /^---[[:space:]]*$/ { if (in_sec) in_sec = 0 }
    in_sec { print }
  ' "$path"
}
```

- [ ] **Step 4: Run, all pass**

Expected: 9 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/parser.sh scaffold-onboard/tests/test-parser.sh
git commit -m "scaffold-onboard: parser subsection + summary (Phase B)"
```

### Task TB.8: parser.sh — `sf_spec_validate`

**Files:**
- Modify: `scaffold-onboard/lib/parser.sh`
- Modify: `scaffold-onboard/tests/test-parser.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-parser.sh`:

```bash
write_full_spec() {
  cat > "$1" <<'EOF'
# proj — Master Specification

**Spec version:** 1.0

## Executive Summary

Body.

EOF
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    cat >> "$1" <<EOF
<!-- master-spec:phase id=$i name=p$i -->
## Phase $i: Stuff

Content.

EOF
  done
  cat >> "$1" <<'EOF'
### 1.3 Project class & MVP
**Project class:** CLI tool
EOF
}

test_validate_full_ok() {
  echo "test_validate_full_ok:"
  local spec="$FIXTURE_DIR/full.md"
  write_full_spec "$spec"
  assert_exit_code 0 sf_spec_validate "$spec"
}

test_validate_missing_file() {
  echo "test_validate_missing_file:"
  assert_exit_code 1 sf_spec_validate "$FIXTURE_DIR/nonexistent.md"
}

test_validate_missing_phase() {
  echo "test_validate_missing_phase:"
  local spec="$FIXTURE_DIR/missing-phase.md"
  cat > "$spec" <<'EOF'
# proj — Master Specification
## Executive Summary
body
<!-- master-spec:phase id=1 name=p1 -->
## Phase 1: x
### 1.3 Project class & MVP
**Project class:** CLI tool
EOF
  assert_exit_code 1 sf_spec_validate "$spec"
}

test_validate_invalid_project_class() {
  echo "test_validate_invalid_project_class:"
  local spec="$FIXTURE_DIR/bad-pc.md"
  cat > "$spec" <<'EOF'
# proj — Master Specification
## Executive Summary
body
EOF
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    cat >> "$spec" <<EOF
<!-- master-spec:phase id=$i name=p$i -->
## Phase $i: x
EOF
  done
  cat >> "$spec" <<'EOF'
### 1.3 Project class & MVP
**Project class:** Toaster
EOF
  assert_exit_code 1 sf_spec_validate "$spec"
}

test_validate_full_ok
test_validate_missing_file
test_validate_missing_phase
test_validate_invalid_project_class
```

- [ ] **Step 2: Run, see failures**

- [ ] **Step 3: Implement validation**

Append to `lib/parser.sh`:

```bash
# The 9 enum values for project class (spec §6.5)
SF_PROJECT_CLASS_ENUM=(
  "CLI tool" "Library or SDK" "Web app" "Web service (API only)"
  "Mobile app" "ML or AI system" "Agent or plugin" "Data pipeline" "Other"
)

# Validate a MASTER-SPEC.md file. Exit 0 if OK; non-zero with stderr message
# on first ERROR. WARNINGs and INFOs do not block.
sf_spec_validate() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    sf_log_error "MASTER-SPEC.md not found at $path. Run /onboard first."
    return 1
  fi
  if ! head -1 "$path" | grep -qE "^# .+ — Master Specification$"; then
    sf_log_error "Missing top-level '# <name> — Master Specification' heading."
    return 1
  fi
  if ! grep -qE "^## Executive Summary[[:space:]]*$" "$path"; then
    sf_log_error "Missing ## Executive Summary section."
    return 1
  fi
  local phases
  phases="$(sf_spec_phases_present "$path")"
  local missing=""
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if ! echo " $phases " | grep -q " $i "; then
      missing="$missing id=$i"
    fi
  done
  if [[ -n "$missing" ]]; then
    sf_log_error "Missing phase markers:$missing. Phases must be authored via /onboard."
    return 1
  fi
  local pc
  pc="$(sf_spec_project_class "$path")"
  if [[ -z "$pc" ]]; then
    sf_log_error "Project class enum not found. Expected **Project class:** <enum>."
    return 1
  fi
  local known=0 enum
  for enum in "${SF_PROJECT_CLASS_ENUM[@]}"; do
    if [[ "$pc" == "$enum" ]]; then known=1; break; fi
  done
  if [[ "$known" -ne 1 ]]; then
    sf_log_error "Project class '$pc' not in enum. Expected one of: ${SF_PROJECT_CLASS_ENUM[*]}"
    return 1
  fi
  # WARNING-level: spec version
  local sv
  sv="$(sf_spec_kv "$path" "Spec version")"
  if [[ "$sv" != "1.0" ]]; then
    sf_log_warn "Spec version '$sv' unrecognized. Continuing with v1.0 parser."
  fi
  return 0
}
```

- [ ] **Step 4: Run, all pass**

Expected: 13 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/parser.sh scaffold-onboard/tests/test-parser.sh
git commit -m "scaffold-onboard: parser validation (Phase B)"
```

### Task TB.9: render.sh — template substitution

**Files:**
- Modify: `scaffold-onboard/lib/render.sh`
- Create: `scaffold-onboard/tests/test-render.sh`

- [ ] **Step 1: Write failing tests**

Write `tests/test-render.sh`:

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/render.sh"

FIXTURE_DIR="$HERE/fixtures"
mkdir -p "$FIXTURE_DIR"

test_simple_substitution() {
  echo "test_simple_substitution:"
  local tmpl="$FIXTURE_DIR/simple.tmpl"
  echo "Hello, {{name}}! You are {{age}}." > "$tmpl"
  local out
  out="$(sf_render "$tmpl" name=World age=42)"
  assert_eq "simple substitution" "Hello, World! You are 42." "$out"
}

test_missing_var_becomes_todo() {
  echo "test_missing_var_becomes_todo:"
  local tmpl="$FIXTURE_DIR/missing.tmpl"
  echo "Project: {{name}}; Owner: {{owner}}" > "$tmpl"
  local out
  out="$(sf_render "$tmpl" name=foo)"
  if echo "$out" | grep -q "TODO: owner"; then
    PASS=$((PASS+1)); echo "  ✓ missing var rendered as TODO"
  else
    FAIL=$((FAIL+1)); echo "  ✗ missing var not flagged: $out"
  fi
}

test_value_with_spaces() {
  echo "test_value_with_spaces:"
  local tmpl="$FIXTURE_DIR/spaces.tmpl"
  echo "Pitch: {{pitch}}" > "$tmpl"
  local out
  out="$(sf_render "$tmpl" "pitch=todo-cli — a fast local-first task manager.")"
  assert_eq "spaces in value" \
    "Pitch: todo-cli — a fast local-first task manager." \
    "$out"
}

test_simple_substitution
test_missing_var_becomes_todo
test_value_with_spaces
report_results
```

- [ ] **Step 2: Run, fail**

Expected: `sf_render: command not found`.

- [ ] **Step 3: Implement `sf_render`**

Replace `lib/render.sh`:

```bash
#!/usr/bin/env bash
# scaffold-onboard/lib/render.sh
# Template substitution. Grammar: {{key}} for single values. Missing values
# render as TODO: <key>. Block forms ({{#if}}, {{#each}}) added in TB.10.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# sf_render <template_path> key=value key=value ...
# Echoes the rendered template. Missing keys render as "TODO: <key>".
sf_render() {
  local tmpl="$1"; shift
  local content
  content="$(cat "$tmpl")"
  # Build a sed program that substitutes each provided key=value pair.
  # To handle values with sed metacharacters safely we substitute one var at
  # a time using bash string operations rather than sed.
  declare -A vars=()
  local kv key val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    vars[$key]="$val"
  done
  # Replace each {{key}}. Iterate over occurrences via a regex match in bash.
  local result="$content"
  while [[ "$result" =~ \{\{([a-zA-Z0-9_.]+)\}\} ]]; do
    local placeholder="${BASH_REMATCH[0]}"
    local k="${BASH_REMATCH[1]}"
    local v
    if [[ -n "${vars[$k]+x}" ]]; then
      v="${vars[$k]}"
    else
      v="TODO: $k"
    fi
    # Use bash parameter expansion replace-first; loop iterates until none left
    result="${result//$placeholder/$v}"
  done
  printf '%s\n' "$result"
}
```

- [ ] **Step 4: Run, all pass**

Run: `bash scaffold-onboard/tests/test-render.sh`
Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/render.sh scaffold-onboard/tests/test-render.sh
git commit -m "scaffold-onboard: template substitution {{key}} (Phase B)"
```

### Task TB.10: render.sh — `{{#if}}` block and `{{#each}}` block

**Files:**
- Modify: `scaffold-onboard/lib/render.sh`
- Modify: `scaffold-onboard/tests/test-render.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-render.sh`:

```bash
test_if_true() {
  echo "test_if_true:"
  local tmpl="$FIXTURE_DIR/if.tmpl"
  cat > "$tmpl" <<'EOF'
Pre.
{{#if has_llm}}
LLM section here.
{{/if}}
Post.
EOF
  local out
  out="$(sf_render "$tmpl" has_llm=true)"
  if echo "$out" | grep -q "LLM section here"; then
    PASS=$((PASS+1)); echo "  ✓ if-true renders block"
  else
    FAIL=$((FAIL+1)); echo "  ✗ if-true skipped block: $out"
  fi
}

test_if_false() {
  echo "test_if_false:"
  local tmpl="$FIXTURE_DIR/if.tmpl"
  local out
  out="$(sf_render "$tmpl" has_llm=false)"
  if echo "$out" | grep -q "LLM section here"; then
    FAIL=$((FAIL+1)); echo "  ✗ if-false rendered block"
  else
    PASS=$((PASS+1)); echo "  ✓ if-false skipped block"
  fi
}

test_if_true
test_if_false
```

- [ ] **Step 2: Run, fail (blocks render literally)**

- [ ] **Step 3: Implement `{{#if}}` block processing in `sf_render`**

Edit `lib/render.sh`. After the var-substitution loop in `sf_render`, before the `printf` at the end, add:

```bash
  # Process {{#if key}}...{{/if}} blocks. Truthy = exactly "true".
  # After substitution above, {{#if key}} placeholders should have been
  # replaced with "{{#if true}}" or "{{#if false}}" or "{{#if TODO: key}}".
  # But our substitution only replaces {{key}} — not {{#if key}}.
  # So instead, process if-blocks against the vars map directly before
  # var substitution. We need to refactor.
```

Actually, the loop ordering matters. Rewrite `sf_render`:

```bash
sf_render() {
  local tmpl="$1"; shift
  local content
  content="$(cat "$tmpl")"
  declare -A vars=()
  local kv key val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    vars[$key]="$val"
  done

  # Step 1: process {{#if key}}...{{/if}} blocks.
  # Use awk for line-based block tracking.
  local if_processed
  if_processed="$(
    awk -v keys="${!vars[*]}" -v vals="$(for k in "${!vars[@]}"; do printf '%s=%s\n' "$k" "${vars[$k]}"; done)" '
      BEGIN {
        n = split(vals, arr, "\n")
        for (i = 1; i <= n; i++) {
          split(arr[i], kv, "=")
          v[kv[1]] = kv[2]
        }
      }
      /\{\{#if [a-zA-Z0-9_.]+\}\}/ {
        match($0, /\{\{#if ([a-zA-Z0-9_.]+)\}\}/, m)
        in_if = 1
        if_truthy = (v[m[1]] == "true")
        next
      }
      /\{\{\/if\}\}/ { in_if = 0; next }
      { if (!in_if || if_truthy) print }
    ' <<< "$content"
  )"
  content="$if_processed"

  # Step 2: substitute {{key}} placeholders.
  while [[ "$content" =~ \{\{([a-zA-Z0-9_.]+)\}\} ]]; do
    local placeholder="${BASH_REMATCH[0]}"
    local k="${BASH_REMATCH[1]}"
    local v
    if [[ -n "${vars[$k]+x}" ]]; then
      v="${vars[$k]}"
    else
      v="TODO: $k"
    fi
    content="${content//$placeholder/$v}"
  done
  printf '%s\n' "$content"
}
```

- [ ] **Step 4: Run, all pass**

Run: `bash scaffold-onboard/tests/test-render.sh`
Expected: 5 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/render.sh scaffold-onboard/tests/test-render.sh
git commit -m "scaffold-onboard: render {{#if}} blocks (Phase B)"
```

> Note: `{{#each}}` blocks are deferred — no Phase D template uses them in v0.1. Add in v0.2 if needed (tracked in CHANGELOG).

### Task TB.11: Run full Phase B suite

- [ ] **Step 1: Run all Phase B tests**

```bash
for t in scaffold-onboard/tests/test-state.sh scaffold-onboard/tests/test-parser.sh scaffold-onboard/tests/test-render.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```

Expected: each suite reports `Results: N passed, 0 failed` and exits 0. Cumulative target: ~27 tests passing.

- [ ] **Step 2: Tag Phase B complete in CHANGELOG**

Edit `scaffold-onboard/CHANGELOG.md`. Under `## [Unreleased]` / `### Added`, append:

```
- Phase B: lib/state.sh, lib/parser.sh, lib/render.sh implemented with full test coverage. 27 tests passing across 3 suites.
```

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/CHANGELOG.md
git commit -m "scaffold-onboard: Phase B complete — parser + state + render"
```

---

## Phase C — `/onboard` implementation

After Phase C: `/onboard` runs end-to-end on an empty repo, asks all ~54 questions across 10 phases, persists state after every answer, and authors a complete `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md`. Cross-cutting integration (mentor/critic hints) is stubbed; full wiring happens in Phase F.

### Task TC.1: Author `phases.yaml` — the question bank

**Files:**
- Create: `scaffold-onboard/templates/onboarding-questions/phases.yaml`

**Content source:** the canonical question taxonomy is in `docs/SPEC-scaffold-onboarding.md` §5.1.1 (10 phases · ~54 questions · branching rules). The YAML below transcribes that content into a machine-readable schema. **Do not invent questions** — every question's `id`, `text`, and `required`/`gate` metadata must come verbatim from the spec.

- [ ] **Step 1: Create the templates directory**

```bash
mkdir -p scaffold-onboard/templates/onboarding-questions
```

- [ ] **Step 2: Write `phases.yaml` with the schema and full question bank**

The schema (every phase follows it):

```yaml
phases:
  - id: 1
    name: foundation
    title: "Foundation"
    role: "Product Manager"
    subsections:
      - id: "1.1"
        title: "Vision & Problem"
        questions:
          - id: "1.1.1"
            text: "One-sentence elevator pitch: what are you building?"
            required: true
          - id: "1.1.2"
            text: "What problem does this solve, and for whom?"
            required: true
          - id: "1.1.3"
            text: "What does success look like 6 months from launch?"
            required: false
      # ... 1.2, 1.3
  # ... phases 2–10
```

**Question metadata fields:**
- `id` — dotted form `<phase>.<subsection>.<n>` (e.g., `1.3.1`)
- `text` — exact wording from spec §5.1.1
- `required` — boolean; `false` means user can answer "TBD"
- `gate` — optional; bash expression evaluated against state.answers (e.g., `gate: project_class in {Web app, Mobile app}`)
- `enum` — optional; list of valid values for enum-shaped answers (e.g., project class question 1.3.1)

**Full file:** transcribe all 10 phases, all 54 questions from `docs/SPEC-scaffold-onboarding.md` §5.1.1 (lines 162–303). Phase 1's three subsections (1.1, 1.2, 1.3) follow the schema above. Phases 2–10 follow the same pattern with their own subsections and gate rules. The branching gates that matter:

- `1.3.1` (Project class) — enum value drives later gates; `enum: [CLI tool, Library or SDK, Web app, Web service (API only), Mobile app, ML or AI system, Agent or plugin, Data pipeline, Other]`
- Phase 6 — `gate: project_class in {Web app, Mobile app, CLI tool, ML or AI system, Agent or plugin, Other}` selects 4-question UI path; else 2-question DX path (subsections 6A vs 6B)
- Phase 7.2 — `gate: project_class in {Web app, Web service (API only), ML or AI system, Agent or plugin, Data pipeline}` (backend questions)
- Phase 7.3 — `gate: project_class in {Web app, Mobile app}` (frontend questions)
- Phase 7.4 — `gate: project_class == "Library or SDK"` (lib/SDK questions)
- Phase 9.3 — `gate: uses_llm == true` (eval questions, only if user answered yes on 9.3.1)

The final file ends with a validation-aid block:

```yaml
schema_version: "1.0"
expected_phase_count: 10
expected_question_count: 54
```

- [ ] **Step 3: Validate YAML parses**

Run: `python3 -c 'import yaml,sys; yaml.safe_load(open("scaffold-onboard/templates/onboarding-questions/phases.yaml"))'`
Expected: no output (silent success). If parse error, fix the YAML.

> Note: we use Python's `yaml` only for validation here; runtime parsing of phases.yaml in bash uses a focused awk/grep approach (Task TC.8). We never ship a Python dependency.

- [ ] **Step 4: Sanity check phase count**

Run: `grep -cE '^  - id: [0-9]+$' scaffold-onboard/templates/onboarding-questions/phases.yaml`
Expected: `10`.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/templates/onboarding-questions/phases.yaml
git commit -m "scaffold-onboard: phases.yaml — 10 phases, 54 questions (Phase C)"
```

### Task TC.2: Author `MASTER-SPEC.md.tmpl`

**Files:**
- Create: `scaffold-onboard/templates/master-spec/MASTER-SPEC.md.tmpl`

- [ ] **Step 1: Create directory**

```bash
mkdir -p scaffold-onboard/templates/master-spec
```

- [ ] **Step 2: Write the template**

```markdown
# {{project_name}} — Master Specification

> Source-of-truth document produced by `/onboard`.
> Edit freely; downstream commands (`/scaffold-project`, `/scaffold-docs`) re-derive from this file.

**Spec version:** 1.0
**Created:** {{created_date}}
**Last updated:** {{updated_date}}
**Project class:** {{project_class}}

---

## Executive Summary

{{executive_summary}}

---

<!-- master-spec:phase id=1 name=foundation -->
## Phase 1: Foundation

### 1.1 Vision & Problem
**Pitch:** {{phase_1.1.1}}

**Problem:**
{{phase_1.1.2}}

**6-month success:**
{{phase_1.1.3}}

### 1.2 Users & Use cases
**Primary users:**
{{phase_1.2.1}}

**Core use case:**
{{phase_1.2.2}}

### 1.3 Project class & MVP
**Project class:** {{phase_1.3.1}}

**MVP cut:**
{{phase_1.3.2}}

---

<!-- master-spec:phase id=2 name=strategy -->
## Phase 2: Strategy

### 2.1 Timeline & Resources
**Target weeks to MVP:** {{phase_2.1.1}}

**Team size:** {{phase_2.1.2}}

### 2.2 Constraints
**Monthly budget cap:** {{phase_2.2.1}}

**Top 3 risks:**
{{phase_2.2.2}}

### 2.3 Success
**Success metric:**
{{phase_2.3.1}}

---

<!-- master-spec:phase id=3 name=domain -->
## Phase 3: Domain & Data Model

### 3.1 Core entities
**Entities:**
{{phase_3.1.1}}

**Per-entity identity & description:**
{{phase_3.1.2}}

### 3.2 Relationships
**Key relationships:**
{{phase_3.2.1}}

**Aggregates / invariants:**
{{phase_3.2.2}}

### 3.3 Ubiquitous language
**Domain terms:**
{{phase_3.3.1}}

---

<!-- master-spec:phase id=4 name=security -->
## Phase 4: Security & Compliance

### 4.1 Sensitivity
**Sensitive data:** {{phase_4.1.1}}

**Regulated domain:** {{phase_4.1.2}}

### 4.2 Auth & access
**Auth model:** {{phase_4.2.1}}

**Multi-tenant or single-tenant:** {{phase_4.2.2}}

### 4.3 Threat surface
**External attack surface:** {{phase_4.3.1}}

---

<!-- master-spec:phase id=5 name=architecture -->
## Phase 5: Architecture

### 5.1 Shape
**Shape:** {{phase_5.1.1}}

**Async/event-driven boundaries:**
{{phase_5.1.2}}

### 5.2 Tech choices
**Primary language(s):** {{phase_5.2.1}}

**Primary data store(s):** {{phase_5.2.2}}

**External APIs / third-party services:**
{{phase_5.2.3}}

### 5.3 Performance & scale
**Expected scale at 6 months:**
{{phase_5.3.1}}

**Latency targets for hot paths:**
{{phase_5.3.2}}

---

<!-- master-spec:phase id=6 name=ux -->
## Phase 6: UX / Surfaces

{{#if ui_branch}}
### 6A.1 Surfaces
**Surfaces:** {{phase_6A.1.1}}

**Primary user flow:**
{{phase_6A.1.2}}

### 6A.2 Standards
**Accessibility floor:** {{phase_6A.2.1}}

**Design system:** {{phase_6A.2.2}}
{{/if}}
{{#if dx_branch}}
### 6B.1 Developer experience
**Discovery & learning:**
{{phase_6B.1.1}}

**Error and output style:** {{phase_6B.1.2}}
{{/if}}

---

<!-- master-spec:phase id=7 name=implementation -->
## Phase 7: Implementation Approach

### 7.1 Decomposition
**Module / package boundaries:**
{{phase_7.1.1}}

**Code style:** {{phase_7.1.2}}

{{#if backend_branch}}
### 7.2 Backend
**ORM / query builder / raw SQL:** {{phase_7.2.1}}

**API style:** {{phase_7.2.2}}
{{/if}}

{{#if frontend_branch}}
### 7.3 Frontend
**State management:** {{phase_7.3.1}}
{{/if}}

{{#if library_branch}}
### 7.4 Library / SDK
**Public API surface + versioning:**
{{phase_7.4.1}}
{{/if}}

---

<!-- master-spec:phase id=8 name=devops -->
## Phase 8: DevOps & Environments

### 8.1 Local dev
**Required local tooling:**
{{phase_8.1.1}}

**Clone-to-running target time:** {{phase_8.1.2}}

### 8.2 CI/CD
**CI platform:** {{phase_8.2.1}}

**Environments:** {{phase_8.2.2}}

### 8.3 Hosting
**Hosting target:** {{phase_8.3.1}}

---

<!-- master-spec:phase id=9 name=quality -->
## Phase 9: Quality, Testing & Eval

### 9.1 Test pyramid
**Coverage floor for core logic:** {{phase_9.1.1}}

**Test types in scope:** {{phase_9.1.2}}

### 9.2 Quality gates
**Pre-merge gates:**
{{phase_9.2.1}}

{{#if uses_llm}}
### 9.3 Eval
**Uses LLMs / ML models:** {{phase_9.3.1}}

**Eval dimensions:** {{phase_9.3.2}}
{{/if}}

---

<!-- master-spec:phase id=10 name=operations -->
## Phase 10: Operations & Support

### 10.1 Rollout
**Rollout strategy:** {{phase_10.1.1}}

### 10.2 Observability
**Logs / metrics / traces destination:** {{phase_10.2.1}}

**Alerting target:** {{phase_10.2.2}}

### 10.3 Support model
**On-call / response:** {{phase_10.3.1}}

**Deprecation / retirement plan:** {{phase_10.3.2}}

---

<!-- generated by scaffold-onboard v0.1.0 -->
```

- [ ] **Step 3: Verify file exists with non-zero size**

Run: `wc -l scaffold-onboard/templates/master-spec/MASTER-SPEC.md.tmpl`
Expected: > 150 lines.

- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/templates/master-spec/MASTER-SPEC.md.tmpl
git commit -m "scaffold-onboard: MASTER-SPEC.md template (Phase C)"
```

### Task TC.3: Author `EXECUTIVE-SUMMARY.md.tmpl`

**Files:**
- Create: `scaffold-onboard/templates/master-spec/EXECUTIVE-SUMMARY.md.tmpl`

- [ ] **Step 1: Write the template**

```markdown
# {{project_name}} — Executive Summary

{{executive_summary}}

---

**Project class:** {{project_class}}
**Created:** {{created_date}}
**Source:** [MASTER-SPEC.md](./MASTER-SPEC.md)

<!-- generated by scaffold-onboard v0.1.0; this summary is regenerated whenever /onboard re-runs to close. Edit by hand if Claude's synthesis is off; the hand-edited version is preserved on /scaffold-project runs. -->
```

- [ ] **Step 2: Commit**

```bash
git add scaffold-onboard/templates/master-spec/EXECUTIVE-SUMMARY.md.tmpl
git commit -m "scaffold-onboard: EXECUTIVE-SUMMARY.md template (Phase C)"
```

### Task TC.4: `lib/state.sh` — phase advancement + branching gate evaluation

**Files:**
- Modify: `scaffold-onboard/lib/state.sh`
- Modify: `scaffold-onboard/tests/test-state.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-state.sh` before `report_results`:

```bash
test_phase_advance() {
  echo "test_phase_advance:"
  setup_tmp_repo
  sf_state_init
  sf_state_advance_phase
  local p
  p="$(sf_state_read_field current_phase)"
  assert_eq "current_phase after advance" "2" "$p"
}

test_phase_complete_marks_status() {
  echo "test_phase_complete_marks_status:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic current_phase 10
  sf_state_advance_phase
  local status
  status="$(sf_state_read_field status)"
  assert_eq "status after phase 10 advance" "complete" "$status"
}

test_branching_gate_ui() {
  echo "test_branching_gate_ui:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.3.1" "Web app"
  assert_exit_code 0 sf_state_gate_passes "project_class in {Web app, Mobile app}"
}

test_branching_gate_dx() {
  echo "test_branching_gate_dx:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.3.1" "Library or SDK"
  assert_exit_code 1 sf_state_gate_passes "project_class in {Web app, Mobile app}"
}

test_phase_advance
test_phase_complete_marks_status
test_branching_gate_ui
test_branching_gate_dx
```

- [ ] **Step 2: Run, see failures**

Expected: 11 prior pass; 4 new fail (`sf_state_advance_phase: command not found`).

- [ ] **Step 3: Implement phase advance + gate evaluation**

Append to `lib/state.sh`:

```bash
# Advance current_phase by 1. If already at 10, set status=complete instead.
sf_state_advance_phase() {
  local cur
  cur="$(sf_state_read_field current_phase)"
  if [[ "$cur" == "10" ]]; then
    sf_state_write_atomic status complete
  else
    sf_state_write_atomic current_phase "$((cur+1))"
  fi
}

# Evaluate a branching gate expression against current state.answers.
# Supported forms:
#   "project_class == \"Web app\""
#   "project_class in {Web app, Mobile app}"
#   "uses_llm == true"
# Returns 0 if gate passes, 1 if not.
sf_state_gate_passes() {
  local expr="$1"
  # Substitute known variables
  local project_class uses_llm
  project_class="$(sf_state_read_answer 1.3.1)"
  uses_llm="$(sf_state_read_answer 9.3.1)"

  # Form: project_class in {A, B, C}
  if [[ "$expr" =~ ^project_class[[:space:]]+in[[:space:]]+\{(.+)\}$ ]]; then
    local list="${BASH_REMATCH[1]}"
    local IFS=','
    local item
    for item in $list; do
      # trim leading/trailing whitespace
      item="${item#"${item%%[![:space:]]*}"}"
      item="${item%"${item##*[![:space:]]}"}"
      if [[ "$item" == "$project_class" ]]; then
        return 0
      fi
    done
    return 1
  fi

  # Form: project_class == "value"
  if [[ "$expr" =~ ^project_class[[:space:]]+==[[:space:]]+\"(.+)\"$ ]]; then
    [[ "$project_class" == "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  fi

  # Form: uses_llm == true
  if [[ "$expr" =~ ^uses_llm[[:space:]]+==[[:space:]]+(true|false)$ ]]; then
    [[ "$uses_llm" == "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  fi

  sf_log_warn "Unknown gate expression: $expr (defaulting to passes)"
  return 0
}
```

- [ ] **Step 4: Run, all pass**

Expected: 15 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-state.sh
git commit -m "scaffold-onboard: phase advance + branching gates (Phase C)"
```

### Task TC.5: `lib/state.sh` — mode detection (new / resume / re-onboard)

**Files:**
- Modify: `scaffold-onboard/lib/state.sh`
- Modify: `scaffold-onboard/tests/test-state.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-state.sh`:

```bash
test_mode_new() {
  echo "test_mode_new:"
  setup_tmp_repo
  rm -f "$(sf_state_path)"  # ensure no state
  local mode
  mode="$(sf_state_mode)"
  assert_eq "no state -> new" "new" "$mode"
}

test_mode_resume() {
  echo "test_mode_resume:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic current_phase 5
  local mode
  mode="$(sf_state_mode)"
  assert_eq "in_progress -> resume" "resume" "$mode"
}

test_mode_reonboard() {
  echo "test_mode_reonboard:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic status complete
  local mode
  mode="$(sf_state_mode)"
  assert_eq "complete -> reonboard" "reonboard" "$mode"
}

test_mode_new
test_mode_resume
test_mode_reonboard
```

- [ ] **Step 2: Run, fail**

Expected: 15 prior pass; 3 new fail.

- [ ] **Step 3: Implement mode detection**

Append to `lib/state.sh`:

```bash
# Determine the onboarding mode based on state file existence + status.
# Returns one of: new | resume | reonboard
sf_state_mode() {
  local path
  path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "new"
    return 0
  fi
  local status
  status="$(sf_state_read_field status)"
  case "$status" in
    "in_progress") echo "resume" ;;
    "complete")    echo "reonboard" ;;
    *)             echo "new" ;;  # malformed or unrecognized
  esac
}
```

- [ ] **Step 4: Run, all pass**

Expected: 18 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-state.sh
git commit -m "scaffold-onboard: mode detection (new/resume/reonboard) (Phase C)"
```

### Task TC.6: `lib/state.sh` — phases.yaml reader

**Files:**
- Modify: `scaffold-onboard/lib/state.sh`
- Modify: `scaffold-onboard/tests/test-state.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-state.sh`:

```bash
test_phases_yaml_question_ids_for_phase() {
  echo "test_phases_yaml_question_ids_for_phase:"
  setup_tmp_repo
  local pyaml="$(dirname "$0")/../templates/onboarding-questions/phases.yaml"
  local ids
  ids="$(sf_phases_questions_for "$pyaml" 1)"
  if echo "$ids" | grep -q "1.1.1"; then
    PASS=$((PASS+1)); echo "  ✓ phase 1 contains question 1.1.1"
  else
    FAIL=$((FAIL+1)); echo "  ✗ phase 1 missing 1.1.1: $ids"
  fi
}

test_phases_yaml_question_ids_for_phase
```

- [ ] **Step 2: Run, fail**

Expected: `sf_phases_questions_for: command not found`.

- [ ] **Step 3: Implement phases.yaml reader**

Append to `lib/state.sh`:

```bash
# Return all question IDs for phase N from phases.yaml, one per line.
# Uses awk to find the phase block, then extract `id: "M.N.K"` patterns.
sf_phases_questions_for() {
  local yaml="$1" target="$2"
  awk -v target="$target" '
    /^  - id: [0-9]+$/ {
      match($0, /id: ([0-9]+)/, arr)
      cur_phase = arr[1]
      next
    }
    /^      - id: "[0-9]+\.[0-9]+\.[0-9]+"$/ {
      if (cur_phase == target) {
        match($0, /id: "([0-9]+\.[0-9]+\.[0-9]+)"/, arr)
        print arr[1]
      }
    }
  ' "$yaml"
}

# Return the text of a specific question by ID.
sf_phases_question_text() {
  local yaml="$1" qid="$2"
  awk -v qid="$qid" '
    $0 ~ "id: \"" qid "\"$" { found = 1; next }
    found && /text:/ {
      match($0, /text: "(.*)"$/, arr)
      print arr[1]
      exit
    }
  ' "$yaml"
}

# Return whether a question is required (true/false).
sf_phases_question_required() {
  local yaml="$1" qid="$2"
  awk -v qid="$qid" '
    $0 ~ "id: \"" qid "\"$" { found = 1; next }
    found && /required:/ {
      match($0, /required: (true|false)/, arr)
      print arr[1]
      exit
    }
  ' "$yaml"
}

# Return the gate expression for a question, or empty if none.
sf_phases_question_gate() {
  local yaml="$1" qid="$2"
  awk -v qid="$qid" '
    $0 ~ "id: \"" qid "\"$" { found = 1; next }
    /^      - id:/ && found { exit }
    found && /gate:/ {
      sub(/.*gate: /, "")
      sub(/^"/, "")
      sub(/"$/, "")
      print
      exit
    }
  ' "$yaml"
}
```

- [ ] **Step 4: Run, pass**

Expected: 19 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-state.sh
git commit -m "scaffold-onboard: phases.yaml reader helpers (Phase C)"
```

### Task TC.7: `lib/render.sh` — MASTER-SPEC section append helper

**Files:**
- Modify: `scaffold-onboard/lib/render.sh`
- Modify: `scaffold-onboard/tests/test-render.sh`

- [ ] **Step 1: Append failing test**

Append to `tests/test-render.sh`:

```bash
test_master_spec_init() {
  echo "test_master_spec_init:"
  setup_tmp_repo
  local tmpl="$(dirname "$0")/../templates/master-spec/MASTER-SPEC.md.tmpl"
  sf_master_spec_init "$tmpl" "todo-cli" "CLI tool"
  assert_file_exists "./MASTER-SPEC.md"
  assert_file_contains "./MASTER-SPEC.md" "# todo-cli — Master Specification"
  assert_file_contains "./MASTER-SPEC.md" '\*\*Project class:\*\* CLI tool'
}

test_master_spec_init
```

- [ ] **Step 2: Run, fail**

Expected: `sf_master_spec_init: command not found`.

- [ ] **Step 3: Implement `sf_master_spec_init`**

Append to `lib/render.sh`:

```bash
# Initialize MASTER-SPEC.md from the template with project_name and project_class.
# All other placeholders render as TODO: <key> at init; they get filled in
# as phases complete (via sf_master_spec_update_phase).
sf_master_spec_init() {
  local tmpl="$1" project_name="$2" project_class="$3"
  local today
  today="$(date -u +%Y-%m-%d)"
  sf_render "$tmpl" \
    "project_name=$project_name" \
    "project_class=$project_class" \
    "created_date=$today" \
    "updated_date=$today" \
    > MASTER-SPEC.md
}
```

- [ ] **Step 4: Run, pass**

Expected: 6 passed in test-render.sh.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/render.sh scaffold-onboard/tests/test-render.sh
git commit -m "scaffold-onboard: MASTER-SPEC.md init helper (Phase C)"
```

### Task TC.8: `lib/render.sh` — update one phase's answers in MASTER-SPEC.md

**Files:**
- Modify: `scaffold-onboard/lib/render.sh`
- Modify: `scaffold-onboard/tests/test-render.sh`

- [ ] **Step 1: Append failing test**

Append to `tests/test-render.sh`:

```bash
test_master_spec_update_phase() {
  echo "test_master_spec_update_phase:"
  setup_tmp_repo
  local tmpl="$(dirname "$0")/../templates/master-spec/MASTER-SPEC.md.tmpl"
  sf_master_spec_init "$tmpl" "todo-cli" "CLI tool"
  sf_state_init
  sf_state_write_answer "1.1.1" "todo-cli — fast local-first task manager"
  sf_state_write_answer "1.1.2" "Existing managers are heavy and cloud-coupled."
  sf_master_spec_update_phase "$tmpl" 1
  assert_file_contains "./MASTER-SPEC.md" "todo-cli — fast local-first task manager"
  assert_file_contains "./MASTER-SPEC.md" "heavy and cloud-coupled"
}

# Need to source state.sh too
source "$(dirname "$0")/../lib/state.sh"

test_master_spec_update_phase
```

- [ ] **Step 2: Run, fail**

Expected: `sf_master_spec_update_phase: command not found`.

- [ ] **Step 3: Implement `sf_master_spec_update_phase`**

Append to `lib/render.sh`:

```bash
# Re-render MASTER-SPEC.md from the template, populating Phase N's placeholders
# with values from state.answers. Other phases' placeholders are left as-is
# (preserved from prior runs or showing TODO: <key> if not yet answered).
#
# Strategy: re-render the FULL template each time, with all currently-known
# answers fed in. This is deterministic and idempotent.
sf_master_spec_update_phase() {
  local tmpl="$1" phase_id="$2"
  # Collect every answered question's id+value into key=value pairs
  local args=()
  args+=("project_name=$(basename "$PWD")")
  local pc
  pc="$(sf_state_read_answer 1.3.1)"
  [[ "$pc" != "null" ]] && args+=("project_class=$pc")
  args+=("created_date=$(date -u +%Y-%m-%d)")
  args+=("updated_date=$(date -u +%Y-%m-%d)")

  # All phase answers
  local path
  path="$(sf_state_path)"
  local qid val
  while IFS=$'\t' read -r qid val; do
    [[ -z "$qid" ]] && continue
    # phases.yaml uses "1.1.1" → template placeholder {{phase_1.1.1}}
    args+=("phase_${qid}=${val}")
  done < <(jq -r '.answers | to_entries[] | "\(.key)\t\(.value)"' "$path")

  # Branching gate flags for {{#if}} blocks
  if sf_state_gate_passes 'project_class in {Web app, Mobile app, CLI tool, ML or AI system, Agent or plugin, Other}'; then
    args+=("ui_branch=true")
  else
    args+=("ui_branch=false")
  fi
  if sf_state_gate_passes 'project_class in {Library or SDK, Data pipeline, Web service (API only)}'; then
    args+=("dx_branch=true")
  else
    args+=("dx_branch=false")
  fi
  if sf_state_gate_passes 'project_class in {Web app, Web service (API only), ML or AI system, Agent or plugin, Data pipeline}'; then
    args+=("backend_branch=true")
  else
    args+=("backend_branch=false")
  fi
  if sf_state_gate_passes 'project_class in {Web app, Mobile app}'; then
    args+=("frontend_branch=true")
  else
    args+=("frontend_branch=false")
  fi
  if sf_state_gate_passes 'project_class == "Library or SDK"'; then
    args+=("library_branch=true")
  else
    args+=("library_branch=false")
  fi
  local llm
  llm="$(sf_state_read_answer 9.3.1)"
  if [[ "$llm" == "yes" || "$llm" == "true" ]]; then
    args+=("uses_llm=true")
  else
    args+=("uses_llm=false")
  fi

  sf_render "$tmpl" "${args[@]}" > MASTER-SPEC.md
}
```

- [ ] **Step 4: Run, pass**

Expected: 7 passed in test-render.sh.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/render.sh scaffold-onboard/tests/test-render.sh
git commit -m "scaffold-onboard: MASTER-SPEC phase update (Phase C)"
```

### Task TC.9: `/onboard` command implementation — the conversational protocol

**Files:**
- Modify: `scaffold-onboard/commands/onboard.md`

The `/onboard` command is a Claude Code slash command. It mixes a bash setup block (state checks, mode detection, environment) with a protocol-style markdown body that instructs Claude how to conduct the interactive 10-phase loop. Claude reads the protocol on every invocation.

- [ ] **Step 1: Replace the stub with the full command**

```markdown
---
description: Guided 10-phase onboarding conversation that authors MASTER-SPEC.md as source of truth for this project.
argument-hint: ""
allowed-tools: Bash(bash:*), Read, Write, Edit
---

Run the onboarding setup block, then conduct the per-phase conversation per the protocol below.

```bash
bash -c '
set -u
source "${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "scaffold-onboard: not inside a git repo. Run \`git init\` first."
  exit 1
fi
cd "$REPO_ROOT"

# Acquire onboarding lock
if ! sf_state_lock_acquire; then
  echo "scaffold-onboard: onboarding already in progress in another session."
  exit 1
fi
trap "sf_state_lock_release" EXIT

MODE="$(sf_state_mode)"
echo "scaffold-onboard: mode=$MODE"

case "$MODE" in
  new)
    sf_state_init
    echo "scaffold-onboard: initialized state at $(sf_state_path)"
    # symlink for in-repo visibility (gitignored)
    mkdir -p .claude
    ln -sf "$(sf_state_path)" .claude/.onboarding-state.json
    ;;
  resume)
    echo "scaffold-onboard: resuming at phase $(sf_state_read_field current_phase)"
    ;;
  reonboard)
    echo "scaffold-onboard: prior onboarding complete. Type re-onboard to overwrite MASTER-SPEC.md, or cancel."
    # The user reply is interpreted by Claude per the protocol below.
    ;;
esac

echo "current_phase=$(sf_state_read_field current_phase)"
echo "phases_yaml=${CLAUDE_PLUGIN_ROOT}/templates/onboarding-questions/phases.yaml"
echo "master_spec_tmpl=${CLAUDE_PLUGIN_ROOT}/templates/master-spec/MASTER-SPEC.md.tmpl"
echo "exec_summary_tmpl=${CLAUDE_PLUGIN_ROOT}/templates/master-spec/EXECUTIVE-SUMMARY.md.tmpl"
'
```

---

## Onboarding protocol (Claude follows this loop)

After the setup block runs, follow this protocol step-by-step. The setup output tells you `current_phase`, paths to `phases.yaml` and templates, and the mode.

**Per-phase loop (run once for the current phase, then re-invoke `/onboard` to continue or wait for user):**

1. **Read `phases.yaml`** for the current phase's question list using `sf_phases_questions_for <yaml> <phase_id>`.

2. **Check Phase 5 / Phase 7 entry signals.** If `current_phase` is 5 or 7:
   - Source `${CLAUDE_PLUGIN_ROOT}/lib/compose.sh` (Phase F — soft-fail if not present yet).
   - If `ai-mentor` detected: print `💡 Phase {N} ({Architecture|Implementation}) is judgment-dense. Consider /z2-decide for spotter mode.`
   - If `superpowers` detected with `brainstorming_available=true`: print `💡 superpowers:brainstorming is available for visual trade-off exploration on this phase.`

3. **Ask each question** in `phases.yaml` for this phase, in order:
   - For each question ID, call `sf_phases_question_text <yaml> <qid>` to get the question text.
   - Call `sf_phases_question_gate <yaml> <qid>` — if non-empty, evaluate with `sf_state_gate_passes`. If the gate fails, skip the question.
   - Present the question to the user. Accept their answer or `TBD`.
   - Persist immediately: `sf_state_write_answer <qid> <value>`.
   - Move to the next question.

4. **After all questions in this phase are answered:**
   - Re-render MASTER-SPEC.md to incorporate the new answers:
     `sf_master_spec_update_phase "${master_spec_tmpl}" <phase_id>`.
   - Generate a 3–5 line recap of this phase's section (read MASTER-SPEC.md's Phase N section back; summarize what the user said).

5. **Phase 5 + Phase 7 recap critic gate:**
   - If `current_phase` is 5 or 7 AND `architect-critic` detected (via `composition.json`):
   - Announce: `Running architect-critic premise audit on Phase {N} recap. Type 'skip' to bypass this fire.`
   - Watch for user's next message in the current turn:
     - If it's exactly `skip` (case-insensitive): log "skipped by user" and proceed to step 6.
     - Otherwise: build the critic request JSON per SPEC §8.3 and write to `${CLAUDE_PLUGIN_DATA}/architect-critic/inbox/<request-id>.json`. Invoke `/critique`. Read the outbox response. Present challenges to the user. The user may iterate on the recap or accept.

6. **Recap acceptance:** present the (possibly-revised) recap and ask user `accept / edit / append a note`. Apply their choice — `edit` means re-prompt; `append` means add the user's text as an addendum to the Phase N section of MASTER-SPEC.md.

7. **Advance state:** `sf_state_advance_phase`.

8. **If `sf_state_read_field status` is `complete` (i.e., Phase 10 just finished):**
   - Generate the executive summary (~500 words synthesized from all phases).
   - Re-render `EXECUTIVE-SUMMARY.md` using `sf_render "${exec_summary_tmpl}" project_name="$(basename "$PWD")" project_class="$(sf_state_read_answer 1.3.1)" created_date="$(date -u +%Y-%m-%d)" executive_summary="<the synthesized text>"`.
   - If `architect-critic` detected: announce `Running architect-critic close audit (claude + codex). Type 'skip' to bypass.` Process same as step 5 with `depth=close, adversaries=[claude, codex]`.
   - Report: `MASTER-SPEC.md authored. Next: /scaffold-project`.

9. **Otherwise:** report `Phase {N} complete. Re-invoke /onboard to continue.` and exit.

**Mode-specific entry:**

- **new mode:** start at Phase 1.
- **resume mode:** pick up at `current_phase`; if there are unanswered questions in that phase (check via `sf_state_read_answer` returning `null`), resume from the first unanswered one.
- **reonboard mode:** ask the user `re-onboard (overwrites MASTER-SPEC.md) / resume Phase N / cancel`. On `re-onboard`, set `status=in_progress`, `current_phase=1`, clear `.answers`, and restart at Phase 1. Default is `cancel`.

**Discipline:**

- Persist state after every single answer. Interruptions never lose work.
- Never modify state for `ai-mentor` or `architect-critic` — only read.
- Skip-flag mechanism is per-occurrence inline (user types `skip` in the turn the critic announces).
```

- [ ] **Step 2: Verify command file syntax**

Run: `head -5 scaffold-onboard/commands/onboard.md`
Expected: shows YAML frontmatter with `description`, `argument-hint`, `allowed-tools`.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/commands/onboard.md
git commit -m "scaffold-onboard: /onboard command + protocol body (Phase C)"
```

### Task TC.10: E2E test — scripted onboarding to MASTER-SPEC.md

This is a coarse end-to-end check that the bash helpers can be composed to produce a valid MASTER-SPEC.md without invoking Claude. The full interactive flow gets validated in Phase G's E2E tests.

**Files:**
- Modify: `scaffold-onboard/tests/test-state.sh`

- [ ] **Step 1: Append a long scripted scenario**

Append to `tests/test-state.sh`:

```bash
test_scripted_full_onboarding() {
  echo "test_scripted_full_onboarding:"
  setup_tmp_repo
  local pyaml="$(dirname "$0")/../templates/onboarding-questions/phases.yaml"
  local tmpl="$(dirname "$0")/../templates/master-spec/MASTER-SPEC.md.tmpl"
  source "$(dirname "$0")/../lib/render.sh"
  sf_state_init
  # Project class first (gates everything else)
  sf_state_write_answer "1.3.1" "CLI tool"
  # Init MASTER-SPEC with project_name + project_class
  sf_master_spec_init "$tmpl" "todo-cli" "CLI tool"
  # Fill a few representative answers across phases
  sf_state_write_answer "1.1.1" "todo-cli — fast local-first task manager"
  sf_state_write_answer "1.1.2" "Existing managers are heavy and cloud-coupled."
  sf_state_write_answer "1.2.1" "Solo devs and ops engineers."
  sf_state_write_answer "1.3.2" "add/list/complete tasks; persist to ~/.todo.json"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "5.2.2" "file (~/.todo.json)"
  sf_state_write_answer "7.1.2" "statically typed Rust"
  sf_state_write_answer "9.3.1" "no"

  # Update each phase to reflect state
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done

  assert_file_exists "./MASTER-SPEC.md"
  assert_file_contains "./MASTER-SPEC.md" "todo-cli — fast local-first task manager"
  assert_file_contains "./MASTER-SPEC.md" '\*\*Project class:\*\* CLI tool'
  assert_file_contains "./MASTER-SPEC.md" "Rust"

  # Validate the produced spec
  source "$(dirname "$0")/../lib/parser.sh"
  assert_exit_code 0 sf_spec_validate ./MASTER-SPEC.md
}

test_scripted_full_onboarding
```

- [ ] **Step 2: Run, all pass**

Run: `bash scaffold-onboard/tests/test-state.sh`
Expected: 23 passed (15 + 4 + 3 + 1 scripted scenario with 4 internal assertions).

- [ ] **Step 3: Commit + Phase C complete**

Update `scaffold-onboard/CHANGELOG.md` `## [Unreleased]` / `### Added`:

```
- Phase C: phases.yaml (10 phases, ~54 questions, branching gates), MASTER-SPEC + EXECUTIVE-SUMMARY templates, /onboard command with conversational protocol body, state advance + gate evaluation + mode detection + phases.yaml reader. ~23 tests in test-state.sh + 7 in test-render.sh + 13 in test-parser.sh = ~43 tests total at Phase C.
```

```bash
git add scaffold-onboard/tests/test-state.sh scaffold-onboard/CHANGELOG.md
git commit -m "scaffold-onboard: Phase C complete — /onboard end-to-end"
```

---

## Phase D — `/scaffold-project` implementation

After Phase D: `/scaffold-project` runs deterministically against any valid `MASTER-SPEC.md` and produces `.claude/memory-bank/` (11 files) + `<repo>/CLAUDE.md` + `.claude/settings.json`. Derived files are rewritten on every run; live files (`05`, `06`, `WORKFLOW.md`) are preserved unless `--force`.

### Task TD.1: Memory-bank templates — derived files (00–04, 07, 08, index)

**Files:**
- Create: 8 templates under `scaffold-onboard/templates/memory-bank/`

Templates share a structural pattern: a header with the derivation stamp, then content sections that reference MASTER-SPEC.md placeholders. Each is shown in full below.

- [ ] **Step 1: Create directory**

```bash
mkdir -p scaffold-onboard/templates/memory-bank
```

- [ ] **Step 2: Write `00-project-brief.md.tmpl`**

```markdown
# Project Brief

**Last derived from MASTER-SPEC.md @ {{ts}}**

## What is this?
{{phase_1.1.1}}

## Project class
{{project_class}}

## Problem
{{phase_1.1.2}}

## Primary users
{{phase_1.2.1}}

## Core use case
{{phase_1.2.2}}

## MVP cut
{{phase_1.3.2}}

## See also
- [MASTER-SPEC §Phase 1](../../MASTER-SPEC.md#phase-1-foundation)
- [Executive Summary](../../MASTER-SPEC.md#executive-summary)
```

- [ ] **Step 3: Write `01-product-context.md.tmpl`**

```markdown
# Product Context

**Last derived from MASTER-SPEC.md @ {{ts}}**

## Primary users
{{phase_1.2.1}}

## Core use case
{{phase_1.2.2}}

## Domain entities
{{phase_3.1.1}}

## Entity identity & description
{{phase_3.1.2}}

## Key relationships
{{phase_3.2.1}}

## Aggregates / invariants
{{phase_3.2.2}}

## Ubiquitous language
{{phase_3.3.1}}

{{#if ui_branch}}
## Surfaces
{{phase_6A.1.1}}

## Primary user flow
{{phase_6A.1.2}}
{{/if}}
{{#if dx_branch}}
## Developer experience — discovery & learning
{{phase_6B.1.1}}

## Error and output style
{{phase_6B.1.2}}
{{/if}}

## See also
- [MASTER-SPEC §Phase 3](../../MASTER-SPEC.md#phase-3-domain--data-model)
- [MASTER-SPEC §Phase 6](../../MASTER-SPEC.md#phase-6-ux--surfaces)
```

- [ ] **Step 4: Write `02-system-patterns.md.tmpl`**

```markdown
# System Patterns

**Last derived from MASTER-SPEC.md @ {{ts}}**

## Architecture shape
{{phase_5.1.1}}

## Async / event-driven boundaries
{{phase_5.1.2}}

## Security posture
- Sensitive data: {{phase_4.1.1}}
- Regulated domain: {{phase_4.1.2}}
- Auth model: {{phase_4.2.1}}
- Tenancy: {{phase_4.2.2}}
- External attack surface: {{phase_4.3.1}}

## Performance & scale targets
- Expected scale (6 months): {{phase_5.3.1}}
- Latency targets (hot paths): {{phase_5.3.2}}

## ADR index
- See `docs/adr/` for recorded decisions (generated by `/scaffold-docs`).

## See also
- [MASTER-SPEC §Phase 4](../../MASTER-SPEC.md#phase-4-security--compliance)
- [MASTER-SPEC §Phase 5](../../MASTER-SPEC.md#phase-5-architecture)
```

- [ ] **Step 5: Write `03-code-patterns.md.tmpl`**

```markdown
# Code Patterns

**Last derived from MASTER-SPEC.md @ {{ts}}**

## Module / package boundaries
{{phase_7.1.1}}

## Code style
{{phase_7.1.2}}

{{#if backend_branch}}
## Backend conventions
- ORM / query builder / raw SQL: {{phase_7.2.1}}
- API style: {{phase_7.2.2}}
{{/if}}

{{#if frontend_branch}}
## Frontend conventions
- State management: {{phase_7.3.1}}
{{/if}}

{{#if library_branch}}
## Library / SDK conventions
- Public API surface + versioning: {{phase_7.4.1}}
{{/if}}

## User-global defaults (apply unless overridden above)
- Functions ≤ 80 lines
- No premature abstraction — 3 similar lines beat extraction-for-2
- Functional by default; classes only when state must persist
- Comments only for non-obvious *why*, never for *what*
- Don't add error handling for impossible scenarios
- No half-finished implementations or commented-out code blocks
- Fix root causes, not symptoms

## See also
- [MASTER-SPEC §Phase 7](../../MASTER-SPEC.md#phase-7-implementation-approach)
```

- [ ] **Step 6: Write `04-tech-context.md.tmpl`**

```markdown
# Tech Context

**Last derived from MASTER-SPEC.md @ {{ts}}**

## Languages
{{phase_5.2.1}}

## Data stores
{{phase_5.2.2}}

## External APIs / third-party services
{{phase_5.2.3}}

## Local dev tooling
{{phase_8.1.1}}

## CI/CD
- Platform: {{phase_8.2.1}}
- Environments: {{phase_8.2.2}}

## Hosting target
{{phase_8.3.1}}

{{#if backend_branch}}
## Backend specifics
- ORM / query / SQL: {{phase_7.2.1}}
- API style: {{phase_7.2.2}}
{{/if}}
{{#if frontend_branch}}
## Frontend specifics
- State management: {{phase_7.3.1}}
{{/if}}
{{#if library_branch}}
## Library specifics
- Public API + versioning: {{phase_7.4.1}}
{{/if}}

## See also
- [MASTER-SPEC §Phase 5](../../MASTER-SPEC.md#phase-5-architecture)
- [MASTER-SPEC §Phase 8](../../MASTER-SPEC.md#phase-8-devops--environments)
```

- [ ] **Step 7: Write `07-constraints.md.tmpl`**

```markdown
# Constraints

**Last derived from MASTER-SPEC.md @ {{ts}}**

## Timeline & resources
- Target weeks to MVP: {{phase_2.1.1}}
- Team size: {{phase_2.1.2}}

## Budget
- Monthly cap: {{phase_2.2.1}}

## Risks (top 3)
{{phase_2.2.2}}

## Success metric
{{phase_2.3.1}}

## Compliance / regulation
{{phase_4.1.2}}

## Performance targets
- Scale (6 months): {{phase_5.3.1}}
- Latency: {{phase_5.3.2}}

## Operations & support
- On-call / response: {{phase_10.3.1}}
- Deprecation plan: {{phase_10.3.2}}

## See also
- [MASTER-SPEC §Phase 2](../../MASTER-SPEC.md#phase-2-strategy)
- [MASTER-SPEC §Phase 4](../../MASTER-SPEC.md#phase-4-security--compliance)
- [MASTER-SPEC §Phase 10](../../MASTER-SPEC.md#phase-10-operations--support)
```

- [ ] **Step 8: Write `08-governance.md.tmpl`**

```markdown
# Governance

**Last derived from MASTER-SPEC.md @ {{ts}}**

## Governance docs
The following documents are generated by `/scaffold-docs`:

- [PRD](../../docs/PRD.md) — Product requirements
- [SRS](../../docs/SRS.md) — Software requirements (lite)
- [BACKLOG](../../docs/BACKLOG.md) — Story-shaped backlog
- [PROJECT_PLAN](../../docs/PROJECT_PLAN.md) — Timeline + sprint structure
- [ADR-0001](../../docs/adr/0001-record-architecture-decisions.md) — Decision-recording protocol

With `/scaffold-docs --full`, also:
- RISK_REGISTER · THREAT_MODEL · TEST_STRATEGY · DEFINITION_OF_DONE
- EVALS_PLAN · MODEL_CARD · PROMPT_GOVERNANCE (LLM-project gated)
- CUTOVER_PLAN · DEMO_RUNBOOK

## Workflow rules
- MASTER-SPEC.md is canonical. Derived files (memory-bank 00–04, 07, 08, index · docs/*) are regenerated by `/scaffold-project` and `/scaffold-docs`.
- Hand-edits to derived files get overwritten on the next derive. Edit MASTER-SPEC.md instead.
- Live files (`05-active-context.md`, `06-progress.md`) are owned by slice work — never auto-rewritten.
```

- [ ] **Step 9: Write `index.md.tmpl`**

```markdown
# Memory Bank Index

**Last derived from MASTER-SPEC.md @ {{ts}}**

| File | Purpose | Load tier |
|---|---|---|
| `00-project-brief.md` | Vision · problem · users · MVP · project class | **Tier 0** (always preloaded) |
| `01-product-context.md` | Domain entities · user flows / DX · ubiquitous language | branch · product/UX |
| `02-system-patterns.md` | Architecture invariants · security posture · async rules | branch · architecture |
| `03-code-patterns.md` | Code style · function/class rules · banned patterns | branch · implementation |
| `04-tech-context.md` | Languages · frameworks · stores · hosting · tooling | branch · tech |
| `05-active-context.md` | What's happening *right now* — active sprint, slice, blockers | **Tier 0** · **LIVE** |
| `06-progress.md` | Append-only log: dated entries by sprint/slice/decision/gotcha | branch · history · **LIVE** |
| `07-constraints.md` | Hard constraints — budget · timeline · compliance · perf | branch · planning |
| `08-governance.md` | Pointers to governance docs · workflow rules | branch · planning |
| `WORKFLOW.md` | Per-sprint workflow — pointers to the slice loop | branch · workflow · **STATIC** |
| `index.md` | This file | **Tier 0** |
```

- [ ] **Step 10: Verify all 8 derived templates exist**

Run: `ls scaffold-onboard/templates/memory-bank/*.tmpl | wc -l`
Expected: 8 (00, 01, 02, 03, 04, 07, 08, index — note 05/06/WORKFLOW are next task).

- [ ] **Step 11: Commit**

```bash
git add scaffold-onboard/templates/memory-bank/
git commit -m "scaffold-onboard: derived memory-bank templates (Phase D)"
```

### Task TD.2: Memory-bank templates — live (05, 06) + static (WORKFLOW)

**Files:**
- Create: `scaffold-onboard/templates/memory-bank/05-active-context.md.tmpl`
- Create: `scaffold-onboard/templates/memory-bank/06-progress.md.tmpl`
- Create: `scaffold-onboard/templates/memory-bank/WORKFLOW.md`

- [ ] **Step 1: Write `05-active-context.md.tmpl`** (seeded once; never re-rendered after first run)

```markdown
# Active Context

> Live file — authored by slice work, never auto-regenerated. Update by hand or via slice commands during day-to-day work.

## Current focus
*(no active sprint — seeded by /scaffold-project)*

## Recent decisions
*(none yet)*

## Blockers
*(none)*

## Next up
*(plan your first slice — see `WORKFLOW.md`)*
```

- [ ] **Step 2: Write `06-progress.md.tmpl`** (seeded once; append-only after that)

```markdown
# Progress

> Live file — append-only log authored by slice work and `/changelog`. Entries are dated; older entries stay at the top of their section.

## Sprint 0 — bootstrap
- {{ts}}: Project onboarding complete; MASTER-SPEC.md authored; memory-bank derived.

## Sprint 1
*(no entries yet)*
```

- [ ] **Step 3: Write `WORKFLOW.md`** (static file — same on every project)

```markdown
# Workflow

> Static file copied from scaffold-onboard. Not regenerated; edit by hand if your workflow diverges.

## Per-slice loop

Use the companion `scaffold` plugin (implementation phase) for slice work:

1. `/slice-new <name>` — author the slice spec
2. `/slice-contract` — scaffold failing tests for each acceptance criterion
3. `/slice-scaffold` — write skeletons (types, glue, structure)
4. `/slice-implement` — fill in the logic until tests pass
5. `/slice-verify` — run all tests; mark complete when green

## When to update memory-bank

- **05-active-context.md** — update as you switch slices or change focus. Hand-edit freely.
- **06-progress.md** — append after every commit (via `/changelog` or by hand). One line per change.
- **00–04, 07, 08, index** — never hand-edit; re-run `/scaffold-project` after editing MASTER-SPEC.md.

## When to update governance docs

- **ADRs** — `/adr-new` for each architectural decision.
- **PRD / SRS / BACKLOG / PROJECT_PLAN** — re-run `/scaffold-docs` after material MASTER-SPEC.md changes; otherwise hand-edit (existing files preserved).

## Composition with other plugins

- `ai-mentor` — cognitive mode (`/z1`, `/z2-decide`, `/z2-build`). Use when decisions matter more than typing speed.
- `architect-critic` — anti-sycophancy reviews. Auto-fires at Phase 5/7 onboarding recaps and MASTER-SPEC close; can be invoked manually on slice specs and ADRs.
- `superpowers` — TDD, debugging, parallel agent dispatch, plan/execute discipline.
```

- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/templates/memory-bank/05-active-context.md.tmpl \
        scaffold-onboard/templates/memory-bank/06-progress.md.tmpl \
        scaffold-onboard/templates/memory-bank/WORKFLOW.md
git commit -m "scaffold-onboard: live + static memory-bank templates (Phase D)"
```

### Task TD.3: `CLAUDE.md.tmpl` — session-start router

**Files:**
- Create: `scaffold-onboard/templates/claude-md/CLAUDE.md.tmpl`

- [ ] **Step 1: Create directory**

```bash
mkdir -p scaffold-onboard/templates/claude-md
```

- [ ] **Step 2: Write the template**

```markdown
# Project: {{project_name}}

<!-- Generated by scaffold-onboard v0.1.0 at {{ts}}. Edit MASTER-SPEC.md and re-run /scaffold-project. -->

## Tier 0 — always preloaded

When this file loads, also preload:
- `.claude/memory-bank/index.md`
- `.claude/memory-bank/00-project-brief.md`
- `.claude/memory-bank/05-active-context.md`
- `MASTER-SPEC.md` §Executive Summary + §Phase 1 only

## Project in 5 lines

{{phase_1.1.1}}
{{phase_1.1.2}}
Primary users: {{phase_1.2.1}}
Project class: {{project_class}} · MVP: {{phase_1.3.2}}
Stack: {{phase_5.2.1}} · {{phase_5.2.2}}

## Branch loading rules

If the user's first message is about:

- **Architecture / system design** → load `.claude/memory-bank/02-system-patterns.md` + `04-tech-context.md`
- **Implementation / coding** → load `.claude/memory-bank/03-code-patterns.md` + `04-tech-context.md`
- **Product / UX** → load `.claude/memory-bank/01-product-context.md`
- **Planning / scoping** → load `.claude/memory-bank/07-constraints.md` + `08-governance.md`
- **Workflow / process** → load `.claude/memory-bank/WORKFLOW.md` + `06-progress.md`

## Slash commands

- `/onboard` — re-run onboarding · re-author MASTER-SPEC.md
- `/scaffold-project` — re-derive memory-bank · live files preserved
- `/scaffold-docs [--full]` — re-derive governance docs · preserves existing

{{#if has_scaffold_plugin}}
- `/slice-new`, `/slice-spec`, `/slice-contract`, `/slice-scaffold`, `/slice-implement`, `/slice-verify` — slice workflow (scaffold plugin)
- `/adr-new`, `/changelog`, `/runbook-new` — governance (scaffold plugin)
{{/if}}

{{#if has_ai_mentor}}
- `/z1`, `/z2-decide`, `/z2-build`, `/locked`, `/quiz`, `/eli10`, `/fool` — cognitive mode (ai-mentor)
{{/if}}

{{#if has_architect_critic}}
- `/critique` — anti-sycophancy review (architect-critic). Auto-fires during /onboard at Phase 5/7 recaps and MASTER-SPEC close.
{{/if}}

{{#if has_superpowers}}
- superpowers skills are auto-loaded: brainstorming, writing-plans, executing-plans, TDD, systematic-debugging, dispatching-parallel-agents, etc.
{{/if}}

## SSoT discipline

- `MASTER-SPEC.md` is the source of truth. Derived files (memory-bank 00–04, 07, 08, index · docs/*) are regenerated by `/scaffold-project` and `/scaffold-docs`.
- Hand-edits to derived files will be overwritten. Edit MASTER-SPEC.md instead.
- `05-active-context.md` and `06-progress.md` are LIVE — owned by slice work, never auto-rewritten.
```

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/templates/claude-md/CLAUDE.md.tmpl
git commit -m "scaffold-onboard: CLAUDE.md template — Tier 0 + branch routing (Phase D)"
```

### Task TD.4: `claude-settings.json.tmpl`

**Files:**
- Create: `scaffold-onboard/templates/settings/claude-settings.json.tmpl`

- [ ] **Step 1: Create directory and write template**

```bash
mkdir -p scaffold-onboard/templates/settings
```

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(grep:*)",
      "Bash(rg:*)",
      "Bash(jq:*)"
    ]
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add scaffold-onboard/templates/settings/claude-settings.json.tmpl
git commit -m "scaffold-onboard: .claude/settings.json template (Phase D)"
```

### Task TD.5: `lib/memory-bank.sh` — derived file generation

**Files:**
- Modify: `scaffold-onboard/lib/memory-bank.sh`
- Create: `scaffold-onboard/tests/test-memory-bank.sh`

- [ ] **Step 1: Write failing test**

Write `tests/test-memory-bank.sh`:

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/parser.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/memory-bank.sh"

PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Build a minimal valid MASTER-SPEC.md in $PWD using the templates + state.
seed_master_spec() {
  local tmpl="$PLUGIN_ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  sf_state_init
  sf_state_write_answer "1.1.1" "test-proj — a fast widget"
  sf_state_write_answer "1.1.2" "Widgets are slow today."
  sf_state_write_answer "1.2.1" "Solo devs"
  sf_state_write_answer "1.2.2" "Build a widget in 1 command"
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "1.3.2" "create / list / destroy widgets"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "5.2.2" "file (~/.widgets.json)"
  sf_state_write_answer "7.1.2" "statically typed Rust"
  sf_state_write_answer "9.3.1" "no"
  sf_master_spec_init "$tmpl" "test-proj" "CLI tool"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done
}

test_derive_00_project_brief() {
  echo "test_derive_00_project_brief:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  assert_file_exists "./.claude/memory-bank/00-project-brief.md"
  assert_file_contains "./.claude/memory-bank/00-project-brief.md" "test-proj — a fast widget"
  assert_file_contains "./.claude/memory-bank/00-project-brief.md" "Last derived from MASTER-SPEC.md"
}

test_derive_00_project_brief
report_results
```

- [ ] **Step 2: Run, fail**

Expected: `sf_memory_bank_derive: command not found`.

- [ ] **Step 3: Implement derived-file generation**

Replace `lib/memory-bank.sh`:

```bash
#!/usr/bin/env bash
# scaffold-onboard/lib/memory-bank.sh
# Memory-bank derivation: 9 derived files + 2 live (seeded once) + 1 static.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Render args used by every memory-bank file
_memory_bank_args() {
  local ts="$1"
  local args=("ts=$ts")
  local pc
  pc="$(sf_state_read_answer 1.3.1)"
  [[ "$pc" != "null" ]] && args+=("project_class=$pc")

  # All answered questions
  local path qid val
  path="$(sf_state_path)"
  while IFS=$'\t' read -r qid val; do
    [[ -z "$qid" ]] && continue
    args+=("phase_${qid}=${val}")
  done < <(jq -r '.answers | to_entries[] | "\(.key)\t\(.value)"' "$path")

  # Branching gate flags
  if sf_state_gate_passes 'project_class in {Web app, Mobile app, CLI tool, ML or AI system, Agent or plugin, Other}'; then
    args+=("ui_branch=true")
  else
    args+=("ui_branch=false")
  fi
  if sf_state_gate_passes 'project_class in {Library or SDK, Data pipeline, Web service (API only)}'; then
    args+=("dx_branch=true")
  else
    args+=("dx_branch=false")
  fi
  if sf_state_gate_passes 'project_class in {Web app, Web service (API only), ML or AI system, Agent or plugin, Data pipeline}'; then
    args+=("backend_branch=true")
  else
    args+=("backend_branch=false")
  fi
  if sf_state_gate_passes 'project_class in {Web app, Mobile app}'; then
    args+=("frontend_branch=true")
  else
    args+=("frontend_branch=false")
  fi
  if sf_state_gate_passes 'project_class == "Library or SDK"'; then
    args+=("library_branch=true")
  else
    args+=("library_branch=false")
  fi

  printf '%s\n' "${args[@]}"
}

# Derive memory-bank: regenerate derived files, seed live files only if missing,
# copy static file only if missing.
# Args: --force (optional) to overwrite live files too.
sf_memory_bank_derive() {
  local force=0
  if [[ "${1:-}" == "--force" ]]; then force=1; fi

  local root tmpl_dir ts
  root="$(sf_plugin_root)"
  tmpl_dir="$root/templates/memory-bank"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p .claude/memory-bank

  # Collect args once
  local args=()
  while IFS= read -r line; do args+=("$line"); done < <(_memory_bank_args "$ts")

  # 8 derived files
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 07-constraints 08-governance index; do
    sf_render "$tmpl_dir/${f}.md.tmpl" "${args[@]}" > ".claude/memory-bank/${f}.md"
  done

  # 2 live files — seed only if missing (unless --force)
  for f in 05-active-context 06-progress; do
    local target=".claude/memory-bank/${f}.md"
    if [[ ! -f "$target" || "$force" -eq 1 ]]; then
      sf_render "$tmpl_dir/${f}.md.tmpl" "${args[@]}" > "$target"
    else
      sf_log_info "preserved live file: $target"
    fi
  done

  # 1 static file — copy only if missing (--force does NOT overwrite static; it's project-agnostic)
  if [[ ! -f ".claude/memory-bank/WORKFLOW.md" ]]; then
    cp "$tmpl_dir/WORKFLOW.md" ".claude/memory-bank/WORKFLOW.md"
  fi
}
```

- [ ] **Step 4: Run, pass**

Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/memory-bank.sh scaffold-onboard/tests/test-memory-bank.sh
git commit -m "scaffold-onboard: derive 9 memory-bank files (Phase D)"
```

### Task TD.6: `lib/memory-bank.sh` — live-file preservation tests

**Files:**
- Modify: `scaffold-onboard/tests/test-memory-bank.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-memory-bank.sh` before `report_results`:

```bash
test_live_files_preserved() {
  echo "test_live_files_preserved:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  # Hand-edit the live file
  echo "## My custom note" >> ".claude/memory-bank/05-active-context.md"
  sf_memory_bank_derive
  assert_file_contains "./.claude/memory-bank/05-active-context.md" "My custom note"
}

test_live_files_force_overwritten() {
  echo "test_live_files_force_overwritten:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  echo "## My custom note" >> ".claude/memory-bank/05-active-context.md"
  sf_memory_bank_derive --force
  if grep -q "My custom note" "./.claude/memory-bank/05-active-context.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ --force should have overwritten"
  else
    PASS=$((PASS+1)); echo "  ✓ --force overwrote live file"
  fi
}

test_workflow_static_unchanged() {
  echo "test_workflow_static_unchanged:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  echo "## My workflow note" >> ".claude/memory-bank/WORKFLOW.md"
  sf_memory_bank_derive
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "My workflow note"
}

test_all_derived_files_present() {
  echo "test_all_derived_files_present:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 05-active-context 06-progress 07-constraints 08-governance index WORKFLOW; do
    assert_file_exists "./.claude/memory-bank/${f}.md"
  done
}

test_live_files_preserved
test_live_files_force_overwritten
test_workflow_static_unchanged
test_all_derived_files_present
```

- [ ] **Step 2: Run, all pass**

Expected: 4 prior + 14 new (3 standalone + 11 file-existence checks) = 18 passed.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/tests/test-memory-bank.sh
git commit -m "scaffold-onboard: live-file preservation tests (Phase D)"
```

### Task TD.7: `lib/memory-bank.sh` — CLAUDE.md generation

**Files:**
- Modify: `scaffold-onboard/lib/memory-bank.sh`
- Modify: `scaffold-onboard/tests/test-memory-bank.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-memory-bank.sh`:

```bash
test_claude_md_generated() {
  echo "test_claude_md_generated:"
  setup_tmp_repo
  seed_master_spec
  sf_claude_md_generate
  assert_file_exists "./CLAUDE.md"
  assert_file_contains "./CLAUDE.md" "# Project: test-proj"
  assert_file_contains "./CLAUDE.md" "Tier 0"
  assert_file_contains "./CLAUDE.md" "Branch loading rules"
}

test_claude_md_plugin_awareness_when_no_composition() {
  echo "test_claude_md_plugin_awareness_when_no_composition:"
  setup_tmp_repo
  seed_master_spec
  # No composition.json present
  sf_claude_md_generate
  # ai-mentor / critic / superpowers sections should NOT appear
  if grep -q "/z2-decide" "./CLAUDE.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ ai-mentor section leaked without composition"
  else
    PASS=$((PASS+1)); echo "  ✓ ai-mentor section absent without composition"
  fi
}

test_claude_md_generated
test_claude_md_plugin_awareness_when_no_composition
```

- [ ] **Step 2: Run, fail**

Expected: `sf_claude_md_generate: command not found`.

- [ ] **Step 3: Implement CLAUDE.md generation**

Append to `lib/memory-bank.sh`:

```bash
# Read composition.json (if it exists) and return key=value pairs for plugin awareness
_composition_args() {
  local comp="$(sf_data_dir)/composition.json"
  if [[ ! -f "$comp" ]]; then
    echo "has_ai_mentor=false"
    echo "has_architect_critic=false"
    echo "has_superpowers=false"
    echo "has_scaffold_plugin=false"
    return 0
  fi
  local v
  v="$(jq -r '.plugins["ai-mentor"].installed // false' "$comp")"
  echo "has_ai_mentor=$v"
  v="$(jq -r '.plugins["architect-critic"].installed // false' "$comp")"
  echo "has_architect_critic=$v"
  v="$(jq -r '.plugins["superpowers"].installed // false' "$comp")"
  echo "has_superpowers=$v"
  v="$(jq -r '.plugins["scaffold"].installed // false' "$comp")"
  echo "has_scaffold_plugin=$v"
}

# Generate <repo>/CLAUDE.md from the template using state.answers + composition.json
sf_claude_md_generate() {
  local root tmpl ts
  root="$(sf_plugin_root)"
  tmpl="$root/templates/claude-md/CLAUDE.md.tmpl"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local args=()
  args+=("project_name=$(basename "$PWD")")
  args+=("ts=$ts")
  while IFS= read -r line; do args+=("$line"); done < <(_memory_bank_args "$ts")
  while IFS= read -r line; do args+=("$line"); done < <(_composition_args)

  sf_render "$tmpl" "${args[@]}" > CLAUDE.md
}

# Generate .claude/settings.json from template, only if not present
sf_claude_settings_generate() {
  if [[ -f ".claude/settings.json" ]]; then
    sf_log_info "preserved existing .claude/settings.json"
    return 0
  fi
  local root tmpl
  root="$(sf_plugin_root)"
  tmpl="$root/templates/settings/claude-settings.json.tmpl"
  mkdir -p .claude
  cp "$tmpl" .claude/settings.json
}
```

- [ ] **Step 4: Run, all pass**

Expected: 20 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/memory-bank.sh scaffold-onboard/tests/test-memory-bank.sh
git commit -m "scaffold-onboard: CLAUDE.md + settings.json generation (Phase D)"
```

### Task TD.8: `/scaffold-project` command

**Files:**
- Modify: `scaffold-onboard/commands/scaffold-project.md`

- [ ] **Step 1: Replace stub with full command**

```markdown
---
description: Derive .claude/memory-bank/ (11 files) and CLAUDE.md from MASTER-SPEC.md. Deterministic and idempotent. Use --force to overwrite live files.
argument-hint: "[--force]"
allowed-tools: Bash(bash:*)
---

Validate MASTER-SPEC.md, then run the deterministic derivation pipeline.

```bash
bash -c '
set -u
source "${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/parser.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/memory-bank.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "scaffold-onboard: not inside a git repo."
  exit 1
fi
cd "$REPO_ROOT"

FORCE=""
if [[ "${1:-}" == "--force" ]]; then
  FORCE="--force"
  echo "scaffold-project: --force passed; live files WILL be overwritten."
  echo "Continue? Type yes to proceed: "
  read -r REPLY
  [[ "$REPLY" == "yes" ]] || { echo "Cancelled."; exit 0; }
fi

if ! sf_spec_validate ./MASTER-SPEC.md; then
  exit 1
fi

echo "scaffold-project: deriving memory-bank..."
sf_memory_bank_derive $FORCE
echo "scaffold-project: generating CLAUDE.md..."
sf_claude_md_generate
echo "scaffold-project: writing .claude/settings.json..."
sf_claude_settings_generate

echo ""
echo "scaffold-project: done."
echo "  memory-bank: .claude/memory-bank/ (11 files)"
echo "  router:      CLAUDE.md"
echo "  settings:    .claude/settings.json"
echo ""
echo "Next: /scaffold-docs (governance docs) or /slice-new (start first slice via the scaffold plugin)."
' -- "$1"
```

After running, summarize in 1-2 sentences: which files were created vs preserved. If `--force` was passed, note that live files were reset. Otherwise mention that `05-active-context.md` and `06-progress.md` were preserved across the run.
```

- [ ] **Step 2: Commit**

```bash
git add scaffold-onboard/commands/scaffold-project.md
git commit -m "scaffold-onboard: /scaffold-project command (Phase D)"
```

### Task TD.9: Phase D close — run all suites

- [ ] **Step 1: Run all Phase A–D test suites**

```bash
for t in scaffold-onboard/tests/test-state.sh scaffold-onboard/tests/test-parser.sh scaffold-onboard/tests/test-render.sh scaffold-onboard/tests/test-memory-bank.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```

Expected: each suite exits 0; cumulative ~60+ tests passing.

- [ ] **Step 2: Update CHANGELOG**

Append to `scaffold-onboard/CHANGELOG.md` under `## [Unreleased]` / `### Added`:

```
- Phase D: 11 memory-bank templates (00–08, index, WORKFLOW), CLAUDE.md template (Tier 0 + branch routing + plugin awareness), .claude/settings.json template, lib/memory-bank.sh with derive + CLAUDE.md generation + live-file preservation + --force, /scaffold-project command. ~20 tests in test-memory-bank.sh.
```

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/CHANGELOG.md
git commit -m "scaffold-onboard: Phase D complete — /scaffold-project end-to-end"
```

---

## Phase E — `/scaffold-docs` implementation

After Phase E: `/scaffold-docs` runs deterministically against MASTER-SPEC.md and produces `docs/PRD.md`, `SRS.md`, `BACKLOG.md`, `PROJECT_PLAN.md`, `adr/0001-record-architecture-decisions.md`. With `--full`, 9 additional governance docs are generated (3 are LLM-project-gated). Existing files are preserved unless `--regenerate`.

### Task TE.1: Default governance doc templates (5 files)

**Files:**
- Create 5 templates under `scaffold-onboard/templates/docs-minimal/`

- [ ] **Step 1: Create directories**

```bash
mkdir -p scaffold-onboard/templates/docs-minimal/adr
```

- [ ] **Step 2: Write `PRD.md.tmpl`**

```markdown
# {{project_name}} — Product Requirements Document

**Last derived from MASTER-SPEC.md @ {{ts}}**

## 1. Vision

{{phase_1.1.1}}

## 2. Problem

{{phase_1.1.2}}

## 3. 6-month success criteria

{{phase_1.1.3}}

## 4. Users

{{phase_1.2.1}}

## 5. Core use case

{{phase_1.2.2}}

## 6. Project class

{{project_class}}

## 7. MVP cut

{{phase_1.3.2}}

## 8. Domain entities

{{phase_3.1.1}}

## 9. Entity identity & description

{{phase_3.1.2}}

## 10. Key relationships

{{phase_3.2.1}}

## See also

- [MASTER-SPEC](../MASTER-SPEC.md)
- [BACKLOG](./BACKLOG.md)
- [PROJECT_PLAN](./PROJECT_PLAN.md)
```

- [ ] **Step 3: Write `SRS.md.tmpl`** (lightweight — not the heavy enterprise SRS)

```markdown
# {{project_name}} — Software Requirements (lite)

**Last derived from MASTER-SPEC.md @ {{ts}}**

## 1. Security & access

- Sensitive data: {{phase_4.1.1}}
- Regulated domain: {{phase_4.1.2}}
- Auth model: {{phase_4.2.1}}
- Tenancy: {{phase_4.2.2}}
- External attack surface: {{phase_4.3.1}}

## 2. Surfaces

{{#if ui_branch}}
- Surfaces in scope: {{phase_6A.1.1}}
- Primary user flow: {{phase_6A.1.2}}
- Accessibility floor: {{phase_6A.2.1}}
- Design system: {{phase_6A.2.2}}
{{/if}}
{{#if dx_branch}}
- Discovery & learning: {{phase_6B.1.1}}
- Error and output style: {{phase_6B.1.2}}
{{/if}}

## 3. Implementation requirements

- Module / package boundaries: {{phase_7.1.1}}
- Code style: {{phase_7.1.2}}

{{#if backend_branch}}
- ORM / query / SQL: {{phase_7.2.1}}
- API style: {{phase_7.2.2}}
{{/if}}
{{#if frontend_branch}}
- State management: {{phase_7.3.1}}
{{/if}}
{{#if library_branch}}
- Public API surface + versioning: {{phase_7.4.1}}
{{/if}}

## 4. Environments

- Local tooling: {{phase_8.1.1}}
- Clone-to-running target: {{phase_8.1.2}}
- CI platform: {{phase_8.2.1}}
- Environments: {{phase_8.2.2}}
- Hosting target: {{phase_8.3.1}}

## See also

- [MASTER-SPEC](../MASTER-SPEC.md)
- [PRD](./PRD.md)
```

- [ ] **Step 4: Write `BACKLOG.md.tmpl`**

```markdown
# {{project_name}} — Backlog

**Last derived from MASTER-SPEC.md @ {{ts}}**

> Stories are seeded from Phase 1 user stories and Phase 4 features. Refine and add IDs as you go.

## Story format

`As a <persona>, I want to <capability>, so that <outcome>.`

## Initial stories (seeded from MASTER-SPEC.md)

### S-001 — Core use case (MVP)

As {{phase_1.2.1}}, I want to {{phase_1.2.2}}, so that the MVP delivers value end-to-end.

**Acceptance:** {{phase_1.3.2}}

### S-002 — Authentication (if applicable)

Auth model defined as: {{phase_4.2.1}}. If non-trivial, scope each auth path (signup / signin / token refresh / session revocation) as separate stories below.

### S-003 — Per-user data

Tenancy: {{phase_4.2.2}}. Data isolation, per-user accounts, multi-tenant boundaries — split into per-feature stories as needed.

## Backlog conventions

- Stories get IDs `S-NNN`, slices get IDs `slice-NN-<name>` (via the `scaffold` plugin's `/slice-new`).
- One slice may implement one or more stories; one story may span multiple slices.
- Move done stories to the bottom of this file with a `~~strikethrough~~` and the completion date.

## See also

- [MASTER-SPEC §Phase 1](../MASTER-SPEC.md#phase-1-foundation)
- [PRD](./PRD.md)
```

- [ ] **Step 5: Write `PROJECT_PLAN.md.tmpl`**

```markdown
# {{project_name}} — Project Plan

**Last derived from MASTER-SPEC.md @ {{ts}}**

## 1. Timeline

- Target weeks to MVP: {{phase_2.1.1}}
- Team size: {{phase_2.1.2}}

## 2. Risks

{{phase_2.2.2}}

## 3. Success metric

{{phase_2.3.1}}

## 4. Budget

- Monthly cap: {{phase_2.2.1}}

## 5. Rollout plan

- Strategy: {{phase_10.1.1}}
- Observability: {{phase_10.2.1}}
- Alerting: {{phase_10.2.2}}

## 6. Sprint structure

> Recommended sprint length: 1 week. Adjust as you settle into rhythm. Use the `scaffold` plugin's slice workflow per sprint:
> - `/slice-new <name>` → `/slice-contract` → `/slice-scaffold` → `/slice-implement` → `/slice-verify`

### Sprint 0 — bootstrap
- Onboarding (this artifact) — {{ts}}
- Memory-bank + governance docs derivation
- First slice ready to start

### Sprint 1
*(populate after planning)*

## See also

- [MASTER-SPEC](../MASTER-SPEC.md)
- [BACKLOG](./BACKLOG.md)
- [WORKFLOW](../.claude/memory-bank/WORKFLOW.md)
```

- [ ] **Step 6: Write `adr/0001-record-architecture-decisions.md.tmpl`** (Michael Nygard format)

```markdown
# 1. Record architecture decisions

Date: {{ts}}

## Status

Accepted

## Context

We need to record the architectural decisions made on this project. The Nygard ADR format gives each decision its own short, dated document with a fixed structure so future readers can trace why a choice was made.

This project is a {{project_class}}. Key Phase 4 + Phase 5 inputs are baked into subsequent ADRs:

- Auth model: {{phase_4.2.1}}
- Tenancy: {{phase_4.2.2}}
- Architecture shape: {{phase_5.1.1}}
- Primary language(s): {{phase_5.2.1}}
- Primary data store(s): {{phase_5.2.2}}

## Decision

We will use Architecture Decision Records, as described by Michael Nygard, with the following file structure under `docs/adr/`:

- `NNNN-<slug>.md` — one per decision; numbers are zero-padded and never reused
- Each ADR has sections: **Status** / **Context** / **Decision** / **Consequences**
- Status values: Proposed · Accepted · Deprecated · Superseded by NNNN

## Consequences

- New architectural decisions get a written record at the time the decision is made.
- Future contributors can read ADRs chronologically to understand the project's evolution.
- ADRs do not capture every implementation detail — only decisions that constrain future work.
- The `scaffold` (implementation) plugin provides `/adr-new` for fast authoring.
```

- [ ] **Step 7: Commit**

```bash
git add scaffold-onboard/templates/docs-minimal/
git commit -m "scaffold-onboard: 5 default governance doc templates (Phase E)"
```

### Task TE.2: `--full` governance doc templates — non-LLM (6 files)

**Files:**
- Create 6 templates under `scaffold-onboard/templates/docs-full/`

- [ ] **Step 1: Create directory**

```bash
mkdir -p scaffold-onboard/templates/docs-full
```

- [ ] **Step 2: Write `RISK_REGISTER.md.tmpl`**

```markdown
# {{project_name}} — Risk Register

**Last derived from MASTER-SPEC.md @ {{ts}}**

> Initial risks seeded from Phase 2.2.2. Add columns / rows as you encounter risks during slice work.

| ID | Risk | Category | Likelihood | Impact | Mitigation | Owner | Status |
|---|---|---|---|---|---|---|---|
| R-001 | *(seed from Phase 2.2.2 — risk 1)* | tech / market / resource | TBD | TBD | TBD | TBD | open |
| R-002 | *(seed from Phase 2.2.2 — risk 2)* | tech / market / resource | TBD | TBD | TBD | TBD | open |
| R-003 | *(seed from Phase 2.2.2 — risk 3)* | tech / market / resource | TBD | TBD | TBD | TBD | open |

## Phase 2.2.2 source text

{{phase_2.2.2}}

## Conventions

- IDs `R-NNN`, never reused.
- `Status`: open · mitigated · accepted · closed.
- Hand-edit this file freely; it's a working document, not a regenerated artifact.
```

- [ ] **Step 3: Write `THREAT_MODEL.md.tmpl`**

```markdown
# {{project_name}} — Threat Model

**Last derived from MASTER-SPEC.md @ {{ts}}**

## Scope

- Sensitive data handled: {{phase_4.1.1}}
- Regulated domain: {{phase_4.1.2}}
- External attack surface: {{phase_4.3.1}}
- Auth model: {{phase_4.2.1}}
- Tenancy: {{phase_4.2.2}}

## STRIDE checklist

| Threat | In scope? | Mitigation strategy |
|---|---|---|
| **S**poofing identity | TBD | Auth model: {{phase_4.2.1}} |
| **T**ampering with data | TBD | TBD |
| **R**epudiation | TBD | TBD |
| **I**nformation disclosure | TBD | TBD |
| **D**enial of service | TBD | TBD |
| **E**levation of privilege | TBD | TBD |

## Trust boundaries

*(diagram or paragraph describing where untrusted input enters the system and how it's validated)*

## Open threat items

- *(add as you discover them during slice work — link to mitigation slices)*
```

- [ ] **Step 4: Write `TEST_STRATEGY.md.tmpl`**

```markdown
# {{project_name}} — Test Strategy

**Last derived from MASTER-SPEC.md @ {{ts}}**

## Coverage floor

{{phase_9.1.1}}

## Test types in scope

{{phase_9.1.2}}

## Pyramid

- **Unit tests** — fast, isolated, run on every commit. Target: 80%+ of business logic.
- **Integration tests** — exercise multiple components together; real DB where applicable. Target: critical paths.
- **End-to-end** — happy path + 2–3 representative failure modes. Target: <30s total runtime.

## Pre-merge gates

{{phase_9.2.1}}

## Framework

Detected stack: {{phase_5.2.1}}. Pick the canonical test framework for that stack. Test commands belong in your build tool (`cargo test`, `pytest`, `npm test`, etc.) and are invoked by the `scaffold` plugin's `/slice-verify`.

## What we deliberately don't test

- *(list things out-of-scope to prevent test-bloat creep — generated code, dependencies, etc.)*
```

- [ ] **Step 5: Write `DEFINITION_OF_DONE.md.tmpl`**

```markdown
# {{project_name}} — Definition of Done

**Last derived from MASTER-SPEC.md @ {{ts}}**

A change is "done" when **all** of the following hold:

## Code

- [ ] Implementation matches the slice spec's acceptance criteria
- [ ] All tests for the slice pass; pre-existing tests still pass
- [ ] Code follows `03-code-patterns.md` rules
- [ ] No `TODO` or `FIXME` left in shipped code without a linked issue

## Tests

- [ ] Per-AC tests exist and pass
- [ ] Coverage floor met (see TEST_STRATEGY.md)
- [ ] Tests run deterministically (no flaky time/network dependencies)

## Pre-merge gates

{{phase_9.2.1}}

## Documentation

- [ ] CHANGELOG entry added (via `/changelog` or hand-edit)
- [ ] If decision-worthy: ADR drafted via `/adr-new`
- [ ] If runbook-worthy: runbook drafted via `/runbook-new`

## Operations

- [ ] Observability: logs/metrics added where appropriate ({{phase_10.2.1}})
- [ ] Rollback path clear (especially for migrations / cutover)

## Release readiness ({{phase_10.1.1}})

- [ ] Rollout strategy understood
- [ ] On-call / response plan: {{phase_10.3.1}}
- [ ] Deprecation / retirement clear: {{phase_10.3.2}}
```

- [ ] **Step 6: Write `CUTOVER_PLAN.md.tmpl`**

```markdown
# {{project_name}} — Cutover Plan

**Last derived from MASTER-SPEC.md @ {{ts}}**

> A cutover plan documents the script for migrations, rollouts, and deprecations. Replace placeholders as the project matures.

## Environments

{{phase_8.2.2}}

## Hosting

{{phase_8.3.1}}

## Rollout strategy

{{phase_10.1.1}}

## Cutover script

### Pre-cutover

1. *(tasks to complete before the cutover window)*
2. *(verify rollback path is tested)*

### During cutover

1. *(steps in order, with expected outcomes per step)*

### Post-cutover

1. *(monitoring checks, sign-off criteria)*

### Rollback

1. *(steps to revert; explicit "we will roll back if X")*

## Communication

- Stakeholders to notify: *(list)*
- Channels: *(Slack / email / status page)*
```

- [ ] **Step 7: Write `DEMO_RUNBOOK.md.tmpl`**

```markdown
# {{project_name}} — Demo Runbook

**Last derived from MASTER-SPEC.md @ {{ts}}**

> Step-by-step script for demoing the product. Update as the UX surface evolves.

## Setup

1. Environment: {{phase_8.3.1}}
2. Test data: *(describe data fixtures needed for a clean demo)*
3. User accounts: *(describe accounts and roles)*

## Demo flow

{{#if ui_branch}}
1. Open {{phase_6A.1.1}}
2. Walk through primary user flow: {{phase_6A.1.2}}
3. Highlight: *(features that distinguish from competitors)*
{{/if}}
{{#if dx_branch}}
1. Open terminal / IDE / docs site
2. Walk through {{phase_6B.1.1}}
3. Highlight: error and output style: {{phase_6B.1.2}}
{{/if}}

## Common questions + answers

| Question | Answer |
|---|---|
| *(seed with FAQs as you encounter them in real demos)* | |

## Recovery

If something breaks mid-demo:
- *(pre-baked fallback paths)*
- *(escape clause: "let me show you Y instead while Z recovers")*
```

- [ ] **Step 8: Commit**

```bash
git add scaffold-onboard/templates/docs-full/
git commit -m "scaffold-onboard: 6 non-LLM --full doc templates (Phase E)"
```

### Task TE.3: `--full` LLM-gated templates (3 files)

**Files:**
- Create 3 templates under `scaffold-onboard/templates/docs-full/`

These templates are only rendered when `phase_9.3.1 = yes` (project uses LLMs/ML).

- [ ] **Step 1: Write `EVALS_PLAN.md.tmpl`**

```markdown
# {{project_name}} — Evals Plan

**Last derived from MASTER-SPEC.md @ {{ts}}**

> This document is generated only when the project uses LLMs / ML. Phase 9.3 inputs drive content.

## Eval dimensions

{{phase_9.3.2}}

## Dataset

- Golden set: *(describe held-out evaluation data — source, size, refresh cadence)*
- Acceptance threshold per dimension: *(set numerical floors per axis)*

## Eval cadence

- Pre-merge: lightweight smoke evals on every PR touching prompt or model code.
- Nightly: full suite against golden set.
- Pre-release: regression check against the prior 3 releases.

## Failure handling

- An eval regression that exceeds the per-dimension threshold blocks merge.
- A nightly regression triggers an alert via {{phase_10.2.2}}.

## See also

- [MODEL_CARD](./MODEL_CARD.md)
- [PROMPT_GOVERNANCE](./PROMPT_GOVERNANCE.md)
```

- [ ] **Step 2: Write `MODEL_CARD.md.tmpl`**

```markdown
# {{project_name}} — Model Card

**Last derived from MASTER-SPEC.md @ {{ts}}**

> Model card describing what model is used, for what, and its limitations.

## Model

- Family / vendor: *(e.g., Anthropic Claude, OpenAI GPT, local Llama 3, etc.)*
- Version: *(specific model ID)*
- Source: *(API / hosted / self-hosted on which infra)*

## Intended use

- Primary use case: {{phase_1.2.2}}
- Users: {{phase_1.2.1}}

## Out-of-scope use

- *(domains the model should not be applied to)*
- *(content types it's not validated on)*

## Limitations

- Hallucination risk: *(describe + mitigation)*
- Latency: *(measured P50/P95/P99 against hot paths {{phase_5.3.2}})*
- Cost per call: *(measured average; tracked against budget {{phase_2.2.1}})*

## Data inputs

- Stores: {{phase_5.2.2}}
- Sensitive data handling: {{phase_4.1.1}}

## Eval reference

- See [EVALS_PLAN](./EVALS_PLAN.md) for golden set + acceptance thresholds.
```

- [ ] **Step 3: Write `PROMPT_GOVERNANCE.md.tmpl`**

```markdown
# {{project_name}} — Prompt Governance

**Last derived from MASTER-SPEC.md @ {{ts}}**

> Rules for authoring, versioning, evaluating, and rolling back prompts. Treat prompts as code.

## Authoring

- All prompts live under `prompts/` (or your project's equivalent).
- One prompt per file. Filename matches its purpose (e.g., `summarize_doc.md`).
- Prompts include a frontmatter block with: `version`, `intended_use`, `expected_inputs`, `expected_outputs`.

## Versioning

- Each material prompt change bumps the version field in frontmatter (semver-style: major.minor).
- The previous prompt version is preserved at `prompts/_archive/<name>-v<X>.<Y>.md`.

## Evaluation before rollout

- Every prompt change runs the eval plan ({{phase_9.3.2}}) against the golden set.
- Acceptance threshold: *(set per the EVALS_PLAN)*.
- Failing evals block the change from merging.

## Rollback

- If a deployed prompt regresses metrics in production, revert by restoring the prior version file and redeploying.
- The `scaffold` plugin's `/runbook-new` should be used to record the incident.

## See also

- [EVALS_PLAN](./EVALS_PLAN.md)
- [MODEL_CARD](./MODEL_CARD.md)
```

- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/templates/docs-full/EVALS_PLAN.md.tmpl \
        scaffold-onboard/templates/docs-full/MODEL_CARD.md.tmpl \
        scaffold-onboard/templates/docs-full/PROMPT_GOVERNANCE.md.tmpl
git commit -m "scaffold-onboard: 3 LLM-gated --full doc templates (Phase E)"
```

### Task TE.4: `lib/docs.sh` — default derivation

**Files:**
- Modify: `scaffold-onboard/lib/docs.sh`
- Create: `scaffold-onboard/tests/test-docs.sh`

- [ ] **Step 1: Write failing test**

Write `tests/test-docs.sh`:

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/parser.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/docs.sh"

PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

seed_master_spec_for_docs() {
  local tmpl="$PLUGIN_ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  sf_state_init
  sf_state_write_answer "1.1.1" "test-proj — fast widget"
  sf_state_write_answer "1.1.2" "Widgets slow."
  sf_state_write_answer "1.2.1" "Solo devs"
  sf_state_write_answer "1.2.2" "Build in one command"
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "1.3.2" "core flows"
  sf_state_write_answer "2.1.1" "4 weeks"
  sf_state_write_answer "2.2.2" "tech: dependency drift; market: niche; resource: solo"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "9.3.1" "no"
  sf_master_spec_init "$tmpl" "test-proj" "CLI tool"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done
}

test_default_docs_generated() {
  echo "test_default_docs_generated:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  assert_file_exists "./docs/PRD.md"
  assert_file_exists "./docs/SRS.md"
  assert_file_exists "./docs/BACKLOG.md"
  assert_file_exists "./docs/PROJECT_PLAN.md"
  assert_file_exists "./docs/adr/0001-record-architecture-decisions.md"
}

test_prd_content() {
  echo "test_prd_content:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  assert_file_contains "./docs/PRD.md" "test-proj — fast widget"
  assert_file_contains "./docs/PRD.md" "CLI tool"
}

test_default_does_not_create_full_docs() {
  echo "test_default_does_not_create_full_docs:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  assert_file_missing "./docs/RISK_REGISTER.md"
  assert_file_missing "./docs/EVALS_PLAN.md"
}

test_default_docs_generated
test_prd_content
test_default_does_not_create_full_docs
report_results
```

- [ ] **Step 2: Run, fail**

Expected: `sf_docs_derive: command not found`.

- [ ] **Step 3: Implement default derivation**

Replace `lib/docs.sh`:

```bash
#!/usr/bin/env bash
# scaffold-onboard/lib/docs.sh
# Governance doc derivation. Default = 5 docs; --full = +9 (3 LLM-gated).

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Shared render args — same shape as memory-bank.sh's _memory_bank_args
_docs_args() {
  local ts="$1"
  local args=("ts=$ts")
  args+=("project_name=$(basename "$PWD")")
  local pc
  pc="$(sf_state_read_answer 1.3.1)"
  [[ "$pc" != "null" ]] && args+=("project_class=$pc")

  local path qid val
  path="$(sf_state_path)"
  while IFS=$'\t' read -r qid val; do
    [[ -z "$qid" ]] && continue
    args+=("phase_${qid}=${val}")
  done < <(jq -r '.answers | to_entries[] | "\(.key)\t\(.value)"' "$path")

  # Branching gate flags (same as memory-bank.sh)
  if sf_state_gate_passes 'project_class in {Web app, Mobile app, CLI tool, ML or AI system, Agent or plugin, Other}'; then
    args+=("ui_branch=true"); else args+=("ui_branch=false"); fi
  if sf_state_gate_passes 'project_class in {Library or SDK, Data pipeline, Web service (API only)}'; then
    args+=("dx_branch=true"); else args+=("dx_branch=false"); fi
  if sf_state_gate_passes 'project_class in {Web app, Web service (API only), ML or AI system, Agent or plugin, Data pipeline}'; then
    args+=("backend_branch=true"); else args+=("backend_branch=false"); fi
  if sf_state_gate_passes 'project_class in {Web app, Mobile app}'; then
    args+=("frontend_branch=true"); else args+=("frontend_branch=false"); fi
  if sf_state_gate_passes 'project_class == "Library or SDK"'; then
    args+=("library_branch=true"); else args+=("library_branch=false"); fi

  printf '%s\n' "${args[@]}"
}

# Derive default + (optionally) full docs.
# Args: [--full] [--regenerate]
sf_docs_derive() {
  local full=0 regen=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --full) full=1 ;;
      --regenerate) regen=1 ;;
    esac
    shift
  done

  local root ts tmpl_min tmpl_full
  root="$(sf_plugin_root)"
  tmpl_min="$root/templates/docs-minimal"
  tmpl_full="$root/templates/docs-full"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p docs/adr

  local args=()
  while IFS= read -r line; do args+=("$line"); done < <(_docs_args "$ts")

  # 5 default docs
  _write_or_skip "$tmpl_min/PRD.md.tmpl" "docs/PRD.md" "$regen" "${args[@]}"
  _write_or_skip "$tmpl_min/SRS.md.tmpl" "docs/SRS.md" "$regen" "${args[@]}"
  _write_or_skip "$tmpl_min/BACKLOG.md.tmpl" "docs/BACKLOG.md" "$regen" "${args[@]}"
  _write_or_skip "$tmpl_min/PROJECT_PLAN.md.tmpl" "docs/PROJECT_PLAN.md" "$regen" "${args[@]}"
  _write_or_skip "$tmpl_min/adr/0001-record-architecture-decisions.md.tmpl" \
                 "docs/adr/0001-record-architecture-decisions.md" "$regen" "${args[@]}"

  if [[ "$full" -eq 1 ]]; then
    # Always-on --full docs
    _write_or_skip "$tmpl_full/RISK_REGISTER.md.tmpl" "docs/RISK_REGISTER.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/THREAT_MODEL.md.tmpl" "docs/THREAT_MODEL.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/TEST_STRATEGY.md.tmpl" "docs/TEST_STRATEGY.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/DEFINITION_OF_DONE.md.tmpl" "docs/DEFINITION_OF_DONE.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/CUTOVER_PLAN.md.tmpl" "docs/CUTOVER_PLAN.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/DEMO_RUNBOOK.md.tmpl" "docs/DEMO_RUNBOOK.md" "$regen" "${args[@]}"

    # LLM-gated --full docs
    local uses_llm
    uses_llm="$(sf_state_read_answer 9.3.1)"
    if [[ "$uses_llm" == "yes" || "$uses_llm" == "true" ]]; then
      _write_or_skip "$tmpl_full/EVALS_PLAN.md.tmpl" "docs/EVALS_PLAN.md" "$regen" "${args[@]}"
      _write_or_skip "$tmpl_full/MODEL_CARD.md.tmpl" "docs/MODEL_CARD.md" "$regen" "${args[@]}"
      _write_or_skip "$tmpl_full/PROMPT_GOVERNANCE.md.tmpl" "docs/PROMPT_GOVERNANCE.md" "$regen" "${args[@]}"
    else
      sf_log_info "LLM-gated --full docs skipped (phase 9.3.1 != yes)"
    fi
  fi
}

# Internal helper: render template to target unless target exists and not --regenerate.
_write_or_skip() {
  local tmpl="$1" target="$2" regen="$3"; shift 3
  if [[ -f "$target" && "$regen" -ne 1 ]]; then
    sf_log_info "preserved: $target"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  sf_render "$tmpl" "$@" > "$target"
}
```

- [ ] **Step 4: Run, pass**

Expected: 9 passed (3 file-exists in test 1, 2 contains in test 2, 2 missing in test 3, plus 2 standalone — actually let me re-count: test 1 has 5 file_exists = 5, test 2 has 2 file_contains = 2, test 3 has 2 file_missing = 2 → 9 total).

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/docs.sh scaffold-onboard/tests/test-docs.sh
git commit -m "scaffold-onboard: docs.sh default derivation (Phase E)"
```

### Task TE.5: `--full` mode + LLM-gating tests

**Files:**
- Modify: `scaffold-onboard/tests/test-docs.sh`

- [ ] **Step 1: Append failing tests**

Append before `report_results`:

```bash
test_full_mode_non_llm() {
  echo "test_full_mode_non_llm:"
  setup_tmp_repo
  seed_master_spec_for_docs  # 9.3.1 = "no"
  sf_docs_derive --full
  # 5 default + 6 non-LLM --full = 11 docs total under docs/
  assert_file_exists "./docs/RISK_REGISTER.md"
  assert_file_exists "./docs/THREAT_MODEL.md"
  assert_file_exists "./docs/TEST_STRATEGY.md"
  assert_file_exists "./docs/DEFINITION_OF_DONE.md"
  assert_file_exists "./docs/CUTOVER_PLAN.md"
  assert_file_exists "./docs/DEMO_RUNBOOK.md"
  # LLM-gated should NOT be generated
  assert_file_missing "./docs/EVALS_PLAN.md"
  assert_file_missing "./docs/MODEL_CARD.md"
  assert_file_missing "./docs/PROMPT_GOVERNANCE.md"
}

test_full_mode_llm_project() {
  echo "test_full_mode_llm_project:"
  setup_tmp_repo
  seed_master_spec_for_docs
  # Flip the LLM gate
  sf_state_write_answer "9.3.1" "yes"
  sf_state_write_answer "9.3.2" "groundedness, factuality, latency, cost"
  local tmpl="$PLUGIN_ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done
  sf_docs_derive --full
  assert_file_exists "./docs/EVALS_PLAN.md"
  assert_file_exists "./docs/MODEL_CARD.md"
  assert_file_exists "./docs/PROMPT_GOVERNANCE.md"
}

test_existing_files_preserved() {
  echo "test_existing_files_preserved:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  # Hand-edit
  echo "## My addition" >> "./docs/PRD.md"
  sf_docs_derive  # should NOT overwrite
  assert_file_contains "./docs/PRD.md" "My addition"
}

test_regenerate_overwrites() {
  echo "test_regenerate_overwrites:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  echo "## My addition" >> "./docs/PRD.md"
  sf_docs_derive --regenerate
  if grep -q "My addition" "./docs/PRD.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ --regenerate did not overwrite"
  else
    PASS=$((PASS+1)); echo "  ✓ --regenerate overwrote existing file"
  fi
}

test_full_mode_non_llm
test_full_mode_llm_project
test_existing_files_preserved
test_regenerate_overwrites
```

- [ ] **Step 2: Run, all pass**

Expected: 9 prior + 12 new (3+3+1+1=8 assertions in 4 tests) = ~21 passed.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/tests/test-docs.sh
git commit -m "scaffold-onboard: --full + LLM-gating + preservation tests (Phase E)"
```

### Task TE.6: `/scaffold-docs` command

**Files:**
- Modify: `scaffold-onboard/commands/scaffold-docs.md`

- [ ] **Step 1: Replace stub with full command**

```markdown
---
description: Derive governance docs (PRD, SRS, BACKLOG, PROJECT_PLAN, ADR-0001) from MASTER-SPEC.md. --full adds 9 more; --regenerate overwrites existing.
argument-hint: "[--full] [--regenerate]"
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set -u
source "${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/parser.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/render.sh"
source "${CLAUDE_PLUGIN_ROOT}/lib/docs.sh"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  echo "scaffold-onboard: not inside a git repo."
  exit 1
fi
cd "$REPO_ROOT"

if ! sf_spec_validate ./MASTER-SPEC.md; then
  exit 1
fi

FLAGS=()
[[ "$1" == "--full" || "$2" == "--full" ]] && FLAGS+=("--full")
[[ "$1" == "--regenerate" || "$2" == "--regenerate" ]] && FLAGS+=("--regenerate")

echo "scaffold-docs: deriving governance docs (flags: ${FLAGS[*]:-default})..."
sf_docs_derive "${FLAGS[@]}"

echo ""
echo "scaffold-docs: done."
echo ""
ls -1 docs/ docs/adr/ 2>/dev/null | head -30
' -- "${1:-}" "${2:-}"
```

After running, summarize: how many docs were written, how many preserved, whether LLM-gated docs were generated or skipped.
```

- [ ] **Step 2: Commit**

```bash
git add scaffold-onboard/commands/scaffold-docs.md
git commit -m "scaffold-onboard: /scaffold-docs command (Phase E)"
```

### Task TE.7: Phase E close — run all suites

- [ ] **Step 1: Run all Phase A–E test suites**

```bash
for t in scaffold-onboard/tests/test-state.sh scaffold-onboard/tests/test-parser.sh scaffold-onboard/tests/test-render.sh scaffold-onboard/tests/test-memory-bank.sh scaffold-onboard/tests/test-docs.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```

Expected: each suite exits 0; cumulative ~80+ tests passing.

- [ ] **Step 2: Update CHANGELOG**

Append to `scaffold-onboard/CHANGELOG.md` under `## [Unreleased]` / `### Added`:

```
- Phase E: 14 governance doc templates (5 default + 9 --full, 3 LLM-project-gated). lib/docs.sh with default + --full derivation, existing-file preservation, --regenerate override. /scaffold-docs command. ~21 tests in test-docs.sh.
```

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/CHANGELOG.md
git commit -m "scaffold-onboard: Phase E complete — /scaffold-docs end-to-end"
```

---

## Phase F — cross-cutting integration

After Phase F: `scaffold-onboard` detects ai-mentor, architect-critic, and superpowers at session start; caches detection results in `composition.json`; can emit ai-mentor hints and dispatch critic requests via the file-based inbox/outbox handshake. Soft-fail when any cross-cutting plugin is missing.

> **Testing strategy:** detection tests use a `SF_COMPOSE_PROBE_PATHS` env var to point at fake plugin directories instead of the real `~/.claude/plugins/` install paths. Critic handshake tests mock the outbox by pre-writing the response file (since there's no real critic plugin yet).

### Task TF.1: `lib/compose.sh` — probe-path discovery + ai-mentor detection

**Files:**
- Modify: `scaffold-onboard/lib/compose.sh`
- Create: `scaffold-onboard/tests/test-compose.sh`

- [ ] **Step 1: Write failing test**

Write `tests/test-compose.sh`:

```bash
#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/compose.sh"

# Build a fake plugin install dir at $TMP_DIR/fake-plugins/<name>
mk_fake_plugin() {
  local name="$1"; shift
  local dir="$TMP_DIR/fake-plugins/$name"
  mkdir -p "$dir"
  # Optional file paths to create inside the fake plugin
  local rel
  for rel in "$@"; do
    mkdir -p "$dir/$(dirname "$rel")"
    : > "$dir/$rel"
  done
  echo "$dir"
}

test_detect_ai_mentor_present() {
  echo "test_detect_ai_mentor_present:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-foo" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_ai_mentor)"
  if [[ "$found" == *"ai-mentor-foo"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ ai-mentor detected: $found"
  else
    FAIL=$((FAIL+1)); echo "  ✗ ai-mentor not detected: $found"
  fi
}

test_detect_ai_mentor_absent() {
  echo "test_detect_ai_mentor_absent:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"  # exists but empty
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_ai_mentor)"
  assert_eq "ai-mentor absent → empty" "" "$found"
}

test_detect_ai_mentor_present
test_detect_ai_mentor_absent
report_results
```

- [ ] **Step 2: Run, fail**

Expected: `sf_compose_detect_ai_mentor: command not found`.

- [ ] **Step 3: Implement probe-path discovery + ai-mentor detection**

Replace `lib/compose.sh`:

```bash
#!/usr/bin/env bash
# scaffold-onboard/lib/compose.sh
# Cross-cutting plugin detection + composition.json caching + critic dispatch.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Return the list of paths to probe for installed plugins.
# Override via SF_COMPOSE_PROBE_PATHS env var (colon-separated).
sf_compose_probe_paths() {
  if [[ -n "${SF_COMPOSE_PROBE_PATHS:-}" ]]; then
    echo "$SF_COMPOSE_PROBE_PATHS" | tr ":" "\n"
  else
    # Default: standard Claude Code plugin dirs
    echo "$HOME/.claude/plugins/data"
    echo "$HOME/.claude/plugins/cache"
  fi
}

# Find a plugin by name prefix. Echo the first matching directory or empty.
_compose_find_plugin() {
  local prefix="$1"
  local dir
  while IFS= read -r dir; do
    [[ -d "$dir" ]] || continue
    local match
    match="$(find "$dir" -maxdepth 2 -type d -name "${prefix}*" 2>/dev/null | head -1)"
    if [[ -n "$match" ]]; then
      echo "$match"
      return 0
    fi
  done < <(sf_compose_probe_paths)
  echo ""
}

sf_compose_detect_ai_mentor() {
  _compose_find_plugin "ai-mentor"
}
```

- [ ] **Step 4: Run, pass**

Expected: 2 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/compose.sh scaffold-onboard/tests/test-compose.sh
git commit -m "scaffold-onboard: compose probe + ai-mentor detection (Phase F)"
```

### Task TF.2: Detect architect-critic + superpowers

**Files:**
- Modify: `scaffold-onboard/lib/compose.sh`
- Modify: `scaffold-onboard/tests/test-compose.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-compose.sh`:

```bash
test_detect_architect_critic() {
  echo "test_detect_architect_critic:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-bar" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_architect_critic)"
  if [[ "$found" == *"architect-critic-bar"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ architect-critic detected"
  else
    FAIL=$((FAIL+1)); echo "  ✗ architect-critic not detected: $found"
  fi
}

test_detect_superpowers() {
  echo "test_detect_superpowers:"
  setup_tmp_repo
  mk_fake_plugin "superpowers" "skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_superpowers)"
  if [[ "$found" == *"superpowers"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ superpowers detected"
  else
    FAIL=$((FAIL+1)); echo "  ✗ superpowers not detected: $found"
  fi
}

test_detect_brainstorming_available() {
  echo "test_detect_brainstorming_available:"
  setup_tmp_repo
  mk_fake_plugin "superpowers" "skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local available
  available="$(sf_compose_brainstorming_available)"
  assert_eq "brainstorming available" "true" "$available"
}

test_detect_brainstorming_unavailable() {
  echo "test_detect_brainstorming_unavailable:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local available
  available="$(sf_compose_brainstorming_available)"
  assert_eq "brainstorming unavailable" "false" "$available"
}

test_detect_architect_critic
test_detect_superpowers
test_detect_brainstorming_available
test_detect_brainstorming_unavailable
```

- [ ] **Step 2: Run, fail**

Expected: 2 prior pass; 4 new fail.

- [ ] **Step 3: Implement remaining detection helpers**

Append to `lib/compose.sh`:

```bash
sf_compose_detect_architect_critic() {
  _compose_find_plugin "architect-critic"
}

sf_compose_detect_superpowers() {
  _compose_find_plugin "superpowers"
}

# Returns "true" if superpowers is installed AND its brainstorming skill is present
sf_compose_brainstorming_available() {
  local sp
  sp="$(sf_compose_detect_superpowers)"
  if [[ -n "$sp" && -f "$sp/skills/brainstorming/SKILL.md" ]]; then
    echo "true"
  else
    echo "false"
  fi
}
```

- [ ] **Step 4: Run, all pass**

Expected: 6 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/compose.sh scaffold-onboard/tests/test-compose.sh
git commit -m "scaffold-onboard: detect critic + superpowers + brainstorming (Phase F)"
```

### Task TF.3: `composition.json` write + read

**Files:**
- Modify: `scaffold-onboard/lib/compose.sh`
- Modify: `scaffold-onboard/tests/test-compose.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-compose.sh`:

```bash
test_composition_refresh_with_plugins() {
  echo "test_composition_refresh_with_plugins:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-x" "state.json"
  mk_fake_plugin "architect-critic-y" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local path="$CLAUDE_PLUGIN_DATA/composition.json"
  assert_file_exists "$path"
  local mentor_installed critic_installed
  mentor_installed="$(jq -r '.plugins["ai-mentor"].installed' "$path")"
  critic_installed="$(jq -r '.plugins["architect-critic"].installed' "$path")"
  assert_eq "ai-mentor installed" "true" "$mentor_installed"
  assert_eq "architect-critic installed" "true" "$critic_installed"
}

test_composition_refresh_no_plugins() {
  echo "test_composition_refresh_no_plugins:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local path="$CLAUDE_PLUGIN_DATA/composition.json"
  local mentor_installed
  mentor_installed="$(jq -r '.plugins["ai-mentor"].installed' "$path")"
  assert_eq "ai-mentor absent" "false" "$mentor_installed"
}

test_composition_is_installed_helper() {
  echo "test_composition_is_installed_helper:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-z" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  assert_exit_code 0 sf_compose_is_installed "ai-mentor"
  assert_exit_code 1 sf_compose_is_installed "architect-critic"
}

test_composition_refresh_with_plugins
test_composition_refresh_no_plugins
test_composition_is_installed_helper
```

- [ ] **Step 2: Run, fail**

Expected: 6 prior pass; new ones fail.

- [ ] **Step 3: Implement composition.json write/read**

Append to `lib/compose.sh`:

```bash
sf_compose_path() {
  echo "$(sf_data_dir)/composition.json"
}

# Probe every cross-cutting plugin and write composition.json. Atomic via tmp+mv.
sf_compose_refresh() {
  local path tmp now
  path="$(sf_compose_path)"
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${path}.XXXXXX")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local mentor_dir critic_dir superpowers_dir brainstorming
  mentor_dir="$(sf_compose_detect_ai_mentor)"
  critic_dir="$(sf_compose_detect_architect_critic)"
  superpowers_dir="$(sf_compose_detect_superpowers)"
  brainstorming="$(sf_compose_brainstorming_available)"

  jq -n \
    --arg now "$now" \
    --arg mentor "$mentor_dir" \
    --arg critic "$critic_dir" \
    --arg sp "$superpowers_dir" \
    --arg br "$brainstorming" \
    '{
      detected_at: $now,
      plugins: {
        "ai-mentor": {
          installed: ($mentor != ""),
          data_dir: $mentor,
          state_file: (if $mentor != "" then ($mentor + "/state.json") else "" end)
        },
        "architect-critic": {
          installed: ($critic != ""),
          data_dir: $critic,
          principles_file: (if $critic != "" then ($critic + "/principles.md") else "" end),
          command: "/critique"
        },
        "superpowers": {
          installed: ($sp != ""),
          skills_dir: (if $sp != "" then ($sp + "/skills") else "" end),
          brainstorming_available: ($br == "true")
        }
      },
      user_overrides: {
        disable_mentor_suggestions: false,
        disable_critic: false,
        disable_superpowers_subskill: false
      }
    }' > "$tmp"
  mv "$tmp" "$path"
}

# Return 0 if a plugin is currently marked installed in composition.json.
sf_compose_is_installed() {
  local name="$1"
  local path
  path="$(sf_compose_path)"
  [[ -f "$path" ]] || return 1
  local v
  v="$(jq -r --arg n "$name" '.plugins[$n].installed // false' "$path")"
  [[ "$v" == "true" ]]
}
```

- [ ] **Step 4: Run, all pass**

Expected: 11 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/compose.sh scaffold-onboard/tests/test-compose.sh
git commit -m "scaffold-onboard: composition.json write + is_installed helper (Phase F)"
```

### Task TF.4: SessionStart hook implementation

**Files:**
- Modify: `scaffold-onboard/hooks-handlers/session-start.sh`

- [ ] **Step 1: Replace the stub**

```bash
#!/usr/bin/env bash
# SessionStart hook for scaffold-onboard.
# Source-aware: refresh composition.json on startup/clear; preserve on resume/compact;
# emit additionalContext if onboarding is in progress in the current repo.

set -u

# Resolve plugin root (Claude Code sets CLAUDE_PLUGIN_ROOT for hooks)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

source "$PLUGIN_ROOT/lib/_helpers.sh"
source "$PLUGIN_ROOT/lib/state.sh"
source "$PLUGIN_ROOT/lib/compose.sh"

# Read source field from stdin JSON payload, if present
SOURCE=""
if [[ ! -t 0 ]]; then
  PAYLOAD="$(cat 2>/dev/null || true)"
  if [[ -n "$PAYLOAD" ]]; then
    SOURCE="$(echo "$PAYLOAD" | jq -r '.source // ""' 2>/dev/null || echo "")"
  fi
fi

# Refresh composition.json on startup/clear (fresh detection)
case "$SOURCE" in
  ""|"startup"|"clear")
    sf_compose_refresh 2>/dev/null || true
    ;;
  "resume"|"compact")
    # Preserve composition.json; only refresh if it doesn't exist yet
    if [[ ! -f "$(sf_compose_path)" ]]; then
      sf_compose_refresh 2>/dev/null || true
    fi
    ;;
esac

# If onboarding is in progress in the current repo, emit additionalContext
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$REPO_ROOT" ]]; then
  STATE_PATH="$(sf_state_path)"
  if [[ -f "$STATE_PATH" ]]; then
    STATUS="$(jq -r '.status // ""' "$STATE_PATH" 2>/dev/null || echo "")"
    PHASE="$(jq -r '.current_phase // ""' "$STATE_PATH" 2>/dev/null || echo "")"
    if [[ "$STATUS" == "in_progress" ]]; then
      cat <<JSON
{
  "additionalContext": "scaffold-onboard: onboarding in progress in this repo (phase ${PHASE}/10). Resume via /onboard."
}
JSON
    fi
  fi
fi

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scaffold-onboard/hooks-handlers/session-start.sh
```

- [ ] **Step 3: Smoke-test the hook**

Run:
```bash
bash -c '
export CLAUDE_PLUGIN_ROOT="$(pwd)/scaffold-onboard"
export CLAUDE_PLUGIN_DATA="$(mktemp -d)"
export SF_COMPOSE_PROBE_PATHS="/nonexistent"
echo "{\"source\":\"startup\"}" | bash scaffold-onboard/hooks-handlers/session-start.sh
ls "$CLAUDE_PLUGIN_DATA/"
'
```
Expected: `composition.json` listed in the output (created by the hook). No errors.

- [ ] **Step 4: Commit**

```bash
git add scaffold-onboard/hooks-handlers/session-start.sh
git commit -m "scaffold-onboard: SessionStart hook — source-aware compose refresh (Phase F)"
```

### Task TF.5: ai-mentor hint emission

**Files:**
- Modify: `scaffold-onboard/lib/compose.sh`
- Modify: `scaffold-onboard/tests/test-compose.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-compose.sh`:

```bash
test_mentor_hint_phase_5() {
  echo "test_mentor_hint_phase_5:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-q" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local hint
  hint="$(sf_compose_mentor_hint 5)"
  if echo "$hint" | grep -q "z2-decide"; then
    PASS=$((PASS+1)); echo "  ✓ phase 5 emits /z2-decide hint"
  else
    FAIL=$((FAIL+1)); echo "  ✗ phase 5 hint missing: $hint"
  fi
}

test_mentor_hint_phase_2() {
  echo "test_mentor_hint_phase_2:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-q" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local hint
  hint="$(sf_compose_mentor_hint 2)"
  assert_eq "phase 2 no hint" "" "$hint"
}

test_mentor_hint_without_install() {
  echo "test_mentor_hint_without_install:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local hint
  hint="$(sf_compose_mentor_hint 5)"
  assert_eq "no install, no hint" "" "$hint"
}

test_mentor_hint_phase_5
test_mentor_hint_phase_2
test_mentor_hint_without_install
```

- [ ] **Step 2: Run, fail**

Expected: `sf_compose_mentor_hint: command not found`.

- [ ] **Step 3: Implement hint emitters**

Append to `lib/compose.sh`:

```bash
# Emit ai-mentor /z2-decide hint for judgment-dense phases (5, 7).
# Returns empty string when phase doesn't qualify, plugin isn't installed,
# or user has disabled hints.
sf_compose_mentor_hint() {
  local phase="$1"
  case "$phase" in
    5|7) ;;
    *)   echo ""; return 0 ;;
  esac

  local path
  path="$(sf_compose_path)"
  [[ -f "$path" ]] || { echo ""; return 0; }

  local installed disabled
  installed="$(jq -r '.plugins["ai-mentor"].installed // false' "$path")"
  disabled="$(jq -r '.user_overrides.disable_mentor_suggestions // false' "$path")"
  [[ "$installed" != "true" ]] && { echo ""; return 0; }
  [[ "$disabled" == "true" ]]   && { echo ""; return 0; }

  case "$phase" in
    5) echo "💡 Phase 5 (Architecture) is judgment-dense. Consider /z2-decide for spotter mode." ;;
    7) echo "💡 Phase 7 (Implementation) is judgment-dense. Consider /z2-decide for spotter mode." ;;
  esac
}

# Similarly: superpowers brainstorming hint at Phase 5/7
sf_compose_brainstorming_hint() {
  local phase="$1"
  case "$phase" in
    5|7) ;;
    *)   echo ""; return 0 ;;
  esac

  local path
  path="$(sf_compose_path)"
  [[ -f "$path" ]] || { echo ""; return 0; }

  local avail disabled
  avail="$(jq -r '.plugins["superpowers"].brainstorming_available // false' "$path")"
  disabled="$(jq -r '.user_overrides.disable_superpowers_subskill // false' "$path")"
  [[ "$avail" != "true" ]]    && { echo ""; return 0; }
  [[ "$disabled" == "true" ]] && { echo ""; return 0; }

  echo "💡 superpowers:brainstorming is available for visual trade-off exploration on this phase."
}
```

- [ ] **Step 4: Run, all pass**

Expected: 14 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/compose.sh scaffold-onboard/tests/test-compose.sh
git commit -m "scaffold-onboard: mentor + brainstorming hints (Phase F)"
```

### Task TF.6: Critic request envelope build

**Files:**
- Modify: `scaffold-onboard/lib/compose.sh`
- Modify: `scaffold-onboard/tests/test-compose.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-compose.sh`:

```bash
test_critic_request_premise_audit() {
  echo "test_critic_request_premise_audit:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-r" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  echo "test content" > MASTER-SPEC.md
  sf_state_init
  sf_state_write_answer "1.3.1" "CLI tool"
  local req_path
  req_path="$(sf_compose_build_critic_request "premise-audit" 5)"
  assert_file_exists "$req_path"
  local depth phase_id
  depth="$(jq -r .depth "$req_path")"
  phase_id="$(jq -r .target.phase_id "$req_path")"
  assert_eq "request depth" "premise-audit" "$depth"
  assert_eq "request phase_id" "5" "$phase_id"
  local concession
  concession="$(jq -r .concession_threshold "$req_path")"
  assert_eq "concession threshold = 4" "4" "$concession"
}

test_critic_request_close() {
  echo "test_critic_request_close:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-r" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  echo "test content" > MASTER-SPEC.md
  sf_state_init
  sf_state_write_answer "1.3.1" "CLI tool"
  local req_path
  req_path="$(sf_compose_build_critic_request "close" "")"
  local depth target_type
  depth="$(jq -r .depth "$req_path")"
  target_type="$(jq -r .target.type "$req_path")"
  assert_eq "depth=close" "close" "$depth"
  assert_eq "target type=master-spec-full" "master-spec-full" "$target_type"
  local adv0 adv1
  adv0="$(jq -r '.adversaries[0]' "$req_path")"
  adv1="$(jq -r '.adversaries[1]' "$req_path")"
  assert_eq "adversaries[0] = claude" "claude" "$adv0"
  assert_eq "adversaries[1] = codex" "codex" "$adv1"
}

test_critic_request_premise_audit
test_critic_request_close
```

- [ ] **Step 2: Run, fail**

Expected: `sf_compose_build_critic_request: command not found`.

- [ ] **Step 3: Implement envelope build**

Append to `lib/compose.sh`:

```bash
# Build a critic request envelope per SPEC §8.3 and write it to the
# architect-critic inbox dir. Echo the path of the written request file.
# Args: <depth> <phase_id_or_empty>
sf_compose_build_critic_request() {
  local depth="$1" phase_id="${2:-}"
  local comp
  comp="$(sf_compose_path)"
  [[ -f "$comp" ]] || { sf_log_error "composition.json missing"; return 1; }

  local critic_dir
  critic_dir="$(jq -r '.plugins["architect-critic"].data_dir // ""' "$comp")"
  [[ -z "$critic_dir" ]] && { sf_log_error "architect-critic not installed"; return 1; }

  local principles
  principles="$(jq -r '.plugins["architect-critic"].principles_file // ""' "$comp")"

  local inbox_dir
  inbox_dir="$critic_dir/inbox"
  mkdir -p "$inbox_dir"

  local now request_id req_path
  now="$(date -u +%Y-%m-%dT%H%M%S)"
  if [[ -n "$phase_id" ]]; then
    request_id="crit-${now}-phase${phase_id}"
  else
    request_id="crit-${now}-close"
  fi
  req_path="$inbox_dir/${request_id}.json"

  # Adversaries: claude only for per-phase audits; claude+codex at close.
  local adversaries_json
  if [[ "$depth" == "close" ]]; then
    adversaries_json='["claude","codex"]'
  else
    adversaries_json='["claude"]'
  fi

  # target: master-spec-phase (for per-phase) or master-spec-full (for close)
  local target_json
  local master_spec_path
  master_spec_path="$(pwd)/MASTER-SPEC.md"
  if [[ "$depth" == "close" ]]; then
    target_json="$(jq -n --arg p "$master_spec_path" '{type:"master-spec-full",path:$p}')"
  else
    target_json="$(jq -n --arg p "$master_spec_path" --argjson pid "$phase_id" \
      '{type:"master-spec-phase",path:$p,phase_id:$pid}')"
  fi

  # Accumulated phases: 1..N-1 for per-phase audits; 1..10 for close
  local acc_json
  if [[ "$depth" == "close" ]]; then
    acc_json='[1,2,3,4,5,6,7,8,9,10]'
  else
    acc_json="$(jq -n --argjson pid "$phase_id" '[range(1;$pid)]')"
  fi

  local project_class
  project_class="$(sf_state_read_answer 1.3.1)"
  [[ "$project_class" == "null" ]] && project_class=""

  jq -n \
    --arg rid "$request_id" \
    --arg depth "$depth" \
    --argjson adv "$adversaries_json" \
    --argjson target "$target_json" \
    --arg principles "$principles" \
    --argjson acc "$acc_json" \
    --argjson conc 4 \
    --arg pc "$project_class" \
    '{
      request_id: $rid,
      depth: $depth,
      adversaries: $adv,
      target: $target,
      sources: { principles: $principles, accumulated_phases: $acc },
      concession_threshold: $conc,
      project_class: $pc
    }' > "$req_path"

  echo "$req_path"
}
```

- [ ] **Step 4: Run, all pass**

Expected: 22 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/compose.sh scaffold-onboard/tests/test-compose.sh
git commit -m "scaffold-onboard: build critic request envelope (Phase F)"
```

### Task TF.7: Critic invocation + mock outbox response

**Files:**
- Modify: `scaffold-onboard/lib/compose.sh`
- Modify: `scaffold-onboard/tests/test-compose.sh`

- [ ] **Step 1: Append failing test (uses a mock outbox)**

Append to `tests/test-compose.sh`:

```bash
test_critic_dispatch_with_mock_outbox() {
  echo "test_critic_dispatch_with_mock_outbox:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-m" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  echo "test content" > MASTER-SPEC.md
  sf_state_init
  sf_state_write_answer "1.3.1" "CLI tool"

  # Build request
  local req_path
  req_path="$(sf_compose_build_critic_request "premise-audit" 5)"
  local request_id
  request_id="$(jq -r .request_id "$req_path")"

  # Mock: write a response to the outbox manually (simulating critic)
  local critic_dir
  critic_dir="$(jq -r '.plugins["architect-critic"].data_dir' "$CLAUDE_PLUGIN_DATA/composition.json")"
  mkdir -p "$critic_dir/outbox"
  jq -n --arg rid "$request_id" '{
    request_id: $rid,
    adversaries_used: ["claude"],
    challenges: [
      {severity:"premise", text:"Test challenge", references:["Phase 5.2"]}
    ],
    gaps: [],
    divergences: [],
    elapsed_ms: 25000
  }' > "$critic_dir/outbox/${request_id}.json"

  # Wait/read the response (no real wait — mock is already there)
  local response_json
  response_json="$(sf_compose_read_critic_response "$request_id" 5)"
  local num_challenges
  num_challenges="$(echo "$response_json" | jq '.challenges | length')"
  assert_eq "challenge count" "1" "$num_challenges"
}

test_critic_response_timeout() {
  echo "test_critic_response_timeout:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-m" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  # No outbox response, short timeout
  local result ec
  set +e
  result="$(sf_compose_read_critic_response "nonexistent-id" 2 2>&1)"
  ec=$?
  set -e 2>/dev/null || true
  assert_eq "timeout exits non-zero" "1" "$ec"
}

test_critic_dispatch_with_mock_outbox
test_critic_response_timeout
```

- [ ] **Step 2: Run, fail**

Expected: `sf_compose_read_critic_response: command not found`.

- [ ] **Step 3: Implement response reader with timeout**

Append to `lib/compose.sh`:

```bash
# Read a critic response from the outbox by request_id, with a polling timeout.
# Args: <request_id> <timeout_seconds>
# Echoes the response JSON on success; returns 1 on timeout.
sf_compose_read_critic_response() {
  local request_id="$1" timeout_s="$2"
  local comp critic_dir outbox_path
  comp="$(sf_compose_path)"
  critic_dir="$(jq -r '.plugins["architect-critic"].data_dir // ""' "$comp")"
  [[ -z "$critic_dir" ]] && return 1
  outbox_path="$critic_dir/outbox/${request_id}.json"

  local elapsed=0
  while [[ "$elapsed" -lt "$timeout_s" ]]; do
    if [[ -f "$outbox_path" ]]; then
      cat "$outbox_path"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed+1))
  done
  sf_log_warn "Critic response timeout for request $request_id (waited ${timeout_s}s)"
  return 1
}
```

- [ ] **Step 4: Run, all pass**

Expected: 24 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/compose.sh scaffold-onboard/tests/test-compose.sh
git commit -m "scaffold-onboard: critic response reader with timeout (Phase F)"
```

### Task TF.8: User override toggles in `composition.json`

**Files:**
- Modify: `scaffold-onboard/lib/compose.sh`
- Modify: `scaffold-onboard/tests/test-compose.sh`

- [ ] **Step 1: Append failing tests**

Append to `tests/test-compose.sh`:

```bash
test_user_override_disable_mentor() {
  echo "test_user_override_disable_mentor:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-z" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  # Flip the user override
  sf_compose_set_override "disable_mentor_suggestions" true
  local hint
  hint="$(sf_compose_mentor_hint 5)"
  assert_eq "override disables hint" "" "$hint"
}

test_user_override_survives_refresh() {
  echo "test_user_override_survives_refresh:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-z" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  sf_compose_set_override "disable_critic" true
  sf_compose_refresh  # second refresh — should preserve overrides
  local v
  v="$(jq -r '.user_overrides.disable_critic' "$CLAUDE_PLUGIN_DATA/composition.json")"
  assert_eq "override preserved" "true" "$v"
}

test_user_override_disable_mentor
test_user_override_survives_refresh
```

- [ ] **Step 2: Run, fail**

Expected: `sf_compose_set_override: command not found`.

- [ ] **Step 3: Implement override setter + refresh preservation**

Update `sf_compose_refresh` in `lib/compose.sh` to preserve overrides:

Replace the `jq -n ...` block in `sf_compose_refresh` with this version that reads existing overrides first:

```bash
sf_compose_refresh() {
  local path tmp now
  path="$(sf_compose_path)"
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${path}.XXXXXX")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local mentor_dir critic_dir superpowers_dir brainstorming
  mentor_dir="$(sf_compose_detect_ai_mentor)"
  critic_dir="$(sf_compose_detect_architect_critic)"
  superpowers_dir="$(sf_compose_detect_superpowers)"
  brainstorming="$(sf_compose_brainstorming_available)"

  # Preserve existing user_overrides if composition.json exists
  local overrides_json
  if [[ -f "$path" ]]; then
    overrides_json="$(jq '.user_overrides // {}' "$path")"
  else
    overrides_json='{"disable_mentor_suggestions":false,"disable_critic":false,"disable_superpowers_subskill":false}'
  fi

  jq -n \
    --arg now "$now" \
    --arg mentor "$mentor_dir" \
    --arg critic "$critic_dir" \
    --arg sp "$superpowers_dir" \
    --arg br "$brainstorming" \
    --argjson overrides "$overrides_json" \
    '{
      detected_at: $now,
      plugins: {
        "ai-mentor": {
          installed: ($mentor != ""),
          data_dir: $mentor,
          state_file: (if $mentor != "" then ($mentor + "/state.json") else "" end)
        },
        "architect-critic": {
          installed: ($critic != ""),
          data_dir: $critic,
          principles_file: (if $critic != "" then ($critic + "/principles.md") else "" end),
          command: "/critique"
        },
        "superpowers": {
          installed: ($sp != ""),
          skills_dir: (if $sp != "" then ($sp + "/skills") else "" end),
          brainstorming_available: ($br == "true")
        }
      },
      user_overrides: ($overrides | . + {
        disable_mentor_suggestions: (.disable_mentor_suggestions // false),
        disable_critic: (.disable_critic // false),
        disable_superpowers_subskill: (.disable_superpowers_subskill // false)
      })
    }' > "$tmp"
  mv "$tmp" "$path"
}

# Set a user override toggle. Args: <key> <true|false>
sf_compose_set_override() {
  local key="$1" value="$2"
  local path tmp
  path="$(sf_compose_path)"
  [[ -f "$path" ]] || sf_compose_refresh
  tmp="$(mktemp "${path}.XXXXXX")"
  if [[ "$value" == "true" || "$value" == "false" ]]; then
    jq --arg k "$key" --argjson v "$value" '.user_overrides[$k] = $v' "$path" > "$tmp"
  else
    sf_log_error "override value must be true or false, got: $value"
    rm -f "$tmp"
    return 1
  fi
  mv "$tmp" "$path"
}
```

- [ ] **Step 4: Run, all pass**

Expected: 26 passed.

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/lib/compose.sh scaffold-onboard/tests/test-compose.sh
git commit -m "scaffold-onboard: user override toggles preserved across refresh (Phase F)"
```

### Task TF.9: Phase F close — run all suites

- [ ] **Step 1: Run all Phase A–F test suites**

```bash
for t in scaffold-onboard/tests/test-state.sh \
         scaffold-onboard/tests/test-parser.sh \
         scaffold-onboard/tests/test-render.sh \
         scaffold-onboard/tests/test-memory-bank.sh \
         scaffold-onboard/tests/test-docs.sh \
         scaffold-onboard/tests/test-compose.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```

Expected: every suite exits 0; cumulative ~105+ tests passing.

- [ ] **Step 2: Update CHANGELOG**

Append to `scaffold-onboard/CHANGELOG.md` under `## [Unreleased]` / `### Added`:

```
- Phase F: lib/compose.sh with probe-path detection for ai-mentor / architect-critic / superpowers; composition.json caching with user-override toggles preserved across refresh; SessionStart hook (source-aware) refreshing composition.json on startup/clear and preserving on resume/compact; ai-mentor + brainstorming hint emitters; critic request envelope build per SPEC §8.3; critic response reader with timeout. ~26 tests in test-compose.sh.
```

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/CHANGELOG.md
git commit -m "scaffold-onboard: Phase F complete — cross-cutting integration"
```

---

## Phase G — End-to-end tests + polish

After Phase G: full pipeline runs cleanly on a fresh repo, on an existing repo with prior artifacts, and survives interruption + resume. README polished, CHANGELOG complete, all suites green.

### Task TG.1: E2E — fresh repo, scripted onboarding to first slice readiness

**Files:**
- Create: `scaffold-onboard/tests/test-e2e.sh`

- [ ] **Step 1: Write the test**

```bash
#!/usr/bin/env bash
# End-to-end tests for scaffold-onboard.
# Each test runs the full bash pipeline (onboard helpers → scaffold-project →
# scaffold-docs) against a fresh tmp repo with scripted answers.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/parser.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/memory-bank.sh"
source "$HERE/../lib/docs.sh"
source "$HERE/../lib/compose.sh"

PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Scripted answers for a representative CLI project (no LLM, no UI).
script_answers_cli() {
  sf_state_write_answer "1.1.1" "todo-cli — fast local-first task manager"
  sf_state_write_answer "1.1.2" "Existing managers are heavy and cloud-coupled."
  sf_state_write_answer "1.1.3" "Solo devs adopt as their default task tool."
  sf_state_write_answer "1.2.1" "Solo devs and ops engineers."
  sf_state_write_answer "1.2.2" "Add a task, see what's pending, mark done — all under 200ms."
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "1.3.2" "add / list / complete tasks; persist to ~/.todo.json; tab-complete."
  sf_state_write_answer "2.1.1" "4 weeks"
  sf_state_write_answer "2.1.2" "Solo"
  sf_state_write_answer "2.2.1" "0 (no hosted infra)"
  sf_state_write_answer "2.2.2" "tech: dep drift; market: niche; resource: solo bandwidth"
  sf_state_write_answer "2.3.1" "Daily use by 1 user for 4 weeks."
  sf_state_write_answer "3.1.1" "Task, Project (optional)"
  sf_state_write_answer "3.1.2" "Task(id, title, status, due); Project(id, name)"
  sf_state_write_answer "3.2.1" "Project has many Tasks"
  sf_state_write_answer "3.3.1" "task, project, done, due"
  sf_state_write_answer "4.1.1" "none"
  sf_state_write_answer "4.1.2" "none"
  sf_state_write_answer "4.2.1" "none"
  sf_state_write_answer "4.2.2" "single-tenant (local only)"
  sf_state_write_answer "4.3.1" "local only"
  sf_state_write_answer "5.1.1" "CLI"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "5.2.2" "file (~/.todo.json)"
  sf_state_write_answer "5.3.1" "single user, <1MB data"
  sf_state_write_answer "5.3.2" "<200ms per command"
  sf_state_write_answer "6A.1.1" "CLI"
  sf_state_write_answer "6A.1.2" "todo add 'feed cat' → todo list → todo done 1"
  sf_state_write_answer "7.1.1" "src/{cli,store,model}"
  sf_state_write_answer "7.1.2" "statically typed Rust"
  sf_state_write_answer "8.1.1" "cargo"
  sf_state_write_answer "8.2.1" "GitHub Actions"
  sf_state_write_answer "8.2.2" "dev only"
  sf_state_write_answer "8.3.1" "self-hosted (binary release)"
  sf_state_write_answer "9.1.1" "80%"
  sf_state_write_answer "9.1.2" "unit, integration"
  sf_state_write_answer "9.2.1" "tests pass, cargo clippy clean"
  sf_state_write_answer "9.3.1" "no"
  sf_state_write_answer "10.1.1" "direct"
  sf_state_write_answer "10.3.1" "solo / business hours"
}

run_full_pipeline_cli() {
  sf_state_init
  script_answers_cli
  local tmpl="$PLUGIN_ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  sf_master_spec_init "$tmpl" "todo-cli" "CLI tool"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done
  sf_state_write_atomic status complete
  sf_memory_bank_derive
  sf_claude_md_generate
  sf_claude_settings_generate
  sf_docs_derive
}

test_e2e_fresh_repo_cli() {
  echo "test_e2e_fresh_repo_cli:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  run_full_pipeline_cli
  # MASTER-SPEC artifacts
  assert_file_exists "./MASTER-SPEC.md"
  assert_exit_code 0 sf_spec_validate ./MASTER-SPEC.md
  # Memory bank
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 05-active-context 06-progress 07-constraints 08-governance index WORKFLOW; do
    assert_file_exists "./.claude/memory-bank/${f}.md"
  done
  # CLAUDE.md
  assert_file_exists "./CLAUDE.md"
  assert_file_contains "./CLAUDE.md" "todo-cli"
  assert_file_contains "./CLAUDE.md" "Tier 0"
  # Settings
  assert_file_exists "./.claude/settings.json"
  # Default docs
  assert_file_exists "./docs/PRD.md"
  assert_file_exists "./docs/SRS.md"
  assert_file_exists "./docs/BACKLOG.md"
  assert_file_exists "./docs/PROJECT_PLAN.md"
  assert_file_exists "./docs/adr/0001-record-architecture-decisions.md"
  # No --full docs
  assert_file_missing "./docs/RISK_REGISTER.md"
  assert_file_missing "./docs/EVALS_PLAN.md"
}

test_e2e_full_mode() {
  echo "test_e2e_full_mode:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  run_full_pipeline_cli
  sf_docs_derive --full
  assert_file_exists "./docs/RISK_REGISTER.md"
  assert_file_exists "./docs/TEST_STRATEGY.md"
  assert_file_exists "./docs/CUTOVER_PLAN.md"
  # LLM-gated still skipped (this project says no LLMs)
  assert_file_missing "./docs/EVALS_PLAN.md"
}

test_e2e_fresh_repo_cli
test_e2e_full_mode
report_results
```

- [ ] **Step 2: Run, all pass**

Run: `bash scaffold-onboard/tests/test-e2e.sh`
Expected: ~25 assertions passing (16 file_exists + 4 file_contains + 5 file_missing-or-passes).

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/tests/test-e2e.sh
git commit -m "scaffold-onboard: E2E test on fresh CLI repo (Phase G)"
```

### Task TG.2: E2E — existing repo with prior CLAUDE.md + docs

**Files:**
- Modify: `scaffold-onboard/tests/test-e2e.sh`

- [ ] **Step 1: Append failing test**

Append before `report_results`:

```bash
test_e2e_existing_repo_preserves_user_files() {
  echo "test_e2e_existing_repo_preserves_user_files:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  # Pre-seed user-authored files BEFORE running scaffold-onboard
  mkdir -p docs/adr
  echo "# My existing PRD" > docs/PRD.md
  echo "# Pre-existing ADR" > docs/adr/0001-record-architecture-decisions.md
  echo "# Existing settings note" > .claude_user_note  # canary

  run_full_pipeline_cli

  # docs/PRD.md is in docs-minimal — preserved unless --regenerate
  assert_file_contains "./docs/PRD.md" "My existing PRD"
  # ADR-0001 preserved
  assert_file_contains "./docs/adr/0001-record-architecture-decisions.md" "Pre-existing ADR"
  # User's canary untouched
  assert_file_contains "./.claude_user_note" "Existing settings note"
}

test_e2e_regenerate_overwrites_docs() {
  echo "test_e2e_regenerate_overwrites_docs:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  echo "# My existing PRD" > docs/PRD.md 2>/dev/null || { mkdir -p docs; echo "# My existing PRD" > docs/PRD.md; }
  run_full_pipeline_cli
  sf_docs_derive --regenerate
  if grep -q "My existing PRD" docs/PRD.md; then
    FAIL=$((FAIL+1)); echo "  ✗ --regenerate did not overwrite"
  else
    PASS=$((PASS+1)); echo "  ✓ --regenerate overwrote existing PRD"
  fi
}

test_e2e_existing_repo_preserves_user_files
test_e2e_regenerate_overwrites_docs
```

- [ ] **Step 2: Run, all pass**

Expected: ~29 assertions passing in test-e2e.sh.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/tests/test-e2e.sh
git commit -m "scaffold-onboard: E2E existing-repo preservation (Phase G)"
```

### Task TG.3: E2E — resume after interruption

**Files:**
- Modify: `scaffold-onboard/tests/test-e2e.sh`

- [ ] **Step 1: Append failing test**

Append:

```bash
test_e2e_resume_mid_onboarding() {
  echo "test_e2e_resume_mid_onboarding:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"

  # Partial onboarding: answer phases 1-3 only, leave 4-10 unanswered
  sf_state_init
  sf_state_write_answer "1.1.1" "partial-proj"
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "2.2.2" "risks here"
  sf_state_write_answer "3.1.1" "Thing"
  sf_state_write_atomic current_phase 4

  # Mode check: should be "resume"
  local mode
  mode="$(sf_state_mode)"
  assert_eq "mode is resume" "resume" "$mode"

  # Current phase persisted
  local phase
  phase="$(sf_state_read_field current_phase)"
  assert_eq "phase 4 persisted" "4" "$phase"

  # Resume by answering remaining phases
  sf_state_write_answer "4.1.1" "none"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "9.3.1" "no"
  sf_state_write_atomic current_phase 10
  sf_state_advance_phase  # → status=complete

  local status
  status="$(sf_state_read_field status)"
  assert_eq "completed after resume" "complete" "$status"
}

test_e2e_resume_mid_onboarding
```

- [ ] **Step 2: Run, pass**

Expected: 32 assertions passing.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/tests/test-e2e.sh
git commit -m "scaffold-onboard: E2E resume after interruption (Phase G)"
```

### Task TG.4: E2E — with cross-cutting plugins detected (mock)

**Files:**
- Modify: `scaffold-onboard/tests/test-e2e.sh`

- [ ] **Step 1: Append failing test**

Append:

```bash
test_e2e_with_composition_mocked() {
  echo "test_e2e_with_composition_mocked:"
  setup_tmp_repo
  # Fake-install all three cross-cutting plugins
  mkdir -p "$TMP_DIR/fake-plugins/ai-mentor-x"
  : > "$TMP_DIR/fake-plugins/ai-mentor-x/state.json"
  mkdir -p "$TMP_DIR/fake-plugins/architect-critic-y"
  : > "$TMP_DIR/fake-plugins/architect-critic-y/principles.md"
  mkdir -p "$TMP_DIR/fake-plugins/superpowers-z/skills/brainstorming"
  : > "$TMP_DIR/fake-plugins/superpowers-z/skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"

  sf_compose_refresh
  run_full_pipeline_cli

  # CLAUDE.md should mention all three integrations
  assert_file_contains "./CLAUDE.md" "z2-decide"
  assert_file_contains "./CLAUDE.md" "/critique"
  assert_file_contains "./CLAUDE.md" "superpowers"

  # Mentor hint emits at Phase 5 + 7
  local hint5 hint7 hint2
  hint5="$(sf_compose_mentor_hint 5)"
  hint7="$(sf_compose_mentor_hint 7)"
  hint2="$(sf_compose_mentor_hint 2)"
  if [[ -n "$hint5" ]]; then PASS=$((PASS+1)); echo "  ✓ Phase 5 mentor hint emitted"; else FAIL=$((FAIL+1)); echo "  ✗ no Phase 5 mentor hint"; fi
  if [[ -n "$hint7" ]]; then PASS=$((PASS+1)); echo "  ✓ Phase 7 mentor hint emitted"; else FAIL=$((FAIL+1)); echo "  ✗ no Phase 7 mentor hint"; fi
  assert_eq "no Phase 2 hint" "" "$hint2"
}

test_e2e_with_composition_mocked
```

- [ ] **Step 2: Run, pass**

Expected: 36 assertions passing.

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/tests/test-e2e.sh
git commit -m "scaffold-onboard: E2E with cross-cutting plugins mocked (Phase G)"
```

### Task TG.5: README polish

**Files:**
- Modify: `scaffold-onboard/README.md`

- [ ] **Step 1: Replace README with the full version**

```markdown
# scaffold-onboard

Run-once project onboarding plugin for Claude Code. Walks you through 10 expert-role phases (~54 questions) to author `MASTER-SPEC.md`, then deterministically derives a `.claude/memory-bank/` (11 files), a tiered `CLAUDE.md` session-start router, and 5 (or 14 with `--full`) governance docs.

Composes with `ai-mentor` (cognitive mode), `architect-critic` (anti-sycophancy review), and `superpowers` (visual brainstorming + skills library) if installed — but works fully standalone.

## Install

```
/plugin marketplace add github:draco28/claude-agent-scaffolding
/plugin install scaffold-onboard@claude-agent-scaffolding
```

## Quick start

```
cd <your-new-project>
git init
> /onboard                              # ~30–45 min · authors MASTER-SPEC.md
> /scaffold-project                     # ~10s · derives memory-bank + CLAUDE.md
> /scaffold-docs                        # ~10s · derives 5 governance docs
> /scaffold-docs --full                 # +9 governance docs (3 LLM-gated)
```

After that, install and use the companion `scaffold` plugin for slice-driven implementation work.

## Commands

| Command | What it does | Time |
|---|---|---|
| `/onboard` | Guided 10-phase conversation; produces `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md` | ~30–45 min |
| `/scaffold-project [--force]` | Derives `.claude/memory-bank/` (11 files) + `CLAUDE.md` + `.claude/settings.json` | ~10s |
| `/scaffold-docs [--full] [--regenerate]` | Derives `docs/PRD.md`, `SRS.md`, `BACKLOG.md`, `PROJECT_PLAN.md`, `adr/0001-*.md` (`--full` adds 9 more) | ~10s |

## How it works

`MASTER-SPEC.md` is the **single source of truth**. Memory-bank and governance docs derive from it deterministically. Re-running a derive command after editing `MASTER-SPEC.md` regenerates derived files; live files (`05-active-context.md`, `06-progress.md`, `WORKFLOW.md`) are preserved.

The 10 phases mirror the ProjectPulse expert-role taxonomy: Foundation → Strategy → Domain & Data → Security → Architecture → UX → Implementation → DevOps → Quality → Operations. Each phase has 3–7 questions. Phase 1's project-class enum drives branching gates in later phases (UI vs DX, BE vs FE vs lib, LLM-eval vs not).

Soft composition with cross-cutting plugins is opportunistic — scaffold-onboard probes installed plugins at session start, caches results in `composition.json`, and emits hints / dispatches critic requests when relevant. See `docs/SPEC-scaffold-onboard.md` for the full design and `docs/PLAN-scaffold-onboard.md` for the implementation plan.

## Platforms

Linux and macOS. Windows is deferred (matches sibling plugins).

## Status

v0.1.0 — design spec at `docs/SPEC-scaffold-onboard.md`; implementation plan at `docs/PLAN-scaffold-onboard.md`.

## License

MIT — see `LICENSE`.
```

- [ ] **Step 2: Commit**

```bash
git add scaffold-onboard/README.md
git commit -m "scaffold-onboard: README polish (Phase G)"
```

### Task TG.6: Phase G close — full test sweep

- [ ] **Step 1: Run every suite**

```bash
for t in scaffold-onboard/tests/test-state.sh \
         scaffold-onboard/tests/test-parser.sh \
         scaffold-onboard/tests/test-render.sh \
         scaffold-onboard/tests/test-memory-bank.sh \
         scaffold-onboard/tests/test-docs.sh \
         scaffold-onboard/tests/test-compose.sh \
         scaffold-onboard/tests/test-e2e.sh; do
  echo "=== $t ==="
  bash "$t" || exit 1
done
```

Expected: every suite exits 0; cumulative ~140+ tests passing across seven suites.

- [ ] **Step 2: Update CHANGELOG `## [Unreleased]` → `## [0.1.0]`**

Rewrite the CHANGELOG:

```markdown
# Changelog

All notable changes to scaffold-onboard documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [0.1.0] — 2026-05-12

### Added
- Plugin scaffold (Phase A) — manifest, LICENSE, README, CHANGELOG, command stubs, hook + lib skeletons, test helpers.
- lib/state.sh, lib/parser.sh, lib/render.sh (Phase B) — state CRUD with atomic writes + lock file, MASTER-SPEC.md parser with three primitives + 7 validation rules, template substitution with `{{key}}` + `{{#if}}` blocks.
- phases.yaml (10 phases, ~54 questions, branching gates), MASTER-SPEC + EXECUTIVE-SUMMARY templates, /onboard command with conversational protocol body, state advance + gate evaluation + mode detection + phases.yaml reader (Phase C).
- 11 memory-bank templates (00–08, index, WORKFLOW), CLAUDE.md template (Tier 0 + branch routing + plugin awareness), .claude/settings.json template, lib/memory-bank.sh with derive + CLAUDE.md generation + live-file preservation + --force, /scaffold-project command (Phase D).
- 14 governance doc templates (5 default + 9 --full, 3 LLM-project-gated), lib/docs.sh with default + --full derivation + --regenerate override, /scaffold-docs command (Phase E).
- lib/compose.sh with probe-path detection for ai-mentor / architect-critic / superpowers, composition.json caching with user-override toggles preserved across refresh, SessionStart hook (source-aware), mentor + brainstorming hint emitters, critic request envelope per SPEC §8.3, critic response reader with timeout (Phase F).
- ~140 tests across 7 bash test suites covering state, parser, render, memory-bank, docs, compose, and end-to-end pipelines on fresh + existing repos including resume after interruption and cross-cutting composition.

### Composition
- Composes with `ai-mentor`, `architect-critic`, `superpowers`. Works standalone if any are absent.
```

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/CHANGELOG.md
git commit -m "scaffold-onboard: Phase G complete — E2E + polish, v0.1.0 ready"
```

---

## Phase H — Publish v0.1.0

After Phase H: scaffold-onboard is listed in the marketplace and installable via the standard `/plugin install` flow.

### Task TH.1: Verify manifest + bump confirmation

**Files:**
- Verify: `scaffold-onboard/.claude-plugin/plugin.json`

- [ ] **Step 1: Confirm manifest version is 0.1.0**

Run: `jq -r .version scaffold-onboard/.claude-plugin/plugin.json`
Expected: `0.1.0` (set in Task TA.1; this step verifies no later task accidentally changed it).

If for any reason it isn't `0.1.0`, fix and commit:

```bash
jq '.version = "0.1.0"' scaffold-onboard/.claude-plugin/plugin.json > /tmp/m.json && mv /tmp/m.json scaffold-onboard/.claude-plugin/plugin.json
git add scaffold-onboard/.claude-plugin/plugin.json
git commit -m "scaffold-onboard: pin manifest version 0.1.0 (Phase H)"
```

### Task TH.2: Add to marketplace.json

**Files:**
- Modify: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Add scaffold-onboard entry to the plugins array**

Edit `.claude-plugin/marketplace.json`. The current file has two entries (`ai-mentor`, `scaffold`). Add a third entry between them or at the end:

```json
{
  "name": "scaffold-onboard",
  "description": "Project onboarding via 10-phase guided conversation. Authors MASTER-SPEC.md as source of truth; derives 11-file memory-bank, tiered CLAUDE.md router, and 5/14 governance docs. Soft-composes with ai-mentor (cognitive mode) and architect-critic (anti-sycophancy review). Run-once per project; complements the `scaffold` plugin which owns slice-driven implementation.",
  "category": "workflow",
  "source": "./scaffold-onboard"
}
```

The final `marketplace.json` should look like:

```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "claude-agent-scaffolding",
  "description": "Personal plugin marketplace: AI Mentor (cognitive partner), scaffold-onboard (run-once project bootstrap), and scaffold (slice-driven implementation workflow).",
  "owner": {
    "name": "Pras"
  },
  "plugins": [
    {
      "name": "ai-mentor",
      "description": "Cognitive partner — mechanically enforces spotter mode (Curve 2) via PreToolUse hook. Pillar 3 (Gym: /z2-decide, /z2-build, /locked, /quiz) + Pillar 4 (Fool: /eli10, /fool).",
      "category": "productivity",
      "source": "./ai-mentor"
    },
    {
      "name": "scaffold-onboard",
      "description": "Project onboarding via 10-phase guided conversation. Authors MASTER-SPEC.md as source of truth; derives 11-file memory-bank, tiered CLAUDE.md router, and 5/14 governance docs. Soft-composes with ai-mentor (cognitive mode) and architect-critic (anti-sycophancy review). Run-once per project; complements the `scaffold` plugin which owns slice-driven implementation.",
      "category": "workflow",
      "source": "./scaffold-onboard"
    },
    {
      "name": "scaffold",
      "description": "Project-level workflow plugin. Bootstrap or audit any repo, run slice-driven 5-phase workflow (spec → contract → scaffold → implement → verify), manage living governance (ADRs, CHANGELOG, runbooks), and search a per-repo memory bank via Ollama-backed semantic recall (FTS5 fallback). Worktree-safe: state lives outside the working tree so parallel branches inherit/fork cleanly. 18 slash commands + 10 MCP tools.",
      "category": "workflow",
      "source": "./scaffold"
    }
  ]
}
```

- [ ] **Step 2: Validate marketplace.json**

Run: `jq . .claude-plugin/marketplace.json`
Expected: valid JSON, 3 plugin entries.

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "marketplace: add scaffold-onboard v0.1.0 (Phase H)"
```

### Task TH.3: Update top-level README + final tag

**Files:**
- Modify: `README.md` (repo root)
- Tag: `scaffold-onboard-v0.1.0`

- [ ] **Step 1: Update root README plugin table**

In `README.md` at repo root, update the plugin table. Existing rows for `ai-mentor` and `scaffold` stay; add a row for `scaffold-onboard` between them. The new table:

```markdown
| Plugin | Version | Scope | Purpose |
|---|---|---|---|
| [`ai-mentor`](./ai-mentor/) | v1.3.0 | User-level | Cognitive partner. Pillar 3 (Gym/spotter) with two Curve-2 sub-modes (`/z2-decide` and `/z2-build`) + Pillar 4 (Fool/beginner's mind). Mechanically enforces spotter mode via PreToolUse hook + state file. |
| [`scaffold-onboard`](./scaffold-onboard/) | v0.1.0 | Project-level (run-once) | Onboarding plugin. 10-phase guided conversation authors `MASTER-SPEC.md`; deterministic derivation produces an 11-file memory-bank, a tiered `CLAUDE.md` router, and 5/14 governance docs. Soft-composes with ai-mentor + architect-critic. |
| [`scaffold`](./scaffold/) | v1.0.0 | Project-level (continuous) | Implementation plugin. Slice-driven 5-phase workflow, living governance (ADRs, CHANGELOG, runbooks), per-repo memory bank with semantic search. 18 slash commands + 10 MCP tools. |
```

Also update the "Plugins" intro paragraph just below the table to mention the three-plugin lineup:

```markdown
The three plugins are designed to **compose without overlap**: `ai-mentor` enforces *cognitive mode* (when AI types vs when you do); `scaffold-onboard` runs once per project to author the source-of-truth spec and derive its scaffolding; `scaffold` owns the continuous slice-by-slice implementation phase. Disjoint slash command namespaces, distinct state paths.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: surface scaffold-onboard in root README (Phase H)"
```

- [ ] **Step 3: Tag the release**

```bash
git tag -a scaffold-onboard-v0.1.0 -m "scaffold-onboard v0.1.0 — onboarding plugin, soft-composes with ai-mentor + architect-critic"
git tag
```

Expected: `scaffold-onboard-v0.1.0` appears in the tag list.

- [ ] **Step 4: Push (user-confirmed)**

Push only when the user is ready — this publishes to GitHub.

```bash
git push origin main
git push origin scaffold-onboard-v0.1.0
```

Expected: both push successfully. The marketplace entry becomes installable via `/plugin install scaffold-onboard@claude-agent-scaffolding`.

---

## Plan complete

After all phases (A through H), the deliverable is:
- `scaffold-onboard/` plugin (~140 tests passing across 7 bash suites)
- `docs/SPEC-scaffold-onboard.md` (design spec) and `docs/PLAN-scaffold-onboard.md` (this file)
- Updated marketplace.json and root README
- v0.1.0 tag pushed

**Coverage check against the spec:**

| Spec section | Covered by |
|---|---|
| §4 Architecture | Phase A (TA.1–TA.5) — plugin manifest + directory layout + hook + lib skeletons |
| §5.1 `/onboard` | Phase C (TC.1–TC.10) — phases.yaml, master-spec templates, state machine, conversational protocol |
| §5.2 `/scaffold-project` | Phase D (TD.1–TD.9) — 11 memory-bank templates, CLAUDE.md template, lib/memory-bank.sh, command |
| §5.3 `/scaffold-docs` | Phase E (TE.1–TE.7) — 14 doc templates, lib/docs.sh with LLM-gating + preservation, command |
| §6 MASTER-SPEC schema + parser | Phase B (TB.5–TB.8) — parser primitives + validation |
| §7.1 Memory-bank taxonomy | Phase D (TD.1–TD.2) — 11 templates with derived/live/static split |
| §7.2 CLAUDE.md Tier 0 + branch | Phase D (TD.3, TD.7) — template + lib/memory-bank.sh:sf_claude_md_generate |
| §7.3 Governance docs | Phase E (TE.1–TE.3) — 5 default + 9 --full templates |
| §7.4 Template grammar | Phase B (TB.9–TB.10) — sf_render with `{{key}}` + `{{#if}}` |
| §8 Cross-cutting integration | Phase F (TF.1–TF.9) — compose.sh detection + composition.json + hint emitters + critic envelope |
| §9 Architect-critic Q1–Q5 | Phase F (TF.5–TF.8) — Q1 selective-per-phase encoded in mentor_hint phases, Q2 codex at close encoded in build_critic_request, Q4 concession_threshold=4 baked into request, Q5 principles path passed in sources |
| §10 Error handling | Throughout — error paths covered in lib functions and tests (validation failures, missing files, timeouts, lock-file refusal) |
| §11 Edge cases | Phase G (TG.1–TG.4) — fresh repo, existing repo, resume, composition |
| §12 Testing strategy | All test suites totaling ~140 tests across 7 files |
| §13 Build sequence | The phases of this plan map 1:1 with the spec's build sequence A–H |
| §14 Risks | R1 (skip flag), R2 (Codex fallback), R3 (one-time cost), R4 (spec version), R5 (compose refresh) all addressed in implementations |
| §15 Open questions | Auto-promotion deferred per spec; surfaces in compose.sh's user_overrides for future expansion |

No spec requirement is uncovered. The plan is ready for execution.
