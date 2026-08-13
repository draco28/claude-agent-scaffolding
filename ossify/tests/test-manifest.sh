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

# ---------------------------------------------------------------------------
# The RELATIVE-path trap (Codex P2, PR #149). `_oss_manifest_resolve`
# substitutes `${...}` tokens but never joins a bare relative value onto the
# workspace root, so a relative routed value came back unchanged and sailed past
# the unresolved-token guard — then resolved against whichever directory the
# session happened to start in. Two agents in two directories, two state files.
# ---------------------------------------------------------------------------
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"ps.json"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_state_path
t_assert_rc 1 "a RELATIVE routed state path is refused, not resolved against the cwd"
t_assert_contains "$T_OUT" "not absolute" "the refusal names absoluteness, not tokens"
cd "$HERE"

# ---------------------------------------------------------------------------
# `oss spec_path` — the lean MASTER-SPEC resolver behind doctor's spec surface.
# workspace-init writes `.well_known_paths.master_spec` (default
# `${ai_workspace.root}/docs/MASTER-SPEC.md`), so a resolver that knew only the
# workspace root would miss a customized routed destination and report an
# initialised project as having no spec at all.
# ---------------------------------------------------------------------------
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_spec_path
t_assert_rc 0 "spec path resolved with no routing key"
t_assert_eq "$TMP/ws/docs/MASTER-SPEC.md" "$T_OUT" "convention default matches workspace-init's own default destination"
cd "$HERE"

# A CUSTOMIZED routed destination must win over the convention — the whole point
# of reading the key. If this returned the convention path, the finding Codex
# raised would still be live and this suite would still be green.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"master_spec":"\${ai_workspace.root}/specs/LEAN-SPEC.md"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_spec_path
t_assert_rc 0 "routed spec path resolved"
t_assert_eq "$TMP/ws/specs/LEAN-SPEC.md" "$T_OUT" "the ROUTED destination wins over the convention"
cd "$HERE"

# The same two guards apply, because they are the same guard.
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"master_spec":"\${private_core.root}/S.md"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_spec_path
t_assert_rc 1 "an unresolved token in the spec path is refused"
cd "$HERE"
cat > "$TMP/ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"master_spec":"docs/S.md"}}
JSON
cd "$TMP/ws"
t_capture oss_manifest_spec_path
t_assert_rc 1 "a relative spec path is refused"
t_capture "$OSS" spec_path
t_assert_rc 1 "dispatcher: spec_path propagates the refusal under strict mode"
cd "$HERE"

# ---------------------------------------------------------------------------
# A workspace root containing `&`. `${s//needle/$repl}` is not literal in the
# replacement half: under bash 5.2's default `patsub_replacement` an `&` expands
# to the whole matched text, turning `${ai_workspace.root}/docs/S.md` back into
# an unresolved token and making the guard reject a correctly-configured
# project. The escape-based fix was measured to repair 5.2 and BREAK 3.2 (which
# macOS ships), so the substitution is done by hand instead.
#
# This assertion passes on 3.2 today for the wrong reason — 3.2 has no
# patsub_replacement — but it is the regression guard for the machines that do,
# and it fails on ANY version if the hand-rolled substituter is wrong.
# ---------------------------------------------------------------------------
mkdir -p "$TMP/amp&ws/.workspace"
cat > "$TMP/amp&ws/.workspace/pairing.json" <<JSON
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/amp&ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"master_spec":"\${ai_workspace.root}/docs/MASTER-SPEC.md"}}
JSON
cd "$TMP/amp&ws"
t_capture oss_manifest_spec_path
t_assert_rc 0 "a workspace root containing '&' still resolves"
t_assert_eq "$TMP/amp&ws/docs/MASTER-SPEC.md" "$T_OUT" "the '&' survives verbatim instead of re-expanding to the matched token"
t_capture oss_manifest_state_path
t_assert_eq "$TMP/amp&ws/.ossify/project-state.json" "$T_OUT" "the same holds for the state resolver"
cd "$HERE"

# The substituter itself, directly — every case the token expansion relies on.
t_assert_eq "/a&b/x"  "$(_oss_subst_literal '${R}/x' '${R}' '/a&b')"  "subst: & is literal in the replacement"
t_assert_eq '/a\b/x'  "$(_oss_subst_literal '${R}/x' '${R}' '/a\b')" "subst: a backslash is literal too"
t_assert_eq "aZbZc"   "$(_oss_subst_literal 'a${T}b${T}c' '${T}' 'Z')" "subst: every occurrence is replaced"
t_assert_eq 'a${T}b'  "$(_oss_subst_literal 'a${T}b' '${T}' '${T}')" "subst: a replacement containing the needle does not re-match"
t_assert_eq "plain"   "$(_oss_subst_literal 'plain' '${T}' 'Z')"    "subst: no occurrence leaves the string alone"

# --- _oss_canon_path: identity comparison for paths that may not exist -----
# Moved here from doctor.sh, where it was reachable only by callers that had
# already proved the file exists. `oss_interop_check` compares a path that
# documents itself as possibly-absent, so the existence-only form silently
# skipped normalization in exactly the case it was needed (#150).
CP="$TMP/canon-fixture"
mkdir -p "$CP/dir"

