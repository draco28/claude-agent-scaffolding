#!/usr/bin/env bash
# test-principles.sh — tests for lib/principles.sh (Phase B, Task TB.2)
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
SCRIPT_DIR="$TESTS_DIR"  # backward-compat for fixtures path below

source "$TESTS_DIR/_helpers.sh"
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

# ===========================================================================
# v0.2 Phase 3.2: shipped-default tag + merge order (HTML-comment contract)
# ===========================================================================

echo ""
echo "=== v0.2 Phase 3.2: shipped-default + merge order ==="

# Helper: write a user-global principles.md with one user-promoted principle
# (HTML-comment-tagged) and (optionally) a project-scoped principles.md.
_v02_setup_user_global() {
  local pfile
  pfile="$(ac_principles_user_path)"
  mkdir -p "$(dirname "$pfile")"
  cat > "$pfile" <<'EOF'
# Architect-critic principles (user-global)

## Your principles (user-promoted)

<!-- source: user-promoted, promoted_at: 2026-05-22T10:00:00Z, principle_id: pp-user1 -->
- **User promoted principle one:** explicit beats implicit in all configs.
EOF
}

_v02_setup_project() {
  local pfile
  pfile="$(ac_principles_project_path)"
  [[ -z "$pfile" ]] && return 0
  mkdir -p "$(dirname "$pfile")"
  cat > "$pfile" <<'EOF'
# Architect-critic principles (project)

## Project principles (scope=project)

<!-- source: project, promoted_at: 2026-05-23T11:00:00Z, principle_id: pp-proj1 -->
- **Project principle one:** YAML uses 2-space indent in this repo.
EOF
}

# Override HOME to the per-test tmp dir so user-global path is isolated.
_v02_isolate_home() {
  export HOME="$TMP_DIR/home"
  mkdir -p "$HOME/.claude/architect-critic"
}

# ---------------------------------------------------------------------------
# v0.2 T1: parse HTML comment meta keys (source / principle_id / promoted_at)
# ---------------------------------------------------------------------------
echo "--- v0.2 T1: ac_principles_parse_meta extracts keys correctly ---"
setup_tmp_repo > /dev/null
_v02_isolate_home
tmp_meta_file="$TMP_DIR/meta-fixture.md"
cat > "$tmp_meta_file" <<'EOF'
# header

<!-- source: user-promoted, promoted_at: 2026-05-22T10:00:00Z, principle_id: pp-abc123 -->
- **Some user principle:** body text here.

<!-- source: shipped-default, principle_id: pp-ghost-notes -->
- **Ghost notes:** Look for what is absent.
EOF

meta_out="$(ac_principles_parse_meta "$tmp_meta_file")"
# Expect 2 JSON lines
line_count="$(printf '%s\n' "$meta_out" | grep -c '^{')"
assert_eq "parse_meta emits 2 JSON lines for 2 principles" "2" "$line_count"

src1="$(printf '%s\n' "$meta_out" | sed -n '1p' | jq -r '.source')"
assert_eq "parse_meta first source=user-promoted" "user-promoted" "$src1"

pid1="$(printf '%s\n' "$meta_out" | sed -n '1p' | jq -r '.principle_id')"
assert_eq "parse_meta first principle_id=pp-abc123" "pp-abc123" "$pid1"

prom1="$(printf '%s\n' "$meta_out" | sed -n '1p' | jq -r '.promoted_at')"
assert_eq "parse_meta first promoted_at" "2026-05-22T10:00:00Z" "$prom1"

src2="$(printf '%s\n' "$meta_out" | sed -n '2p' | jq -r '.source')"
assert_eq "parse_meta second source=shipped-default" "shipped-default" "$src2"

pid2="$(printf '%s\n' "$meta_out" | sed -n '2p' | jq -r '.principle_id')"
assert_eq "parse_meta second principle_id=pp-ghost-notes" "pp-ghost-notes" "$pid2"

# ---------------------------------------------------------------------------
# v0.2 T2: shipped defaults preserved on merge
# ---------------------------------------------------------------------------
echo "--- v0.2 T2: ac_principles_merge preserves shipped defaults ---"
setup_tmp_repo > /dev/null
_v02_isolate_home
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
_v02_setup_user_global

merged="$(ac_principles_merge)"
# Must include both shipped-default IDs (pp-ghost-notes + pp-core-protocol).
echo "$merged" | jq -r '.[].principle_id' | grep -q '^pp-ghost-notes$'
assert_eq "merge includes pp-ghost-notes" "0" "$?"

echo "$merged" | jq -r '.[].principle_id' | grep -q '^pp-core-protocol$'
assert_eq "merge includes pp-core-protocol" "0" "$?"

# And the user-promoted entry is also in the merge.
echo "$merged" | jq -r '.[].principle_id' | grep -q '^pp-user1$'
assert_eq "merge includes user-promoted pp-user1" "0" "$?"

