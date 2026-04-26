#!/usr/bin/env bash
#
# AI Mentor — hook regression suite.
#
# Runs the PreToolUse and SessionStart hooks against a captive state file
# (AI_MENTOR_STATE override) and a synthesized transcript file, and asserts
# the exact behavior contract documented in SPEC-ai-mentor.md (A2/A3/A11/A14).
#
# Usage:    bash ai-mentor/tests/test-hooks.sh
# Exit:     0 if all tests pass, 1 if any failed.
# Deps:     bash, jq.
#
# Isolation:
#   - AI_MENTOR_STATE points at a tempfile under /tmp; never touches the
#     user's real state at ${CLAUDE_PLUGIN_DATA}/state.json.
#   - CLAUDE_PLUGIN_DATA is unset so the lib's preference order picks our
#     explicit AI_MENTOR_STATE.
#   - Trap on EXIT cleans up tempfiles even if a test crashes.

set +e  # we manage failures explicitly via PASS/FAIL counters

# ── locate plugin root from this script's location ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$PLUGIN_ROOT/lib/state.sh"
HOOK_PRE="$PLUGIN_ROOT/hooks-handlers/pre-tool-use.sh"
HOOK_SS="$PLUGIN_ROOT/hooks-handlers/session-start.sh"

# ── isolated test environment ───────────────────────────────────────────────
TMPDIR_TESTS="$(mktemp -d -t ai-mentor-tests-XXXXXX)"
export AI_MENTOR_STATE="$TMPDIR_TESTS/state.json"
unset CLAUDE_PLUGIN_DATA AI_MENTOR_DIR
TX_OVERRIDE="$TMPDIR_TESTS/tx-override.jsonl"
TX_INNOCENT="$TMPDIR_TESTS/tx-innocent.jsonl"

cleanup() {
  rm -rf "$TMPDIR_TESTS"
}
trap cleanup EXIT

# ── assertion helpers ───────────────────────────────────────────────────────
PASS=0
FAIL=0
FAILED_TESTS=()

pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "$2" ]] && printf '      %s\n' "$2"; }

# Run pre-tool-use hook. Args: tool_name transcript_path
# Echoes the hook's stdout.
run_pre_hook() {
  jq -n --arg t "$1" --arg tx "$2" \
    '{tool_name:$t, transcript_path:$tx, hook_event_name:"PreToolUse"}' \
    | bash "$HOOK_PRE"
}

# Run session-start hook. Args: source
# Echoes hook's stdout (includes additionalContext JSON).
run_ss_hook() {
  jq -n --arg s "$1" '{source:$s, hook_event_name:"SessionStart"}' \
    | bash "$HOOK_SS"
}

# Assert hook output is empty (i.e. tool allowed).
assert_allowed() {
  local out="$1" name="$2"
  if [[ -z "$out" ]]; then pass "$name"; else fail "$name" "expected allow (empty stdout), got: $out"; fi
}

# Assert hook output is a deny JSON.
assert_blocked() {
  local out="$1" name="$2"
  if echo "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
    pass "$name"
  else
    fail "$name" "expected deny JSON, got: $out"
  fi
}

# Assert state field equals expected value.
assert_state() {
  local field="$1" expected="$2" name="$3"
  local actual
  actual="$(am_read_field "$field")"
  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "field $field: expected '$expected', got '$actual'"
  fi
}

# ── test fixtures ───────────────────────────────────────────────────────────
cat > "$TX_OVERRIDE" <<'EOF'
{"type":"user","message":{"content":[{"type":"text","text":"yes show me"}]}}
EOF
cat > "$TX_INNOCENT" <<'EOF'
{"type":"user","message":{"content":[{"type":"text","text":"please implement quicksort"}]}}
EOF

# Source the lib so we can call helpers directly in tests.
# shellcheck source=../lib/state.sh
source "$LIB"

# ═══════════════════════════════════════════════════════════════════════════
# Section 1: state helper unit tests
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "── state helpers (lib/state.sh) ──"

