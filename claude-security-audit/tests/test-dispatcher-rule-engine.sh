#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"

_csa_failed=0
_tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-dispatch.XXXXXX")"
trap 'rm -rf "$_tmp"' EXIT

# assert_dispatcher_jsonl_contains <output> <rule-id>
# The dispatcher emits JSONL: every nonempty line must be one JSON object.
assert_dispatcher_jsonl_contains() {
  local out="$1" expected="$2" line rule_id found=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    if ! jq -e 'type == "object"' <<< "$line" >/dev/null; then
      printf '    invalid dispatcher JSONL: %s\n' "$line" >&2
      return 1
    fi
    rule_id="$(jq -r '.rule_id // empty' <<< "$line")"
    [[ "$rule_id" == "$expected" ]] && found=1
  done <<< "$out"
  [[ "$found" -eq 1 ]] || {
    printf '    dispatcher emitted no %s finding: %s\n' "$expected" "$out" >&2
    return 1
  }
}

test_dispatcher_scans_clean_project_without_harness_environment() {
  local project="$_tmp/clean-project"
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

test_dispatcher_finds_secret_control_without_harness_environment() {
  local project="$_tmp/secret-project"
  mkdir -p "$project"
  printf 'ANTHROPIC_API_KEY=sk-ant-api03-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' \
    > "$project/CLAUDE.md"

  local out ec=0
  out="$(env -u CSA_PLUGIN_ROOT -u CSA_LIB_DIR -u CSA_RULES_DIR -u CSA_FIXTURES_DIR \
    -u PLUGIN_ROOT HOME=/nonexistent \
    "$CSA_PLUGIN_ROOT/bin/csa" rule_engine_scan_all "$project" all 2>&1)" || ec=$?

  assert_eq "0" "$ec" "dispatcher control scan exit code" || return 1
  assert_dispatcher_jsonl_contains "$out" "SECRETS-001"
}

test_dispatcher_jsonl_rejects_non_jsonl_output() {
  if assert_dispatcher_jsonl_contains "" "SECRETS-001" >/dev/null 2>&1; then
    printf '    empty dispatcher output was accepted\n' >&2
    return 1
  fi
  if assert_dispatcher_jsonl_contains "not-json SECRETS-001" "SECRETS-001" >/dev/null 2>&1; then
    printf '    malformed dispatcher output was accepted\n' >&2
    return 1
  fi
  local pretty=$'{\n  "rule_id": "SECRETS-001"\n}'
  if assert_dispatcher_jsonl_contains "$pretty" "SECRETS-001" >/dev/null 2>&1; then
    printf '    pretty-printed dispatcher object was accepted as JSONL\n' >&2
    return 1
  fi
}

test_dispatcher_suite_cleans_scratch() {
  local parent; parent="$(mktemp -d "${TMPDIR:-/tmp}/csa-dispatch-probe.XXXXXX")"
  local child_log="$parent/child.log"
  if ! TMPDIR="$parent" CSA_DISPATCHER_LEAK_PROBE=1 bash "$0" > "$child_log" 2>&1; then
    printf '    child dispatcher suite failed: %s\n' "$(<"$child_log")" >&2
    rm -rf "$parent"
    return 1
  fi

  local leftovers
  leftovers="$(find "$parent" -maxdepth 1 -type d -name 'csa-dispatch.*' -print)"
  if [[ -n "$leftovers" ]]; then
    printf '    dispatcher scratch leaked: %s\n' "$leftovers" >&2
    rm -rf "$parent"
    return 1
  fi
  rm -rf "$parent"
}

csa_test_run test_dispatcher_scans_clean_project_without_harness_environment || _csa_failed=$((_csa_failed + 1))
csa_test_run test_dispatcher_finds_secret_control_without_harness_environment || _csa_failed=$((_csa_failed + 1))
csa_test_run test_dispatcher_jsonl_rejects_non_jsonl_output || _csa_failed=$((_csa_failed + 1))
if [[ "${CSA_DISPATCHER_LEAK_PROBE:-}" != "1" ]]; then
  csa_test_run test_dispatcher_suite_cleans_scratch || _csa_failed=$((_csa_failed + 1))
fi

[[ "$_csa_failed" -eq 0 ]] || exit 1
