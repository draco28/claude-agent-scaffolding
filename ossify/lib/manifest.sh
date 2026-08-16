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
# Literal find-and-replace, without bash pattern substitution.
#
# `${s//needle/$repl}` is NOT literal in the replacement half. Under bash 5.2's
# default `patsub_replacement`, an `&` in $repl expands to the whole matched
# text - so a perfectly valid workspace root like `/home/acme&co` turns
# `${ai_workspace.root}/docs/S.md` back into `${ai_workspace.root}...`, and the
# unresolved-token guard downstream then rejects a correctly-configured project.
#
# The obvious fix does not work. Escaping as `${repl//&/\\&}` was MEASURED on
# both: it repairs bash 5.2 and BREAKS bash 3.2, which renders the backslash
# literally (`/home/acme\&co`). macOS ships bash 3.2 and this repo runs on it,
# so an escape-based fix would trade a Linux bug for a mac one. Doing the
# substitution by hand is the only form that is literal on every version.
# (Codex P2, PR #149 round 4.)
_oss_subst_literal() { # $1=haystack $2=needle $3=replacement
  local hay="$1" needle="$2" repl="$3" out="" pre
  [ -n "$needle" ] || { printf '%s' "$hay"; return 0; }
  while :; do
    case "$hay" in
      *"$needle"*)
        pre="${hay%%"$needle"*}"
        out="$out$pre$repl"
        hay="${hay#"$pre$needle"}"
        ;;
      *) out="$out$hay"; break ;;
    esac
  done
  printf '%s' "$out"
}

_oss_manifest_resolve() { # $1=ai-root $2=string
  local ai_root="$1" result="$2" manifest="$1/.workspace/pairing.json" aw cn
  [ -f "$manifest" ] || { echo "oss: manifest not found at $manifest" >&2; return 1; }
  aw="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)" || true
  cn="$(jq -r '.canonical.root // empty' "$manifest" 2>/dev/null)" || true
  [ -n "$aw" ] && result="$(_oss_subst_literal "$result" '${ai_workspace.root}' "$aw")"
  [ -n "$cn" ] && result="$(_oss_subst_literal "$result" '${canonical.root}' "$cn")"
  # Two failure modes, and only substituting-when-present avoids both. Under the
  # dispatcher's `set -u` a bare `$HOME` with HOME unset is a fatal expansion
  # error raised on the REPLACEMENT side, aborting every state-resolving verb
  # before it can return a diagnostic. But substituting `${HOME:-}` is worse:
  # `${HOME}/demo` collapses to `/demo`, a well-formed path that sails past the
  # unresolved-token guard below and lets `oss init` write outside the intended
  # workspace. So substitute only when HOME is actually set, and otherwise LEAVE
  # THE TOKEN IN PLACE for that guard to reject by name.
  [ -n "${HOME:-}" ] && result="$(_oss_subst_literal "$result" '${HOME}' "$HOME")"
  result="$(_oss_subst_literal "$result" '${USER}' "$(_oss_current_user)")"
  echo "$result"
}

# Shared guard for every well-known-path resolver.
#
# The token half was always here. The ABSOLUTE half is new, and it closes a trap
# that hid behind the token guard: `_oss_manifest_resolve` substitutes `${...}`
# tokens but does NOT join a bare relative value onto the AI-workspace root. So
# `.well_known_paths.project_state = "state.json"` came back unchanged, sailed
# past the token check, and then resolved against whatever directory the session
# happened to start in - two agents in two directories driving two different
# files, which is precisely the failure a well-known path exists to prevent.
# (Codex P2, PR #149.)
# rc 0 if $1 holds a COMPLETE `${PLUGIN_DATA:<name>}` token (#165).
#
# The grammar is workspace-init's, copied deliberately rather than approximated:
# `\$\{PLUGIN_DATA:([a-zA-Z0-9_-]+)\}` (workspace-init/lib/manifest.sh). A substring
# glob on the `${PLUGIN_DATA:` prefix alone was the first spelling and it was wrong -
# it also swallowed `${PLUGIN_DATA:}`, an unterminated `${PLUGIN_DATA:foo`, and
# `${PLUGIN_DATA:foo.bar}`. Those are TYPOS, not supported vocabulary, so the
# unsupported-token message made exactly the malformed-vs-unsupported distinction it
# exists to draw, backwards. Anything failing this test falls through to the generic
# unresolved-token arm, which is the correct answer for a typo.
#
# One helper, two call sites (here and `_oss_repo_root`), so the grammar cannot drift
# between the two refusals the way the wording already did.
_oss_is_plugin_data_token() { # $1=value ; rc 0 if it holds a complete PLUGIN_DATA token
  [[ "$1" =~ \$\{PLUGIN_DATA:[a-zA-Z0-9_-]+\} ]]
}

