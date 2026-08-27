#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
ROOT="$HERE/.."; . "$ROOT/lib/cli.sh"; . "$ROOT/lib/resolve.sh"; . "$ROOT/lib/setup.sh"; . "$ROOT/lib/sync.sh"
F="$HERE/fixtures/state"
mkws() { local d; d="$(mktemp -d)/pt-ai"; mkdir -p "$d/.ossify"; cp "$1" "$d/.ossify/project-state.json"; echo "$d"; }
fresh_fake() { export BOARD_FAKE_LOG="$1/calls.log" BOARD_FAKE_DIR="$1/fake" BOARD_HULY_BIN="$HERE/fake/huly"; mkdir -p "$BOARD_FAKE_DIR"; : > "$BOARD_FAKE_LOG"
  echo '{"taskTypes":[{"id":"tt1","name":"Spine","projectTypeName":"Ossify project"},{"id":"tt2","name":"Work item","projectTypeName":"Ossify project"}],"total":2}' > "$BOARD_FAKE_DIR/task-types.list.json"
  echo '{"permissions":[{"id":"core:permission:CreateObject","label":"Create object"},{"id":"core:permission:UpdateObject","label":"Update object"},{"id":"core:permission:DeleteObject","label":"Delete object"}],"total":3}' > "$BOARD_FAKE_DIR/spaces.permissions.list.json"
  echo '{"identifier":"PTRD","name":"pulse-trader","defaultStatus":"Backlog","statuses":["Backlog","Todo","New state","Won","Lost","planned","active","complete","abandoned"]}' > "$BOARD_FAKE_DIR/projects.get.json"
  echo '{"blockedBy":[],"blocks":[],"relations":[],"documents":[]}' > "$BOARD_FAKE_DIR/issues.relations.list.json"; }
# sync-scope ops only: setup's idempotent task-type/status/role creates are not drift mutations
mutations() { awk 'index($0,"milestones create ")||index($0,"milestones update ")||index($0,"issues create ")||index($0,"issues update ")||index($0,"relations add")||index($0,"milestone set")||index($0,"labels add"){n++} END{print n+0}' "$BOARD_FAKE_LOG"; }
unset HULY_EMAIL HULY_URL HULY_WORKSPACE HULY_TOKEN   # hermeticity: the digest gate compares the destination too; every case runs with these unset unless it exports its own

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
# milestones create has no status flag (always lands "planned"): a non-planned desired status
# is set right after creation, in the same run — known-answer: releases whose mapped status != planned
NON_PLANNED_MS="$(jq -f "$ROOT/lib/map.jq" "$F/pulse-trader.json" | jq '[.milestones[] | select(.status != "planned")] | length')"
t_capture grep -c 'milestones update' "$BOARD_FAKE_LOG"; t_assert_eq "$NON_PLANNED_MS" "$T_OUT" "non-planned milestone status set at creation, not a second run"
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
jq '[.issues[] | {identifier: ("PTRD-" + (.key|gsub("\\.";""))), title: .title, status: .status, milestone: (if .milestone_key then {label: (.milestone_key + " — x")} else null end), labels: (if .label then [{title: .label}] else [] end)}]' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/issues.list.json"
# the fake answers every relations.list call with the same file: the union of every edge's target,
# so each from-issue's blockedBy check finds its target regardless of which identifier asked
jq '{blockedBy: [.relations[] | {identifier: ("PTRD-" + (.to_key|gsub("\\.";"")))}]}' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/issues.relations.list.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "force on matching board ok"
t_assert_eq 0 "$(mutations)" "matching board: zero mutations"
t_capture jq -r '.unchanged' <<<"$T_OUT"; t_assert_eq 15 "$T_OUT" "all 15 reported unchanged"
# zero-call witness for HULY_EMAIL unset (case 10 below covers it set): a --force sync that
# reaches mirroring still makes no membership call when the email is not configured
t_capture grep -c 'spaces members add' "$BOARD_FAKE_LOG"; t_assert_eq 0 "$T_OUT" "HULY_EMAIL unset: zero members-add calls"