# The pre-existing behaviour, kept: an existing path resolves physically, so
# directory symlinks and `..` are handled by the filesystem rather than by string
# surgery.
: > "$CP/dir/f"
t_assert_eq "$(cd "$CP/dir" && pwd -P)/f" "$(_oss_canon_path "$CP/dir/f")" \
  "canon: an existing path resolves to its physical location"
t_assert_eq "$(_oss_canon_path "$CP/dir/f")" "$(_oss_canon_path "$CP/./dir/f")" \
  "canon: two spellings of an EXISTING file agree"
t_assert_eq "$(_oss_canon_path "$CP/dir/f")" "$(_oss_canon_path "$CP//dir/f")" \
  "canon: a doubled slash on an existing file agrees too"

# The new half. These are the spellings interop_check actually compares.
t_assert_eq "$CP/dir/gone" "$(_oss_canon_path "$CP/./dir/gone")" \
  "canon: /./ is collapsed on a path that does NOT exist"
t_assert_eq "$CP/dir/gone" "$(_oss_canon_path "$CP//dir//gone")" \
  "canon: doubled slashes are collapsed on a path that does NOT exist"
t_assert_eq "$CP/nodir/gone" "$(_oss_canon_path "$CP/./nodir/./gone")" \
  "canon: collapsing does not require the PARENT to exist either"
t_assert_eq "$(_oss_canon_path "$CP/./dir/gone")" "$(_oss_canon_path "$CP/dir/gone")" \
  "canon: the two spellings interop_check compares now agree while the file is absent"

# A DELIBERATE limit, pinned so it is a decision rather than an oversight.
# `a/b/..` is NOT `a` when `b` is a symlink, so resolving `..` textually would
# be wrong in precisely the case canonicalization exists to get right. On a path
# that exists, `cd`+`pwd -P` resolves `..` correctly via the filesystem; on one
# that does not, it is left alone. A future resolver that walks to the deepest
# existing ancestor may legitimately change this line — it must not be changed
# by adding textual `..` collapsing.
t_assert_eq "$CP/dir/../gone" "$(_oss_canon_path "$CP/dir/../gone")" \
  "canon: .. is left UNRESOLVED on a non-existent path — textual .. resolution is wrong under symlinks"
: > "$CP/f2"
t_assert_eq "$(cd "$CP" && pwd -P)/f2" "$(_oss_canon_path "$CP/dir/../f2")" \
  "canon: .. IS resolved when the path exists, by the filesystem rather than by string surgery"

# Unchanged contract: empty in, empty out; a caller comparing two spellings must
# never see two different files collapse to the same empty string.
t_assert_eq "" "$(_oss_canon_path "")" "canon: empty stays empty"

# `/` is the one input the physical half gets wrong on its own: `${d%/}` empties
# and `basename /` is `/`, composing `//`. Unreachable through a state path,
# which is how it survived unnoticed in doctor.sh — but a shared helper that
# returns two unequal spellings of the ROOT is a trap laid for the next caller.
t_assert_eq "/" "$(_oss_canon_path "/")"    "canon: the root is its own canonical form, not //"
t_assert_eq "/" "$(_oss_canon_path "///")"  "canon: a repeated-slash root collapses to the same single /"
t_assert_eq "/" "$(_oss_canon_path "/./")"  "canon: a /./ root collapses to the same single /"

# A TRAILING `/` or `.` is not decoration — it asserts the path names a
# DIRECTORY, and POSIX enforces that: `jq f.json/` fails ENOTDIR and
# `[ -f f.json/ ]` is false. Collapsing it made `interop_check` print
# `ok: state_path` for an $OSS_STATE_FILE that every state read then failed on —
# the check certifying a workspace as switch-ready while the session could not
# read its state at all. (Codex P2, PR #166 round 1.)
#
# Guarded as the CLASS. The review's remedy was "preserve the final EMPTY
# component", which covers `f.json/` and `f.json//` but leaves `f.json/.` —
# whose final component is `.`, not empty — collapsed and failing identically.
t_assert_eq "$CP/dir/gone/" "$(_oss_canon_path "$CP/dir/gone/")" \
  "canon: a trailing / is PRESERVED — it constrains the path to a directory"
t_assert_eq "$CP/dir/gone/" "$(_oss_canon_path "$CP/dir/gone//")" \
  "canon: a doubled trailing slash normalizes to ONE, still preserved"
t_assert_eq "$CP/dir/gone/" "$(_oss_canon_path "$CP/dir/gone/.")" \
  "canon: a trailing /. carries the same directory constraint and is preserved"
t_assert_eq "$CP/dir/gone/" "$(_oss_canon_path "$CP/dir/gone/./")" \
  "canon: a trailing /./ likewise"
t_assert_eq "no" "$([ "$(_oss_canon_path "$CP/dir/gone/")" = "$(_oss_canon_path "$CP/dir/gone")" ] && echo yes || echo no)" \
  "canon: the directory-constrained spelling does NOT compare equal to the bare file path — that equality was the defect"
# And the constraint is about the FINAL component only: a `/./` in the middle is
# still identity-neutral and must still collapse, or the #150 fix is undone.
t_assert_eq "$CP/dir/gone" "$(_oss_canon_path "$CP/./dir/gone")" \
  "canon: a mid-path /./ still collapses — preserving the trailing one must not re-break #150"

rm -rf "$TMP"
t_summary
