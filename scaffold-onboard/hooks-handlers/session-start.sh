#!/usr/bin/env bash
# SessionStart hook for scaffold-onboard.
# Source-aware: refresh composition.json on startup/clear; preserve on resume/compact;
# emit additionalContext if onboarding is in progress in the current repo.

set -u

# Resolve plugin root (Claude Code sets CLAUDE_PLUGIN_ROOT for hooks)
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

source "$PLUGIN_ROOT/lib/_helpers.sh"
source "$PLUGIN_ROOT/lib/state.sh"
source "$PLUGIN_ROOT/lib/compose.sh"

# Read source field from stdin JSON payload, if present
SOURCE=""
if [[ ! -t 0 ]]; then
  PAYLOAD="$(cat 2>/dev/null || true)"
  if [[ -n "$PAYLOAD" ]]; then
    SOURCE="$(echo "$PAYLOAD" | jq -r '.source // ""' 2>/dev/null || echo "")"
  fi
fi

# Refresh composition.json on startup/clear (fresh detection)
case "$SOURCE" in
  ""|"startup"|"clear")
    sf_compose_refresh 2>/dev/null || true
    ;;
  "resume"|"compact")
    # Preserve composition.json; only refresh if it doesn't exist yet
    if [[ ! -f "$(sf_compose_path)" ]]; then
      sf_compose_refresh 2>/dev/null || true
    fi
    ;;
esac

# If onboarding is in progress in the current repo, emit additionalContext
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$REPO_ROOT" ]]; then
  STATE_PATH="$(sf_state_path)"
  if [[ -f "$STATE_PATH" ]]; then
    STATUS="$(jq -r '.status // ""' "$STATE_PATH" 2>/dev/null || echo "")"
    PHASE="$(jq -r '.current_phase // ""' "$STATE_PATH" 2>/dev/null || echo "")"
    if [[ "$STATUS" == "in_progress" ]]; then
      cat <<JSON
{
  "additionalContext": "scaffold-onboard: onboarding in progress in this repo (phase ${PHASE}/10). Resume via /onboard."
}
JSON
    fi
  fi
fi

exit 0
