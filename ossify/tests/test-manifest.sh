#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/manifest.sh"
TMP="$(mktemp -d)"

# Fixture workspace with a pairing manifest at .workspace/pairing.json.
mkdir -p "$TMP/ws/.workspace"
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON

# Discovery + convention default (walk up from a nested dir).
# NOTE: cd directly rather than `( cd DIR; ... )` — t_capture/t_assert_* mutate
# the T_PASS/T_FAIL globals, and a `(...)` subshell forks a child process whose
# mutations never propagate back, which would silently undercount failures
# (verified: with oss_manifest_discover deliberately broken, subshell-wrapped
# assertions still print "FAIL: ..." but the final tally stayed pass=1 fail=0
# and exit 0 — a vacuous-green trap for this very suite). cd back to $HERE
# after each block instead.
mkdir -p "$TMP/ws/sub/deep"
cd "$TMP/ws/sub/deep"
t_capture oss_manifest_discover
t_assert_rc 0 "manifest discovered from nested dir"
t_assert_eq "$TMP/ws/.workspace/pairing.json" "$T_OUT" "discovered path"
t_capture oss_manifest_state_path
t_assert_rc 0 "state path resolved"
t_assert_eq "$TMP/ws/.ossify/project-state.json" "$T_OUT" "convention default state path"
cd "$HERE"

# Honor an explicit well_known_paths.project_state with a resolvable token.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"\${ai_workspace.root}/.ossify/ps.json"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_state_path
t_assert_rc 0 "routed state path resolved"
t_assert_eq "$TMP/ws/.ossify/ps.json" "$T_OUT" "routed path token resolved"
cd "$HERE"

# The silent-literal trap: an UNKNOWN token must be refused, not passed through.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"\${private_core.root}/ps.json"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_state_path
t_assert_rc 1 "unresolved token refused (not passed through as literal)"
t_assert_contains "$T_OUT" "unresolved" "refusal names the unresolved path"
cd "$HERE"

# No manifest anywhere → require refuses with both slash-command tokens.
cd "$TMP"
t_capture oss_manifest_require
t_assert_rc 1 "require refuses when no manifest"
t_assert_contains "$T_OUT" "/init-workspace" "refusal keeps /init-workspace token"
t_assert_contains "$T_OUT" "/pair-workspace" "refusal keeps /pair-workspace token"
cd "$HERE"

# _oss_resolve_state precedence: explicit > OSS_STATE_FILE.
t_capture _oss_resolve_state "/explicit/x.json"
t_assert_eq "/explicit/x.json" "$T_OUT" "explicit path wins"
export OSS_STATE_FILE="/env/y.json"
t_capture _oss_resolve_state
t_assert_eq "/env/y.json" "$T_OUT" "OSS_STATE_FILE used when no explicit path"
unset OSS_STATE_FILE

# Dispatcher-path smoke check: `oss state_path` must work through bin/oss under
# REAL strict mode (set -euo pipefail) — sourced-only tests can miss
# strict-mode bugs that only surface via the dispatcher (repo lesson).
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON
OSS="$HERE/../bin/oss"
cd "$TMP/ws"
t_capture "$OSS" state_path
t_assert_rc 0 "oss state_path works through the dispatcher under strict mode"
t_assert_eq "$TMP/ws/.ossify/project-state.json" "$T_OUT" "dispatcher state_path matches convention default"
cd "$HERE"

rm -rf "$TMP"
t_summary
