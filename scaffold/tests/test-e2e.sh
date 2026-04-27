#!/usr/bin/env bash
#
# scaffold/tests/test-e2e.sh — end-to-end integration test.
#
# Walks through the complete workflow as a user would, exercising the
# composition between phases A-H rather than testing each in isolation.
#
# Two scenarios:
#   FRESH:    git init → /scaffold-init → /slice-new → /slice-spec...verify →
#             /adr-new → /changelog Added → /changelog bump → /scaffold-audit
#   EXISTING: pre-populated repo with README, ADR, etc. → /scaffold-init →
#             verifies init does not overwrite existing files
#
# Plus: worktree fork happy path + memory.db seed + SessionStart hook output
# verification across both scenarios.
#
# Slow (~10s) because it runs many commands sequentially. Not part of the
# default test cadence — used to verify a release.
#
# Usage: bash scaffold/tests/test-e2e.sh

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TMPDIR_TESTS="$(mktemp -d -t scaffold-e2e-XXXXXX)"
export CLAUDE_PLUGIN_DATA="$TMPDIR_TESTS/data"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$CLAUDE_PLUGIN_DATA"

cleanup() { rm -rf "$TMPDIR_TESTS"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED_TESTS=()
pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "$2" ]] && printf '      %s\n' "$2"; }

# Run a slash command's bash payload with the given ARGUMENTS env value
run_cmd() {
  local cmd="$1" args="$2"
  local script="$TMPDIR_TESTS/_cmd.sh"
  awk '/^```bash$/,/^```$/' "$PLUGIN_ROOT/commands/${cmd}.md" | sed '/^```/d' > "$script"
  ARGUMENTS="$args" bash "$script"
}

# Run the SessionStart hook and return the additionalContext
run_session_hook() {
  echo '{"source":"startup","hook_event_name":"SessionStart"}' \
    | bash "$PLUGIN_ROOT/hooks-handlers/session-start.sh" \
    | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null
}

# ═════════════════════════════════════════════════════════════════════════════
# SCENARIO 1: fresh repo
# ═════════════════════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════════"
echo " SCENARIO 1: fresh repo (bootstrap path)"
echo "════════════════════════════════════════════════════════════"

FRESH="$TMPDIR_TESTS/fresh"
mkdir -p "$FRESH"
( cd "$FRESH" && git init -q -b main && git config user.email t@t && git config user.name "Test User" )
echo "[project]" > "$FRESH/pyproject.toml"
( cd "$FRESH" && git add . && git commit -q -m init )
cd "$FRESH"

echo ""
echo "── /scaffold-init ──"
out="$(run_cmd scaffold-init '')"
echo "$out" | grep -q "scaffold-init complete" && pass "F1.1 init reports completion" || fail "F1.1 init message"
[[ -r "$FRESH/LICENSE" ]] && pass "F1.2 LICENSE created" || fail "F1.2 LICENSE"
[[ -r "$FRESH/.gitignore" ]] && pass "F1.3 .gitignore created" || fail "F1.3 gitignore"
[[ -r "$FRESH/README.md" ]] && pass "F1.4 README.md created" || fail "F1.4 README"
[[ -r "$FRESH/CLAUDE.md" ]] && pass "F1.5 CLAUDE.md generated" || fail "F1.5 CLAUDE.md"
[[ -d "$FRESH/docs/adr" && -d "$FRESH/docs/runbooks" && -d "$FRESH/docs/slices" ]] && pass "F1.6 docs/ structure" || fail "F1.6 docs/"

echo ""
echo "── full slice cycle ──"
run_cmd slice-new "user-auth" >/dev/null
[[ -r "$FRESH/docs/slices/slice-01-user-auth.md" ]] && pass "F2.1 slice spec file created" || fail "F2.1 spec file"

# Inject 2 acceptance criteria
cat > "$FRESH/docs/slices/slice-01-user-auth.md" <<XEOF
# Slice 1: user-auth

## Acceptance criteria

- [ ] **AC-1:** Login with email/password
- [ ] **AC-2:** Session expires after 24h
XEOF

