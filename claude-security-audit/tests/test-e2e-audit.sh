#!/usr/bin/env bash
# tests/test-e2e-audit.sh — Core e2e: release-gate (zero findings on clean fixtures)
# + issue fixture detection coverage.
# Phase 7 Task 7.1.

set -u
source "$(dirname "$0")/_helpers.sh"

_csa_failed=0

# ---------------------------------------------------------------------------
# Clean fixture: zero findings
# ---------------------------------------------------------------------------

test_e2e_clean_minimal_zero_findings() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/clean/minimal-project/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  [[ -z "$out" ]] || { printf '    unexpected findings: %s\n' "$out" >&2; return 1; }
}

test_e2e_clean_empty_zero_findings() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/clean/empty-project/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  [[ -z "$out" ]] || { printf '    unexpected findings: %s\n' "$out" >&2; return 1; }
}

test_e2e_clean_standard_zero_findings() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/clean/standard-project/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  [[ -z "$out" ]] || { printf '    unexpected findings: %s\n' "$out" >&2; return 1; }
}

test_e2e_clean_plugin_using_zero_findings() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/clean/plugin-using-project/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  [[ -z "$out" ]] || { printf '    unexpected findings: %s\n' "$out" >&2; return 1; }
}

test_e2e_clean_teamworkflow_zero_findings() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/clean/teamworkflow-project/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  [[ -z "$out" ]] || { printf '    unexpected findings: %s\n' "$out" >&2; return 1; }
}

# ---------------------------------------------------------------------------
# Issue fixture: detection coverage
# ---------------------------------------------------------------------------

test_e2e_issue_secrets_detected() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/issues/secrets-issue/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  assert_contains "$out" "SECRETS-001" "secrets-issue should detect SECRETS-001"
}

test_e2e_issue_permissions_detected() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/issues/permissions-issue/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  # permissions-issue has broad Bash(*) allow — should trigger PERM-001
  local found=0
  printf '%s\n' "$out" | grep -q '"PERM-' && found=1
  [[ "$found" -eq 1 ]] || { printf '    no PERM-* finding in: %s\n' "$out" >&2; return 1; }
}

test_e2e_issue_perm005_typo_detected() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/issues/permissions-schema-typo/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  assert_contains "$out" "PERM-005" "permissions-schema-typo should detect PERM-005"
}

test_e2e_issue_hook_injection_detected() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/issues/hook-injection/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  assert_contains "$out" "HOOK-001" "hook-injection should detect HOOK-001"
}

test_e2e_issue_marketplace_untrusted_detected() {
  local tmp; tmp="$(mktemp -d "${TMPDIR:-/tmp}/csa-e2e.XXXXXX")"
  trap "rm -rf '$tmp'" RETURN
  cp -R "$CSA_FIXTURES_DIR/issues/marketplace-untrusted/." "$tmp/"
  local out; out="$(HOME=/nonexistent csa_audit_harness "$tmp" 2>/dev/null)"
  assert_contains "$out" "MARKETPLACE-001" "marketplace-untrusted should detect MARKETPLACE-001"
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

csa_test_run test_e2e_clean_minimal_zero_findings       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_clean_empty_zero_findings         || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_clean_standard_zero_findings      || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_clean_plugin_using_zero_findings  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_clean_teamworkflow_zero_findings  || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_issue_secrets_detected            || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_issue_permissions_detected        || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_issue_perm005_typo_detected       || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_issue_hook_injection_detected     || _csa_failed=$((_csa_failed + 1))
csa_test_run test_e2e_issue_marketplace_untrusted_detected || _csa_failed=$((_csa_failed + 1))

[[ "$_csa_failed" -eq 0 ]] || exit 1
