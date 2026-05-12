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

test_phases_present
test_phase_extract
test_kv_parse
test_kv_parse_missing
test_project_class_helper
report_results