# /slice-spec re-parses ACs
out="$(run_cmd slice-spec '')"
echo "$out" | grep -q "Refreshed ACs" && pass "F2.2 slice-spec re-parses ACs" || fail "F2.2 slice-spec"

# /slice-contract → /slice-scaffold → /slice-implement
run_cmd slice-contract '' >/dev/null
[[ "$(source $PLUGIN_ROOT/lib/slice.sh; sf_slice_phase 'slice-01-user-auth')" == "contract" ]] && pass "F2.3 phase=contract" || fail "F2.3 contract"

run_cmd slice-scaffold '' >/dev/null
[[ "$(source $PLUGIN_ROOT/lib/slice.sh; sf_slice_phase 'slice-01-user-auth')" == "scaffold" ]] && pass "F2.4 phase=scaffold" || fail "F2.4 scaffold"

run_cmd slice-implement '' >/dev/null
[[ "$(source $PLUGIN_ROOT/lib/slice.sh; sf_slice_phase 'slice-01-user-auth')" == "implement" ]] && pass "F2.5 phase=implement" || fail "F2.5 implement"

# Mock test command to true; /slice-verify should mark complete
source $PLUGIN_ROOT/lib/state.sh
sf_state_apply '.slices["slice-01-user-auth"].test_command = "true"'
run_cmd slice-verify '' >/dev/null 2>&1
[[ "$(sf_state_get_path '.slices["slice-01-user-auth"].phase')" == "complete" ]] && pass "F2.6 verify (mock pass) → complete" || fail "F2.6 complete"

echo ""
echo "── governance commands ──"
run_cmd adr-new 'Use Postgres over MySQL' >/dev/null
[[ -r "$FRESH/docs/adr/0001-use-postgres-over-mysql.md" ]] && pass "F3.1 ADR 0001 created" || fail "F3.1 ADR"

run_cmd adr-new 'Adopt JWT for sessions' >/dev/null
[[ -r "$FRESH/docs/adr/0002-adopt-jwt-for-sessions.md" ]] && pass "F3.2 ADR 0002 created" || fail "F3.2 ADR 2"
[[ "$(sf_state_get adr_counter)" == "2" ]] && pass "F3.3 adr_counter=2" || fail "F3.3 counter"

run_cmd changelog 'Added User auth slice' >/dev/null
grep -q "User auth slice" "$FRESH/CHANGELOG.md" && pass "F3.4 changelog Added entry" || fail "F3.4 changelog"

run_cmd changelog 'bump 0.1.0' >/dev/null
grep -qE "## \[0\.1\.0\] — [0-9]{4}-[0-9]{2}-[0-9]{2}" "$FRESH/CHANGELOG.md" && pass "F3.5 changelog bump → versioned heading" || fail "F3.5 bump"

run_cmd runbook-new 'oom-kills' >/dev/null
[[ -r "$FRESH/docs/runbooks/oom-kills.md" ]] && pass "F3.6 runbook created" || fail "F3.6 runbook"

echo ""
echo "── /scaffold-audit ──"
out="$(run_cmd scaffold-audit '')"
echo "$out" | grep -q "^| ✓ | README" && pass "F4.1 audit table renders" || fail "F4.1 audit"
echo "$out" | grep -qE "[0-9]+ pass · [0-9]+ warn" && pass "F4.2 audit summary line" || fail "F4.2 summary"

echo ""
echo "── SessionStart hook (managed) ──"
ctx="$(run_session_hook)"
[[ -n "$ctx" ]] && pass "F5.1 hook emits context for managed repo" || fail "F5.1 ctx empty"
echo "$ctx" | grep -q "Project: fresh" && pass "F5.2 ctx has project name" || fail "F5.2 project name"
echo "$ctx" | grep -q "phase: complete" && pass "F5.3 ctx reflects current slice phase=complete" || fail "F5.3 phase"

