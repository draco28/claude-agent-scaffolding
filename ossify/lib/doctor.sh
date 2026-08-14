#!/usr/bin/env bash
# oss doctor - state health checks (spec §9.2 + §9.1 doctor entry).

# Read one advisory COUNT, and treat an unreadable field as UNREADABLE rather
# than as zero. The old `jq ... || echo 0` form was survivable only while these
# advisories printed nothing on a zero count: a corrupt `.demo_ledger` produced
# "0" and therefore silence. Once the clean `ok:` arms were added (round 2), the
# identical fallback started printing "ok: ledger - no pending amendments" over
# data it had failed to read - a check ASSERTING cleanliness about a field it
# could not parse, which is worse than the silence it replaced and contradicts
# the `skip:` contract every other check here follows.
#
# A count must also LOOK like a count: `jq -r` exits 0 while echoing `null` for
# a missing field, and `[ null -gt 0 ]` is a syntax error, not a zero.
#
# Every caller's expression opens with `_arr(f)`, which ERRORS unless the field
# is an array. That is not belt-and-braces: `jq`'s `length` is defined for
# almost everything, so `.patch_records | length` on an OBJECT quietly returns
# its key count and on a NUMBER returns its absolute value. Neither is a record
# count, and neither fails - so without the type guard a structurally wrong
# field produces a confident wrong number instead of a `skip:`. (Measured, when
# a test fixture using `{"a":1}` was expected to fail and reported `warn:
# patches - 1` instead.) (Codex P2, PR #149 round 3.)
_OSS_DOCTOR_ARR='def _arr(f): if (f|type) == "array" then f else error("not an array") end;'

# `_oss_canon_path` MOVED to lib/manifest.sh (#150), because it compares the two
# paths `_oss_resolve_state` and `oss_manifest_state_path` produce and both live
# there, and because the interop check needed it without wanting doctor.sh
# sourced.
#
# THAT SECOND REASON IS GONE: the interop check is prose now and its verb was
# removed, so this file holds the only two remaining calls. When `doctor` itself
# converts, `_oss_canon_path` loses its last caller and goes too — see the note
# on the function. It is deliberately NOT moved back here in the meantime; a move
# now would be churn on 81 lines both of us intend to delete.

