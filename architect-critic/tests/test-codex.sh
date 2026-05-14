#!/usr/bin/env bash
# test-codex.sh — unit tests for lib/codex.sh
# ~15 tests covering: available detection, JSON success, empty/malformed payloads,
# timeout, non-zero exit, absent codex, env override.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=./_helpers.sh
source "$SCRIPT_DIR/_helpers.sh"
# shellcheck source=../lib/_helpers.sh
source "$PLUGIN_ROOT/lib/_helpers.sh"
# shellcheck source=../lib/codex.sh
source "$PLUGIN_ROOT/lib/codex.sh"

FIXTURES_DIR="$SCRIPT_DIR/fixtures"
PAYLOADS_DIR="$FIXTURES_DIR/codex-payloads"
MOCK_CODEX_DIR="$FIXTURES_DIR/mock-codex"

echo "=== test-codex.sh ==="

# ---------------------------------------------------------------------------
# 1. ac_codex_available — codex absent (PATH stripped of real codex and mock)
# ---------------------------------------------------------------------------
echo ""
echo "-- 1. ac_codex_available: codex absent --"
(
  # Override PATH to a minimal safe set with no codex
  export PATH="/usr/bin:/bin"
  if ac_codex_available 2>/dev/null; then
    echo "  ✗ ac_codex_available should return 1 when codex absent"
    exit 1
  else
    echo "  ✓ ac_codex_available returns 1 when codex absent"
    exit 0
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 2. ac_codex_available — codex present (mock in PATH)
# ---------------------------------------------------------------------------
echo ""
echo "-- 2. ac_codex_available: codex present via mock --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  if ac_codex_available 2>/dev/null; then
    echo "  ✓ ac_codex_available returns 0 when mock codex in PATH"
    exit 0
  else
    echo "  ✗ ac_codex_available should return 0 when codex present"
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 3. ac_codex_audit — codex absent → returns 1 with info log
# ---------------------------------------------------------------------------
echo ""
echo "-- 3. ac_codex_audit: codex absent → returns 1 --"
(
  export PATH="/usr/bin:/bin"
  result=$(ac_codex_audit "some prompt" 2>/tmp/test_codex_stderr_3)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✓ ac_codex_audit returns 1 when codex absent"
  else
    echo "  ✗ ac_codex_audit should return 1 when codex absent (got $ec)"
    exit 1
  fi
  # Should emit info log about codex not being available
  if grep -qi "info\|codex\|unavailable\|not found\|absent\|available" /tmp/test_codex_stderr_3 2>/dev/null; then
    echo "  ✓ ac_codex_audit logs info when codex absent"
  else
    echo "  ✗ ac_codex_audit should log info when codex absent"
    cat /tmp/test_codex_stderr_3 >&2
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+2)); else FAIL=$((FAIL+2)); fi

# ---------------------------------------------------------------------------
# 4. ac_codex_audit — JSON parse success, 3-challenges payload
# ---------------------------------------------------------------------------
echo ""
echo "-- 4. ac_codex_audit: JSON parse success (3-challenges) --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE
  result=$(ac_codex_audit "test prompt" 2>/dev/null)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✗ ac_codex_audit should succeed with valid JSON (got $ec)"
    exit 1
  fi
  # Result should be parseable JSON with challenges key
  challenge_count=$(echo "$result" | jq -r '.challenges | length' 2>/dev/null)
  if [[ "$challenge_count" == "3" ]]; then
    echo "  ✓ ac_codex_audit returns parsed JSON with 3 challenges"
  else
    echo "  ✗ expected 3 challenges, got: $challenge_count"
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 5. ac_codex_audit — empty.json payload → emits {challenges:[], gaps:[]}
# ---------------------------------------------------------------------------
echo ""
echo "-- 5. ac_codex_audit: empty payload → {challenges:[], gaps:[]} --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/empty.json"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE
  result=$(ac_codex_audit "test prompt" 2>/dev/null)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✗ ac_codex_audit should succeed with empty JSON (got $ec)"
    exit 1
  fi
  c_count=$(echo "$result" | jq -r '.challenges | length' 2>/dev/null)
  g_count=$(echo "$result" | jq -r '.gaps | length' 2>/dev/null)
  if [[ "$c_count" == "0" && "$g_count" == "0" ]]; then
    echo "  ✓ ac_codex_audit returns {challenges:[], gaps:[]} for empty payload"
  else
    echo "  ✗ expected empty arrays, got challenges=$c_count gaps=$g_count"
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 6. ac_codex_audit — malformed JSON → returns 1 with warn log
# ---------------------------------------------------------------------------
echo ""
echo "-- 6. ac_codex_audit: malformed JSON → returns 1 with warn --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/malformed.json"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE
  result=$(ac_codex_audit "test prompt" 2>/tmp/test_codex_stderr_6)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✓ ac_codex_audit returns 1 for malformed JSON"
  else
    echo "  ✗ ac_codex_audit should return 1 for malformed JSON (got 0)"
    exit 1
  fi
  if grep -qi "warn\|parse\|json\|invalid\|malformed" /tmp/test_codex_stderr_6 2>/dev/null; then
    echo "  ✓ ac_codex_audit logs warn for malformed JSON"
  else
    echo "  ✗ ac_codex_audit should log warn for malformed JSON"
    cat /tmp/test_codex_stderr_6 >&2
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+2)); else FAIL=$((FAIL+2)); fi

