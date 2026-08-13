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
_oss_manifest_wellknown_guard() { # $1=resolved $2=what $3=source ; rc 0 if usable
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

# Canonicalize a path for IDENTITY comparison. Lives here rather than in
# doctor.sh (its original home) because the two paths it exists to compare -
# `_oss_resolve_state` above and `oss_manifest_state_path` - are both in this
# file, and `oss_interop_check` needs it too.
#
# TWO HALVES, and the split is the point (#150).
#
# The LEXICAL half runs always. Collapsing `//` and `/./` cannot change which
# file a path names, symlink or not, so it needs no filesystem and works on a
# path that does not exist yet. That case is not hypothetical: unlike
# `oss_cmd_doctor`, which returns early on `[ -f "$sf" ]` and therefore only
# ever canonicalizes paths that exist, `oss_interop_check` compares a path whose
# own resolver documents that the file may not exist yet. The existence-only
# form skipped normalization in exactly the workspace where someone is still
# wiring up their environment, so `$ws/./.ossify/…` read as another project.
#
# `..` is deliberately NOT collapsed lexically: `a/b/..` is not `a` when `b` is
# a symlink, which is precisely the case canonicalization exists to get right.
# On a path that exists the PHYSICAL half below resolves `..` correctly through
# the filesystem; on one that does not, it is left in place rather than resolved
# wrongly. A future resolver that walks to the deepest existing ancestor may
# improve on this - adding textual `..` collapsing would not.
#
# The PHYSICAL half is the original behaviour, unchanged: `cd` the directory and
# `pwd -P`, which resolves directory symlinks and `..` together. Deliberately not
# `realpath` (absent on stock macOS), and deliberately tolerant - a path whose
# directory cannot be entered comes back lexically normalized rather than empty,
# because the caller is comparing two spellings and an empty string would make
# two DIFFERENT files look identical.
#
# A TRAILING `/` OR `.` IS PRESERVED, and that is not a special case - it is the
# same rule as `lead`, at the other end. `f.json/` does not name the same thing
# as `f.json`: the trailing separator asserts a DIRECTORY and POSIX enforces it,
# so `jq -e . f.json/` fails ENOTDIR and `[ -f f.json/ ]` is false. Collapsing it
# made `oss_interop_check` print `ok: state_path` for an `$OSS_STATE_FILE` that
# every state read then failed on - certifying a workspace as switch-ready while
# the session could not read its state at all, which is precisely the condition
# that check exists to catch. (Codex P2, PR #166 round 1, on this function's own
# first version.)
#
# The constraint is carried by the FINAL component only; a `/./` in the middle is
# identity-neutral and still collapses. And it is keyed on `$NF == "."` as well as
# a trailing slash, because `f.json/.` fails ENOTDIR identically while its final
# component is `.` rather than empty - a rule phrased only about empty components
# would leave that spelling broken.
#
# Consequence worth knowing before writing the next caller: the canonical form now
# distinguishes `x` from `x/`. Both current callers compare FILE paths, where that
# is what you want. For a target that exists AS a directory the physical half below
# still collapses `d/` to `d`, so a directory's canonical form is existence-
# dependent - harmless for identity comparison, since two spellings compared at the
# same moment agree either way, but not something to rediscover.
#
# One awk pass rather than a loop of shell string surgery: rebuilding from the
# `/`-split components makes "drop empty and `.` components, keep the ends" the
# whole rule, and it keeps `&` and backslashes literal (this file has already
# shipped one `&`-in-replacement defect, in `_oss_subst_literal`).
_oss_canon_path() { # $1=path ; echoes the canonical form, or $1 lexically normalized
  local p d b
  [ -n "$1" ] || { printf '%s' ""; return 0; }
  p="$(printf '%s\n' "$1" | awk -F/ '{
    lead  = ($0 ~ /^\//) ? "/" : ""
    trail = ($0 ~ /\/$/ || $NF == ".") ? "/" : ""
    out = ""
    for (i = 1; i <= NF; i++) {
      if ($i == "" || $i == ".") continue
      out = out (out == "" ? "" : "/") $i
    }
    if (out == "") { print (lead == "/") ? "/" : "."; next }
    print lead out trail
  }')"
  # `/` is its own canonical form, and it is the one input the physical half
  # gets wrong: `${d%/}` empties and `basename /` is `/`, so it would compose
  # `//` - two spellings of the root that no longer compare equal to each other.
  # Unreachable through a state path, which is why it survived in doctor.sh; this
  # is a shared helper now and the next caller should not have to know that.
  if [ "$p" = "/" ]; then printf '%s' "/"; return 0; fi
  [ -e "$p" ] || { printf '%s' "$p"; return 0; }
  d="$(cd "$(dirname -- "$p")" 2>/dev/null && pwd -P)" || { printf '%s' "$p"; return 0; }
  b="$(basename -- "$p")"
  printf '%s/%s' "${d%/}" "$b"
}

oss_cmd_state_path() { oss_manifest_state_path; }   # `oss state_path` for skills/debug
oss_cmd_spec_path()  { oss_manifest_spec_path; }    # `oss spec_path` for doctor's spec surface
