#!/usr/bin/env bash
#
# scaffold/tests/test-session-start.sh — regression suite for the SessionStart hook.
#
# Verifies:
#   - Unmanaged repo → silent (exit 0, no output)
#   - Non-git dir → silent
#   - Managed repo → emits valid JSON with additionalContext
#   - Context includes project name, branch, stack, current slice, phase
#   - Recent memory entries from sqlite3 surfaced when memory.db exists
#   - Hook is source-agnostic (always emits when managed, regardless of source field)
#
# Usage: bash scaffold/tests/test-session-start.sh

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks-handlers/session-start.sh"

TMPDIR_TESTS="$(mktemp -d -t scaffold-ss-tests-XXXXXX)"
export CLAUDE_PLUGIN_DATA="$TMPDIR_TESTS/data"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$CLAUDE_PLUGIN_DATA"

cleanup() { rm -rf "$TMPDIR_TESTS"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED_TESTS=()
pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "$2" ]] && printf '      %s\n' "$2"; }

# Run hook with given source field, returns stdout
run_hook() {
  local src="${1:-startup}"
  jq -n --arg s "$src" '{source:$s, hook_event_name:"SessionStart"}' | bash "$HOOK"
}

# Source state lib so we can prep test repos
# shellcheck source=../lib/state.sh
source "$PLUGIN_ROOT/lib/state.sh"

echo ""
echo "── silent exit cases ──"

# E1 — non-git directory
NONGIT="$TMPDIR_TESTS/nongit"
mkdir -p "$NONGIT"
( cd "$NONGIT" && out="$(run_hook startup)" && [[ -z "$out" ]] ) \
  && pass "E1 non-git dir → silent (no output)" \
  || fail "E1 non-git silent"

# E2 — git repo but not scaffold-managed
UNMANAGED="$TMPDIR_TESTS/unmanaged"
mkdir -p "$UNMANAGED"
( cd "$UNMANAGED" && git init -q -b main && git config user.email t@t && git config user.name t \
  && touch .keep && git add .keep && git commit -q -m init )
( cd "$UNMANAGED" && out="$(run_hook startup)" && [[ -z "$out" ]] ) \
  && pass "E2 git repo without scaffold state → silent" \
  || fail "E2 unmanaged silent"

echo ""
echo "── managed repo: context emission ──"

# Setup a managed repo
REPO="$TMPDIR_TESTS/work"
mkdir -p "$REPO"
( cd "$REPO" && git init -q -b main && git config user.email t@t && git config user.name t )
echo "[project]" > "$REPO/pyproject.toml"
( cd "$REPO" && git add . && git commit -q -m init )
cd "$REPO"
sf_init_state >/dev/null

# M1 — managed repo emits non-empty output
out="$(run_hook startup)"
[[ -n "$out" ]] && pass "M1 managed repo emits output" || fail "M1 emits"

# M2 — output is valid JSON
echo "$out" | jq -e . >/dev/null 2>&1 \
  && pass "M2 output is valid JSON" \
  || fail "M2 valid JSON" "got: $out"

# M3 — has correct hookEventName
[[ "$(echo "$out" | jq -r .hookSpecificOutput.hookEventName)" == "SessionStart" ]] \
  && pass "M3 hookEventName = SessionStart" \
  || fail "M3 hookEventName"

# M4 — additionalContext non-empty
ctx="$(echo "$out" | jq -r .hookSpecificOutput.additionalContext)"
[[ -n "$ctx" && "$ctx" != "null" ]] && pass "M4 additionalContext present" || fail "M4 ctx"

# M5 — context includes project name
echo "$ctx" | grep -q "Project: work" \
  && pass "M5 context includes project name" \
  || fail "M5 project name" "ctx: $ctx"

# M6 — context includes branch
echo "$ctx" | grep -q "branch: main" \
  && pass "M6 context includes branch" \
  || fail "M6 branch"

# M7 — context includes stack (python detected from pyproject.toml)
echo "$ctx" | grep -q "stack: python" \
  && pass "M7 context includes stack: python" \
  || fail "M7 stack"

# M8 — context shows "(none ...)" for current slice when no slice yet
echo "$ctx" | grep -q "Current slice: (none" \
  && pass "M8 current slice → (none ...) when none" \
  || fail "M8 no slice"

# M9 — slash command catalog present
echo "$ctx" | grep -q "/slice-new" \
  && echo "$ctx" | grep -q "/scaffold-audit" \
  && echo "$ctx" | grep -q "/adr-new" \
  && pass "M9 slash command catalog present" \
  || fail "M9 catalog"

echo ""
echo "── managed repo with active slice ──"

