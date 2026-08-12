#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/state.sh"
. "$HERE/../lib/doctor.sh"
. "$HERE/../lib/id.sh"
. "$HERE/../lib/entities.sh"
. "$HERE/../lib/ledger.sh"
. "$HERE/../lib/registries.sh"
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

# --- Fix 4: the shape check must verify EVERY required top-level key, not just
# 6. A state missing e.g. `counters` (which every ledger add needs) must FAIL
# shape, not be reported as having "all required keys present".
#
# This comment used to say "ALL 14 keys". The list is 16 as of v0.3 and will
# grow again, so the count is deliberately not restated here — a number in a
# comment beside a loop that owns the real list is a second copy that only ever
# drifts. `doctor.sh`'s `for key in …` is the list. ---
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
# base+journal genuinely no longer rebuild to live, and leave schema_version at
# whatever `oss_state_init` currently writes (v3 as of Plan C1 Task 2's fix
# round) so the schema gate does not short-circuit replay. The point is that
# the schema check must PASS here — never hardcode the version, or this test
# silently stops reaching replay on the next bump.
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

# --- Step 4 doctor visibility: each warn: line must be provably reachable.
# Seed a state carrying all three rot conditions: a pending amendment, a
# quarantined line, and a RENEWED fake (not merely active - `renewed` is the
# case the stale selector under-counted, and the one whose deadline already
# moved once). IDs are captured from the minting calls rather than hardcoded,
# so a counter change upstream cannot silently point an assertion at nothing.
WTMP="$(mktemp -d)"; W="$WTMP/state.json"
oss_state_init "$W" doctor-warn >/dev/null
REL="$(oss_entity_add_release "$W" "mvp" "ship the core loop")"
SP="$(oss_entity_add_spine "$W" "$REL" "order flow" flesh canonical)"
L1="$(oss_ledger_add_auto "$W" "$SP" "line one" "bash -c 'exit 0'" "exit:0")"
L2="$(oss_ledger_add_auto "$W" "$SP" "line two" "bash -c 'exit 0'" "exit:0")"

# Assert the fixture actually seeded BEFORE asserting on doctor's output. A
# seeding call that rc's nonzero creates no condition, and the warn: assertion
# below then fails for a reason that has nothing to do with the selector under
# test. This is the Task 2 trap verbatim: its scoping fixture amended against a
# spine the file never created, the call rc-7'd, and the assertion passed while
# testing nothing.
if [ -n "$REL" ] && [ -n "$SP" ] && [ -n "$L1" ] && [ -n "$L2" ]; then
  T_PASS=$((T_PASS+1))
else
  T_FAIL=$((T_FAIL+1)); echo "FAIL: doctor-warn fixture did not seed (REL=$REL SP=$SP L1=$L1 L2=$L2)"
fi

oss_ledger_retire       "$W" "$L1" "$SP" "replaced by the new flow"        # -> pending_amendments[]
oss_ledger_quarantine   "$W" "$L2" "flaky under load" "$REL"               # -> status quarantined
# NOTE: channel (3rd arg) must be real|fake|deferred (registries.sh's
# oss_reg_add_fake enum guard) - "fake" here, not a protocol name like "http".
oss_reg_add_fake        "$W" "payment-gateway" "fake" "no vendor sandbox" "sandbox ships" "$REL" >/dev/null
oss_reg_set_fake_status "$W" "payment-gateway" renewed "vendor slipped a quarter" "r2"

# Codex P2 finding #2: doctor must surface out-of-spine patch records. The
# patch-lane contract (spec §6.1) says these are doctor-visible.
oss_ledger_add_patch "$W" abc1234 "typo in export path, no bone no gate no line"

# Through the REAL dispatcher binary (set -euo pipefail), not a sourced call:
# all three new warn: lines use the `[ "$n" -gt 0 ] && echo ...` bare-command
# shape, which is exactly the form that dies under strict mode if the
# errexit-exemption reasoning is wrong - a sourced-only call (this test file
# never enables `set -e`) cannot catch that class of fault.
t_capture "$OSS" doctor "$W"
t_assert_contains "$T_OUT" "warn: ledger - 1 demo line(s) carry a pending amendment" "doctor surfaces a pending amendment"
t_assert_contains "$T_OUT" "warn: ledger - 1 quarantined line(s)" "doctor surfaces a quarantined line"
t_assert_contains "$T_OUT" "warn: fakes - 1 outstanding fake(s)" "doctor surfaces a RENEWED fake, not just an active one"
t_assert_contains "$T_OUT" "warn: patches - 1 out-of-spine patch record(s)" "doctor surfaces patch-lane records"
t_assert_rc 0 "the four warn: lines are advisory - they must not change doctor's rc"

# --- v0.3 worktree drift, the SKIP arm. The worktree check is the only one here
# that reads the REPO rather than the state file, so it is the only one that can
# be legitimately unavailable: no pairing manifest means no canonical root to
# look in. It must still emit a line. A check that falls silent when it cannot
# run reads as a check that ran and found nothing - the exact failure the
# `skip: replay` branch above already exists to prevent, and the reason this arm
# is asserted rather than assumed.
#
# Run from a MANIFEST-FREE directory rather than wherever the suite happened to
# be launched: `oss_manifest_discover` walks up from $PWD, so a repo that later
# grows a pairing manifest would silently flip this assertion's arm.
# The warn: and ok: arms need a real canonical repo with real worktree dirs and
# live in test-worktree.sh, next to the selector they exercise.
NOMAN="$(mktemp -d)"; PREVPWD="$PWD"
cd "$NOMAN"
t_capture "$OSS" doctor "$W"
t_assert_contains "$T_OUT" "skip: worktrees - skipped" "doctor: the worktree check emits a skip line with no manifest, never silence"
t_assert_rc 0 "doctor: an unavailable worktree check is advisory - skip: never sets rc"
cd "$PREVPWD"; rm -rf "$NOMAN"
rm -rf "$WTMP"

rm -rf "$TMP"
t_summary
