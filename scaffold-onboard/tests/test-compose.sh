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

test_mentor_hint_phase_5() {
  echo "test_mentor_hint_phase_5:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-q" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local hint
  hint="$(sf_compose_mentor_hint 5)"
  if echo "$hint" | grep -q "z2-decide"; then
    PASS=$((PASS+1)); echo "  ✓ phase 5 emits /z2-decide hint"
  else
    FAIL=$((FAIL+1)); echo "  ✗ phase 5 hint missing: $hint"
  fi
}

test_mentor_hint_phase_2() {
  echo "test_mentor_hint_phase_2:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-q" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local hint
  hint="$(sf_compose_mentor_hint 2)"
  assert_eq "phase 2 no hint" "" "$hint"
}

test_mentor_hint_without_install() {
  echo "test_mentor_hint_without_install:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/fake-plugins"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  local hint
  hint="$(sf_compose_mentor_hint 5)"
  assert_eq "no install, no hint" "" "$hint"
}

test_critic_request_premise_audit() {
  echo "test_critic_request_premise_audit:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-r" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  echo "test content" > MASTER-SPEC.md
  sf_state_init
  sf_state_write_answer "1.3.1" "CLI tool"
  local req_path
  req_path="$(sf_compose_build_critic_request "premise-audit" 5)"
  assert_file_exists "$req_path"
  local depth phase_id
  depth="$(jq -r .depth "$req_path")"
  phase_id="$(jq -r .target.phase_id "$req_path")"
  assert_eq "request depth" "premise-audit" "$depth"
  assert_eq "request phase_id" "5" "$phase_id"
  local concession
  concession="$(jq -r .concession_threshold "$req_path")"
  assert_eq "concession threshold = 4" "4" "$concession"
}

test_critic_request_close() {
  echo "test_critic_request_close:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-r" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  echo "test content" > MASTER-SPEC.md
  sf_state_init
  sf_state_write_answer "1.3.1" "CLI tool"
  local req_path
  req_path="$(sf_compose_build_critic_request "close" "")"
  local depth target_type
  depth="$(jq -r .depth "$req_path")"
  target_type="$(jq -r .target.type "$req_path")"
  assert_eq "depth=close" "close" "$depth"
  assert_eq "target type=master-spec-full" "master-spec-full" "$target_type"
  local adv0 adv1
  adv0="$(jq -r '.adversaries[0]' "$req_path")"
  adv1="$(jq -r '.adversaries[1]' "$req_path")"
  assert_eq "adversaries[0] = claude" "claude" "$adv0"
  assert_eq "adversaries[1] = codex" "codex" "$adv1"
}

test_critic_dispatch_with_mock_outbox() {
  echo "test_critic_dispatch_with_mock_outbox:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-m" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  echo "test content" > MASTER-SPEC.md
  sf_state_init
  sf_state_write_answer "1.3.1" "CLI tool"

  # Build request
  local req_path
  req_path="$(sf_compose_build_critic_request "premise-audit" 5)"
  local request_id
  request_id="$(jq -r .request_id "$req_path")"

  # Mock: write a response to the outbox manually (simulating critic)
  local critic_dir
  critic_dir="$(jq -r '.plugins["architect-critic"].data_dir' "$CLAUDE_PLUGIN_DATA/composition.json")"
  mkdir -p "$critic_dir/outbox"
  jq -n --arg rid "$request_id" '{
    request_id: $rid,
    adversaries_used: ["claude"],
    challenges: [
      {severity:"premise", text:"Test challenge", references:["Phase 5.2"]}
    ],
    gaps: [],
    divergences: [],
    elapsed_ms: 25000
  }' > "$critic_dir/outbox/${request_id}.json"

  # Wait/read the response (no real wait — mock is already there)
  local response_json
  response_json="$(sf_compose_read_critic_response "$request_id" 5)"
  local num_challenges
  num_challenges="$(echo "$response_json" | jq '.challenges | length')"
  assert_eq "challenge count" "1" "$num_challenges"
}

test_critic_response_timeout() {
  echo "test_critic_response_timeout:"
  setup_tmp_repo
  mk_fake_plugin "architect-critic-m" "principles.md"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  # No outbox response, short timeout
  local result ec
  set +e
  result="$(sf_compose_read_critic_response "nonexistent-id" 2 2>&1)"
  ec=$?
  set -e 2>/dev/null || true
  assert_eq "timeout exits non-zero" "1" "$ec"
}

test_user_override_disable_mentor() {
  echo "test_user_override_disable_mentor:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-z" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  # Flip the user override
  sf_compose_set_override "disable_mentor_suggestions" true
  local hint
  hint="$(sf_compose_mentor_hint 5)"
  assert_eq "override disables hint" "" "$hint"
}

test_user_override_survives_refresh() {
  echo "test_user_override_survives_refresh:"
  setup_tmp_repo
  mk_fake_plugin "ai-mentor-z" "state.json"
  export SF_COMPOSE_PROBE_PATHS="$TMP_DIR/fake-plugins"
  sf_compose_refresh
  sf_compose_set_override "disable_critic" true
  sf_compose_refresh  # second refresh — should preserve overrides
  local v
  v="$(jq -r '.user_overrides.disable_critic' "$CLAUDE_PLUGIN_DATA/composition.json")"
  assert_eq "override preserved" "true" "$v"
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
test_mentor_hint_phase_5
test_mentor_hint_phase_2
test_mentor_hint_without_install
test_critic_request_premise_audit
test_critic_request_close
test_critic_dispatch_with_mock_outbox
test_critic_response_timeout
test_user_override_disable_mentor
test_user_override_survives_refresh
report_results
