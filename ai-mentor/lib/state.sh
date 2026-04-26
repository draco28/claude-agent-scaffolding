#!/usr/bin/env bash
# AI Mentor — shared state helpers.
# All functions FAIL OPEN: on any error they return safe defaults so the
# PreToolUse hook never blocks edits due to a bug in the plugin itself.

# State file path resolution (override-friendly for tests).
# Preference order:
#   1. AI_MENTOR_STATE — explicit override (used by tests).
#   2. ${CLAUDE_PLUGIN_DATA}/state.json — canonical plugin-data location set by
#      Claude Code at hook invocation time. Survives plugin updates.
#   3. ~/.claude/ai-mentor/state.json — legacy fallback for contexts where the
#      env var is not set (e.g., sourcing this lib from a plain shell).
if [[ -z "${AI_MENTOR_STATE:-}" ]]; then
  if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    AI_MENTOR_STATE="${CLAUDE_PLUGIN_DATA}/state.json"
  else
    AI_MENTOR_STATE="$HOME/.claude/ai-mentor/state.json"
  fi
fi
AI_MENTOR_DIR="$(dirname "$AI_MENTOR_STATE")"

# Default state JSON.
am_default_state() {
  cat <<'EOF'
{
  "zone": "ambient",
  "submode": null,
  "set_at": null,
  "set_by": null,
  "session_id": null,
  "quiz_level": null
}
EOF
}

# Read the state file. Echoes JSON on stdout. Returns default if file is
# missing or malformed. Never errors.
am_read_state() {
  if [[ ! -r "$AI_MENTOR_STATE" ]]; then
    am_default_state
    return 0
  fi
  if ! jq -e . "$AI_MENTOR_STATE" >/dev/null 2>&1; then
    am_default_state
    return 0
  fi
  cat "$AI_MENTOR_STATE"
}

# Read a single field from state. Usage: am_read_field zone | submode | quiz_level
am_read_field() {
  local field="$1"
  am_read_state | jq -r ".${field} // empty" 2>/dev/null || echo ""
}

# Write the entire state JSON from stdin to the state file (atomic via temp+mv).
am_write_state_stdin() {
  mkdir -p "$AI_MENTOR_DIR" 2>/dev/null || return 0
  local tmp
  tmp="$(mktemp "${AI_MENTOR_STATE}.XXXXXX" 2>/dev/null)" || return 0
  cat > "$tmp"
  if jq -e . "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$AI_MENTOR_STATE" 2>/dev/null || rm -f "$tmp"
  else
    rm -f "$tmp"
  fi
  return 0
}

# Set zone + submode atomically. Usage: am_set_zone <zone> <submode|null> <set_by>
am_set_zone() {
  local zone="${1:-ambient}"
  local submode="${2:-null}"
  local set_by="${3:-skill}"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")"
  am_read_state | jq \
    --arg zone "$zone" \
    --arg submode "$submode" \
    --arg set_by "$set_by" \
    --arg now "$now" \
    '.zone = $zone
     | .submode = (if $submode == "null" then null else $submode end)
     | .set_by = $set_by
     | .set_at = $now' 2>/dev/null | am_write_state_stdin
}

# Set quiz level. Usage: am_set_quiz <1..4|null>
am_set_quiz() {
  local level="${1:-null}"
  am_read_state | jq \
    --arg level "$level" \
    '.quiz_level = (if $level == "null" then null else ($level | tonumber) end)' \
    2>/dev/null | am_write_state_stdin
}

# Reset state to ambient defaults. Used by SessionStart.
am_reset_state() {
  am_default_state | am_write_state_stdin
}

# Read the most recent user message text from the transcript file.
# Echoes the content on stdout (lower-cased for matching), or empty string on
# any error. Never blocks the hook.
# Usage: am_last_user_msg <transcript_path>
am_last_user_msg() {
  local transcript="${1:-}"
  if [[ -z "$transcript" || ! -r "$transcript" ]]; then
    echo ""
    return 0
  fi
  # JSONL: one entry per line. Want the last entry with .type == "user".
  # Different transcript shapes exist; try a few extractors.
  local msg
  msg="$(tac "$transcript" 2>/dev/null \
    | jq -rs 'map(select(.type == "user")) | .[0].message.content
              | (if type == "array" then map(select(.type == "text") | .text) | join(" ")
                 elif type == "string" then .
                 else "" end)' 2>/dev/null \
    || echo "")"
  echo "${msg,,}"  # lowercase for case-insensitive matching
}

# Check whether the last user message contains any of the override phrases
# for /z2-build mode. Returns 0 if override present, 1 otherwise.
# Usage: am_has_build_override <transcript_path>
am_has_build_override() {
  local transcript="${1:-}"
  local msg
  msg="$(am_last_user_msg "$transcript")"
  [[ -z "$msg" ]] && return 1
  # Phrases to match (case-insensitive — msg is already lowercased).
  local phrases=(
    "z1"
    "just write it"
    "just do it"
    "skip to solution"
    "show me"
    "just show me"
    "/locked"
    "/implement"
    "/z1"
  )
  local p
  for p in "${phrases[@]}"; do
    if [[ "$msg" == *"$p"* ]]; then
      return 0
    fi
  done
  return 1
}