# ---------------------------------------------------------------------------
# 7. ac_codex_audit — non-zero exit (MOCK_CODEX_EXIT_CODE=2) → returns 1 with warn
# ---------------------------------------------------------------------------
echo ""
echo "-- 7. ac_codex_audit: non-zero exit (exit code 2) → returns 1 with warn --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  export MOCK_CODEX_EXIT_CODE=2
  unset MOCK_CODEX_SLEEP
  result=$(ac_codex_audit "test prompt" 2>/tmp/test_codex_stderr_7)
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  ✓ ac_codex_audit returns 1 for non-zero codex exit"
  else
    echo "  ✗ ac_codex_audit should return 1 for non-zero codex exit (got 0)"
    exit 1
  fi
  if grep -qi "warn\|exit\|fail\|error\|non.zero\|nonzero" /tmp/test_codex_stderr_7 2>/dev/null; then
    echo "  ✓ ac_codex_audit logs warn for non-zero codex exit"
  else
    echo "  ✗ ac_codex_audit should log warn for non-zero exit"
    cat /tmp/test_codex_stderr_7 >&2
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+2)); else FAIL=$((FAIL+2)); fi

# ---------------------------------------------------------------------------
# 8. ac_codex_audit — timeout: MOCK_CODEX_SLEEP=5, ARCHITECT_CRITIC_CODEX_TIMEOUT=2
#    Should kill process, return 1 with warn, wall-clock <10s
# ---------------------------------------------------------------------------
echo ""
echo "-- 8. ac_codex_audit: timeout (sleep=5, timeout=2) → returns 1 with warn --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  export MOCK_CODEX_SLEEP=5
  export ARCHITECT_CRITIC_CODEX_TIMEOUT=2
  unset MOCK_CODEX_EXIT_CODE
  start_ts=$(date +%s)
  result=$(ac_codex_audit "test prompt" 2>/tmp/test_codex_stderr_8)
  ec=$?
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  if [[ $ec -ne 0 ]]; then
    echo "  ✓ ac_codex_audit returns 1 on timeout"
  else
    echo "  ✗ ac_codex_audit should return 1 on timeout (got 0)"
    exit 1
  fi
  if [[ $elapsed -lt 10 ]]; then
    echo "  ✓ wall-clock ${elapsed}s < 10s (timeout enforced)"
  else
    echo "  ✗ wall-clock ${elapsed}s too long (timeout not enforced)"
    exit 1
  fi
  if grep -qi "warn\|timeout\|timed\|killed\|kill" /tmp/test_codex_stderr_8 2>/dev/null; then
    echo "  ✓ ac_codex_audit logs warn on timeout"
  else
    echo "  ✗ ac_codex_audit should log warn on timeout"
    cat /tmp/test_codex_stderr_8 >&2
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+3)); else FAIL=$((FAIL+3)); fi

# ---------------------------------------------------------------------------
# 9. ARCHITECT_CRITIC_CODEX_TIMEOUT env override is honored
#    Set timeout=1, sleep=3 → should finish in <5s with non-zero exit
# ---------------------------------------------------------------------------
echo ""
echo "-- 9. ARCHITECT_CRITIC_CODEX_TIMEOUT env override honored --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  export MOCK_CODEX_SLEEP=3
  export ARCHITECT_CRITIC_CODEX_TIMEOUT=1
  unset MOCK_CODEX_EXIT_CODE
  start_ts=$(date +%s)
  result=$(ac_codex_audit "test prompt" 2>/dev/null)
  ec=$?
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  if [[ $ec -ne 0 && $elapsed -lt 5 ]]; then
    echo "  ✓ ARCHITECT_CRITIC_CODEX_TIMEOUT=1 honored: failed in ${elapsed}s"
  else
    echo "  ✗ expected failure in <5s, got ec=$ec elapsed=${elapsed}s"
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 10. ac_codex_audit passes prompt to codex via stdin
#     (mock consumes stdin; verify function doesn't crash on long prompts)
# ---------------------------------------------------------------------------
echo ""
echo "-- 10. ac_codex_audit: long prompt doesn't crash --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/empty.json"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE
  long_prompt="$(python3 -c 'print("x " * 5000)' 2>/dev/null || printf '%0.s x' {1..100})"
  result=$(ac_codex_audit "$long_prompt" 2>/dev/null)
  ec=$?
  if [[ $ec -eq 0 ]]; then
    echo "  ✓ ac_codex_audit handles long prompt without crash"
  else
    echo "  ✗ ac_codex_audit crashed on long prompt (ec=$ec)"
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 11. Default timeout is 180 when ARCHITECT_CRITIC_CODEX_TIMEOUT not set
#     (functional check: default is used — can't wait 180s, so just verify the
#      variable isn't required for success path)
# ---------------------------------------------------------------------------
echo ""
echo "-- 11. Default timeout: function works without ARCHITECT_CRITIC_CODEX_TIMEOUT set --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/empty.json"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE ARCHITECT_CRITIC_CODEX_TIMEOUT
  result=$(ac_codex_audit "test prompt" 2>/dev/null)
  ec=$?
  if [[ $ec -eq 0 ]]; then
    echo "  ✓ ac_codex_audit works with default timeout (ARCHITECT_CRITIC_CODEX_TIMEOUT unset)"
  else
    echo "  ✗ ac_codex_audit should work with default timeout (ec=$ec)"
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Cleanup tmp stderr files
rm -f /tmp/test_codex_stderr_3 /tmp/test_codex_stderr_6 /tmp/test_codex_stderr_7 /tmp/test_codex_stderr_8

report_results
