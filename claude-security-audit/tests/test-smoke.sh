#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"

test_harness_loads() {
  [[ -n "$CSA_PLUGIN_ROOT" ]] || return 1
  [[ -d "$CSA_PLUGIN_ROOT/.claude-plugin" ]] || return 1
  assert_eq "claude-security-audit" "$(jq -r .name "$CSA_PLUGIN_ROOT/.claude-plugin/plugin.json")" || return 1
}

test_assertion_failures_are_loud() {
  # This test should FAIL; running it confirms the harness reports failures.
  # We invert by checking it returns non-zero.
  if assert_eq "a" "b" "intentional failure" 2>/dev/null; then
    return 1   # assert_eq returned 0, harness is broken
  fi
}

csa_test_run test_harness_loads
csa_test_run test_assertion_failures_are_loud
