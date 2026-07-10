#!/usr/bin/env bash
# tests/test-harvest.sh — contract tests for lib/harvest.sh (sd_harvest_apply)

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
  local items='[{"source":"report","work_item":"1.01","target_file":"10-decisions-log.md","text":"Atomic writes for state."}]'
  sd_harvest_apply "$items" "VS-3.2.1"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/10-decisions-log.md" "Atomic writes for state"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/10-decisions-log.md" "Added from VS-3.2.1 retrospective"
}

# 2. apply is idempotent — re-applying same item doesn't duplicate
test_apply_idempotent() {
  echo "test_apply_idempotent:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  local items='[{"source":"report","work_item":"1.01","target_file":"10-decisions-log.md","text":"Identical line."}]'
  sd_harvest_apply "$items" "VS-3.2.1"
  sd_harvest_apply "$items" "VS-3.2.1"
  local count
  count="$(grep -c "Identical line" "$TMP_AI_WORKSPACE/.claude/memory-bank/10-decisions-log.md")"
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

# #102 — a spec-derived target is rejected before any file is seeded or changed.
test_apply_rejects_derived_target_atomically() {
  echo "test_apply_rejects_derived_target_atomically:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  echo "# Code Patterns" > "$TMP_AI_WORKSPACE/.claude/memory-bank/02-system-patterns.md"
  local items='[{"source":"report","work_item":"1.01","target_file":"02-system-patterns.md","text":"watch the startup race"}]'
  local rc=0
  sd_harvest_apply "$items" "VS-3.2.1" 2>/dev/null || rc=$?
  assert_eq "derived target returns rc=1" "1" "$rc"
  assert_file_not_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/02-system-patterns.md" "startup race"
  assert_file_missing "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md"
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

test_apply_accepts_legacy_suggestion_field() {
  echo "test_apply_accepts_legacy_suggestion_field:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local items='[{"source":"report","target_file":"09-known-issues.md","suggestion":"legacy report suggestion"}]'
  sd_harvest_apply "$items" "VS-3.2.1"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md" "legacy report suggestion"
}

test_apply_prefers_canonical_text_field() {
  echo "test_apply_prefers_canonical_text_field:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local items='[{"source":"report","target_file":"09-known-issues.md","text":"canonical text","suggestion":"legacy text"}]'
  sd_harvest_apply "$items" "VS-3.2.1"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md" "canonical text"
  assert_file_not_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md" "legacy text"
}

test_apply_rejects_empty_canonical_text() {
  echo "test_apply_rejects_empty_canonical_text:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local items='[{"source":"report","target_file":"09-known-issues.md","text":"   ","suggestion":"must not mask invalid canonical content"}]'
  assert_exit_code 1 sd_harvest_apply "$items" "VS-3.2.1"
  assert_file_missing "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md"
}

test_apply_rejects_mixed_array_before_writing() {
  echo "test_apply_rejects_mixed_array_before_writing:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local items='[
    {"source":"report","target_file":"09-known-issues.md","text":"would otherwise write"},
    {"source":"handoff","target_file":"10-decisions-log.md"}
  ]'
  local rc=0
  sd_harvest_apply "$items" "VS-3.2.1" 2>/dev/null || rc=$?
  assert_eq "mixed invalid array returns rc=1" "1" "$rc"
  assert_file_missing "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md"
  assert_file_missing "$TMP_AI_WORKSPACE/.claude/memory-bank/10-decisions-log.md"
}

test_apply_rejects_invalid_source_before_writing() {
  echo "test_apply_rejects_invalid_source_before_writing:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local items='[{"source":"unknown","target_file":"09-known-issues.md","text":"bad source"}]'
  assert_exit_code 1 sd_harvest_apply "$items" "VS-3.2.1"
  assert_file_missing "$TMP_AI_WORKSPACE/.claude/memory-bank/09-known-issues.md"
}

test_apply_rejects_unsupported_target_before_writing() {
  echo "test_apply_rejects_unsupported_target_before_writing:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local items='[{"source":"report","target_file":"custom-notes.md","text":"unsupported target"}]'
  assert_exit_code 1 sd_harvest_apply "$items" "VS-3.2.1"
  assert_file_missing "$TMP_AI_WORKSPACE/.claude/memory-bank/custom-notes.md"
}

test_apply_rejects_non_array_payload() {
  echo "test_apply_rejects_non_array_payload:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  assert_exit_code 1 sd_harvest_apply '{"text":"not an array"}' "VS-3.2.1"
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

test_lint_length_under_threshold() {
  echo "test_lint_length_under_threshold:"
  # 3-line entry, default threshold 12 -> lean (return 0)
  local text=$'line one\nline two\nline three'
  set +e
  sd_harvest_lint_length "$text" >/dev/null
  local rc=$?
  :
  assert_eq "3-line entry is lean" "0" "$rc"
}

test_lint_length_over_threshold() {
  echo "test_lint_length_over_threshold:"
  # 15-line entry, default threshold 12 -> flagged (return 1), count echoed
  local text; text="$(printf 'l%.0s\n' $(seq 1 15))"
  local count rc
  set +e
  count="$(sd_harvest_lint_length "$text")"; rc="$?"
  :
  assert_eq "15-line entry is flagged" "1" "$rc"
  assert_eq "echoes the line count" "15" "$count"
}

test_lint_length_custom_threshold() {
  echo "test_lint_length_custom_threshold:"
  local text=$'a\nb\nc\nd\ne'   # 5 lines, threshold 4 -> flagged
  set +e
  sd_harvest_lint_length "$text" 4 >/dev/null
  local rc=$?
  :
  assert_eq "5-line entry flagged at threshold 4" "1" "$rc"
}

test_apply_writes_trailer
test_apply_idempotent
test_apply_empty
test_apply_rejects_derived_target_atomically
test_apply_allows_dev_authored_target
test_apply_accepts_legacy_suggestion_field
test_apply_prefers_canonical_text_field
test_apply_rejects_empty_canonical_text
test_apply_rejects_mixed_array_before_writing
test_apply_rejects_invalid_source_before_writing
test_apply_rejects_unsupported_target_before_writing
test_apply_rejects_non_array_payload
test_assert_file_not_contains_missing_file_fails
test_lint_length_under_threshold
test_lint_length_over_threshold
test_lint_length_custom_threshold

sd_test_summary
