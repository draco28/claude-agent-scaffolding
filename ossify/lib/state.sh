#!/usr/bin/env bash
# ossify state engine. §9.2 safety commitments: atomic writes, lock file,
# schema_version+migrations, append-only mutations journal.

OSS_STATE_SCHEMA_VERSION=1

_oss_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

oss_state_init() { # $1=state-file $2=project-name
  local sf="$1" name="$2"
  [ -e "$sf" ] && { echo "oss: state already exists: $sf" >&2; return 1; }
  mkdir -p "$(dirname "$sf")"
  jq -n --arg name "$name" --argjson sv "$OSS_STATE_SCHEMA_VERSION" '{
    schema_version:$sv,
    project:{name:$name,posture:null,composition_root:null,overlay_wiring:null},
    counters:{demo_line:0},
    releases:[],spines:[],work_items:[],
    demo_ledger:[],bones:[],risk_gates:[],fakes:[],
    feature_map:[],patch_records:[],class_overrides:[],
    mutations:[]
  }' > "$sf"
  cp "$sf" "$sf.base.json"
}

oss_state_read() { jq -r "$2" "$1"; }

# Pure transform: op+payload applied to state on stdin -> new state on stdout.
# Shared by mutate (live) and replay (Task 4). Every new op lands HERE only.
_oss_apply_op() { # $1=op $2=payload-json
  local op="$1" payload="$2"
  case "$op" in
    set_posture)
      jq --argjson p "$payload" '.project.posture = $p.posture' ;;
    *)
      echo "oss: unknown op '$op'" >&2; return 4 ;;
  esac
}

oss_state_mutate() { # $1=state-file $2=op $3=payload-json
  local sf="$1" op="$2" payload="$3" lock="$1.lock" tmp seq ts
  if ! mkdir "$lock" 2>/dev/null; then
    echo "oss: state locked ($lock exists) - another ceremony is mutating; retry or run 'oss doctor'" >&2
    return 3
  fi
  # shellcheck disable=SC2064
  trap "rmdir '$lock' 2>/dev/null || true" RETURN 2>/dev/null || true
  # Guard every command whose failure would otherwise abort the whole process
  # under the caller's `set -e` (bin/oss) mid-function, before the trap runs
  # (a RETURN trap does not fire on an errexit-triggered hard exit) - the
  # lock must be released here explicitly, not left to the trap alone.
  tmp="$(mktemp "${sf}.tmp.XXXXXX")" || { rmdir "$lock" 2>/dev/null || true; return 4; }
  seq="$(jq '.mutations | length' "$sf" 2>/dev/null)" || { rm -f "$tmp"; rmdir "$lock" 2>/dev/null || true; return 4; }
  ts="$(_oss_now)"
  if ! jq --arg op "$op" --arg ts "$ts" --argjson seq "$seq" --argjson payload "$payload" \
      '.mutations += [{seq:$seq,op:$op,ts:$ts,payload:$payload}]' "$sf" \
      | _oss_apply_op "$op" "$payload" > "$tmp"; then
    rm -f "$tmp"; rmdir "$lock" 2>/dev/null || true; return 4
  fi
  # refuse to install an empty/invalid result (pipeline failure guard)
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"; rmdir "$lock" 2>/dev/null || true
    echo "oss: mutation produced invalid state; aborted (original untouched)" >&2
    return 4
  fi
  mv "$tmp" "$sf" || { rm -f "$tmp"; rmdir "$lock" 2>/dev/null || true; return 4; }
  rmdir "$lock" 2>/dev/null || true
}
