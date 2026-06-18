#!/usr/bin/env bash
# tests/test-review-gate.sh — tests for lib/review_gate.sh (#39 Phase B
# review-gate selector) + the §7 gate seams in the slice-close / spec-gate
# skills. Dispatcher-path (bin/sd) for the set -e-sensitive manifest-read
# default, mirroring tests/test-backend.sh.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
SD_BIN="$HERE/../bin/sd"

# --- B-W1: sd_review_gate_resolve --------------------------------------------

test_resolve_default_when_field_absent() {
  echo "test_resolve_default_when_field_absent:"
  setup_tmp_workspace
  # Manifest exists (no review_gate field) → default off.
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "defaults to off" "off" "$OUT"
}

test_resolve_field_both() {
  echo "test_resolve_field_both:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.review_gate = "both"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "reads both from manifest" "both" "$OUT"
}

test_resolve_field_slice_close() {
  echo "test_resolve_field_slice_close:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.review_gate = "slice_close"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "reads slice_close" "slice_close" "$OUT"
}

test_resolve_field_spec_close() {
  echo "test_resolve_field_spec_close:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.review_gate = "spec_close"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "reads spec_close" "spec_close" "$OUT"
}

test_override_beats_manifest() {
  echo "test_override_beats_manifest:"
  setup_tmp_workspace
  # Manifest absent (default off); override forces slice_close.
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve --gate slice_close)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "override wins" "slice_close" "$OUT"
}

# Override must beat a SET manifest field (a different value), not just an absent one.
test_override_beats_set_manifest() {
  echo "test_override_beats_set_manifest:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.review_gate = "both"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  # Manifest SET to both; override to a DIFFERENT value must win.
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve --gate off)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "override beats a SET manifest field" "off" "$OUT"
}

test_override_missing_value() {
  echo "test_override_missing_value:"
  setup_tmp_workspace
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve --gate 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=2 when --gate lacks a value" "2" "$RC"
  assert_contains "reports missing --gate value" "missing value for --gate" "$OUT"
}

test_resolve_no_manifest_defaults() {
  echo "test_resolve_no_manifest_defaults:"
  setup_tmp_repo
  # Plain git repo, no .workspace/pairing.json on the walk-up path. The
  # manifest-read returns rc=1 and must NOT abort under the dispatcher set -e.
  OUT="$(cd "$TMP_DIR/repo" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0 (manifest-read rc1 does not abort)" "0" "$RC"
  assert_eq "defaults to off" "off" "$OUT"
}

test_resolve_invalid_gate() {
  echo "test_resolve_invalid_gate:"
  setup_tmp_repo
  OUT="$(cd "$TMP_DIR/repo" && bash "$SD_BIN" review_gate_resolve --gate bogus 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 on invalid gate" "1" "$RC"
  assert_contains "names the invalid value" "bogus" "$OUT"
}

test_resolve_default_when_field_absent
test_resolve_field_both
test_resolve_field_slice_close
test_resolve_field_spec_close
test_override_beats_manifest
test_override_beats_set_manifest
test_override_missing_value
test_resolve_no_manifest_defaults
test_resolve_invalid_gate

sd_test_summary
