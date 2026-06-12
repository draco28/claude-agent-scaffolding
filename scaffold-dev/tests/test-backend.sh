#!/usr/bin/env bash
# tests/test-backend.sh — tests for lib/backend.sh (SS-5 backend selector).
# Dispatcher-path (bin/sd) for the set -e-sensitive manifest-read default.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
SD_BIN="$HERE/../bin/sd"

test_resolve_default_when_field_absent() {
  echo "test_resolve_default_when_field_absent:"
  setup_tmp_workspace
  # Manifest exists (no implementer_backend field) → default.
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" backend_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "defaults to claude_subagent" "claude_subagent" "$OUT"
}

test_resolve_field_codex() {
  echo "test_resolve_field_codex:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.implementer_backend = "codex"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" backend_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "reads codex from manifest" "codex" "$OUT"
}

test_override_beats_manifest() {
  echo "test_override_beats_manifest:"
  setup_tmp_workspace
  # Manifest says claude_subagent (default/absent); override forces codex.
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" backend_resolve --backend codex)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "override wins" "codex" "$OUT"
}

test_resolve_no_manifest_defaults() {
  echo "test_resolve_no_manifest_defaults:"
  setup_tmp_repo
  # Plain git repo, no .workspace/pairing.json on the walk-up path. The
  # manifest-read returns rc=1 and must NOT abort under the dispatcher set -e.
  OUT="$(cd "$TMP_DIR/repo" && bash "$SD_BIN" backend_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0 (manifest-read rc1 does not abort)" "0" "$RC"
  assert_eq "defaults to claude_subagent" "claude_subagent" "$OUT"
}

test_resolve_invalid_backend() {
  echo "test_resolve_invalid_backend:"
  setup_tmp_repo
  OUT="$(cd "$TMP_DIR/repo" && bash "$SD_BIN" backend_resolve --backend bogus 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 on invalid backend" "1" "$RC"
  assert_contains "names the invalid value" "bogus" "$OUT"
}

# #7: override must beat a SET manifest field (a different value), not just an absent one.
test_override_beats_set_manifest() {
  echo "test_override_beats_set_manifest:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.implementer_backend = "codex"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  # Manifest SET to codex; override to a DIFFERENT value must win.
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" backend_resolve --backend claude_subagent)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "override beats a SET manifest field" "claude_subagent" "$OUT"
}

test_resolve_default_when_field_absent
test_resolve_field_codex
test_override_beats_manifest
test_override_beats_set_manifest
test_resolve_no_manifest_defaults
test_resolve_invalid_backend

sd_test_summary
