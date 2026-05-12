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

test_state_atomic_write() {
  echo "test_state_atomic_write:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic 'current_phase' 5
  local val
  val="$(sf_state_read_field current_phase)"
  assert_eq "current_phase after write" "5" "$val"
}

test_state_read_missing_field() {
  echo "test_state_read_missing_field:"
  setup_tmp_repo
  sf_state_init
  local val
  val="$(sf_state_read_field nonexistent_key)"
  assert_eq "missing field reads as null" "null" "$val"
}

test_answer_write_read() {
  echo "test_answer_write_read:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "todo-cli — a fast task manager"
  local val
  val="$(sf_state_read_answer 1.1.1)"
  assert_eq "answer round-trip" "todo-cli — a fast task manager" "$val"
}

test_answer_with_special_chars() {
  echo "test_answer_with_special_chars:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.2.2" 'A "quoted" value with $special chars'
  local val
  val="$(sf_state_read_answer 1.2.2)"
  assert_eq "special chars preserved" 'A "quoted" value with $special chars' "$val"
}

test_lock_acquire_release() {
  echo "test_lock_acquire_release:"
  setup_tmp_repo
  sf_state_init
  sf_state_lock_acquire
  assert_file_exists "$(sf_state_lock_path)"
  sf_state_lock_release
  assert_file_missing "$(sf_state_lock_path)"
}

test_lock_refusal() {
  echo "test_lock_refusal:"
  setup_tmp_repo
  sf_state_init
  sf_state_lock_acquire
  local ec
  set +e
  sf_state_lock_acquire 2>/dev/null
  ec=$?
  set -e 2>/dev/null || true
  assert_eq "second acquire exits non-zero" "1" "$ec"
  sf_state_lock_release
}

test_state_init
test_state_atomic_write
test_state_read_missing_field
test_answer_write_read
test_answer_with_special_chars
test_lock_acquire_release
test_lock_refusal
report_results
