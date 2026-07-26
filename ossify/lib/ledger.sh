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

_oss_ledger_set_status() { # $1=state $2=line-id $3=status $4=by $5=reason
  jq -e --arg id "$2" '.demo_ledger[] | select(.id == $id)' "$1" >/dev/null 2>&1 \
    || { echo "oss: unknown demo line '$2'" >&2; return 7; }
  oss_state_mutate "$1" set_demo_line_status \
    "$(jq -n --arg id "$2" --arg st "$3" --arg by "$4" --arg r "$5" \
      '{id:$id,status:$st,by:$by,reason:$r}')"
}
oss_ledger_supersede()  { _oss_ledger_set_status "$1" "$2" superseded "$3" "$4"; }
oss_ledger_retire()     { _oss_ledger_set_status "$1" "$2" retired "$3" "$4"; }
oss_ledger_quarantine() { _oss_ledger_set_status "$1" "$2" quarantined "quarantine" "$3"; }

oss_ledger_active_auto() { jq '[.demo_ledger[] | select(.type == "auto" and .status == "active")]' "$1"; }

oss_ledger_add_patch() { # $1=state $2=commit $3=one-liner
  oss_state_mutate "$1" add_patch_record \
    "$(jq -n --arg c "$2" --arg t "$3" --arg ts "$(_oss_now)" '{commit:$c,text:$t,at:$ts}')"
}
