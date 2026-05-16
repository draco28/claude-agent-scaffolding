#!/usr/bin/env bash
# test-principles.sh — tests for lib/principles.sh (Phase B, Task TB.2)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/_helpers.sh"
source "$PLUGIN_ROOT/lib/_helpers.sh"
source "$PLUGIN_ROOT/lib/principles.sh"

echo "=== test-principles.sh ==="

# ---------------------------------------------------------------------------
# Test 1: ac_principles_path returns data-dir/principles.md
# ---------------------------------------------------------------------------
echo "--- Test: ac_principles_path ---"
setup_tmp_repo > /dev/null
result="$(ac_principles_path)"
assert_eq "principles_path is inside data dir" "$CLAUDE_PLUGIN_DATA/principles.md" "$result"

# ---------------------------------------------------------------------------
# Test 2: ac_principles_seed copies template when file is missing
# ---------------------------------------------------------------------------
echo "--- Test: ac_principles_seed (creates when missing) ---"
setup_tmp_repo > /dev/null
assert_file_missing "$(ac_principles_path)"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" ac_principles_seed
assert_file_exists "$(ac_principles_path)"

# ---------------------------------------------------------------------------
# Test 3: ac_principles_seed does NOT overwrite existing file
# ---------------------------------------------------------------------------
echo "--- Test: ac_principles_seed (no-op when exists) ---"
setup_tmp_repo > /dev/null
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" ac_principles_seed
echo "my existing principle" >> "$(ac_principles_path)"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" ac_principles_seed
result="$(grep -c 'my existing principle' "$(ac_principles_path)")"
assert_eq "seed does not overwrite existing file" "1" "$result"

# ---------------------------------------------------------------------------
# Test 4: ac_principles_load_user_global strips lines starting with "# "
# ---------------------------------------------------------------------------
echo "--- Test: load_user_global strips comment/header lines ---"
setup_tmp_repo > /dev/null
pfile="$(ac_principles_path)"
mkdir -p "$(dirname "$pfile")"
printf '%s\n' \
  "# This is a header" \
  "# This is a comment principle example" \
  "active principle one" \
  "## Section header without space after hash" \
  "active principle two" \
  > "$pfile"
output="$(ac_principles_load_user_global)"
# Should contain active principles
echo "$output" | grep -q "active principle one"
assert_eq "active principle one present" "0" "$?"
echo "$output" | grep -q "active principle two"
assert_eq "active principle two present" "0" "$?"
# Should NOT contain lines starting with "# "
echo "$output" | grep -q "^# "
assert_eq "header/comment lines stripped" "1" "$?"

# ---------------------------------------------------------------------------
# Test 5: ac_principles_load_user_global strips trailing [promoted ...] annotations
# ---------------------------------------------------------------------------
echo "--- Test: load_user_global strips promoted annotations ---"
setup_tmp_repo > /dev/null
pfile="$(ac_principles_path)"
mkdir -p "$(dirname "$pfile")"
printf '%s\n' \
  "prefer explicit config [promoted 2026-05-01 source:manual]" \
  "push validation to boundaries [promoted 2026-05-14 source:auto]" \
  > "$pfile"
output="$(ac_principles_load_user_global)"
echo "$output" | grep -q "\[promoted"
assert_eq "promoted annotations stripped" "1" "$?"
echo "$output" | grep -q "prefer explicit config"
assert_eq "principle text retained after strip" "0" "$?"

# ---------------------------------------------------------------------------
# Test 6: ac_principles_load_user_global returns nothing when file is empty of active principles
# ---------------------------------------------------------------------------
echo "--- Test: load_user_global empty file returns empty ---"
setup_tmp_repo > /dev/null
pfile="$(ac_principles_path)"
mkdir -p "$(dirname "$pfile")"
printf '%s\n' \
  "# Header only" \
  "# Another comment" \
  "" \
  > "$pfile"
output="$(ac_principles_load_user_global)"
# No active lines; output should be blank (possibly just whitespace)
active="$(echo "$output" | grep -v '^[[:space:]]*$' || true)"
assert_eq "no active principles returned" "" "$active"

# ---------------------------------------------------------------------------
# Test 7: ac_principles_load_master_spec_phases extracts named phase content
# ---------------------------------------------------------------------------
echo "--- Test: load_master_spec_phases extracts phases ---"
setup_tmp_repo > /dev/null
tiny_spec="$PLUGIN_ROOT/tests/fixtures/master-specs/tiny-spec.md"
output="$(ac_principles_load_master_spec_phases "$tiny_spec" "1,3")"
echo "$output" | grep -q "Phase 1"
assert_eq "phase 1 content present" "0" "$?"
echo "$output" | grep -q "Phase 3"
assert_eq "phase 3 content present" "0" "$?"
# Phase 2 should NOT appear
echo "$output" | grep -q "Phase 2: Strategy"
assert_eq "phase 2 not included" "1" "$?"

