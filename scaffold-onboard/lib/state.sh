#!/usr/bin/env bash
# scaffold-onboard/lib/state.sh
# Onboarding state CRUD. State file lives at $(sf_data_dir)/onboarding-state.json.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

sf_state_path() {
  echo "$(sf_data_dir)/onboarding-state.json"
}

sf_state_init() {
  local path
  path="$(sf_state_path)"
  mkdir -p "$(dirname "$path")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat > "$path" <<JSON
{
  "status": "in_progress",
  "current_phase": 1,
  "current_question": null,
  "project_class": null,
  "created_at": "$now",
  "updated_at": "$now",
  "answers": {}
}
JSON
}

# Read a top-level field from the state file. Returns "null" if missing.
sf_state_read_field() {
  local key="$1"
  local path
  path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "null"
    return 0
  fi
  jq -r --arg k "$key" '.[$k] // "null"' "$path"
}

# Write a top-level field atomically: jq writes to tmp, then mv.
# Treats numeric strings as numbers; anything else as a JSON string.
sf_state_write_atomic() {
  local key="$1" value="$2"
  local path
  path="$(sf_state_path)"
  local tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Detect numeric value (integer only)
  if [[ "$value" =~ ^-?[0-9]+$ ]]; then
    jq --arg k "$key" --argjson v "$value" --arg now "$now" \
      '.[$k] = $v | .updated_at = $now' "$path" > "$tmp"
  else
    jq --arg k "$key" --arg v "$value" --arg now "$now" \
      '.[$k] = $v | .updated_at = $now' "$path" > "$tmp"
  fi
  mv "$tmp" "$path"
}

# Write an answer to state.answers["<question_id>"]. value is treated as a
# raw string; jq handles escaping.
sf_state_write_answer() {
  local qid="$1" value="$2"
  local path
  path="$(sf_state_path)"
  local tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg q "$qid" --arg v "$value" --arg now "$now" \
    '.answers[$q] = $v | .updated_at = $now' "$path" > "$tmp"
  mv "$tmp" "$path"
}

# Read state.answers["<question_id>"]. Returns "null" if absent.
sf_state_read_answer() {
  local qid="$1"
  local path
  path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "null"
    return 0
  fi
  jq -r --arg q "$qid" '.answers[$q] // "null"' "$path"
}

sf_state_lock_path() {
  echo "$(sf_data_dir)/onboarding.lock"
}

# Acquire the onboarding lock. Exits 1 if already held.
# Lock contents: PID + iso-timestamp, for diagnostics.
sf_state_lock_acquire() {
  local path
  path="$(sf_state_lock_path)"
  mkdir -p "$(dirname "$path")"
  # Use noclobber redirection for atomic create-or-fail
  if ( set -o noclobber; echo "$$ $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$path" ) 2>/dev/null; then
    return 0
  else
    sf_log_error "onboarding lock already held: $path ($(cat "$path" 2>/dev/null || echo unknown))"
    return 1
  fi
}

sf_state_lock_release() {
  rm -f "$(sf_state_lock_path)"
}
