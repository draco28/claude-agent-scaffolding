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

# Fix 5 (test coverage): missing base snapshot is the rc-1 path, previously
# only documented in the function's prose comment.
rm -f "$S.base.json"
t_capture oss_state_replay "$S"
t_assert_rc 1 "missing base snapshot is rc 1"
t_assert_contains "$T_OUT" "no base snapshot" "missing-base message named"

rm -rf "$TMP"
t_summary
