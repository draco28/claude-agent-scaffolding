#!/usr/bin/env bash
# Tests for lib/routing.sh — sf_discover_manifest + sf_resolve_output_path
# Per SPEC §10.1-10.4 + PLAN T3.1 (12 assertions).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/routing.sh"

# Stable anchor dir for tests that need a "safe cwd" between teardowns.
# Each teardown removes its own TMP_DIR, so we always cd back here first.
ANCHOR_DIR="$HERE"

# ---------- Per-test isolation helper ---------------------------------------
# (setup_tmp_repo from _helpers cd's into one tmp/repo; here we need richer
# fixtures with a sibling ai-workspace + canonical pair, optionally nested.)
#
# Globals exported:
#   TMP_AI_WORKSPACE — absolute path to ai-workspace
#   TMP_CANONICAL    — absolute path to canonical
#   TMP_MANIFEST     — absolute path to pairing.json
test_setup_workspace() {
  local include_roadmap="${1:-yes}"   # "yes" | "no" (omit routing.roadmap key)
  TMP_DIR="$(mktemp -d -t scaffold-onboard-routing.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  TMP_AI_WORKSPACE="$TMP_DIR/foo-ai"
  TMP_CANONICAL="$TMP_DIR/foo"
  mkdir -p "$TMP_AI_WORKSPACE/.workspace"
  mkdir -p "$TMP_CANONICAL"
  TMP_MANIFEST="$TMP_AI_WORKSPACE/.workspace/pairing.json"

  if [[ "$include_roadmap" == "yes" ]]; then
    cat > "$TMP_MANIFEST" <<EOF
{
  "schema_version": "1.0",
  "topology": "dual-repo",
  "ai_workspace": { "root": "${TMP_AI_WORKSPACE}", "name": "foo-ai" },
  "canonical":    { "root": "${TMP_CANONICAL}",    "name": "foo" },
  "routing": {
    "master_spec":              "ai_workspace",
    "executive_summary":        "canonical",
    "memory_bank":              "ai_workspace",
    "claude_md":                "ai_workspace",
    "agents_md":                "ai_workspace",
    "scaffold_project_outputs": "ai_workspace",
    "backlog":                  "canonical",
    "project_plan":             "canonical",
    "roadmap":                  "canonical",
    "prd":                      "canonical",
    "srs":                      "canonical",
    "product_adrs":             "canonical",
    "process_adrs":             "ai_workspace",
    "sprint_specs":             "ai_workspace",
    "implementation_handoffs":  "ai_workspace",
    "brainstorm_artifacts":     "ai_workspace"
  }
}
EOF
  else
    # Manifest WITHOUT routing.roadmap (workspace-init v0.1 baseline)
    cat > "$TMP_MANIFEST" <<EOF
{
  "schema_version": "1.0",
  "topology": "dual-repo",
  "ai_workspace": { "root": "${TMP_AI_WORKSPACE}", "name": "foo-ai" },
  "canonical":    { "root": "${TMP_CANONICAL}",    "name": "foo" },
  "routing": {
    "master_spec":  "ai_workspace",
    "prd":          "canonical"
  }
}
EOF
  fi
}

teardown_workspace() {
  # Always cd to a stable safe dir BEFORE removing TMP_DIR; otherwise the
  # next test's cd will fail if its cwd was inside the just-deleted tree.
  cd "$ANCHOR_DIR" 2>/dev/null || cd /tmp
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
  TMP_DIR=""
}

# ---------- Tests -----------------------------------------------------------

test_discover_manifest_walks_up() {
  echo "test_discover_manifest_walks_up:"
  test_setup_workspace yes
  mkdir -p "$TMP_AI_WORKSPACE/docs/specs/sprint-1"
  cd "$TMP_AI_WORKSPACE/docs/specs/sprint-1"
  local found
  found="$(sf_discover_manifest)"
  assert_eq "walks up from nested subdir to find pairing.json" "$TMP_MANIFEST" "$found"
  teardown_workspace
}

