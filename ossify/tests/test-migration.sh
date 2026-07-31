#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"

# A GENUINE v1 state, hand-built — NOT a fresh `oss init`, which now emits v3.
# Testing migration against a freshly-derived state proves nothing: the
# upgrade-input class of bug only shows up when the input is legacy-shaped.
V1="$TMP/v1.json"
jq -n '{schema_version:1,
  project:{name:"legacy",posture:null,composition_root:null,overlay_wiring:null},
  counters:{demo_line:0},
  releases:[],spines:[],work_items:[],demo_ledger:[],bones:[],risk_gates:[],fakes:[],
  feature_map:[],patch_records:[],class_overrides:[],veto_dispositions:[],mutations:[]}' > "$V1"
cp "$V1" "$V1.base.json"

# A v1 state is REFUSED for mutation until migrated — never silently upgraded.
export OSS_STATE_FILE="$V1"
t_capture "$OSS" posture_set fully-private
t_assert_rc 6 "dispatcher: mutating a v1 state is refused rc 6"
t_assert_contains "$T_OUT" "oss migrate" "the refusal names the migration command"

# doctor says the same thing rather than reporting ok.
t_capture "$OSS" doctor
t_assert_contains "$T_OUT" "fail: schema" "doctor reports the stale schema"

# Migration is explicit, journaled, and idempotent. v1 -> v3 in ONE `oss
# migrate` call (not one hop per version) — migrate_schema is version-agnostic
# and total, so a v1 state (no demo lines at all here) lands on v3 directly.
t_capture "$OSS" migrate
t_assert_rc 0 "migrate v1 -> v3 ok"
t_capture "$OSS" get '.schema_version'; t_assert_eq "3" "$T_OUT" "schema is v3 after migrate"
t_capture "$OSS" get '.close_records | length'; t_assert_eq "0" "$T_OUT" "close_records seeded empty"
t_capture "$OSS" migrate
t_assert_rc 0 "re-migrating an already-current state is a no-op, not an error"
t_assert_contains "$T_OUT" "already at v3" "no-op migrate says so"

# THE POINT: replay must still be clean. base.json is v1, the journal now ends
# with migrate_schema, and base+journal must rebuild the v3 live state exactly.
t_capture "$OSS" doctor
t_assert_contains "$T_OUT" "ok: replay" "replay is clean across the migration boundary"
t_capture oss_state_read "$V1.base.json" '.schema_version'
t_assert_eq "1" "$T_OUT" "the base snapshot is NOT rewritten — the migration is journaled, not retroactive"

# A migrated state accepts normal mutations again.
t_capture "$OSS" posture_set fully-private
t_assert_rc 0 "post-migration mutation ok"

# --- F1.1: a GENUINE v2 state (schema_version:2, close_records already
# present, a demo line with the v2-era SCALAR pending_* fields set, plus one
# with none at all) must ALSO reach v3 in one `oss migrate` call through the
# real dispatcher — not just via a direct _oss_apply_op call. Real projects are
# sitting at v2 today (this build shipped it), so the dispatcher's own
# version-gate has to accept v2 as a starting point, not just v1.
V2="$TMP/v2.json"
jq -n '{schema_version:2,
  project:{name:"legacy-v2",posture:null,composition_root:null,overlay_wiring:null},
  counters:{demo_line:2},
  releases:[],spines:[{id:"r0.s1",release:"r0",name:"s",class:"flesh",target_repo:"canonical"}],
  work_items:[],
  demo_ledger:[
    {id:"d1",type:"auto",status:"active",status_reason:null,status_by:null,
     pending_status:"superseded",pending_by:"r0.s1",pending_reason:"v2-era amendment",pending_at:"2026-01-01T00:00:00Z"},
    {id:"d2",type:"auto",status:"active",status_reason:null,status_by:null,
     pending_status:null,pending_by:null,pending_reason:null,pending_at:null}
  ],
  bones:[],risk_gates:[],fakes:[],
  feature_map:[],patch_records:[],class_overrides:[],veto_dispositions:[],
  close_records:[],mutations:[]}' > "$V2"
cp "$V2" "$V2.base.json"
export OSS_STATE_FILE="$V2"
t_capture "$OSS" migrate
t_assert_rc 0 "migrate v2 -> v3 ok, through the real dispatcher"
t_capture "$OSS" get '.schema_version'; t_assert_eq "3" "$T_OUT" "schema is v3 after migrating a v2 state"
t_capture "$OSS" get '.demo_ledger[0].pending_amendments[0].status'
t_assert_eq "superseded" "$T_OUT" "a v2 line with a set pending_status becomes a one-element pending_amendments list"
t_capture "$OSS" get '.demo_ledger[0].pending_amendments[0].by'
t_assert_eq "r0.s1" "$T_OUT" "...carrying the v2 pending_by as the list entry's spine"
t_capture "$OSS" get '.demo_ledger[0] | has("pending_status")'
t_assert_eq "false" "$T_OUT" "the v2 scalar pending_status field is gone after migration, not merely nulled"
t_capture "$OSS" get '.demo_ledger[1].pending_amendments'
t_assert_eq "[]" "$T_OUT" "a v2 line with no pending amendment becomes an empty list, not null"
t_capture "$OSS" doctor
t_assert_contains "$T_OUT" "ok: replay" "replay is clean across the v2->v3 migration boundary too"
t_capture "$OSS" migrate
t_assert_rc 0 "re-migrating the v2-origin state (now v3) is a no-op"
t_assert_contains "$T_OUT" "already at v3" "no-op migrate says so"

# --- G5: idempotency at the OP level, not the dispatcher's. `oss_cmd_migrate`
# short-circuits on "already at vN" BEFORE _oss_apply_op ever runs a second
# time, so calling `oss migrate` twice (above) asserts the DISPATCHER's
# short-circuit, not migrate_schema's own idempotency - which is what replay
# actually depends on (replay re-applies migrate_schema from the journal every
# time, with no dispatcher short-circuit anywhere in that path). Call the op
# directly, twice, and diff with `jq -S` so the has(...)-guards are provably
# load-bearing rather than merely read as such.
G5V1='{"schema_version":1,"demo_ledger":[
  {"id":"d1","pending_status":"retired","pending_by":"r0.s1","pending_reason":"x","pending_at":"t"},
  {"id":"d2"}
]}'
G5_ONCE="$(printf '%s' "$G5V1" | _oss_apply_op migrate_schema '{"to":3}')"
G5_TWICE="$(printf '%s' "$G5_ONCE" | _oss_apply_op migrate_schema '{"to":3}')"
t_assert_eq "$(printf '%s' "$G5_ONCE" | jq -S .)" "$(printf '%s' "$G5_TWICE" | jq -S .)" \
  "migrate_schema is idempotent at the op level, called directly twice (G5)"

# A FUTURE schema is still refused, and is NOT offered a migration.
FUT="$TMP/fut.json"; cp "$V1" "$FUT"; cp "$V1.base.json" "$FUT.base.json"
jq '.schema_version = 99' "$FUT" > "$FUT.x" && mv "$FUT.x" "$FUT"
export OSS_STATE_FILE="$FUT"
t_capture "$OSS" migrate
t_assert_rc 6 "migrate refuses a state newer than the build"
t_assert_contains "$T_OUT" "newer" "the refusal says the state is newer"

rm -rf "$TMP"
t_summary
