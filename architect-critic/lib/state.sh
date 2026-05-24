#!/usr/bin/env bash
# lib/state.sh — state.json CRUD for architect-critic (schema v2, Phase 3)
# macOS bash 3.2 portable; no declare -A; explicit lock release before each return.
#
# Schema v2 (SPEC §6.1):
#   {
#     "schema_version": 2,
#     "recent_runs": [ {request_id, completed_at, depth, adversaries_used[],
#                       challenge_count, concessions, skill_invoked, elapsed_ms} ],
#     "principle_promotions": [...],
#     "candidate_promotions": [...],
#     "declined_candidates": [...],
#     "auto_promote_suppressions": [ {fingerprint, suppressed_at, expires_at, reason_score} ]
#   }
# v2 changes vs v1: drops the per-request in-flight tracker and per-run USD field;
# adds concessions + skill_invoked to recent_runs; adds auto_promote_suppressions[].

# Returns the absolute path to state.json.
ac_state_path() {
  echo "$(ac_data_dir)/state.json"
}

# Initialise state.json with an empty schema v2 if it does not already exist.
# If file exists (any schema_version), leave it untouched. When the on-disk
# schema_version is higher than what this build knows (2), log info and preserve
# — forward-compatibility tolerance.
ac_state_init() {
  local state_file
  state_file="$(ac_state_path)"
  local data_dir
  data_dir="$(ac_data_dir)"
  if [[ ! -f "$state_file" ]]; then
    mkdir -p "$data_dir"
    printf '%s\n' '{"schema_version":2,"recent_runs":[],"principle_promotions":[],"candidate_promotions":[],"declined_candidates":[],"auto_promote_suppressions":[]}' > "$state_file"
  else
    local on_disk_ver
    on_disk_ver="$(jq -r '.schema_version // 0' "$state_file" 2>/dev/null || echo 0)"
    if [[ "$on_disk_ver" -gt 2 ]] 2>/dev/null; then
      ac_log_info "state.json has future schema_version=${on_disk_ver}; preserving without modification"
    fi
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

# Append a completed run to recent_runs (schema v2), then trim to the last 20 entries.
# Args: <request_id> <depth> <adversaries_used_json> <challenge_count> <concessions> <skill_invoked> <elapsed_ms>
#   adversaries_used_json: a JSON array literal, e.g. '["claude"]' or '["claude","codex"]'
ac_state_append_run() {
  local request_id="$1"
  local depth="$2"
  local adversaries_json="$3"
  local challenge_count="$4"
  local concessions="$5"
  local skill_invoked="$6"
  local elapsed_ms="$7"
  local state_file lock_path completed_at
  state_file="$(ac_state_path)"
  lock_path="$(ac_data_dir)/state.lock"
  completed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  ac_lock_acquire "$lock_path" || return 1
  ac_guarded_jq_write "$state_file" \
    --arg rid "$request_id" \
    --arg cat "$completed_at" \
    --arg dep "$depth" \
    --argjson adv "$adversaries_json" \
    --argjson cc "$challenge_count" \
    --argjson con "$concessions" \
    --arg skl "$skill_invoked" \
    --argjson elm "$elapsed_ms" \
    '.recent_runs = ((.recent_runs + [{
       "request_id": $rid,
       "completed_at": $cat,
       "depth": $dep,
       "adversaries_used": $adv,
       "challenge_count": $cc,
       "concessions": $con,
       "skill_invoked": $skl,
       "elapsed_ms": $elm
     }]) | if length > 20 then .[-20:] else . end)' \
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

# Append an auto-promote suppression entry by fingerprint.
# Args: <fingerprint> <reason_score>
#   fingerprint: opaque string identifying the candidate (caller computes SHA-256)
#   reason_score: integer 4 → 30-day window; 5 → 90-day window
# Uses BSD date arithmetic (date -u -v+30d) for macOS portability.
ac_state_add_suppression() {
  local fingerprint="$1"
  local reason_score="$2"
  local state_file lock_path suppressed_at expires_at days
  state_file="$(ac_state_path)"
  lock_path="$(ac_data_dir)/state.lock"
  suppressed_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  case "$reason_score" in
    5) days=90 ;;
    4) days=30 ;;
    *)
      ac_log_warn "ac_state_add_suppression: reason_score=$reason_score not in {4,5}; defaulting to 30-day window"
      days=30
      ;;
  esac

  # BSD date: parse suppressed_at then add N days. -j = no set, -f = input format.
  expires_at="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$suppressed_at" "-v+${days}d" +"%Y-%m-%dT%H:%M:%SZ")"

  ac_lock_acquire "$lock_path" || return 1
  ac_guarded_jq_write "$state_file" \
    --arg fp "$fingerprint" \
    --arg sa "$suppressed_at" \
    --arg ea "$expires_at" \
    --argjson rs "$reason_score" \
    '.auto_promote_suppressions += [{
       "fingerprint": $fp,
       "suppressed_at": $sa,
       "expires_at": $ea,
       "reason_score": $rs
     }]' \
    "$state_file"
  local rc=$?
  ac_lock_release "$lock_path"
  return $rc
}
