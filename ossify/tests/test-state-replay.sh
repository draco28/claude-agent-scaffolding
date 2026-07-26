#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/state.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"

oss_state_init "$S" replay-demo >/dev/null
oss_state_mutate "$S" set_posture '{"posture":"open-core"}'
oss_state_mutate "$S" set_posture '{"posture":"fully-private"}'

t_capture oss_state_replay "$S"
t_assert_rc 0 "replay reproduces live state"

jq '.project.posture = "tampered"' "$S" > "$S.x" && mv "$S.x" "$S"   # out-of-band edit
t_capture oss_state_replay "$S"
t_assert_rc 5 "tamper detected as drift"
t_assert_contains "$T_OUT" "drift" "drift named in output"

# Final review finding 5: the drift message used to end "Run 'oss doctor' and
# repair from journal". doctor is replay's ONLY caller, so that told an operator
# running doctor to run doctor — and no repair/restore/recover verb exists in
# this build's subcommand inventory at all. A remediation string naming a command
# that cannot repair is worse than naming none: the obvious next move becomes
# deleting the state file, which destroys the append-only journal living inside
# it. The message must state only what is true today.
case "$T_OUT" in
  *"repair from journal"*) T_FAIL=$((T_FAIL+1)); echo "FAIL: drift message still points at a repair path that does not exist";;
  *) T_PASS=$((T_PASS+1));;
esac
t_assert_contains "$T_OUT" "no automated restore verb" "drift message says what this build can actually do"
t_assert_contains "$T_OUT" "Do NOT delete" "drift message guards the journal against the obvious wrong next move"
t_assert_contains "$T_OUT" "base.json" "drift message names the intact base snapshot the state is still derivable from"

# Fix 5 (test coverage): missing base snapshot is the rc-1 path, previously
# only documented in the function's prose comment.
rm -f "$S.base.json"
t_capture oss_state_replay "$S"
t_assert_rc 1 "missing base snapshot is rc 1"
t_assert_contains "$T_OUT" "no base snapshot" "missing-base message named"

rm -rf "$TMP"
t_summary