echo ""
echo "── /scaffold-worktree-fork ──"
run_cmd scaffold-worktree-fork "auth-v2-spike" >/dev/null
WT_PATH="$TMPDIR_TESTS/fresh-auth-v2-spike"
[[ -d "$WT_PATH" ]] && pass "F6.1 worktree dir created" || fail "F6.1 worktree dir"
[[ -r "$WT_PATH/CLAUDE.md" ]] && pass "F6.2 CLAUDE.md materialized in worktree" || fail "F6.2 worktree CLAUDE.md"

# Inside the new worktree: state should be forked (current_slice=null but adr_counter=2 inherited)
( cd "$WT_PATH" && [[ "$(sf_state_get_path '.current_slice')" == "" ]] ) && pass "F6.3 worktree current_slice reset" || fail "F6.3 worktree slice reset"
( cd "$WT_PATH" && [[ "$(sf_state_get adr_counter)" == "2" ]] ) && pass "F6.4 worktree inherits adr_counter=2" || fail "F6.4 adr_counter inherit"

# /scaffold-worktree-list should show both
out="$(run_cmd scaffold-worktree-list '')"
echo "$out" | grep -q "main" && echo "$out" | grep -q "auth-v2-spike" && pass "F6.5 worktree-list shows both" || fail "F6.5 list"

# ═════════════════════════════════════════════════════════════════════════════
# SCENARIO 2: existing repo onboarding
# ═════════════════════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════════"
echo " SCENARIO 2: existing repo (onboarding path)"
echo "════════════════════════════════════════════════════════════"

EXISTING="$TMPDIR_TESTS/existing"
mkdir -p "$EXISTING/docs/adr"
( cd "$EXISTING" && git init -q -b main && git config user.email t@t && git config user.name "Test User" )

cat > "$EXISTING/README.md" <<'XEOF'
# example

## Quickstart

Existing project with real content.
XEOF

cat > "$EXISTING/CLAUDE.md" <<'XEOF'
# Hand-written project notes

This was authored before scaffold was installed.
- existing convention 1
- existing convention 2
XEOF

cat > "$EXISTING/docs/adr/0001-existing-decision.md" <<'XEOF'
# 1. An existing decision

The user already wrote this ADR.
XEOF

echo "MIT" > "$EXISTING/LICENSE"
echo "*.pyc" > "$EXISTING/.gitignore"
echo "[project]" > "$EXISTING/pyproject.toml"

( cd "$EXISTING" && git add . && git commit -q -m init )
cd "$EXISTING"

# Capture file contents to verify non-overwrite later
ORIG_CLAUDE_MD="$(cat CLAUDE.md)"
ORIG_README="$(cat README.md)"
ORIG_LICENSE="$(cat LICENSE)"
ORIG_ADR="$(cat docs/adr/0001-existing-decision.md)"

echo ""
echo "── /scaffold-init on existing repo ──"
out="$(run_cmd scaffold-init '')"
echo "$out" | grep -q "scaffold-init complete" && pass "E1.1 init completes on existing repo" || fail "E1.1 init message"

# Existing files preserved
[[ "$(cat README.md)" == "$ORIG_README" ]] && pass "E1.2 existing README.md preserved" || fail "E1.2 README"
[[ "$(cat LICENSE)" == "$ORIG_LICENSE" ]] && pass "E1.3 existing LICENSE preserved" || fail "E1.3 LICENSE"
[[ "$(cat CLAUDE.md)" == "$ORIG_CLAUDE_MD" ]] && pass "E1.4 existing CLAUDE.md NOT overwritten" || fail "E1.4 CLAUDE.md"
[[ "$(cat docs/adr/0001-existing-decision.md)" == "$ORIG_ADR" ]] && pass "E1.5 existing ADR preserved" || fail "E1.5 existing ADR"

# Init notes the existing CLAUDE.md
echo "$out" | grep -qi "CLAUDE.md already exists" && pass "E1.6 init flags existing CLAUDE.md" || fail "E1.6 CLAUDE.md note" "out: $out"

# State is initialized — use a jq path that needs no shell-string escaping
[[ "$(sf_state_get_path '.stack[0]')" == "python" ]] && pass "E1.7 stack detected: python" || fail "E1.7 stack"

