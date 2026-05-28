#!/usr/bin/env bash
# test-codex.sh — unit tests for lib/codex.sh (v0.2 codex 0.125+ semantics).
# Covers: availability, v0.2 flag-set, model override, timeout (default + env +
# flag), output parsed from --output-last-message file, schema validation,
# graceful fallback on every failure mode.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# shellcheck source=../_helpers.sh
source "$TESTS_DIR/_helpers.sh"
# shellcheck source=../../lib/_helpers.sh
source "$PLUGIN_ROOT/lib/_helpers.sh"
# shellcheck source=../../lib/codex.sh
source "$PLUGIN_ROOT/lib/codex.sh"

FIXTURES_DIR="$TESTS_DIR/fixtures"
PAYLOADS_DIR="$FIXTURES_DIR/codex-payloads"
MOCK_CODEX_DIR="$FIXTURES_DIR/mock-codex"

# Export plugin root so schema path resolution works from tmp dirs.
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

echo "=== test-codex.sh (v0.2) ==="

# ---------------------------------------------------------------------------
# 0. Structured-output schema is strict enough for OpenAI response_format.
# ---------------------------------------------------------------------------
echo ""
echo "-- 0. output schema requires additionalProperties=false on every object --"
(
  schema="$PLUGIN_ROOT/templates/output-schema.json"
  missing="$(jq -r '
    [path(.. | objects) as $p
      | getpath($p) as $obj
      | select(($obj.type? == "object") and ($obj.additionalProperties? != false))
      | "/" + ($p | map(tostring) | join("/"))
    ] | join("\n")
  ' "$schema")"
  if [[ -n "$missing" ]]; then
    echo "  x object schema(s) missing additionalProperties:false:"
    printf '%s\n' "$missing" | sed 's/^/    /'
    exit 1
  fi
  echo "  ok every object schema has additionalProperties:false"
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

echo ""
echo "-- 0b. output schema requires every declared property --"
(
  schema="$PLUGIN_ROOT/templates/output-schema.json"
  missing="$(jq -r '
    [path(.. | objects) as $p
      | getpath($p) as $obj
      | select($obj.type? == "object" and ($obj.properties? | type == "object"))
      | (($obj.properties | keys_unsorted) - ($obj.required // [])) as $missing
      | select($missing | length > 0)
      | ("/" + ($p | map(tostring) | join("/")) + " missing required: " + ($missing | join(",")))
    ] | join("\n")
  ' "$schema")"
  if [[ -n "$missing" ]]; then
    echo "  x object schema(s) have properties not listed in required:"
    printf '%s\n' "$missing" | sed 's/^/    /'
    exit 1
  fi
  echo "  ok every declared property is required"
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 1. ac_codex_available — codex absent (PATH stripped of real codex and mock).
# ---------------------------------------------------------------------------
echo ""
echo "-- 1. ac_codex_available: codex absent --"
(
  export PATH="/usr/bin:/bin"
  if ac_codex_available 2>/dev/null; then
    echo "  x ac_codex_available should return 1 when codex absent"
    exit 1
  else
    echo "  ok ac_codex_available returns 1 when codex absent"
    exit 0
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 2. ac_codex_available — codex present (mock in PATH).
# ---------------------------------------------------------------------------
echo ""
echo "-- 2. ac_codex_available: codex present via mock --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  if ac_codex_available 2>/dev/null; then
    echo "  ok ac_codex_available returns 0 when mock codex in PATH"
    exit 0
  else
    echo "  x ac_codex_available should return 0 when codex present"
    exit 1
  fi
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 3. ac_codex_run_audit — invocation uses required v0.2 flags.
# ---------------------------------------------------------------------------
echo ""
echo "-- 3. v0.2 invocation flags present in argv --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  out_dir="$(mktemp -d)"
  export MOCK_CODEX_ARGV_LOG="$out_dir/argv.log"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE
  ac_codex_run_audit "test prompt" "$out_dir" >/dev/null 2>&1
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  x run_audit failed unexpectedly (ec=$ec)"
    cat "$out_dir/argv.log" 2>/dev/null
    exit 1
  fi
  failed=0
  for required in exec --json --output-schema --output-last-message --ignore-user-config --ignore-rules --skip-git-repo-check; do
    if ! grep -qxF -e "$required" "$out_dir/argv.log"; then
      echo "  x missing required flag in argv: $required"
      failed=1
    fi
  done
  rm -rf "$out_dir"
  [[ $failed -eq 0 ]] && { echo "  ok all required v0.2 flags present"; exit 0; }
  exit 1
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 4. ac_codex_run_audit — no hardcoded model when override absent.
# ---------------------------------------------------------------------------
echo ""
echo "-- 4. no -c model= when --model override absent --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  out_dir="$(mktemp -d)"
  export MOCK_CODEX_ARGV_LOG="$out_dir/argv.log"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE
  ac_codex_run_audit "test prompt" "$out_dir" >/dev/null 2>&1
  if grep -qE '^model=' "$out_dir/argv.log" || grep -qxF -e '-c' "$out_dir/argv.log"; then
    echo "  x argv should not contain hardcoded model"
    cat "$out_dir/argv.log"
    rm -rf "$out_dir"
    exit 1
  fi
  rm -rf "$out_dir"
  echo "  ok no -c model=... in default argv"
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 5. ac_codex_run_audit — --model NAME injects -c model="NAME".
# ---------------------------------------------------------------------------
echo ""
echo "-- 5. --model NAME injects -c model=\"NAME\" --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  out_dir="$(mktemp -d)"
  export MOCK_CODEX_ARGV_LOG="$out_dir/argv.log"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE
  ac_codex_run_audit "test prompt" "$out_dir" --model gpt-5.5 >/dev/null 2>&1
  if ! grep -qxF -e '-c' "$out_dir/argv.log"; then
    echo "  x argv missing -c"
    cat "$out_dir/argv.log"; rm -rf "$out_dir"; exit 1
  fi
  if ! grep -qF 'model="gpt-5.5"' "$out_dir/argv.log"; then
    echo "  x argv missing model=\"gpt-5.5\""
    cat "$out_dir/argv.log"; rm -rf "$out_dir"; exit 1
  fi
  rm -rf "$out_dir"
  echo "  ok argv contains -c model=\"gpt-5.5\""
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 6. Default timeout is 300s when ARCHITECT_CRITIC_CODEX_TIMEOUT_S unset.
#    Functional check: function works with default; can't sit through 300s,
#    so just verify success path with default does not block.
# ---------------------------------------------------------------------------
echo ""
echo "-- 6. default timeout = 300s (success path works) --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/empty.json"
  out_dir="$(mktemp -d)"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE ARCHITECT_CRITIC_CODEX_TIMEOUT_S MOCK_CODEX_ARGV_LOG
  if [[ "$_AC_CODEX_DEFAULT_TIMEOUT_S" != "300" ]]; then
    echo "  x _AC_CODEX_DEFAULT_TIMEOUT_S should be 300, got $_AC_CODEX_DEFAULT_TIMEOUT_S"
    rm -rf "$out_dir"; exit 1
  fi
  result="$(ac_codex_run_audit "p" "$out_dir" 2>/dev/null)"
  ec=$?
  rm -rf "$out_dir"
  if [[ $ec -eq 0 ]]; then
    echo "  ok works with default timeout"
    exit 0
  fi
  echo "  x default-timeout run failed (ec=$ec)"
  exit 1
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 7. ARCHITECT_CRITIC_CODEX_TIMEOUT_S env override is honored.
#    Set timeout=1, sleep=4 -> should finish in <5s with ec=124.
# ---------------------------------------------------------------------------
echo ""
echo "-- 7. ARCHITECT_CRITIC_CODEX_TIMEOUT_S env override honored --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  export MOCK_CODEX_SLEEP=4
  export ARCHITECT_CRITIC_CODEX_TIMEOUT_S=1
  unset MOCK_CODEX_EXIT_CODE MOCK_CODEX_ARGV_LOG
  out_dir="$(mktemp -d)"
  start_ts=$(date +%s)
  ac_codex_run_audit "p" "$out_dir" >/dev/null 2>/dev/null
  ec=$?
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  rm -rf "$out_dir"
  if [[ $ec -eq 124 && $elapsed -lt 5 ]]; then
    echo "  ok env timeout honored: returned 124 in ${elapsed}s"
    exit 0
  fi
  echo "  x expected ec=124 in <5s, got ec=$ec elapsed=${elapsed}s"
  exit 1
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 8. --timeout flag wins over env var.
# ---------------------------------------------------------------------------
echo ""
echo "-- 8. --timeout flag wins over env var --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  export MOCK_CODEX_SLEEP=4
  export ARCHITECT_CRITIC_CODEX_TIMEOUT_S=60   # generous, so env alone would NOT trip
  unset MOCK_CODEX_EXIT_CODE MOCK_CODEX_ARGV_LOG
  out_dir="$(mktemp -d)"
  start_ts=$(date +%s)
  ac_codex_run_audit "p" "$out_dir" --timeout 1 >/dev/null 2>/dev/null
  ec=$?
  end_ts=$(date +%s)
  elapsed=$((end_ts - start_ts))
  rm -rf "$out_dir"
  if [[ $ec -eq 124 && $elapsed -lt 5 ]]; then
    echo "  ok --timeout 1 won over env=60: returned 124 in ${elapsed}s"
    exit 0
  fi
  echo "  x expected ec=124 in <5s, got ec=$ec elapsed=${elapsed}s"
  exit 1
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 9. Output parsed from --output-last-message file (3-challenges payload).
# ---------------------------------------------------------------------------
echo ""
echo "-- 9. output parsed from --output-last-message file --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE MOCK_CODEX_ARGV_LOG
  out_dir="$(mktemp -d)"
  result="$(ac_codex_run_audit "test prompt" "$out_dir" 2>/dev/null)"
  ec=$?
  if [[ $ec -ne 0 ]]; then
    echo "  x expected ec=0, got $ec"; rm -rf "$out_dir"; exit 1
  fi
  c_count="$(printf '%s' "$result" | jq -r '.challenges | length' 2>/dev/null)"
  if [[ "$c_count" != "3" ]]; then
    echo "  x expected 3 challenges, got $c_count"; rm -rf "$out_dir"; exit 1
  fi
  # Verify the actual file was written under output_dir.
  if ! ls "$out_dir"/codex-audit-*.json >/dev/null 2>&1; then
    echo "  x no codex-audit-*.json file written under $out_dir"; rm -rf "$out_dir"; exit 1
  fi
  rm -rf "$out_dir"
  echo "  ok 3 challenges parsed from last-message file"
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 10. Empty payload returns {challenges:[]}, ec=0.
# ---------------------------------------------------------------------------
echo ""
echo "-- 10. empty payload returns {challenges:[]} --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/empty.json"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE MOCK_CODEX_ARGV_LOG
  out_dir="$(mktemp -d)"
  result="$(ac_codex_run_audit "p" "$out_dir" 2>/dev/null)"
  ec=$?
  rm -rf "$out_dir"
  if [[ $ec -ne 0 ]]; then
    echo "  x expected ec=0, got $ec"; exit 1
  fi
  c_count="$(printf '%s' "$result" | jq -r '.challenges | length' 2>/dev/null)"
  if [[ "$c_count" != "0" ]]; then
    echo "  x expected 0 challenges, got $c_count"; exit 1
  fi
  echo "  ok empty payload returns 0 challenges"
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 11. Schema-violation file -> ec=1, stdout = empty result, warn logged.
# ---------------------------------------------------------------------------
echo ""
echo "-- 11. schema-violation rejected; ec=1; empty fallback emitted --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/schema-violation.json"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE MOCK_CODEX_ARGV_LOG
  out_dir="$(mktemp -d)"
  result="$(ac_codex_run_audit "p" "$out_dir" 2>/tmp/test_codex_stderr_11)"
  ec=$?
  rm -rf "$out_dir"
  if [[ $ec -eq 0 ]]; then
    echo "  x expected non-zero ec on schema violation, got 0"; exit 1
  fi
  c_count="$(printf '%s' "$result" | jq -r '.challenges | length' 2>/dev/null)"
  if [[ "$c_count" != "0" ]]; then
    echo "  x expected empty fallback challenges:[], got $c_count"; exit 1
  fi
  if ! grep -qi 'schema\|invalid\|valid' /tmp/test_codex_stderr_11; then
    echo "  x expected warn log about schema/invalid"; cat /tmp/test_codex_stderr_11; exit 1
  fi
  echo "  ok schema violation -> ec=1, empty fallback, warn logged"
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 12. Codex non-zero exit -> ec=1, empty fallback, warn logged.
# ---------------------------------------------------------------------------
echo ""
echo "-- 12. codex non-zero exit -> ec=1, empty fallback, warn logged --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  export MOCK_CODEX_EXIT_CODE=2
  unset MOCK_CODEX_SLEEP MOCK_CODEX_ARGV_LOG
  out_dir="$(mktemp -d)"
  result="$(ac_codex_run_audit "p" "$out_dir" 2>/tmp/test_codex_stderr_12)"
  ec=$?
  rm -rf "$out_dir"
  if [[ $ec -eq 0 ]]; then
    echo "  x expected non-zero ec, got 0"; exit 1
  fi
  c_count="$(printf '%s' "$result" | jq -r '.challenges | length' 2>/dev/null)"
  if [[ "$c_count" != "0" ]]; then
    echo "  x expected empty fallback, got $c_count"; exit 1
  fi
  if ! grep -qi 'exit\|non.zero\|nonzero\|fail' /tmp/test_codex_stderr_12; then
    echo "  x expected warn about non-zero exit"; cat /tmp/test_codex_stderr_12; exit 1
  fi
  echo "  ok non-zero exit -> empty fallback + warn"
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 13. Codex absent -> ec=1, empty fallback, info logged.
# ---------------------------------------------------------------------------
echo ""
echo "-- 13. codex absent -> ec=1, empty fallback, info logged --"
(
  export PATH="/usr/bin:/bin"
  out_dir="$(mktemp -d)"
  result="$(ac_codex_run_audit "p" "$out_dir" 2>/tmp/test_codex_stderr_13)"
  ec=$?
  rm -rf "$out_dir"
  if [[ $ec -eq 0 ]]; then
    echo "  x expected non-zero ec, got 0"; exit 1
  fi
  c_count="$(printf '%s' "$result" | jq -r '.challenges | length' 2>/dev/null)"
  if [[ "$c_count" != "0" ]]; then
    echo "  x expected empty fallback, got $c_count"; exit 1
  fi
  if ! grep -qi 'codex\|not\|available' /tmp/test_codex_stderr_13; then
    echo "  x expected info log about codex unavailable"; cat /tmp/test_codex_stderr_13; exit 1
  fi
  echo "  ok codex absent -> empty fallback + info"
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 14. Timeout returns ec=124 (GNU timeout convention) + warn logged.
# ---------------------------------------------------------------------------
echo ""
echo "-- 14. timeout returns ec=124 --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  export MOCK_CODEX_SLEEP=4
  export ARCHITECT_CRITIC_CODEX_TIMEOUT_S=1
  unset MOCK_CODEX_EXIT_CODE MOCK_CODEX_ARGV_LOG
  out_dir="$(mktemp -d)"
  ac_codex_run_audit "p" "$out_dir" >/dev/null 2>/tmp/test_codex_stderr_14
  ec=$?
  rm -rf "$out_dir"
  if [[ $ec -ne 124 ]]; then
    echo "  x expected ec=124 on timeout, got $ec"; exit 1
  fi
  if ! grep -qi 'timed\|timeout' /tmp/test_codex_stderr_14; then
    echo "  x expected warn about timeout"; cat /tmp/test_codex_stderr_14; exit 1
  fi
  echo "  ok timeout returns ec=124 + warn"
  exit 0
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 15. Long prompt does not crash; passed as last positional argv.
# ---------------------------------------------------------------------------
echo ""
echo "-- 15. long prompt passed as positional, no crash --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/empty.json"
  out_dir="$(mktemp -d)"
  export MOCK_CODEX_ARGV_LOG="$out_dir/argv.log"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE
  long_prompt="$(python3 -c 'print("x " * 5000)' 2>/dev/null || printf 'x %.0s' $(seq 1 200))"
  ac_codex_run_audit "$long_prompt" "$out_dir" >/dev/null 2>&1
  ec=$?
  last_line="$(tail -1 "$out_dir/argv.log" 2>/dev/null)"
  rm -rf "$out_dir"
  if [[ $ec -ne 0 ]]; then
    echo "  x failed on long prompt (ec=$ec)"; exit 1
  fi
  case "$last_line" in
    x*) echo "  ok long prompt arrived as positional argv"; exit 0 ;;
    *) echo "  x last argv line did not look like prompt: '$last_line'"; exit 1 ;;
  esac
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# ---------------------------------------------------------------------------
# 16. --output-last-message file lands under output_dir with REQ_ID suffix.
# ---------------------------------------------------------------------------
echo ""
echo "-- 16. last-message file under output_dir with codex-audit-*.json --"
(
  export PATH="$MOCK_CODEX_DIR:$PATH"
  export MOCK_CODEX_OUTPUT="$PAYLOADS_DIR/3-challenges.json"
  out_dir="$(mktemp -d)"
  export MOCK_CODEX_ARGV_LOG="$out_dir/argv.log"
  unset MOCK_CODEX_SLEEP MOCK_CODEX_EXIT_CODE
  ac_codex_run_audit "p" "$out_dir" >/dev/null 2>&1
  prev=""; found=""
  while IFS= read -r line; do
    if [[ "$prev" == "--output-last-message" ]]; then
      found="$line"; break
    fi
    prev="$line"
  done < "$out_dir/argv.log"
  case "$found" in
    "$out_dir"/codex-audit-*.json)
      echo "  ok --output-last-message under output_dir: $found"
      rm -rf "$out_dir"; exit 0 ;;
    *)
      echo "  x last-message path unexpected: '$found'"
      cat "$out_dir/argv.log"
      rm -rf "$out_dir"; exit 1 ;;
  esac
)
if [[ $? -eq 0 ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

# Cleanup tmp stderr files.
rm -f /tmp/test_codex_stderr_11 /tmp/test_codex_stderr_12 /tmp/test_codex_stderr_13 /tmp/test_codex_stderr_14

report_results
