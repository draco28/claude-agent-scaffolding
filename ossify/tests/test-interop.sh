#!/usr/bin/env bash
# `oss interop_check` — can Claude Code AND Codex both drive this workspace?
# Check only; nothing here repairs anything, and nothing should.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries worktree interop; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"

# A workspace with no manifest anywhere on the walk-up. Built under the temp
# root rather than under the repo, so the assertion does not depend on where the
# suite was launched from — `oss_manifest_discover` walks up from $PWD.
mkdir -p "$TMP/bare"
cd "$TMP/bare"
t_capture oss_interop_check
t_assert_rc 1 "no manifest is rc 1"
t_assert_contains "$T_OUT" "fail: manifest" "the missing manifest is named"
t_assert_contains "$T_OUT" "/init-workspace" "the remedy names the literal workspace-init command"
t_assert_eq "1" "$(printf '%s\n' "$T_OUT" | wc -l | tr -d ' ')" \
  "with no manifest the check emits ONE line, not four derived failures — every later check reads it"

# --- a fully-configured workspace ------------------------------------------
mkdir -p "$TMP/ws/.workspace" "$TMP/canon"
git -C "$TMP/canon" init -q
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
printf '# AGENTS\n\nThis project uses the ossify lifecycle plugin.\n' > "$TMP/ws/AGENTS.md"
cd "$TMP/ws"
t_capture oss_interop_check
t_assert_rc 0 "a fully-configured workspace is rc 0"
t_assert_contains "$T_OUT" "ok: canonical" "canonical root reported"
t_assert_contains "$T_OUT" "ok: ai_workspace" "ai_workspace root reported"
t_assert_contains "$T_OUT" "ok: agents_md" "AGENTS.md reported"

# An UNROUTED manifest is not a finding. `oss_manifest_state_path` derives
# `<ai_workspace.root>/.ossify/project-state.json` when
# `.well_known_paths.project_state` is absent, and that derived path is
# manifest-absolute — so it resolves identically from any directory and is no
# interop risk at all. The fixture above deliberately ships an EMPTY
# well_known_paths so this arm is exercised rather than assumed.
t_assert_contains "$T_OUT" "ok: state_path" "an unrouted manifest still resolves — absence of the routing key is not a failure"
t_assert_contains "$T_OUT" ".ossify/project-state.json" "the unrouted path is the derived convention, named in full"

# --- AGENTS.md: the check that is specific to Codex ------------------------
rm -f "$TMP/ws/AGENTS.md"
t_capture oss_interop_check
t_assert_rc 1 "a missing AGENTS.md is rc 1"
t_assert_contains "$T_OUT" "no AGENTS.md at" "the absent file is named by path"
t_assert_contains "$T_OUT" "ok: canonical" "one failure does not suppress the checks around it"

printf '# AGENTS\n\nRun the tests before committing.\n' > "$TMP/ws/AGENTS.md"
t_capture oss_interop_check
t_assert_rc 1 "an AGENTS.md that never mentions ossify is rc 1"
t_assert_contains "$T_OUT" "never mentions ossify" "the finding says WHY, not just that a file is wrong"

# Case-insensitive: a heading written "Ossify" must satisfy the check. Without
# tolower() this is the assertion that goes red.
printf '# AGENTS\n\n## Ossify\n\nCeremonies are driven through /start.\n' > "$TMP/ws/AGENTS.md"
t_capture oss_interop_check
t_assert_rc 0 "AGENTS.md naming 'Ossify' with a capital satisfies the check"

# --- a RELATIVE routed state path is an interop failure --------------------
# This is the shape that used to print `ok:`. The resolver substitutes `${...}`
# tokens but never joins a bare relative value onto the workspace root, so
# `relative-state.json` came back unchanged, passed the token guard, and then
# resolved against whichever directory each session started in — two agents,
# two state files, certified as switch-ready.
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"relative-state.json"}}
EOF
t_capture oss_interop_check
t_assert_rc 1 "a RELATIVE routed state path is rc 1"
t_assert_contains "$T_OUT" "fail: state_path" "the relative routed path is a state_path failure"
t_assert_contains "$T_OUT" "absolute" "the message names absoluteness as the requirement"

# An ABSOLUTE routed state path is fine — the guard rejects relativity, not routing.
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{"project_state":"$TMP/ws/custom-state.json"}}
EOF
t_capture oss_interop_check
t_assert_rc 0 "an ABSOLUTE routed state path passes — routing itself is not the problem"
t_assert_contains "$T_OUT" "custom-state.json" "the routed path is echoed, not the convention"

# --- a root that resolves but is not there ---------------------------------
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/nope"},"well_known_paths":{}}
EOF
t_capture oss_interop_check
t_assert_rc 1 "a canonical root pointing at nothing is rc 1"
t_assert_contains "$T_OUT" "resolved root is not a directory" "a resolvable-but-absent root is distinguished from an unresolvable one"

# --- an unresolved token ---------------------------------------------------
cat > "$TMP/ws/.workspace/pairing.json" <<'EOF'
{"schema_version":"1.0","ai_workspace":{"root":"${NOT_A_REAL_VAR}/ws"},"canonical":{"root":"/tmp"},"well_known_paths":{}}
EOF
t_capture oss_interop_check
t_assert_rc 1 "an unresolved \${...} token in a root is rc 1"
t_assert_contains "$T_OUT" "unresolved" "the token failure names itself rather than reporting a missing directory"

# ---------------------------------------------------------------------------
# Dispatcher path. bin/oss runs `set -euo pipefail`; every assertion above only
# sourced the libs. The `for` loop with its `continue` arms and the awk-based
# AGENTS.md probe are both shapes that behave differently under errexit.
# ---------------------------------------------------------------------------
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
t_capture "$OSS" interop_check
t_assert_rc 0 "dispatcher: a good workspace is rc 0 under strict mode"
t_assert_contains "$T_OUT" "ok: agents_md" "dispatcher: the AGENTS.md line reaches the caller"
rm -f "$TMP/ws/AGENTS.md"
t_capture "$OSS" interop_check
t_assert_rc 1 "dispatcher: a failing check is rc 1, not a strict-mode abort"

cd /; rm -rf "$TMP"
t_summary
