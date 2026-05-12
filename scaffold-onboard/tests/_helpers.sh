#!/usr/bin/env bash
# Shared assertion helpers for scaffold-onboard test suites.
# Source from each test-*.sh file; tests use assert_* and tmp-repo helpers.

set -u

PASS=0
FAIL=0
TMP_DIR=""

_color_pass() { printf "\033[32m%s\033[0m" "$1"; }
_color_fail() { printf "\033[31m%s\033[0m" "$1"; }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_file_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') file exists: $path"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file missing: $path"
  fi
}

assert_file_missing() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') file absent: $path"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file unexpectedly present: $path"
  fi
}

assert_file_contains() {
  local path="$1" pattern="$2"
  if [[ ! -e "$path" ]]; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file missing for contains-check: $path"
    return
  fi
  if grep -qE "$pattern" "$path"; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') $path contains /$pattern/"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $path does not contain /$pattern/"
  fi
}

assert_exit_code() {
  local expected="$1"; shift
  local label="exit code $expected for: $*"
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e 2>/dev/null || true
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $label (got $actual)"
  fi
}

setup_tmp_repo() {
  TMP_DIR="$(mktemp -d -t scaffold-onboard-test.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  mkdir -p "$TMP_DIR/repo"
  cd "$TMP_DIR/repo"
  git init -q
  git config user.email "test@example.com"
  git config user.name  "Test"
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

report_results() {
  echo ""
  echo "Results: $(_color_pass "$PASS passed"), $(_color_fail "$FAIL failed")"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}
