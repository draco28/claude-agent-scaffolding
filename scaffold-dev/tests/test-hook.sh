#!/usr/bin/env bash
# tests/test-hook.sh — T4.1 SessionStart hook + Tier 0 marker coordination.
#
# Six tests per PLAN Phase 4 + SPEC §15.1:
#   1. Manifest absent → stderr warning + exit 0 (no Tier 0, no marker).
#   2. Manifest present + marker absent → emits full Tier 0 + cursor + writes
#      marker with content "scaffold-dev".
#   3. Marker present with "scaffold-onboard" → emits cursor hint only (no full
#      Tier 0); marker content unchanged.
#   4. Marker present with "scaffold-dev" → re-emits full Tier 0 + cursor;
#      marker content stays "scaffold-dev".
#   5. Marker absent → after hook runs, marker file contains exactly
#      "scaffold-dev".
#   6. Exits 0 cleanly in all four scenarios (manifest-absent + 3 marker
#      states).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"

HOOK="$HERE/../hooks-handlers/session-start.sh"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"

_session_id() { printf "test-T4-1-sd-%s-%s" "$$" "$1"; }

# Run hook with manifest present (cwd inside AI workspace).
_run_hook_in_workspace() {
  local tmpdir="$1" sid="$2" cwd="$3"
  ( cd "$cwd"
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    CLAUDE_SESSION_ID="$sid" \
    TMPDIR="$tmpdir" \
      bash "$HOOK" < /dev/null
  )
}

# Run hook without a manifest (cwd in plain tmp dir).
_run_hook_no_manifest() {
  local tmpdir="$1" sid="$2" cwd="$3"
  ( cd "$cwd"
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    CLAUDE_SESSION_ID="$sid" \
    TMPDIR="$tmpdir" \
      bash "$HOOK" < /dev/null
  )
}

# Capture stdout + stderr + exit code from a hook invocation.
# Sets globals: HOOK_STDOUT, HOOK_STDERR, HOOK_RC.
_capture_hook_in_workspace() {
  local tmpdir="$1" sid="$2" cwd="$3"
  local stdout_file stderr_file
  stdout_file="$(mktemp)"
  stderr_file="$(mktemp)"
  set +e
  ( cd "$cwd"
    CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
    CLAUDE_SESSION_ID="$sid" \
    TMPDIR="$tmpdir" \
      bash "$HOOK" < /dev/null
  ) >"$stdout_file" 2>"$stderr_file"
  HOOK_RC=$?
  set -e 2>/dev/null || true
  HOOK_STDOUT="$(cat "$stdout_file")"
  HOOK_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

# ---------- Test 1: Manifest absent → warning + exit 0 ----------
test_manifest_absent_warns_exit_0() {
  echo "test_manifest_absent_warns_exit_0:"
  setup_tmp_repo   # tmp git repo, NO .workspace/pairing.json
  local sid; sid="$(_session_id 1)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  rm -f "$marker"
  _capture_hook_in_workspace "$TMP_DIR" "$sid" "$TMP_DIR/repo"
  assert_eq "exit code 0"     "0" "$HOOK_RC"
  if echo "$HOOK_STDERR" | grep -q "not in an AI workspace"; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') stderr contains manifest-absent warning"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') stderr missing warning; got: $HOOK_STDERR"
  fi
  assert_file_missing "$marker"
}

# ---------- Test 2: manifest present + marker absent → full Tier 0 + cursor + marker write ----------
test_manifest_present_marker_absent_emits_full() {
  echo "test_manifest_present_marker_absent_emits_full:"
  setup_tmp_workspace
  local sid; sid="$(_session_id 2)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  rm -f "$marker"
  _capture_hook_in_workspace "$TMP_DIR" "$sid" "$TMP_AI_WORKSPACE"
  assert_eq "exit code 0" "0" "$HOOK_RC"
  # Either memory-bank content (if 00-overview.md present) OR the fallback notice.
  if echo "$HOOK_STDOUT" | grep -qE "(memory-bank|00-overview)"; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') stdout contains full Tier 0 reference"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') stdout missing Tier 0; got: $HOOK_STDOUT"
  fi
  if echo "$HOOK_STDOUT" | grep -q "active sprint="; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') stdout contains cursor hint"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') stdout missing cursor hint; got: $HOOK_STDOUT"
  fi
  assert_file_exists "$marker"
}