# ---------------------------------------------------------------------------
# Test 8: ac_principles_load_master_spec_phases graceful on missing file
# ---------------------------------------------------------------------------
echo "--- Test: load_master_spec_phases missing file exits cleanly ---"
setup_tmp_repo > /dev/null
output="$(ac_principles_load_master_spec_phases "/nonexistent/spec.md" "1,2" 2>&1)"
assert_eq "missing spec returns empty output" "" "$output"

# ---------------------------------------------------------------------------
# Test 9: ac_principles_load_memory_bank_patterns returns content when file exists
# ---------------------------------------------------------------------------
echo "--- Test: load_memory_bank_patterns returns content ---"
setup_tmp_repo > /dev/null
mkdir -p ".claude/memory-bank"
echo "pattern: always validate inputs" > ".claude/memory-bank/03-code-patterns.md"
output="$(ac_principles_load_memory_bank_patterns)"
assert_eq "patterns content returned" "pattern: always validate inputs" "$output"

# ---------------------------------------------------------------------------
# Test 10: ac_principles_load_memory_bank_patterns graceful when file missing
# ---------------------------------------------------------------------------
echo "--- Test: load_memory_bank_patterns graceful on missing ---"
setup_tmp_repo > /dev/null
output="$(ac_principles_load_memory_bank_patterns 2>&1)"
assert_eq "missing patterns returns empty" "" "$output"

# ---------------------------------------------------------------------------
# Test 11: ac_principles_load_memory_bank_governance returns content when file exists
# ---------------------------------------------------------------------------
echo "--- Test: load_memory_bank_governance returns content ---"
setup_tmp_repo > /dev/null
mkdir -p ".claude/memory-bank"
echo "governance: code review required" > ".claude/memory-bank/08-governance.md"
output="$(ac_principles_load_memory_bank_governance)"
assert_eq "governance content returned" "governance: code review required" "$output"

# ---------------------------------------------------------------------------
# Test 12: ac_principles_compose emits section headers + graceful absent sources
# ---------------------------------------------------------------------------
echo "--- Test: ac_principles_compose with mixed sources ---"
setup_tmp_repo > /dev/null

# Seed principles.md with one active principle
pfile="$(ac_principles_path)"
mkdir -p "$(dirname "$pfile")"
printf '%s\n' \
  "# Principles header" \
  "prefer composition over inheritance" \
  > "$pfile"

# Seed patterns but not governance
mkdir -p ".claude/memory-bank"
echo "always test boundaries" > ".claude/memory-bank/03-code-patterns.md"

tiny_spec="$PLUGIN_ROOT/tests/fixtures/master-specs/tiny-spec.md"
output="$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" ac_principles_compose "$tiny_spec" "1,2")"

# User-global section header must appear
echo "$output" | grep -q "User-global principles"
assert_eq "user-global section header present" "0" "$?"

# Active principle must appear
echo "$output" | grep -q "prefer composition over inheritance"
assert_eq "active principle in compose output" "0" "$?"

# Project context section (spec was present)
echo "$output" | grep -q "Project context"
assert_eq "project context section header present" "0" "$?"

# Project patterns section
echo "$output" | grep -q "Project patterns"
assert_eq "project patterns section header present" "0" "$?"

# No governance section (file absent)
echo "$output" | grep -q "Project governance"
assert_eq "governance section absent when file missing" "1" "$?"

# ---------------------------------------------------------------------------
# TE.7: principles.md re-seed on missing (Phase E edge case)
# ---------------------------------------------------------------------------

echo ""
echo "--- TE.7: load_user_global re-seeds when principles.md missing ---"
setup_tmp_repo > /dev/null
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
PFILE="$(ac_principles_path)"
rm -f "$PFILE"
assert_file_missing "$PFILE"
ac_principles_load_user_global > /dev/null 2>&1 || true
assert_file_exists "$PFILE"

echo ""
echo "--- TE.7: re-seeded principles.md has the canonical preamble line ---"
assert_file_contains "$PFILE" "This file is yours"

# ---------------------------------------------------------------------------
# v0.1.3 regression: runtime re-seed MUST be minimal (no example principles).
# Per G5: principles file is user-owned; the critic must not silently restore
# example principles the user has already deleted.
# ---------------------------------------------------------------------------

echo ""
echo "--- v0.1.3: runtime re-seed is MINIMAL (no commented example principles) ---"
setup_tmp_repo > /dev/null
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
PFILE="$(ac_principles_path)"
rm -f "$PFILE"
ac_principles_load_user_global > /dev/null 2>&1 || true
assert_file_exists "$PFILE"

# The full template has 7 commented examples ("# Prefer explicit ...", etc.).
# Runtime re-seed should NOT include any of them.
if grep -q "^# Prefer explicit over implicit" "$PFILE" 2>/dev/null; then
  echo "  ✗ runtime re-seed leaked example principles (G5 violation)"; FAIL=$((FAIL+1))
else
  echo "  ✓ runtime re-seed contains no example principles (G5 preserved)"; PASS=$((PASS+1))
fi

# But the explicit install-time seed SHOULD still include them.
setup_tmp_repo > /dev/null
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
PFILE="$(ac_principles_path)"
ac_principles_seed   # install-time path
assert_file_contains "$PFILE" "Prefer explicit over implicit"

report_results
