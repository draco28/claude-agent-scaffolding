#!/usr/bin/env bash
# scaffold-dev/lib/handoff.sh
# Path composition + lifecycle for session-handoff documents.
# Handoffs live under <ai_workspace>/.workspace/handoffs/.
# Naming: <scope>-<purpose>-<short-id>[-return].md
#   scope:   sprint | slice | mid-slice | bugfix | techdebt
#   purpose: kebab-case
#   id:      4-char hex (sd_handoff_short_id)
#
# Sprint-close cleanup removes both sprint-N-* and vs-N.*-* entries, except
# for the carry-forward exception prefix passed by the caller (typically
# "sprint-N-to-N+1-handoff-").

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi
if ! declare -F sd_manifest_get >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/manifest.sh"
fi

sd_handoff_dir() {
  local ai_workspace
  ai_workspace="$(sd_manifest_get '.ai_workspace.root')" || return 1
  echo "${ai_workspace}/.workspace/handoffs"
}

sd_handoff_ensure_dir() {
  local d
  d="$(sd_handoff_dir)" || return 1
  mkdir -p "$d"
}

# 4-char hex random id. Bash 3.2-portable.
sd_handoff_short_id() {
  printf '%04x' $(( (RANDOM * 257 + RANDOM) & 0xffff ))
}

# sd_handoff_compose_path <scope> <purpose> <id> [<suffix>]
sd_handoff_compose_path() {
  local scope="$1" purpose="$2" id="$3"
  local suffix="${4:-}"
  local dir
  dir="$(sd_handoff_dir)" || return 1
  echo "${dir}/${scope}-${purpose}-${id}${suffix}.md"
}

# sd_handoff_list <prefix> — list handoffs whose basename begins with <prefix>.
sd_handoff_list() {
  local prefix="$1"
  local dir
  dir="$(sd_handoff_dir)" || return 1
  [[ -d "$dir" ]] || return 0
  local f matched=0
  for f in "$dir/${prefix}"*.md; do
    [[ -f "$f" ]] || continue
    echo "$f"
    matched=1
  done
  [[ "$matched" == "1" ]] && return 0 || return 0
}

# sd_handoff_cleanup_sprint <sprint-id> [<carry-forward-prefix>]
# Removes sprint-<N>-* and vs-<N>.*-* files; preserves any file whose
# basename begins with the carry-forward prefix.
sd_handoff_cleanup_sprint() {
  local sprint="$1"
  local carry="${2:-}"
  local dir
  dir="$(sd_handoff_dir)" || return 1
  [[ -d "$dir" ]] || return 0

  local f base
  for f in "$dir/sprint-${sprint}-"*.md "$dir/vs-${sprint}."*-*.md; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    if [[ -n "$carry" && "$base" == "$carry"* ]]; then
      continue
    fi
    rm -f "$f"
  done
  return 0
}
