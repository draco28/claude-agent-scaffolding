#!/usr/bin/env bash
# tests/test-handoff.sh — 16 tests for lib/handoff.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/handoff.sh"

# 1. dir resolves to <ai_workspace>/.workspace/handoffs
test_dir_resolution() {
  echo "test_dir_resolution:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local d
  d="$(sd_handoff_dir)"
  assert_eq "dir under ai workspace" "$TMP_AI_WORKSPACE/.workspace/handoffs" "$d"
}

# 2. ensure_dir creates the dir if missing
test_ensure_dir_creates() {
  echo "test_ensure_dir_creates:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  # Manifest setup creates .workspace/ but not handoffs/.
  assert_file_missing "$TMP_AI_WORKSPACE/.workspace/handoffs"
  sd_handoff_ensure_dir
  assert_file_exists "$TMP_AI_WORKSPACE/.workspace/handoffs"
}

# 3. ensure_dir is idempotent
test_ensure_dir_idempotent() {
  echo "test_ensure_dir_idempotent:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_handoff_ensure_dir
  set +e
  sd_handoff_ensure_dir
  local rc=$?
  :
  assert_eq "second ensure rc=0" "0" "$rc"
}

# 4. short_id returns 4-char hex
test_short_id_format() {
  echo "test_short_id_format:"
  local id
  id="$(sd_handoff_short_id)"
  if [[ "$id" =~ ^[0-9a-f]{4}$ ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') short_id is 4-hex"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') short_id wrong format: $id"
  fi
}

# 5. short_id distinct across calls (likely-distinct test)
test_short_id_distinct() {
  echo "test_short_id_distinct:"
  local a b c
  a="$(sd_handoff_short_id)"
  b="$(sd_handoff_short_id)"
  c="$(sd_handoff_short_id)"
  # With 16-bit space, collisions can happen but rare. We accept ≥2 distinct.
  local distinct
  distinct="$(printf '%s\n%s\n%s\n' "$a" "$b" "$c" | sort -u | wc -l | tr -d ' ')"
  if [[ "$distinct" -ge 2 ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') short_id distinct ($a $b $c)"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') all 3 ids identical: $a"
  fi
}

# 6. compose_path with no return suffix
test_compose_path_basic() {
  echo "test_compose_path_basic:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local p
  p="$(sd_handoff_compose_path "slice" "auth-flow" "abcd")"
  assert_eq "compose basic" "$TMP_AI_WORKSPACE/.workspace/handoffs/slice-auth-flow-abcd.md" "$p"
}

# 7. compose_path with sprint scope
test_compose_path_sprint() {
  echo "test_compose_path_sprint:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local p
  p="$(sd_handoff_compose_path "sprint" "carry-forward" "ffff")"
  assert_contains "sprint scope in name" "sprint-carry-forward-ffff.md" "$p"
}

# 8. compose_path with --return suffix
test_compose_path_return() {
  echo "test_compose_path_return:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local p
  p="$(sd_handoff_compose_path "mid-slice" "deep-dive" "0001" "-return")"
  assert_contains "return suffix" "mid-slice-deep-dive-0001-return.md" "$p"
}

# 9. list with prefix returns matching files
test_list_with_prefix() {
  echo "test_list_with_prefix:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_handoff_ensure_dir
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/vs-3.2-foo-aaaa.md"
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/vs-3.2-bar-bbbb.md"
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/vs-4.1-baz-cccc.md"
  local out
  out="$(sd_handoff_list "vs-3.2-")"
  local count
  count="$(echo "$out" | wc -l | tr -d ' ')"
  assert_eq "2 vs-3.2-* matches" "2" "$count"
}

# 10. list with prefix excludes non-matching
test_list_exclusion() {
  echo "test_list_exclusion:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_handoff_ensure_dir
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/vs-3.2-foo-aaaa.md"
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/vs-4.1-baz-cccc.md"
  local out
  out="$(sd_handoff_list "vs-3.2-")"
  if [[ "$out" == *"vs-4.1"* ]]; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') vs-4.1 should be excluded"
  else
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') vs-4.1 excluded"
  fi
}

# 11. list on empty dir returns empty (rc may be 0 or 1)
test_list_empty() {
  echo "test_list_empty:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_handoff_ensure_dir
  local out
  out="$(sd_handoff_list "vs-9.9-" 2>/dev/null)"
  assert_eq "empty list" "" "$out"
}

# 12. cleanup_sprint removes sprint-N-* files
test_cleanup_sprint_removes() {
  echo "test_cleanup_sprint_removes:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_handoff_ensure_dir
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-3-foo-aaaa.md"
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/vs-3.2-bar-bbbb.md"
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/vs-3.5-baz-cccc.md"
  sd_handoff_cleanup_sprint "3"
  assert_file_missing "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-3-foo-aaaa.md"
  assert_file_missing "$TMP_AI_WORKSPACE/.workspace/handoffs/vs-3.2-bar-bbbb.md"
}

# 13. cleanup_sprint preserves carry-forward exception
test_cleanup_carry_forward() {
  echo "test_cleanup_carry_forward:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_handoff_ensure_dir
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-3-foo-aaaa.md"
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-3-to-4-handoff-bbbb.md"
  sd_handoff_cleanup_sprint "3" "sprint-3-to-4-handoff-"
  assert_file_missing "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-3-foo-aaaa.md"
  assert_file_exists "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-3-to-4-handoff-bbbb.md"
}

# 14. cleanup_sprint doesn't touch other sprints
test_cleanup_isolates_sprint() {
  echo "test_cleanup_isolates_sprint:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_handoff_ensure_dir
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-3-foo-aaaa.md"
  touch "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-4-bar-bbbb.md"
  sd_handoff_cleanup_sprint "3"
  assert_file_missing "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-3-foo-aaaa.md"
  assert_file_exists  "$TMP_AI_WORKSPACE/.workspace/handoffs/sprint-4-bar-bbbb.md"
}

# 15. cleanup_sprint with no matching files succeeds
test_cleanup_no_match() {
  echo "test_cleanup_no_match:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_handoff_ensure_dir
  set +e
  sd_handoff_cleanup_sprint "99"
  local rc=$?
  :
  assert_eq "no-match cleanup rc=0" "0" "$rc"
}

# 16. compose_path uses scope-purpose-id naming
test_compose_path_full_naming() {
  echo "test_compose_path_full_naming:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local p
  p="$(sd_handoff_compose_path "bugfix" "fix-race" "1234")"
  local base
  base="$(basename "$p")"
  assert_eq "naming" "bugfix-fix-race-1234.md" "$base"
}

test_dir_resolution
test_ensure_dir_creates
test_ensure_dir_idempotent
test_short_id_format
test_short_id_distinct
test_compose_path_basic
test_compose_path_sprint
test_compose_path_return
test_list_with_prefix
test_list_exclusion
test_list_empty
test_cleanup_sprint_removes
test_cleanup_carry_forward
test_cleanup_isolates_sprint
test_cleanup_no_match
test_compose_path_full_naming

sd_test_summary
