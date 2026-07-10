#!/usr/bin/env bash
# T4.1 — Marker-aware Tier 0 hook protocol tests (SPEC §11).
#
# Asserts:
#  1. Marker absent → emits full Tier 0 (memory-bank reference) + writes marker
#     with content "scaffold-onboard".
#  2. Marker present with "scaffold-dev" → suppresses full Tier 0 (minimal hint
#     only); marker content unchanged.
#  3. Marker present with "scaffold-onboard" → emits full Tier 0.
#  4. CLAUDE_SESSION_ID unset → marker path uses "default" suffix.
#  5. CLAUDE_SESSION_ID="abc123" → marker path uses "abc123" suffix.
#  6. Marker decision completes within 50ms of hook entry (race-window
#     discipline per SPEC §11.4).
#  7. Custom TMPDIR honored (marker lands inside TMPDIR).
#  8. TMPDIR unset → marker path falls back to /tmp.
#  9. Hook does NOT overwrite an existing "scaffold-onboard" marker (no spurious
#     re-writes — atime/mtime preserved).
# 10. Minimal onboarding hints use the same SessionStart JSON envelope.
#
# Conventions:
#   * Each test uses a fresh CLAUDE_SESSION_ID="test-T4-fixture-$$-<n>" to keep
#     marker files isolated across runs + parallel CI.
#   * The hook is invoked with empty stdin (`< /dev/null`) — source field is
#     empty, which triggers the standard refresh path.
#   * setup_tmp_repo provides an isolated TMP_DIR + CLAUDE_PLUGIN_DATA + repo.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"

HOOK="$HERE/../hooks-handlers/session-start.sh"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"
source "$PLUGIN_ROOT/lib/state.sh"

assert_session_start_context() {
  local label="$1" out="$2" expected_fragment="$3"
  if printf '%s\n' "$out" | jq -e --arg fragment "$expected_fragment" '
    (keys == ["hookSpecificOutput"])
    and (.hookSpecificOutput.hookEventName == "SessionStart")
    and (.hookSpecificOutput.additionalContext | type == "string")
    and (.hookSpecificOutput.additionalContext | contains($fragment))
  ' >/dev/null 2>&1; then
    PASS=$((PASS+1)); echo "  ✓ $label"
  else
    FAIL=$((FAIL+1)); echo "  ✗ $label; got: $out"
  fi
}

# Build a unique session id per test invocation to avoid cross-test leakage.
_session_id() {
  printf "test-T4-%s-%s" "$$" "$1"
}

# Run the hook in a hermetic env. Args: $1 marker_dir (TMPDIR), $2 session_id.
# Echoes the hook's stdout. Exports CLAUDE_PLUGIN_ROOT so the hook resolves
# helpers correctly.
_run_hook() {
  local tmpdir="$1" sid="$2"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  CLAUDE_SESSION_ID="$sid" \
  TMPDIR="$tmpdir" \
    bash "$HOOK" < /dev/null 2>&1
}

# Same as _run_hook but explicitly unsets CLAUDE_SESSION_ID and TMPDIR for the
# fallback-path tests (4 + 8).
_run_hook_unset_session() {
  local tmpdir="$1"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  TMPDIR="$tmpdir" \
    env -u CLAUDE_SESSION_ID bash "$HOOK" < /dev/null 2>&1
}

_run_hook_unset_tmpdir() {
  local sid="$1"
  CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
  CLAUDE_SESSION_ID="$sid" \
    env -u TMPDIR bash "$HOOK" < /dev/null 2>&1
}

# Cleanup helper — wipes any /tmp/claude-code-tier0-test-T4-* files written by
# the unset-TMPDIR test (which can't use TMP_DIR because that's exactly what's
# being tested).
_cleanup_default_tmp_markers() {
  rm -f /tmp/claude-code-tier0-test-T4-*  2>/dev/null || true
}

