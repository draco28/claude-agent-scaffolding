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

# --- $OSS_STATE_FILE overrides the manifest --------------------------------
# `_oss_resolve_state` gives an exported OSS_STATE_FILE precedence over the
# manifest, and that override is a supported, tested form. A check that reads
# only the manifest path therefore certifies the workspace as switch-ready while
# every ceremony in the session reads and MUTATES another project's state.
cat > "$TMP/ws/.workspace/pairing.json" <<EOF
{"schema_version":"1.0","ai_workspace":{"root":"$TMP/ws"},"canonical":{"root":"$TMP/canon"},"well_known_paths":{}}
EOF
printf '# AGENTS\n\nossify drives this project.\n' > "$TMP/ws/AGENTS.md"
t_capture oss_interop_check
t_assert_rc 0 "control: the workspace passes with no override in play"
export OSS_STATE_FILE="$TMP/elsewhere/state.json"
t_capture oss_interop_check
t_assert_rc 1 "an OSS_STATE_FILE override pointing elsewhere is an interop failure"
t_assert_contains "$T_OUT" "overrides the manifest" "the finding names the override, not a missing path"
t_assert_contains "$T_OUT" "$TMP/elsewhere/state.json" "the finding echoes the path actually in effect"
unset OSS_STATE_FILE
t_capture oss_interop_check
t_assert_rc 0 "unsetting the override restores the pass — the check reads the EFFECTIVE path, not a cached one"

# --- an EQUIVALENT spelling of the override is NOT an override (#150) -------
# `$ws/./.ossify/project-state.json` and `$ws/.ossify/project-state.json` are
# the same file. Compared as raw strings they are not, so the supported override
# made a HEALTHY workspace fail — the check reported that the session was
# driving another project when it was driving this one.
#
# The state file deliberately does NOT exist here. That is the case
# `interop_check` actually meets: `oss_manifest_state_path` documents that the
# file may not exist yet, and a workspace that has never run `oss init` is
# exactly when someone is still wiring up their environment. `oss doctor` never
# sees this case — it returns early on `[ -f "$sf" ]` — so a canonicalizer that
# only normalizes paths that exist fixes doctor's instance and not this class.
[ -e "$TMP/ws/.ossify" ] && { echo "fixture error: .ossify must not exist for this case" >&2; exit 1; }
export OSS_STATE_FILE="$TMP/ws/./.ossify/project-state.json"
t_capture oss_interop_check
t_assert_rc 0 "an OSS_STATE_FILE spelled equivalently to the manifest path is NOT an override, even when the file does not exist yet"
t_assert_contains "$T_OUT" "ok: state_path" "the equivalent spelling reports ok, not a cross-project failure"

# The SAME case once the file exists, so the fix is not silently existence-only.
mkdir -p "$TMP/ws/.ossify"; : > "$TMP/ws/.ossify/project-state.json"
t_capture oss_interop_check
t_assert_rc 0 "the equivalent spelling is still not an override once the state file exists"
rm -rf "$TMP/ws/.ossify"

# CONTROL, adjacent on purpose. Normalizing both sides is a loosening, and the
# failure mode of a loosening is that it stops detecting anything. A genuinely
# different path must still fail, or the override check has been made vacuous
# by its own fix.
# Carries the SAME `/./` the passing case does, so it proves normalization ran
# and still distinguished two files, rather than passing because nothing was
# normalized at all.
export OSS_STATE_FILE="$TMP/ws/./other-project-state.json"
t_capture oss_interop_check
t_assert_rc 1 "control: a DIFFERENT path spelled with the same /./ is still an override — the fix must not make the check vacuous"
t_assert_contains "$T_OUT" "overrides the manifest" "control: the override is still named"

