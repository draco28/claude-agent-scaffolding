#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"

_csa_failed=0

test_dispatcher_scans_clean_project_without_harness_environment() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-dispatch.XXXXXX")"
  trap "rm -rf '$tmp'" EXIT
  local project="$tmp/project"
  mkdir -p "$project/.claude"
  printf '{"permissions":{"allow":["Bash(git:*)"],"deny":["Bash(rm:*)"]}}\n' > "$project/.claude/settings.json"
  printf '# Project instructions\n\nUse normal development practices.\n' > "$project/CLAUDE.md"

  local out ec=0
  out="$(env -u CSA_PLUGIN_ROOT -u CSA_LIB_DIR -u CSA_RULES_DIR -u CSA_FIXTURES_DIR \
    -u PLUGIN_ROOT HOME=/nonexistent \
    "$CSA_PLUGIN_ROOT/bin/csa" rule_engine_scan_all "$project" all 2>&1)" || ec=$?

  assert_eq "0" "$ec" "dispatcher scan exit code" || return 1
  [[ "$out" != *"SCANNER-001"* ]] || {
    printf '    clean dispatcher scan emitted SCANNER-001: %s\n' "$out" >&2
    return 1
  }
  [[ "$out" != *"SCANNER-002"* ]] || {
    printf '    clean dispatcher scan emitted SCANNER-002: %s\n' "$out" >&2
    return 1
  }
  assert_eq "" "$out" "clean dispatcher scan output"
}

csa_test_run test_dispatcher_scans_clean_project_without_harness_environment || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
