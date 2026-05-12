#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/parser.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/docs.sh"

PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

seed_master_spec_for_docs() {
  local tmpl="$PLUGIN_ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  sf_state_init
  sf_state_write_answer "1.1.1" "test-proj — fast widget"
  sf_state_write_answer "1.1.2" "Widgets slow."
  sf_state_write_answer "1.2.1" "Solo devs"
  sf_state_write_answer "1.2.2" "Build in one command"
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "1.3.2" "core flows"
  sf_state_write_answer "2.1.1" "4 weeks"
  sf_state_write_answer "2.2.2" "tech: dependency drift; market: niche; resource: solo"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "9.3.1" "no"
  sf_master_spec_init "$tmpl" "test-proj" "CLI tool"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done
}

test_default_docs_generated() {
  echo "test_default_docs_generated:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  assert_file_exists "./docs/PRD.md"
  assert_file_exists "./docs/SRS.md"
  assert_file_exists "./docs/BACKLOG.md"
  assert_file_exists "./docs/PROJECT_PLAN.md"
  assert_file_exists "./docs/adr/0001-record-architecture-decisions.md"
}

test_prd_content() {
  echo "test_prd_content:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  assert_file_contains "./docs/PRD.md" "test-proj — fast widget"
  assert_file_contains "./docs/PRD.md" "CLI tool"
}

test_default_does_not_create_full_docs() {
  echo "test_default_does_not_create_full_docs:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  assert_file_missing "./docs/RISK_REGISTER.md"
  assert_file_missing "./docs/EVALS_PLAN.md"
}

test_full_mode_non_llm() {
  echo "test_full_mode_non_llm:"
  setup_tmp_repo
  seed_master_spec_for_docs  # 9.3.1 = "no"
  sf_docs_derive --full
  # 5 default + 6 non-LLM --full = 11 docs total under docs/
  assert_file_exists "./docs/RISK_REGISTER.md"
  assert_file_exists "./docs/THREAT_MODEL.md"
  assert_file_exists "./docs/TEST_STRATEGY.md"
  assert_file_exists "./docs/DEFINITION_OF_DONE.md"
  assert_file_exists "./docs/CUTOVER_PLAN.md"
  assert_file_exists "./docs/DEMO_RUNBOOK.md"
  # LLM-gated should NOT be generated
  assert_file_missing "./docs/EVALS_PLAN.md"
  assert_file_missing "./docs/MODEL_CARD.md"
  assert_file_missing "./docs/PROMPT_GOVERNANCE.md"
}

test_full_mode_llm_project() {
  echo "test_full_mode_llm_project:"
  setup_tmp_repo
  seed_master_spec_for_docs
  # Flip the LLM gate
  sf_state_write_answer "9.3.1" "yes"
  sf_state_write_answer "9.3.2" "groundedness, factuality, latency, cost"
  local tmpl="$PLUGIN_ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done
  sf_docs_derive --full
  assert_file_exists "./docs/EVALS_PLAN.md"
  assert_file_exists "./docs/MODEL_CARD.md"
  assert_file_exists "./docs/PROMPT_GOVERNANCE.md"
}

test_existing_files_preserved() {
  echo "test_existing_files_preserved:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  # Hand-edit
  echo "## My addition" >> "./docs/PRD.md"
  sf_docs_derive  # should NOT overwrite
  assert_file_contains "./docs/PRD.md" "My addition"
}

test_regenerate_overwrites() {
  echo "test_regenerate_overwrites:"
  setup_tmp_repo
  seed_master_spec_for_docs
  sf_docs_derive
  echo "## My addition" >> "./docs/PRD.md"
  sf_docs_derive --regenerate
  if grep -q "My addition" "./docs/PRD.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ --regenerate did not overwrite"
  else
    PASS=$((PASS+1)); echo "  ✓ --regenerate overwrote existing file"
  fi
}

test_default_docs_generated
test_prd_content
test_default_does_not_create_full_docs
test_full_mode_non_llm
test_full_mode_llm_project
test_existing_files_preserved
test_regenerate_overwrites
report_results
