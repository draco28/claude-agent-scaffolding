#!/usr/bin/env bash
# tests/test-harvest.sh — 6 tests for lib/harvest.sh (sd_harvest_apply)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/harvest.sh"

# 1. apply writes items to target_file with provenance trailer
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

# 2. apply is idempotent — re-applying same item doesn't duplicate
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

# 3. apply handles empty items array gracefully
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

# SS-1 W4 — harvest aimed at a spec-derived file is rerouted to 09-known-issues
# (never silently appended into the derived file).
test_apply_reroutes_derived_target() {
  echo "test_apply_reroutes_derived_target:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  echo "# Code Patterns" > "$TMP_AI_WORKSPACE/.claude/memory-bank/02-system-patterns.md"
  local items='[{"source":"report","work_item":"1.01","target_file":"02-system-patterns.md","suggestion":"watch the startup race"}]'
  sd_harvest_apply "$items" "VS-3.2.1" 2>/dev/null
  # The derived file is untouched; the note landed in 09-known-issues.md instead.
  assert_file_not_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/02-system-patterns.md" "startup race"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md" "startup race"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md" "Memory-bank update cadence"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md" "Caveats & gotchas"
}

# 09 / 10 (dev-authored) remain valid targets.
test_apply_allows_dev_authored_target() {
  echo "test_apply_allows_dev_authored_target:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  local items='[{"source":"handoff","handoff_file":"vs-3.2.1-x.md","target_file":"10-decisions-log.md","item":"chose file-lock for the registry"}]'
  sd_harvest_apply "$items" "VS-3.2.1"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/10-decisions-log.md" "chose file-lock for the registry"
  # SS-1 review fix — a missing 10-decisions-log.md is seeded from its template
  # (cadence pointer + Decisions section), not a bare header, so a later
  # /scaffold-project preserving it keeps the contract shape.
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/10-decisions-log.md" "Memory-bank update cadence"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/10-decisions-log.md" "Decisions"
}

test_assert_file_not_contains_missing_file_fails() {
  echo "test_assert_file_not_contains_missing_file_fails:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local pass_before fail_before out out_file delta
  pass_before="$PASS"
  fail_before="$FAIL"
  out_file="$TMP_DIR/not-contains-missing.out"
  assert_file_not_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/missing.md" "anything" > "$out_file" 2>&1
  out="$(cat "$out_file")"
  delta=$((FAIL - fail_before))
  PASS="$pass_before"
  FAIL="$fail_before"
  assert_eq "missing file increments FAIL" "1" "$delta"
  assert_contains "missing-file failure message" "file missing for not-contains-check" "$out"
}

test_apply_writes_trailer
test_apply_idempotent
test_apply_empty
test_apply_reroutes_derived_target
test_apply_allows_dev_authored_target
test_assert_file_not_contains_missing_file_fails

sd_test_summary
