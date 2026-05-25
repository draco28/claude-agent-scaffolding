#!/usr/bin/env bash
# tests/test-helpers.sh — 8 tests for lib/_helpers.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"

# 1. sd_log_info writes prefixed message to stderr
test_log_info_to_stderr() {
  echo "test_log_info_to_stderr:"
  local out
  out="$(sd_log_info "hello world" 2>&1 1>/dev/null)"
  assert_eq "log_info prefixed to stderr" "[scaffold-dev] hello world" "$out"
}

# 2. sd_log_warn prefix
test_log_warn_prefix() {
  echo "test_log_warn_prefix:"
  local out
  out="$(sd_log_warn "careful" 2>&1 1>/dev/null)"
  assert_eq "log_warn prefix" "[scaffold-dev WARN] careful" "$out"
}

# 3. sd_log_error prefix
test_log_error_prefix() {
  echo "test_log_error_prefix:"
  local out
  out="$(sd_log_error "boom" 2>&1 1>/dev/null)"
  assert_eq "log_error prefix" "[scaffold-dev ERROR] boom" "$out"
}

# 4. sd_require_jq when jq present
test_require_jq_present() {
  echo "test_require_jq_present:"
  if command -v jq >/dev/null 2>&1; then
    set +e
    sd_require_jq 2>/dev/null
    local rc=$?
    set -e 2>/dev/null || true
    assert_eq "require_jq exits 0 with jq" "0" "$rc"
  else
    echo "  (skipped: jq not in PATH)"
    PASS=$((PASS+1))
  fi
}

# 5. sd_abs_path with absolute input
test_abs_path_absolute() {
  echo "test_abs_path_absolute:"
  local out
  out="$(sd_abs_path "/tmp/foo")"
  assert_eq "abs path passes through" "/tmp/foo" "$out"
}

# 6. sd_abs_path with relative input
test_abs_path_relative() {
  echo "test_abs_path_relative:"
  setup_tmp_repo
  touch a.txt
  local out
  out="$(sd_abs_path "a.txt")"
  assert_eq "relative resolves to abs" "$TMP_DIR/repo/a.txt" "$out"
}

# 7. sd_jq_get returns value
test_jq_get_value() {
  echo "test_jq_get_value:"
  setup_tmp_repo
  echo '{"foo":"bar","n":42}' > data.json
  local out
  out="$(sd_jq_get data.json '.foo')"
  assert_eq "jq_get string value" "bar" "$out"
}

# 8. sd_jq_get returns empty for missing key
test_jq_get_missing() {
  echo "test_jq_get_missing:"
  setup_tmp_repo
  echo '{"foo":"bar"}' > data.json
  local out
  out="$(sd_jq_get data.json '.nope')"
  assert_eq "jq_get missing key empty" "" "$out"
}

test_log_info_to_stderr
test_log_warn_prefix
test_log_error_prefix
test_require_jq_present
test_abs_path_absolute
test_abs_path_relative
test_jq_get_value
test_jq_get_missing

sd_test_summary
