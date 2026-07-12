#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/entities.sh"
. "$HERE/../lib/registries.sh"; . "$HERE/../lib/ledger.sh"; . "$HERE/../lib/demo.sh"; . "$HERE/../lib/doctor.sh"
OSS="$HERE/../bin/oss"
TMP="$(mktemp -d)"; S="$TMP/.ossify/project-state.json"

# Fixture: a skeleton-first project from init to a passing cumulative demo.
oss_state_init "$S" fixture >/dev/null
R="$(oss_entity_add_release "$S" "Skeleton" "core loop usable")"
SP="$(oss_entity_add_spine "$S" "$R" "walking skeleton" bone canonical)"
oss_entity_add_work_item "$S" "$SP" "wire the entry point" >/dev/null
oss_reg_add_bone "$S" ADR-0002 "domain boundary" "src/domain/**" "" >/dev/null
oss_reg_add_fake "$S" coach fake "shell for skeleton" "first refinement" r1 >/dev/null
oss_ledger_add_auto "$S" "$SP" "golden journey" "echo journey-ok" "contains:journey-ok" >/dev/null
oss_ledger_add_user "$S" "$SP" "Run a backtest from the chat panel" "results visible" >/dev/null

t_capture oss_demo_run_auto "$S";  t_assert_rc 0 "fixture demo green"
t_capture "$OSS" doctor "$S";      t_assert_rc 0 "doctor green on full fixture"
t_capture oss_state_replay "$S";   t_assert_rc 0 "full fixture replays clean"
t_capture oss_reg_touch_check "$S" src/domain/x.rs; t_assert_rc 0 "touch check hits bone"

rm -rf "$TMP"
t_summary
