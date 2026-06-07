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
  # Phase-10 advance now sets close_pending (not complete); complete is set only
  # by the §8 close ceremony on success (sf state_write_atomic status complete).
  assert_eq "status after phase 10 advance" "close_pending" "$status"
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

test_mode_close_pending_is_resume() {
  echo "test_mode_close_pending_is_resume:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic status close_pending
  local mode
  mode="$(sf_state_mode)"
  assert_eq "close_pending -> resume" "resume" "$mode"
}

# Guard against regression: complete still routes to reonboard (unchanged).
test_mode_complete_still_reonboard() {
  echo "test_mode_complete_still_reonboard:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic status complete
  local mode
  mode="$(sf_state_mode)"
  assert_eq "complete -> reonboard (regression guard)" "reonboard" "$mode"
}

# After sf_state_init then advancing through phase 10, status=close_pending AND
# sf_state_mode returns resume (not reonboard).
test_advance_through_phase10_gives_close_pending_resume() {
  echo "test_advance_through_phase10_gives_close_pending_resume:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_atomic current_phase 10
  sf_state_advance_phase
  local status mode
  status="$(sf_state_read_field status)"
  mode="$(sf_state_mode)"
  assert_eq "status after phase-10 advance" "close_pending" "$status"
  assert_eq "mode after phase-10 advance" "resume" "$mode"
}

test_branching_gate_ui
test_branching_gate_dx
test_mode_new
test_mode_resume
test_mode_reonboard
test_mode_close_pending_is_resume
test_mode_complete_still_reonboard
test_advance_through_phase10_gives_close_pending_resume

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
  sf_state_init
  # Project class first (gates everything else)
  sf_state_write_answer "1.3.1" "CLI tool"
  # Fill a few representative answers across phases
  sf_state_write_answer "1.1.1" "todo-cli — fast local-first task manager"
  sf_state_write_answer "1.1.2" "Existing managers are heavy and cloud-coupled."
  sf_state_write_answer "1.2.1" "Solo devs and ops engineers."
  sf_state_write_answer "1.3.2" "add/list/complete tasks; persist to ~/.todo.json"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "5.2.2" "file (~/.todo.json)"
  sf_state_write_answer "7.1.2" "statically typed Rust"
  sf_state_write_answer "9.3.1" "no"

  # Write a valid MASTER-SPEC.md fixture directly (sf_master_spec_init and
  # sf_master_spec_update_phase were removed in SS-3; tests seed fixtures instead).
  # The pitch arg ensures the exact phrase from state answer 1.1.1 is present in
  # the fixture's Executive Summary without a post-write printf patch.
  seed_master_spec_fixture "./MASTER-SPEC.md" "todo-cli" "CLI tool" "todo-cli — fast local-first task manager"

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

test_project_scoped_state_paths_differ() {
  echo "test_project_scoped_state_paths_differ:"
  TMP_DIR="$(mktemp -d -t scaffold-onboard-project-state.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$TMP_DIR/project-a" "$TMP_DIR/project-b"
  git -C "$TMP_DIR/project-a" init -q
  git -C "$TMP_DIR/project-b" init -q
  cd "$TMP_DIR/project-a"
  local path_a
  path_a="$(sf_state_path)"
  cd "$TMP_DIR/project-b"
  local path_b
  path_b="$(sf_state_path)"
  if [[ "$path_a" != "$path_b" ]]; then
    PASS=$((PASS+1)); echo "  ✓ two projects get different onboarding state paths"
  else
    FAIL=$((FAIL+1)); echo "  ✗ project state paths collide: $path_a"
  fi
}

test_project_scoped_state_writes_are_isolated() {
  echo "test_project_scoped_state_writes_are_isolated:"
  TMP_DIR="$(mktemp -d -t scaffold-onboard-project-state.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$TMP_DIR/project-a" "$TMP_DIR/project-b"
  git -C "$TMP_DIR/project-a" init -q
  git -C "$TMP_DIR/project-b" init -q
  cd "$TMP_DIR/project-a"
  sf_state_init
  sf_state_write_answer "1.1.1" "Project A"
  cd "$TMP_DIR/project-b"
  sf_state_init
  sf_state_write_answer "1.1.1" "Project B"
  local b_val
  b_val="$(sf_state_read_answer "1.1.1")"
  cd "$TMP_DIR/project-a"
  local a_val
  a_val="$(sf_state_read_answer "1.1.1")"
  assert_eq "project A state remains isolated" "Project A" "$a_val"
  assert_eq "project B state remains isolated" "Project B" "$b_val"
}