test_discover_manifest_absent() {
  echo "test_discover_manifest_absent:"
  # Use a fresh tmp dir with NO pairing.json anywhere up the tree from cwd.
  # We must guarantee no .workspace/pairing.json exists in any ancestor.
  # mktemp under TMPDIR; TMPDIR ancestors might also lack one — verify by
  # walking up ourselves to be sure.
  local before_pwd; before_pwd="$(pwd)"
  TMP_DIR="$(mktemp -d -t scaffold-onboard-routing-absent.XXXXXX)"
  cd "$TMP_DIR"
  # Sanity: confirm no ancestor has .workspace/pairing.json (otherwise the
  # test's premise is broken on this machine — would warrant an env tweak).
  local probe_dir="$TMP_DIR" has_ancestor=0
  while [[ "$probe_dir" != "/" ]]; do
    if [[ -f "$probe_dir/.workspace/pairing.json" ]]; then
      has_ancestor=1; break
    fi
    probe_dir="$(dirname "$probe_dir")"
  done
  if [[ "$has_ancestor" == "1" ]]; then
    FAIL=$((FAIL+1))
    echo "  ✗ test premise broken — pairing.json exists in tmp dir ancestor"
  else
    local out rc
    set +e
    out="$(sf_discover_manifest)"; rc=$?
    set -e 2>/dev/null || true
    if [[ "$rc" == "1" && -z "$out" ]]; then
      PASS=$((PASS+1)); echo "  ✓ no manifest → rc=1 + empty output"
    else
      FAIL=$((FAIL+1))
      echo "  ✗ expected rc=1+empty; got rc=$rc out='$out'"
    fi
  fi
  cd "$before_pwd"
  teardown_workspace
}

test_resolve_master_spec_manifest_present() {
  echo "test_resolve_master_spec_manifest_present:"
  test_setup_workspace yes
  cd "$TMP_AI_WORKSPACE"
  local got
  got="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
  assert_eq "master_spec → ai_workspace.root/MASTER-SPEC.md" \
    "${TMP_AI_WORKSPACE}/MASTER-SPEC.md" "$got"
  teardown_workspace
}

test_resolve_memory_bank_manifest_present() {
  echo "test_resolve_memory_bank_manifest_present:"
  test_setup_workspace yes
  cd "$TMP_AI_WORKSPACE"
  local got
  got="$(sf_resolve_output_path memory_bank 03-code-patterns.md)"
  assert_eq "memory_bank → ai_workspace.root/03-code-patterns.md" \
    "${TMP_AI_WORKSPACE}/03-code-patterns.md" "$got"
  teardown_workspace
}

test_resolve_prd_routes_to_canonical() {
  echo "test_resolve_prd_routes_to_canonical:"
  test_setup_workspace yes
  cd "$TMP_AI_WORKSPACE"
  local got
  got="$(sf_resolve_output_path prd PRD.md)"
  assert_eq "prd → canonical.root/PRD.md" \
    "${TMP_CANONICAL}/PRD.md" "$got"
  teardown_workspace
}

test_resolve_process_adrs_routes_to_ai_workspace() {
  echo "test_resolve_process_adrs_routes_to_ai_workspace:"
  test_setup_workspace yes
  cd "$TMP_AI_WORKSPACE"
  local got
  got="$(sf_resolve_output_path process_adrs adr/0001.md)"
  assert_eq "process_adrs → ai_workspace.root/adr/0001.md" \
    "${TMP_AI_WORKSPACE}/adr/0001.md" "$got"
  teardown_workspace
}

test_resolve_no_manifest_falls_back_to_cwd() {
  echo "test_resolve_no_manifest_falls_back_to_cwd:"
  # Establish a tmp dir with no manifest ancestor (mirrors absent test).
  local before_pwd; before_pwd="$(pwd)"
  TMP_DIR="$(mktemp -d -t scaffold-onboard-routing-fallback.XXXXXX)"
  cd "$TMP_DIR"
  local probe_dir="$TMP_DIR" has_ancestor=0
  while [[ "$probe_dir" != "/" ]]; do
    if [[ -f "$probe_dir/.workspace/pairing.json" ]]; then
      has_ancestor=1; break
    fi
    probe_dir="$(dirname "$probe_dir")"
  done
  if [[ "$has_ancestor" == "1" ]]; then
    FAIL=$((FAIL+1))
    echo "  ✗ test premise broken — pairing.json in ancestor"
  else
    local got
    got="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
    # macOS mktemp paths may contain symlinks; pwd resolves them. Compare
    # against $(pwd) (what the helper actually echoes).
    assert_eq "no manifest → \$(pwd)/MASTER-SPEC.md" \
      "$(pwd)/MASTER-SPEC.md" "$got"
  fi
  cd "$before_pwd"
  teardown_workspace
}

