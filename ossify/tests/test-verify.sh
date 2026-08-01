#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/harness.sh"
for lib in id state manifest commands entities registries ledger demo doctor verify; do . "$HERE/../lib/$lib.sh"; done
TMP="$(mktemp -d)"; SPEC="$TMP/spec.md"

cat > "$SPEC" <<'EOF'
## 5. Acceptance criteria
- [ ] AC-1 auto: `true` → expected: exit 0
- [ ] AC-2 auto: `false` → expected: exit 1
- [ ] AC-3 auto: `echo 42 passed` → expected: output contains 42 passed
- [X] AC-10 auto: `true` → expected: exit 0
- [ ] AC-4 user: open the dashboard and see the new card
EOF

t_capture oss_verify_parse_acs "$SPEC"
t_assert_eq "4" "$(printf '%s\n' "$T_OUT" | grep -c .)" "parses 4 auto ACs and skips the user: row"
t_assert_contains "$T_OUT" "AC-1" "labels captured"
# A checked, UPPERCASE-X checkbox must still yield a bare label. Anchoring the
# extraction on a case class instead of the checkbox silently emits the whole
# line as the label, which report_cross_check then fails to find.
t_assert_contains "$T_OUT" "AC-10	true	exit 0" "an uppercase [X] checkbox still yields a bare label"
# Backticks MUST be stripped: an unstripped command is run as a command
# substitution by the caller's eval, executing something entirely different.
case "$T_OUT" in *'`'*) T_FAIL=$((T_FAIL+1)); echo "FAIL: backticks survived the parse";; *) T_PASS=$((T_PASS+1));; esac

t_capture oss_verify_auto_step "$TMP" "true" "exit 0";           t_assert_rc 0 "exit 0 expectation passes"
t_capture oss_verify_auto_step "$TMP" "false" "exit 0";          t_assert_rc 1 "exit 0 expectation fails on rc 1"
t_capture oss_verify_auto_step "$TMP" "false" "exit 1";          t_assert_rc 0 "exit 1 expectation passes on rc 1"
t_capture oss_verify_auto_step "$TMP" "echo 42 passed" "output contains 42 passed"; t_assert_rc 0 "contains expectation passes"
t_capture oss_verify_auto_step "$TMP" "echo nope" "output contains 42 passed";      t_assert_rc 1 "contains expectation fails"
t_assert_contains "$T_OUT" "output missing '42 passed'" "a failing contains expectation names what was missing, not a silent dump"
# An embedded U+2192 arrow inside the command/expectation text itself (not
# just the grammar's separator arrow) must not confuse the greedy `.*→` split
# (named risk #3).
ARROW_SPEC="$TMP/arrow-spec.md"
printf -- '- [ ] AC-5 auto: `printf '"'"'a \xe2\x86\x92 b'"'"'` \xe2\x86\x92 expected: output contains a \xe2\x86\x92 b\n' > "$ARROW_SPEC"
t_capture oss_verify_parse_acs "$ARROW_SPEC"
t_assert_eq "$(printf 'AC-5\tprintf \x27a \xe2\x86\x92 b\x27\toutput contains a \xe2\x86\x92 b')" "$T_OUT" "an embedded arrow inside the command/expectation text does not confuse the separator split"

t_capture oss_verify_auto_step "$TMP" "true" "exit banana";      t_assert_rc 2 "a malformed expectation is rc 2, never a silent pass"
t_capture oss_verify_auto_step "$TMP" "true" "whatever";         t_assert_rc 2 "an unrecognized expectation form is rc 2"

# Vacuous-green scoping (named risk #4): the guard is scoped to `exit 0` only.
# A command whose text names a recognized runner and whose output happens to
# ALSO contain a zero-tests phrase, but which legitimately expects exit 1,
# must still pass — an unscoped guard would flag it vacuous regardless of
# what was actually expected.
t_capture oss_verify_auto_step "$TMP" "printf 'collected 0 items'; false # pytest" "exit 1"
t_assert_rc 0 "a legitimate exit 1 from a recognized runner is not flagged vacuous"
# ...and the OTHER direction: a recognized runner reporting zero tests fails
# exit 0 even though the rc genuinely matched. Not just the standalone guard
# function (tested above) — the wiring into auto_step itself.
t_capture oss_verify_auto_step "$TMP" "printf 'collected 0 items'; true # pytest" "exit 0"
t_assert_rc 1 "a vacuous exit 0 from a recognized runner fails through auto_step, not just the standalone guard"

