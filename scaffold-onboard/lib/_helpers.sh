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

# Resolve the plugin data directory (writable state). This is the install-level
# data root; project session state is scoped further by sf_project_data_dir.
#
# Resolution order:
#   1. $CLAUDE_PLUGIN_DATA if set — the host runtime's canonical signal.
#   2. Derive the canonical path from $PLUGIN_ROOT / $CLAUDE_PLUGIN_ROOT when
#      it matches the Claude Code cache layout
#      (~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/) — recreates
#      the same `~/.claude/plugins/data/<plugin>-<marketplace>/` path the host
#      runtime would have produced. Works around upstream issue
#      anthropics/claude-code#48230 where CLAUDE_PLUGIN_DATA isn't exported
#      to Bash tool subprocesses.
#   3. Codex plugin cache layout, when installed through Codex.
#   4. Last resort: $HOME/.claude/plugins/data/scaffold-onboard-local/ —
#      DIFFERENT from the host-runtime path so a misconfigured environment
#      doesn't silently masquerade as a real install.
#
# NEVER falls back to the old "~/.scaffold-onboard-test-data/" path that
# caused cross-project state contamination per the v0.x.1 friction-log
# Issue #3 (a 14-day-old stale state file from a different project
# triggered a false "resume" mode at session start).
sf_data_dir() {
  if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    echo "$CLAUDE_PLUGIN_DATA"
    return 0
  fi
  if [[ -n "${CODEX_PLUGIN_DATA:-}" ]]; then
    echo "$CODEX_PLUGIN_DATA"
    return 0
  fi

  # Derive from $PLUGIN_ROOT (exported by bin/sf dispatcher) or
  # $CLAUDE_PLUGIN_ROOT (host runtime — usually unset per #48230).
  local root="${PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${CODEX_PLUGIN_ROOT:-}}}"
  if [[ -n "$root" ]]; then
    # Expected cache layout: .../cache/<marketplace>/<plugin>/<version>
    # PLUGIN_ROOT in cache layout is the <version> dir. Walk up:
    #   parent      = <plugin>
    #   grandparent = <marketplace>
    local version_dir="$root"
    local plugin_dir marketplace_dir cache_dir
    plugin_dir="$(basename "$(dirname "$version_dir")")"
    marketplace_dir="$(basename "$(dirname "$(dirname "$version_dir")")")"
    cache_dir="$(basename "$(dirname "$(dirname "$(dirname "$version_dir")")")")"

    # Only trust the derivation when the layout matches `.../cache/.../.../...`.
    # The root's basename should be a version-like string (digits and dots);
    # the great-great-grandparent should be `cache`. Fall through otherwise.
    if [[ "$cache_dir" == "cache" && "$plugin_dir" == "scaffold-onboard" ]]; then
      if [[ "$version_dir" == *"/.codex/plugins/cache/"* || "$version_dir" == *"/.codex/plugins/cache"* ]]; then
        echo "${CODEX_HOME:-$HOME/.codex}/plugins/data/${plugin_dir}-${marketplace_dir}"
      else
        echo "${HOME}/.claude/plugins/data/${plugin_dir}-${marketplace_dir}"
      fi
      return 0
    fi
  fi

  # Last-resort fallback (does NOT collide with the host-runtime canonical
  # path; intentionally named to surface misconfiguration rather than hide it).
  echo "${HOME}/.claude/plugins/data/scaffold-onboard-local"
}

sf_project_identity_root() {
  if [[ -n "${SF_PROJECT_ROOT:-}" ]]; then
    echo "$SF_PROJECT_ROOT"
    return 0
  fi

  local dir
  dir="$(pwd)"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/.workspace/pairing.json" ]]; then
      local ai_root
      ai_root="$(jq -r '.ai_workspace.root // empty' "$dir/.workspace/pairing.json" 2>/dev/null)"
      if [[ -n "$ai_root" && "$ai_root" != "null" ]]; then
        ai_root="${ai_root//\$\{HOME\}/$HOME}"
        ai_root="${ai_root//\$\{USER\}/${USER:-$(id -un 2>/dev/null)}}"
        echo "$ai_root"
        return 0
      fi
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  local git_root
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  if [[ -n "$git_root" ]]; then
    echo "$git_root"
    return 0
  fi

  pwd
}

sf_project_data_dir() {
  if [[ -n "${SF_PROJECT_DATA_DIR:-}" ]]; then
    echo "$SF_PROJECT_DATA_DIR"
    return 0
  fi

  local root base safe checksum
  root="$(sf_project_identity_root)"
  base="$(basename "$root")"
  safe="$(printf '%s' "$base" | tr -cs 'A-Za-z0-9._-' '-' | sed 's/^-*//; s/-*$//')"
  [[ -n "$safe" ]] || safe="project"
  checksum="$(printf '%s' "$root" | cksum | awk '{print $1}')"
  echo "$(sf_data_dir)/projects/${safe}-${checksum}"
}

# Log levels: info / warn / error. Always to stderr.
sf_log_info() { echo "[scaffold-onboard] $*" >&2; }
sf_log_warn() { echo "[scaffold-onboard:WARN] $*" >&2; }
sf_log_error() { echo "[scaffold-onboard:ERROR] $*" >&2; }
