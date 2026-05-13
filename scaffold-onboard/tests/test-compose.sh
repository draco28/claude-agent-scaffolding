#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/compose.sh"

# Build a fake plugin install dir at $TMP_DIR/fake-plugins/<name>
mk_fake_plugin() {
  local name="$1"; shift
  local dir="$TMP_DIR/fake-plugins/$name"
  mkdir -p "$dir"
  # Optional file paths to create inside the fake plugin
  local rel
  for rel in "$@"; do
    mkdir -p "$dir/$(dirname "$rel")"
    : > "$dir/$rel"
  done
  echo "$dir"
}

test_detect_ai_mentor_present() {
  echo "test_detect_ai_mentor_present:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-foo" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_ai_mentor)"
  if [[ "$found" == *"ai-mentor-foo"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ ai-mentor detected: $found"
  else
    FAIL=$((FAIL+1)); echo "  ✗ ai-mentor not detected: $found"
  fi
}

test_detect_ai_mentor_absent() {
  echo "test_detect_ai_mentor_absent:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"  # exists but empty
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_ai_mentor)"
  assert_eq "ai-mentor absent → empty" "" "$found"
}

test_detect_ai_mentor_present
test_detect_ai_mentor_absent
report_results