# Set up a current slice
sf_state_apply '.current_slice = "slice-04-auth"'
sf_state_apply_typed '.slices["slice-04-auth"] = $val' '{
  "name":"auth","number":4,"phase":"implement",
  "acceptance_criteria":[
    {"id":"AC-1","text":"login","status":"passing"},
    {"id":"AC-2","text":"logout","status":"pending"}
  ]
}'

out="$(run_hook startup)"
ctx="$(echo "$out" | jq -r .hookSpecificOutput.additionalContext)"

# S1 — current slice id surfaced
echo "$ctx" | grep -q "slice-04-auth" \
  && pass "S1 current slice id in context" \
  || fail "S1 slice id" "ctx: $ctx"

# S2 — phase surfaced
echo "$ctx" | grep -q "phase: implement" \
  && pass "S2 phase in context" \
  || fail "S2 phase"

# S3 — AC count: 1/2 passing
echo "$ctx" | grep -q "1/2 passing" \
  && pass "S3 AC count formatted as N/M passing" \
  || fail "S3 AC count" "ctx: $ctx"

echo ""
echo "── memory bank surfacing ──"

# Manually create a memory.db with some entries via python3 stdlib sqlite3
# (avoids depending on sqlite3 CLI which may not be installed).
DB_PATH="$(sf_project_dir)/memory.db"
mkdir -p "$(dirname "$DB_PATH")"
python3 - "$DB_PATH" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.executescript("""
CREATE TABLE memory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type TEXT NOT NULL,
  title TEXT,
  body TEXT NOT NULL,
  tags TEXT,
  branch TEXT,
  related_files TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
""")
db.executemany(
    "INSERT INTO memory(type, title, body, created_at, updated_at) VALUES (?, ?, ?, ?, ?)",
    [
        ('decision', 'Use Postgres', 'context...', '2026-04-26T00:00:00Z', '2026-04-26T00:00:00Z'),
        ('pattern', 'Result types', 'Result<T, E> for fallible ops', '2026-04-27T00:00:00Z', '2026-04-27T00:00:00Z'),
        ('note', None, 'Migration breaks if X happens during deploy', '2026-04-27T01:00:00Z', '2026-04-27T01:00:00Z'),
    ],
)
db.commit()
PY

out="$(run_hook startup)"
ctx="$(echo "$out" | jq -r .hookSpecificOutput.additionalContext)"

# B1 — recent memory section present (not the empty fallback)
echo "$ctx" | grep -q "Recent memory entries" \
  && ! echo "$ctx" | grep -q "memory bank empty" \
  && pass "B1 memory section populated" \
  || fail "B1 memory section" "ctx: $ctx"

# B2 — newest first ordering: note (2026-04-27T01) should appear before pattern (2026-04-27T00)
note_line="$(echo "$ctx" | grep -n "Migration" | head -1 | cut -d: -f1)"
pattern_line="$(echo "$ctx" | grep -n "Result types" | head -1 | cut -d: -f1)"
[[ -n "$note_line" && -n "$pattern_line" && "$note_line" -lt "$pattern_line" ]] \
  && pass "B2 newest-first ordering (note before pattern)" \
  || fail "B2 ordering" "note=$note_line pattern=$pattern_line"

# B3 — body excerpt for entries without titles
echo "$ctx" | grep -q "note: Migration breaks" \
  && pass "B3 untitled note shows body excerpt" \
  || fail "B3 body excerpt"

# B4 — title used for entries with one
echo "$ctx" | grep -q "decision: Use Postgres" \
  && pass "B4 titled entry shows title" \
  || fail "B4 title"

echo ""
echo "── source-awareness (always emit when managed) ──"

# All sources should produce identical (non-empty) output for this state
declare -a sources=(startup resume clear compact)
all_ok=1
for src in "${sources[@]}"; do
  out_src="$(run_hook "$src")"
  ctx_src="$(echo "$out_src" | jq -r .hookSpecificOutput.additionalContext 2>/dev/null)"
  if [[ -z "$ctx_src" || "$ctx_src" == "null" ]]; then
    fail "X1.${src} emit on $src" "got empty"
    all_ok=0
  fi
done
[[ $all_ok -eq 1 ]] && pass "X1 emits context on all four source values (startup/resume/clear/compact)"

# X2 — missing source field still emits
out="$(echo '{}' | bash "$HOOK")"
[[ -n "$out" ]] && pass "X2 emits even with no source field" || fail "X2 no source"

# Summary
TOTAL=$((PASS+FAIL))
echo ""
echo "─────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
  printf '\033[32mAll %d tests passed.\033[0m\n' "$TOTAL"
  exit 0
else
  printf '\033[31m%d/%d tests failed.\033[0m\n' "$FAIL" "$TOTAL"
  for t in "${FAILED_TESTS[@]}"; do printf '  - %s\n' "$t"; done
  exit 1
fi
