#!/usr/bin/env bash
# tests/test-roadmap.sh — consumer-side field-read of the published structured
# roadmap state (lib/roadmap.sh, #28 Phase 3).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/roadmap.sh"

# Build a minimal workspace + manifest, cd into the AI workspace.
# Arg 1: the manifest value for well_known_paths.roadmap_state (empty = omit key).
_mk_roadmap_workspace() {
  local roadmap_state_value="${1:-}"
  TMP_DIR="$(mktemp -d -t scaffold-dev-roadmap.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"; mkdir -p "$CLAUDE_PLUGIN_DATA"
  AW="$TMP_DIR/ai"; mkdir -p "$AW/.workspace"
  local wkp=""
  if [[ -n "$roadmap_state_value" ]]; then
    wkp=', "well_known_paths": {"roadmap_state": "'"$roadmap_state_value"'"}'
  fi
  cat > "$AW/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$AW","name":"demo-ai"},"canonical":{"root":"$TMP_DIR/canon","name":"demo","default_branch":"main"}${wkp}}
EOF
  cd "$AW"
}

# Publish a structured roadmap with 3-part slice ids + explicit sprint_id.
_write_roadmap_json() {
  local path="$1"; mkdir -p "$(dirname "$path")"
  cat > "$path" <<'JSON'
{"vertical_slices":[
  {"id":"VS-1.1.1","sprint_id":"1.1","slice_name":"auth-flow"},
  {"id":"VS-1.1.2","sprint_id":"1.1","slice_name":"logout-flow"},
  {"id":"VS-2.3.1","sprint_id":"2.3","slice_name":"reporting"}
]}
JSON
}

# 1. state path resolves from the routed well_known_paths.roadmap_state key
test_state_path_resolves_routed_key() {
  echo "test_state_path_resolves_routed_key:"
  _mk_roadmap_workspace '${ai_workspace.root}/.workspace/project-roadmap.json'
  assert_eq "routed roadmap_state resolves to AW path" \
    "$AW/.workspace/project-roadmap.json" "$(sd_roadmap_state_path)"
  cleanup
}

# 2. state path falls back when the key is absent (pre-0.1.2 manifest)
test_state_path_fallback_without_key() {
  echo "test_state_path_fallback_without_key:"
  _mk_roadmap_workspace ""
  assert_eq "fallback to canonical workspace path" \
    "$AW/.workspace/project-roadmap.json" "$(sd_roadmap_state_path)"
  cleanup
}

# 3. state path refuses a path with an unresolved ${…} placeholder
test_state_path_rejects_unresolved_placeholder() {
  echo "test_state_path_rejects_unresolved_placeholder:"
  _mk_roadmap_workspace '${TOTALLY_UNKNOWN}/project-roadmap.json'
  assert_exit_code 1 sd_roadmap_state_path
  cleanup
}

# 4. sprint_id is field-read (not derived from the id string)
test_slice_sprint_id_field_read() {
  echo "test_slice_sprint_id_field_read:"
  _mk_roadmap_workspace '${ai_workspace.root}/.workspace/project-roadmap.json'
  _write_roadmap_json "$AW/.workspace/project-roadmap.json"
  assert_eq "VS-1.1.1 sprint_id is 1.1" "1.1" "$(sd_roadmap_slice_sprint_id VS-1.1.1)"
  # The whole point of #28: a 3-part id never collapses to the first field.
  assert_ne "sprint_id is not the bare first field" "1" "$(sd_roadmap_slice_sprint_id VS-1.1.1)"
  assert_eq "VS-2.3.1 sprint_id is 2.3" "2.3" "$(sd_roadmap_slice_sprint_id VS-2.3.1)"
  cleanup
}

# 5. generic field accessor reads arbitrary fields
test_slice_field_generic() {
  echo "test_slice_field_generic:"
  _mk_roadmap_workspace '${ai_workspace.root}/.workspace/project-roadmap.json'
  _write_roadmap_json "$AW/.workspace/project-roadmap.json"
  assert_eq "VS-1.1.2 slice_name" "logout-flow" "$(sd_roadmap_slice_field VS-1.1.2 slice_name)"
  cleanup
}

# 6. exact-id lookup: a non-existent id fails (and the error lists available ids)
test_slice_not_found_fails() {
  echo "test_slice_not_found_fails:"
  _mk_roadmap_workspace '${ai_workspace.root}/.workspace/project-roadmap.json'
  _write_roadmap_json "$AW/.workspace/project-roadmap.json"
  assert_exit_code 1 sd_roadmap_slice_json VS-9.9.9
  # error message names the available ids
  local err; err="$(sd_roadmap_slice_json VS-9.9.9 2>&1 >/dev/null)"
  assert_contains "not-found error lists available ids" "VS-1.1.1" "$err"
  cleanup
}

# 7. missing published file fails with a remediation hint (not a silent default)
test_slice_missing_state_file_fails() {
  echo "test_slice_missing_state_file_fails:"
  _mk_roadmap_workspace '${ai_workspace.root}/.workspace/project-roadmap.json'
  # no _write_roadmap_json — file absent
  assert_exit_code 1 sd_roadmap_slice_json VS-1.1.1
  cleanup
}

test_state_path_resolves_routed_key
test_state_path_fallback_without_key
test_state_path_rejects_unresolved_placeholder
test_slice_sprint_id_field_read
test_slice_field_generic
test_slice_not_found_fails
test_slice_missing_state_file_fails

sd_test_summary
