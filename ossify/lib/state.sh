#!/usr/bin/env bash
# ossify state engine. §9.2 safety commitments: atomic writes, lock file,
# schema_version+migrations, append-only mutations journal.

OSS_STATE_SCHEMA_VERSION=2

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
    feature_map:[],patch_records:[],class_overrides:[],veto_dispositions:[],
    close_records:[],
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
    set_composition)
      jq --argjson p "$payload" '.project.composition_root = $p.composition_root' ;;
    set_overlay)
      jq --argjson p "$payload" '.project.overlay_wiring = $p.overlay_wiring' ;;
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
    add_bone)      jq --argjson p "$payload" '.bones += [$p]' ;;
    add_risk_gate) jq --argjson p "$payload" '.risk_gates += [$p]' ;;
    add_fake)      jq --argjson p "$payload" '.fakes += [$p]' ;;
    add_feature)   jq --argjson p "$payload" '.feature_map += [$p]' ;;
    add_demo_line)
      jq --argjson p "$payload" '.demo_ledger += [$p] | .counters.demo_line += 1' ;;
    set_demo_line_status)
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (.status = $p.status | .status_reason = $p.reason | .status_by = $p.by
           | .quarantined_in_release =
               (if $p.status == "quarantined" then $p.release else .quarantined_in_release end))' ;;
    set_demo_line_pending)
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (.pending_status = $p.status | .pending_by = $p.by
           | .pending_reason = $p.reason | .pending_at = $p.at)' ;;
    # Applies every pending amendment BELONGING TO ONE SPINE and consumes it.
    # Scoped by `pending_by` so a sibling spine's planned amendment is untouched -
    # that scoping is the whole point of the pending lifecycle. Records lacking
    # the pending_* fields entirely (every line written before this task) read as
    # null and are skipped, so no migration of demo_ledger is needed.
    apply_demo_pending)
      jq --argjson p "$payload" '
        .demo_ledger |= map(
          if (.pending_by // null) == $p.spine and (.pending_status // null) != null
          then .status = .pending_status
             | .status_reason = .pending_reason
             | .status_by = .pending_by
             | .pending_status = null | .pending_by = null
             | .pending_reason = null | .pending_at = null
          else . end)' ;;
    clear_demo_pending)
      jq --argjson p "$payload" '
        (.demo_ledger[] | select(.id == $p.id)) |=
          (.pending_status = null | .pending_by = null
           | .pending_reason = null | .pending_at = null)' ;;
    set_fake_status)
      jq --argjson p "$payload" '
        (.fakes[] | select(.boundary == $p.boundary)) |=
          (.status = $p.status | .status_reason = $p.reason | .status_at = $p.at
           | .expiry_release = (if $p.expiry == "" then .expiry_release else $p.expiry end))' ;;
    add_patch_record)
      jq --argjson p "$payload" '.patch_records += [$p]' ;;
    set_release_meta)
      # Allowlist the patch to exactly the five fields the plan names
      # (exit_criteria/spine_dag/ledger_budget/next_sketch/real_use_findings).
      # An unrestricted `. + $p.patch` would let a caller-controlled object
      # splice ANY key onto the release record (e.g. id/status), silently
      # corrupting identity or lifecycle state. Disallowed keys are dropped
      # (not rejected): this keeps the op total/pure for replay - a
      # rejecting op would need a new rc through _oss_apply_op, colliding
      # with the existing rc-4 apply-failure convention that op already
      # shares with every other case in this function.
      jq --argjson p "$payload" '
        ($p.patch | with_entries(select(.key | IN("exit_criteria","spine_dag","ledger_budget","next_sketch","real_use_findings")))) as $allowed
        | (.releases[] | select(.id == $p.release)) |= (. + $allowed)' ;;
    add_veto_disposition)
      jq --argjson p "$payload" '.veto_dispositions += [$p]' ;;
    # Status transitions. Each is a pure jq assignment through a select(), which
    # is a NO-OP on a non-matching id (jq assigns to an empty path expression and
    # exits 0). That silent no-op is exactly finding 7's `class_set` bug shape, so
    # the reject-before-mutate guard in entities.sh is load-bearing, not defensive
    # decoration - it is the ONLY thing that turns a typo'd id into rc 7.
    set_spine_status)
      jq --argjson p "$payload" '(.spines[] | select(.id == $p.spine) | .status) = $p.status' ;;
    set_work_item_status)
      jq --argjson p "$payload" '(.work_items[] | select(.id == $p.work_item) | .status) = $p.status' ;;
    set_release_status)
      jq --argjson p "$payload" '(.releases[] | select(.id == $p.release) | .status) = $p.status' ;;
    set_work_item_exec)
      jq --argjson p "$payload" '
        (.work_items[] | select(.id == $p.work_item)) |=
          (.branch = $p.branch | .worktree_path = $p.worktree_path | .base_sha = $p.base_sha)' ;;
    # §9.2's migration registry, realized. Pure and TOTAL: replay re-applies it
    # from the v1 base snapshot, so base+journal still rebuilds live exactly and
    # the base is never rewritten. `has(...)` keeps it idempotent under replay.
    migrate_schema)
      jq --argjson p "$payload" '
        (if has("close_records") then . else . + {close_records:[]} end)
        | .schema_version = $p.to' ;;
    *)
      echo "oss: unknown op '$op'" >&2; return 4 ;;
  esac
}

