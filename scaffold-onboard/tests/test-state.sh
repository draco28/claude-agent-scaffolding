#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/routing.sh"
source "$HERE/../lib/roadmap.sh"

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

test_phases_yaml_question_ids_for_phase() {
  echo "test_phases_yaml_question_ids_for_phase:"
  setup_tmp_repo
  local pyaml="$HERE/../templates/onboarding-questions/phases.yaml"
  local ids
  ids="$(sf_phases_questions_for "$pyaml" 1)"
  if echo "$ids" | grep -q "1.1.1"; then
    PASS=$((PASS+1)); echo "  ✓ phase 1 contains question 1.1.1"
  else
    FAIL=$((FAIL+1)); echo "  ✗ phase 1 missing 1.1.1: $ids"
  fi
}

test_phases_yaml_question_ids_for_phase

test_scripted_full_onboarding() {
  echo "test_scripted_full_onboarding:"
  setup_tmp_repo
  local pyaml="$HERE/../templates/onboarding-questions/phases.yaml"
  local tmpl="$HERE/../templates/master-spec/MASTER-SPEC.md.tmpl"
  source "$HERE/../lib/render.sh"
  sf_state_init
  # Project class first (gates everything else)
  sf_state_write_answer "1.3.1" "CLI tool"
  # Init MASTER-SPEC with project_name + project_class
  sf_master_spec_init "$tmpl" "todo-cli" "CLI tool"
  # Fill a few representative answers across phases
  sf_state_write_answer "1.1.1" "todo-cli — fast local-first task manager"
  sf_state_write_answer "1.1.2" "Existing managers are heavy and cloud-coupled."
  sf_state_write_answer "1.2.1" "Solo devs and ops engineers."
  sf_state_write_answer "1.3.2" "add/list/complete tasks; persist to ~/.todo.json"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "5.2.2" "file (~/.todo.json)"
  sf_state_write_answer "7.1.2" "statically typed Rust"
  sf_state_write_answer "9.3.1" "no"

  # Update each phase to reflect state
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done

  assert_file_exists "./MASTER-SPEC.md"
  assert_file_contains "./MASTER-SPEC.md" "todo-cli — fast local-first task manager"
  assert_file_contains "./MASTER-SPEC.md" '\*\*Project class:\*\* CLI tool'
  assert_file_contains "./MASTER-SPEC.md" "Rust"

  # Validate the produced spec
  source "$HERE/../lib/parser.sh"
  assert_exit_code 0 sf_spec_validate ./MASTER-SPEC.md
}

test_scripted_full_onboarding

# T7.4 — Confirm onboarding-state.json and project-roadmap.json are separate
# state files (no conflict between sf_state_* and sf_roadmap_state_* writers
# in the same plugin-data directory). Per SPEC §7.2.
test_state_and_roadmap_state_paths_distinct() {
  echo "test_state_and_roadmap_state_paths_distinct:"
  setup_tmp_repo
  local sp rp
  sp="$(sf_state_path)"
  rp="$(sf_roadmap_state_path)"
  if [[ "$sp" != "$rp" ]]; then
    PASS=$((PASS+1)); echo "  ✓ onboarding-state vs project-roadmap state paths are distinct"
  else
    FAIL=$((FAIL+1)); echo "  ✗ state paths collide: $sp == $rp"
  fi
  # And both must live under the same CLAUDE_PLUGIN_DATA root.
  if [[ "$sp" == "$CLAUDE_PLUGIN_DATA/"* && "$rp" == "$CLAUDE_PLUGIN_DATA/"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ both state files rooted under CLAUDE_PLUGIN_DATA"
  else
    FAIL=$((FAIL+1)); echo "  ✗ state files not rooted under CLAUDE_PLUGIN_DATA (sp=$sp, rp=$rp)"
  fi
}

test_state_and_roadmap_state_paths_distinct
report_results
