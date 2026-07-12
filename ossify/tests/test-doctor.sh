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

rm -rf "$TMP"
t_summary
