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

test_detect_architect_critic() {
  echo "test_detect_architect_critic:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-bar" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_architect_critic)"
  if [[ "$found" == *"architect-critic-bar"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ architect-critic detected"
  else
    FAIL=$((FAIL+1)); echo "  ✗ architect-critic not detected: $found"
  fi
}

test_detect_superpowers() {
  echo "test_detect_superpowers:"
  setup_tmp_repo
  mk_fake_plugin "superpowers" "skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local found
  found="$(sf_compose_detect_superpowers)"
  if [[ "$found" == *"superpowers"* ]]; then
    PASS=$((PASS+1)); echo "  ✓ superpowers detected"
  else
    FAIL=$((FAIL+1)); echo "  ✗ superpowers not detected: $found"
  fi
}

test_detect_brainstorming_available() {
  echo "test_detect_brainstorming_available:"
  setup_tmp_repo
  mk_fake_plugin "superpowers" "skills/brainstorming/SKILL.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local available
  available="$(sf_compose_brainstorming_available)"
  assert_eq "brainstorming available" "true" "$available"
}

test_detect_brainstorming_unavailable() {
  echo "test_detect_brainstorming_unavailable:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  local available
  available="$(sf_compose_brainstorming_available)"
  assert_eq "brainstorming unavailable" "false" "$available"
}

test_composition_refresh_with_plugins() {
  echo "test_composition_refresh_with_plugins:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-x" "state.json"
  mk_fake_plugin "architect-critic-y" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local path="$CLAUDE_PLUGIN_DATA/composition.json"
  assert_file_exists "$path"
  local mentor_installed critic_installed
  mentor_installed="$(jq -r '.plugins["ai-mentor"].installed' "$path")"
  critic_installed="$(jq -r '.plugins["architect-critic"].installed' "$path")"
  assert_eq "ai-mentor installed" "true" "$mentor_installed"
  assert_eq "architect-critic installed" "true" "$critic_installed"
}

test_composition_refresh_no_plugins() {
  echo "test_composition_refresh_no_plugins:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local path="$CLAUDE_PLUGIN_DATA/composition.json"
  local mentor_installed
  mentor_installed="$(jq -r '.plugins["ai-mentor"].installed' "$path")"
  assert_eq "ai-mentor absent" "false" "$mentor_installed"
}

test_composition_is_installed_helper() {
  echo "test_composition_is_installed_helper:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-z" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  assert_exit_code 0 sf_compose_is_installed "ai-mentor"
  assert_exit_code 1 sf_compose_is_installed "architect-critic"
}

test_detect_ai_mentor_present
test_detect_ai_mentor_absent
test_detect_architect_critic
test_detect_superpowers
test_detect_brainstorming_available
test_detect_brainstorming_unavailable
test_composition_refresh_with_plugins
test_composition_refresh_no_plugins
test_composition_is_installed_helper
report_results
