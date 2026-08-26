#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
ROOT="$HERE/.."; . "$ROOT/lib/cli.sh"; . "$ROOT/lib/resolve.sh"; . "$ROOT/lib/setup.sh"; . "$ROOT/lib/sync.sh"
F="$HERE/fixtures/state"
mkws() { local d; d="$(mktemp -d)/pt-ai"; mkdir -p "$d/.ossify"; cp "$1" "$d/.ossify/project-state.json"; echo "$d"; }
fresh_fake() { export BOARD_FAKE_LOG="$1/calls.log" BOARD_FAKE_DIR="$1/fake" BOARD_HULY_BIN="$HERE/fake/huly"; mkdir -p "$BOARD_FAKE_DIR"; : > "$BOARD_FAKE_LOG"
  echo '[{"name":"Ossify project","roles":[{"name":"agent"}]}]' > "$BOARD_FAKE_DIR/spaces.types.list.json"
  echo '[{"name":"Spine","statuses":[{"name":"planned"},{"name":"active"},{"name":"complete"},{"name":"abandoned"}]},{"name":"Work item","statuses":[{"name":"planned"},{"name":"active"},{"name":"complete"},{"name":"abandoned"}]}]' > "$BOARD_FAKE_DIR/task-types.list.json"
  echo '{"identifier":"PTRD","name":"pulse-trader"}' > "$BOARD_FAKE_DIR/projects.get.json"; }
mutations() { awk 'index($0,"create ")||index($0," update ")||index($0,"relations add")||index($0,"milestone set")||index($0,"labels add"){n++} END{print n+0}' "$BOARD_FAKE_LOG"; }

# 1. no workspace / no binding
t_capture board_sync "$(mktemp -d)"; t_assert_rc 3 "no workspace -> 3"
WS="$(mkws "$F/pulse-trader.json")"; fresh_fake "$(dirname "$WS")"
t_capture board_sync "$WS"; t_assert_rc 4 "no binding -> 4"

