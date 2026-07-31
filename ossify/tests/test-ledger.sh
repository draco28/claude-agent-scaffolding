#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/ledger.sh"
. "$HERE/../lib/entities.sh"; . "$HERE/../lib/registries.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
oss_state_init "$S" ledger-demo >/dev/null

t_capture oss_ledger_add_auto "$S" r0.s1 "backtest CLI smoke" "true" "exit:0"
t_assert_rc 0 "auto line added"; t_assert_eq "d1" "$T_OUT" "counter-minted id"
t_capture oss_ledger_add_auto "$S" r0.s1 "bad expected" "true" "somehow:fine"
t_assert_rc 2 "invalid expected grammar rejected"

t_capture oss_ledger_add_user "$S" r0.s1 "Type a strategy idea and run a backtest from the chat panel" "results table visible"
t_assert_rc 0 "user journey line added"; t_assert_eq "d2" "$T_OUT" "second id"
t_capture oss_ledger_add_user "$S" r0.s1 "Inspect the pulse.db schema" "schema visible"
t_assert_rc 2 "inspector phrasing banned"

# D1: <by-spine> is now the join key apply_pending matches on, and is validated
# against known spines - this file predates entities.sh and used the free-text
# id "r1.s2"; mint a real release+spine to amend against instead.
t_capture oss_entity_add_release "$S" "amend test" "goal"
t_assert_rc 0 "setup: release minted for the amendment fixture"; REL="$T_OUT"
t_capture oss_entity_add_spine "$S" "$REL" "amending spine" flesh canonical
t_assert_rc 0 "setup: spine minted for the amendment fixture"; SP="$T_OUT"

t_capture oss_ledger_supersede "$S" d1 "$SP" "flow redesigned"
t_assert_rc 0 "supersede ok"
t_capture oss_state_read "$S" '.demo_ledger[0].status'
t_assert_eq "active" "$T_OUT" "status stays ACTIVE until close applies the pending amendment (D1)"
t_capture oss_state_read "$S" '.demo_ledger[0].pending_status'
t_assert_eq "superseded" "$T_OUT" "supersede records a pending status"
t_capture oss_ledger_active_auto "$S"
t_assert_eq "1" "$(printf '%s' "$T_OUT" | jq 'length')" "a pending amendment does not drop the line from the live set"
t_capture oss_ledger_apply_pending "$S" "$SP"
t_assert_rc 0 "apply_pending ok"
t_capture oss_state_read "$S" '.demo_ledger[0].status'; t_assert_eq "superseded" "$T_OUT" "status archived after close applies it"
t_capture oss_ledger_active_auto "$S"
t_assert_eq "[]" "$(printf '%s' "$T_OUT" | jq -c .)" "superseded line not active after close"

t_capture oss_ledger_add_patch "$S" abc1234 "bump serde patch version"
t_assert_rc 0 "patch record added"
t_capture oss_state_read "$S" '.patch_records | length'; t_assert_eq "1" "$T_OUT" "patch recorded"

# §5.3 floor guard must not be bypassable by leading whitespace: a leading
# space/tab before inspector phrasing is the same banned phrasing, just padded.
t_capture oss_ledger_add_user "$S" r0.s1 " Open the file" "file contents visible"
t_assert_rc 2 "leading-space inspector phrasing banned"
t_capture oss_ledger_add_user "$S" r0.s1 "$(printf '\tInspect the schema')" "schema visible"
t_assert_rc 2 "leading-tab inspector phrasing banned"
# ...but the trim must not over-reject a legitimate leading-space journey line.
t_capture oss_ledger_add_user "$S" r0.s1 " Type a strategy idea and run a backtest" "results visible"
t_assert_rc 0 "leading-space legitimate journey line still accepted"

# --- Final review finding 1: the `expected` validator was the glob `exit:[0-9]*`
# = "exit:" + ONE digit + anything. A well-prefixed but malformed operand was
# accepted here, and the runner's `[ "$rc" -ne "${expected#exit:}" ]` then exits
# 2 on the non-numeric operand — which the enclosing `if` reads as FALSE, so the
# FAIL branch never runs and the line counts as passed at every future close.
# The pre-existing negatives above ("somehow:fine") only probe PREFIX failures;
# these probe the operand, which is where the silent pass lived.
for bad in "exit:0 (tests green)" "exit:0abc" "exit:0 # x" "exit:0|contains:x" "exit:" "exit:1 "; do
  t_capture oss_ledger_add_auto "$S" r0.s1 "malformed operand" "true" "$bad"
  t_assert_rc 2 "malformed exit: operand rejected: '$bad'"
done
# ...and the tightening must not over-reject a well-formed multi-digit code.
t_capture oss_ledger_add_auto "$S" r0.s1 "multi-digit exit code" "true" "exit:127"
t_assert_rc 0 "well-formed multi-digit exit: operand still accepted"

L1=d1   # this file uses literal demo-line ids
# Quarantine stays IMMEDIATE (it is a close/doctor-time verb applied when a line
# actually fails, not a planned amendment) and now records WHICH release, so
# §6.1's "fixed or retired by the next release close" has an anchor.
t_capture oss_ledger_quarantine "$S" "$L1" "upstream CI image broken" "r1"
t_assert_rc 0 "quarantine ok"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$L1\")][0].status"
t_assert_eq "quarantined" "$T_OUT" "quarantine applies immediately"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$L1\")][0].quarantined_in_release"
t_assert_eq "r1" "$T_OUT" "quarantine records the release it was raised in"

# Fake lifecycle: a fake can be replaced or explicitly renewed with a NEW expiry.
t_capture oss_reg_add_fake "$S" "broker" "fake" "no sandbox yet" "the first live order" "r1"
t_capture oss_reg_set_fake_status "$S" "broker" "renewed" "sandbox still unavailable" "r2"
t_assert_rc 0 "fake renew ok"
t_capture oss_state_read "$S" '[.fakes[] | select(.boundary=="broker")][0].expiry_release'
t_assert_eq "r2" "$T_OUT" "renewal moves the expiry"
t_capture oss_reg_set_fake_status "$S" "broker" "bogus" "x"
t_assert_rc 2 "fake status rejects an unknown value"
t_capture oss_reg_set_fake_status "$S" "nosuch" "replaced" "x"
t_assert_rc 7 "fake status on an unknown boundary is rc 7"

# set_fake_status is one of Task 2's four new _oss_apply_op cases and is the
# only one of the four with no replay coverage elsewhere (test-spine-planning.sh
# covers set_demo_line_pending/apply_demo_pending/clear_demo_pending but never
# calls fake_status). Close that gap here.
t_capture oss_state_replay "$S"
t_assert_rc 0 "replay stays clean across set_fake_status (and this file's pending/apply/quarantine ops)"

rm -rf "$TMP"
t_summary
