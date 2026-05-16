# architect-critic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `architect-critic` plugin per `docs/SPEC-architect-critic.md` — anti-sycophancy reviewer that runs claude-self-audit + (optionally) codex fresh-frame audit, consolidates challenges/gaps/divergences, presents interactively with T=4 concession scoring, and auto-promotes recurring patterns to user-global `principles.md`. File-IPC counterparty to `scaffold-onboard` at Phase 5/7/close.

**Architecture:** Single Claude Code plugin under `architect-critic/` in this marketplace. Bash orchestration end-to-end (no Python, no MCP server). Ten `lib/` modules with single responsibilities. Templates as data. Ten bash test suites mirroring `scaffold-onboard` v0.1.0's pattern. One SessionStart hook for housekeeping.

**Tech Stack:** Bash 4+ on Linux / bash 3.2 on macOS (`set -u`, `[[ ]]`), `sed`/`awk` for text manipulation, `jq` for JSON manipulation (state files + envelopes), plain bash assertions for tests. Codex CLI dispatched as subprocess (with `timeout(1)` wrapper); mocked via PATH override for hermetic tests. **Implementation uses macOS-portable subset:** BSD awk (no gawk `match(...)` 3-arg form — see Portability notes), bash 3.2 (no `declare -A` — parallel indexed arrays instead).

---

## Implementation Status — v0.1.0 SHIPPED 2026-05-16

> All 8 phases A–H complete. This section preserves the final state for archaeology and a v0.2 baseline.

**Release tag:** `architect-critic-v0.1.0` (pending push to origin pending user confirmation). Branch `implementation-architect-critic` ready to fast-forward merge to `main`.

**Final regression: 244 architect-critic tests + 163 scaffold-onboard tests (regression-green per HANDOFF §7) = 407 total across both plugins.**

**Build history:** Branch `implementation-architect-critic` forked from `main` at `67fd0b6` (PLAN commit). Phase-by-phase TDD subagent dispatches for Phases B–D logic-bearing work; main-session-inline for Phases A and E–H (after agent runtime instability — 2 socket-close + 1 stream-timeout events in TE.1/TE.3/TD.6 reviewer dispatches; pragmatic switch to inline execution when subagent retries cost more tokens than the work itself).



> Update this section after each phase-close. This is the canonical resume point for compaction recovery and fresh-session pickup.

**Branch:** `implementation-architect-critic` (forked from `main` at HEAD post-`a6de55b` "architect-critic: v0.1 design spec" + the PLAN commit that this file is part of).

**Phase summary:**

| Phase | Status | Tasks | Cumulative tests | Phase-close commit |
|---|---|---|---|---|
| A · plugin scaffold | ✅ done | TA.1–TA.5 | 0 (helpers seeded) | (close commit below) |
| B · state + principles + inbox | ✅ done | TB.1–TB.3 | 78 | (close commit below) |
| C · slash command bodies | ✅ done | TC.1–TC.5 (+2 fix-ups) | 103 | (close commit below) |
| D · codex + consolidator + scorer + outbox + cost | ✅ done | TD.1–TD.6 | 184 | (close commit below) |
| E · auto-promotion (FULL) | ✅ done | TE.1–TE.7 | 216 | (close commit below) |
| F · hooks + scaffold-onboard delta (OQ-2) | ✅ done | TF.1, TF.2, TF.4, TF.5 (TF.3 N/A) | 219 | (close commit below) |
| G · E2E + polish + hardening | ✅ done | TG.1–TG.5 (TG.5 doc-only; shellcheck unavailable on host) | 244 | (close commit below) |
| H · v0.1.0 publish | ✅ done (push gated) | TH.1–TH.3 | 244 | (close commit + tag pending) |