# ---------- Test 1: Marker absent → full Tier 0 + marker write ----------
test_marker_absent_emits_full_tier0_and_writes_marker() {
  echo "test_marker_absent_emits_full_tier0_and_writes_marker:"
  setup_tmp_repo
  local sid; sid="$(_session_id 1)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  rm -f "$marker"
  local out; out="$(_run_hook "$TMP_DIR" "$sid")"
  # Full Tier 0 includes a memory-bank reference (per task spec).
  if echo "$out" | grep -q "memory-bank"; then
    PASS=$((PASS+1)); echo "  ✓ stdout contains memory-bank Tier 0 reference"
  else
    FAIL=$((FAIL+1)); echo "  ✗ stdout missing memory-bank reference; got: $out"
  fi
  assert_session_start_context "full Tier 0 uses SessionStart envelope" "$out" "memory-bank"
  assert_file_exists "$marker"
  if [[ -f "$marker" ]]; then
    local content; content="$(cat "$marker")"
    assert_eq "marker content is 'scaffold-onboard'" "scaffold-onboard" "$content"
  fi
}

# ---------- Test 2: Marker says scaffold-dev → minimal hint, no full Tier 0 ----------
test_marker_scaffold_dev_suppresses_full_tier0() {
  echo "test_marker_scaffold_dev_suppresses_full_tier0:"
  setup_tmp_repo
  local sid; sid="$(_session_id 2)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  printf "scaffold-dev" > "$marker"
  local out; out="$(_run_hook "$TMP_DIR" "$sid")"
  if echo "$out" | grep -q "memory-bank"; then
    FAIL=$((FAIL+1)); echo "  ✗ stdout unexpectedly contains memory-bank: $out"
  else
    PASS=$((PASS+1)); echo "  ✓ no full Tier 0 emitted (scaffold-dev owns it)"
  fi
  # Marker MUST remain "scaffold-dev" — we don't overwrite another plugin's claim.
  local content; content="$(cat "$marker")"
  assert_eq "marker content unchanged" "scaffold-dev" "$content"
}

# ---------- Test 3: Marker says scaffold-onboard → full Tier 0 emitted ----------
test_marker_scaffold_onboard_emits_full_tier0() {
  echo "test_marker_scaffold_onboard_emits_full_tier0:"
  setup_tmp_repo
  local sid; sid="$(_session_id 3)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  printf "scaffold-onboard" > "$marker"
  local out; out="$(_run_hook "$TMP_DIR" "$sid")"
  if echo "$out" | grep -q "memory-bank"; then
    PASS=$((PASS+1)); echo "  ✓ stdout contains memory-bank (this plugin owns Tier 0)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ stdout missing memory-bank: $out"
  fi
}

# ---------- Test 4: CLAUDE_SESSION_ID unset → "default" suffix ----------
test_session_id_unset_uses_default_suffix() {
  echo "test_session_id_unset_uses_default_suffix:"
  setup_tmp_repo
  local marker="$TMP_DIR/claude-code-tier0-default"
  rm -f "$marker"
  _run_hook_unset_session "$TMP_DIR" > /dev/null
  assert_file_exists "$marker"
}

# ---------- Test 5: Explicit CLAUDE_SESSION_ID honored in marker path ----------
test_session_id_set_uses_provided_suffix() {
  echo "test_session_id_set_uses_provided_suffix:"
  setup_tmp_repo
  local sid; sid="$(_session_id 5)"  # contains process pid for uniqueness
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  rm -f "$marker"
  _run_hook "$TMP_DIR" "$sid" > /dev/null
  assert_file_exists "$marker"
}

# ---------- Test 6: Marker decision within 50ms of hook entry ----------
# Race-window discipline per SPEC §11.4. The hook itself emits a sentinel at
# the precise moment marker decision is complete, so we measure entry→sentinel
# directly without trying to time the full hook (which also does composition
# refresh + onboarding-hint emission downstream).
test_marker_decision_within_50ms() {
  echo "test_marker_decision_within_50ms:"
  setup_tmp_repo
  local sid; sid="$(_session_id 6)"
  local out
  # SF_TIER0_TIMING_DEBUG=1 instructs the hook to emit
  # "TIER0_TIMING_NS=<elapsed_ns>" on stderr right after marker decision.
  out="$(CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" \
        CLAUDE_SESSION_ID="$sid" \
        TMPDIR="$TMP_DIR" \
        SF_TIER0_TIMING_DEBUG=1 \
        bash "$HOOK" < /dev/null 2>&1)"
  local elapsed_ns
  elapsed_ns="$(echo "$out" | grep -oE 'TIER0_TIMING_NS=[0-9]+' | head -1 | cut -d= -f2)"
  if [[ -z "$elapsed_ns" ]]; then
    FAIL=$((FAIL+1)); echo "  ✗ no TIER0_TIMING_NS emitted; got: $out"
    return
  fi
  # 50ms = 50_000_000 ns. Allow up to that.
  local budget_ns=50000000
  if [[ "$elapsed_ns" -le "$budget_ns" ]]; then
    PASS=$((PASS+1)); echo "  ✓ marker decision in ${elapsed_ns}ns (budget ${budget_ns}ns / 50ms)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ marker decision too slow: ${elapsed_ns}ns > ${budget_ns}ns (50ms)"
  fi
}

