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

# The `oss manifest_get` VERB was removed in v0.2.0 (zero prose consumers, and
# it bypassed the token substitution every real field needs). The lib function
# it wrapped is load-bearing - `_oss_repo_root` is built on it - so the coverage
# moves here rather than being deleted, and is exercised through the dispatcher
# via `repo_root`, which is the supported way to ask.
cd "$TMP/ws"
t_capture oss_manifest_get '.ai_workspace.root'
t_assert_rc 0 "lib: manifest_get ok"
t_assert_eq "$TMP/ws" "$T_OUT" "lib: manifest_get reads a manifest field"
t_capture oss_manifest_get '.no_such_key'
t_assert_rc 1 "lib: manifest_get rc 1 on a missing/null field"
t_capture "$OSS" repo_root ai_workspace
t_assert_rc 0 "dispatcher: repo_root is the supported way to read a root"
t_assert_eq "$TMP/ws" "$T_OUT" "dispatcher: repo_root resolves ai_workspace through bin/oss"
# The removed verb must be GONE, not merely unused - a stale wrapper would keep
# handing callers unresolved `${ai_workspace.root}` tokens.
t_capture "$OSS" manifest_get '.ai_workspace.root'
t_assert_rc 2 "dispatcher: the removed manifest_get verb is unknown (rc 2)"
cd "$HERE"

# --- Final review M1: when OSS_STATE_FILE overrides a MANIFEST-ROUTED project,
# say so. A stale export left by an unrelated session silently redirects every
# read and write, and nothing in the output named the source. Three properties
# are asserted because each one is separately load-bearing:
#   (a) the notice never touches stdout — `_oss_resolve_state`'s stdout IS the
#       state path, and every `oss get` consumer treats stdout as a value;
#   (b) it names the env var AND the manifest path being overridden;
#   (c) it stays silent when nothing is actually being overridden (the env var
#       agrees with the manifest), so it does not become noise to tune out.
cd "$TMP/ws"
export OSS_STATE_FILE="$TMP/elsewhere/state.json"
t_capture _oss_resolve_state 2>/dev/null
OUT_ONLY="$(_oss_resolve_state 2>/dev/null)"
t_assert_eq "$TMP/elsewhere/state.json" "$OUT_ONLY" "override notice stays OFF stdout (stdout is exactly the path)"
ERR_ONLY="$(_oss_resolve_state 2>&1 >/dev/null)"
t_assert_contains "$ERR_ONLY" "OSS_STATE_FILE" "override notice names the env var as the source"
t_assert_contains "$ERR_ONLY" "$TMP/ws/.ossify/project-state.json" "override notice names the manifest-routed path being overridden"

export OSS_STATE_FILE="$TMP/ws/.ossify/project-state.json"
ERR_AGREE="$(_oss_resolve_state 2>&1 >/dev/null)"
t_assert_eq "" "$ERR_AGREE" "no notice when the env var agrees with the manifest (nothing is being overridden)"
unset OSS_STATE_FILE
cd "$HERE"

# ...and with no manifest anywhere on the walk-up path there is nothing to
# override, so the env branch stays silent there too (this is also what keeps
# the rest of the suite, which runs manifest-less, free of the notice).
cd "$TMP"
export OSS_STATE_FILE="/env/y.json"
ERR_NOMANIFEST="$(_oss_resolve_state 2>&1 >/dev/null)"
t_assert_eq "" "$ERR_NOMANIFEST" "no notice when there is no manifest to override"
unset OSS_STATE_FILE
cd "$HERE"

rm -rf "$TMP"
t_summary
