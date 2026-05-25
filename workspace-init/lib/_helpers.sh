#!/usr/bin/env bash
# lib/_helpers.sh — shared primitives for workspace-init.
# Bash 3.2+ compatible (stock macOS). Requires: jq.
# Source via: source "${WI_LIB_DIR}/_helpers.sh"
#
# Mirrors architect-critic/lib/_helpers.sh structure (ac_* → wi_*) and
# claude-security-audit/lib/helpers.sh realpath-fallback pattern, but does NOT
# use `set -e` — callers do explicit return-code checks.

set -u

# --- Logging (all to stderr, INFO/WARN/ERROR prefixes per spec §4) ---

wi_log_info()  { echo "INFO: $*"  >&2; }
wi_log_warn()  { echo "WARN: $*"  >&2; }
wi_log_error() { echo "ERROR: $*" >&2; }

# --- Path canonicalization (no GNU `realpath` dependency) -----------------
# Resolves symlinks and `..` via `cd -P`. On macOS this expands /tmp →
# /private/tmp, /var → /private/var, etc. — the canonical form.
# For non-existing paths, best-effort: canonicalize parent + append basename.
wi_realpath() {
  local path="$1"
  if [[ -d "$path" ]]; then
    ( cd "$path" 2>/dev/null && pwd -P )
    return 0
  fi
  if [[ -e "$path" ]]; then
    local dir base
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    ( cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd -P)" "$base" )
    return 0
  fi
  # Not yet existing — canonicalize parent if possible.
  local dir base
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  if [[ -d "$dir" ]]; then
    printf '%s/%s\n' "$( cd "$dir" 2>/dev/null && pwd -P )" "$base"
  else
    printf '%s\n' "$path"
  fi
}

# --- File-based locking via `set -o noclobber` ----------------------------
# Mirror of architect-critic's ac_lock_acquire pattern. Retry budget is
# configurable via WI_LOCK_RETRIES (default 5, one second between attempts)
# so tests can fail-fast on a held lock.
wi_lock_acquire() {
  local lock="$1"
  local max="${WI_LOCK_RETRIES:-5}"
  local i=0
  while (( i < max )); do
    if ( set -o noclobber; > "$lock" ) 2>/dev/null; then
      return 0
    fi
    sleep 1
    i=$((i + 1))
  done
  wi_log_warn "could not acquire lock $lock after ${max}s"
  return 1
}

wi_lock_release() {
  # Idempotent: -f swallows "no such file" so re-release is safe.
  rm -f "$1"
  return 0
}

# --- Atomic JSON write via jq ---------------------------------------------
# Usage: wi_guarded_jq_write <file> <jq-program> [extra jq args...]
# Reads <file>, applies <jq-program>, writes to <file>.tmp.$$, mv on success.
# Returns 0 on success, 1 on jq failure (and removes the tmp file).
wi_guarded_jq_write() {
  local file="$1"; shift
  local jq_program="$1"; shift
  local tmp="${file}.tmp.$$"
  if jq "$jq_program" "$@" "$file" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$file"
    return 0
  fi
  rm -f "$tmp"
  wi_log_error "jq failed during write to $file"
  return 1
}

# --- Init-log entry append ------------------------------------------------
# Format: OP\tPATH[\tDETAIL]\n
# Appends one line; creates parent directory if missing.
wi_log_op() {
  local logfile="$1"
  local op="$2"
  local path="$3"
  local detail="${4:-}"
  local dir; dir="$(dirname "$logfile")"
  [[ -d "$dir" ]] || mkdir -p "$dir"
  if [[ -n "$detail" ]]; then
    printf '%s\t%s\t%s\n' "$op" "$path" "$detail" >> "$logfile"
  else
    printf '%s\t%s\n' "$op" "$path" >> "$logfile"
  fi
}

# --- Template render with ${VAR} substitution -----------------------------
# Args: wi_render_template <tmpl> <out> [VAR1=val1 VAR2=val2 ...]
# Substitutes literal `${VAR}` placeholders in the template body. Pure-bash
# parameter expansion — no shell metachar evaluation, so values can safely
# contain `$`, backticks, etc.
wi_render_template() {
  local tmpl="$1"
  local out="$2"
  shift 2
  if [[ ! -f "$tmpl" ]]; then
    wi_log_error "template not found: $tmpl"
    return 1
  fi
  local content
  content="$(cat "$tmpl")"
  local pair var val
  while (( $# > 0 )); do
    pair="$1"; shift
    var="${pair%%=*}"
    val="${pair#*=}"
    # Replace every literal ${VAR} with val. Bash 3.2-safe pattern expansion.
    content="${content//\$\{${var}\}/${val}}"
  done
  local outdir; outdir="$(dirname "$out")"
  [[ -d "$outdir" ]] || mkdir -p "$outdir"
  printf '%s\n' "$content" > "$out"
}
