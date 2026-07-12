#!/usr/bin/env bash
# oss doctor - state health checks (spec §9.2 + §9.1 doctor entry).

oss_cmd_doctor() { # $1=state-file (optional; default .ossify/project-state.json)
  local sf="${1:-.ossify/project-state.json}" rc=0 out
  [ -f "$sf" ] || { echo "fail: state - not found at $sf"; return 1; }

  # Each check below is called inside an `if ...; then ... else ...; fi` (or
  # an equivalent tested position) so a failing check's nonzero rc is
  # captured into `rc`/an echoed line WITHOUT tripping `errexit` and aborting
  # the remaining checks - that suspension covers the whole invoked function
  # body, not just the top-level call (verified: a function called from an
  # `if` condition keeps `set -e` suspended through its own internal command
  # substitutions too). `rc` only accumulates; we never `return` early on a
  # single check's failure.
  if out="$(oss_state_check_version "$sf" 2>&1)"; then
    echo "ok: schema - v$(jq -r '.schema_version' "$sf")"
  else
    echo "fail: schema - $out"; rc=1
  fi

  if [ -d "$sf.lock" ]; then
    if [ -n "$(find "$sf.lock" -maxdepth 0 -mmin +30 2>/dev/null)" ]; then
      echo "warn: lock - stale lock dir (>30min): rmdir '$sf.lock' if no ceremony is running"
    else
      echo "warn: lock - held (a ceremony may be mid-mutation)"
    fi
  else
    echo "ok: lock - free"
  fi

  if [ "$rc" -eq 0 ]; then
    if out="$(oss_state_replay "$sf" 2>&1)"; then
      echo "ok: replay - $out"
    else
      echo "fail: replay - $out"; rc=1
    fi
  fi

  local key
  for key in releases spines work_items demo_ledger bones mutations; do
    if ! jq -e --arg k "$key" 'has($k)' "$sf" >/dev/null 2>&1; then
      echo "fail: shape - missing key '$key'"; rc=1
    fi
  done
  [ "$rc" -eq 0 ] && echo "ok: shape - all required keys present"
  return "$rc"
}
