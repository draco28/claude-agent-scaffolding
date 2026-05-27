#!/usr/bin/env bash
# architect-critic test helpers — sourced by every test suite.

PASS=0
FAIL=0
TMP_DIR=""

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ✓ $label"; PASS=$((PASS+1))
  else
    echo "  ✗ $label: expected '$expected', got '$actual'"; FAIL=$((FAIL+1))
  fi
}

assert_file_exists() {
  if [[ -f "$1" ]]; then
    echo "  ✓ file exists: $1"; PASS=$((PASS+1))
  else
    echo "  ✗ file missing: $1"; FAIL=$((FAIL+1))
  fi
}

assert_file_missing() {
  if [[ ! -f "$1" ]]; then
    echo "  ✓ file absent: $1"; PASS=$((PASS+1))
  else
    echo "  ✗ file present: $1"; FAIL=$((FAIL+1))
  fi
}

assert_file_contains() {
  if grep -q "$2" "$1" 2>/dev/null; then
    echo "  ✓ file contains pattern in $1"; PASS=$((PASS+1))
  else
    echo "  ✗ file missing pattern in $1: $2"; FAIL=$((FAIL+1))
  fi
}

assert_exit_code() {
  local expected="$1"; shift
  set +e; "$@" >/dev/null 2>&1; local ec=$?; set -e 2>/dev/null || true
  if [[ "$ec" == "$expected" ]]; then
    echo "  ✓ exit code $expected for: $*"; PASS=$((PASS+1))
  else
    echo "  ✗ exit code $expected for: $* (got $ec)"; FAIL=$((FAIL+1))
  fi
}

setup_tmp_repo() {
  TMP_DIR="$(mktemp -d -t architect-critic-test.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  mkdir -p "$TMP_DIR/repo"
  cd "$TMP_DIR/repo" || exit 1
  git init -q
  echo "$TMP_DIR"
}

cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
  return 0
}
trap cleanup EXIT

setup_mock_codex() {
  local payload="${1:-3-challenges.json}"
  local fixtures_dir
  fixtures_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixtures" && pwd)"
  export PATH="$fixtures_dir/mock-codex:$PATH"
  export MOCK_CODEX_OUTPUT="$fixtures_dir/codex-payloads/$payload"
}

report_results() {
  echo ""
  echo "Results: $PASS passed, $FAIL failed"
  [[ "$FAIL" -gt 0 ]] && exit 1 || exit 0
}
