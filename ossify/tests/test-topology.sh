#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/manifest.sh"
TMP="$(mktemp -d)"

# --- topology discovery wins; pairing still discovered alone ---
mkdir -p "$TMP/ws/.ossify" "$TMP/ws/sub" "$TMP/legacy/.workspace" "$TMP/legacy/sub"
cat > "$TMP/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMP/core"},"ui":{"root":"$TMP/ui"}},"well_known_paths":{}}
JSON
cat > "$TMP/legacy/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/legacy"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON
cd "$TMP/ws/sub"
t_capture oss_topology_discover
t_assert_rc 0 "topology discovered from nested dir"
t_assert_eq "$TMP/ws/.ossify/topology.json" "$T_OUT" "topology path"
cd "$TMP/legacy/sub"
t_capture oss_topology_discover
t_assert_rc 0 "pairing fallback discovered"
t_assert_eq "$TMP/legacy/.workspace/pairing.json" "$T_OUT" "pairing path"
cd "$TMP"
t_capture oss_topology_discover
t_assert_rc 1 "neither file -> rc 1"
cd "$HERE"

# --- the internal shape, from both sources ---
cd "$TMP/ws"
t_capture _oss_shape_file
t_assert_rc 0 "shape resolved from topology"
t_assert_contains "$T_OUT" '"core"' "shape carries core"
t_assert_contains "$T_OUT" '"source":"topology"' "shape names its source"
# workspace is implicit: parent of .ossify/
t_assert_contains "$T_OUT" "\"workspace\":\"$TMP/ws\"" "implicit workspace root"
t_capture oss_manifest_state_path
t_assert_rc 0 "state path via topology"
t_assert_eq "$TMP/ws/.ossify/project-state.json" "$T_OUT" "convention default unchanged"
cd "$TMP/legacy"
t_capture _oss_shape_file
t_assert_contains "$T_OUT" '"canonical"' "pairing translates canonical"
t_assert_contains "$T_OUT" '"source":"pairing"' "shape names pairing"
t_assert_contains "$T_OUT" "\"workspace\":\"$TMP/legacy\"" "pairing workspace from key"
cd "$HERE"

# --- future writer-side roles translate; unknown keys ride along ignored ---
cat > "$TMP/legacy/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/legacy"},"canonical":{"root":"$TMP/canon"},"tooling_repo":{"root":"$TMP/tools"},"routing":{"extra":"ignored"},"during_dev":{"worktrees_dir":"\${canonical.root}/.worktrees"}}
JSON
cd "$TMP/legacy"
t_capture _oss_shape_file
t_assert_contains "$T_OUT" '"tooling_repo"' "tooling_repo becomes a declared repo"
case "$T_OUT" in *'"routing"'*) t_assert_eq "absent" "present" "routing is NOT a repo (no .root)";; *) t_assert_rc 0 "non-root keys are not repos";; esac
cd "$HERE"

# --- refusal: old tokens stay, new remedy added ---
cd "$TMP"
t_capture oss_manifest_require
t_assert_rc 1 "require refuses when no declaration"
t_assert_contains "$T_OUT" "/init-workspace" "refusal keeps /init-workspace token"
t_assert_contains "$T_OUT" "/pair-workspace" "refusal keeps /pair-workspace token"
t_assert_contains "$T_OUT" "/ossify:start" "refusal names /ossify:start"
t_assert_contains "$T_OUT" "/ossify:adopt" "refusal names /ossify:adopt"
cd "$HERE"

t_summary