# /scaffold-audit on this repo finds the existing ADR
out_audit="$(run_cmd scaffold-audit '')"
echo "$out_audit" | grep -q "^| ✓ | ADRs | At least one ADR" && pass "E1.8 audit finds existing ADR" || fail "E1.8 audit ADR"

# /adr-new picks up at 0002 (counter starts at 0; first /adr-new → 1; but
# existing ADR doesn't update counter — known v1 behavior; counter is per-repo
# session-tracked).
run_cmd adr-new 'New decision after init' >/dev/null
ls docs/adr/ | grep -q "^0001" && ls docs/adr/ | grep -q "^0002-new-decision-after-init.md$" && pass "E1.9 adr-new produces 0002 (next after counter init)" || fail "E1.9 adr-new collision-free" "files: $(ls docs/adr/)"

echo ""
echo "── audit summary on the now-fully-onboarded repo ──"
out_audit="$(run_cmd scaffold-audit '')"
fail_count="$(echo "$out_audit" | grep -oE '[0-9]+ fail' | grep -oE '[0-9]+' | head -1)"
[[ "$fail_count" == "0" ]] && pass "E2.1 no fail rows on onboarded existing repo" || fail "E2.1 audit failures" "got $fail_count"

echo ""
echo "── SessionStart hook (existing repo) ──"
ctx="$(run_session_hook)"
echo "$ctx" | grep -q "Project: existing" && pass "E3.1 hook emits ctx for onboarded repo" || fail "E3.1 ctx"

# ═════════════════════════════════════════════════════════════════════════════
# Memory bank surfacing across both scenarios (smoke)
# ═════════════════════════════════════════════════════════════════════════════

echo ""
echo "════════════════════════════════════════════════════════════"
echo " Memory bank smoke (sqlite seed + hook surface)"
echo "════════════════════════════════════════════════════════════"

# Seed memory.db for the FRESH repo via python3
DB_PATH="$CLAUDE_PLUGIN_DATA/projects/$(cd $FRESH && source $PLUGIN_ROOT/lib/repo.sh && sf_repo_hash)/memory.db"
mkdir -p "$(dirname "$DB_PATH")"

python3 - "$DB_PATH" <<'PY'
import sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.executescript("""
CREATE TABLE IF NOT EXISTS memory (
  id INTEGER PRIMARY KEY AUTOINCREMENT, type TEXT NOT NULL, title TEXT,
  body TEXT NOT NULL, tags TEXT, branch TEXT, related_files TEXT,
  created_at TEXT NOT NULL, updated_at TEXT NOT NULL
);""")
db.executemany(
    "INSERT INTO memory(type, title, body, created_at, updated_at) VALUES (?,?,?,?,?)",
    [
        ('decision', 'Pick HTTP/2 server', 'rationale...', '2026-04-27T10:00:00Z', '2026-04-27T10:00:00Z'),
        ('pattern',  'Logging convention', 'use structured json logs', '2026-04-27T11:00:00Z', '2026-04-27T11:00:00Z'),
    ]
)
db.commit()
PY

cd "$FRESH"
ctx="$(run_session_hook)"
echo "$ctx" | grep -q "decision: Pick HTTP/2 server" && pass "M1.1 SessionStart surfaces memory entry by title" || fail "M1.1 ctx memory surface"
echo "$ctx" | grep -q "pattern: Logging convention" && pass "M1.2 multiple memory entries listed" || fail "M1.2 multi"

# Summary
TOTAL=$((PASS+FAIL))
echo ""
echo "════════════════════════════════════════════════════════════"
if [[ $FAIL -eq 0 ]]; then
  printf '\033[32mAll %d E2E tests passed.\033[0m\n' "$TOTAL"
  exit 0
else
  printf '\033[31m%d/%d E2E tests failed.\033[0m\n' "$FAIL" "$TOTAL"
  for t in "${FAILED_TESTS[@]}"; do printf '  - %s\n' "$t"; done
  exit 1
fi
