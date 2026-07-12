#!/usr/bin/env bash
# Cumulative product demo ledger (spec §3, §6.1) + patch lane records.

_oss_ledger_next_id() { echo "d$(( $(jq -r '.counters.demo_line' "$1") + 1 ))"; }

oss_ledger_add_auto() { # $1=state $2=spine $3=text $4=command $5=expected
  case "$5" in exit:[0-9]*|contains:?*) ;; *)
    echo "oss: expected must be 'exit:<n>' or 'contains:<str>'" >&2; return 2;; esac
  local id; id="$(_oss_ledger_next_id "$1")"
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg id "$id" --arg s "$2" --arg t "$3" --arg c "$4" --arg e "$5" --arg ts "$(_oss_now)" \
      '{id:$id,type:"auto",text:$t,command:$c,expected:$e,source_spine:$s,status:"active",status_reason:null,status_by:null,at:$ts}')" || return $?
  echo "$id"
}

oss_ledger_add_user() { # $1=state $2=spine $3=text $4=outcome
  local lower
  lower="$(printf '%s' "$3" | tr '[:upper:]' '[:lower:]')"
  lower="${lower#"${lower%%[![:space:]]*}"}"   # trim leading whitespace (spaces/tabs) so " Open ..." can't evade the ban
  case "$lower" in inspect\ *|view\ *|open\ *)
    echo "oss: inspector phrasing banned in user journey lines (spec §5.3 floor) - phrase as an action the user performs for value" >&2
    return 2;; esac
  local id; id="$(_oss_ledger_next_id "$1")"
  oss_state_mutate "$1" add_demo_line \
    "$(jq -n --arg id "$id" --arg s "$2" --arg t "$3" --arg o "$4" --arg ts "$(_oss_now)" \
      '{id:$id,type:"user",text:$t,outcome:$o,source_spine:$s,status:"active",status_reason:null,status_by:null,at:$ts}')" || return $?
  echo "$id"
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