# ---------------------------------------------------------------------------
# v0.2 T3a: filter by source = shipped
# ---------------------------------------------------------------------------
echo "--- v0.2 T3a: ac_principles_filter_by_source shipped ---"
setup_tmp_repo > /dev/null
_v02_isolate_home
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
_v02_setup_user_global
_v02_setup_project

shipped_only="$(ac_principles_filter_by_source shipped)"
shipped_count="$(echo "$shipped_only" | jq 'length')"
# templates/principles.md ships 2 shipped-default principles.
assert_eq "shipped filter returns 2 entries" "2" "$shipped_count"
non_shipped="$(echo "$shipped_only" | jq -r '[.[] | select(.source != "shipped-default")] | length')"
assert_eq "shipped filter contains only shipped-default" "0" "$non_shipped"

# ---------------------------------------------------------------------------
# v0.2 T3b: filter by source = user
# ---------------------------------------------------------------------------
echo "--- v0.2 T3b: ac_principles_filter_by_source user ---"
user_only="$(ac_principles_filter_by_source user)"
user_count="$(echo "$user_only" | jq 'length')"
assert_eq "user filter returns 1 entry" "1" "$user_count"
user_src="$(echo "$user_only" | jq -r '.[0].source')"
assert_eq "user filter source=user-promoted" "user-promoted" "$user_src"

# ---------------------------------------------------------------------------
# v0.2 T3c: filter by source = project
# ---------------------------------------------------------------------------
echo "--- v0.2 T3c: ac_principles_filter_by_source project ---"
project_only="$(ac_principles_filter_by_source project)"
project_count="$(echo "$project_only" | jq 'length')"
assert_eq "project filter returns 1 entry" "1" "$project_count"
project_src="$(echo "$project_only" | jq -r '.[0].source')"
assert_eq "project filter source=project" "project" "$project_src"

# ---------------------------------------------------------------------------
# v0.2 T4: user-promoted appears below shipped in display order
# ---------------------------------------------------------------------------
echo "--- v0.2 T4: user-promoted appears below shipped in display order ---"
merged="$(ac_principles_merge)"
ids="$(echo "$merged" | jq -r '.[].principle_id')"
# Position of pp-ghost-notes must come before pp-user1.
ghost_pos="$(echo "$ids" | grep -n '^pp-ghost-notes$' | cut -d: -f1)"
user_pos="$(echo "$ids" | grep -n '^pp-user1$' | cut -d: -f1)"
if [[ "$ghost_pos" -lt "$user_pos" ]]; then
  echo "  ✓ pp-ghost-notes precedes pp-user1 (shipped before user-promoted)"; PASS=$((PASS+1))
else
  echo "  ✗ ordering broken: ghost_pos=$ghost_pos user_pos=$user_pos"; FAIL=$((FAIL+1))
fi

# Project should come after user-promoted.
proj_pos="$(echo "$ids" | grep -n '^pp-proj1$' | cut -d: -f1)"
if [[ "$user_pos" -lt "$proj_pos" ]]; then
  echo "  ✓ pp-user1 precedes pp-proj1 (user-promoted before project)"; PASS=$((PASS+1))
else
  echo "  ✗ ordering broken: user_pos=$user_pos proj_pos=$proj_pos"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# v0.2 T5: project overrides user with same principle_id (last-source-wins)
# ---------------------------------------------------------------------------
echo "--- v0.2 T5: project overrides user with same principle_id ---"
setup_tmp_repo > /dev/null
_v02_isolate_home
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# User-global pp-foo
upath="$(ac_principles_user_path)"
mkdir -p "$(dirname "$upath")"
cat > "$upath" <<'EOF'
## Your principles (user-promoted)

<!-- source: user-promoted, promoted_at: 2026-05-20T10:00:00Z, principle_id: pp-foo -->
- **Foo (user version):** original text from user-global.
EOF

# Project pp-foo (same id, different text)
ppath="$(ac_principles_project_path)"
mkdir -p "$(dirname "$ppath")"
cat > "$ppath" <<'EOF'
## Project principles (scope=project)

<!-- source: project, promoted_at: 2026-05-23T11:00:00Z, principle_id: pp-foo -->
- **Foo (project override):** project-scoped replacement text.
EOF

merged="$(ac_principles_merge)"
# Expect only ONE pp-foo entry, with source=project.
foo_count="$(echo "$merged" | jq '[.[] | select(.principle_id == "pp-foo")] | length')"
assert_eq "pp-foo deduplicated to single entry" "1" "$foo_count"

foo_src="$(echo "$merged" | jq -r '.[] | select(.principle_id == "pp-foo") | .source')"
assert_eq "pp-foo final source=project (project wins)" "project" "$foo_src"

foo_override="$(echo "$merged" | jq -r '.[] | select(.principle_id == "pp-foo") | .overrides_source')"
assert_eq "pp-foo carries overrides_source=user-promoted annotation" "user-promoted" "$foo_override"

report_results