# Mint a sequential id from the CURRENT (locked) state. Reuses the Plan A
# derivation helpers verbatim — the only change from Plan A is the call site:
# these now run INSIDE the mutate lock (state is stable), so two concurrent
# ceremonies cannot read the same max/counter and mint a duplicate id.
_oss_mint_id() { # $1=state-file $2=mint-spec (release | spine:<rel> | work_item:<spine> | demo)
  local sf="$1" spec="$2" kind parent
  kind="${spec%%:*}"; parent="${spec#*:}"; [ "$parent" = "$spec" ] && parent=""
  case "$kind" in
    release)   oss_id_next_release "$sf" ;;
    spine)     oss_id_next_spine "$sf" "$parent" ;;
    work_item) oss_id_next_work_item "$sf" "$parent" ;;
    demo)      echo "d$(( $(jq -r '.counters.demo_line' "$sf" 2>/dev/null || echo 0) + 1 ))" ;;
    *)         echo "oss: unknown mint spec '$spec'" >&2; return 4 ;;
  esac
}

oss_state_mutate() { # $1=state-file $2=op $3=payload-json [$4=mint-spec]
  local sf="$1" op="$2" payload="$3" mint="${4:-}" lock="$1.lock" rc=0
  # §9.2 schema guard, on the WRITE path. doctor's call is advisory and
  # read-only and therefore protects nothing; without this line a v1 build
  # journals v1-semantics ops straight into a state claiming a future schema.
  #
  # Placed BEFORE `mkdir "$lock"` on purpose: a `return 6` after the lock is
  # acquired would jump past the unconditional `rmdir` below and wedge the state
  # file permanently.
  #
  # Gated on the file PARSING first so an unreadable/corrupt state keeps its
  # established rc 4 (apply-failure, original untouched) owned by
  # _oss_state_mutate_body, rather than being re-labelled a schema failure.
  #
  # `migrate_schema` is the ONE op that must run against a state this build's
  # guard would otherwise refuse - gating it would make the migration
  # unreachable and wedge every v1 project permanently. Still placed BEFORE
  # `mkdir "$lock"`: a `return 6` after the lock jumps past the unconditional
  # `rmdir` below and wedges the state file.
  if [ "$op" != "migrate_schema" ] && jq -e . "$sf" >/dev/null 2>&1; then
    oss_state_check_version "$sf" || return 6
  fi
  if ! mkdir "$lock" 2>/dev/null; then
    echo "oss: state locked ($lock exists) - another ceremony is mutating; retry or run 'oss doctor'" >&2
    return 3
  fi
  # Critical section runs as a body function invoked in `|| rc=$?` context:
  # errexit is SUSPENDED for the whole body, so no bare command-substitution
  # inside it can hard-exit and leak the lock. The body echoes the minted id
  # (if any) to stdout on success; that stdout flows through this function.
  _oss_state_mutate_body "$sf" "$op" "$payload" "$mint" || rc=$?
  rmdir "$lock" 2>/dev/null || true
  return "$rc"
}

