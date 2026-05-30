#!/usr/bin/env bash
# tests/test-harvest.sh — 12 tests for lib/harvest.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/harvest.sh"

# Helper: create a work-item report with a Suggestions section.
_mk_report() {
  local dir="$1" item="$2"
  mkdir -p "$dir/work-${item}-foo"
  cat > "$dir/work-${item}-foo/report.md" <<EOF
# Report for work-${item}

## Summary
Did the thing.

## Suggestions for memory bank

- target_file: 04-architecture.md
  suggestion: Use atomic-write pattern for state mutations.
- target_file: 03-code-patterns.md
  suggestion: Prefer jq over awk for JSON building.
EOF
}

_mk_handoff() {
  local dir="$1" slice="$2"
  mkdir -p "$dir"
  cat > "$dir/${slice}-followup.md" <<EOF
# Handoff: ${slice}

## 1. What was done
Lots.

## 4. What's NOT in memory bank yet

- We discovered that race-conditions matter; pattern needs codifying.
- Logging convention TBD for cross-plugin invocations.

## 5. Open questions
EOF
}

# 1. reports sweep extracts suggestion lines as JSON array
test_reports_sweep_basic() {
  echo "test_reports_sweep_basic:"
  setup_tmp_repo
  local slice="$TMP_DIR/repo/sprint-3.2/VS-3.2.1-foo"
  mkdir -p "$slice"
  _mk_report "$slice" "1.01"
  local out
  out="$(sd_harvest_reports "$slice")"
  local count
  count="$(echo "$out" | jq 'length')"
  assert_eq "2 suggestions parsed" "2" "$count"
}

# 2. reports sweep tags source as "report"
test_reports_source_tag() {
  echo "test_reports_source_tag:"
  setup_tmp_repo
  local slice="$TMP_DIR/repo/sprint-3.2/VS-3.2.1-foo"
  mkdir -p "$slice"
  _mk_report "$slice" "1.01"
  local source
  source="$(sd_harvest_reports "$slice" | jq -r '.[0].source')"
  assert_eq "source=report" "report" "$source"
}

# 3. reports sweep includes work_item id
test_reports_work_item() {
  echo "test_reports_work_item:"
  setup_tmp_repo
  local slice="$TMP_DIR/repo/sprint-3.2/VS-3.2.1-foo"
  mkdir -p "$slice"
  _mk_report "$slice" "1.01"
  local work_item
  work_item="$(sd_harvest_reports "$slice" | jq -r '.[0].work_item')"
  assert_eq "work_item id" "1.01" "$work_item"
}

# 4. reports sweep captures target_file
test_reports_target_file() {
  echo "test_reports_target_file:"
  setup_tmp_repo
  local slice="$TMP_DIR/repo/sprint-3.2/VS-3.2.1-foo"
  mkdir -p "$slice"
  _mk_report "$slice" "1.01"
  local tf
  tf="$(sd_harvest_reports "$slice" | jq -r '.[0].target_file')"
  assert_eq "target_file" "04-architecture.md" "$tf"
}

# 5. reports sweep — multiple work items
test_reports_multi_workitem() {
  echo "test_reports_multi_workitem:"
  setup_tmp_repo
  local slice="$TMP_DIR/repo/sprint-3.2/VS-3.2.1-foo"
  mkdir -p "$slice"
  _mk_report "$slice" "1.01"
  _mk_report "$slice" "1.02"
  local count
  count="$(sd_harvest_reports "$slice" | jq 'length')"
  assert_eq "4 across 2 reports" "4" "$count"
}

# 6. reports sweep — empty slice returns []
test_reports_empty() {
  echo "test_reports_empty:"
  setup_tmp_repo
  local slice="$TMP_DIR/repo/sprint-3.2/VS-3.2.1-empty"
  mkdir -p "$slice"
  local out
  out="$(sd_harvest_reports "$slice")"
  assert_eq "empty slice -> []" "[]" "$out"
}

# 7. handoffs sweep extracts section 4 items
test_handoffs_sweep() {
  echo "test_handoffs_sweep:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_handoff "$TMP_AI_WORKSPACE/.workspace/handoffs" "vs-3.2-mid"
  local out
  out="$(sd_harvest_handoffs "vs-3.2")"
  local count
  count="$(echo "$out" | jq 'length')"
  assert_eq "2 handoff items" "2" "$count"
}

# 8. handoffs sweep tags source="handoff"
test_handoffs_source_tag() {
  echo "test_handoffs_source_tag:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_handoff "$TMP_AI_WORKSPACE/.workspace/handoffs" "vs-3.2-mid"
  local source
  source="$(sd_harvest_handoffs "vs-3.2" | jq -r '.[0].source')"
  assert_eq "source=handoff" "handoff" "$source"
}

# 9. handoffs sweep prefix filter — different slice excluded
test_handoffs_filter() {
  echo "test_handoffs_filter:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  _mk_handoff "$TMP_AI_WORKSPACE/.workspace/handoffs" "vs-3.2-mid"
  _mk_handoff "$TMP_AI_WORKSPACE/.workspace/handoffs" "vs-4.1-mid"
  local out
  out="$(sd_harvest_handoffs "vs-3.2" | jq 'length')"
  assert_eq "filter excludes other slice" "2" "$out"
}

# 10. apply writes items to target_file with provenance trailer
test_apply_writes_trailer() {
  echo "test_apply_writes_trailer:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  echo "# Architecture" > "$TMP_AI_WORKSPACE/.claude/memory-bank/04-architecture.md"
  local items='[{"source":"report","work_item":"1.01","target_file":"04-architecture.md","suggestion":"Atomic writes for state."}]'
  sd_harvest_apply "$items" "VS-3.2.1"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/04-architecture.md" "Atomic writes for state"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/04-architecture.md" "Added from VS-3.2.1 retrospective"
}

# 11. apply is idempotent — re-applying same item doesn't duplicate
test_apply_idempotent() {
  echo "test_apply_idempotent:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  echo "# Architecture" > "$TMP_AI_WORKSPACE/.claude/memory-bank/04-architecture.md"
  local items='[{"source":"report","work_item":"1.01","target_file":"04-architecture.md","suggestion":"Identical line."}]'
  sd_harvest_apply "$items" "VS-3.2.1"
  sd_harvest_apply "$items" "VS-3.2.1"
  local count
  count="$(grep -c "Identical line" "$TMP_AI_WORKSPACE/.claude/memory-bank/04-architecture.md")"
  assert_eq "no duplicate after re-apply" "1" "$count"
}

# 12. apply handles empty items array gracefully
test_apply_empty() {
  echo "test_apply_empty:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  set +e
  sd_harvest_apply '[]' "VS-3.2.1" 2>/dev/null
  local rc=$?
  :
  assert_eq "empty apply rc=0" "0" "$rc"
}

test_reports_sweep_basic
test_reports_source_tag
test_reports_work_item
test_reports_target_file
test_reports_multi_workitem
test_reports_empty
test_handoffs_sweep
test_handoffs_source_tag
test_handoffs_filter
test_apply_writes_trailer
test_apply_idempotent
test_apply_empty

sd_test_summary
