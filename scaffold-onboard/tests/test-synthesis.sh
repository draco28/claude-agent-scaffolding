#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/synthesis.sh"
PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

test_project_name_prefers_explicit_answer() {
  echo "test_project_name_prefers_explicit_answer:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "Acme — the — multi — dash — pitch"
  sf_state_write_answer "1.1.4" "Acme"
  assert_eq "explicit name wins" "Acme" "$(sf_project_name)"
}

test_project_name_no_emdash_truncation_fallback() {
  echo "test_project_name_no_emdash_truncation_fallback:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "Acme — a — pitch — with — dashes"
  local got; got="$(sf_project_name)"
  assert_eq "fallback is basename, not em-dash prefix" "$(basename "$PWD")" "$got"
}

test_project_name_prefers_explicit_answer
test_project_name_no_emdash_truncation_fallback
report_results
