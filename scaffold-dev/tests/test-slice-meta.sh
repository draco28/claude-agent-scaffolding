#!/usr/bin/env bash
# tests/test-slice-meta.sh — tests for lib/slice_meta.sh (#76 slice-start baseline:
# append-once JSON sentinel block in the VS README, read at slice-close).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/slice_meta.sh"

# A slice_root with a rendered VS README (as planning §6.2 leaves it before §8.1).
_mk_slice_root() {
  local d="$TMP_DIR/slice"
  mkdir -p "$d"
  printf '# VS-1.1.1 — demo slice\n\n## Description\n\nbody\n' > "$d/README.md"
  echo "$d"
}

test_write_then_read_roundtrip() {
  echo "test_write_then_read_roundtrip:"
  setup_tmp_repo
  local sr; sr="$(_mk_slice_root)"
  sd_slice_baseline_write "$sr" "a1b2c3d4" "main"
  local out; out="$(sd_slice_baseline_read "$sr")"
  assert_eq "sha round-trips"    "a1b2c3d4" "$(echo "$out" | jq -r .recorded_base_sha)"
  assert_eq "branch round-trips" "main"     "$(echo "$out" | jq -r .recorded_base_branch)"
}

test_write_is_record_once() {
  echo "test_write_is_record_once:"
  setup_tmp_repo
  local sr; sr="$(_mk_slice_root)"
  sd_slice_baseline_write "$sr" "first111" "main"
  sd_slice_baseline_write "$sr" "second22" "main"   # later round must NOT clobber
  assert_eq "first baseline preserved" "first111" "$(sd_slice_baseline_read "$sr" | jq -r .recorded_base_sha)"
}

test_write_preserves_readme_body() {
  echo "test_write_preserves_readme_body:"
  setup_tmp_repo
  local sr; sr="$(_mk_slice_root)"
  sd_slice_baseline_write "$sr" "a1b2c3d4" "main"
  assert_file_contains "$sr/README.md" "## Description"
  assert_file_contains "$sr/README.md" "sd:baseline:start"
}

test_write_atomic_no_tmp_leftover() {
  echo "test_write_atomic_no_tmp_leftover:"
  setup_tmp_repo
  local sr; sr="$(_mk_slice_root)"
  sd_slice_baseline_write "$sr" "a1b2c3d4" "main"
  assert_eq "no .tmp leftovers" "0" "$(ls "$sr" | grep -c '\.tmp' || true)"
}

test_read_absent_returns_1() {
  echo "test_read_absent_returns_1:"
  setup_tmp_repo
  local sr; sr="$(_mk_slice_root)"   # README exists but no baseline block
  sd_slice_baseline_read "$sr" >/dev/null 2>&1; local rc=$?
  assert_eq "read absent rc=1" "1" "$rc"
}

test_write_creates_readme_if_absent() {
  echo "test_write_creates_readme_if_absent:"
  setup_tmp_repo
  local sr="$TMP_DIR/slice2"; mkdir -p "$sr"
  sd_slice_baseline_write "$sr" "deadbeef" "main"
  assert_file_exists "$sr/README.md"
  assert_eq "sha readable" "deadbeef" "$(sd_slice_baseline_read "$sr" | jq -r .recorded_base_sha)"
}

test_write_usage_error_rc2() {
  echo "test_write_usage_error_rc2:"
  setup_tmp_repo
  sd_slice_baseline_write "$TMP_DIR/x" "" "main" >/dev/null 2>&1; local rc=$?
  assert_eq "missing sha → rc=2" "2" "$rc"
}

test_write_then_read_roundtrip
test_write_is_record_once
test_write_preserves_readme_body
test_write_atomic_no_tmp_leftover
test_read_absent_returns_1
test_write_creates_readme_if_absent
test_write_usage_error_rc2

sd_test_summary
