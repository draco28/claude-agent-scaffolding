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

# Take the vacuous line (d4) out of the active run so the halt-on-first-fail run
# can reach the next assertion. D1 (Plan C1 Task 2) made retire a PLANNING verb
# that only records a pending amendment - applied by a spine's close, and now
# validated against a real spine id - so it no longer clears d4 out of the
# active set on the spot, and this fixture defines no spine to amend against.
# Quarantine is the immediate verb (a close/doctor-time action on a line that
# actually fails, requiring only that the line exist - see d3 above) and is
# what this fixture actually needs: d4 out of the run immediately, no spine.
oss_ledger_quarantine "$S" d4 "test cleanup" >/dev/null

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

# --- Final review finding 1 (runner half). The ledger is APPEND-ONLY, so a line
# whose `expected` slipped past an older, looser validator is re-run and
# re-reported at every future close. The runner must therefore FAIL CLOSED on an
# operand it cannot compare, not fall out of the `case` (or let `[` exit 2, which
# the `if` reads as false) and count the line as passed. Injected straight into
# state because the validator now correctly refuses to create such a line.
T2="$(mktemp -d)"; S2="$T2/state.json"
oss_state_init "$S2" demo-malformed >/dev/null
oss_ledger_add_auto "$S2" r0.s1 "legacy line, malformed operand" "exit 1" "exit:0" >/dev/null
jq '.demo_ledger[0].expected = "exit:0 (tests green)"' "$S2" > "$S2.x" && mv "$S2.x" "$S2"
t_capture oss_demo_run_auto "$S2"
t_assert_rc 1 "malformed exit: operand FAILS the line (was: silently counted as PASS)"
t_assert_contains "$T_OUT" "FAIL d1" "the malformed line is named"

# An `expected` the runner recognizes not at all must also fail closed. The
# command here exits 0, so a rc 0 can only come from the fall-through — this is
# the assertion that distinguishes "fails closed" from "the command happened to
# fail" above.
jq '.demo_ledger[0].expected = "under 40ms" | .demo_ledger[0].command = "true"' "$S2" > "$S2.x" && mv "$S2.x" "$S2"
t_capture oss_demo_run_auto "$S2"
t_assert_rc 1 "unrecognized expected grammar FAILS the line (fail closed, not fall through)"
t_assert_contains "$T_OUT" "FAIL d1" "the unrecognized-grammar line is named"
rm -rf "$T2"

rm -rf "$TMP"
t_summary
