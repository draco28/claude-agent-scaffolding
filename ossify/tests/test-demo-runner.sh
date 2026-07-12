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

oss_ledger_add_auto "$S" r0.s1 "vacuous suite" "echo 'collected 0 items' # pytest" "exit:0" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 1 "vacuous green caught"; t_assert_contains "$T_OUT" "vacuous-green" "guard named"

# Retire the vacuous line (d4) so the halt-on-first-fail run can reach the next assertion.
oss_ledger_retire "$S" d4 "test cleanup" >/dev/null

# A legitimate demo line that merely mentions a zero-tests phrase in its output —
# but is NOT a test runner — must NOT be flagged vacuous-green (AND-gate precision).
oss_ledger_add_auto "$S" r0.s1 "legit zero-passing mention" "echo '0 passing warnings remain'" "contains:0 passing" >/dev/null
t_capture oss_demo_run_auto "$S"
t_assert_rc 0 "non-runner output mentioning a zero-tests phrase is NOT vacuous-green"

# Fix 3: a missing/unreadable state file must be a guarded rc-1 error, not an
# unguarded jq exit-2 abort under the dispatcher's `set -e` (which collides
# with the rc-2 "usage error" convention). Exercised through the real
# dispatcher (bin/oss), not the bare lib function, so `set -e` is actually in
# effect the way it is in production use.
t_capture "$HERE/../bin/oss" demo_run /nonexistent/state.json
t_assert_rc 1 "missing state file is rc 1, not rc 2, via dispatcher"
t_assert_contains "$T_OUT" "cannot read state" "error message names the problem"

rm -rf "$TMP"
t_summary
