#!/usr/bin/env bash
# End-to-end tests for scaffold-onboard.
# Each test runs the full bash pipeline (onboard helpers → scaffold-project →
# scaffold-docs) against a fresh tmp repo with scripted answers.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/parser.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/memory-bank.sh"
source "$HERE/../lib/docs.sh"
source "$HERE/../lib/compose.sh"

PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Scripted answers for a representative CLI project (no LLM, no UI).
script_answers_cli() {
  sf_state_write_answer "1.1.1" "todo-cli — fast local-first task manager"
  sf_state_write_answer "1.1.2" "Existing managers are heavy and cloud-coupled."
  sf_state_write_answer "1.1.3" "Solo devs adopt as their default task tool."
  sf_state_write_answer "1.2.1" "Solo devs and ops engineers."
  sf_state_write_answer "1.2.2" "Add a task, see what's pending, mark done — all under 200ms."
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "1.3.2" "add / list / complete tasks; persist to ~/.todo.json; tab-complete."
  sf_state_write_answer "2.1.1" "4 weeks"
  sf_state_write_answer "2.1.2" "Solo"
  sf_state_write_answer "2.2.1" "0 (no hosted infra)"
  sf_state_write_answer "2.2.2" "tech: dep drift; market: niche; resource: solo bandwidth"
  sf_state_write_answer "2.3.1" "Daily use by 1 user for 4 weeks."
  sf_state_write_answer "3.1.1" "Task, Project (optional)"
  sf_state_write_answer "3.1.2" "Task(id, title, status, due); Project(id, name)"
  sf_state_write_answer "3.2.1" "Project has many Tasks"
  sf_state_write_answer "3.3.1" "task, project, done, due"
  sf_state_write_answer "4.1.1" "none"
  sf_state_write_answer "4.1.2" "none"
  sf_state_write_answer "4.2.1" "none"
  sf_state_write_answer "4.2.2" "single-tenant (local only)"
  sf_state_write_answer "4.3.1" "local only"
  sf_state_write_answer "5.1.1" "CLI"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "5.2.2" "file (~/.todo.json)"
  sf_state_write_answer "5.3.1" "single user, <1MB data"
  sf_state_write_answer "5.3.2" "<200ms per command"
  sf_state_write_answer "6A.1.1" "CLI"
  sf_state_write_answer "6A.1.2" "todo add 'feed cat' → todo list → todo done 1"
  sf_state_write_answer "7.1.1" "src/{cli,store,model}"
  sf_state_write_answer "7.1.2" "statically typed Rust"
  sf_state_write_answer "8.1.1" "cargo"
  sf_state_write_answer "8.2.1" "GitHub Actions"
  sf_state_write_answer "8.2.2" "dev only"
  sf_state_write_answer "8.3.1" "self-hosted (binary release)"
  sf_state_write_answer "9.1.1" "80%"
  sf_state_write_answer "9.1.2" "unit, integration"
  sf_state_write_answer "9.2.1" "tests pass, cargo clippy clean"
  sf_state_write_answer "9.3.1" "no"
  sf_state_write_answer "10.1.1" "direct"
  sf_state_write_answer "10.3.1" "solo / business hours"
}

run_full_pipeline_cli() {
  sf_state_init
  script_answers_cli
  local tmpl="$PLUGIN_ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  sf_master_spec_init "$tmpl" "todo-cli" "CLI tool"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done
  sf_state_write_atomic status complete
  sf_memory_bank_derive
  sf_claude_md_generate
  sf_claude_settings_generate
  sf_docs_derive
}

