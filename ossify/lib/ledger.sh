#!/usr/bin/env bash
# Cumulative product demo ledger (spec §3, §6.1) + patch lane records.

oss_ledger_add_auto() { # $1=state $2=spine $3=text $4=command $5=expected
  # The `exit:` operand must be digits-only END TO END. The old glob
  # `exit:[0-9]*` was "exit:" + ONE digit + anything, so plausible authoring
  # slips ("exit:0 (tests green)", "exit:0abc", "exit:0 # green") were accepted
  # here — and the runner's `[ "$rc" -ne "${expected#exit:}" ]` then exits 2 on
  # the non-numeric operand, which the enclosing `if` reads as FALSE: the FAIL
  # branch is skipped and the line counts as passed. The ledger is append-only,
  # so one such line re-reports green at every future close. Same
  # `''|*[!0-9]*` idiom as state.sh's schema-version guard, for the same reason:
  # a value that is not digits makes the later numeric test error rather than
  # compare, and an erroring test reads as "condition not met".
  case "$5" in
    exit:*)
      case "${5#exit:}" in ''|*[!0-9]*)
        echo "oss: expected 'exit:<n>' takes digits only (got '$5')" >&2; return 2;; esac ;;
    contains:?*) ;;
    *) echo "oss: expected must be 'exit:<n>' or 'contains:<str>'" >&2; return 2 ;;
  esac
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg s "$2" --arg t "$3" --arg c "$4" --arg e "$5" --arg ts "$(_oss_now)" \
      '{type:"auto",text:$t,command:$c,expected:$e,source_spine:$s,status:"active",status_reason:null,status_by:null,at:$ts}')" \
    demo
}

oss_ledger_add_user() { # $1=state $2=spine $3=text $4=outcome
  local lower
  lower="$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]')"
  lower="${lower#"${lower%%[![:space:]]*}"}"   # trim leading whitespace so " Open ..." can't evade the ban
  case "$lower" in inspect\ *|view\ *|open\ *)
    echo "oss: inspector phrasing banned in user journey lines (spec §5.3 floor) - phrase as an action the user performs for value" >&2
    return 2;; esac
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg s "$2" --arg t "$3" --arg o "$4" --arg ts "$(_oss_now)" \
      '{type:"user",text:$t,outcome:$o,source_spine:$s,status:"active",status_reason:null,status_by:null,at:$ts}')" \
    demo
}

_oss_ledger_require_line() { # $1=state $2=line-id
  jq -e --arg id "$2" '.demo_ledger[] | select(.id == $id)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown demo line '$2'" >&2; return 7; }
}

# D1: supersede/retire are PLANNING verbs. They record intent and leave the line
# live, so a sibling spine closing before this one still runs the flow, and a
# spine that is replanned or abandoned drops no coverage. `close` applies them.
_oss_ledger_plan_amendment() { # $1=state $2=line-id $3=status $4=by-spine $5=reason
  _oss_ledger_require_line "$1" "$2" || return $?
  # D1 promotes <by-spine> from a provenance STRING into the JOIN KEY that
  # apply_demo_pending matches on. Under the old immediate semantics a typo'd
  # spine was a cosmetic blemish in an audit trail; now it means the amendment
  # is never applied by any close, silently and forever. Validate it like the
  # line id. (demo-amendments.md §3 currently states the opposite - "not
  # validated against known spines, a typo records silently" - and is corrected
  # in Step 6.)
  jq -e --arg s "$4" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$4' - an amendment keyed to a spine that does not exist would never be applied" >&2; return 7; }
  oss_state_mutate "$1" set_demo_line_pending \
    "$(jq -n --arg id "$2" --arg st "$3" --arg by "$4" --arg r "$5" --arg ts "$(_oss_now)" \
      '{id:$id,status:$st,by:$by,reason:$r,at:$ts}')"
}
oss_ledger_supersede() { _oss_ledger_plan_amendment "$1" "$2" superseded "$3" "$4"; }
oss_ledger_retire()    { _oss_ledger_plan_amendment "$1" "$2" retired    "$3" "$4"; }

# The close-time apply. Runs AFTER merge and BEFORE the cumulative demo, so the
# demo measures the amended set against a product where the flow really is gone.
# Same reject-before-mutate shape as _oss_ledger_plan_amendment: this is the
# only mutator this task added that lacked it (F3) - an unknown or typo'd spine
# used to return rc 0 and journal a no-op, so `close` (Task 9) would report
# success while silently applying nothing.
oss_ledger_apply_pending() { # $1=state $2=spine
  jq -e --arg s "$2" '.spines[] | select(.id == $s)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$2' - apply_pending against a spine that does not exist would apply nothing while reporting success" >&2; return 7; }
  oss_state_mutate "$1" apply_demo_pending "$(jq -n --arg s "$2" '{spine:$s}')"
}

# The escape hatch: clears the CALLING spine's planned amendment on a line.
# There is no `reactivate` for an APPLIED one by design - once close has
# applied it the ledger records history.
#
# F1 (2026-07-31): a line now carries a LIST of pending amendments, one per
# spine, so "clear the pending amendment on line d1" is ambiguous - clearing
# every spine's entry indiscriminately is the same silent-coverage-loss
# footgun F1 exists to remove, just moved from set/apply to unplan. The spine
# is therefore REQUIRED, not optional, and is validated the same way the two
# planning verbs validate it: reject-before-mutate, both on an unknown line and
# on a spine that holds no pending amendment on that line (a typo'd spine here
# would otherwise silently no-op and look like it worked).
oss_ledger_unplan() { # $1=state $2=line-id $3=spine
  _oss_ledger_require_line "$1" "$2" || return $?
  jq -e --arg id "$2" --arg s "$3" \
      '.demo_ledger[] | select(.id == $id) | (.pending_amendments // []) | map(select(.by == $s)) | length > 0' \
      "$1" >/dev/null 2>&1 \
    || { echo "oss: spine '$3' holds no pending amendment on line '$2'" >&2; return 7; }
  oss_state_mutate "$1" clear_demo_pending "$(jq -n --arg id "$2" --arg s "$3" '{id:$id,spine:$s}')"
}

# Quarantine is NOT a planned amendment: it is raised at close/doctor time when a
# line actually fails for causes unrelated to any open spine, so it applies at
# once. The release is recorded because §6.1 makes it a parking ticket that
# expires - "fixed or retired by the next release close" needs an anchor.
oss_ledger_quarantine() { # $1=state $2=line-id $3=reason $4=release
  _oss_ledger_require_line "$1" "$2" || return $?
  oss_state_mutate "$1" set_demo_line_status \
    "$(jq -n --arg id "$2" --arg st quarantined --arg by quarantine \
        --arg r "$3" --arg rel "${4:-}" \
      '{id:$id,status:$st,by:$by,reason:$r,release:$rel}')"
}

oss_ledger_active_auto() { jq '[.demo_ledger[] | select(.type == "auto" and .status == "active")]' "$1"; }

oss_ledger_add_patch() { # $1=state $2=commit $3=one-liner
  oss_state_mutate "$1" add_patch_record \
    "$(jq -n --arg c "$2" --arg t "$3" --arg ts "$(_oss_now)" '{commit:$c,text:$t,at:$ts}')"
}
