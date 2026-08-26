#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
ROOT="$HERE/.."; . "$ROOT/lib/cli.sh"; . "$ROOT/lib/setup.sh"
TMP="$(mktemp -d)"; export BOARD_FAKE_LOG="$TMP/calls.log" BOARD_FAKE_DIR="$TMP/fake" BOARD_HULY_BIN="$HERE/fake/huly"; mkdir -p "$BOARD_FAKE_DIR"
mut() { awk 'index($0," create ")||index($0,"roles create")||index($0,"statuses create"){n++} END{print n+0}' "$BOARD_FAKE_LOG"; }

# type absent: `task-types list --project-type` fails INTEGRATION_FAILED (recorded: "did not
# resolve to exactly one project type") -> rc 5, instruction names the seed-Spine UI step, zero mutations
echo 1 > "$BOARD_FAKE_DIR/task-types.list.rc"
echo '{"code":"INTEGRATION_FAILED","message":"did not resolve to exactly one project type"}' > "$BOARD_FAKE_DIR/task-types.list.err"
t_capture board_setup_workspace_type; t_assert_rc 5 "type absent -> rc 5"; t_assert_contains "$T_OUT" "Spine" "prints the seed-Spine UI step"
t_assert_eq 0 "$(mut)" "absent type: nothing created"
rm -f "$BOARD_FAKE_DIR/task-types.list.rc" "$BOARD_FAKE_DIR/task-types.list.err"

# type exists but is empty: the CLI cannot populate an empty type (task-types create copies
# an existing one) -> rc 5, same seed-Spine instruction, zero mutations
: > "$BOARD_FAKE_LOG"
echo '{"taskTypes":[],"total":0}' > "$BOARD_FAKE_DIR/task-types.list.json"
t_capture board_setup_workspace_type; t_assert_rc 5 "empty type -> rc 5"; t_assert_contains "$T_OUT" "Spine" "prints the seed-Spine UI step"
t_assert_eq 0 "$(mut)" "empty type: nothing created"

# type has only the hand-seeded Spine: exactly one task-types create ("Work item"),
# 4 issue-statuses create, 1 spaces roles create. The permissions fake mirrors the recorded
# live listing's shape: real ids, over-grant bait present (UpdateSpace, CreateCard), and —
# as on the live server — no Read-permission id at all.
: > "$BOARD_FAKE_LOG"
echo '{"taskTypes":[{"id":"tt1","name":"Spine","projectTypeId":"pt1","projectTypeName":"Ossify project","kind":"issue","issueClass":"tracker:class:Issue","statusCount":0}],"total":1}' > "$BOARD_FAKE_DIR/task-types.list.json"
echo '{"permissions":[{"id":"core:permission:CreateObject","label":"Create object"},{"id":"core:permission:UpdateObject","label":"Update object"},{"id":"core:permission:DeleteObject","label":"Delete object"},{"id":"core:permission:UpdateSpace","label":"Update space"},{"id":"card:permission:CreateCard","label":"Create card"}],"total":5}' > "$BOARD_FAKE_DIR/spaces.permissions.list.json"
t_capture board_setup_workspace_type; t_assert_rc 0 "Spine-only type: setup ok"
t_capture grep -c 'task-types create' "$BOARD_FAKE_LOG"; t_assert_eq 1 "$T_OUT" "exactly one task type created"
t_capture sed -n '2p' "$BOARD_FAKE_LOG"; t_assert_eq "task-types create Work item --project-type Ossify project --json" "$T_OUT" "Work item argv (after the task-types list call)"
t_capture grep -c 'issue-statuses create' "$BOARD_FAKE_LOG"; t_assert_eq 4 "$T_OUT" "four statuses created"
t_capture grep -c 'spaces roles create' "$BOARD_FAKE_LOG"; t_assert_eq 1 "$T_OUT" "one role created"
t_capture grep 'spaces roles create' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" '["core:permission:CreateObject","core:permission:UpdateObject"]' "role gets exactly the two object ids — no substring over-grant"
t_capture grep 'spaces roles create' "$BOARD_FAKE_LOG"; case "$T_OUT" in *UpdateSpace*|*CreateCard*) T_FAIL=$((T_FAIL+1)); echo "FAIL: over-grant id in role argv";; *) T_PASS=$((T_PASS+1));; esac
t_capture grep 'spaces roles create' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" "--confirm --yes" "role create requires both --confirm and --yes"

# an expected permission id absent from the listing is a loud stop, not a smaller role
: > "$BOARD_FAKE_LOG"
echo '{"permissions":[{"id":"core:permission:CreateObject","label":"Create object"}],"total":1}' > "$BOARD_FAKE_DIR/spaces.permissions.list.json"
t_capture board_setup_workspace_type; t_assert_rc 1 "missing expected id -> rc 1"
t_assert_contains "$T_OUT" "core:permission:UpdateObject" "missing id named"
t_capture grep -c 'spaces roles create' "$BOARD_FAKE_LOG"; t_assert_eq 0 "$T_OUT" "missing id: no role created"
echo '{"permissions":[{"id":"core:permission:CreateObject","label":"Create object"},{"id":"core:permission:UpdateObject","label":"Update object"},{"id":"core:permission:DeleteObject","label":"Delete object"},{"id":"core:permission:UpdateSpace","label":"Update space"},{"id":"card:permission:CreateCard","label":"Create card"}],"total":5}' > "$BOARD_FAKE_DIR/spaces.permissions.list.json"

# type complete (both task types present): no task-type create, but statuses and role are
# still attempted every run — creation is idempotent by design, not diffed against a listing
# that carries no per-type status names
: > "$BOARD_FAKE_LOG"
echo '{"taskTypes":[{"id":"tt1","name":"Spine","projectTypeName":"Ossify project"},{"id":"tt2","name":"Work item","projectTypeName":"Ossify project"}],"total":2}' > "$BOARD_FAKE_DIR/task-types.list.json"
t_capture board_setup_workspace_type; t_assert_rc 0 "complete type: ok"
t_capture grep -c 'task-types create' "$BOARD_FAKE_LOG"; t_assert_eq 0 "$T_OUT" "complete type: no task-type create"
t_capture grep -c 'issue-statuses create' "$BOARD_FAKE_LOG"; t_assert_eq 4 "$T_OUT" "complete type: four status creates (idempotent)"
t_capture grep -c 'spaces roles create' "$BOARD_FAKE_LOG"; t_assert_eq 1 "$T_OUT" "complete type: one role create (idempotent)"

# role CONFLICT on create is tolerated (duplicate create returns CONFLICT without
# overwriting the existing role's permissions)
: > "$BOARD_FAKE_LOG"; echo 5 > "$BOARD_FAKE_DIR/spaces.roles.create.rc"; echo '{"code":"CONFLICT","message":"exists"}' > "$BOARD_FAKE_DIR/spaces.roles.create.err"
t_capture board_setup_workspace_type; t_assert_rc 0 "role CONFLICT on create is not a failure"
rm -f "$BOARD_FAKE_DIR/spaces.roles.create.rc" "$BOARD_FAKE_DIR/spaces.roles.create.err"

# any other failure on a status create propagates
echo 3 > "$BOARD_FAKE_DIR/issue-statuses.create.rc"; echo '{"code":"AUTHENTICATION_FAILED","message":"no"}' > "$BOARD_FAKE_DIR/issue-statuses.create.err"
t_capture board_setup_workspace_type; t_assert_rc 1 "other failures propagate"
rm -f "$BOARD_FAKE_DIR/issue-statuses.create.rc" "$BOARD_FAKE_DIR/issue-statuses.create.err"
t_summary
