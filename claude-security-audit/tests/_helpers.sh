#!/usr/bin/env bash
# tests/_helpers.sh — shared assertion primitives for security-audit test suite.
# Mirrors architect-critic's bash test harness convention.

set -u

# Cross-platform sha256: sha256sum on Linux, shasum -a 256 on macOS.
csa_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  fi
}

# csa_test_run <test_function_name>
# Prints PASS/FAIL with the function name.
csa_test_run() {
  local fn="$1"
  if "$fn"; then
    printf '  PASS  %s\n' "$fn"
    return 0
  else
    printf '  FAIL  %s\n' "$fn" >&2
    return 1
  fi
}

# assert_eq <expected> <actual> [<message>]
assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-assert_eq}"
  if [[ "$expected" != "$actual" ]]; then
    printf '    %s: expected=%q actual=%q\n' "$msg" "$expected" "$actual" >&2
    return 1
  fi
}

# assert_contains <haystack> <needle> [<message>]
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local msg="${3:-assert_contains}"
  if [[ "$haystack" != *"$needle"* ]]; then
    printf '    %s: needle=%q not found in haystack=%q\n' "$msg" "$needle" "$haystack" >&2
    return 1
  fi
}

# assert_exits_with <expected_exit_code> <command...>
assert_exits_with() {
  local expected_ec="$1"; shift
  local actual_ec=0
  "$@" >/dev/null 2>&1 || actual_ec=$?
  if [[ "$actual_ec" -ne "$expected_ec" ]]; then
    printf '    assert_exits_with: expected_ec=%d actual_ec=%d cmd=%q\n' "$expected_ec" "$actual_ec" "$*" >&2
    return 1
  fi
}

# csa_tmpdir — create a sandbox tempdir, register cleanup on exit.
csa_tmpdir() {
  local d
  d="$(mktemp -d "${TMPDIR:-/tmp}/csa-test.XXXXXX")"
  # Auto-cleanup on script exit; trap is additive.
  trap "rm -rf '$d'" EXIT
  printf '%s' "$d"
}

# Resolve plugin root regardless of CWD or BASH_SOURCE quirks (architect-critic
# v0.1.3 issue #3 noted; we resolve eagerly here to avoid the same bug).
CSA_PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export CSA_PLUGIN_ROOT
export CSA_LIB_DIR="$CSA_PLUGIN_ROOT/lib"
export CSA_RULES_DIR="$CSA_LIB_DIR/rules"
export CSA_FIXTURES_DIR="$CSA_PLUGIN_ROOT/fixtures"
