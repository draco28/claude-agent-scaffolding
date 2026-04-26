#!/usr/bin/env bash
# AI Mentor — PreToolUse hook.
# Blocks Edit/Write/NotebookEdit when zone=2, with submode-specific unblock logic.
#
# FAIL-OPEN PRINCIPLE: any error path leads to exit 0 (allow tool). The plugin
# must never brick the user's session due to its own bugs.

set +e  # never let an unhandled error abort the script

# Read all of stdin as the hook payload.
INPUT="$(cat 2>/dev/null)" || INPUT=""

# Source state helpers; if missing, allow.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || exit 0
LIB="${SCRIPT_DIR}/../lib/state.sh"
if [[ ! -r "$LIB" ]]; then
  exit 0
fi
# shellcheck source=../lib/state.sh
source "$LIB" 2>/dev/null || exit 0

# If jq is unavailable, fail open. We need it to read the transcript.
command -v jq >/dev/null 2>&1 || exit 0

# Extract fields from hook input.
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
TRANSCRIPT_PATH="$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)"

# Only enforce on edit-shaped tools. The hooks.json matcher should already
# scope us to these, but double-check defensively.
case "$TOOL_NAME" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

# Read current state.
ZONE="$(am_read_field zone)"
SUBMODE="$(am_read_field submode)"

# Outside Curve 2 → allow.
if [[ "$ZONE" != "2" ]]; then
  exit 0
fi

# Build the deny payload. Stdout JSON instructs Claude Code to block the tool.
deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }' 2>/dev/null || {
    # If jq fails to construct the JSON, fall back to exit 0 (fail open).
    exit 0
  }
  exit 0
}

case "$SUBMODE" in
  build)
    # Fail open if transcript is unreadable — can't check for override phrase.
    if [[ -z "$TRANSCRIPT_PATH" || ! -r "$TRANSCRIPT_PATH" ]]; then
      exit 0
    fi
    if am_has_build_override "$TRANSCRIPT_PATH"; then
      exit 0
    fi
    deny "AI Mentor: Z2-build mode active — you're meant to type this rep yourself. To override for this edit, include one of: 'show me', 'skip to solution', 'just write it', 'z1'. To exit build mode entirely: /z1. To flip to implementation: /locked."
    ;;
  decide)
    # Decide mode always blocks — unblock is /locked (state transition), not transcript parse.
    deny "AI Mentor: Z2-decide mode active — decisions not yet locked. AI is your spotter on the thinking, not the typing. When architecture/decisions are finalized, run /locked (or /implement) to let me implement. To exit decide mode entirely: /z1."
    ;;
  *)
    # zone=2 but submode is null/unknown — allow rather than block on bad state.
    exit 0
    ;;
esac
