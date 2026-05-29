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
  sf_state_write_answer "1.1.4" "test-proj"
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

test_claude_md_generated() {
  echo "test_claude_md_generated:"
  setup_tmp_repo
  seed_master_spec
  sf_claude_md_generate
  assert_file_exists "./CLAUDE.md"
  assert_file_contains "./CLAUDE.md" "# Project: test-proj"
  assert_file_contains "./CLAUDE.md" "Tier 0"
  assert_file_contains "./CLAUDE.md" "Branch loading rules"
}

test_claude_md_plugin_awareness_when_no_composition() {
  echo "test_claude_md_plugin_awareness_when_no_composition:"
  setup_tmp_repo
  seed_master_spec
  # No composition.json present
  sf_claude_md_generate
  # ai-mentor / critic / superpowers sections should NOT appear
  if grep -q "/z2-decide" "./CLAUDE.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ ai-mentor section leaked without composition"
  else
    PASS=$((PASS+1)); echo "  ✓ ai-mentor section absent without composition"
  fi
}

# #21 — Karpathy opt-in: phase_10.4.include_karpathy=yes emits the Behavioral
# Discipline section with the verbatim attribution; any other value omits it.
test_claude_md_karpathy_opt_in() {
  echo "test_claude_md_karpathy_opt_in:"
  setup_tmp_repo
  seed_master_spec
  sf_state_write_answer phase_10.4.include_karpathy yes
  sf_claude_md_generate
  assert_file_contains "./CLAUDE.md" "Behavioral Discipline \(Karpathy-inspired\)"
  assert_file_contains "./CLAUDE.md" "Behavioral guidelines inspired by Karpathy's observations \(Chang, 2026; MIT\)"
  assert_file_contains "./CLAUDE.md" "Think Before Coding"
}

test_claude_md_karpathy_opt_out() {
  echo "test_claude_md_karpathy_opt_out:"
  setup_tmp_repo
  seed_master_spec
  # seed_master_spec does not set the karpathy answer → opt-out by default
  sf_claude_md_generate
  if grep -q "Behavioral Discipline (Karpathy-inspired)" "./CLAUDE.md"; then
    FAIL=$((FAIL+1)); echo "  ✗ Karpathy section present without opt-in"
  else
    PASS=$((PASS+1)); echo "  ✓ Karpathy section absent without opt-in"
  fi
}

# T7.4 — R2 contract: 03-code-patterns.md seeds an empty "Machine-checkable
# rules" section so /add-project-rule (authoring-machine-checkable-rules) has
# a known heading to insert mcrule blocks under. SPEC §8.1.
test_derive_seeds_machine_checkable_rules_section() {
  echo "test_derive_seeds_machine_checkable_rules_section:"
  setup_tmp_repo
  seed_master_spec
  sf_memory_bank_derive
  assert_file_contains "./.claude/memory-bank/03-code-patterns.md" "^## Machine-checkable rules"
}

test_derive_00_project_brief
test_live_files_preserved
test_live_files_force_overwritten
test_workflow_static_unchanged
test_all_derived_files_present
test_claude_md_generated
test_claude_md_plugin_awareness_when_no_composition
test_claude_md_karpathy_opt_in
test_claude_md_karpathy_opt_out
test_derive_seeds_machine_checkable_rules_section
report_results