# zero-tests guard: BOTH conditions required (recognized runner AND zero-tests output).
printf 'collected 0 items\n' | oss_verify_zero_tests_guard "pytest tests/"; t_assert_eq "0" "$?" "vacuous green detected"
printf 'collected 9 items\n' | oss_verify_zero_tests_guard "pytest tests/"; t_assert_eq "1" "$?" "a real run is not vacuous"
printf 'collected 0 items\n' | oss_verify_zero_tests_guard "echo hi";       t_assert_eq "1" "$?" "a non-runner merely MENTIONING a zero-tests phrase is not vacuous"

# RED gate: rc 1 (already GREEN) is the ONLY hard block; rc 2 (errored) is advisory.
t_capture oss_verify_redgate "$TMP" "false" "exit 0";            t_assert_rc 0 "a failing command is RED"
t_capture oss_verify_redgate "$TMP" "true" "exit 0";             t_assert_rc 1 "an already-passing command is already-GREEN"
t_capture oss_verify_redgate "$TMP" "nosuchcommand_xyz" "exit 0";t_assert_rc 2 "an uninvocable command is errored, not already-GREEN"

# report cross-check: every auto AC in the spec must appear in the report.
cat > "$TMP/report.md" <<'EOF'
## 3. ACs — verification status
| AC | Status |
|---|---|
| AC-1 | pass |
| AC-2 | pass |
EOF
t_capture oss_verify_report_cross_check "$TMP/report.md" "$SPEC"
t_assert_rc 1 "cross-check fails when the report omits an AC"
t_assert_contains "$T_OUT" "AC-3" "...and names the missing one"
# The spec fixture's 4th auto AC is AC-10 (used above to test the checkbox-
# anchored label extraction) — a report accounting for "every auto AC" must
# include it too, not just AC-1..AC-3.
printf '| AC-3 | fail |\n| AC-10 | pass |\n' >> "$TMP/report.md"
t_capture oss_verify_report_cross_check "$TMP/report.md" "$SPEC"
t_assert_rc 0 "cross-check passes when every auto AC is accounted for"

# Word-boundary regression: AC-10 legitimately present in the report must NOT
# satisfy a search for AC-1 via substring match ("AC-10" contains "AC-1" as a
# literal prefix). A report naming AC-10 but omitting AC-1 must still fail,
# and must name AC-1 (not AC-10) as the missing one.
cat > "$TMP/report-boundary.md" <<'EOF'
| AC-10 | pass |
| AC-2 | pass |
| AC-3 | pass |
EOF
t_capture oss_verify_report_cross_check "$TMP/report-boundary.md" "$SPEC"
t_assert_rc 1 "AC-10's presence in the report does not satisfy a search for AC-1"
t_assert_contains "$T_OUT" "does not account for: AC-1" "...and AC-1 (not AC-10) is named missing"

OSSB="$HERE/../bin/oss"
t_capture bash "$OSSB" verify_step "$TMP" "false" "exit 1"
t_assert_rc 0 "dispatcher: a command that exits 1 against 'exit 1' PASSES (does not abort under set -e)"
t_capture bash "$OSSB" verify_step "$TMP" "false" "exit 0"
t_assert_rc 1 "dispatcher: a failing AC returns 1 with a diagnostic, not a strict-mode abort"
t_assert_contains "$T_OUT" "wanted" "dispatcher: the failing arm emitted its rc diagnostic rather than dying silently"
t_capture bash "$OSSB" verify_step "$TMP" "true" "whatever"
t_assert_rc 2 "dispatcher: malformed expectation is rc 2"
t_capture bash "$OSSB" redgate "$TMP" "false" "exit 0"
t_assert_rc 0 "dispatcher: a genuinely failing command is RED (rc 0), not an abort"
t_capture bash "$OSSB" redgate "$TMP" "true" "exit 0"
t_assert_rc 1 "dispatcher: already-GREEN is the hard block"
t_capture bash "$OSSB" redgate "$TMP" "nosuchcommand_xyz" "exit 0"
t_assert_rc 2 "dispatcher: an uninvocable command is advisory rc 2, not 127"

rm -rf "$TMP"; t_summary
