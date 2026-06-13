#!/usr/bin/env bash
# tests/test-manifest.sh — sf_manifest_get field reader (SS-5.1). Dispatcher-path
# (bin/sf) for the set -e-sensitive absent-field read.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
SF_BIN="$HERE/../bin/sf"

test_get_present_field() {
  echo "test_get_present_field:"
  setup_tmp_workspace_init
  local tmp="$TMP_MANIFEST.new"
  jq '.synthesizer_backend = "codex"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" manifest_get '.synthesizer_backend')" && rc=0 || rc=$?
  assert_eq "rc=0 on present field" "0" "$rc"
  assert_eq "echoes the field value" "codex" "$out"
}

test_get_absent_field_rc1() {
  echo "test_get_absent_field_rc1:"
  setup_tmp_workspace_init   # no synthesizer_backend field
  local out rc
  out="$(cd "$TMP_AI_WORKSPACE" && bash "$SF_BIN" manifest_get '.synthesizer_backend' 2>/dev/null)" && rc=0 || rc=$?
  assert_eq "rc=1 on absent field" "1" "$rc"
  assert_eq "no output on absent field" "" "$out"
}

test_get_no_manifest_rc1_no_abort() {
  echo "test_get_no_manifest_rc1_no_abort:"
  setup_tmp_repo   # plain git repo, no .workspace/pairing.json on the walk-up path
  local out rc
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" manifest_get '.synthesizer_backend' 2>/dev/null)" && rc=0 || rc=$?
  assert_eq "rc=1 when no manifest (must not abort under set -e)" "1" "$rc"
}

test_get_present_field
test_get_absent_field_rc1
test_get_no_manifest_rc1_no_abort
report_results
