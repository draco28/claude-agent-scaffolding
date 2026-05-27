#!/usr/bin/env bash
# scaffold-dev/lib/manifest.sh
# Walk-up discovery + read + cross-plugin variable resolution for the
# workspace-init pairing manifest (.workspace/pairing.json).
#
# Cross-plugin source pattern: prefer workspace-init's own mi_manifest_resolve
# (sourced from plugin cache); fall back to a local minimal resolver covering
# ${ai_workspace.root}, ${canonical.root}, ${HOME}, ${USER}, and
# ${PLUGIN_DATA:<name>}.

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi

# sd_manifest_discover — walk up from $PWD looking for .workspace/pairing.json.
# Echoes the absolute path; returns 1 if not found.
sd_manifest_discover() {
  local dir="$PWD"
  while [[ "$dir" != "/" && -n "$dir" ]]; do
    if [[ -f "$dir/.workspace/pairing.json" ]]; then
      echo "$dir/.workspace/pairing.json"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# sd_manifest_get <jq-path> — read a field from the discovered manifest.
# Returns 1 if no manifest or field missing/null.
sd_manifest_get() {
  local expr="$1"
  local manifest
  if ! manifest="$(sd_manifest_discover)"; then
    sd_log_error "sd_manifest_get: no manifest found (walked up from $PWD)"
    return 1
  fi
  local out
  out="$(sd_jq_get "$manifest" "$expr")"
  if [[ -z "$out" ]]; then
    return 1
  fi
  echo "$out"
}

# sd_manifest_require — refuse to proceed when no manifest is on the walk-up
# path. Skills that need workspace-init pairing call this early.
sd_manifest_require() {
  if ! sd_manifest_discover >/dev/null; then
    sd_log_error "scaffold-dev requires a workspace-init pairing manifest. Run /init-workspace or /pair-workspace first."
    return 1
  fi
  return 0
}

# _sd_manifest_locate_mi — find workspace-init's lib/manifest.sh in the plugin
# cache. Echoes the first match or empty string.
_sd_manifest_locate_mi() {
  local glob_pat="${HOME}/.claude/plugins/cache"
  local cand
  for cand in "$glob_pat"/*/workspace-init/*/lib/manifest.sh; do
    [[ -f "$cand" ]] && { echo "$cand"; return 0; }
  done
  glob_pat="${CODEX_HOME:-$HOME/.codex}/plugins/cache"
  for cand in "$glob_pat"/*/workspace-init/*/lib/manifest.sh; do
    [[ -f "$cand" ]] && { echo "$cand"; return 0; }
  done
  # Also try the in-repo sibling path (development / monorepo usage).
  local sibling
  sibling="$(cd "$_SD_LIB_DIR/../../workspace-init/lib/manifest.sh" 2>/dev/null && pwd)"
  if [[ -f "$_SD_LIB_DIR/../../workspace-init/lib/manifest.sh" ]]; then
    echo "$_SD_LIB_DIR/../../workspace-init/lib/manifest.sh"
    return 0
  fi
  echo ""
  return 1
}

# _sd_manifest_resolve_local <ai-root> <string> — minimal fallback resolver.
# Covers ${ai_workspace.root}, ${canonical.root}, ${HOME}, ${USER}, and
# ${PLUGIN_DATA:<name>}.
_sd_manifest_resolve_local() {
  local ai_root="$1"
  local input="$2"
  local manifest="$ai_root/.workspace/pairing.json"

  if [[ ! -f "$manifest" ]]; then
    sd_log_error "sd_manifest_resolve: manifest not found at $manifest"
    return 1
  fi

  local result="$input"
  local aw_root cn_root
  aw_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)"
  cn_root="$(jq -r '.canonical.root // empty' "$manifest" 2>/dev/null)"
  [[ -n "$aw_root" ]] && result="${result//\$\{ai_workspace.root\}/$aw_root}"
  [[ -n "$cn_root" ]] && result="${result//\$\{canonical.root\}/$cn_root}"

  # ${PLUGIN_DATA:<name>} — resolve to ~/.claude or ~/.codex plugin data.
  local guard=0
  while [[ "$result" =~ \$\{PLUGIN_DATA:([a-zA-Z0-9_-]+)\} ]]; do
    local plugin="${BASH_REMATCH[1]}"
    local data_dir="${HOME}/.claude/plugins/data/${plugin}"
    # Try marketplace-suffixed first if the parent dir exists.
    if [[ -d "${HOME}/.claude/plugins/data" ]]; then
      local cand
      for cand in "${HOME}/.claude/plugins/data/${plugin}"-*; do
        if [[ -d "$cand" ]]; then
          data_dir="$cand"
          break
        fi
      done
    fi
    if [[ "$data_dir" == "${HOME}/.claude/plugins/data/${plugin}" && -d "${CODEX_HOME:-$HOME/.codex}/plugins/data" ]]; then
      for cand in "${CODEX_HOME:-$HOME/.codex}/plugins/data/${plugin}"-*; do
        if [[ -d "$cand" ]]; then
          data_dir="$cand"
          break
        fi
      done
      if [[ "$data_dir" == "${HOME}/.claude/plugins/data/${plugin}" && -d "${CODEX_HOME:-$HOME/.codex}/plugins/data/${plugin}" ]]; then
        data_dir="${CODEX_HOME:-$HOME/.codex}/plugins/data/${plugin}"
      fi
    fi
    result="${result//\$\{PLUGIN_DATA:${plugin}\}/$data_dir}"
    guard=$((guard + 1))
    (( guard > 64 )) && break
  done

  result="${result//\$\{HOME\}/$HOME}"
  local _user="${USER:-$(id -un 2>/dev/null)}"
  result="${result//\$\{USER\}/$_user}"

  echo "$result"
  return 0
}

# sd_manifest_resolve <ai-root> <string-with-vars>
# Delegates to workspace-init's mi_manifest_resolve when available; falls back
# to the local minimal resolver otherwise.
sd_manifest_resolve() {
  local mi_path
  mi_path="$(_sd_manifest_locate_mi)"
  if [[ -n "$mi_path" && -f "$mi_path" ]]; then
    # shellcheck disable=SC1090
    source "$mi_path"
    if declare -F mi_manifest_resolve >/dev/null 2>&1; then
      mi_manifest_resolve "$@"
      return $?
    fi
  fi
  sd_log_warn "workspace-init's manifest.sh not found; using local minimal resolver"
  _sd_manifest_resolve_local "$@"
}