# 4b. known-answer: the result-wrapped issues-list shape (data-dependent — a creator with no
# person record) must not change behavior against the same matching board
jq '{result: .}' "$BOARD_FAKE_DIR/issues.list.json" > "$BOARD_FAKE_DIR/issues.list.json.wrapped" && mv "$BOARD_FAKE_DIR/issues.list.json.wrapped" "$BOARD_FAKE_DIR/issues.list.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "result-wrapped issues list: force sync ok"
t_assert_eq 0 "$(mutations)" "result-wrapped issues list: zero mutations"
# reset to the bare-array shape: case 5 and after expect it
jq '.result' "$BOARD_FAKE_DIR/issues.list.json" > "$BOARD_FAKE_DIR/issues.list.json.bare" && mv "$BOARD_FAKE_DIR/issues.list.json.bare" "$BOARD_FAKE_DIR/issues.list.json"

# 4c. destination change defeats the digest gate: same file, different HULY_WORKSPACE ->
# a full (non-skipped) run; against the matching board it still mutates nothing
: > "$BOARD_FAKE_LOG"
export HULY_WORKSPACE=elsewhere
t_capture board_sync "$WS"; t_assert_rc 0 "dest change: rc 0"
t_capture jq -r '.skipped' <<<"$T_OUT"; t_assert_eq "null" "$T_OUT" "dest change: gate falls through, not skipped"
t_assert_eq 0 "$(mutations)" "dest change: zero mutations against a matching board"
unset HULY_WORKSPACE
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS"; t_assert_rc 0 "dest restored: rc 0"
t_capture jq -r '.skipped' <<<"$T_OUT"; t_assert_eq "null" "$T_OUT" "dest restored: one more full run rewrites dest"

