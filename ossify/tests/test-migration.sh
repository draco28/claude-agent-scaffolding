#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor; do . "$HERE/../lib/$lib.sh"; done
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"

# A GENUINE v1 state, hand-built — NOT a fresh `oss init`, which now emits v2.
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

# Migration is explicit, journaled, and idempotent.
t_capture "$OSS" migrate
t_assert_rc 0 "migrate v1 -> v2 ok"
t_capture "$OSS" get '.schema_version'; t_assert_eq "2" "$T_OUT" "schema is v2 after migrate"
t_capture "$OSS" get '.close_records | length'; t_assert_eq "0" "$T_OUT" "close_records seeded empty"
t_capture "$OSS" migrate
t_assert_rc 0 "re-migrating an already-current state is a no-op, not an error"
t_assert_contains "$T_OUT" "already at v2" "no-op migrate says so"

# THE POINT: replay must still be clean. base.json is v1, the journal now ends
# with migrate_schema, and base+journal must rebuild the v2 live state exactly.
t_capture "$OSS" doctor
t_assert_contains "$T_OUT" "ok: replay" "replay is clean across the migration boundary"
t_capture oss_state_read "$V1.base.json" '.schema_version'
t_assert_eq "1" "$T_OUT" "the base snapshot is NOT rewritten — the migration is journaled, not retroactive"

# A migrated state accepts normal mutations again.
t_capture "$OSS" posture_set fully-private
t_assert_rc 0 "post-migration mutation ok"

# A FUTURE schema is still refused, and is NOT offered a migration.
FUT="$TMP/fut.json"; cp "$V1" "$FUT"; cp "$V1.base.json" "$FUT.base.json"
jq '.schema_version = 99' "$FUT" > "$FUT.x" && mv "$FUT.x" "$FUT"
export OSS_STATE_FILE="$FUT"
t_capture "$OSS" migrate
t_assert_rc 6 "migrate refuses a state newer than the build"
t_assert_contains "$T_OUT" "newer" "the refusal says the state is newer"

rm -rf "$TMP"
t_summary