# T1.1 — default state when file missing
rm -f "$AI_MENTOR_STATE"
default_zone="$(am_read_field zone)"
[[ "$default_zone" == "ambient" ]] && pass "S1 missing state → ambient default" \
  || fail "S1 missing state → ambient default" "got '$default_zone'"

# T1.2 — am_set_zone writes correct fields
am_set_zone 2 decide slash:/z2-decide
zone="$(am_read_field zone)"
submode="$(am_read_field submode)"
[[ "$zone" == "2" && "$submode" == "decide" ]] && pass "S2 am_set_zone writes zone+submode" \
  || fail "S2 am_set_zone writes zone+submode" "got zone=$zone submode=$submode"

# T1.3 — malformed state file returns default (fail-safe read)
echo "garbage{not_json" > "$AI_MENTOR_STATE"
zone="$(am_read_field zone)"
[[ "$zone" == "ambient" ]] && pass "S3 malformed state → ambient (fail-safe)" \
  || fail "S3 malformed state → ambient (fail-safe)" "got '$zone'"

# T1.4 — am_set_quiz then read
am_reset_state
am_set_quiz 3
ql="$(am_read_field quiz_level)"
[[ "$ql" == "3" ]] && pass "S4 am_set_quiz 3 → quiz_level=3" \
  || fail "S4 am_set_quiz 3 → quiz_level=3" "got '$ql'"

# T1.5 — am_set_quiz null clears
am_set_quiz null
ql="$(am_read_field quiz_level)"
[[ -z "$ql" ]] && pass "S5 am_set_quiz null → quiz_level cleared" \
  || fail "S5 am_set_quiz null → quiz_level cleared" "got '$ql'"

# T1.6 — am_last_user_msg parses transcript
msg="$(am_last_user_msg "$TX_OVERRIDE")"
[[ "$msg" == *"show me"* ]] && pass "S6 am_last_user_msg extracts last message" \
  || fail "S6 am_last_user_msg extracts last message" "got '$msg'"

# T1.7 — am_has_build_override detects override phrase
am_has_build_override "$TX_OVERRIDE" && pass "S7 am_has_build_override 'show me' → yes" \
  || fail "S7 am_has_build_override 'show me' → yes"

# T1.8 — am_has_build_override no false positive on innocent message
if am_has_build_override "$TX_INNOCENT"; then
  fail "S8 am_has_build_override innocent message → no" "false positive"
else
  pass "S8 am_has_build_override innocent message → no"
fi

# T1.9 — am_last_user_msg with empty arg returns empty
msg="$(am_last_user_msg "")"
[[ -z "$msg" ]] && pass "S9 am_last_user_msg empty arg → empty" \
  || fail "S9 am_last_user_msg empty arg → empty" "got '$msg'"

# ═══════════════════════════════════════════════════════════════════════════
# Section 2: PreToolUse hook scenarios (the contract from SPEC A2/A3/A14)
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "── PreToolUse hook (hooks-handlers/pre-tool-use.sh) ──"

# T2.1 — zone=ambient → allow
am_reset_state
out="$(run_pre_hook Edit "$TX_INNOCENT")"
assert_allowed "$out" "P1 zone=ambient → allow"

# T2.2 — zone=1 → allow
am_set_zone 1 null slash:/z1
out="$(run_pre_hook Edit "$TX_INNOCENT")"
assert_allowed "$out" "P2 zone=1 → allow"

# T2.3 — zone=2/build, no override → block
am_set_zone 2 build slash:/z2-build
out="$(run_pre_hook Edit "$TX_INNOCENT")"
assert_blocked "$out" "P3 zone=2/build, no override → block"

# T2.4 — zone=2/build, override 'show me' → allow
out="$(run_pre_hook Edit "$TX_OVERRIDE")"
assert_allowed "$out" "P4 zone=2/build, override 'show me' → allow"

# T2.5 — zone=2/decide → block (regardless of override)
am_set_zone 2 decide slash:/z2-decide
out="$(run_pre_hook Edit "$TX_INNOCENT")"
assert_blocked "$out" "P5 zone=2/decide → block"

