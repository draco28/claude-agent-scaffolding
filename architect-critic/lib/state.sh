#!/usr/bin/env bash
# lib/state.sh — state.json CRUD for architect-critic (Phase B, Task TB.1)
# macOS bash 3.2 portable; no declare -A; explicit lock release before each return.

# Returns the absolute path to state.json.
ac_state_path() {
  echo "$(ac_data_dir)/state.json"
}

# Initialise state.json with an empty schema if it does not already exist.
# If file exists (any schema_version), leave it untouched.
ac_state_init() {
  local state_file
  state_file="$(ac_state_path)"
  local data_dir
  data_dir="$(ac_data_dir)"
  if [[ ! -f "$state_file" ]]; then
    mkdir -p "$data_dir"
    printf '%s\n' '{"schema_version":1,"in_flight":[],"recent_runs":[],"principle_promotions":[],"candidate_promotions":[],"declined_candidates":[]}' > "$state_file"
  fi
}

# Emit the raw contents of state.json to stdout.
# Caller is responsible for piping to jq.
ac_state_read() {
  cat "$(ac_state_path)"
}

# Atomically update a single field in state.json.
# Args: <jq_path> <value>
# <jq_path> must be a valid jq left-hand path expression (e.g. ".schema_version").
# <value> is passed as the --argjson value (must be valid JSON or a plain number/string).
# Uses ac_lock_acquire/release around the write transaction.
ac_state_write_field() {
  local jq_path="$1"
  local value="$2"
  local state_file lock_path
  state_file="$(ac_state_path)"
  lock_path="$(ac_data_dir)/state.lock"

  ac_lock_acquire "$lock_path" || return 1
  ac_guarded_jq_write "$state_file" --argjson v "$value" "${jq_path} = \$v" "$state_file"
  local rc=$?
  ac_lock_release "$lock_path"
  return $rc
}

# Append an in_flight marker to state.json.
# Args: <request_id> <depth> <phase_id|null>
# phase_id should be passed as a JSON-compatible value: an integer string or the literal "null".
ac_state_append_in_flight() {
  local request_id="$1"
  local depth="$2"
  local phase_id_raw="$3"
  local state_file lock_path started_at
  state_file="$(ac_state_path)"
  lock_path="$(ac_data_dir)/state.lock"
  started_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")"

  # Determine if phase_id is the literal string "null" or an integer
  local phase_id_json
  if [[ "$phase_id_raw" == "null" ]]; then
    phase_id_json="null"
  else
    phase_id_json="$phase_id_raw"
  fi

  ac_lock_acquire "$lock_path" || return 1
  ac_guarded_jq_write "$state_file" \
    --arg rid "$request_id" \
    --arg dep "$depth" \
    --arg sat "$started_at" \
    --argjson pid "$phase_id_json" \
    '.in_flight += [{"request_id":$rid,"started_at":$sat,"depth":$dep,"phase_id":$pid}]' \
    "$state_file"
  local rc=$?
  ac_lock_release "$lock_path"
  return $rc
}

# Remove an in_flight entry by request_id.
# Args: <request_id>
ac_state_remove_in_flight() {
  local request_id="$1"
  local state_file lock_path
  state_file="$(ac_state_path)"
  lock_path="$(ac_data_dir)/state.lock"

  ac_lock_acquire "$lock_path" || return 1
  ac_guarded_jq_write "$state_file" \
    --arg rid "$request_id" \
    '.in_flight = [.in_flight[] | select(.request_id != $rid)]' \
    "$state_file"
  local rc=$?
  ac_lock_release "$lock_path"
  return $rc
}

# Append a completed run to recent_runs, then trim to the last 20 entries.
# Args: <run_json>  (a valid JSON object matching the recent_runs schema)
ac_state_append_recent_run() {
  local run_json="$1"
  local state_file lock_path
  state_file="$(ac_state_path)"
  lock_path="$(ac_data_dir)/state.lock"

  ac_lock_acquire "$lock_path" || return 1
  ac_guarded_jq_write "$state_file" \
    --argjson run "$run_json" \
    '.recent_runs = ((.recent_runs + [$run]) | if length > 20 then .[-20:] else . end)' \
    "$state_file"
  local rc=$?
  ac_lock_release "$lock_path"
  return $rc
}

# Append a promotion record to principle_promotions.
# Args: <source> <text> <scope>
# source: "manual" | "auto"
# scope:  "user"   | "project"
ac_state_append_promotion() {
  local source="$1"
  local text="$2"
  local scope="$3"
  local state_file lock_path timestamp
  state_file="$(ac_state_path)"
  lock_path="$(ac_data_dir)/state.lock"
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  ac_lock_acquire "$lock_path" || return 1
  ac_guarded_jq_write "$state_file" \
    --arg src "$source" \
    --arg txt "$text" \
    --arg scp "$scope" \
    --arg ts "$timestamp" \
    '.principle_promotions += [{"timestamp":$ts,"source":$src,"text":$txt,"scope":$scp}]' \
    "$state_file"
  local rc=$?
  ac_lock_release "$lock_path"
  return $rc
}

# Append a declined candidate to declined_candidates.
# Args: <text> <suppress_until>
# suppress_until: ISO-8601 timestamp string (e.g. "2026-06-14T00:00:00Z")
ac_state_append_declined() {
  local text="$1"
  local suppress_until="$2"
  local state_file lock_path declined_at
  state_file="$(ac_state_path)"
  lock_path="$(ac_data_dir)/state.lock"
  declined_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  ac_lock_acquire "$lock_path" || return 1
  ac_guarded_jq_write "$state_file" \
    --arg txt "$text" \
    --arg da "$declined_at" \
    --arg su "$suppress_until" \
    '.declined_candidates += [{"text":$txt,"declined_at":$da,"suppress_until":$su}]' \
    "$state_file"
  local rc=$?
  ac_lock_release "$lock_path"
  return $rc
}