# 4d. a live holder's lock: sync skips as "locked", zero CLI calls, lock left alone
mkdir -p "$WS/.board/lock"; echo $$ > "$WS/.board/lock/pid"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "locked: rc 0"
t_capture jq -r '.skipped' <<<"$T_OUT"; t_assert_eq "locked" "$T_OUT" "locked: skipped"
t_assert_eq 0 "$(wc -l < "$BOARD_FAKE_LOG" | tr -d ' ')" "locked: zero CLI calls"
[ -d "$WS/.board/lock" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: locked: another holder's lock must not be removed"; }

# 4e. a dead holder's lock is stolen, the sync proceeds, and the lock is gone afterwards
( : ) & DEAD=$!; wait "$DEAD" 2>/dev/null
echo "$DEAD" > "$WS/.board/lock/pid"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "stale lock: stolen, sync ok"
t_capture jq -r '.skipped' <<<"$T_OUT"; t_assert_eq "null" "$T_OUT" "stale lock: not skipped"
[ ! -d "$WS/.board/lock" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: stale lock: lock not cleaned up after the run"; }

# 4e2. a young lock with no pid yet is a holder mid-acquisition, not debris: skip, don't steal
mkdir -p "$WS/.board/lock"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "young pid-less lock: rc 0"
t_capture jq -r '.skipped' <<<"$T_OUT"; t_assert_eq "locked" "$T_OUT" "young pid-less lock: skipped, not stolen"
[ -d "$WS/.board/lock" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: young pid-less lock must be left alone"; }
rm -rf "$WS/.board/lock"

# 4f. --bind conflicting with the existing binding: rc 7, nothing touched; a matching
# --bind (the documented rerun path after rc 6) still proceeds
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --bind OTHER; t_assert_rc 7 "bind conflict -> rc 7"
t_assert_contains "$T_OUT" "already bound to 'PTRD'" "bind conflict: names the existing binding"
t_capture board_binding_read "$WS"; t_assert_eq "PTRD" "$T_OUT" "bind conflict: binding unchanged"
t_assert_eq 0 "$(wc -l < "$BOARD_FAKE_LOG" | tr -d ' ')" "bind conflict: zero CLI calls"
t_capture board_sync "$WS" --force --bind PTRD; t_assert_rc 0 "matching --bind: proceeds"
t_capture board_sync "$WS" --bind; t_assert_rc 2 "--bind without a value -> usage error rc 2"
t_assert_contains "$T_OUT" "requires an identifier" "--bind without a value: message"

# 4g. milestone listing at the 200 cap: refuse to reconcile (the CLI has no pagination —
# a truncated listing would re-create anything past the cap as a permanent duplicate)
jq -n '[range(200) | {label: ("m\(.) — x"), status: "planned"}]' > "$BOARD_FAKE_DIR/milestones.list.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 1 "milestones at cap -> rc 1"
t_assert_eq 0 "$(mutations)" "milestones at cap: zero mutations"
t_capture tail -1 "$WS/.board/sync.log"; t_assert_contains "$T_OUT" "200-item limit" "milestones at cap: logged"
jq '[.milestones[] | {label: .title, status: .status, _id: .key}]' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/milestones.list.json"

# 4h. a hand-rebound .board/config.json defeats the digest gate: same digest + dest, new
# project -> full run, not skipped:"unchanged"
board_binding_write "$WS" PTRD2
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS"; t_assert_rc 0 "rebind: rc 0"
t_capture jq -r '.skipped' <<<"$T_OUT"; t_assert_eq "null" "$T_OUT" "rebind: gate falls through"
board_binding_write "$WS" PTRD
t_capture board_sync "$WS" --force; t_assert_rc 0 "rebind restored"

# 4i. a tab in a title would shift the TSV records the reconcile iterates: refuse loudly,
# mutate nothing
jq '(.work_items[0].title) = "Tauri\tshell"' "$F/pulse-trader.json" > "$WS/.ossify/project-state.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 1 "tab in title -> rc 1"
t_assert_eq 0 "$(mutations)" "tab in title: zero mutations"
t_capture tail -1 "$WS/.board/sync.log"; t_assert_contains "$T_OUT" "tab or newline" "tab in title: logged"
cp "$F/pulse-trader.json" "$WS/.ossify/project-state.json"

# 4j. a listing that omits the labels field must not freeze the label out: the add is
# attempted (CONFLICT would mean already there); exactly one labels-add for the one entry
jq 'map(if (.title|startswith("r1.s1 ")) then del(.labels) else . end)' "$BOARD_FAKE_DIR/issues.list.json" > "$BOARD_FAKE_DIR/issues.list.json.t" && mv "$BOARD_FAKE_DIR/issues.list.json.t" "$BOARD_FAKE_DIR/issues.list.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "labels field absent: ok"
t_capture grep -c 'labels add' "$BOARD_FAKE_LOG"; t_assert_eq 1 "$T_OUT" "labels field absent: exactly one add"
t_capture grep 'labels add' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" "PTRD-r1s1 --label spine:bone" "labels field absent: the right spine, the right label"
jq '[.issues[] | {identifier: ("PTRD-" + (.key|gsub("\\.";""))), title: .title, status: .status, milestone: (if .milestone_key then {label: (.milestone_key + " — x")} else null end), labels: (if .label then [{title: .label}] else [] end)}]' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/issues.list.json"

# 5. known-answer negative: flip one work item status -> exactly one issues update, nothing else
jq '(.work_items[] | select(.id=="r1.s1.w3") | .status) = "active"' "$F/pulse-trader.json" > "$WS/.ossify/project-state.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS"; t_assert_rc 0 "flip: ok"
t_assert_eq 1 "$(mutations)" "flip: exactly one mutation"
t_capture grep 'issues update' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" "PTRD-r1s1w3 --status active" "flip: the right item, the right status"

# 5b. label drift: actual exposes labels ([{title:...}], the recorded shape) and one spine lacks
# its class label -> exactly one labels add
jq -f "$ROOT/lib/map.jq" "$WS/.ossify/project-state.json" > "$BOARD_FAKE_DIR/desired.json"
jq '[.issues[] | {identifier: ("PTRD-" + (.key|gsub("\\.";""))), title: .title, status: .status, milestone: (if .milestone_key then {label: (.milestone_key + " — x")} else null end), labels: (if .label then [{title: .label}] else [] end)}] | map(if (.title|startswith("r1.s1 ")) then .labels = [] else . end)' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/issues.list.json"
: > "$BOARD_FAKE_LOG"
t_capture board_sync "$WS" --force; t_assert_rc 0 "label drift: ok"
t_assert_eq 1 "$(mutations)" "label drift: exactly one mutation"
t_capture grep 'labels add' "$BOARD_FAKE_LOG"; t_assert_contains "$T_OUT" "PTRD-r1s1 --label spine:bone" "label drift: the spine, the class label"

# 5c. milestone drift: one spine attached to the wrong milestone -> exactly one milestone set
jq '[.issues[] | {identifier: ("PTRD-" + (.key|gsub("\\.";""))), title: .title, status: .status, milestone: (if .milestone_key then {label: (.milestone_key + " — x")} else null end), labels: (if .label then [{title: .label}] else [] end)}] | map(if (.title|startswith("r1.s2 ")) then .milestone = {label:"r0 — Release 0"} else . end)' "$BOARD_FAKE_DIR/desired.json" > "$BOARD_FAKE_DIR/issues.list.json"
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

# 6b. issues-list failure: the log carries THIS call's error code. (The lookup used to run
# inside a command substitution, so board_cli's error file update was lost to the subshell
# and the log showed a stale code from the previous parent-shell CLI call.)
echo 3 > "$BOARD_FAKE_DIR/issues.list.rc"; echo '{"code":"INTEGRATION_FAILED","message":"integration down"}' > "$BOARD_FAKE_DIR/issues.list.err"
t_capture board_sync "$WS" --force; t_assert_rc 1 "issues-list failure -> rc 1"
t_capture tail -1 "$WS/.board/sync.log"; t_assert_contains "$T_OUT" "issues list" "issues-list failure: step named"
t_capture tail -1 "$WS/.board/sync.log"; t_assert_contains "$T_OUT" "INTEGRATION_FAILED" "issues-list failure: the real code, not a stale one"
rm -f "$BOARD_FAKE_DIR/issues.list.rc" "$BOARD_FAKE_DIR/issues.list.err"

# 7. task-types gate fails INTEGRATION_FAILED (the type doesn't exist) -> rc 5 before any mutation
: > "$BOARD_FAKE_LOG"
echo 1 > "$BOARD_FAKE_DIR/task-types.list.rc.once"
echo '{"code":"INTEGRATION_FAILED","message":"did not resolve to exactly one project type"}' > "$BOARD_FAKE_DIR/task-types.list.err.once"
t_capture board_sync "$WS" --force; t_assert_rc 5 "type missing -> 5"; t_assert_eq 0 "$(mutations)" "type missing: zero mutations"

# 8a. bare binding, project already exists: bind succeeds, binding written, nothing mirrored
BARE="$(mktemp -d)/scaf-ai"; mkdir -p "$BARE"; fresh_fake "$(dirname "$BARE")"
t_capture board_sync "$BARE" --bind SCAF; t_assert_rc 0 "bare bind (project exists): ok"
t_capture board_binding_read "$BARE"; t_assert_eq "SCAF" "$T_OUT" "bare binding written"
t_capture grep -c 'issues create' "$BOARD_FAKE_LOG"; t_assert_eq 0 "$T_OUT" "bare (project exists): nothing mirrored"

# 8b. bare binding, project missing: typed creation is UI-only, so this is now a hard stop —
# rc 6, the message points at Tracker, no binding written, no creation attempted
BARE2="$(mktemp -d)/scaf2-ai"; mkdir -p "$BARE2"; fresh_fake "$(dirname "$BARE2")"
echo 5 > "$BOARD_FAKE_DIR/projects.get.rc"; echo '{"code":"NOT_FOUND","message":"no"}' > "$BOARD_FAKE_DIR/projects.get.err"
t_capture board_sync "$BARE2" --bind SCF2; t_assert_rc 6 "bare bind (project missing): rc 6"
t_assert_contains "$T_OUT" "Tracker" "bare bind (project missing): message points at Tracker"
t_capture board_binding_read "$BARE2"; t_assert_rc 4 "bare bind (project missing): binding not written"
t_capture grep -c 'issues create' "$BOARD_FAKE_LOG"; t_assert_eq 0 "$T_OUT" "bare (project missing): no creation attempted"

# 8c. --bind onto an existing project of the WRONG type (Classic statuses): rc 9 before
# any project-scoped action — no members-add, no mutation, no binding written
BARE4="$(mktemp -d)/scf4-ai"; mkdir -p "$BARE4"; fresh_fake "$(dirname "$BARE4")"
echo '{"identifier":"SCF4","name":"x","defaultStatus":"Backlog","statuses":["Backlog","Todo","In Progress","Done","Canceled"]}' > "$BOARD_FAKE_DIR/projects.get.json"
export HULY_EMAIL=agent@x.local
t_capture board_sync "$BARE4" --bind SCF4; t_assert_rc 9 "wrong-type project -> rc 9"
unset HULY_EMAIL
t_assert_contains "$T_OUT" "not an Ossify project" "wrong type: message names the problem"
t_capture grep -c 'spaces members add' "$BOARD_FAKE_LOG"; t_assert_eq 0 "$T_OUT" "wrong type: members-add blocked too"
t_assert_eq 0 "$(mutations)" "wrong type: zero mutations"
t_capture board_binding_read "$BARE4"; t_assert_rc 4 "wrong type: binding not written"

# 8d. bare binding from a git subdirectory: .board lands at the repository root, not the cwd
BARE5="$(mktemp -d)/repo"; mkdir -p "$BARE5/docs"; git -C "$(dirname "$BARE5")" init -q "$BARE5" 2>/dev/null || git init -q "$BARE5"
fresh_fake "$(dirname "$BARE5")"
t_capture board_sync "$BARE5/docs" --bind SCF5; t_assert_rc 0 "bare bind from subdir: ok"
[ -f "$BARE5/.board/config.json" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: bare bind from subdir: config not at the git root"; }
[ ! -e "$BARE5/docs/.board" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: bare bind from subdir: .board created in the subdir"; }

# 9. dispatcher path (set -euo pipefail) — the lib must survive strict mode
# re-point the fake at $WS's own directory: 8a/8b repointed BOARD_FAKE_DIR/LOG at their
# bare-binding temp dirs (case 8b even left a projects.get NOT_FOUND override in place)
fresh_fake "$(dirname "$WS")"
cp "$F/empty.json" "$WS/.ossify/project-state.json"
t_capture bash "$ROOT/bin/board" sync "$WS" --force; t_assert_rc 0 "dispatcher: empty state syncs"
t_capture bash "$ROOT/bin/board" digest "$WS"; t_assert_eq 64 "${#T_OUT}" "dispatcher: digest"
echo 1 > "$BOARD_FAKE_DIR/task-types.list.rc.once"
echo '{"code":"INTEGRATION_FAILED","message":"did not resolve to exactly one project type"}' > "$BOARD_FAKE_DIR/task-types.list.err.once"
t_capture bash "$ROOT/bin/board" sync "$WS" --force; t_assert_rc 5 "dispatcher: type missing propagates rc 5 under strict mode"; t_assert_contains "$T_OUT" "Spine" "dispatcher: rc-5 message still prints"
# no-argument invocations are usage errors, not set -u aborts or silent exits
t_capture bash "$ROOT/bin/board" sync; t_assert_rc 2 "dispatcher: sync without a directory -> rc 2"
t_assert_contains "$T_OUT" "requires a directory" "dispatcher: sync usage message"
t_capture bash "$ROOT/bin/board" digest; t_assert_rc 2 "dispatcher: digest without a directory -> rc 2"
t_capture bash "$ROOT/bin/board" sync "$WS" --bind; t_assert_rc 2 "dispatcher: --bind without a value under strict mode -> rc 2"
t_capture bash "$ROOT/bin/board" digest "$(mktemp -d)"; t_assert_rc 3 "dispatcher: digest outside any workspace -> rc 3 with a message"
t_assert_contains "$T_OUT" "no .ossify workspace" "dispatcher: digest no-workspace message"

# 10. HULY_EMAIL set: membership self-ensure fires exactly once, argv carries the project name
# (from projects.get.json: "pulse-trader") and the email
fresh_fake "$(dirname "$WS")"
: > "$BOARD_FAKE_LOG"
export HULY_EMAIL=agent@x.local
t_capture board_sync "$WS" --force; t_assert_rc 0 "HULY_EMAIL set: force sync ok"
unset HULY_EMAIL
t_capture grep -c 'spaces members add' "$BOARD_FAKE_LOG"; t_assert_eq 1 "$T_OUT" "HULY_EMAIL set: exactly one members-add call"
t_capture grep 'spaces members add' "$BOARD_FAKE_LOG"
t_assert_contains "$T_OUT" "pulse-trader" "members-add argv carries the project name"
t_assert_contains "$T_OUT" "agent@x.local" "members-add argv carries the email"
t_summary
