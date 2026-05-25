#!/usr/bin/env bash
# SessionStart hook for scaffold-dev.
# Coordinates Tier 0 marker with scaffold-onboard per SPEC §15.1:
#   * If marker exists and was written by another plugin → emit only a thin
#     scaffold-dev cursor hint (don't re-emit Tier 0).
#   * If marker exists and was written by scaffold-dev → re-emit full Tier 0
#     (re-entrant; treat as first-emitter).
#   * If marker absent → emit full Tier 0 + cursor + write marker as
#     "scaffold-dev".
# Walks up for .workspace/pairing.json; if no manifest is found, emits a stderr
# warning and exits 0 (no-op).

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

_SD_LIB_DIR="$PLUGIN_ROOT/lib"
# shellcheck disable=SC1091
source "$_SD_LIB_DIR/_helpers.sh"
# shellcheck disable=SC1091
source "$_SD_LIB_DIR/manifest.sh"
# shellcheck disable=SC1091
source "$_SD_LIB_DIR/state.sh"

TIER0_MARKER="${TMPDIR:-/tmp}/claude-code-tier0-${CLAUDE_SESSION_ID:-default}"

# Determine emit mode based on marker state.
EMIT_FULL=1
MARKER_OWNER=""
if [[ -f "$TIER0_MARKER" ]]; then
  MARKER_OWNER="$(cat "$TIER0_MARKER" 2>/dev/null || true)"
  if [[ "$MARKER_OWNER" != "scaffold-dev" ]]; then
    EMIT_FULL=0
  fi
fi

# Manifest discovery — required for both cursor and full Tier 0.
if ! sd_manifest_discover >/dev/null 2>&1; then
  echo "[scaffold-dev] not in an AI workspace; manifest discovery skipped" >&2
  exit 0
fi

# Resolve cursor hint (best-effort; missing state file → "unknown").
sprint="$(sd_state_active_sprint 2>/dev/null || echo unknown)"
slice="$(sd_state_active_slice  2>/dev/null || echo unknown)"
[[ -z "$sprint" || "$sprint" == "null" ]] && sprint="unknown"
[[ -z "$slice"  || "$slice"  == "null" ]] && slice="unknown"

if [[ "$EMIT_FULL" == "1" ]]; then
  # Full Tier 0: memory-bank reference (sourced from 00-overview.md per
  # scaffold-onboard convention) + scaffold-dev cursor hint.
  ai_workspace="$(sd_manifest_get .ai_workspace.root 2>/dev/null || echo "")"
  if [[ -n "$ai_workspace" && -f "${ai_workspace}/.claude/memory-bank/00-overview.md" ]]; then
    head -50 "${ai_workspace}/.claude/memory-bank/00-overview.md"
  else
    echo "[scaffold-dev] memory-bank conventions active (00-overview.md not yet authored)"
  fi
  echo "[scaffold-dev] active sprint=${sprint} slice=${slice}"
  # Claim the marker (overwrite ok — we own it or it was absent).
  printf "scaffold-dev" > "$TIER0_MARKER" 2>/dev/null || true
else
  # Another plugin owns Tier 0; emit cursor hint only.
  echo "[scaffold-dev] active sprint=${sprint} slice=${slice}"
fi

exit 0
