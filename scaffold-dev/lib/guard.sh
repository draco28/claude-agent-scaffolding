#!/usr/bin/env bash
# scaffold-dev/lib/guard.sh
# Cross-agent live-state guardrails for volatile scaffold state files.

set -u

_SD_GUARD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  source "$_SD_GUARD_LIB_DIR/_helpers.sh"
fi
if ! declare -F sd_manifest_discover >/dev/null 2>&1; then
  source "$_SD_GUARD_LIB_DIR/manifest.sh"
fi

sd_guard_host_agent() {
  if [[ -n "${SCAFFOLD_HOST_AGENT:-}" ]]; then
    echo "$SCAFFOLD_HOST_AGENT"
  elif [[ -n "${CODEX_HOME:-}" || -n "${CODEX_PLUGIN_ROOT:-}" ]]; then
    echo "codex"
  elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" || -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    echo "claude"
  else
    echo "${SCAFFOLD_HOST_AGENT:-unknown}"
  fi
}

sd_guard_locks_dir() {
  local manifest ai_root
  if ! manifest="$(sd_manifest_discover)"; then
    return 1
  fi
  ai_root="$(sd_jq_get "$manifest" '.ai_workspace.root')"
  [[ -n "$ai_root" ]] || return 1
  echo "$ai_root/.workspace/locks"
}

sd_guard_lock_acquire() {
  local name="$1"
  local locks_dir lock_dir
  if ! locks_dir="$(sd_guard_locks_dir)"; then
    sd_log_error "sd_guard_lock_acquire: no manifest"
    return 1
  fi
  mkdir -p "$locks_dir"
  lock_dir="$locks_dir/${name}.lock"
  if mkdir "$lock_dir" 2>/dev/null; then
    {
      printf 'pid=%s\n' "$$"
      printf 'host=%s\n' "$(sd_guard_host_agent)"
      printf 'created_at=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$lock_dir/owner"
    echo "$lock_dir"
    return 0
  fi
  sd_log_error "live-state lock already held: $lock_dir ($(cat "$lock_dir/owner" 2>/dev/null | tr '\n' ' ' || echo unknown))"
  return 1
}

sd_guard_lock_release() {
  local lock_dir="$1"
  [[ -n "$lock_dir" && -d "$lock_dir" ]] && rmdir "$lock_dir" 2>/dev/null || rm -rf "$lock_dir"
}

sd_guard_provenance_comment() {
  local surface="$1"
  printf '<!-- sd:provenance surface=%s host=%s pid=%s updated_at=%s -->\n' \
    "$surface" "$(sd_guard_host_agent)" "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
