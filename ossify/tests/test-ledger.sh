#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/ledger.sh"
. "$HERE/../lib/entities.sh"; . "$HERE/../lib/registries.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
oss_state_init "$S" ledger-demo >/dev/null

# Mint the spine that the demo lines are keyed to. ledger_add_auto/add_user now
# validate the source_spine exists (Codex P2 finding #1) — a demo line against
# a nonexistent spine is silently skipped at close.
oss_entity_add_release "$S" "demo release" "goal" >/dev/null
oss_entity_add_spine "$S" r0 "demo spine" bone canonical >/dev/null

t_capture oss_ledger_add_auto "$S" r0.s1 "backtest CLI smoke" "true" "exit:0"
t_assert_rc 0 "auto line added"; t_assert_eq "d1" "$T_OUT" "counter-minted id"
t_capture oss_ledger_add_auto "$S" r0.s1 "bad expected" "true" "somehow:fine"
t_assert_rc 2 "invalid expected grammar rejected"

t_capture oss_ledger_add_user "$S" r0.s1 "Type a strategy idea and run a backtest from the chat panel" "results table visible"
t_assert_rc 0 "user journey line added"; t_assert_eq "d2" "$T_OUT" "second id"
t_capture oss_ledger_add_user "$S" r0.s1 "Inspect the pulse.db schema" "schema visible"
t_assert_rc 2 "inspector phrasing banned"

# Codex P2 finding #1: a demo line keyed to a nonexistent spine journals
# silently and is never exercised at close. Both add_auto and add_user must
# reject an unknown spine with rc 7 before mutating.
t_capture oss_state_read "$S" '.demo_ledger | length'
BEFORE="$T_OUT"
t_capture oss_ledger_add_auto "$S" r9.s99 "phantom" "true" "exit:0"
t_assert_rc 7 "add_auto rejects unknown spine"
t_capture oss_ledger_add_user "$S" r9.s99 "phantom user line" "phantom outcome"
t_assert_rc 7 "add_user rejects unknown spine"
t_capture oss_state_read "$S" '.demo_ledger | length'
t_assert_eq "$BEFORE" "$T_OUT" "no phantom demo line journaled after unknown-spine refusal"

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
t_capture oss_state_read "$S" '.demo_ledger[0].pending_amendments[0].status'
t_assert_eq "superseded" "$T_OUT" "supersede records a pending amendment (F1: a list entry, not a scalar)"
t_capture oss_state_read "$S" '.demo_ledger[0].pending_amendments[0].by'
t_assert_eq "$SP" "$T_OUT" "...keyed to the planning spine"
t_capture oss_ledger_active_auto "$S"
t_assert_eq "1" "$(printf '%s' "$T_OUT" | jq 'length')" "a pending amendment does not drop the line from the live set"
t_capture oss_ledger_apply_pending "$S" "$SP"
t_assert_rc 0 "apply_pending ok"
t_capture oss_state_read "$S" '.demo_ledger[0].status'; t_assert_eq "superseded" "$T_OUT" "status archived after close applies it"
t_capture oss_state_read "$S" '.demo_ledger[0].pending_amendments'
t_assert_eq "[]" "$T_OUT" "pending amendment consumed by apply"
t_capture oss_ledger_active_auto "$S"
t_assert_eq "[]" "$(printf '%s' "$T_OUT" | jq -c .)" "superseded line not active after close"

# F3: apply_pending against an unknown spine is a reject-before-mutate rc 7,
# not a silent rc-0 no-op (which would let a typo'd close report success while
# applying nothing).
t_capture oss_state_read "$S" '.mutations | length'; MUT_BEFORE="$T_OUT"
t_capture oss_ledger_apply_pending "$S" "r9.s9"
t_assert_rc 7 "apply_pending against an unknown spine is rc 7"
t_capture oss_state_read "$S" '.mutations | length'
t_assert_eq "$MUT_BEFORE" "$T_OUT" "no phantom mutation journaled after unknown-spine refusal"

# F1.3: unplan now takes the spine, and rejects a spine with nothing pending
# on the line (ambiguity a list makes possible that a single slot never had).
t_capture oss_ledger_supersede "$S" d2 "$SP" "second amendment for the unplan test"
t_assert_rc 0 "setup: second pending amendment for the unplan test"
t_capture oss_ledger_unplan "$S" d2 "r9.s9"
t_assert_rc 7 "unplan rejects a spine with no pending amendment on the line"
t_capture oss_ledger_unplan "$S" d2 "$SP"
t_assert_rc 0 "unplan clears the calling spine's own pending amendment"
t_capture oss_state_read "$S" '.demo_ledger[1].pending_amendments'
t_assert_eq "[]" "$T_OUT" "pending amendment cleared"
t_capture oss_ledger_unplan "$S" d999 "$SP"
t_assert_rc 7 "unplan against an unknown line id is rc 7"

# --- F9 / named risk 3: a demo line written before this task (no
# `pending_amendments` key AT ALL - not even a migrated empty []) must survive
# apply_demo_pending BYTE-IDENTICAL when the calling spine has nothing pending
# on it. Hand-built, not `oss_state_init`-derived: a fresh init writes the
# CURRENT shape and proves nothing about an upgrade input. Compared with
# `jq -S -c` (sorted keys) on both sides per the brief's explicit instruction -
# reading the jq is not proof, only a diff on the actual output is.
LEGACY_LINE='{"id":"d1","status":"active","status_reason":null,"status_by":null}'
LEGACY_STATE="$(jq -n --argjson l "$LEGACY_LINE" '{demo_ledger:[$l]}')"
LEGACY_AFTER="$(printf '%s' "$LEGACY_STATE" | _oss_apply_op apply_demo_pending '{"spine":"r0.s1"}')"
IN_SORTED="$(printf '%s' "$LEGACY_STATE" | jq -S -c '.demo_ledger[0]')"
OUT_SORTED="$(printf '%s' "$LEGACY_AFTER" | jq -S -c '.demo_ledger[0]')"
t_assert_eq "$IN_SORTED" "$OUT_SORTED" "a legacy demo line with no pending_amendments key at all survives apply_demo_pending byte-identical"

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

# --- G2 test 2: anchor preservation. Re-quarantining the SAME line WITHOUT a
# release must not erase the already-recorded one - the unconditional
# pre-F2 write ("r0" -> "") destroyed §6.1's parking-ticket anchor.
t_capture oss_ledger_quarantine "$S" "$L1" "re-examined, still broken"
t_assert_rc 0 "re-quarantine without a release ok"
t_capture oss_state_read "$S" "[.demo_ledger[] | select(.id==\"$L1\")][0].quarantined_in_release"
t_assert_eq "r1" "$T_OUT" "re-quarantining without a release does not erase the original anchor"

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
