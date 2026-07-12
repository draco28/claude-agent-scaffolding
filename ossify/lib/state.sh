#!/usr/bin/env bash
# ossify state engine. §9.2 safety commitments: atomic writes, lock file,
# schema_version+migrations, append-only mutations journal.

OSS_STATE_SCHEMA_VERSION=1

_oss_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

oss_state_init() { # $1=state-file $2=project-name
  local sf="$1" name="$2" tmp
  [ -e "$sf" ] && { echo "oss: state already exists: $sf" >&2; return 1; }
  mkdir -p "$(dirname "$sf")" || return 1
  # §9.2: every state write goes temp+mv. A crash/disk-full mid-write must not
  # leave a truncated file that the "refuse if exists" guard then treats as a
  # valid existing state, permanently wedging the project.
  tmp="$(mktemp "${sf}.tmp.XXXXXX")" || return 1
  if ! jq -n --arg name "$name" --argjson sv "$OSS_STATE_SCHEMA_VERSION" '{
    schema_version:$sv,
    project:{name:$name,posture:null,composition_root:null,overlay_wiring:null},
    counters:{demo_line:0},
    releases:[],spines:[],work_items:[],
    demo_ledger:[],bones:[],risk_gates:[],fakes:[],
    feature_map:[],patch_records:[],class_overrides:[],
    mutations:[]
  }' > "$tmp"; then
    rm -f "$tmp"; return 1
  fi
  # never install an unparseable/empty skeleton
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"; echo "oss: init produced invalid state; aborted" >&2; return 1
  fi
  # base snapshot: temp+mv too (from the validated skeleton, before it moves)
  local btmp
  btmp="$(mktemp "${sf}.base.tmp.XXXXXX")" || { rm -f "$tmp"; return 1; }
  cp "$tmp" "$btmp" || { rm -f "$tmp" "$btmp"; return 1; }
  mv "$btmp" "$sf.base.json" || { rm -f "$tmp" "$btmp"; return 1; }
  mv "$tmp" "$sf" || { rm -f "$tmp"; return 1; }
}

oss_state_read() { jq -r "$2" "$1"; }

# Pure transform: op+payload applied to state on stdin -> new state on stdout.
# Shared by mutate (live) and replay (Task 4). Every new op lands HERE only.
_oss_apply_op() { # $1=op $2=payload-json
  local op="$1" payload="$2"
  case "$op" in
    set_posture)
      jq --argjson p "$payload" '.project.posture = $p.posture' ;;
    add_release)
      jq --argjson p "$payload" '.releases += [$p]' ;;
    add_spine)
      jq --argjson p "$payload" '.spines += [$p]' ;;
    add_work_item)
      jq --argjson p "$payload" '.work_items += [$p]' ;;
    set_spine_class)
      jq --argjson p "$payload" '
        (.spines[] | select(.id == $p.spine) | .class) = $p.to
        | .class_overrides += [{spine:$p.spine,from:$p.from,to:$p.to,reason:$p.reason,at:$p.at}]' ;;
    *)
      echo "oss: unknown op '$op'" >&2; return 4 ;;
  esac
}

oss_state_mutate() { # $1=state-file $2=op $3=payload-json
  local sf="$1" op="$2" payload="$3" lock="$1.lock" rc=0
  if ! mkdir "$lock" 2>/dev/null; then
    echo "oss: state locked ($lock exists) - another ceremony is mutating; retry or run 'oss doctor'" >&2
    return 3
  fi
  # Critical section runs as a body function invoked in `|| rc=$?` context:
  # errexit is SUSPENDED for the whole body (that is the documented behavior of
  # a command on the left of `||`), so NO bare command-substitution inside it -
  # not the ones here today, nor any Task 4 replay work adds later - can
  # hard-exit the process and leak the lock. The RETURN trap is gone: the
  # unconditional `rmdir` below releases the lock on EVERY path (success and
  # every failure rc). rc 3 (contention) returns above, before the lock is
  # acquired, so we never rmdir a lock we do not own.
  _oss_state_mutate_body "$sf" "$op" "$payload" || rc=$?
  rmdir "$lock" 2>/dev/null || true
  return "$rc"
}

# Critical-section body. rc 0 ok, 4 on any failure. NO lock logic lives here -
# the wrapper owns lock acquire/release. Because the wrapper calls this in
# `|| rc=$?` context, errexit is off for everything below: even a future
# UNguarded bare `x="$(cmd)"` cannot hard-exit; worst case it continues with an
# empty value and the invalid-result guard catches it before the `mv`.
_oss_state_mutate_body() { # $1=state-file $2=op $3=payload
  local sf="$1" op="$2" payload="$3" tmp seq ts
  tmp="$(mktemp "${sf}.tmp.XXXXXX")" || return 4
  seq="$(jq '.mutations | length' "$sf" 2>/dev/null)" || { rm -f "$tmp"; return 4; }
  ts="$(_oss_now)" || { rm -f "$tmp"; return 4; }
  # journal append + effect happen in ONE jq pipeline into ONE $tmp, committed
  # by a single mv - so the mutation and its journal entry commit atomically.
  if ! jq --arg op "$op" --arg ts "$ts" --argjson seq "$seq" --argjson payload "$payload" \
      '.mutations += [{seq:$seq,op:$op,ts:$ts,payload:$payload}]' "$sf" \
      | _oss_apply_op "$op" "$payload" > "$tmp"; then
    rm -f "$tmp"; return 4
  fi
  # refuse to install an empty/invalid result (pipeline failure guard) - runs
  # BEFORE the mv, so the original is left untouched on any failure.
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    echo "oss: mutation produced invalid state; aborted (original untouched)" >&2
    return 4
  fi
  mv "$tmp" "$sf" || { rm -f "$tmp"; return 4; }
}