test_resolve_unknown_name_warns_and_falls_back() {
  echo "test_resolve_unknown_name_warns_and_falls_back:"
  test_setup_workspace yes
  cd "$TMP_AI_WORKSPACE"
  local got stderr_capture
  stderr_capture="$(mktemp -t sf-routing-stderr.XXXXXX)"
  got="$(sf_resolve_output_path bogus_unknown_key foo.md 2>"$stderr_capture")"
  # Expected: stderr contains "bogus_unknown_key" + falls back to cwd
  if grep -q "bogus_unknown_key" "$stderr_capture"; then
    PASS=$((PASS+1)); echo "  ✓ stderr warns about unknown logical name"
  else
    FAIL=$((FAIL+1))
    echo "  ✗ expected warn about 'bogus_unknown_key' in stderr"
    echo "    stderr was:"; cat "$stderr_capture" | sed 's/^/      /'
  fi
  assert_eq "unknown logical name → cwd fallback" \
    "$(pwd)/foo.md" "$got"
  rm -f "$stderr_capture"
  teardown_workspace
}

test_resolve_roadmap_defaults_when_key_missing() {
  echo "test_resolve_roadmap_defaults_when_key_missing:"
  # Workspace-init v0.1 baseline: manifest lacks routing.roadmap.
  # Per SPEC §10.4 forward-compat: default to canonical.
  test_setup_workspace no
  cd "$TMP_AI_WORKSPACE"
  local got
  got="$(sf_resolve_output_path roadmap ROADMAP.md 2>/dev/null)"
  assert_eq "roadmap missing key → defaults to canonical.root/ROADMAP.md" \
    "${TMP_CANONICAL}/ROADMAP.md" "$got"
  teardown_workspace
}

test_local_fallback_mi_resolver_works() {
  echo "test_local_fallback_mi_resolver_works:"
  # workspace-init NOT installed in any candidate path. Reset state so the
  # source-probe runs fresh and lands on the local fallback. Then exercise
  # the resolver via sf_resolve_output_path.
  test_setup_workspace yes
  cd "$TMP_AI_WORKSPACE"
  # Force candidate paths to nonexistent locations.
  export SF_ROUTING_MI_RESOLVER_PATHS="$TMP_DIR/nope-1/manifest.sh:$TMP_DIR/nope-2/manifest.sh"
  unset -f mi_manifest_resolve 2>/dev/null || true
  _SF_ROUTING_RESOLVER_SOURCED=""
  local got
  got="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
  assert_eq "local fallback resolver produces correct path" \
    "${TMP_AI_WORKSPACE}/MASTER-SPEC.md" "$got"
  unset SF_ROUTING_MI_RESOLVER_PATHS
  unset -f mi_manifest_resolve 2>/dev/null || true
  _SF_ROUTING_RESOLVER_SOURCED=""
  teardown_workspace
}