# A TRAILING SLASH IS NOT AN EQUIVALENT SPELLING. It constrains the path to a
# directory, and POSIX enforces it — `jq -e . project-state.json/` fails ENOTDIR.
# So an override spelled that way is a workspace where every ceremony fails to
# read state, and reporting `ok:` for it certifies exactly the condition this
# check exists to catch. Normalizing it away was a regression introduced by the
# #150 fix in this same PR. (Codex P2, round 1.)
export OSS_STATE_FILE="$TMP/ws/.ossify/project-state.json/"
t_capture oss_interop_check
t_assert_rc 1 "a trailing slash on the override is an interop failure — the path names a directory and state reads fail ENOTDIR"
t_assert_contains "$T_OUT" "overrides the manifest" "the trailing-slash override is named as an override"
export OSS_STATE_FILE="$TMP/ws/.ossify/project-state.json/."
t_capture oss_interop_check
t_assert_rc 1 "a trailing /. carries the identical constraint and is likewise a failure"
unset OSS_STATE_FILE

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

# --- a manifest that exists but cannot be read (#157) ----------------------
# Existence was the whole test, so a corrupt manifest printed `ok: manifest` and
# then three or four derived failures about roots and paths that were never
# readable — sending the operator to repair settings that had not been consulted.
# The MISSING-manifest branch at the top of this file already returns after one
# line for exactly this reason; an unreadable manifest earns the same treatment.
printf 'not json at all {{{\n' > "$TMP/ws/.workspace/pairing.json"
t_capture oss_interop_check
t_assert_rc 1 "a corrupt manifest is rc 1"
t_assert_contains "$T_OUT" "fail: manifest" "the unreadable manifest is named as the failure"
t_assert_eq "1" "$(printf '%s\n' "$T_OUT" | wc -l | tr -d ' ')" \
  "a corrupt manifest emits ONE line, not derived failures about values that were never read"

# The finding named a CLASS — "the manifest cannot be read" — and malformed JSON
# is one instance. A syntactically valid non-object parses fine and then fails
# every `jq -r '.ai_workspace.root'` downstream, reproducing the identical
# misleading read-out. Guarding only the parse would fix the reported instance
# and leave the class, which is the defect this repo keeps re-finding.
for bad in '[]' '"a string"' 'null' '42'; do
  printf '%s\n' "$bad" > "$TMP/ws/.workspace/pairing.json"
  t_capture oss_interop_check
  t_assert_rc 1 "a manifest holding $bad is rc 1 — valid JSON is not a readable manifest"
  t_assert_eq "1" "$(printf '%s\n' "$T_OUT" | wc -l | tr -d ' ')" \
    "a manifest holding $bad emits ONE line, same as malformed JSON"
done

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

# The $OSS_STATE_FILE branch, under strict mode. Every assertion for it above
# only SOURCED the libs, where errexit is not in force. That branch is where the
# canonicalization landed — three command substitutions in a row — and under
# `set -euo pipefail` a non-zero from any of them aborts the whole verb instead
# of printing a finding, which reads to the operator as a crash rather than a
# check. This is the gap that has bitten this codebase before: a lib change
# verified only through direct sourcing, shipped into a strict-mode dispatcher.
export OSS_STATE_FILE="$TMP/ws/./.ossify/project-state.json"
t_capture "$OSS" interop_check
t_assert_rc 0 "dispatcher: an equivalently-spelled override is ok under strict mode, not an errexit abort"
t_assert_contains "$T_OUT" "ok: state_path" "dispatcher: the state_path line survives strict mode"
export OSS_STATE_FILE="$TMP/ws/./other-project-state.json"
t_capture "$OSS" interop_check
t_assert_rc 1 "dispatcher: a genuinely different override is still rc 1 under strict mode"
t_assert_contains "$T_OUT" "overrides the manifest" "dispatcher: the override finding survives strict mode"
unset OSS_STATE_FILE
rm -f "$TMP/ws/AGENTS.md"
t_capture "$OSS" interop_check
t_assert_rc 1 "dispatcher: a failing check is rc 1, not a strict-mode abort"

cd /; rm -rf "$TMP"
t_summary
