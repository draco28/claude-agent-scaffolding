#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
ROOT="$HERE/.."; . "$ROOT/lib/cli.sh"; . "$ROOT/lib/setup.sh"
TMP="$(mktemp -d)"; export BOARD_FAKE_LOG="$TMP/calls.log" BOARD_FAKE_DIR="$TMP/fake" BOARD_HULY_BIN="$HERE/fake/huly"; mkdir -p "$BOARD_FAKE_DIR"
mut() { awk 'index($0," create ")||index($0,"roles create")||index($0,"statuses create"){n++} END{print n+0}' "$BOARD_FAKE_LOG"; }

# type absent -> rc 5, instruction, zero mutations
echo '[{"name":"Classic project"}]' > "$BOARD_FAKE_DIR/spaces.types.list.json"
t_capture board_setup_workspace_type; t_assert_rc 5 "type absent -> rc 5"; t_assert_contains "$T_OUT" "Settings" "prints the UI step"
t_assert_eq 0 "$(mut)" "absent type: nothing created"

# type present, nothing inside -> creates 2 task types, 4 statuses, 1 role, in that order
: > "$BOARD_FAKE_LOG"
echo '[{"name":"Classic project"},{"name":"Ossify project","roles":[]}]' > "$BOARD_FAKE_DIR/spaces.types.list.json"
echo '[]' > "$BOARD_FAKE_DIR/task-types.list.json"
echo '[{"_id":"p1","name":"CreateObject","label":"Create object"},{"_id":"p2","name":"UpdateObject","label":"Update object"},{"_id":"p3","name":"DeleteObject","label":"Delete object"},{"_id":"p4","name":"ArchiveSpace","label":"Archive space"},{"_id":"p5","name":"ReadObject","label":"Read object"}]' > "$BOARD_FAKE_DIR/spaces.permissions.list.json"
t_capture board_setup_workspace_type; t_assert_rc 0 "empty type: setup ok"
t_capture grep -c 'task-types create' "$BOARD_FAKE_LOG"; t_assert_eq 2 "$T_OUT" "two task types created"
t_capture grep -c 'issue-statuses create' "$BOARD_FAKE_LOG"; t_assert_eq 4 "$T_OUT" "four statuses created"
t_capture grep -c 'spaces roles create' "$BOARD_FAKE_LOG"; t_assert_eq 1 "$T_OUT" "one role created"
t_capture grep 'spaces roles create' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" '["p1","p2","p5"]' "role gets create/update/read ids only"
t_capture sed -n '3p' "$BOARD_FAKE_LOG"; t_assert_eq "task-types create Spine --project-type Ossify project --json" "$T_OUT" "first task type argv (after the two list calls)"

# type complete -> zero mutations (idempotency)
: > "$BOARD_FAKE_LOG"
echo '[{"name":"Classic project"},{"name":"Ossify project","roles":[{"name":"agent"}]}]' > "$BOARD_FAKE_DIR/spaces.types.list.json"
echo '[{"name":"Spine","statuses":[{"name":"planned"},{"name":"active"},{"name":"complete"},{"name":"abandoned"}]},{"name":"Work item","statuses":[{"name":"planned"},{"name":"active"},{"name":"complete"},{"name":"abandoned"}]}]' > "$BOARD_FAKE_DIR/task-types.list.json"
t_capture board_setup_workspace_type; t_assert_rc 0 "complete type: ok"; t_assert_eq 0 "$(mut)" "complete type: zero mutations"

# known-answer negative: one status missing on one task type -> exactly one status create
: > "$BOARD_FAKE_LOG"
echo '[{"name":"Spine","statuses":[{"name":"planned"},{"name":"active"},{"name":"complete"}]},{"name":"Work item","statuses":[{"name":"planned"},{"name":"active"},{"name":"complete"},{"name":"abandoned"}]}]' > "$BOARD_FAKE_DIR/task-types.list.json"
t_capture board_setup_workspace_type; t_assert_rc 0 "partial: ok"
t_capture grep -c 'issue-statuses create' "$BOARD_FAKE_LOG"; t_assert_eq 1 "$T_OUT" "exactly one status re-created"
t_capture grep 'issue-statuses create' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" "abandoned Lost" "the missing one"

# CONFLICT on create is tolerated (the spike may show creates are not idempotent server-side)
: > "$BOARD_FAKE_LOG"; echo 5 > "$BOARD_FAKE_DIR/issue-statuses.create.rc"; echo '{"code":"CONFLICT","message":"exists"}' > "$BOARD_FAKE_DIR/issue-statuses.create.err"
t_capture board_setup_workspace_type; t_assert_rc 0 "CONFLICT on status create is not a failure"
rm -f "$BOARD_FAKE_DIR/issue-statuses.create.rc" "$BOARD_FAKE_DIR/issue-statuses.create.err"
echo 3 > "$BOARD_FAKE_DIR/issue-statuses.create.rc"; echo '{"code":"AUTHENTICATION_FAILED","message":"no"}' > "$BOARD_FAKE_DIR/issue-statuses.create.err"
t_capture board_setup_workspace_type; t_assert_rc 1 "other failures propagate"
t_summary