# §9.2 replay capability: rebuild state from the base snapshot by re-applying
# every journaled mutation through the SAME pure transform mutate uses
# (_oss_apply_op), re-appending each mutation record to .mutations first so a
# faithful replay reproduces the live state including the journal itself.
# Read-only against $sf (only $sf.base.json's content is read into memory) -
# doctor (Task 5) can call this freely without a lock.
oss_state_replay() { # $1=state-file ; rc 0 = clean, 5 = drift, 1 = no base
  local sf="$1" base="$1.base.json" rebuilt live n i op payload seq_json
  [ -f "$base" ] || { echo "oss: no base snapshot ($base)" >&2; return 1; }
  rebuilt="$(cat "$base")" || return 1
  n="$(jq '.mutations | length' "$sf" 2>/dev/null)" || { echo "oss: cannot read mutations from $sf" >&2; return 1; }
  i=0
  while [ "$i" -lt "$n" ]; do
    seq_json="$(jq -c ".mutations[$i]" "$sf" 2>/dev/null)" || { echo "oss: mutation $i unreadable" >&2; return 4; }
    op="$(printf '%s' "$seq_json" | jq -r '.op' 2>/dev/null)" || { echo "oss: mutation $i op unreadable" >&2; return 4; }
    payload="$(printf '%s' "$seq_json" | jq -c '.payload' 2>/dev/null)" || { echo "oss: mutation $i payload unreadable" >&2; return 4; }
    rebuilt="$(printf '%s' "$rebuilt" \
      | jq --argjson m "$seq_json" '.mutations += [$m]' \
      | _oss_apply_op "$op" "$payload")" || return 4
    i=$((i+1))
  done
  live="$(jq -S . "$sf" 2>/dev/null)" || { echo "oss: cannot read live state $sf" >&2; return 1; }
  if [ "$(printf '%s' "$rebuilt" | jq -S .)" = "$live" ]; then
    echo "replay: clean ($n mutations)"
  else
    echo "replay: drift detected - live state does not equal base+journal ($n mutations). Run 'oss doctor' and repair from journal." >&2
    return 5
  fi
}

# §9.2 schema-version guard (no silent upgrades): refuse to operate on a state
# file whose schema_version is newer than this build supports, and name the
# gap rather than guess. Migration registry lives HERE: a future v1->v2
# migration is added as an explicit, journaled `_oss_migrate_1_to_2` case
# dispatched from this function once a v2 schema exists - never silent.
oss_state_check_version() { # $1=state-file ; rc 0 ok, 6 missing/invalid/future
  local v
  # Guarded with `|| v=""` (deviates from the brief's bare
  # `v="$(jq ... 2>/dev/null)"`): a bare assignment's exit status IS the
  # command substitution's exit status, so a missing/unreadable state file
  # (jq rc!=0) would trip `errexit` in any caller that isn't already
  # suspending it (e.g. this function called directly, not if-wrapped) -
  # silently killing the process instead of returning the documented rc 6.
  # doctor.sh always calls this if-wrapped (which does suspend errexit for
  # the whole call), but the function's own contract promises rc 6 for
  # missing/invalid regardless of call site, so guard it here too.
  v="$(jq -r '.schema_version // empty' "$1" 2>/dev/null)" || v=""
  [ -n "$v" ] || { echo "state schema missing/invalid" >&2; return 6; }
  # Reject any non-digit value (e.g. "abc", "1.5", a JSON boolean) BEFORE the
  # numeric `-gt` comparison. Without this a valid-JSON-but-non-integer
  # schema_version makes `[ "$v" -gt N ]` error ("integer expression
  # expected"); inside the `if` that nonzero exit reads as "not newer" and
  # execution silently falls through to `return 0` - the exact §9.2
  # silent-acceptance the guard exists to prevent. Digits-only here
  # guarantees the `-gt` below is always a numeric comparison.
  case "$v" in
    ''|*[!0-9]*) echo "state schema invalid: '$v'" >&2; return 6 ;;
  esac
  if [ "$v" -gt "$OSS_STATE_SCHEMA_VERSION" ] 2>/dev/null; then
    echo "state schema v$v requires a newer ossify (this build supports v$OSS_STATE_SCHEMA_VERSION)" >&2
    return 6
  fi
  # Migration registry: when v2 exists, dispatch _oss_migrate_1_to_2 here
  # (explicit, journaled, never silent - spec §9.2).
  return 0
}