test_sourced_mi_resolver_takes_precedence() {
  echo "test_sourced_mi_resolver_takes_precedence:"
  # Mock workspace-init's lib/manifest.sh at a candidate path. The probe
  # should source it and use that mi_manifest_resolve in preference to
  # the local fallback.
  test_setup_workspace yes
  cd "$TMP_AI_WORKSPACE"
  local mock_dir="$TMP_DIR/mock-workspace-init/lib"
  mkdir -p "$mock_dir"
  local mock_marker="$TMP_DIR/mock-was-sourced.marker"
  # Mock writes a filesystem marker when sourced (env vars set in
  # command-substitution subshells don't propagate to parent — use file).
  cat > "$mock_dir/manifest.sh" <<MOCK
touch "${mock_marker}"
mi_manifest_resolve() {
  local manifest="\$1"
  local var_ref="\$2"  # e.g., "ai_workspace.root"
  local section field
  section="\${var_ref%%.*}"
  field="\${var_ref#*.}"
  jq -r ".\${section}.\${field}" "\$manifest"
}
MOCK
  export SF_ROUTING_MI_RESOLVER_PATHS="$mock_dir/manifest.sh"
  unset -f mi_manifest_resolve 2>/dev/null || true
  rm -f "$mock_marker"
  _SF_ROUTING_RESOLVER_SOURCED=""
  local got
  got="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
  assert_eq "sourced mi_manifest_resolve produces correct path" \
    "${TMP_AI_WORKSPACE}/MASTER-SPEC.md" "$got"
  if [[ -f "$mock_marker" ]]; then
    PASS=$((PASS+1)); echo "  ✓ mock workspace-init manifest.sh was sourced"
  else
    FAIL=$((FAIL+1)); echo "  ✗ mock was NOT sourced; marker file absent"
  fi
  unset SF_ROUTING_MI_RESOLVER_PATHS
  unset -f mi_manifest_resolve 2>/dev/null || true
  _SF_ROUTING_RESOLVER_SOURCED=""
  teardown_workspace
}

test_home_expansion_in_manifest_values() {
  echo "test_home_expansion_in_manifest_values:"
  # Author a manifest where ai_workspace.root contains ${HOME}; verify the
  # local fallback resolver expands it.
  TMP_DIR="$(mktemp -d -t scaffold-onboard-routing-home.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  # Use a subdir of HOME that we'll create + clean up.
  local rel_subdir=".scaffold-onboard-routing-test.XXX"
  local home_subdir; home_subdir="$(mktemp -d "$HOME/${rel_subdir}")"
  TMP_AI_WORKSPACE="$home_subdir"
  TMP_CANONICAL="$TMP_DIR/canonical"
  mkdir -p "$TMP_AI_WORKSPACE/.workspace" "$TMP_CANONICAL"
  TMP_MANIFEST="$TMP_AI_WORKSPACE/.workspace/pairing.json"
  # Build ${HOME}-using manifest. Substring relative to HOME:
  local home_rel="${home_subdir#${HOME}/}"
  cat > "$TMP_MANIFEST" <<EOF
{
  "schema_version": "1.0",
  "topology": "dual-repo",
  "ai_workspace": { "root": "\${HOME}/${home_rel}", "name": "foo-ai" },
  "canonical":    { "root": "${TMP_CANONICAL}", "name": "foo" },
  "routing": { "master_spec": "ai_workspace", "prd": "canonical" }
}
EOF
  # Force LOCAL fallback resolver (not a sourced workspace-init one).
  export SF_ROUTING_MI_RESOLVER_PATHS="$TMP_DIR/nope/manifest.sh"
  unset -f mi_manifest_resolve 2>/dev/null || true
  _SF_ROUTING_RESOLVER_SOURCED=""
  cd "$TMP_AI_WORKSPACE"
  local got
  got="$(sf_resolve_output_path master_spec MASTER-SPEC.md)"
  assert_eq "\${HOME} expansion via local fallback resolver" \
    "${home_subdir}/MASTER-SPEC.md" "$got"
  # Cleanup the home subdir we created.
  rm -rf "$home_subdir"
  unset SF_ROUTING_MI_RESOLVER_PATHS
  unset -f mi_manifest_resolve 2>/dev/null || true
  _SF_ROUTING_RESOLVER_SOURCED=""
  teardown_workspace
}

# ---------- Run all tests ---------------------------------------------------

echo "=== test-manifest-routing.sh ==="
test_discover_manifest_walks_up           # 1
test_discover_manifest_absent             # 2
test_resolve_master_spec_manifest_present # 3
test_resolve_memory_bank_manifest_present # 4
test_resolve_prd_routes_to_canonical      # 5
test_resolve_process_adrs_routes_to_ai_workspace # 6
test_resolve_no_manifest_falls_back_to_cwd       # 7
test_resolve_unknown_name_warns_and_falls_back   # 8
test_resolve_roadmap_defaults_when_key_missing   # 9
test_local_fallback_mi_resolver_works            # 10
test_sourced_mi_resolver_takes_precedence        # 11
test_home_expansion_in_manifest_values           # 12

report_results
