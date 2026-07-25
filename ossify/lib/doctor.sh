#!/usr/bin/env bash
# oss doctor - state health checks (spec §9.2 + §9.1 doctor entry).

oss_cmd_doctor() { # $1=state-file (optional; resolves via manifest/OSS_STATE_FILE when omitted)
  local sf rc=0 out; sf="$(_oss_resolve_state "${1:-}")" || return $?
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

  # Replay depends on a valid schema, so it's gated on the schema check. But
  # "gated out" must still emit ONE line (a skip notice) rather than silently
  # dropping the check - an operator debugging a broken state file needs to
  # see that replay was intentionally not run, not a missing line. `skip:`
  # (like `warn:`) never sets rc.
  if [ "$rc" -eq 0 ]; then
    if out="$(oss_state_replay "$sf" 2>&1)"; then
      echo "ok: replay - $out"
    else
      echo "fail: replay - $out"; rc=1
    fi
  else
    echo "skip: replay - skipped (schema check failed)"
  fi

  # Shape is schema-independent (pure key presence), so it ALWAYS reports:
  # the detection loop runs unconditionally and the positive summary is
  # printed whenever no key was actually missing (tracked by a local flag,
  # NOT by the overall rc - a prior schema/replay failure must not suppress
  # a legitimately-green shape line).
  local key shape_ok=1
  for key in schema_version project counters releases spines work_items demo_ledger bones risk_gates fakes feature_map patch_records class_overrides mutations; do
    if ! jq -e --arg k "$key" 'has($k)' "$sf" >/dev/null 2>&1; then
      echo "fail: shape - missing key '$key'"; rc=1; shape_ok=0
    fi
  done
  [ "$shape_ok" -eq 1 ] && echo "ok: shape - all required keys present"
  return "$rc"
}
