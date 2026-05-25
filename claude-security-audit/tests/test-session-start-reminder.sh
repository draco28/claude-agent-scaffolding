#!/usr/bin/env bash
set -u
source "$(dirname "$0")/_helpers.sh"

_csa_failed=0

test_hook_silent_when_no_state() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-hook.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  local out; out="$(cd "$tmp" && bash "$CSA_PLUGIN_ROOT/hooks/session-start-reminder.sh" 2>&1)"
  # No output expected; exit 0
  assert_eq "" "$out"
}

test_hook_prints_days_when_state_exists() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-hook2.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  mkdir -p "$tmp/.claude/audits"
  local five_days_ago
  if date -u -d '5 days ago' +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
    five_days_ago="$(date -u -d '5 days ago' +%Y-%m-%dT%H:%M:%SZ)"
  else
    five_days_ago="$(date -u -v-5d +%Y-%m-%dT%H:%M:%SZ)"
  fi
  printf '{"last_audit":{"date":"%s"}}' "$five_days_ago" > "$tmp/.claude/audits/state.json"
  local out; out="$(cd "$tmp" && bash "$CSA_PLUGIN_ROOT/hooks/session-start-reminder.sh")"
  assert_contains "$out" "claude-security-audit: last audit" || return 1
  assert_contains "$out" "days ago" || return 1
}

csa_test_run test_hook_silent_when_no_state          || _csa_failed=$((_csa_failed + 1))
csa_test_run test_hook_prints_days_when_state_exists || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
