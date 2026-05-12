#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"

test_state_init() {
  echo "test_state_init:"
  setup_tmp_repo
  sf_state_init
  assert_file_exists "$(sf_state_path)"
  assert_file_contains "$(sf_state_path)" '"status": "in_progress"'
  assert_file_contains "$(sf_state_path)" '"current_phase": 1'
}

test_state_init
report_results