**Total tasks:** 39 (consolidated from the meta-plan's ~67-task estimate; each task is atomic — one commit per task — but spans multiple sub-libraries where they share a test suite). The implementer subagent can split a task into smaller intra-task TDD increments (red→green per function, then one task-close commit). **Target test count:** ~120–160 across 10 bash suites.

---

## File Structure (locked before tasks)

```
architect-critic/
├── .claude-plugin/plugin.json
├── commands/
│   ├── critique.md
│   ├── critique-list.md
│   ├── promote-principle.md
│   └── principles-list.md
├── hooks/hooks.json
├── hooks-handlers/session-start.sh
├── lib/
│   ├── _helpers.sh
│   ├── state.sh
│   ├── principles.sh
│   ├── inbox.sh
│   ├── codex.sh
│   ├── consolidator.sh
│   ├── scorer.sh
│   ├── promotion.sh
│   ├── outbox.sh
│   └── cost.sh
├── templates/
│   └── principles.md
├── tests/
│   ├── _helpers.sh
│   ├── fixtures/
│   │   ├── mock-codex/codex                   # PATH-override mock binary
│   │   ├── codex-payloads/                    # canned codex JSON outputs
│   │   │   ├── 3-challenges.json
│   │   │   ├── empty.json
│   │   │   └── malformed.json
│   │   └── master-specs/                      # fixture MASTER-SPECs
│   │       └── tiny-spec.md
│   ├── test-state.sh
│   ├── test-principles.sh
│   ├── test-inbox.sh
│   ├── test-codex.sh
│   ├── test-consolidator.sh
│   ├── test-scorer.sh
│   ├── test-promotion.sh
│   ├── test-outbox.sh
│   ├── test-commands.sh
│   └── test-e2e.sh
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## Test Infrastructure (shared)

Every test suite sources `tests/_helpers.sh` (verbatim shape from scaffold-onboard's `tests/_helpers.sh`):

- `assert_eq <label> <expected> <actual>` — string equality
- `assert_file_exists <path>` — file exists
- `assert_file_missing <path>` — file does not exist
- `assert_file_contains <path> <pattern>` — file content matches regex
- `assert_exit_code <expected_code> <command...>` — command exits with code
- `setup_tmp_repo` — creates an isolated tmp dir, sets `CLAUDE_PLUGIN_DATA` to a tmp dir, `cd`s into a subdir, runs `git init`
- `cleanup` — registered with `trap` to remove tmp dir
- `setup_mock_codex [<payload-name>]` — prepends `tests/fixtures/mock-codex/` to PATH, sets `MOCK_CODEX_OUTPUT` env to the named payload (default `3-challenges.json`)

Tests increment `PASS`/`FAIL` counters. At end: print summary; exit non-zero if `FAIL > 0`.

`_helpers.sh` is implemented in **Task TA.5** below; every later test task assumes it exists.

---

## Portability notes (inherited verbatim from scaffold-onboard's PLAN)

**Target platforms:** macOS *and* Linux. Windows is deferred per `docs/SPEC-architect-critic.md` §3 NG5 (matches sibling plugins).

Three real-world patterns were discovered during scaffold-onboard's Phase B execution. They apply equally to architect-critic. **Apply these substitutions wherever the original pattern appears in task code blocks.**

### Adaptation 1 · BSD awk → portable `sub()` chains

macOS's default awk does **not** support gawk's 3-arg `match($0, /pattern/, arr)`. Use `sub()` chains.

**Avoid (gawk-only):** `match($0, /id=([0-9]+)/, arr); pid = arr[1]`

**Use instead (POSIX awk, works on both):**
```awk
line = $0
sub(/^.*id=/, "", line)
sub(/[^0-9].*$/, "", line)
pid = line
```

### Adaptation 2 · bash 3.2 → parallel indexed arrays

macOS's default bash is 3.2. It does **not** support `declare -A`. Use parallel indexed arrays + `_lookup_var` helper.

**Avoid:** `declare -A vars=(); vars[$key]="$val"; v="${vars[$k]}"`

**Use instead (bash 3.2+, works on both):**
```bash
var_keys=()
var_vals=()
var_keys+=("$key"); var_vals+=("$val")

_lookup_var() {
  local needle="$1" i
  for ((i=0; i<${#var_keys[@]}; i++)); do
    if [[ "${var_keys[$i]}" == "$needle" ]]; then
      printf '%s' "${var_vals[$i]}"; return 0
    fi
  done
  return 1
}
```

### Adaptation 3 · explicit cleanup before `return` (no `trap RETURN`)

bash 3.2 RETURN traps are unreliable. Use explicit release calls before each `return`:

```bash
my_func() {
  acquire_lock || return 1
  if some_check; then
    release_lock     # explicit before each return
    return 1
  fi
  do_work
  release_lock       # explicit before normal return
  return 0
}
```

### Where these matter in architect-critic phases

| Phase | Task | Pattern in plan code | Adaptation |
|---|---|---|---|
| B | TB.5 (principles parser) | `match($0, /^# /, ...)` | Adaptation 1 |
| D | TD.4 (consolidator dedup) | uses indexed `args=()` already — OK | (none) |
| D | TD.5 (scorer) | uses indexed arrays — OK | (none) |
| E | TE.3 (promotion topic clustering) | `match($0, /pattern/, arr)` | Adaptation 1 |
| F | TF.3 (state.json housekeeping) | uses jq + bash 3.2 lock pattern | Adaptation 3 |

When implementing these tasks, subagents should apply the substitution **before writing the code** rather than discovering at test time. The orchestrator prompt for affected tasks pre-flags the adaptation.

---

## Phase A — Plugin scaffold

Skeleton files only — no logic yet. Verifies the plugin manifest loads, directory structure is in place, license + readme exist.

### Task TA.1: Create plugin manifest

**Files:** Create `architect-critic/.claude-plugin/plugin.json`

- [ ] **Step 1:** `mkdir -p architect-critic/.claude-plugin`
- [ ] **Step 2:** Write `architect-critic/.claude-plugin/plugin.json`:

```json
{
  "name": "architect-critic",
  "version": "0.1.0",
  "description": "Anti-sycophancy reviewer. /critique runs claude-self-audit + (optionally) codex fresh-frame audit, consolidates into challenges/gaps/divergences, presents interactively with T=4 concession scoring, auto-promotes recurring patterns to user-global principles.md. File-based IPC counterparty to scaffold-onboard at Phase 5/7/close.",
  "author": { "name": "Pras" },
  "category": "workflow"
}
```

- [ ] **Step 3:** `jq . architect-critic/.claude-plugin/plugin.json` exits 0
- [ ] **Step 4:** Commit: `git add architect-critic/.claude-plugin/plugin.json && git commit -m "architect-critic: plugin manifest skeleton (Phase A)"`

### Task TA.2: Create LICENSE, README skeleton, CHANGELOG

**Files:** `architect-critic/{LICENSE,README.md,CHANGELOG.md}`

- [ ] **Step 1:** `cp scaffold-onboard/LICENSE architect-critic/LICENSE`
- [ ] **Step 2:** Write `architect-critic/README.md`:

```markdown
# architect-critic

Anti-sycophancy reviewer plugin for Claude Code. `/critique` runs a claude-self-audit + (optionally) a codex fresh-frame audit, consolidates findings, and presents challenges with the T=4 concession scoring rubric (1–5 against the bar; concedes only at ≥4). Recurring patterns are surfaced as candidates to promote into your user-global `principles.md`.

Composes with `scaffold-onboard` via file-based JSON IPC: at Phase 5/7 recap and at MASTER-SPEC close, scaffold-onboard's `/onboard` writes a request envelope to inbox, invokes `/critique` synchronously, and reads the response from outbox. Also usable standalone — `/critique` in any session synthesizes an envelope from defaults.

## Commands

- `/critique [--phase N] [--depth premise-audit|close] [--spec PATH]` — primary audit entry
- `/critique-list [--limit N]` — show recent runs + pending requests
- `/promote-principle "<text>" [--scope user|project]` — manually promote a principle
- `/principles-list` — render the merged principle set the next /critique would see

## Status

v0.1.0 — initial release.

## Platforms

macOS and Linux. Windows deferred (matches sibling plugins).

## License

MIT
```

- [ ] **Step 3:** Write `architect-critic/CHANGELOG.md`:

```markdown
# Changelog

## [Unreleased]

### Added
- Plugin scaffold (Phase A).
```

- [ ] **Step 4:** Commit: `git add architect-critic/{LICENSE,README.md,CHANGELOG.md} && git commit -m "architect-critic: LICENSE + README + CHANGELOG (Phase A)"`

### Task TA.3: Create empty command stubs

**Files:** `architect-critic/commands/{critique,critique-list,promote-principle,principles-list}.md`

- [ ] **Step 1:** `mkdir -p architect-critic/commands`
- [ ] **Step 2:** Write each stub. Example for `critique.md`:

```markdown
---
description: Run an architect-critic audit on a spec or plan with claude-self-audit + (optionally) codex fresh-frame review
allowed-tools: Bash, Read, Edit, SlashCommand
---

# /critique

(Phase C will replace this body with the real audit pipeline.)

Stub: prints "critique stub not yet implemented" and exits.
```

Repeat shape for `critique-list.md`, `promote-principle.md`, `principles-list.md` with descriptions matching SPEC §5.2/5.3/5.4.

- [ ] **Step 3:** Verify all 4 files exist: `ls architect-critic/commands/ | wc -l` → `4`
- [ ] **Step 4:** Commit: `git add architect-critic/commands/ && git commit -m "architect-critic: 4 command stubs (Phase A)"`

### Task TA.4: Create hook + lib skeletons + principles.md template

**Files:**
- `architect-critic/hooks/hooks.json`
- `architect-critic/hooks-handlers/session-start.sh`
- `architect-critic/lib/{_helpers,state,principles,inbox,codex,consolidator,scorer,promotion,outbox,cost}.sh` — empty stubs
- `architect-critic/templates/principles.md` — seed (D3 stub-with-examples)

- [ ] **Step 1:** Create directories: `mkdir -p architect-critic/{hooks,hooks-handlers,lib,templates}`
- [ ] **Step 2:** Write `architect-critic/hooks/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks-handlers/session-start.sh" }
        ]
      }
    ]
  }
}
```

- [ ] **Step 3:** Write `architect-critic/hooks-handlers/session-start.sh`:

```bash
#!/usr/bin/env bash
# Phase F will populate this with state.json housekeeping (clear stale in_flight markers >24h).
exit 0
```

`chmod +x architect-critic/hooks-handlers/session-start.sh`

- [ ] **Step 4:** Write `architect-critic/lib/_helpers.sh` with shared logging + jq guard helpers:

```bash
#!/usr/bin/env bash
# architect-critic shared helpers — sourced by every other lib.

ac_log_info()  { echo "[architect-critic INFO] $*" >&2; }
ac_log_warn()  { echo "[architect-critic WARN] $*" >&2; }
ac_log_error() { echo "[architect-critic ERROR] $*" >&2; }

# ${CLAUDE_PLUGIN_DATA} is set by Claude Code; fallback for tests.
ac_data_dir() {
  echo "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/architect-critic}"
}

# jq-then-mv guard: if jq succeeds, atomically mv tmp to target; else rm tmp.
# Args: <jq command pieces...> > tmp; then mv tmp target; else rm tmp; log; return 1
ac_guarded_jq_write() {
  local target="$1"; shift
  local tmp
  tmp="$(mktemp "${target}.XXXXXX")" || return 1
  if jq "$@" > "$tmp"; then
    mv "$tmp" "$target"
  else
    rm -f "$tmp"
    ac_log_error "jq failed during write to $target"
    return 1
  fi
}

# Lock-file pattern (mirror of scaffold-onboard's compose.lock).
# Args: <lock_path>
ac_lock_acquire() {
  local lock="$1"
  local i
  for ((i=0; i<5; i++)); do
    if ( set -o noclobber; > "$lock" ) 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  ac_log_warn "could not acquire lock $lock after 5s"
  return 1
}

ac_lock_release() {
  rm -f "$1"
}
```

- [ ] **Step 5:** Write empty stubs for the other 9 libs (`state.sh`, `principles.sh`, `inbox.sh`, `codex.sh`, `consolidator.sh`, `scorer.sh`, `promotion.sh`, `outbox.sh`, `cost.sh`) — each just a shebang + `# Phase X will populate this`.

- [ ] **Step 6:** Write `architect-critic/templates/principles.md` per SPEC §6.4 seed template (preamble + `## Your principles` + `## Examples (commented out)`).

- [ ] **Step 7:** Commit: `git add architect-critic/{hooks,hooks-handlers,lib,templates}/ && git commit -m "architect-critic: hook + lib + template skeletons (Phase A)"`

### Task TA.5: Create test helpers + fixtures dir

**Files:**
- `architect-critic/tests/_helpers.sh`
- `architect-critic/tests/fixtures/mock-codex/codex` (executable shell script)
- `architect-critic/tests/fixtures/codex-payloads/{3-challenges,empty,malformed}.json`
- `architect-critic/tests/fixtures/master-specs/tiny-spec.md`

- [ ] **Step 1:** `mkdir -p architect-critic/tests/fixtures/{mock-codex,codex-payloads,master-specs}`
- [ ] **Step 2:** Write `architect-critic/tests/_helpers.sh` (mirror of scaffold-onboard's `tests/_helpers.sh` shape):

```bash
#!/usr/bin/env bash
# architect-critic test helpers — sourced by every test suite.

PASS=0
FAIL=0
TMP_DIR=""

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✓ $label"; PASS=$((PASS+1))
  else
    echo "  ✗ $label: expected '$expected', got '$actual'"; FAIL=$((FAIL+1))
  fi
}

assert_file_exists() {
  if [[ -f "$1" ]]; then
    echo "  ✓ file exists: $1"; PASS=$((PASS+1))
  else
    echo "  ✗ file missing: $1"; FAIL=$((FAIL+1))
  fi
}

assert_file_missing() {
  if [[ ! -f "$1" ]]; then
    echo "  ✓ file absent: $1"; PASS=$((PASS+1))
  else
    echo "  ✗ file present: $1"; FAIL=$((FAIL+1))
  fi
}

assert_file_contains() {
  if grep -q "$2" "$1" 2>/dev/null; then
    echo "  ✓ file contains pattern in $1"; PASS=$((PASS+1))
  else
    echo "  ✗ file missing pattern in $1: $2"; FAIL=$((FAIL+1))
  fi
}

assert_exit_code() {
  local expected="$1"; shift
  set +e; "$@" >/dev/null 2>&1; local ec=$?; set -e 2>/dev/null || true
  if [[ "$ec" == "$expected" ]]; then
    echo "  ✓ exit code $expected for: $*"; PASS=$((PASS+1))
  else
    echo "  ✗ exit code $expected for: $* (got $ec)"; FAIL=$((FAIL+1))
  fi
}

setup_tmp_repo() {
  TMP_DIR="$(mktemp -d -t architect-critic-test.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  mkdir -p "$TMP_DIR/repo"
  cd "$TMP_DIR/repo" || exit 1
  git init -q
  echo "$TMP_DIR"
}

cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

setup_mock_codex() {
  local payload="${1:-3-challenges.json}"
  local fixtures_dir
  fixtures_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixtures" && pwd)"
  export PATH="$fixtures_dir/mock-codex:$PATH"
  export MOCK_CODEX_OUTPUT="$fixtures_dir/codex-payloads/$payload"
}

report_results() {
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
}
```

- [ ] **Step 3:** Write `architect-critic/tests/fixtures/mock-codex/codex` (the PATH-override mock):

```bash
#!/usr/bin/env bash
# Mock codex CLI for hermetic tests.
# Reads stdin (and ignores it). Echoes the JSON file at $MOCK_CODEX_OUTPUT to stdout.
# Exits 0 on success, 1 if MOCK_CODEX_OUTPUT not set or file missing.

cat > /dev/null   # consume stdin

if [[ -z "${MOCK_CODEX_OUTPUT:-}" ]]; then
  echo "mock-codex: MOCK_CODEX_OUTPUT not set" >&2
  exit 1
fi

if [[ ! -f "$MOCK_CODEX_OUTPUT" ]]; then
  echo "mock-codex: payload not found: $MOCK_CODEX_OUTPUT" >&2
  exit 1
fi

cat "$MOCK_CODEX_OUTPUT"
exit 0
```

`chmod +x architect-critic/tests/fixtures/mock-codex/codex`

- [ ] **Step 4:** Write canned codex payloads:

`tests/fixtures/codex-payloads/3-challenges.json`:
```json
{
  "challenges": [
    {"severity": "premise", "text": "Phase 5.2 lacks a fallback strategy for codex unavailability", "references": ["Phase 5.2"]},
    {"severity": "gap",     "text": "No mention of state.json schema migration", "references": ["Phase 6.3"]},
    {"severity": "alternative", "text": "Consider hash-based dedup instead of exact-match", "references": ["Phase 7.1"]}
  ],
  "gaps": [
    {"text": "Codex CLI auth flow not documented", "severity": "info"}
  ]
}
```

`tests/fixtures/codex-payloads/empty.json`:
```json
{"challenges": [], "gaps": []}
```

`tests/fixtures/codex-payloads/malformed.json`:
```
{not valid json at all
```

- [ ] **Step 5:** Write `tests/fixtures/master-specs/tiny-spec.md` — a minimal valid MASTER-SPEC with all 10 phase markers (mirror scaffold-onboard's parser fixture pattern, ~50 lines).

- [ ] **Step 6:** Verify mock-codex works: `MOCK_CODEX_OUTPUT=architect-critic/tests/fixtures/codex-payloads/empty.json architect-critic/tests/fixtures/mock-codex/codex < /dev/null | jq .` → `{"challenges": [], "gaps": []}`

- [ ] **Step 7:** Commit: `git add architect-critic/tests/ && git commit -m "architect-critic: test helpers + mock-codex fixture (Phase A)"`

### Phase A close

- [ ] Run a smoke check: `bash -n architect-critic/lib/*.sh architect-critic/hooks-handlers/*.sh architect-critic/tests/_helpers.sh` (all parse OK)
- [ ] Update Implementation Status: Phase A → ✅ done; cumulative tests = 0 (helpers seeded)
- [ ] Phase-close commit: `git commit --allow-empty -m "architect-critic: Phase A complete — plugin scaffold seeded"`

---

## Phase B — state + principles + inbox

Three lib modules + their test suites. End of phase: state.json schema works; principles.md loading + 4-source merge works; inbox envelope validates per SPEC §6.1.

### Task TB.1: lib/state.sh — state.json read/write

**Files:** `architect-critic/lib/state.sh`

Implement these functions:

- `ac_state_path()` — returns `$(ac_data_dir)/state.json`
- `ac_state_init()` — if state.json missing, write empty schema (`{schema_version:1, in_flight:[], recent_runs:[], principle_promotions:[], candidate_promotions:[], declined_candidates:[]}`)
- `ac_state_read()` — `cat $(ac_state_path)` (caller pipes to jq)
- `ac_state_write_field <jq_path> <value>` — atomic update via guarded_jq_write + ac_lock_acquire/release on `$(ac_data_dir)/state.lock`
- `ac_state_append_in_flight <request_id> <depth> <phase_id|null>` — push onto `.in_flight`
- `ac_state_remove_in_flight <request_id>` — filter out matching id
- `ac_state_append_recent_run <run_json>` — push to `.recent_runs`, then trim to last 20
- `ac_state_append_promotion <source> <text> <scope>` — push to `.principle_promotions`
- `ac_state_append_declined <text> <suppress_until>` — push to `.declined_candidates`

Use `ac_guarded_jq_write` for every write. Acquire/release `state.lock` around every write transaction.

- [ ] **Step 1:** Write the `lib/state.sh` implementation
- [ ] **Step 2:** Write `tests/test-state.sh` — ~15 tests covering: init creates schema, append+remove in_flight, recent_runs cap-20 trimming, principle_promotions append, declined_candidates with suppress_until, lock-file acquire/release, concurrent-write refusal (second writer waits then fails)
- [ ] **Step 3:** Run tests; confirm all pass before commit
- [ ] **Step 4:** Commit: `git commit -m "architect-critic: state.sh + test-state.sh (Phase B, ~15 tests)"`

### Task TB.2: lib/principles.sh — load + comment-strip + 4-source merge

**Files:** `architect-critic/lib/principles.sh`

Implement:

- `ac_principles_path()` — returns `$(ac_data_dir)/principles.md`
- `ac_principles_seed()` — if missing, copy `${CLAUDE_PLUGIN_ROOT}/templates/principles.md` to `$(ac_principles_path)`
- `ac_principles_load_user_global()` — read `$(ac_principles_path)`, strip lines starting with `# ` (both headers AND comments per D3), strip trailing `[promoted ...]` annotations, emit one principle per line
- `ac_principles_load_master_spec_phases <spec_path> <phase_ids_csv>` — if `<spec_path>` exists, extract content of named phases (use grep/sed for `<!-- master-spec:phase id=N -->` markers)
- `ac_principles_load_memory_bank_patterns()` — if `.claude/memory-bank/03-code-patterns.md` exists, cat it
- `ac_principles_load_memory_bank_governance()` — if `.claude/memory-bank/08-governance.md` exists, cat it
- `ac_principles_compose <spec_path> <phase_ids_csv>` — emit composed block:
  ```
  # User-global principles
  <user-global lines>

  # Project context (MASTER-SPEC accumulated phases X-Y)
  <phase content>

  # Project patterns
  <03-code-patterns.md content>

  # Project governance
  <08-governance.md content>
  ```
  Each section omitted if its source is absent.

Use **Adaptation 1 (BSD awk `sub()` chains)** for the comment-strip awk script.

- [ ] **Step 1:** Write `lib/principles.sh`
- [ ] **Step 2:** Write `tests/test-principles.sh` — ~12 tests: seed-on-missing, load with comments stripped, 4-source merge with various combinations of present/absent sources, missing-source graceful (no error)
- [ ] **Step 3:** Run; confirm pass
- [ ] **Step 4:** Commit: `git commit -m "architect-critic: principles.sh + test-principles.sh (Phase B, ~12 tests)"`

### Task TB.3: lib/inbox.sh — request envelope read + validate

**Files:** `architect-critic/lib/inbox.sh`

Implement:

- `ac_inbox_dir()` — returns `$(ac_data_dir)/inbox`
- `ac_inbox_path <request_id>` — returns `$(ac_inbox_dir)/<id>.json`
- `ac_inbox_read <request_id>` — cat the file; non-zero on missing
- `ac_inbox_validate <envelope_json>` — apply rules from SPEC §6.1; return 0 + nothing on success; return 1 + stderr error on failure

Validation rules (in order, fail on first ERROR):
1. `request_id` is non-empty string
2. `depth` ∈ {`premise-audit`, `close`}
3. `adversaries` is non-empty array; each entry ∈ {`claude`, `codex`}
4. `target.type` ∈ {`master-spec-phase`, `master-spec-full`}
5. `target.path` is a string and resolves to a readable file (use `[[ -r ]]`)
6. if `target.type == master-spec-phase`: `target.phase_id` is int 1–10
7. `sources.accumulated_phases` is array of ints
8. `concession_threshold` is int 1–5

`sources.principles` missing file → log warn, accept (re-seed signal).
`project_class == null` → log warn, accept.

- [ ] **Step 1:** Write `lib/inbox.sh`
- [ ] **Step 2:** Write `tests/test-inbox.sh` — ~10 tests: valid envelope passes, each rule's failure mode, missing principles file warns but accepts, null project_class warns but accepts
- [ ] **Step 3:** Run; pass
- [ ] **Step 4:** Commit: `git commit -m "architect-critic: inbox.sh + test-inbox.sh (Phase B, ~10 tests)"`

### Phase B close

- [ ] Run all Phase B suites: `for t in architect-critic/tests/test-{state,principles,inbox}.sh; do bash "$t"; done` — expect ~37 passed
- [ ] Update Implementation Status: Phase B → ✅ done; cumulative tests = 37
- [ ] Phase-close commit: `git commit --allow-empty -m "architect-critic: Phase B complete — state + principles + inbox (37 tests)"`

---

## Phase C — Slash command bodies

All four command stubs from Phase A get real bodies wiring to libs from Phase B. Audit pipeline still stubbed (Phase D will replace).

### Task TC.1: /critique command body — envelope synthesis + dispatch shell

**Files:** `architect-critic/commands/critique.md`

Replace stub body with the orchestration prompt. Per SPEC §5.1 mode detection:

```markdown
---
description: Run an architect-critic audit on a spec or plan with claude-self-audit + (optionally) codex fresh-frame review
allowed-tools: Bash, Read, Edit, SlashCommand
---

# /critique

Source the libs:
\`\`\`bash
source ${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh
source ${CLAUDE_PLUGIN_ROOT}/lib/state.sh
source ${CLAUDE_PLUGIN_ROOT}/lib/principles.sh
source ${CLAUDE_PLUGIN_ROOT}/lib/inbox.sh
\`\`\`

Parse args. If $1 looks like a request_id (`crit-*`) AND inbox file exists → programmatic mode (read envelope from inbox). Else → manual mode (synthesize envelope from defaults; write to inbox).

(Phase D will add: claude-self-audit step → consolidator → outbox → rebuttal → promotion → cost line.)

For now, validate the envelope and print a summary.
```

The implementer subagent will write the actual bash orchestration. The body uses bash heredocs / inline functions to keep it self-contained per Claude Code's slash-command body conventions.

- [ ] **Step 1:** Write `commands/critique.md` with the full envelope-synth + validation orchestration (replaces stub)
- [ ] **Step 2:** Manually exercise: `mkdir -p $tmpdir/plugin-data; CLAUDE_PLUGIN_DATA=$tmpdir/plugin-data` → invoke /critique-equivalent script that sources libs and synth-validates
- [ ] **Step 3:** Commit: `git commit -m "architect-critic: /critique command body — envelope synthesis (Phase C)"`

### Task TC.2: /critique-list command body

Read state.json's `recent_runs` + `in_flight`; render terminal table per SPEC §5.2. Default `--limit 10`.

- [ ] **Step 1:** Write `commands/critique-list.md`
- [ ] **Step 2:** Commit: `git commit -m "architect-critic: /critique-list command body (Phase C)"`

### Task TC.3: /promote-principle command body

Validate text (non-empty, single-line, ≤200 chars). Atomic append to user-global or project file per `--scope`. Record in state.json.

- [ ] **Step 1:** Write `commands/promote-principle.md`
- [ ] **Step 2:** Commit: `git commit -m "architect-critic: /promote-principle command body (Phase C)"`

### Task TC.4: /principles-list command body

Compose principles per `lib/principles.sh ac_principles_compose`; render with section headers per SPEC §5.4.

- [ ] **Step 1:** Write `commands/principles-list.md`
- [ ] **Step 2:** Commit: `git commit -m "architect-critic: /principles-list command body (Phase C)"`

### Task TC.5: tests/test-commands.sh — command body smoke + behavior

~12 tests:
- /critique synth-from-defaults produces a valid envelope
- /critique with explicit args overrides defaults
- /critique with non-existent --spec errors
- /critique-list with empty state shows "No runs yet"
- /critique-list with N runs shows N rows in correct order
- /critique-list `--limit` filters correctly
- /promote-principle scope=user appends to principles.md
- /promote-principle scope=project errors when no memory-bank
- /promote-principle scope=project appends to 03-code-patterns.md when memory-bank exists
- /promote-principle records in state.json's principle_promotions
- /principles-list with empty principles.md prints "(empty)"
- /principles-list with all 4 sources renders all sections

- [ ] **Step 1:** Write `tests/test-commands.sh`
- [ ] **Step 2:** Run; all pass
- [ ] **Step 3:** Commit: `git commit -m "architect-critic: test-commands.sh (Phase C, ~12 tests)"`

### Phase C close

- [ ] Run cumulative regression: ~49 tests
- [ ] Update Implementation Status
- [ ] Phase-close commit: `git commit --allow-empty -m "architect-critic: Phase C complete — slash command bodies (49 tests cumulative)"`

---

## Phase D — codex + consolidator + scorer + outbox + cost

The audit pipeline core. By end of phase: /critique can run a full claude-self + codex audit, consolidate, write outbox, score rebuttals, and print cost.

### Task TD.1: lib/codex.sh — subprocess + 180s timeout + JSON-strict + fallback

Implement:
- `ac_codex_available()` — `command -v codex >/dev/null 2>&1`
- `ac_codex_audit <prompt_text>` — pipes prompt to `timeout 180 codex --output-format json` (or `--no-stream` equivalent — implementer determines exact flag from `codex --help` at impl time; document in code comment); jq-parses stdout; returns parsed JSON on success, returns 1 on any failure (timeout, non-zero, non-JSON)
- Set `ARCHITECT_CRITIC_CODEX_TIMEOUT` env override (default 180); document in README

Use mock-via-PATH for tests. ~15 tests in `test-codex.sh`:
- absent codex → 1 + log info
- JSON parse success → emits parsed object
- JSON parse failure → 1 + log warn
- timeout (mock takes >180s with `MOCK_CODEX_SLEEP=200`) → kill + 1
- non-zero exit (mock with `MOCK_CODEX_EXIT_CODE=2`) → 1 + log warn

Mock-codex may need extension to support sleep + exit code env vars. Add to fixture if not already there.

- [ ] **Step 1:** Implement `lib/codex.sh`
- [ ] **Step 2:** Extend `tests/fixtures/mock-codex/codex` to honor `MOCK_CODEX_SLEEP` and `MOCK_CODEX_EXIT_CODE` env vars
- [ ] **Step 3:** Write `tests/test-codex.sh`
- [ ] **Step 4:** Run; all pass
- [ ] **Step 5:** Commit: `git commit -m "architect-critic: codex.sh + test-codex.sh (Phase D, ~15 tests)"`

### Task TD.2: lib/consolidator.sh — concat + tag-source + dedup + divergence

Implement per SPEC §7.1 algorithm:
- `ac_consolidator_merge <claude_audit_json> <codex_audit_json>` — emits `{challenges, gaps, divergences, adversaries_used}`

Use jq for the merge. Dedup key: `(severity, text-normalized, references-sorted)`. Divergence detection: scan for refs that appear in one source's challenges but not the other's.

~15 tests in `test-consolidator.sh`:
- empty + empty → empty result
- claude-only + empty codex → only claude's items, source=claude
- claude + codex with no overlap → both kept, both tagged
- claude + codex with exact-match dedup → 1 item kept, marked agreed-by-both
- claude flagged X.Y, codex didn't → X.Y in divergences
- codex flagged X.Y, claude didn't → X.Y in divergences
- gaps concatenated without dedup
- adversaries_used reflects which audits ran

- [ ] **Step 1:** Implement `lib/consolidator.sh`
- [ ] **Step 2:** Write `tests/test-consolidator.sh`
- [ ] **Step 3:** Run; all pass
- [ ] **Step 4:** Commit: `git commit -m "architect-critic: consolidator.sh + test-consolidator.sh (Phase D, ~15 tests)"`

### Task TD.3: lib/scorer.sh — 1–5 rubric scoring

Implement per SPEC §7.3:
- `ac_scorer_score_rebuttal <challenge_text> <rebuttal_text>` — returns int 1–5
- `ac_scorer_decide <score>` — returns "concede" if score ≥ 4, else "restate"

Heuristic check first (regex); fall back to claude-reasoning for ambiguous cases. (For test purposes, the claude-reasoning fallback can be mocked via `ARCHITECT_CRITIC_SCORER_MOCK` env var that overrides the score.)

~10 tests in `test-scorer.sh`:
- "no" / "wrong" / "disagree" → 1
- rebuttal substring of spec → 2
- rebuttal references new fact → 4 or 5
- multi-paragraph rebuttal truncated to 500 chars
- decide(1..3) → "restate"; decide(4..5) → "concede"

- [ ] **Step 1:** Implement `lib/scorer.sh`
- [ ] **Step 2:** Write `tests/test-scorer.sh`
- [ ] **Step 3:** Commit: `git commit -m "architect-critic: scorer.sh + test-scorer.sh (Phase D, ~10 tests)"`

### Task TD.4: lib/outbox.sh — response envelope write

Implement:
- `ac_outbox_dir()` — `$(ac_data_dir)/outbox`
- `ac_outbox_write <request_id> <consolidated_json> <elapsed_ms> <cost_usd>` — assembles full response envelope per SPEC §6.2; uses `ac_guarded_jq_write` to write to `$(ac_outbox_dir)/<id>.json`

~8 tests in `test-outbox.sh`:
- write with valid input → outbox file exists, jq-parseable, schema-correct
- write to non-existent outbox dir → mkdir -p, then write
- jq-then-mv guard: simulate jq failure (corrupt input) → tmp cleaned up, no target written
- idempotent re-write (same request_id) → overwrites cleanly

- [ ] **Step 1:** Implement `lib/outbox.sh`
- [ ] **Step 2:** Write `tests/test-outbox.sh`
- [ ] **Step 3:** Commit: `git commit -m "architect-critic: outbox.sh + test-outbox.sh (Phase D, ~8 tests)"`

### Task TD.5: lib/cost.sh — post-run cost line

Implement:
- `ac_cost_compute <codex_tokens_in> <codex_tokens_out>` — uses static rate-card constants (`AC_COST_CODEX_IN_PER_1K=0.005`, `AC_COST_CODEX_OUT_PER_1K=0.015` — values placeholders, document as "as of 2026-05; update when model pricing changes"); returns USD as floating string
- `ac_cost_print <codex_cost> <claude_cost=0>` — prints formatted line per SPEC OQ-3

Codex token counts: extracted from codex's response if available (some CLIs report; if not, default to 0 + warn). claude-self cost is 0 (in-session, already paid).

No new test suite — folded into `test-consolidator.sh` (which already touches the response envelope).

- [ ] **Step 1:** Implement `lib/cost.sh`
- [ ] **Step 2:** Add 2 tests to `test-consolidator.sh` exercising cost compute + format
- [ ] **Step 3:** Commit: `git commit -m "architect-critic: cost.sh + cost tests in test-consolidator (Phase D)"`

### Task TD.6: Wire /critique body to use the audit pipeline

Replace the stubbed pipeline in `commands/critique.md` with the real orchestration:
1. inbox read + validate (Phase B)
2. principles compose (Phase B)
3. record in_flight in state (Phase B)
4. claude-self-audit (in-context Claude prompt — uses Read on the spec, returns JSON)
5. codex audit if depth=close (Phase D, lib/codex.sh)
6. consolidator (Phase D, lib/consolidator.sh)
7. outbox write (Phase D, lib/outbox.sh)
8. (rebuttal cycle stubbed — Phase E will add full UX)
9. cost line (Phase D, lib/cost.sh)
10. record completion in state (Phase B)

- [ ] **Step 1:** Update `commands/critique.md` body
- [ ] **Step 2:** Manual exercise: synth-mode /critique with mock-codex → outbox written, state.json updated
- [ ] **Step 3:** Commit: `git commit -m "architect-critic: wire /critique to audit pipeline (Phase D)"`

### Phase D close

- [ ] Cumulative regression: ~49 + 15 + 15 + 10 + 8 + 2 = ~99 tests
- [ ] Update Implementation Status
- [ ] Phase-close commit: `git commit --allow-empty -m "architect-critic: Phase D complete — codex + consolidator + scorer + outbox + cost (99 tests)"`

---

## Phase E — Auto-promotion (FULL per OQ-1)

### Task TE.1: lib/promotion.sh — within-run pattern detection

Implement per SPEC §7.2 step 1:
- `ac_promotion_topic <challenge_json>` — emits normalized topic string (lowercase + first-5-words-stemmed + sort(refs))
- `ac_promotion_within_run_candidates <challenges_json>` — group by topic; for groups size ≥2 emit candidate cluster

Use **Adaptation 1 (BSD awk sub() chains)** if any awk is needed for stemming.

- [ ] Implement, write tests in `test-promotion.sh` (5 tests for within-run)
- [ ] Commit: `git commit -m "architect-critic: promotion.sh within-run detection (Phase E)"`

### Task TE.2: lib/promotion.sh — cross-run pattern detection

Per SPEC §7.2 step 2:
- `ac_promotion_cross_run_candidates <current_challenges_json>` — reads state.json `recent_runs`; for each current challenge, count topic matches across last 20 runs; if ≥3 emit candidate cluster

- [ ] Implement, add 4 tests
- [ ] Commit: `git commit -m "architect-critic: promotion.sh cross-run detection (Phase E)"`

### Task TE.3: lib/promotion.sh — candidate generation (claude-reasoning)

Per SPEC §7.2 step 3:
- `ac_promotion_synthesize <cluster_json>` — emits the prompt text for Claude to generate a one-line principle. The actual claude-reasoning happens in /critique's body (Claude Code session); this function just builds the prompt.

For tests: stub the synthesis with a fixed mapping (`ARCHITECT_CRITIC_PROMOTION_MOCK="canned principle text"`).

- [ ] Implement, add 2 tests
- [ ] Commit: `git commit -m "architect-critic: promotion.sh candidate synthesize (Phase E)"`

### Task TE.4: lib/promotion.sh — suppression filter + state writes

Per SPEC §7.2 steps 4–5:
- `ac_promotion_filter_suppressed <candidates_json>` — drops any candidate matching a `declined_candidates` entry where `suppress_until > now`
- `ac_promotion_record_candidates <candidates_json>` — writes to state.json's `candidate_promotions`
- `ac_promotion_record_decline <text>` — appends to `declined_candidates` with `suppress_until = now + 30d`

- [ ] Implement, add 4 tests (suppression in window, suppression expired → re-offer, decline records correctly)
- [ ] Commit: `git commit -m "architect-critic: promotion.sh suppression + state writes (Phase E)"`

### Task TE.5: /critique body — auto-promotion offer UX

In /critique body, after rebuttal cycle, before return:

```bash
candidates="$(ac_promotion_within_run_candidates "$consolidated")"
candidates="$(echo "$candidates" "$(ac_promotion_cross_run_candidates "$consolidated")" | jq -s 'add')"
candidates="$(ac_promotion_filter_suppressed "$candidates")"

for candidate in $(echo "$candidates" | jq -c '.[]'); do
  text="$(echo "$candidate" | jq -r .text)"
  echo ""
  echo "I noticed a pattern across recent runs:"
  echo "  \"$text\""
  echo "Add to principles.md? [y]es / [n]o / [e]dit"
  read -r answer
  case "$answer" in
    y) /promote-principle "$text" --scope user ;;
    n) ac_promotion_record_decline "$text" ;;
    e) tmp=$(mktemp); echo "$text" > "$tmp"; ${EDITOR:-vi} "$tmp"; ... ;;
  esac
done
```

Implementer fills in editor flow + non-interactive default (auto-decline if no TTY).

- [ ] Update /critique body
- [ ] Add 4 tests in test-commands.sh: y-path appends to principles.md, n-path records decline, e-path mocks editor save, no-TTY path auto-declines
- [ ] Commit: `git commit -m "architect-critic: /critique auto-promotion offer UX (Phase E)"`

### Task TE.6: Rebuttal cycle in /critique body

Per SPEC §5.1 step 8 + §7.3:
- Loop over consolidated challenges
- Present each; read user response
- If "accept" / "edit" / "note" → record + advance
- If rebuttal: `ac_scorer_score_rebuttal` → if ≥4 print concession + advance; else print restate + re-prompt

Add 2 tests in test-commands.sh: accept path skips scoring, rebuttal path scores then advances on concede.

- [ ] Update /critique body
- [ ] Commit: `git commit -m "architect-critic: /critique rebuttal cycle UX (Phase E)"`

### Task TE.7: Edge cases — principles.md missing, user-deletion

Add to `lib/principles.sh`:
- On every `ac_principles_load_user_global`, if file missing, call `ac_principles_seed`; log "principles.md re-seeded"

Add 2 tests in test-principles.sh.

- [ ] Implement
- [ ] Commit: `git commit -m "architect-critic: principles.md re-seed on missing (Phase E)"`

### Phase E close

- [ ] Cumulative regression: ~99 + 15 + 4 = ~118 tests (test-promotion.sh ~15, test-commands.sh +6 for promotion+rebuttal, test-principles.sh +2 for re-seed)
- [ ] Update Implementation Status
- [ ] Phase-close commit: `git commit --allow-empty -m "architect-critic: Phase E complete — auto-promotion (FULL) + rebuttal cycle (118 tests)"`

---

## Phase F — Hooks + scaffold-onboard delta (OQ-2)

### Task TF.1: SessionStart housekeeping hook

In `hooks-handlers/session-start.sh`:
- Source `lib/_helpers.sh` + `lib/state.sh`
- Read `state.json`; for each `in_flight` entry where `started_at < now - 24h`, remove
- Quiet on success; print "[architect-critic] cleared N stale in-flight markers" if N>0

- [ ] Implement
- [ ] Add 2 tests in test-state.sh
- [ ] Commit: `git commit -m "architect-critic: SessionStart housekeeping hook (Phase F)"`

### Task TF.2: scaffold-onboard delta — onboard.md frontmatter + dispatch wiring

Edit `scaffold-onboard/commands/onboard.md`:

1. Add `SlashCommand` to frontmatter `allowed-tools`
2. At Phase 5 recap point (locate via `grep "Phase 5 recap"` or similar):
   - Insert: announce "Running architect-critic premise audit on Phase 5 recap. Type 'skip' to bypass this fire."
   - Read user response; if "skip" → log + skip
   - Else: invoke SlashCommand `/critique <request_id>` (the `<request_id>` from the prior `sf_compose_build_critic_request` call)
   - Then read outbox via `sf_compose_read_critic_response`
3. Same for Phase 7 recap and MASTER-SPEC close

This is gated on `architect-critic` installed (per `composition.json` already populated by scaffold-onboard's compose.sh).

- [ ] Implement (the implementer subagent reads the existing onboard.md and edits in place)
- [ ] Manual smoke: invoke /onboard end-to-end with both plugins installed; verify dispatch fires and outbox is written
- [ ] Commit: `git commit -m "architect-critic: scaffold-onboard /onboard dispatch wiring (Phase F, OQ-2)"`

### Task TF.3: scaffold-onboard test-e2e.sh — mock /critique handler

Edit `scaffold-onboard/tests/test-e2e.sh`. The existing E2E tests run /onboard end-to-end; with the dispatch wiring in TF.2, they'd now invoke /critique. Add a mock at the test setup level:
- Define a shell function `mock_critique` that writes a canned outbox JSON to the expected path
- Override `SlashCommand /critique` in the test environment to call the mock (mechanism: temporary command-stub script in PATH? Or a test-only env var the onboard.md body checks for?)

Implementer determines the cleanest mock approach. Likely: env var `SF_TEST_MOCK_CRITIQUE=1` that onboard.md body checks; if set, skips SlashCommand and writes a canned outbox directly.

- [ ] Implement mock + the corresponding onboard.md branch (small addition)
- [ ] Run scaffold-onboard's full test suite; all 163 still pass
- [ ] Commit: `git commit -m "architect-critic: scaffold-onboard test-e2e.sh mock for /critique (Phase F)"`

### Task TF.4: state.json schema migration tolerance

In `lib/state.sh ac_state_init`:
- If state.json exists with `schema_version != 1`, log info "future schema_version detected; preserving"; do not overwrite

Add 1 test in test-state.sh.

- [ ] Implement
- [ ] Commit: `git commit -m "architect-critic: state.sh schema migration tolerance (Phase F)"`

### Task TF.5: Critique-list cost column

Update `commands/critique-list.md` rendering to include the `cost_usd` column from `recent_runs[].cost_usd`. Format: 2 decimal places.

Add 1 test in test-commands.sh.

- [ ] Implement
- [ ] Commit: `git commit -m "architect-critic: /critique-list cost column (Phase F)"`

### Phase F close

- [ ] Run scaffold-onboard's full regression to verify the OQ-2 delta didn't break anything: `for t in scaffold-onboard/tests/test-*.sh; do bash "$t"; done` — expect 163 still passing
- [ ] Run architect-critic's full regression: ~118 + 4 = ~122 tests
- [ ] Update Implementation Status (note: scaffold-onboard regression confirmed green)
- [ ] Phase-close commit: `git commit --allow-empty -m "architect-critic: Phase F complete — hooks + scaffold-onboard delta (122 tests; scaffold-onboard 163 still green)"`

---

## Phase G — E2E + polish + hardening

### Task TG.1: tests/test-e2e.sh — empty repo + manual /critique

Hermetic E2E:
1. setup_tmp_repo
2. seed principles.md
3. write a fixture spec (use tests/fixtures/master-specs/tiny-spec.md)
4. setup_mock_codex with empty.json payload
5. invoke critique-equivalent script with `--spec /path/to/tiny-spec.md`
6. assert outbox written with correct shape, state.json updated

- [ ] Implement
- [ ] Commit: `git commit -m "architect-critic: test-e2e.sh empty-repo manual /critique (Phase G)"`

### Task TG.2: tests/test-e2e.sh — onboarded repo + /critique --phase 5

Same as TG.1 but with `.claude/memory-bank/` seeded + `.onboarding-state.json` indicating mid-onboarding state. Critique --phase 5 with depth=premise-audit.

- [ ] Implement
- [ ] Commit: `git commit -m "architect-critic: test-e2e.sh onboarded /critique --phase 5 (Phase G)"`

### Task TG.3: tests/test-e2e.sh — full close-depth audit + rebuttal + promotion

End-to-end with mock-codex 3-challenges.json:
1. close-depth audit
2. consolidator merges claude+codex (claude side mocked via canned response saved to a tmp file the /critique body reads when env var `ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK=path` is set)
3. simulate rebuttal cycle (3 challenges, mixed accept/rebut paths) via piped stdin
4. simulate promotion offer (within-run cluster) via stdin

- [ ] Implement (requires extending /critique body with the `ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK` test hook for hermetic claude-side mocking)
- [ ] Commit: `git commit -m "architect-critic: test-e2e.sh full close audit + rebuttal + promotion (Phase G)"`

### Task TG.4: README polish + CHANGELOG

Update `architect-critic/README.md` to include:
- Worked example (manual /critique on a spec)
- Cost note (codex-related)
- Composition note (works standalone or with scaffold-onboard)
- Link to SPEC + PLAN

Update `architect-critic/CHANGELOG.md`:
```markdown
## [0.1.0] — 2026-05-XX

### Added
- /critique, /critique-list, /promote-principle, /principles-list slash commands
- Anti-sycophancy reviewer with T=4 concession scoring (1–5 rubric)
- claude-self-audit + (optional) codex fresh-frame audit at close depth
- Consolidator with concat + dedup + divergence detection
- Auto-promotion: within-run + cross-run pattern detection, candidate generation, offer UX with 30-day decline suppression
- File-based IPC counterparty to scaffold-onboard at Phase 5/7/MASTER-SPEC-close
- SessionStart housekeeping hook for stale in-flight cleanup
- Post-run cost line (codex tokens × static rate-card)
- 10 bash test suites, ~124 tests, full regression <30s
```

- [ ] Update both files
- [ ] Commit: `git commit -m "architect-critic: README + CHANGELOG polish (Phase G)"`

### Task TG.5: Hardening sweep

Quick hardening pass before publish:
- Verify all `ac_guarded_jq_write` callers handle the return-1 path (no silent jq failures clobber existing state)
- Verify all lock acquisitions have explicit release before each return (Adaptation 3)
- Run shellcheck on all lib/*.sh and hooks-handlers/*.sh
- Run all 10 test suites with `set -x` once to verify no untrapped subshell drops

- [ ] Run hardening checks; fix any issues found in single-purpose follow-up commits per the issue
- [ ] Final regression: full ~124 tests; wall-clock <30s
- [ ] Phase-close commit: `git commit --allow-empty -m "architect-critic: Phase G complete — E2E + polish + hardening (~124 tests, <30s)"`

---

## Phase H — v0.1.0 publish

### Task TH.1: Add to marketplace.json

Edit `.claude-plugin/marketplace.json` (root). Add architect-critic entry between scaffold-onboard and scaffold (or at end of plugins array). Use the existing entries' shape as template.

- [ ] Implement
- [ ] Verify: `jq . .claude-plugin/marketplace.json` exits 0; lists 4 plugins
- [ ] Commit: `git commit -m "marketplace: add architect-critic v0.1.0 (Phase H)"`

### Task TH.2: Root README plugin table → 4 rows

Edit root `README.md`:
- Add architect-critic row to the plugins table
- Update install commands section to include `/plugin install architect-critic@claude-agent-scaffolding`

- [ ] Implement
- [ ] Commit: `git commit -m "docs: surface architect-critic in root README (Phase H)"`

### Task TH.3: Tag and push (gated — pause and confirm with user before each git push)

- [ ] Update `architect-critic/.claude-plugin/plugin.json` version (already 0.1.0; verify)
- [ ] Update PLAN's Implementation Status section: all phases ✅, total tests, release tag
- [ ] Commit Implementation Status update: `git commit -m "docs: finalize architect-critic PLAN Implementation Status (v0.1.0 shipped)"`
- [ ] Tag: `git tag -a architect-critic-v0.1.0 -m "architect-critic v0.1.0 — initial release"`
- [ ] **PAUSE** — confirm with user before pushing
- [ ] Push: `git push origin main && git push origin architect-critic-v0.1.0`
- [ ] Verify on GitHub: tag appears, marketplace.json reflects 4 plugins

### Phase H close

- [ ] Final smoke: `/plugin install architect-critic@claude-agent-scaffolding` from a fresh Claude Code session works
- [ ] Update Implementation Status final state

---

## Definition of done (verbatim from `docs/HANDOFF-architect-critic-build.md` §7)

- All phases A–H complete per this PLAN.
- ~120–160 tests passing across the 10 architect-critic bash suites.
- `architect-critic-v0.1.0` tag pushed to origin.
- Entry added to `.claude-plugin/marketplace.json`.
- Root `README.md` plugin table updated to 4 rows.
- `scaffold-onboard`'s `test_critic_dispatch_with_mock_outbox` and `test_critic_response_timeout` tests **still pass** (regression check: contract compatibility).
- Installable via `/plugin install architect-critic@claude-agent-scaffolding`.

End-to-end verification command (run after Phase H):
```bash
for t in scaffold-onboard/tests/test-*.sh architect-critic/tests/test-*.sh; do bash "$t"; done
```
Expected: 163 (scaffold-onboard) + ~124 (architect-critic) all green.

---

## Workflow conventions (verbatim from `docs/HANDOFF-architect-critic-build.md` §4)

- **Subagent-driven dev** (`superpowers:subagent-driven-development`): per task → implementer subagent (general-purpose, sonnet for TDD logic / haiku for stubs+templates) → reads PLAN verbatim → TDD discipline (failing test → impl → passing test → regression → commit) → reviewer subagent (general-purpose, haiku) → TaskUpdate.
- **TDD discipline non-negotiable**: red → green → regression → commit. Never commit with red tests.
- **Commit format**: `architect-critic: <description> (Phase X)` for tasks; `architect-critic: Phase X complete — <summary>` for phase-close commits. **No `Co-Authored-By:`** trailer. Single-line `git commit -m "..."`. No HEREDOC for routine commits.
- **One task = one commit** (small intra-task TDD increments OK; final task-close commit is the one this PLAN names).
- **macOS portability** (codified in Portability notes section): BSD awk `sub()` chains (no gawk 3-arg `match()`), bash 3.2 parallel indexed arrays + `_lookup_var` helper (no `declare -A`), explicit release calls before each `return` (no `trap RETURN`).
- **File-based IPC**: atomic `mktemp` + `mv` (same dir for atomicity), lock-file protection (mirror `sf_compose_lock_*`), guard pattern `if jq ... > tmp; then mv tmp path; else rm -f tmp; ac_log_error ...; return 1; fi`.
- **Phase-close commits update CHANGELOG** + this PLAN's "Implementation Status" section (canonical resume point for compaction recovery).
- **Never amend, never `--no-verify`, never force-push** without explicit user request.

---

## Reading order for fresh sessions

1. This PLAN's "Implementation Status" section (current state).
2. The phase being worked on (next-up tasks).
3. `docs/SPEC-architect-critic.md` for design context.
4. `docs/HANDOFF-architect-critic-build.md` for the workflow conventions and original game plan.
5. `docs/SPEC-scaffold-onboard.md` §8.3 for the file-IPC contract semantics.

The implementer subagent reads (1) + (2) + (3) verbatim; the orchestrator hands them the task body via prompt.