# 2. bind + first full sync on an empty board: counts and call shapes
board_binding_write "$WS" PTRD
# issues created get identifiers PTRD-1.. in call order; the fake returns a fixed identifier, so make
# it count: a tiny stateful override that numbers creates.
cat > "$BOARD_FAKE_DIR/issues.create.json" <<'JSON'
{"identifier":"PTRD-N"}
JSON
t_capture board_sync "$WS"; t_assert_rc 0 "first sync ok"
t_capture jq -r '.created' <<<"$T_OUT"; t_assert_eq 15 "$T_OUT" "created = 2 milestones + 5 spines + 8 items"
t_capture grep -c 'milestones create' "$BOARD_FAKE_LOG"; t_assert_eq 2 "$T_OUT" "two milestone creates"
t_capture grep -c 'issues create' "$BOARD_FAKE_LOG";     t_assert_eq 13 "$T_OUT" "thirteen issue creates"
t_capture grep -c 'issues create .*--parent-issue' "$BOARD_FAKE_LOG"; t_assert_eq 8 "$T_OUT" "eight are sub-issues"
t_capture grep -c 'issues milestone set' "$BOARD_FAKE_LOG"; t_assert_eq 5 "$T_OUT" "five milestone sets (spines only)"
t_capture grep -c 'labels add' "$BOARD_FAKE_LOG";        t_assert_eq 5 "$T_OUT" "five spine labels"
EDGES="$(jq '[.releases[].spine_dag[]?[1][]?] | length' "$F/pulse-trader.json")"
t_capture grep -c 'relations add' "$BOARD_FAKE_LOG";     t_assert_eq "$EDGES" "$T_OUT" "relations added = dag edges (independent count)"
# order: milestones before issues before relations
ML="$(grep -n 'milestones create' "$BOARD_FAKE_LOG" | tail -1 | cut -d: -f1)"; IF="$(grep -n 'issues create' "$BOARD_FAKE_LOG" | head -1 | cut -d: -f1)"
[ "$ML" -lt "$IF" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: milestones before issues"; }
t_capture board_sync_read "$WS" '.digest'; t_assert_eq "$(board_state_digest "$WS")" "$T_OUT" "digest written on success"

# 3. second run with unchanged digest: CLI never invoked
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS"; t_assert_rc 0 "unchanged: rc 0"; t_capture jq -r '.skipped' <<<"$T_OUT"; t_assert_eq "unchanged" "$T_OUT" "unchanged: skipped"
t_assert_eq 0 "$(wc -l < "$BOARD_FAKE_LOG" | tr -d ' ')" "unchanged: zero CLI calls"

# 4. --force against a board that already matches: zero mutations (idempotency)
jq -f "$ROOT/lib/map.jq" "$WS/.ossify/project-state.json" > "$BOARD_FAKE_DIR/desired.json"
jq '[.milestones[] | {label: .title, status: .status, _id: .key}]' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/milestones.list.json"
jq '[.issues[] | {identifier: ("PTRD-" + (.key|gsub("\\.";""))), title: .title, status: {name: .status}, taskType: {name: .task_type}, milestone: (if .milestone_key then {label: (.milestone_key + " — x")} else null end), parentIssue: (if .parent_key then ("PTRD-" + (.parent_key|gsub("\\.";""))) else null end)}]' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/issues.list.json"
# the fake answers every relations.list with "all relations present"
jq '[.relations[] | {type:"is-blocked-by", target: ("PTRD-" + (.to_key|gsub("\\.";""))), source: ("PTRD-" + (.from_key|gsub("\\.";"")))}]' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/issues.relations.list.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "force on matching board ok"
t_assert_eq 0 "$(mutations)" "matching board: zero mutations"
t_capture jq -r '.unchanged' <<<"$T_OUT"; t_assert_eq 15 "$T_OUT" "all 15 reported unchanged"

# 5. known-answer negative: flip one work item status -> exactly one issues update, nothing else
jq '(.work_items[] | select(.id=="r1.s1.w3") | .status) = "active"' "$F/pulse-trader.json" > "$WS/.ossify/project-state.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS"; t_assert_rc 0 "flip: ok"
t_assert_eq 1 "$(mutations)" "flip: exactly one mutation"
t_capture grep 'issues update' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" "PTRD-r1s1w3 --status active" "flip: the right item, the right status"

# 5b. label drift: actual exposes labels and one spine lacks its class label -> exactly one labels add
jq -f "$ROOT/lib/map.jq" "$WS/.ossify/project-state.json" > "$BOARD_FAKE_DIR/desired.json"
jq '[.issues[] | {identifier: ("PTRD-" + (.key|gsub("\\.";""))), title: .title, status: {name: .status}, taskType: {name: .task_type}, milestone: (if .milestone_key then {label: (.milestone_key + " — x")} else null end), parentIssue: (if .parent_key then ("PTRD-" + (.parent_key|gsub("\\.";""))) else null end), labels: (if .label then [.label] else [] end)}] | map(if (.title|startswith("r1.s1 ")) then .labels = [] else . end)' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/issues.list.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "label drift: ok"
t_assert_eq 1 "$(mutations)" "label drift: exactly one mutation"
t_capture grep 'labels add' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" "PTRD-r1s1 --label spine:bone" "label drift: the spine, the class label"

# 5c. milestone drift: one spine attached to the wrong milestone -> exactly one milestone set
jq '[.issues[] | {identifier: ("PTRD-" + (.key|gsub("\\.";""))), title: .title, status: {name: .status}, taskType: {name: .task_type}, milestone: (if .milestone_key then {label: (.milestone_key + " — x")} else null end), parentIssue: (if .parent_key then ("PTRD-" + (.parent_key|gsub("\\.";""))) else null end), labels: (if .label then [.label] else [] end)}] | map(if (.title|startswith("r1.s2 ")) then .milestone = {label:"r0 — Release 0"} else . end)' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/issues.list.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "milestone drift: ok"
t_assert_eq 1 "$(mutations)" "milestone drift: exactly one mutation"
t_capture grep 'milestone set' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" "--milestone r1 " "milestone drift: reattached to r1"

# 6. failure mid-run: digest untouched, log written, rc 1
cp "$F/dag.json" "$WS/.ossify/project-state.json"; D_BEFORE="$(board_sync_read "$WS" '.digest')"
rm -f "$BOARD_FAKE_DIR/milestones.list.json"   # empty board again, so the milestone create is attempted
echo 3 > "$BOARD_FAKE_DIR/milestones.create.rc"; echo '{"code":"AUTHENTICATION_FAILED","message":"expired"}' > "$BOARD_FAKE_DIR/milestones.create.err"
t_capture board_sync "$WS"; t_assert_rc 1 "failure -> rc 1"
t_assert_eq "$D_BEFORE" "$(board_sync_read "$WS" '.digest')" "failure: digest untouched"
t_capture tail -1 "$WS/.board/sync.log"; t_assert_contains "$T_OUT" "AUTHENTICATION_FAILED" "failure logged with code"
rm -f "$BOARD_FAKE_DIR/milestones.create.rc" "$BOARD_FAKE_DIR/milestones.create.err"

# 7. space type missing -> rc 5 before any mutation
: > "$BOARD_FAKE_LOG"; echo '[{"name":"Classic project"}]' > "$BOARD_FAKE_DIR/spaces.types.list.json"
t_capture board_sync "$WS" --force; t_assert_rc 5 "type missing -> 5"; t_assert_eq 0 "$(mutations)" "type missing: zero mutations"

# 8. bare binding: no state file, --bind creates the project and config, mirrors nothing
BARE="$(mktemp -d)/scaf-ai"; mkdir -p "$BARE"; fresh_fake "$(dirname "$BARE")"
echo 5 > "$BOARD_FAKE_DIR/projects.get.rc.once"; echo '{"code":"NOT_FOUND","message":"no"}' > "$BOARD_FAKE_DIR/projects.get.err.once"   # first get fails, second succeeds
t_capture board_sync "$BARE" --bind SCAF; t_assert_rc 0 "bare bind ok"
t_capture board_binding_read "$BARE"; t_assert_eq "SCAF" "$T_OUT" "bare binding written"
t_capture grep -c 'spaces create Ossify project SCAF' "$BOARD_FAKE_LOG"; t_assert_eq 1 "$T_OUT" "typed project created"
t_capture grep -c 'issues create' "$BOARD_FAKE_LOG"; t_assert_eq 0 "$T_OUT" "bare: nothing mirrored"

# 9. dispatcher path (set -euo pipefail) — the lib must survive strict mode
: > "$BOARD_FAKE_LOG"; cp "$F/empty.json" "$WS/.ossify/project-state.json"; echo '[{"name":"Ossify project","roles":[{"name":"agent"}]}]' > "$BOARD_FAKE_DIR/spaces.types.list.json"
t_capture bash "$ROOT/bin/board" sync "$WS" --force; t_assert_rc 0 "dispatcher: empty state syncs"
t_capture bash "$ROOT/bin/board" digest "$WS"; t_assert_eq 64 "${#T_OUT}" "dispatcher: digest"
echo '[{"name":"Classic project"}]' > "$BOARD_FAKE_DIR/spaces.types.list.json"
t_capture bash "$ROOT/bin/board" sync "$WS" --force; t_assert_rc 5 "dispatcher: type missing propagates rc 5 under strict mode"; t_assert_contains "$T_OUT" "Settings" "dispatcher: rc-5 message still prints"
t_summary