# ---------- Test 3: Marker present with "scaffold-onboard" → cursor only ----------
test_marker_scaffold_onboard_cursor_only() {
  echo "test_marker_scaffold_onboard_cursor_only:"
  setup_tmp_workspace
  local sid; sid="$(_session_id 3)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  printf "scaffold-onboard" > "$marker"
  _capture_hook_in_workspace "$TMP_DIR" "$sid" "$TMP_AI_WORKSPACE"
  assert_eq "exit code 0" "0" "$HOOK_RC"
  # Should NOT contain full Tier 0 markers (memory-bank head content).
  if echo "$HOOK_STDOUT" | grep -qE "(memory-bank|00-overview)"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') stdout unexpectedly contains full Tier 0; got: $HOOK_STDOUT"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') no full Tier 0 emitted (scaffold-onboard owns it)"
  fi
  if echo "$HOOK_STDOUT" | grep -q "active sprint="; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') cursor hint emitted"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') cursor hint missing; got: $HOOK_STDOUT"
  fi
  # Marker MUST remain "scaffold-onboard".
  local content; content="$(cat "$marker")"
  assert_eq "marker content unchanged" "scaffold-onboard" "$content"
}

# ---------- Test 4: Marker present with "scaffold-dev" → re-emits full ----------
test_marker_scaffold_dev_reemits_full() {
  echo "test_marker_scaffold_dev_reemits_full:"
  setup_tmp_workspace
  local sid; sid="$(_session_id 4)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  printf "scaffold-dev" > "$marker"
  _capture_hook_in_workspace "$TMP_DIR" "$sid" "$TMP_AI_WORKSPACE"
  assert_eq "exit code 0" "0" "$HOOK_RC"
  if echo "$HOOK_STDOUT" | grep -qE "(memory-bank|00-overview)"; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') full Tier 0 re-emitted (we own marker)"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') full Tier 0 missing; got: $HOOK_STDOUT"
  fi
  if echo "$HOOK_STDOUT" | grep -q "active sprint="; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') cursor hint emitted"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') cursor hint missing"
  fi
  local content; content="$(cat "$marker")"
  assert_eq "marker still scaffold-dev" "scaffold-dev" "$content"
}

# ---------- Test 5: Marker absent → marker content after hook is "scaffold-dev" ----------
test_marker_absent_writes_scaffold_dev_content() {
  echo "test_marker_absent_writes_scaffold_dev_content:"
  setup_tmp_workspace
  local sid; sid="$(_session_id 5)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  rm -f "$marker"
  _capture_hook_in_workspace "$TMP_DIR" "$sid" "$TMP_AI_WORKSPACE"
  assert_eq "exit code 0" "0" "$HOOK_RC"
  assert_file_exists "$marker"
  local content; content="$(cat "$marker")"
  assert_eq "marker content is 'scaffold-dev'" "scaffold-dev" "$content"
}

# ---------- Test 6: Exits 0 cleanly in all scenarios ----------
test_exits_0_in_all_scenarios() {
  echo "test_exits_0_in_all_scenarios:"
  # Scenario A: no manifest.
  setup_tmp_repo
  local sid_a; sid_a="$(_session_id 6a)"
  _capture_hook_in_workspace "$TMP_DIR" "$sid_a" "$TMP_DIR/repo"
  assert_eq "no-manifest exit 0" "0" "$HOOK_RC"

  # Scenario B: marker absent, manifest present.
  setup_tmp_workspace
  local sid_b; sid_b="$(_session_id 6b)"
  rm -f "$TMP_DIR/claude-code-tier0-$sid_b"
  _capture_hook_in_workspace "$TMP_DIR" "$sid_b" "$TMP_AI_WORKSPACE"
  assert_eq "marker-absent exit 0" "0" "$HOOK_RC"

  # Scenario C: marker present with scaffold-onboard.
  setup_tmp_workspace
  local sid_c; sid_c="$(_session_id 6c)"
  printf "scaffold-onboard" > "$TMP_DIR/claude-code-tier0-$sid_c"
  _capture_hook_in_workspace "$TMP_DIR" "$sid_c" "$TMP_AI_WORKSPACE"
  assert_eq "marker-onboard exit 0" "0" "$HOOK_RC"

  # Scenario D: marker present with scaffold-dev.
  setup_tmp_workspace
  local sid_d; sid_d="$(_session_id 6d)"
  printf "scaffold-dev" > "$TMP_DIR/claude-code-tier0-$sid_d"
  _capture_hook_in_workspace "$TMP_DIR" "$sid_d" "$TMP_AI_WORKSPACE"
  assert_eq "marker-dev exit 0" "0" "$HOOK_RC"
}

test_manifest_absent_warns_exit_0
test_manifest_present_marker_absent_emits_full
test_marker_scaffold_onboard_cursor_only
test_marker_scaffold_dev_reemits_full
test_marker_absent_writes_scaffold_dev_content
test_exits_0_in_all_scenarios

sd_test_summary