# The PLUGIN_DATA branch is ordered BEFORE the generic token arm on purpose (#165).
# That token is a documented member of workspace-init's shared manifest vocabulary
# which ossify deliberately does not resolve (#152, wontfix). Reported through the
# generic arm it reads as "you typed this wrong", so the obvious next move - checking
# the token against workspace-init's docs, where it IS valid - leads away from the fix.
# Naming it converts a confusing rejection into a documented limit; it does not fork
# the vocabulary.
_oss_manifest_wellknown_guard() { # $1=resolved $2=what $3=source ; rc 0 if usable
  if _oss_is_plugin_data_token "$1"; then
    echo "oss: $2 path uses \${PLUGIN_DATA:...}, which ossify does not resolve - route it with \${ai_workspace.root}, \${canonical.root}, \${HOME}, \${USER}, or an absolute path (from '$3')" >&2
    return 1
  fi
  case "$1" in
    '')      echo "oss: unresolved $2 path: <empty> (from '$3')" >&2; return 1 ;;
    *'${'*)  echo "oss: unresolved $2 path: '$1' (from '$3')" >&2; return 1 ;;
    /*)      return 0 ;;
    *)       echo "oss: $2 path is not absolute: '$1' (from '$3') - a well-known path that depends on the session's cwd is not well-known" >&2; return 1 ;;
  esac
}

# The AI-workspace root, token-substituted. Both resolvers below need exactly
# this and nothing else, and having it once keeps their two copies from drifting.
_oss_manifest_ai_root() { # echoes the substituted ai_workspace.root
  local manifest ai_root
  manifest="$(oss_manifest_discover)" || { echo "oss: $OSS_MANIFEST_REFUSAL" >&2; return 1; }
  ai_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)" || true
  [ -n "$ai_root" ] || { echo "oss: manifest missing ai_workspace.root" >&2; return 1; }
  [ -n "${HOME:-}" ] && ai_root="$(_oss_subst_literal "$ai_root" '${HOME}' "$HOME")"
  ai_root="$(_oss_subst_literal "$ai_root" '${USER}' "$(_oss_current_user)")"
  printf '%s\n' "$ai_root"
}

# Resolve the ossify state-file path. Honors an optional
# .well_known_paths.project_state key (Plan D may add it); else derives by
# convention <ai_workspace.root>/.ossify/project-state.json.
# Echoes the path (the file itself may not exist yet).
oss_manifest_state_path() {
  local manifest ai_root routed dest
  ai_root="$(_oss_manifest_ai_root)" || return 1
  manifest="$(oss_manifest_discover)" || return 1
  routed="$(jq -r '.well_known_paths.project_state // empty' "$manifest" 2>/dev/null)" || true
  if [ -n "$routed" ]; then
    dest="$(_oss_manifest_resolve "$ai_root" "$routed")" || return 1
  else
    dest="$ai_root/.ossify/project-state.json"
  fi
  _oss_manifest_wellknown_guard "$dest" state "${routed:-convention}" || return 1
  echo "$dest"
}

# Resolve the lean MASTER-SPEC path, the same way and from the same manifest.
# `.well_known_paths.master_spec` is the key workspace-init actually writes
# (default `${ai_workspace.root}/docs/MASTER-SPEC.md`), so a resolver that only
# knew the AI-workspace root would miss a customized routed destination and
# report an initialised project as having no spec. `doctor`'s spec-validation
# surface is the consumer. Echoes the path; the file may not exist yet.
oss_manifest_spec_path() {
  local manifest ai_root routed dest
  ai_root="$(_oss_manifest_ai_root)" || return 1
  manifest="$(oss_manifest_discover)" || return 1
  routed="$(jq -r '.well_known_paths.master_spec // empty' "$manifest" 2>/dev/null)" || true
  if [ -n "$routed" ]; then
    dest="$(_oss_manifest_resolve "$ai_root" "$routed")" || return 1
  else
    dest="$ai_root/docs/MASTER-SPEC.md"
  fi
  _oss_manifest_wellknown_guard "$dest" spec "${routed:-convention}" || return 1
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
#
# #171 SETTLED 2026-08-16: the rail stays BLUNT and now says so in its own text —
# the notice names raw-string comparison, so an equivalent spelling reads as the
# rail's known bluntness rather than as real divergence. The alternatives were each
# walked and declined: canonicalization is not coming back (deleted on PR #184 with
# its own do-not-restore note below — path normalization cost this repo four review
# rounds on PR #166 and seven findings across four more rounds on PR #182); `-ef`
# is read-identity and this function's result feeds
# mutating verbs (the exact -ef-on-a-write-target mistake PR #178 paid two P1s for);
# and a refuse-rather-than-warn redesign across all 42 callers would be new
# deterministic gating semantics, which the 2026-08-15 freeze declines. Removing the
# notice entirely was tried on PR #178 and reverted: it is a SAFETY RAIL, not a
# read-out, and docs/conventions/skill-first.md puts "safety rails the agent must
# not argue past" on the deterministic side.
_oss_resolve_state() { # [$1=explicit-path]
  if [ -n "${1:-}" ]; then echo "$1"; return 0; fi
  if [ -n "${OSS_STATE_FILE:-}" ]; then
    local _routed
    _routed="$(oss_manifest_state_path 2>/dev/null)" || _routed=""
    if [ -n "$_routed" ] && [ "$_routed" != "$OSS_STATE_FILE" ]; then
      echo "oss: state path came from \$OSS_STATE_FILE ($OSS_STATE_FILE), overriding the manifest-routed $_routed (paths compared as written; an equivalent spelling of the same file also triggers this notice)" >&2
    fi
    echo "$OSS_STATE_FILE"; return 0
  fi
  oss_manifest_state_path
}

# `_oss_canon_path` was DELETED here (PR #184), closing #151 and #168 without
# either being fixed. It canonicalized a path for identity comparison and had
# exactly two consumers: `oss_interop_check`, which became prose on PR #182, and
# `oss_cmd_doctor`'s repo-vs-state worktree check, which became prose here. With
# both gone it had no callers, so it left with them - function AND its ~21 direct
# test assertions in tests/test-manifest.sh, together.
#
# Do not bring it back. Path normalization has cost this repo four review rounds
# in the bash (PR #166) and seven findings across four more in the prose that
# briefly replaced it (PR #182), and both times the net product value was a path
# normalizer. If you need to compare two paths, prefer a blunt comparison that
# fails SAFE and says what to do about it; see doctor/references/interop-check.md.

oss_cmd_state_path() { oss_manifest_state_path; }   # `oss state_path` for skills/debug
oss_cmd_spec_path()  { oss_manifest_spec_path; }    # `oss spec_path` for doctor's spec surface