# ---------- Test 7: Custom TMPDIR honored ----------
test_custom_tmpdir_honored() {
  echo "test_custom_tmpdir_honored:"
  setup_tmp_repo
  local custom_tmpdir="$TMP_DIR/custom-tmp"
  mkdir -p "$custom_tmpdir"
  local sid; sid="$(_session_id 7)"
  local marker="$custom_tmpdir/claude-code-tier0-$sid"
  rm -f "$marker"
  _run_hook "$custom_tmpdir" "$sid" > /dev/null
  assert_file_exists "$marker"
}

# ---------- Test 8: TMPDIR unset → falls back to /tmp ----------
test_tmpdir_unset_falls_back_to_slash_tmp() {
  echo "test_tmpdir_unset_falls_back_to_slash_tmp:"
  setup_tmp_repo
  local sid; sid="$(_session_id 8)"
  local marker="/tmp/claude-code-tier0-$sid"
  rm -f "$marker"
  _run_hook_unset_tmpdir "$sid" > /dev/null
  assert_file_exists "$marker"
  rm -f "$marker"  # leave /tmp clean
  _cleanup_default_tmp_markers
}

# ---------- Test 9: No spurious overwrite of existing scaffold-onboard marker ----------
test_no_spurious_overwrite_when_owned() {
  echo "test_no_spurious_overwrite_when_owned:"
  setup_tmp_repo
  local sid; sid="$(_session_id 9)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  printf "scaffold-onboard" > "$marker"
  # Record mtime (use stat — macOS form first, GNU fallback).
  local mtime_before
  mtime_before="$(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null)"
  # Sleep ≥1s to make any spurious write produce a measurable mtime change.
  sleep 1
  _run_hook "$TMP_DIR" "$sid" > /dev/null
  local mtime_after
  mtime_after="$(stat -c %Y "$marker" 2>/dev/null || stat -f %m "$marker" 2>/dev/null)"
  assert_eq "marker mtime unchanged (no spurious write)" "$mtime_before" "$mtime_after"
}

# ---------- Test 10: Minimal hint uses the same SessionStart envelope ----------
test_minimal_hint_uses_session_start_envelope() {
  echo "test_minimal_hint_uses_session_start_envelope:"
  setup_tmp_repo
  sf_state_init
  local sid; sid="$(_session_id 10)"
  local marker="$TMP_DIR/claude-code-tier0-$sid"
  printf "scaffold-dev" > "$marker"
  local out; out="$(_run_hook "$TMP_DIR" "$sid")"
  assert_session_start_context \
    "minimal onboarding hint uses SessionStart envelope" \
    "$out" \
    "onboarding in progress"
  if echo "$out" | grep -q "memory-bank"; then
    FAIL=$((FAIL+1)); echo "  ✗ minimal hint unexpectedly contains full Tier 0: $out"
  else
    PASS=$((PASS+1)); echo "  ✓ minimal hint excludes full Tier 0"
  fi
}

test_marker_absent_emits_full_tier0_and_writes_marker
test_marker_scaffold_dev_suppresses_full_tier0
test_marker_scaffold_onboard_emits_full_tier0
test_session_id_unset_uses_default_suffix
test_session_id_set_uses_provided_suffix
test_marker_decision_within_50ms
test_custom_tmpdir_honored
test_tmpdir_unset_falls_back_to_slash_tmp
test_no_spurious_overwrite_when_owned
test_minimal_hint_uses_session_start_envelope

report_results
