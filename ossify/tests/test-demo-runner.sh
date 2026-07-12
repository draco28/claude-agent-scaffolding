#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
. "$HERE/../lib/id.sh"; . "$HERE/../lib/state.sh"; . "$HERE/../lib/ledger.sh"; . "$HERE/../lib/demo.sh"
TMP="$(mktemp -d)"; S="$TMP/state.json"
oss_state_init "$S" demo-run >/dev/null

oss_ledger_add_auto "$S" r0.s1 "always true" "true" "exit:0" >/dev/null
oss_ledger_add_auto "$S" r0.s1 "greets" "echo hello-world" "contains:hello" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 0 "all green"; t_assert_contains "$T_OUT" "PASS 2" "pass count"

oss_ledger_add_auto "$S" r0.s1 "always false" "false" "exit:0" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 1 "halt on first fail"; t_assert_contains "$T_OUT" "FAIL d3" "failing line named"

oss_ledger_quarantine "$S" d3 "flaky env, fix by r1 close" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 0 "quarantined line skipped"; t_assert_contains "$T_OUT" "SKIP" "skip reported"

oss_ledger_add_auto "$S" r0.s1 "vacuous suite" "echo 'collected 0 items'; true" "exit:0" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 1 "vacuous green caught"; t_assert_contains "$T_OUT" "vacuous-green" "guard named"

rm -rf "$TMP"
t_summary
