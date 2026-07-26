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

# --- Fix 4: the shape check must verify ALL 14 required top-level keys, not
# just 6. A state missing e.g. `counters` (which every ledger add needs) must
# FAIL shape, not be reported as having "all required keys present". ---
T4="$(mktemp -d)"; S4="$T4/state.json"
oss_state_init "$S4" doc-shape >/dev/null
jq 'del(.counters)' "$S4" > "$S4.x" && mv "$S4.x" "$S4"
jq 'del(.counters)' "$S4.base.json" > "$S4.bx" && mv "$S4.bx" "$S4.base.json"
t_capture "$OSS" doctor "$S4"
t_assert_rc 1 "doctor fails on state missing 'counters'"
t_assert_contains "$T_OUT" "fail: shape - missing key 'counters'" "missing counters key reported"
rm -rf "$T4"

# --- Final review finding 8: every doctor-level replay assertion in this file
# ran against a CLEAN state, so doctor was never tested against drift. The file's
# own tamper case sets schema_version = 99, which fails the schema check first
# and takes the `skip: replay` branch — replay is never reached by it. Two
# mutations survived the whole suite as a result: making doctor never call replay
# (the "ok: replay" substring still matched), and flipping its fail:/rc=1 arm to
# ok:. doctor is §9.1's operator entry for a binding §9.2 guarantee and its gate
# is `rc -eq 0` rather than "schema ok", so any future check that fails ahead of
# replay would silently downgrade drift detection to a mis-attributed skip.
#
# Tamper the live state OUT OF BAND while leaving base.json intact, so
# base+journal genuinely no longer rebuild to live, and keep schema_version at 1
# so the schema gate does not short-circuit replay.
T5="$(mktemp -d)"; S5="$T5/state.json"
oss_state_init "$S5" doc-drift >/dev/null
oss_state_mutate "$S5" set_posture '{"posture":"open-core"}' >/dev/null   # one real journaled mutation
jq '.project.posture = "tampered-out-of-band"' "$S5" > "$S5.x" && mv "$S5.x" "$S5"
t_capture "$OSS" doctor "$S5"
t_assert_rc 1 "doctor fails on a DRIFTED state"
t_assert_contains "$T_OUT" "ok: schema" "schema is still green — drift is not a schema failure"
t_assert_contains "$T_OUT" "fail: replay" "drift reported by replay (not skipped, not reported ok)"
t_assert_contains "$T_OUT" "drift detected" "replay's drift message reaches the operator through doctor"
t_assert_contains "$T_OUT" "ok: shape" "shape still reports independently of the replay failure"
rm -rf "$T5"

rm -rf "$TMP"
t_summary