test_project_scoped_lock_paths_differ() {
  echo "test_project_scoped_lock_paths_differ:"
  TMP_DIR="$(mktemp -d -t scaffold-onboard-project-state.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$TMP_DIR/project-a" "$TMP_DIR/project-b"
  git -C "$TMP_DIR/project-a" init -q
  git -C "$TMP_DIR/project-b" init -q
  cd "$TMP_DIR/project-a"
  local lock_a
  lock_a="$(sf_state_lock_path)"
  cd "$TMP_DIR/project-b"
  local lock_b
  lock_b="$(sf_state_lock_path)"
  if [[ "$lock_a" != "$lock_b" ]]; then
    PASS=$((PASS+1)); echo "  ✓ two projects get different onboarding lock paths"
  else
    FAIL=$((FAIL+1)); echo "  ✗ project lock paths collide: $lock_a"
  fi
}

test_legacy_onboarding_state_migrates_when_project_matches() {
  echo "test_legacy_onboarding_state_migrates_when_project_matches:"
  TMP_DIR="$(mktemp -d -t scaffold-onboard-project-state.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$TMP_DIR/project-a"
  git -C "$TMP_DIR/project-a" init -q
  cd "$TMP_DIR/project-a"
  local root legacy scoped mode
  root="$(sf_project_identity_root)"
  legacy="$(sf_state_legacy_path)"
  jq -n --arg root "$root" '{
    status: "in_progress",
    current_phase: 4,
    project_root: $root,
    answers: {"1.1.1": "legacy-owned"}
  }' > "$legacy"
  scoped="$(sf_state_path)"
  mode="$(sf_state_mode)"
  assert_file_exists "$scoped"
  assert_eq "matching legacy state migrates to resume" "resume" "$mode"
  assert_eq "migrated answer preserved" "legacy-owned" "$(sf_state_read_answer "1.1.1")"
  assert_file_exists "$legacy"
}

test_legacy_onboarding_state_ignored_when_project_mismatches() {
  echo "test_legacy_onboarding_state_ignored_when_project_mismatches:"
  TMP_DIR="$(mktemp -d -t scaffold-onboard-project-state.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA" "$TMP_DIR/project-a"
  git -C "$TMP_DIR/project-a" init -q
  cd "$TMP_DIR/project-a"
  local legacy scoped mode
  legacy="$(sf_state_legacy_path)"
  jq -n '{
    status: "in_progress",
    current_phase: 4,
    project_root: "/not/this/project",
    answers: {"1.1.1": "legacy-foreign"}
  }' > "$legacy"
  scoped="$(sf_project_data_dir)/onboarding-state.json"
  mode="$(sf_state_mode)"
  assert_eq "mismatched legacy state is ignored" "new" "$mode"
  assert_file_missing "$scoped"
  assert_file_exists "$legacy"
}

test_project_scoped_state_paths_differ
test_project_scoped_state_writes_are_isolated
test_project_scoped_lock_paths_differ
test_legacy_onboarding_state_migrates_when_project_matches
test_legacy_onboarding_state_ignored_when_project_mismatches

# Fix 3 — normalize LLM opt-in yes/no → true/false for the gate.
# answer 9.3.1="yes" must pass uses_llm == true; "no" must fail it.
test_uses_llm_gate_yes_passes() {
  echo "test_uses_llm_gate_yes_passes:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "9.3.1" "yes"
  assert_exit_code 0 sf_state_gate_passes "uses_llm == true"
}

test_uses_llm_gate_no_fails() {
  echo "test_uses_llm_gate_no_fails:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "9.3.1" "no"
  assert_exit_code 1 sf_state_gate_passes "uses_llm == true"
}

test_uses_llm_gate_true_literal_passes() {
  echo "test_uses_llm_gate_true_literal_passes:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "9.3.1" "true"
  assert_exit_code 0 sf_state_gate_passes "uses_llm == true"
}

test_uses_llm_gate_yes_passes
test_uses_llm_gate_no_fails
test_uses_llm_gate_true_literal_passes

report_results
