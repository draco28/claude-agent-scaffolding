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

test_phase_10_stops_before_post_mvp_appendix() {
  echo "test_phase_10_stops_before_post_mvp_appendix:"
  local spec="$FIXTURE_DIR/phase-10-appendix.md"
  cat > "$spec" <<'EOF'
# proj — Master Specification

**Spec version:** 1.0
**Project class:** CLI tool

## Executive Summary

Body.
EOF
  local i
  for i in 1 2 3 4 5 6 7 8 9; do
    cat >> "$spec" <<EOF
<!-- master-spec:phase id=$i name=p$i -->
## Phase $i: Stuff

Phase $i content.

EOF
  done
  cat >> "$spec" <<'EOF'
<!-- master-spec:phase id=10 name=Operations & Support -->
## Phase 10: Operations & Support

Runbooks and support ownership.

## Appendix: Post-MVP Horizon

Deferred item: multi-region failover.
EOF

  local content
  content="$(sf_spec_phase "$spec" 10)"
  if echo "$content" | grep -q "Runbooks and support ownership"; then
    PASS=$((PASS+1)); echo "  ✓ phase 10 contains operations content"
  else
    FAIL=$((FAIL+1)); echo "  ✗ phase 10 missing operations content"
  fi
  if echo "$content" | grep -q "multi-region failover"; then
    FAIL=$((FAIL+1)); echo "  ✗ phase 10 leaks post-MVP appendix content"
  else
    PASS=$((PASS+1)); echo "  ✓ phase 10 stops before post-MVP appendix"
  fi
  assert_exit_code 0 sf_spec_validate "$spec"
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

test_phases_present
test_phase_extract
test_phase_10_stops_before_post_mvp_appendix
test_kv_parse
test_kv_parse_missing
test_project_class_helper
test_subsection_extract
test_summary_extract
test_validate_full_ok
test_validate_missing_file
test_validate_missing_phase
test_validate_invalid_project_class
report_results
