#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
ROOT="$HERE/.."; . "$ROOT/lib/resolve.sh"
HOOK="$ROOT/hooks-handlers/stop.sh"; F="$HERE/fixtures/state"
TMP="$(mktemp -d)"; export BOARD_FAKE_LOG="$TMP/calls.log" BOARD_FAKE_DIR="$TMP/fake" BOARD_HULY_BIN="$HERE/fake/huly"; mkdir -p "$BOARD_FAKE_DIR"; : > "$BOARD_FAKE_LOG"
echo '{"taskTypes":[{"id":"tt1","name":"Spine","projectTypeName":"Ossify project"},{"id":"tt2","name":"Work item","projectTypeName":"Ossify project"}],"total":2}' > "$BOARD_FAKE_DIR/task-types.list.json"
echo '{"permissions":[{"id":"core:permission:CreateObject","label":"Create object"},{"id":"core:permission:UpdateObject","label":"Update object"},{"id":"core:permission:DeleteObject","label":"Delete object"}],"total":3}' > "$BOARD_FAKE_DIR/spaces.permissions.list.json"
echo '{"identifier":"PTRD","statuses":["Backlog","planned","active","complete","abandoned"]}' > "$BOARD_FAKE_DIR/projects.get.json"
unset HULY_URL HULY_WORKSPACE HULY_TOKEN HULY_EMAIL   # hermeticity: the digest gate compares the destination too
run_hook() { printf '{"session_id":"s1","cwd":"%s","hook_event_name":"Stop"}' "$1" | bash "$HOOK"; }

# no workspace: exit 0, no CLI
t_capture run_hook "$TMP"; t_assert_rc 0 "no workspace: exit 0"; t_assert_eq 0 "$(wc -l < "$BOARD_FAKE_LOG" | tr -d ' ')" "no workspace: no CLI"
# workspace without binding: exit 0, no CLI
WS="$TMP/pt-ai"; mkdir -p "$WS/.ossify"; cp "$F/empty.json" "$WS/.ossify/project-state.json"
t_capture run_hook "$WS"; t_assert_rc 0 "no binding: exit 0"; t_assert_eq 0 "$(wc -l < "$BOARD_FAKE_LOG" | tr -d ' ')" "no binding: no CLI"
# bound + changed digest: CLI invoked, digest written
board_binding_write "$WS" PTRD
t_capture run_hook "$WS/.ossify"; t_assert_rc 0 "bound: exit 0"
t_capture grep -c 'task-types list' "$BOARD_FAKE_LOG"; t_assert_eq 1 "$T_OUT" "bound: sync ran"
t_capture board_sync_read "$WS" '.digest'; t_assert_eq "$(board_state_digest "$WS")" "$T_OUT" "bound: digest written"
# unchanged: no CLI
: > "$BOARD_FAKE_LOG"; t_capture run_hook "$WS"; t_assert_rc 0 "unchanged: exit 0"; t_assert_eq 0 "$(wc -l < "$BOARD_FAKE_LOG" | tr -d ' ')" "unchanged: no CLI"
# failing CLI: still exit 0, digest untouched, log line
cp "$F/dag.json" "$WS/.ossify/project-state.json"; D="$(board_sync_read "$WS" '.digest')"
echo 3 > "$BOARD_FAKE_DIR/milestones.create.rc"; echo '{"code":"AUTHENTICATION_FAILED","message":"x"}' > "$BOARD_FAKE_DIR/milestones.create.err"
t_capture run_hook "$WS"; t_assert_rc 0 "failing sync: hook still exits 0"
t_assert_eq "$D" "$(board_sync_read "$WS" '.digest')" "failing sync: digest untouched"
t_capture tail -1 "$WS/.board/sync.log"; t_assert_contains "$T_OUT" "AUTHENTICATION_FAILED" "failing sync: logged"
# malformed stdin: exit 0
t_capture bash -c "echo 'not json' | bash '$HOOK'"; t_assert_rc 0 "garbage stdin: exit 0"
# hooks.json shape
t_capture jq -r '.hooks.Stop[0].hooks[0].async' "$ROOT/hooks/hooks.json"; t_assert_eq "true" "$T_OUT" "Stop hook is async"
t_capture jq -r '.hooks.Stop[0].hooks[0].timeout' "$ROOT/hooks/hooks.json"; t_assert_eq "600" "$T_OUT" "Stop hook timeout 600 (a full reconcile is one npx process per CLI call; 30s truncated it)"
t_summary
