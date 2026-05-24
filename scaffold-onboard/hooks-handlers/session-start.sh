#!/usr/bin/env bash
# SessionStart hook for scaffold-onboard.
# Marker-aware Tier 0 protocol (v0.2, per SPEC §11) + source-aware composition
# refresh (v0.1.0, preserved below). Marker check + write block sits at lines
# 1-15 (post-shebang) per SPEC §11.4 race-window discipline; all other work
# follows AFTER the marker decision.
set -u
_TIER0_T0_NS="$(date +%s%N 2>/dev/null || echo 0)"
TIER0_MARKER="${TMPDIR:-/tmp}/claude-code-tier0-${CLAUDE_SESSION_ID:-default}"
TIER0_EMIT_FULL=1
if [[ -f "$TIER0_MARKER" ]]; then
  _emitting_plugin="$(cat "$TIER0_MARKER" 2>/dev/null || true)"
  [[ "$_emitting_plugin" != "scaffold-onboard" ]] && TIER0_EMIT_FULL=0
else
  printf "scaffold-onboard" > "$TIER0_MARKER" 2>/dev/null || true
fi
if [[ "${SF_TIER0_TIMING_DEBUG:-}" == "1" ]]; then
  _TIER0_T1_NS="$(date +%s%N 2>/dev/null || echo 0)"
  echo "TIER0_TIMING_NS=$((_TIER0_T1_NS - _TIER0_T0_NS))" >&2
fi

# --- Below: v0.1.0 logic preserved (composition refresh + onboarding hint) ---

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

# Detect onboarding-in-progress for the optional minimal hint.
ONBOARDING_HINT=""
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -n "$REPO_ROOT" ]]; then
  STATE_PATH="$(sf_state_path)"
  if [[ -f "$STATE_PATH" ]]; then
    STATUS="$(jq -r '.status // ""' "$STATE_PATH" 2>/dev/null || echo "")"
    PHASE="$(jq -r '.current_phase // ""' "$STATE_PATH" 2>/dev/null || echo "")"
    if [[ "$STATUS" == "in_progress" ]]; then
      ONBOARDING_HINT="scaffold-onboard: onboarding in progress in this repo (phase ${PHASE}/10). Resume via /onboard."
    fi
  fi
fi

# Emit additionalContext JSON.
# - Full Tier 0 (we own it): memory-bank reference + onboarding hint (if any).
# - Minimal hint (another plugin owns Tier 0): onboarding hint only, if any;
#   otherwise emit nothing (preserves v0.1.0 quiet behavior).
if [[ "$TIER0_EMIT_FULL" == "1" ]]; then
  MSG="scaffold-onboard: project memory-bank conventions active. Tier 0 context preloaded; deeper sections branch-loaded per CLAUDE.md."
  if [[ -n "$ONBOARDING_HINT" ]]; then
    MSG="${MSG} ${ONBOARDING_HINT}"
  fi
  printf '{\n  "additionalContext": "%s"\n}\n' "$MSG"
else
  if [[ -n "$ONBOARDING_HINT" ]]; then
    printf '{\n  "additionalContext": "%s"\n}\n' "$ONBOARDING_HINT"
  fi
fi

exit 0
