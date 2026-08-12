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
  for key in schema_version project counters releases spines work_items demo_ledger bones risk_gates fakes feature_map patch_records class_overrides veto_dispositions close_records mutations; do
    if ! jq -e --arg k "$key" 'has($k)' "$sf" >/dev/null 2>&1; then
      echo "fail: shape - missing key '$key'"; rc=1; shape_ok=0
    fi
  done
  [ "$shape_ok" -eq 1 ] && echo "ok: shape - all required keys present"

  # §6.1 operator visibility: the three things that rot silently.
  local pend quar fexp
  pend="$(jq -r '[.demo_ledger[] | select(((.pending_amendments // []) | length) > 0)] | length' "$sf" 2>/dev/null || echo 0)"
  [ "$pend" -gt 0 ] 2>/dev/null && echo "warn: ledger - $pend demo line(s) carry a pending amendment awaiting a spine close ('oss ledger_unplan <line-id> <spine>' to drop one)"
  quar="$(jq -r '[.demo_ledger[] | select(.status == "quarantined")] | length' "$sf" 2>/dev/null || echo 0)"
  [ "$quar" -gt 0 ] 2>/dev/null && echo "warn: ledger - $quar quarantined line(s); each must be fixed or retired by the next release close"
  fexp="$(jq -r '[.fakes[] | select(.status == "active" or .status == "renewed")] | length' "$sf" 2>/dev/null || echo 0)"
  [ "$fexp" -gt 0 ] 2>/dev/null && echo "warn: fakes - $fexp outstanding fake(s) carrying a replacement trigger and expiry release"

  # §6.1 operator visibility: the fourth thing that rots silently — out-of-spine
  # patch-lane records. A patch is self-declared and unchecked until the next
  # spine close's cumulative demo re-validates the product; doctor must surface
  # the count so an operator can audit accumulated drift (spec §6.1 patch lane:
  # "self-declared, doctor-visible").
  local pat
  pat="$(jq -r '.patch_records | length' "$sf" 2>/dev/null || echo 0)"
  [ "$pat" -gt 0 ] 2>/dev/null && echo "warn: patches - $pat out-of-spine patch record(s) since the last spine close"

  # Repo-vs-state drift (v0.3). Spine close removes worktrees by READING STATE
  # (spine-close.md §10), so a directory state does not know about is cleaned by
  # no ceremony at all: it accumulates in the canonical repo whose cleanliness
  # close then checks, and the first symptom is a close failing for a reason
  # that has nothing to do with the spine being closed.
  #
  # This is the only check here that reads the REPO rather than the state file,
  # which makes it the only one that can be legitimately UNAVAILABLE - without a
  # pairing manifest there is no canonical root to look in. It therefore follows
  # the replay precedent above and emits a `skip:` line rather than nothing: a
  # missing line reads as clean, and making silence impossible is the entire job
  # of this function. `skip:` (like `warn:`) never sets rc.
  local orph
  if orph="$(oss_worktree_orphans canonical "$sf" 2>/dev/null)"; then
    if [ -n "$orph" ]; then
      echo "warn: worktrees - $(printf '%s\n' "$orph" | wc -l | tr -d ' ') orphaned worktree dir(s) under canonical .worktrees/ claimed by no work item; 'oss worktree_orphans canonical' names them"
    else
      echo "ok: worktrees - none orphaned"
    fi
  else
    echo "skip: worktrees - skipped (no resolvable canonical root; needs a pairing manifest)"
  fi

  return "$rc"
}