test_e2e_fresh_repo_cli() {
  echo "test_e2e_fresh_repo_cli:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  run_full_pipeline_cli
  # MASTER-SPEC artifacts
  assert_file_exists "./MASTER-SPEC.md"
  assert_exit_code 0 sf_spec_validate ./MASTER-SPEC.md
  # Memory bank
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 05-active-context 06-progress 07-constraints 08-governance index WORKFLOW; do
    assert_file_exists "./.claude/memory-bank/${f}.md"
  done
  # CLAUDE.md
  assert_file_exists "./CLAUDE.md"
  assert_file_contains "./CLAUDE.md" "todo-cli"
  assert_file_contains "./CLAUDE.md" "Tier 0"
  # Settings
  assert_file_exists "./.claude/settings.json"
  # Default docs
  assert_file_exists "./docs/PRD.md"
  assert_file_exists "./docs/SRS.md"
  assert_file_exists "./docs/BACKLOG.md"
  assert_file_exists "./docs/PROJECT_PLAN.md"
  assert_file_exists "./docs/adr/0001-record-architecture-decisions.md"
  # No --full docs
  assert_file_missing "./docs/RISK_REGISTER.md"
  assert_file_missing "./docs/EVALS_PLAN.md"
}

test_e2e_full_mode() {
  echo "test_e2e_full_mode:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  run_full_pipeline_cli
  sf_docs_derive --full
  assert_file_exists "./docs/RISK_REGISTER.md"
  assert_file_exists "./docs/TEST_STRATEGY.md"
  assert_file_exists "./docs/CUTOVER_PLAN.md"
  # LLM-gated still skipped (this project says no LLMs)
  assert_file_missing "./docs/EVALS_PLAN.md"
}

test_e2e_existing_repo_preserves_user_files() {
  echo "test_e2e_existing_repo_preserves_user_files:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  # Pre-seed user-authored files BEFORE running scaffold-onboard
  mkdir -p docs/adr
  echo "# My existing PRD" > docs/PRD.md
  echo "# Pre-existing ADR" > docs/adr/0001-record-architecture-decisions.md
  echo "# Existing settings note" > .claude_user_note  # canary

  run_full_pipeline_cli

  # docs/PRD.md is in docs-minimal — preserved unless --regenerate
  assert_file_contains "./docs/PRD.md" "My existing PRD"
  # ADR-0001 preserved
  assert_file_contains "./docs/adr/0001-record-architecture-decisions.md" "Pre-existing ADR"
  # User's canary untouched
  assert_file_contains "./.claude_user_note" "Existing settings note"
}

test_e2e_regenerate_overwrites_docs() {
  echo "test_e2e_regenerate_overwrites_docs:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"
  echo "# My existing PRD" > docs/PRD.md 2>/dev/null || { mkdir -p docs; echo "# My existing PRD" > docs/PRD.md; }
  run_full_pipeline_cli
  sf_docs_derive --regenerate
  if grep -q "My existing PRD" docs/PRD.md; then
    FAIL=$((FAIL+1)); echo "  ✗ --regenerate did not overwrite"
  else
    PASS=$((PASS+1)); echo "  ✓ --regenerate overwrote existing PRD"
  fi
}

test_e2e_resume_mid_onboarding() {
  echo "test_e2e_resume_mid_onboarding:"
  setup_tmp_repo
  export SF_COMPOSE_PROBE_PATHS="/nonexistent"

  # Partial onboarding: answer phases 1-3 only, leave 4-10 unanswered
  sf_state_init
  sf_state_write_answer "1.1.1" "partial-proj"
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "2.2.2" "risks here"
  sf_state_write_answer "3.1.1" "Thing"
  sf_state_write_atomic current_phase 4

  # Mode check: should be "resume"
  local mode
  mode="$(sf_state_mode)"
  assert_eq "mode is resume" "resume" "$mode"

  # Current phase persisted
  local phase
  phase="$(sf_state_read_field current_phase)"
  assert_eq "phase 4 persisted" "4" "$phase"

  # Resume by answering remaining phases
  sf_state_write_answer "4.1.1" "none"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "9.3.1" "no"
  sf_state_write_atomic current_phase 10
  sf_state_advance_phase  # → status=complete

  local status
  status="$(sf_state_read_field status)"
  assert_eq "completed after resume" "complete" "$status"
}

