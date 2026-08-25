#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/manifest.sh"
. "$HERE/../lib/worktree.sh"
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

# --- topology wins regardless of which is nearer, on the SAME walk-up chain ---
# The contract is "topology wins when both exist ANYWHERE on the walk-up", not
# "whichever is closer to $PWD". Two orderings, both must resolve to topology.
mkdir -p "$TMP/mix1/.workspace" "$TMP/mix1/inner/.ossify" "$TMP/mix1/inner/sub"
cat > "$TMP/mix1/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/mix1"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON
cat > "$TMP/mix1/inner/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMP/core"}},"well_known_paths":{}}
JSON
cd "$TMP/mix1/inner/sub"
t_capture oss_topology_discover
t_assert_rc 0 "topology nearer than pairing: discovered"
t_assert_eq "$TMP/mix1/inner/.ossify/topology.json" "$T_OUT" "topology nearer than pairing: topology wins"
cd "$HERE"

mkdir -p "$TMP/mix2/.ossify" "$TMP/mix2/inner/.workspace" "$TMP/mix2/inner/sub"
cat > "$TMP/mix2/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMP/core"}},"well_known_paths":{}}
JSON
cat > "$TMP/mix2/inner/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/mix2/inner"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON
cd "$TMP/mix2/inner/sub"
t_capture oss_topology_discover
t_assert_rc 0 "pairing nearer than topology: discovered"
t_assert_eq "$TMP/mix2/.ossify/topology.json" "$T_OUT" "pairing nearer than topology: topology STILL wins"
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

# --- malformed manifest: found but unparseable must fail LOUD, not silent ---
# Regression guard: at the base commit, a malformed pairing.json (missing
# ai_workspace.root) still printed a diagnostic to stderr. _oss_shape_file must
# not regress that to a silent rc 1 for either source.
mkdir -p "$TMP/badtopo/.ossify"
printf '{not valid json' > "$TMP/badtopo/.ossify/topology.json"
cd "$TMP/badtopo"
t_capture _oss_shape_file
t_assert_rc 1 "malformed topology.json refused"
t_assert_contains "$T_OUT" "could not be parsed" "malformed topology.json: stderr names the parse failure"
cd "$HERE"

mkdir -p "$TMP/badpair/.workspace"
printf '{not valid json' > "$TMP/badpair/.workspace/pairing.json"
cd "$TMP/badpair"
t_capture oss_manifest_state_path
t_assert_rc 1 "malformed pairing.json refused via state_path (the function skills call)"
t_assert_contains "$T_OUT" "could not be parsed" "malformed pairing.json: stderr names the parse failure"
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

# --- grammar is an injection boundary, refused BEFORE any jq read ---
cd "$TMP/ws"   # declares core + ui only
for bad in 'x|hack' '1core' '' 'Core' 'core.js' 'a b'; do
  t_capture _oss_repo_root "$bad"
  t_assert_rc 2 "invalid repo key '$bad' refused at rc 2"
done
t_capture _oss_repo_root ui
t_assert_rc 0 "declared repo resolves"
t_assert_eq "$TMP/ui" "$T_OUT" "ui root"
t_capture _oss_repo_root nosuch
t_assert_rc 2 "undeclared repo refused"
t_assert_contains "$T_OUT" "core, ui" "refusal lists declared repos"
t_capture _oss_repo_root ai_workspace
t_assert_rc 0 "ai_workspace still resolves (reserved)"
t_assert_eq "$TMP/ws" "$T_OUT" "workspace root via reserved key"
cd "$TMP/legacy"
t_capture _oss_repo_root canonical
t_assert_rc 0 "legacy canonical resolves through translation"
t_assert_eq "$TMP/canon" "$T_OUT" "legacy canonical root"
t_capture _oss_repo_root tooling_repo
t_assert_rc 0 "tooling_repo resolves (was refused by the enum)"
cd "$HERE"

# --- token vocabulary: repos tokens, alias, fail-safe unknown ---
cat > "$TMP/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMP/core"},"canonical":{"root":"$TMP/canon"}},"well_known_paths":{"project_state":"\${repos.ui.root}/ps.json"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_state_path
t_assert_rc 1 "unknown repo in a route token is refused (left for the guard)"
t_assert_contains "$T_OUT" "unresolved" "guard names it unresolved"
cat > "$TMP/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMP/core"},"ui":{"root":"$TMP/ui"}},"well_known_paths":{"project_state":"\${repos.core.root}/.ossify/ps.json"}}
JSON
t_capture oss_manifest_state_path
t_assert_rc 0 "repos-token route resolves"
t_assert_eq "$TMP/core/.ossify/ps.json" "$T_OUT" "repos.core.root substituted"
cat > "$TMP/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":"$TMP/core"}},"well_known_paths":{"project_state":"\${canonical.root}/ps.json"}}
JSON
t_capture oss_manifest_state_path
t_assert_rc 1 "canonical alias without a canonical repo is refused"
cat > "$TMP/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"canonical":{"root":"$TMP/canon"}},"well_known_paths":{"project_state":"\${canonical.root}/ps.json"}}
JSON
t_capture oss_manifest_state_path
t_assert_rc 0 "canonical alias resolves when declared"
t_assert_eq "$TMP/canon/ps.json" "$T_OUT" "canonical alias substitutes to the declared canonical root"
# --- review round 1, Finding 3: both spellings must resolve identically for
# a repo literally named canonical - ${canonical.root} is documented as an
# alias, so pin that the two spellings are not just each individually
# resolvable but resolve to the SAME value.
cat > "$TMP/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"canonical":{"root":"$TMP/canon"}},"well_known_paths":{"project_state":"\${repos.canonical.root}/ps.json"}}
JSON
t_capture oss_manifest_state_path
t_assert_rc 0 "repos.canonical.root spelling resolves for a repo literally named canonical"
t_assert_eq "$TMP/canon/ps.json" "$T_OUT" "both spellings resolve to the identical value"
cd "$HERE"

# --- review round 1, Finding 1: a declared-but-empty repo root must NOT
# substitute to the empty string. `${repos.core.root}/ps.json` with an empty
# core root collapses to `/ps.json` - a well-formed, root-anchored path
# manufactured out of an absent value, exactly the trap the ${HOME} comment
# in _oss_manifest_resolve already names and guards against. The token must
# be LEFT IN PLACE so the unresolved-token guard catches it, the same
# substituting-when-present discipline every other substitution in that
# function already follows.
cat > "$TMP/ws/.ossify/topology.json" <<JSON
{"schema_version":1,"repos":{"core":{"root":""}},"well_known_paths":{"project_state":"\${repos.core.root}/ps.json"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_state_path
t_assert_rc 1 "a declared-but-empty repo root leaves its token in place, not substituted to empty"
t_assert_contains "$T_OUT" "unresolved" "guard names it unresolved rather than manufacturing a root-anchored path"
cd "$HERE"

t_summary
