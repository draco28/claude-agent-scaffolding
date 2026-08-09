#!/usr/bin/env bash
# Manifest / state-path resolution for ossify. Ports scaffold-dev's manifest
# discovery + resolver, and adds the unresolved-token guard the companion §1
# "silent-literal-path" trap requires. Reads the EXISTING workspace-init
# pairing manifest (<ai-root>/.workspace/pairing.json); never writes it.

OSS_MANIFEST_REFUSAL="ossify requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."

# Resolve the effective ${USER} value without ever propagating a failed `id`
# call into a caller's `set -e` context: this function's own exit status is
# always 0 (the trailing printf), so embedding it in a substitution is safe.
_oss_current_user() {
  local u="${USER:-}"
  if [ -z "$u" ]; then
    u="$(id -un 2>/dev/null)" || true
  fi
  printf '%s' "$u"
}

# Walk up from $PWD to find .workspace/pairing.json. Echoes the abs path; rc 1.
oss_manifest_discover() {
  local dir="$PWD"
  while [ "$dir" != "/" ] && [ -n "$dir" ]; do
    if [ -f "$dir/.workspace/pairing.json" ]; then
      echo "$dir/.workspace/pairing.json"; return 0
    fi
    dir="$(dirname "$dir")" || return 1
  done
  return 1
}

# Read a jq expression from the discovered manifest. rc 1 if no manifest / null.
oss_manifest_get() { # $1=jq-expr
  local expr="$1" manifest out
  manifest="$(oss_manifest_discover)" || { echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1; }
  out="$(jq -r "${expr} // empty" "$manifest" 2>/dev/null)" || true
  [ -n "$out" ] || return 1
  echo "$out"
}

# Refuse to proceed when no manifest is on the walk-up path (skills call early).
oss_manifest_require() {
  oss_manifest_discover >/dev/null 2>&1 && return 0
  echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1
}

# Resolve the two root tokens + ${HOME}/${USER} in a string. Unknown ${x} tokens
# are LEFT IN PLACE (matching the upstream resolvers) - the CALLER detects them.
_oss_manifest_resolve() { # $1=ai-root $2=string
  local ai_root="$1" result="$2" manifest="$1/.workspace/pairing.json" aw cn
  [ -f "$manifest" ] || { echo "oss: manifest not found at $manifest" >&2; return 1; }
  aw="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)" || true
  cn="$(jq -r '.canonical.root // empty' "$manifest" 2>/dev/null)" || true
  [ -n "$aw" ] && result="${result//\$\{ai_workspace.root\}/$aw}"
  [ -n "$cn" ] && result="${result//\$\{canonical.root\}/$cn}"
  # Guard ${HOME:-} (Codex C8): bin/oss runs `set -euo pipefail`, so a bare
  # `$HOME` aborts every manifest-routed state command with "HOME: unbound
  # variable" when OpenCode launches without HOME set (e.g. `env -u HOME oss
  # state_path`). Leaving the literal ${HOME} token in place when unset matches
  # the "unknown tokens left for the caller to detect" contract above; it is
  # caught by the caller's unresolved-${...} refusal rather than aborting here.
  [ -n "${HOME:-}" ] && result="${result//\$\{HOME\}/$HOME}"
  result="${result//\$\{USER\}/$(_oss_current_user)}"
  echo "$result"
}

# Resolve the ossify state-file path. Honors an optional
# .well_known_paths.project_state key (Plan D may add it); else derives by
# convention <ai_workspace.root>/.ossify/project-state.json. Closes the
# silent-literal trap: refuses any path still holding an unresolved ${...}.
# Echoes the path (the file itself may not exist yet).
oss_manifest_state_path() {
  local manifest ai_root routed dest
  manifest="$(oss_manifest_discover)" || { echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1; }
  ai_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)" || true
  [ -n "$ai_root" ] || { echo "oss: manifest missing ai_workspace.root" >&2; return 1; }
  # Guard ${HOME:-} (Codex C8): see _oss_manifest_resolve above.
  [ -n "${HOME:-}" ] && ai_root="${ai_root//\$\{HOME\}/$HOME}"
  ai_root="${ai_root//\$\{USER\}/$(_oss_current_user)}"
  routed="$(jq -r '.well_known_paths.project_state // empty' "$manifest" 2>/dev/null)" || true
  if [ -n "$routed" ]; then
    dest="$(_oss_manifest_resolve "$ai_root" "$routed")" || return 1
  else
    dest="$ai_root/.ossify/project-state.json"
  fi
  case "$dest" in
    ''|*'${'*) echo "oss: unresolved state path: '${dest:-<empty>}' (from '${routed:-convention}')" >&2; return 1 ;;
  esac
  echo "$dest"
}

# Dispatcher glue: resolve the state path for a subcommand.
# Precedence: explicit $1 > $OSS_STATE_FILE (test/override) > manifest-derived.
#
# The env branch names itself on STDERR when it is genuinely overriding a
# manifest-routed project: a stale OSS_STATE_FILE exported by an unrelated
# session silently redirects every read and every write, and nothing else in the
# output says where the path came from.
#
# Two boundaries are deliberate. The notice never goes to stdout — this
# function's stdout IS the state path, and callers consume it as a value. And it
# stays silent when there is no manifest, or when the manifest agrees: nothing is
# being overridden in either case, and a notice on every call is noise the reader
# learns to skip, which is the failure mode this is supposed to prevent.
_oss_resolve_state() { # [$1=explicit-path]
  if [ -n "${1:-}" ]; then echo "$1"; return 0; fi
  if [ -n "${OSS_STATE_FILE:-}" ]; then
    local _routed
    _routed="$(oss_manifest_state_path 2>/dev/null)" || _routed=""
    if [ -n "$_routed" ] && [ "$_routed" != "$OSS_STATE_FILE" ]; then
      echo "oss: state path came from \$OSS_STATE_FILE ($OSS_STATE_FILE), overriding the manifest-routed $_routed" >&2
    fi
    echo "$OSS_STATE_FILE"; return 0
  fi
  oss_manifest_state_path
}

oss_cmd_state_path() { oss_manifest_state_path; }   # `oss state_path` for skills/debug