test_e2e_with_composition_mocked() {
  echo "test_e2e_with_composition_mocked:"
  setup_tmp_repo
  # Fake-install all three cross-cutting plugins
  mkdir -p "$TMP_DIR/fake-plugins/ai-mentor-x"
  : > "$TMP_DIR/fake-plugins/ai-mentor-x/state.json"
  mkdir -p "$TMP_DIR/fake-plugins/architect-critic-y"
  : > "$TMP_DIR/fake-plugins/architect-critic-y/principles.md"
  mkdir -p "$TMP_DIR/fake-plugins/superpowers-z/skills/brainstorming"
  : > "$TMP_DIR/fake-plugins/superpowers-z/skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"

  sf_compose_refresh
  run_full_pipeline_cli

  # CLAUDE.md should mention all three integrations
  assert_file_contains "./CLAUDE.md" "z2-decide"
  assert_file_contains "./CLAUDE.md" "/critique"
  assert_file_contains "./CLAUDE.md" "superpowers"

  # Mentor hint emits at Phase 5 + 7
  local hint5 hint7 hint2
  hint5="$(sf_compose_mentor_hint 5)"
  hint7="$(sf_compose_mentor_hint 7)"
  hint2="$(sf_compose_mentor_hint 2)"
  if [[ -n "$hint5" ]]; then PASS=$((PASS+1)); echo "  ✓ Phase 5 mentor hint emitted"; else FAIL=$((FAIL+1)); echo "  ✗ no Phase 5 mentor hint"; fi
  if [[ -n "$hint7" ]]; then PASS=$((PASS+1)); echo "  ✓ Phase 7 mentor hint emitted"; else FAIL=$((FAIL+1)); echo "  ✗ no Phase 7 mentor hint"; fi
  assert_eq "no Phase 2 hint" "" "$hint2"
}

test_e2e_onboarding_project_skill_present() {
  echo "test_e2e_onboarding_project_skill_present:"
  local skill_path="$PLUGIN_ROOT/skills/onboarding-project/SKILL.md"

  # 1. SKILL.md exists
  assert_file_exists "$skill_path"
  if [[ ! -f "$skill_path" ]]; then
    return
  fi

  # 2. Valid YAML frontmatter: starts with ---, has name: onboarding-project, has non-empty description
  local first_line
  first_line="$(head -n1 "$skill_path")"
  assert_eq "frontmatter opens with ---" "---" "$first_line"

  if grep -qE '^name:[[:space:]]*onboarding-project[[:space:]]*$' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has name: onboarding-project"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter missing 'name: onboarding-project'"
  fi

  # Description must be non-empty (anything other than blank after the colon)
  if awk '/^---$/{c++; next} c==1 && /^description:[[:space:]]*[^[:space:]]/{found=1} END{exit !found}' "$skill_path"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') frontmatter has non-empty description"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') frontmatter description missing or empty"
  fi

  # 3. Description contains at least 3 of the trigger phrases
  local desc_block
  desc_block="$(awk '/^---$/{c++; next} c==1' "$skill_path")"
  local hits=0
  for phrase in "onboard" "MASTER-SPEC" "10-phase" "start onboarding"; do
    if echo "$desc_block" | grep -qiF "$phrase"; then
      hits=$((hits+1))
    fi
  done
  if [[ "$hits" -ge 3 ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') description contains $hits/4 trigger phrases (≥3)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') description contains only $hits/4 trigger phrases (need ≥3)"
  fi

  # 4. Body references architect-critic:critiquing-spec (not legacy :critique)
  assert_file_contains "$skill_path" "architect-critic:critiquing-spec"

  # 5. Body references sf_resolve_output_path (manifest routing helper)
  assert_file_contains "$skill_path" "sf_resolve_output_path"

  # 6. Body does NOT contain v0.1.3 (drift-resolution sanity)
  if grep -qF "v0.1.3" "$skill_path"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') skill body contains forbidden 'v0.1.3' reference"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') skill body has no 'v0.1.3' references"
  fi
}

test_e2e_fresh_repo_cli
test_e2e_full_mode
test_e2e_existing_repo_preserves_user_files
test_e2e_regenerate_overwrites_docs
test_e2e_resume_mid_onboarding
test_e2e_with_composition_mocked
test_e2e_onboarding_project_skill_present
report_results
