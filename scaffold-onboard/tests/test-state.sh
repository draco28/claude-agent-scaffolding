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

test_phase_advance() {
  echo "test_phase_advance:"
  setup_tmp_repo
  sf_state_init
  sf_state_advance_phase
  local p
  p="$(sf_state_read_field current_phase)"
  assert_eq "current_phase after advance" "2" "$p"
}

test_phase_complete_marks_status() {
  echo "test_phase_complete_marks_status:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic current_phase 10
  sf_state_advance_phase
  local status
  status="$(sf_state_read_field status)"
  assert_eq "status after phase 10 advance" "complete" "$status"
}

test_branching_gate_ui() {
  echo "test_branching_gate_ui:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.3.1" "Web app"
  assert_exit_code 0 sf_state_gate_passes "project_class in {Web app, Mobile app}"
}

test_branching_gate_dx() {
  echo "test_branching_gate_dx:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.3.1" "Library or SDK"
  assert_exit_code 1 sf_state_gate_passes "project_class in {Web app, Mobile app}"
}

test_state_init
test_state_atomic_write
test_state_read_missing_field
test_answer_write_read
test_answer_with_special_chars
test_lock_acquire_release
test_lock_refusal
test_phase_advance
test_phase_complete_marks_status
test_mode_new() {
  echo "test_mode_new:"
  setup_tmp_repo
  rm -f "$(sf_state_path)"  # ensure no state
  local mode
  mode="$(sf_state_mode)"
  assert_eq "no state -> new" "new" "$mode"
}

test_mode_resume() {
  echo "test_mode_resume:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic current_phase 5
  local mode
  mode="$(sf_state_mode)"
  assert_eq "in_progress -> resume" "resume" "$mode"
}

test_mode_reonboard() {
  echo "test_mode_reonboard:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic status complete
  local mode
  mode="$(sf_state_mode)"
  assert_eq "complete -> reonboard" "reonboard" "$mode"
}

test_branching_gate_ui
test_branching_gate_dx
test_mode_new
test_mode_resume
test_mode_reonboard
report_results
