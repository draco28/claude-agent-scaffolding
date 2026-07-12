#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/state.sh"
TMP="$(mktemp -d)"; S="$TMP/.ossify/project-state.json"

t_capture oss_state_init "$S" demo-project
t_assert_rc 0 "init succeeds"
t_capture oss_state_read "$S" '.schema_version';       t_assert_eq "1" "$T_OUT" "schema v1"
t_capture oss_state_read "$S" '.project.name';         t_assert_eq "demo-project" "$T_OUT" "project name"
[ -f "$S.base.json" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: base snapshot missing"; }

t_capture oss_state_init "$S" again
t_assert_rc 1 "re-init refused"

t_capture oss_state_mutate "$S" set_posture '{"posture":"fully-private"}'
t_assert_rc 0 "mutate ok"
t_capture oss_state_read "$S" '.project.posture';      t_assert_eq "fully-private" "$T_OUT" "posture applied"
t_capture oss_state_read "$S" '.mutations | length';   t_assert_eq "1" "$T_OUT" "mutation journaled"
t_capture oss_state_read "$S" '.mutations[0].op';      t_assert_eq "set_posture" "$T_OUT" "op recorded"

mkdir "$S.lock"   # simulate a concurrent holder
t_capture oss_state_mutate "$S" set_posture '{"posture":"fully-open"}'
t_assert_rc 3 "lock contention rc=3"
rmdir "$S.lock"
t_capture oss_state_read "$S" '.project.posture';      t_assert_eq "fully-private" "$T_OUT" "state untouched under contention"

rm -rf "$TMP"
t_summary
