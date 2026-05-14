#!/usr/bin/env bash
# architect-critic lib/outbox.sh
# Writes the response envelope to the outbox per SPEC §6.2.
#
# Functions:
#   ac_outbox_dir()
#   ac_outbox_write <request_id> <consolidated_json> <elapsed_ms> <cost_usd>
#
# macOS-portable: bash 3.2, jq required.

# ac_outbox_dir — returns the outbox directory path
ac_outbox_dir() {
  echo "$(ac_data_dir)/outbox"
}

# ac_outbox_write <request_id> <consolidated_json> <elapsed_ms> <cost_usd>
# Assembles the full response envelope per SPEC §6.2 and atomically writes
# it to $(ac_outbox_dir)/<request_id>.json using ac_guarded_jq_write.
# Returns 0 on success, 1 on failure (invalid JSON or write error).
ac_outbox_write() {
  local request_id="$1"
  local consolidated_json="$2"
  local elapsed_ms="$3"
  local cost_usd="$4"

  local outbox_dir
  outbox_dir="$(ac_outbox_dir)"

  # Ensure outbox directory exists
  mkdir -p "$outbox_dir" || {
    ac_log_error "outbox: failed to create outbox dir: $outbox_dir"
    return 1
  }

  local target="${outbox_dir}/${request_id}.json"

  # Assemble the full response envelope using jq.
  # consolidated_json already contains: {challenges, gaps, divergences, adversaries_used}
  # We add: request_id, elapsed_ms, cost_usd
  # cost_usd is passed through as a number (jq --argjson preserves numeric type).
  ac_guarded_jq_write "$target" \
    --argjson consolidated "$consolidated_json" \
    --arg request_id "$request_id" \
    --argjson elapsed_ms "$elapsed_ms" \
    --argjson cost_usd "$cost_usd" \
    -n \
    '{
      request_id: $request_id,
      adversaries_used: $consolidated.adversaries_used,
      challenges: $consolidated.challenges,
      gaps: $consolidated.gaps,
      divergences: $consolidated.divergences,
      elapsed_ms: $elapsed_ms,
      cost_usd: $cost_usd
    }'
}
