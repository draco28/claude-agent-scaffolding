#!/usr/bin/env bash
# SessionStart housekeeping for architect-critic (Phase F TF.1).
# Per SPEC §9.2 D6: clear stale in_flight markers (>24h old) from state.json.
# Source-aware: SessionStart fires on startup/clear; resume/compact already
# filtered by the matcher in hooks/hooks.json.

set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Source the libs we need.
source "$PLUGIN_ROOT/lib/_helpers.sh"
source "$PLUGIN_ROOT/lib/state.sh"

state_file="$(ac_state_path)"

# No state.json → nothing to do.
[[ -f "$state_file" ]] || exit 0

# Compute cutoff (now - 24h) in ISO8601 UTC. Try BSD `date -v` first, then GNU `date -d`.
if cutoff="$(date -u -v-1d +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)"; then
  :
else
  cutoff="$(date -u -d "-1 day" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)" || exit 0
fi

# Count stale entries before deletion.
stale_count="$(jq --arg cutoff "$cutoff" '[.in_flight[]? | select(.started_at < $cutoff)] | length' "$state_file" 2>/dev/null || echo 0)"

if [[ "$stale_count" -gt 0 ]]; then
  lock_path="$(ac_data_dir)/state.lock"
  ac_lock_acquire "$lock_path" || exit 0
  if ac_guarded_jq_write "$state_file" \
       --arg cutoff "$cutoff" \
       '.in_flight = [.in_flight[]? | select(.started_at >= $cutoff)]' \
       "$state_file"; then
    ac_lock_release "$lock_path"
    echo "[architect-critic] cleared ${stale_count} stale in-flight marker(s) (>24h old)"
  else
    ac_lock_release "$lock_path"
  fi
fi

exit 0
