#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
. "$HERE/../lib/resolve.sh"
TMP="$(mktemp -d)"; WS="$TMP/proj-ai"; mkdir -p "$WS/.ossify" "$WS/deep/er"
echo '{"schema_version":3,"project":{"name":"p"},"releases":[],"spines":[],"work_items":[]}' > "$WS/.ossify/project-state.json"

t_capture board_resolve_workspace "$WS/deep/er"; t_assert_rc 0 "walk-up finds workspace"; t_assert_eq "$WS" "$T_OUT" "echoes workspace root"
t_capture board_resolve_workspace "$TMP";        t_assert_rc 3 "no workspace above -> rc 3"

t_capture board_binding_read "$WS"; t_assert_rc 4 "no binding -> rc 4"
board_binding_write "$WS" PTRD
t_capture board_binding_read "$WS"; t_assert_rc 0 "binding readable"; t_assert_eq "PTRD" "$T_OUT" "binding identifier"
t_capture jq -r '.channel' "$WS/.board/config.json"; t_assert_eq "false" "$T_OUT" "channel defaults to false"

D1="$(board_state_digest "$WS")"; t_assert_eq 64 "${#D1}" "digest is sha256 hex"
echo '{"schema_version":3,"project":{"name":"p2"},"releases":[],"spines":[],"work_items":[]}' > "$WS/.ossify/project-state.json"
D2="$(board_state_digest "$WS")"; [ "$D1" != "$D2" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: digest changes with content"; }

t_capture board_sync_read "$WS" '.digest'; t_assert_eq "null" "$T_OUT" "missing sync.json reads as null"
board_sync_write "$WS" "{\"project\":\"PTRD\",\"digest\":\"$D2\",\"synced_at\":\"2026-08-26T00:00:00Z\"}"
t_capture board_sync_read "$WS" '.digest'; t_assert_eq "$D2" "$T_OUT" "sync.json round-trips"
t_capture cat "$WS/.board/.gitignore"; t_assert_contains "$T_OUT" "sync.json" "gitignore covers sync.json"; t_assert_contains "$T_OUT" "sync.log" "gitignore covers sync.log"
echo 'not json' > "$WS/.board/sync.json"
t_capture board_sync_read "$WS" '.digest'; t_assert_eq "null" "$T_OUT" "corrupt sync.json reads as null (full reconcile path)"
board_log "$WS" "hello"; t_capture tail -1 "$WS/.board/sync.log"; t_assert_contains "$T_OUT" "hello" "log appends"; t_assert_contains "$T_OUT" "Z " "log line is timestamped"
t_summary