# Critical-section body. rc 0 ok, 4 on any failure. NO lock logic here - the
# wrapper owns lock acquire/release. Minting happens here (inside the lock);
# the minted id is injected into the payload BEFORE journaling so the journal
# format and _oss_apply_op are unchanged (replay stays byte-identical).
_oss_state_mutate_body() { # $1=state-file $2=op $3=payload $4=mint-spec
  local sf="$1" op="$2" payload="$3" mint="${4:-}" tmp seq ts minted_id=""
  tmp="$(mktemp "${sf}.tmp.XXXXXX")" || return 4
  if [ -n "$mint" ]; then
    minted_id="$(_oss_mint_id "$sf" "$mint")" || { rm -f "$tmp"; return 4; }
    [ -n "$minted_id" ] || { rm -f "$tmp"; echo "oss: id minting produced empty id" >&2; return 4; }
    # Inject the minted id, overriding any caller-supplied id (a caller can
    # never win a race by pre-baking an id).
    payload="$(printf '%s' "$payload" | jq -c --arg id "$minted_id" '. + {id:$id}')" \
      || { rm -f "$tmp"; return 4; }
  fi
  seq="$(jq '.mutations | length' "$sf" 2>/dev/null)" || { rm -f "$tmp"; return 4; }
  ts="$(_oss_now)" || { rm -f "$tmp"; return 4; }
  # journal append + effect in ONE jq pipeline into ONE $tmp, committed by a
  # single mv - mutation and journal entry commit atomically.
  if ! jq --arg op "$op" --arg ts "$ts" --argjson seq "$seq" --argjson payload "$payload" \
      '.mutations += [{seq:$seq,op:$op,ts:$ts,payload:$payload}]' "$sf" \
      | _oss_apply_op "$op" "$payload" > "$tmp"; then
    rm -f "$tmp"; return 4
  fi
  if ! jq -e '.schema_version' "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    echo "oss: mutation produced invalid state; aborted (original untouched)" >&2
    return 4
  fi
  mv "$tmp" "$sf" || { rm -f "$tmp"; return 4; }
  # Report the minted id (success only). Explicit `return 0`: a bare
  # `[ -n "$minted_id" ] && printf ...` as the last line would make the
  # function return 1 for non-mint ops (empty minted_id) - a false failure.
  [ -n "$minted_id" ] && printf '%s\n' "$minted_id"
  return 0
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
    # Say only what is true today. The previous message pointed the operator at
    # `oss doctor` for repair, but doctor is replay's ONLY caller (so it told an
    # operator running doctor to run doctor) and no repair/restore verb exists in
    # this build. Naming a command that cannot repair is worse than naming none:
    # the operator's next move becomes deleting the state file, which destroys
    # the journal living inside it. `$rebuilt` is deliberately NOT written from
    # here — this function is lock-free so doctor can call it freely.
    echo "replay: drift detected - live state does not equal base+journal ($n mutations)." >&2
    echo "  Nothing is lost: the base snapshot ($base) and the append-only journal inside $sf are both intact, so the correct state is still derivable from them." >&2
    echo "  This build has no automated restore verb. Do NOT delete $sf - the journal lives inside it. Recover by re-applying '.mutations' onto '$base' out-of-band, or restore the file from version control." >&2
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
  # A state OLDER than this build is refused too, and told what to run. Silently
  # operating on a v1 state with v2 semantics is the same class of failure as
  # operating on a v99 one - §9.2 binds "an explicit migration policy ... never
  # silent" in both directions. The refusal names the command so the operator's
  # next move is `oss migrate`, not deleting the state file.
  if [ "$v" -lt "$OSS_STATE_SCHEMA_VERSION" ]; then
    echo "state schema v$v predates this build (v$OSS_STATE_SCHEMA_VERSION) - run 'oss migrate' to upgrade it" >&2
    return 6
  fi
  return 0
}
