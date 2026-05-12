#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/parser.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/memory-bank.sh"

PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

# Build a minimal valid MASTER-SPEC.md in $PWD using the templates + state.
seed_master_spec() {
  local tmpl="$PLUGIN_ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  sf_state_init
  sf_state_write_answer "1.1.1" "test-proj — a fast widget"
  sf_state_write_answer "1.1.2" "Widgets are slow today."
  sf_state_write_answer "1.2.1" "Solo devs"
  sf_state_write_answer "1.2.2" "Build a widget in 1 command"
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "1.3.2" "create / list / destroy widgets"
  sf_state_write_answer "5.2.1" "Rust"
  sf_state_write_answer "5.2.2" "file (~/.widgets.json)"
  sf_state_write_answer "7.1.2" "statically typed Rust"
  sf_state_write_answer "9.3.1" "no"
  sf_master_spec_init "$tmpl" "test-proj" "CLI tool"
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    sf_master_spec_update_phase "$tmpl" "$i"
  done
}

test_derive_00_project_brief() {
  echo "test_derive_00_project_brief:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  assert_file_exists "./.claude/memory-bank/00-project-brief.md"
  assert_file_contains "./.claude/memory-bank/00-project-brief.md" "test-proj — a fast widget"
  assert_file_contains "./.claude/memory-bank/00-project-brief.md" "Last derived from MASTER-SPEC.md"
}

test_live_files_preserved() {
  echo "test_live_files_preserved:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  # Hand-edit the live file
  echo "## My custom note" >> ".claude/memory-bank/05-active-context.md"
  sf_memory_bank_derive
  assert_file_contains "./.claude/memory-bank/05-active-context.md" "My custom note"
}

test_live_files_force_overwritten() {
  echo "test_live_files_force_overwritten:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  echo "## My custom note" >> ".claude/memory-bank/05-active-context.md"
  sf_memory_bank_derive --force
  if grep -q "My custom note" "./.claude/memory-bank/05-active-context.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ --force should have overwritten"
  else
    PASS=$((PASS+1)); echo "  ✓ --force overwrote live file"
  fi
}

test_workflow_static_unchanged() {
  echo "test_workflow_static_unchanged:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  echo "## My workflow note" >> ".claude/memory-bank/WORKFLOW.md"
  sf_memory_bank_derive
  assert_file_contains "./.claude/memory-bank/WORKFLOW.md" "My workflow note"
}

test_all_derived_files_present() {
  echo "test_all_derived_files_present:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 05-active-context 06-progress 07-constraints 08-governance index WORKFLOW; do
    assert_file_exists "./.claude/memory-bank/${f}.md"
  done
}

test_derive_00_project_brief
test_live_files_preserved
test_live_files_force_overwritten
test_workflow_static_unchanged
test_all_derived_files_present
report_results
