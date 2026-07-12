#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/state.sh"
. "$HERE/../lib/doctor.sh"
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"; S="$TMP/state.json"

oss_state_init "$S" doc-demo >/dev/null

t_capture "$OSS" doctor "$S"
t_assert_rc 0 "doctor green on fresh state"
t_assert_contains "$T_OUT" "ok: schema" "version check reported"
t_assert_contains "$T_OUT" "ok: replay" "drift check reported"

jq '.schema_version = 99' "$S" > "$S.x" && mv "$S.x" "$S"
t_capture "$OSS" doctor "$S"
t_assert_rc 1 "doctor fails on future schema"
t_assert_contains "$T_OUT" "requires a newer ossify" "upgrade message"

# --- Fix Round 1 (critical): a valid-JSON but non-numeric schema_version must
# FAIL, not silently pass. Sync base.json too so replay stays CLEAN and the
# schema check alone determines rc (isolates the bug: current code returns
# rc 0 / "ok: schema" because [ "abc" -gt 1 ] errors -> reads "not newer" ->
# falls through to return 0). ---
T2="$(mktemp -d)"; S2="$T2/state.json"
oss_state_init "$S2" doc-nonnum >/dev/null
jq '.schema_version = "abc"' "$S2" > "$S2.x" && mv "$S2.x" "$S2"
jq '.schema_version = "abc"' "$S2.base.json" > "$S2.bx" && mv "$S2.bx" "$S2.base.json"
t_capture "$OSS" doctor "$S2"
t_assert_rc 1 "doctor fails on non-numeric schema (abc)"
t_assert_contains "$T_OUT" "fail: schema" "non-numeric schema reported as fail"

jq '.schema_version = "1.5"' "$S2" > "$S2.x" && mv "$S2.x" "$S2"
jq '.schema_version = "1.5"' "$S2.base.json" > "$S2.bx" && mv "$S2.bx" "$S2.base.json"
t_capture "$OSS" doctor "$S2"
t_assert_rc 1 "doctor fails on non-integer schema (1.5)"
t_assert_contains "$T_OUT" "fail: schema" "non-integer schema reported as fail"
rm -rf "$T2"

# --- Fix Round 1 (important): no check line is silently dropped when schema
# fails. On a future-schema (99) state, schema FAILs and replay is gated out -
# current code prints NOTHING for replay; it must instead print an explicit
# skip line so every check reports one line. ---
T3="$(mktemp -d)"; S3="$T3/state.json"
oss_state_init "$S3" doc-skip >/dev/null
jq '.schema_version = 99' "$S3" > "$S3.x" && mv "$S3.x" "$S3"
t_capture "$OSS" doctor "$S3"
t_assert_contains "$T_OUT" "fail: schema" "schema fail line present"
t_assert_contains "$T_OUT" "skip: replay" "replay skip line present (not silently dropped)"
rm -rf "$T3"

rm -rf "$TMP"
t_summary
