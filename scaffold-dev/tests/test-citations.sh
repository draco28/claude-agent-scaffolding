#!/usr/bin/env bash
# tests/test-citations.sh — 4 tests for lib/citations.sh mechanical citation legs (#7)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/citations.sh"

# 1. sd_citations_check_file on an existing file → returns 0
test_check_file_exists() {
  echo "test_check_file_exists:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/real.py"
  echo "# content" > "$f"
  set +e
  sd_citations_check_file "$f" >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "existing file returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 2. sd_citations_check_file on a missing file → returns 1
test_check_file_missing() {
  echo "test_check_file_missing:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/no-such-file.py"
  set +e
  sd_citations_check_file "$f" >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "missing file returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

# 3. sd_citations_check_signature where file contains the exact signature → returns 0
test_check_signature_exact_match() {
  echo "test_check_signature_exact_match:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/module.py"
  printf 'def foo(a, b):\n    pass\n' > "$f"
  set +e
  sd_citations_check_signature "$f" "def foo(a, b):" >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "exact signature found returns 0" "0" "$rc"
  rm -rf "$TMP_DIR"
}

# 4. sd_citations_check_signature where file has a DRIFTED signature → returns 1
test_check_signature_drifted() {
  echo "test_check_signature_drifted:"
  TMP_DIR="$(mktemp -d -t sd-cit-test.XXXXXX)"
  local f="$TMP_DIR/module.py"
  # File now has an extra parameter — signature has drifted from the cited form
  printf 'def foo(a, b, c=False):\n    pass\n' > "$f"
  set +e
  sd_citations_check_signature "$f" "def foo(a, b):" >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "drifted signature returns 1" "1" "$rc"
  rm -rf "$TMP_DIR"
}

test_check_file_exists
test_check_file_missing
test_check_signature_exact_match
test_check_signature_drifted

sd_test_summary
