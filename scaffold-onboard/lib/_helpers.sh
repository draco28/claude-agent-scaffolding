#!/usr/bin/env bash
# Shared helpers used by every lib module.
# Phase A: skeleton. Concrete helpers added in Phase B (TB.2).

# Resolve the plugin root from CLAUDE_PLUGIN_ROOT env var, or by walking up
# from this script's location as a fallback (useful in tests).
sf_plugin_root() {
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    echo "$CLAUDE_PLUGIN_ROOT"
    return 0
  fi
  # Fallback: walk up from this file's location to find .claude-plugin/
  local d
  d="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  echo "$d"
}

# Resolve the plugin data directory (writable state).
sf_data_dir() {
  if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    echo "$CLAUDE_PLUGIN_DATA"
    return 0
  fi
  # Fallback for shell-level testing: a temp dir under HOME
  echo "${HOME}/.scaffold-onboard-test-data"
}

# Log levels: info / warn / error. Always to stderr.
sf_log_info() { echo "[scaffold-onboard] $*" >&2; }
sf_log_warn() { echo "[scaffold-onboard:WARN] $*" >&2; }
sf_log_error() { echo "[scaffold-onboard:ERROR] $*" >&2; }
