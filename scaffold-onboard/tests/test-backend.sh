#!/usr/bin/env bash
# tests/test-backend.sh — sf_backend_resolve (SS-5.1 synthesizer selector).
# Dispatcher-path (bin/sf) for the set -e-sensitive manifest-read default.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
SF_BIN="$HERE/../bin/sf"

# Local substring assertion (scaffold-onboard _helpers.sh has no assert_contains).
assert_match() {
  local label="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') $label"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') $label"
    echo "    expected substring: $needle"
    echo "    in: $hay"
  fi
}

test_default_when_field_absent() {
  echo "test_default_when_field_absent:"
  setup_tmp_workspace_init
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" backend_resolve)" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "defaults to claude_subagent" "claude_subagent" "$out"
}

test_field_codex() {
  echo "test_field_codex:"
  setup_tmp_workspace_init
  local tmp="$TMP_MANIFEST.new"
  jq '.synthesizer_backend = "codex"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" backend_resolve)" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "reads codex from manifest" "codex" "$out"
}

test_override_beats_manifest() {
  echo "test_override_beats_manifest:"
  setup_tmp_workspace_init
  local tmp="$TMP_MANIFEST.new"
  jq '.synthesizer_backend = "codex"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" backend_resolve --backend claude_subagent)" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "override beats a SET manifest field" "claude_subagent" "$out"
}

test_override_missing_value_rc2() {
  echo "test_override_missing_value_rc2:"
  setup_tmp_workspace_init
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" backend_resolve --backend 2>&1)" && rc=0 || rc=$?
  assert_eq "rc=2 when --backend lacks a value" "2" "$rc"
  assert_match "names the missing --backend value" "missing value for --backend" "$out"
}

test_no_manifest_defaults_no_abort() {
  echo "test_no_manifest_defaults_no_abort:"
  setup_tmp_repo   # no manifest on the walk-up path; manifest-read rc1 must not abort under set -e
  local out rc
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" backend_resolve)" && rc=0 || rc=$?
  assert_eq "rc=0 (manifest-read rc1 does not abort)" "0" "$rc"
  assert_eq "defaults to claude_subagent" "claude_subagent" "$out"
}

test_invalid_backend_rc1() {
  echo "test_invalid_backend_rc1:"
  setup_tmp_repo
  local out rc
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" backend_resolve --backend bogus 2>&1)" && rc=0 || rc=$?
  assert_eq "rc=1 on invalid backend" "1" "$rc"
  assert_match "names the invalid value" "bogus" "$out"
}

test_default_when_field_absent
test_field_codex
test_override_beats_manifest
test_override_missing_value_rc2
test_no_manifest_defaults_no_abort
test_invalid_backend_rc1
report_results
