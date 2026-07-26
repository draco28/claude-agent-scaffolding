#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/ledger.sh"
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

t_capture oss_ledger_supersede "$S" d1 r1.s2 "flow redesigned"
t_assert_rc 0 "supersede ok"
t_capture oss_state_read "$S" '.demo_ledger[0].status'; t_assert_eq "superseded" "$T_OUT" "status archived"
t_capture oss_ledger_active_auto "$S"
t_assert_eq "[]" "$(printf '%s' "$T_OUT" | jq -c .)" "superseded line not active"

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

rm -rf "$TMP"
t_summary
