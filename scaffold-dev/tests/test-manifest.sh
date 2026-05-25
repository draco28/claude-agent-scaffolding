#!/usr/bin/env bash
# tests/test-manifest.sh — 12 tests for lib/manifest.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"

# 1. discover finds manifest in cwd
test_discover_cwd() {
  echo "test_discover_cwd:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local out
  out="$(sd_manifest_discover)"
  assert_eq "discover cwd" "$TMP_MANIFEST" "$out"
}

# 2. discover walks up from subdir
test_discover_parent() {
  echo "test_discover_parent:"
  setup_tmp_workspace
  mkdir -p "$TMP_AI_WORKSPACE/sub/deep"
  cd "$TMP_AI_WORKSPACE/sub/deep"
  local out
  out="$(sd_manifest_discover)"
  assert_eq "discover parent" "$TMP_MANIFEST" "$out"
}

# 3. discover walks up across canonical (looks toward ai workspace via walk-up)
test_discover_grandparent() {
  echo "test_discover_grandparent:"
  setup_tmp_workspace
  mkdir -p "$TMP_AI_WORKSPACE/a/b/c/d"
  cd "$TMP_AI_WORKSPACE/a/b/c/d"
  local out
  out="$(sd_manifest_discover)"
  assert_eq "discover deep walk-up" "$TMP_MANIFEST" "$out"
}

# 4. discover returns 1 when absent
test_discover_absent() {
  echo "test_discover_absent:"
  setup_tmp_repo
  set +e
  sd_manifest_discover 2>/dev/null
  local rc=$?
  :
  assert_eq "discover absent rc=1" "1" "$rc"
}

# 5. sd_manifest_require fails when absent
test_require_absent() {
  echo "test_require_absent:"
  setup_tmp_repo
  set +e
  sd_manifest_require 2>/dev/null
  local rc=$?
  :
  assert_eq "require absent rc=1" "1" "$rc"
}

# 6. sd_manifest_require passes when present
test_require_present() {
  echo "test_require_present:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e
  sd_manifest_require 2>/dev/null
  local rc=$?
  :
  assert_eq "require present rc=0" "0" "$rc"
}

# 7. sd_manifest_get reads canonical.root
test_get_canonical_root() {
  echo "test_get_canonical_root:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local out
  out="$(sd_manifest_get '.canonical.root')"
  assert_eq "canonical.root" "$TMP_CANONICAL" "$out"
}

# 8. sd_manifest_get reads ai_workspace.root
test_get_ai_root() {
  echo "test_get_ai_root:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local out
  out="$(sd_manifest_get '.ai_workspace.root')"
  assert_eq "ai_workspace.root" "$TMP_AI_WORKSPACE" "$out"
}

# 9. sd_manifest_get reads nested routing
test_get_routing_roadmap() {
  echo "test_get_routing_roadmap:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local out
  out="$(sd_manifest_get '.routing.roadmap')"
  assert_eq "routing.roadmap" "canonical" "$out"
}

# 10. sd_manifest_get fails on missing manifest
test_get_no_manifest() {
  echo "test_get_no_manifest:"
  setup_tmp_repo
  set +e
  sd_manifest_get '.foo' 2>/dev/null
  local rc=$?
  :
  assert_eq "get with no manifest rc=1" "1" "$rc"
}

# 11. sd_manifest_resolve resolves ${ai_workspace.root}
test_resolve_ai_root() {
  echo "test_resolve_ai_root:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local out
  out="$(sd_manifest_resolve "$TMP_AI_WORKSPACE" '${ai_workspace.root}/docs/spec.md')"
  assert_eq "resolve ai_workspace.root" "$TMP_AI_WORKSPACE/docs/spec.md" "$out"
}

# 12. sd_manifest_resolve resolves ${PLUGIN_DATA:<plugin>}
test_resolve_plugin_data() {
  echo "test_resolve_plugin_data:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local out
  out="$(sd_manifest_resolve "$TMP_AI_WORKSPACE" '${PLUGIN_DATA:scaffold-dev}/state.json')"
  assert_contains "PLUGIN_DATA resolves to a path" "scaffold-dev/state.json" "$out"
}

test_discover_cwd
test_discover_parent
test_discover_grandparent
test_discover_absent
test_require_absent
test_require_present
test_get_canonical_root
test_get_ai_root
test_get_routing_roadmap
test_get_no_manifest
test_resolve_ai_root
test_resolve_plugin_data

sd_test_summary
