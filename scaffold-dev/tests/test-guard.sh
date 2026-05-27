#!/usr/bin/env bash
# Tests for cross-agent live-state guard helpers.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/guard.sh"
source "$HERE/../lib/state.sh"

test_lock_acquire_blocks_second_holder() {
  echo "test_lock_acquire_blocks_second_holder:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local lock rc
  lock="$(sd_guard_lock_acquire active-context)"
  set +e
  sd_guard_lock_acquire active-context >/dev/null 2>&1
  rc=$?
  :
  assert_eq "second lock acquire fails" "1" "$rc"
  sd_guard_lock_release "$lock"
}

test_cursor_write_adds_provenance_and_releases_lock() {
  echo "test_cursor_write_adds_provenance_and_releases_lock:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  mkdir -p "$TMP_AI_WORKSPACE/.claude/memory-bank"
  SCAFFOLD_HOST_AGENT=codex sd_state_write_cursor 1 "VS-1.1" "1.01"
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/05-active-context.md" 'sd:provenance surface=active-context'
  assert_file_contains "$TMP_AI_WORKSPACE/.claude/memory-bank/05-active-context.md" 'host=codex'
  if [[ -d "$TMP_AI_WORKSPACE/.workspace/locks/active-context.lock" ]]; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') lock left behind"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') lock released"
  fi
}

test_lock_acquire_blocks_second_holder
test_cursor_write_adds_provenance_and_releases_lock

sd_test_summary