# T2.6 — zone=2/decide with override phrase still blocks (decide unblocks via /locked only)
out="$(run_pre_hook Edit "$TX_OVERRIDE")"
assert_blocked "$out" "P6 zone=2/decide, override phrase → still block (decide needs /locked)"

# T2.7 — zone=2 + non-edit tool (Bash) → allow (matcher scope)
out="$(run_pre_hook Bash "$TX_INNOCENT")"
assert_allowed "$out" "P7 zone=2/decide, tool=Bash → allow (matcher scope)"

# T2.8 — fail open: malformed state
echo "garbage" > "$AI_MENTOR_STATE"
out="$(run_pre_hook Edit "$TX_INNOCENT")"
assert_allowed "$out" "P8 malformed state → allow (fail open)"

# T2.9 — fail open: build mode + missing transcript → allow
am_set_zone 2 build slash:/z2-build
out="$(run_pre_hook Edit "")"
assert_allowed "$out" "P9 zone=2/build + missing transcript → allow (fail open)"

# T2.10 — decide mode + missing transcript → block (unblock is /locked, not transcript)
am_set_zone 2 decide slash:/z2-decide
out="$(run_pre_hook Edit "")"
assert_blocked "$out" "P10 zone=2/decide + missing transcript → block (unblock = /locked)"

# T2.11 — zone=2 with NULL submode → allow (defensive)
am_set_zone 2 null skill
out="$(run_pre_hook Edit "$TX_INNOCENT")"
assert_allowed "$out" "P11 zone=2, null submode → allow (defensive)"

# ═══════════════════════════════════════════════════════════════════════════
# Section 3: SessionStart source-aware behavior (SPEC A11)
# ═══════════════════════════════════════════════════════════════════════════
echo ""
echo "── SessionStart hook (hooks-handlers/session-start.sh) ──"

# T3.1 — startup → reset to ambient
am_set_zone 2 build slash:/z2-build
run_ss_hook startup >/dev/null
assert_state zone "ambient" "M1 SessionStart startup → state reset to ambient"

# T3.2 — clear → reset to ambient
am_set_zone 2 decide slash:/z2-decide
run_ss_hook clear >/dev/null
assert_state zone "ambient" "M2 SessionStart clear → state reset to ambient"

# T3.3 — compact → preserve zone (the load-bearing v1.1 case)
am_set_zone 2 build slash:/z2-build
run_ss_hook compact >/dev/null
assert_state zone "2" "M3 SessionStart compact → zone preserved"
assert_state submode "build" "M4 SessionStart compact → submode preserved"

# T3.4 — resume → preserve zone
am_set_zone 2 decide slash:/z2-decide
run_ss_hook resume >/dev/null
assert_state zone "2" "M5 SessionStart resume → zone preserved"
assert_state submode "decide" "M6 SessionStart resume → submode preserved"

# T3.5 — missing source → reset (defensive default)
am_set_zone 2 build slash:/z2-build
echo '{"hook_event_name":"SessionStart"}' | bash "$HOOK_SS" >/dev/null
assert_state zone "ambient" "M7 SessionStart missing source → reset (defensive)"

# T3.6 — additionalContext is emitted (any source) and is non-empty
out="$(run_ss_hook startup)"
ctx="$(echo "$out" | jq -r .hookSpecificOutput.additionalContext 2>/dev/null)"
[[ -n "$ctx" && "${#ctx}" -gt 200 ]] && pass "M8 SessionStart emits non-empty additionalContext" \
  || fail "M8 SessionStart emits non-empty additionalContext" "got ${#ctx} chars"

# ═══════════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════════
TOTAL=$((PASS+FAIL))
echo ""
echo "─────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
  printf '\033[32mAll %d tests passed.\033[0m\n' "$TOTAL"
  exit 0
else
  printf '\033[31m%d/%d tests failed.\033[0m\n' "$FAIL" "$TOTAL"
  printf 'Failed:\n'
  for t in "${FAILED_TESTS[@]}"; do printf '  - %s\n' "$t"; done
  exit 1
fi