_oss_doctor_count() { # $1=state-file $2=jq-expr ; echoes the count, rc 1 if unreadable
  local out
  out="$(jq -r "$_OSS_DOCTOR_ARR $2" "$1" 2>/dev/null)" || return 1
  case "$out" in
    ''|*[!0-9]*) return 1 ;;
  esac
  printf '%s\n' "$out"
}

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
  #
  # Each of these ALWAYS emits a line now. They used to print only their `warn:`
  # arm, so on a healthy project the `ledger`, `fakes` and `patches` checks were
  # simply absent from the read-out - and an omitted check is indistinguishable
  # from one that ran and found nothing, which is the exact invariant the
  # `skip:` arms elsewhere in this function exist to protect. The contract was
  # stated as "one line per check" before it was true of these three.
  # (Codex P2, PR #149 round 2.)
  local pend quar fexp
  if pend="$(_oss_doctor_count "$sf" '[_arr(.demo_ledger)[] | select(((.pending_amendments // []) | length) > 0)] | length')" \
     && quar="$(_oss_doctor_count "$sf" '[_arr(.demo_ledger)[] | select(.status == "quarantined")] | length')"; then
    [ "$pend" -gt 0 ] && echo "warn: ledger - $pend demo line(s) carry a pending amendment awaiting a spine close ('oss ledger_unplan <line-id> <spine>' to drop one)"
    [ "$quar" -gt 0 ] && echo "warn: ledger - $quar quarantined line(s); each must be fixed or retired by the next release close"
    # The ledger owns TWO counters, so its clean line is emitted once, only when
    # BOTH are zero - otherwise a project with a quarantine but no pending
    # amendment would print a warning and a clean line about the same check.
    { [ "$pend" -eq 0 ] && [ "$quar" -eq 0 ]; } \
      && echo "ok: ledger - no pending amendments, no quarantined lines"
  else
    echo "skip: ledger - unavailable (.demo_ledger could not be read as a countable list)"
  fi
  if fexp="$(_oss_doctor_count "$sf" '[_arr(.fakes)[] | select(.status == "active" or .status == "renewed")] | length')"; then
    if [ "$fexp" -gt 0 ]; then
      echo "warn: fakes - $fexp outstanding fake(s) carrying a replacement trigger and expiry release"
    else
      echo "ok: fakes - none outstanding"
    fi
  else
    echo "skip: fakes - unavailable (.fakes could not be read as a countable list)"
  fi

  # §6.1 operator visibility: the fourth thing that rots silently — out-of-spine
  # patch-lane records. A patch is self-declared and unchecked until the next
  # spine close's cumulative demo re-validates the product; doctor must surface
  # the count so an operator can audit accumulated drift (spec §6.1 patch lane:
  # "self-declared, doctor-visible").
  local pat
  if pat="$(_oss_doctor_count "$sf" '_arr(.patch_records) | length')"; then
    if [ "$pat" -gt 0 ]; then
      echo "warn: patches - $pat out-of-spine patch record(s) since the last spine close"
    else
      echo "ok: patches - none since the last spine close"
    fi
  else
    echo "skip: patches - unavailable (.patch_records could not be read as a countable list)"
  fi

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
  # The check compares a repo found via `$PWD`'s manifest against work items in
  # the state file THIS RUN was given - and those are not always the same
  # project. `oss doctor <explicit-state>` (a supported, tested form) or a stale
  # exported $OSS_STATE_FILE can point at project B while $PWD discovers project
  # A's manifest, in which case A's directories would be judged against B's work
  # items and reported as orphaned or claimed on no evidence at all. Every OTHER
  # check here reads only `$sf`, so this association problem is unique to this
  # one. Refuse to guess: unless the inspected state IS the manifest-routed
  # state, skip and say why. (Codex P2, PR #149.)
  # Gated on `rc` — i.e. on schema, replay and shape all being green — and NOT
  # merely on the state being parseable JSON. A live state that parses but has
  # drifted from its base and journal still has a corrupt `.work_items`: a
  # removed work item whose id-named directory survives reads as an orphan, so
  # doctor would print a deletion-flavoured warning about a worktree that
  # `oss state_restore` is about to reclaim. The parse guard inside
  # `worktree_orphans` catches malformed JSON and is the wrong instrument for
  # this; replay is the check that knows. Same precedent as `skip: replay`
  # above, one gate further along. (Codex P2, PR #149 round 2.)
  # Both paths are CANONICALIZED before comparison. A raw string compare drops
  # the check on paths that name the same file in different spellings - the
  # supported `oss doctor .ossify/project-state.json` relative form, or any
  # absolute spelling carrying a symlink or `..` - and losing orphan detection
  # on an otherwise healthy run is a silent false negative, the failure mode
  # this whole function is built to avoid. (Codex P2, PR #149 round 4.)
  # ONE LINE PER REPO KEY, never one line for `canonical` alone. The selector
  # has been repo-parameterized and `target_repo`-scoped since PR #149, but this
  # call site passed `canonical` literally - so a project that configures
  # `private_core` got a clean `ok: worktrees - none orphaned` read-out produced
  # WITHOUT the private root ever being opened. That is not a missing feature,
  # it is a false assurance in the one surface the public/private boundary
  # exists to protect: private work accumulating under a root that no ceremony
  # cleans and no check reads. (Issue #156, deferred from PR #149.)
  #
  # An unconfigured key still costs a LINE. Silence is what made the original
  # bug invisible, and dropping a repo from the read-out is indistinguishable
  # from reporting it clean; `skip:` says "not looked at" out loud, which is the
  # same contract every other unavailable check here already follows.
  local orph mstate key
  mstate="$(oss_manifest_state_path 2>/dev/null)" || mstate=""
  mstate="$(_oss_canon_path "$mstate")"
  sf="$(_oss_canon_path "$sf")"
  if [ "$rc" -ne 0 ]; then
    echo "skip: worktrees - skipped (state health is not green; fix the fail: line above before trusting a repo-vs-state comparison)"
  elif [ -z "$mstate" ] || [ "$mstate" != "$sf" ]; then
    echo "skip: worktrees - skipped (the inspected state is not this directory's manifest-routed state, so a repo-vs-state comparison would cross projects)"
  else
    # The key list is `_oss_repo_root`'s enum, and it is a SECOND copy of it -
    # deliberately, because deriving it would mean a new lib verb for a fact
    # that is three words long. `test-worktree.sh` (12) asserts the two copies
    # agree, so a fourth repo key cannot be added to one and forgotten in the
    # other without turning the suite red.
    # --- REPO-KEY LOOP (drift-guarded: test-worktree.sh (12b)) ---
    for key in canonical ai_workspace private_core; do
      # Called from an `if` CONDITION so a nonzero rc lands in the else arm
      # instead of tripping errexit - the loop body is not covered by the
      # suspension the surrounding `if` gives its own condition.
      if orph="$(oss_worktree_orphans "$key" "$sf" 2>/dev/null)"; then
        if [ -n "$orph" ]; then
          # The remedy is PINNED to the inspected state, not just to the repo
          # key. `_oss_resolve_state` puts `$OSS_STATE_FILE` ahead of the
          # manifest route (manifest.sh:183-190), so a bare
          # `oss worktree_orphans <key>` run by an operator with that variable
          # exported inspects a DIFFERENT project and prints nothing - directly
          # after a line promising it names the directories just found.
          # (Codex P2, PR #160 round 2.)
          #
          # SHELL-QUOTED, not just wrapped in `"`. Pinning the state made
          # "runnable as printed" part of this line's contract, and double
          # quotes do not deliver that: a `$` expands, backticks and `$(...)`
          # execute, and an embedded `"` ends the quoting outright - so an
          # operator copying the line could select a different state file or run
          # something the line never displayed. `printf %q` exists for exactly
          # this and is a bash builtin, so it costs no new lib verb.
          # (Codex P2, PR #160 round 3.)
          echo "warn: worktrees($key) - $(printf '%s\n' "$orph" | wc -l | tr -d ' ') orphaned worktree dir(s) under ${key}'s .worktrees/ claimed by no work item; 'oss worktree_orphans $key $(printf '%q' "$sf")' names them"
        else
          echo "ok: worktrees($key) - none orphaned"
        fi
      else
        # The causes are collapsed on purpose. `_oss_repo_root` returns rc 2 for
        # all three repo-side ones and the state-side one is shared by every
        # key, so splitting them would print the SAME state complaint three
        # times while telling the operator nothing the remedy differs on.
        #
        # BOTH FAMILIES MUST BE NAMED. The selector returns nonzero for
        # state-side failures too - unparseable JSON, a non-array `.work_items`,
        # a record that is not an object, a record whose claim fields are not
        # strings (#155) - and round 2 dropped that half while making the
        # repo-side causes more precise. A skip listing only repo-side causes
        # sends an operator to debug a healthy manifest and root while the state
        # that actually stopped the check goes unnamed, which is the same
        # misdirection-by-omission this whole surface exists to avoid. (Codex
        # P2, PR #160 round 3, on a round 2 regression.)
        #
        # "read or traversed", both: #162 split the two permissions apart. The
        # root now fails on TRAVERSAL (`-x`) and `.worktrees` on READ, so a line
        # naming only reading would misdescribe the commoner of the two.
        echo "skip: worktrees($key) - skipped (not configured in the pairing manifest; or its root does not resolve / does not exist / cannot be read or traversed; or the state's work-item claims could not be inspected)"
      fi
    done
  fi

  return "$rc"
}
