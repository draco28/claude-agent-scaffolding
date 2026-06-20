#!/usr/bin/env bash
# tests/test-verify.sh — tests for lib/verify.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SD_BIN="$(cd "$HERE/.." && pwd)/bin/sd"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/verify.sh"

# 1. auto step — exit 0 expectation, command succeeds → 0
test_auto_exit0_pass() {
  echo "test_auto_exit0_pass:"
  set +e
  sd_verify_auto_step '- [ ] auto: `true` -> expected: exit 0' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "true expected exit 0 → rc=0" "0" "$rc"
}

# 2. auto step — exit 0 expectation, command fails → 1
test_auto_exit0_fail() {
  echo "test_auto_exit0_fail:"
  set +e
  sd_verify_auto_step '- [ ] auto: `false` -> expected: exit 0' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "false expected exit 0 → rc=1" "1" "$rc"
}

# 3. auto step — exit N expectation matches
test_auto_exit_n_match() {
  echo "test_auto_exit_n_match:"
  set +e
  sd_verify_auto_step '- [ ] auto: `exit 3` -> expected: exit 3' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "exit 3 matches → rc=0" "0" "$rc"
}

# 4. auto step — exit N expectation mismatch
test_auto_exit_n_mismatch() {
  echo "test_auto_exit_n_mismatch:"
  set +e
  sd_verify_auto_step '- [ ] auto: `exit 1` -> expected: exit 3' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "mismatch → rc=1" "1" "$rc"
}

# 5. auto step — invalid exit code expectation
test_auto_exit_n_invalid() {
  echo "test_auto_exit_n_invalid:"
  set +e
  sd_verify_auto_step '- [ ] auto: `true` -> expected: exit nope' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "invalid exit code → rc=2" "2" "$rc"
}

# 6. auto step — output contains pattern matches
test_auto_output_contains_pass() {
  echo "test_auto_output_contains_pass:"
  set +e
  sd_verify_auto_step '- [ ] auto: `echo hello world` -> expected: output contains hello' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "output contains match → rc=0" "0" "$rc"
}

# 7. auto step — output contains pattern miss
test_auto_output_contains_miss() {
  echo "test_auto_output_contains_miss:"
  set +e
  sd_verify_auto_step '- [ ] auto: `echo goodbye` -> expected: output contains hello' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "output miss → rc=1" "1" "$rc"
}

# 8. auto step — unknown expected form returns rc=2
test_auto_unknown_form() {
  echo "test_auto_unknown_form:"
  set +e
  sd_verify_auto_step '- [ ] auto: `true` -> expected: stars align' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "unknown form → rc=2" "2" "$rc"
}

# 9. auto step — missing command parse → rc=2
test_auto_missing_cmd() {
  echo "test_auto_missing_cmd:"
  set +e
  sd_verify_auto_step '- [ ] auto: not in backticks → expected: exit 0' >/dev/null 2>&1
  local rc=$?
  :
  # Could be 1 or 2 depending on interpretation; we expect non-zero.
  assert_ne "malformed → rc!=0" "0" "$rc"
}

# 9. report cross-check — all ACs covered
test_report_cross_check_pass() {
  echo "test_report_cross_check_pass:"
  setup_tmp_repo
  cat > spec.md <<'EOF'
# Spec
## Acceptance criteria
- AC-1: must do thing-A
- AC-2: must do thing-B
EOF
  cat > report.md <<'EOF'
# Report
## AC verification
- AC-1: passed
- AC-2: passed
EOF
  set +e
  sd_verify_report_cross_check report.md spec.md >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "all ACs covered → rc=0" "0" "$rc"
}

# 10. report cross-check — missing AC
test_report_cross_check_missing() {
  echo "test_report_cross_check_missing:"
  setup_tmp_repo
  cat > spec.md <<'EOF'
# Spec
## Acceptance criteria
- AC-1: must do thing-A
- AC-2: must do thing-B
- AC-3: must do thing-C
EOF
  cat > report.md <<'EOF'
# Report
- AC-1: ok
- AC-2: ok
EOF
  set +e
  sd_verify_report_cross_check report.md spec.md >/dev/null 2>&1
  local rc=$?
  :
  assert_ne "missing AC-3 → rc!=0" "0" "$rc"
}

# 11. report cross-check — missing report file
test_report_cross_check_no_report() {
  echo "test_report_cross_check_no_report:"
  setup_tmp_repo
  cat > spec.md <<'EOF'
- AC-1: x
EOF
  set +e
  sd_verify_report_cross_check no-such.md spec.md >/dev/null 2>&1
  local rc=$?
  :
  assert_ne "no report → rc!=0" "0" "$rc"
}

# 12. report cross-check — no ACs in spec → rc=0 (trivially satisfied)
test_report_cross_check_no_acs() {
  echo "test_report_cross_check_no_acs:"
  setup_tmp_repo
  echo "# Spec without acceptance criteria" > spec.md
  echo "# Report" > report.md
  set +e
  sd_verify_report_cross_check report.md spec.md >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "no ACs → rc=0" "0" "$rc"
}

# 13. auto step — stderr also counted by output contains
test_auto_output_includes_stderr() {
  echo "test_auto_output_includes_stderr:"
  set +e
  sd_verify_auto_step '- [ ] auto: `bash -c "echo stderrout >&2"` -> expected: output contains stderrout' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "stderr captured → rc=0" "0" "$rc"
}

# 14. auto step — uses arrow character (U+2192) as alternative separator
test_auto_unicode_arrow() {
  echo "test_auto_unicode_arrow:"
  set +e
  # The line uses real Unicode arrow.
  sd_verify_auto_step "$(printf -- '- [ ] auto: `true` \xe2\x86\x92 expected: exit 0')" >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "unicode arrow accepted → rc=0" "0" "$rc"
}

# 15. report cross-check — prose / blockquote / boilerplate AC mentions must NOT
#     poison the check; only declared AC rows count (PR #41 regression).
test_report_cross_check_ignores_prose() {
  echo "test_report_cross_check_ignores_prose:"
  setup_tmp_repo
  cat > spec.md <<'EOF'
# Spec
## 6. Acceptance criteria (machine-checkable)
> Format is `- [ ] AC-<n> auto: ...`; the gate keys off the real AC-9 ids in prose like this.
- [ ] AC-1 auto: `true` → expected: exit 0
EOF
  cat > report.md <<'EOF'
# Report
- AC-1: passed
EOF
  set +e
  sd_verify_report_cross_check report.md spec.md >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "prose AC-9 / AC-<n> ignored; only the AC-1 row counts → rc=0" "0" "$rc"
}

# 16. report cross-check — `user:` rows are manual (slice-close) and must NOT be
#     required in the work-item report. The grammar says user rows carry NO AC-N;
#     this fixture deliberately MIS-labels one (`AC-2 user:`) to prove the cross-check
#     excludes it even when incorrectly labeled (PR #41 regression).
test_report_cross_check_excludes_user_rows() {
  echo "test_report_cross_check_excludes_user_rows:"
  setup_tmp_repo
  cat > spec.md <<'EOF'
## 6. Acceptance criteria (machine-checkable)
- [ ] AC-1 auto: `true` → expected: exit 0
- [ ] AC-2 user: click Export and confirm a CSV downloads
EOF
  cat > report.md <<'EOF'
# Report
- AC-1: passed
EOF
  set +e
  sd_verify_report_cross_check report.md spec.md >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "mislabeled user-row AC-2 excluded; only auto AC-1 required → rc=0" "0" "$rc"
}

# 17. report cross-check — an AC-looking token INSIDE a command or predicate must NOT
#     become a phantom required outcome; only the leading row label counts (PR #41).
test_report_cross_check_ignores_inline_ac_token() {
  echo "test_report_cross_check_ignores_inline_ac_token:"
  setup_tmp_repo
  cat > spec.md <<'EOF'
## 6. Acceptance criteria (machine-checkable)
- [ ] AC-1 auto: `printf AC-99` → expected: output contains AC-99
EOF
  cat > report.md <<'EOF'
# Report
- AC-1: passed
EOF
  set +e
  sd_verify_report_cross_check report.md spec.md >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "inline AC-99 in command/predicate ignored; only AC-1 required → rc=0" "0" "$rc"
}

# 18. redgate — failing command is RED (gate-pass) -> return 0
test_redgate_red_command() {
  echo "test_redgate_red_command:"
  set +e
  sd_redgate_assert_red 'false'
  local rc=$?
  :
  assert_eq "failing command is RED" "0" "$rc"
}

# 19. redgate — passing command is already GREEN (gate-fail) -> return 1
test_redgate_green_command() {
  echo "test_redgate_green_command:"
  set +e
  sd_redgate_assert_red 'true'
  local rc=$?
  :
  assert_eq "passing command is not RED" "1" "$rc"
}

# 20. redgate — uninvocable command (127) -> ERROR, not RED -> return 2
test_redgate_errored_command() {
  echo "test_redgate_errored_command:"
  set +e
  sd_redgate_assert_red 'this_binary_does_not_exist_xyz'
  local rc=$?
  :
  assert_eq "uninvocable command is an error, not RED" "2" "$rc"
}

# 21. redgate — expected exit N is already GREEN when exit matches -> return 1
test_redgate_expected_exit_n_green() {
  echo "test_redgate_expected_exit_n_green:"
  set +e
  sd_redgate_assert_red 'exit 3' 'exit 3'
  local rc=$?
  :
  assert_eq "matching expected exit N is already GREEN" "1" "$rc"
}

# 22. redgate — uninvocable command is ERROR even if expected says exit 127 -> return 2
test_redgate_expected_exit_127_is_error() {
  echo "test_redgate_expected_exit_127_is_error:"
  set +e
  sd_redgate_assert_red 'this_binary_does_not_exist_xyz' 'exit 127'
  local rc=$?
  :
  assert_eq "exit 127 remains harness ERROR, not GREEN" "2" "$rc"
}

# 23. redgate — invalid expected exit code is ERROR -> return 2
test_redgate_expected_exit_n_invalid() {
  echo "test_redgate_expected_exit_n_invalid:"
  set +e
  sd_redgate_assert_red 'true' 'exit nope'
  local rc=$?
  :
  assert_eq "invalid expected exit code is an error" "2" "$rc"
}

# 24. redgate — expected output missing is RED even when command exits 0 -> return 0
test_redgate_output_contains_missing_is_red() {
  echo "test_redgate_output_contains_missing_is_red:"
  set +e
  sd_redgate_assert_red 'printf goodbye' 'output contains hello'
  local rc=$?
  :
  assert_eq "missing expected output is RED" "0" "$rc"
}

# 25. redgate — expected output present is already GREEN -> return 1
test_redgate_output_contains_present_is_green() {
  echo "test_redgate_output_contains_present_is_green:"
  set +e
  sd_redgate_assert_red 'printf hello' 'output contains hello'
  local rc=$?
  :
  assert_eq "present expected output is already GREEN" "1" "$rc"
}

# 26. redgate — empty command is ERROR, not already GREEN -> return 2
test_redgate_empty_command() {
  echo "test_redgate_empty_command:"
  set +e
  sd_redgate_assert_red ''
  local rc=$?
  :
  assert_eq "empty command is an error" "2" "$rc"
}

# 27. redgate via dispatcher — failing command is RED -> return 0
# Exercises sd_redgate_assert_red through bin/sd (which runs set -euo pipefail),
# proving the set -e-safe if-branch captures the exit code correctly.
test_redgate_dispatcher_red() {
  echo "test_redgate_dispatcher_red:"
  set +e; "$SD_BIN" redgate_assert_red 'false' >/dev/null 2>&1; local rc=$?; set -e
  assert_eq "dispatcher: failing command is RED" "0" "$rc"
}

# 28. redgate via dispatcher — passing command is already-GREEN -> return 1
test_redgate_dispatcher_green() {
  echo "test_redgate_dispatcher_green:"
  set +e; "$SD_BIN" redgate_assert_red 'true' >/dev/null 2>&1; local rc=$?; set -e
  assert_eq "dispatcher: passing command is already-GREEN" "1" "$rc"
}

# 29. redgate via dispatcher — uninvocable command (127) -> ERROR, not RED -> return 2
test_redgate_dispatcher_errored() {
  echo "test_redgate_dispatcher_errored:"
  set +e; "$SD_BIN" redgate_assert_red 'this_binary_does_not_exist_xyz' >/dev/null 2>&1; local rc=$?; set -e
  assert_eq "dispatcher: uninvocable command is errored" "2" "$rc"
}

# 30. redgate via dispatcher — expected predicate is honored under set -e
test_redgate_dispatcher_expected_exit_n_green() {
  echo "test_redgate_dispatcher_expected_exit_n_green:"
  set +e; "$SD_BIN" redgate_assert_red 'exit 3' 'exit 3' >/dev/null 2>&1; local rc=$?; set -e
  assert_eq "dispatcher: matching expected exit N is already-GREEN" "1" "$rc"
}

# 31. redgate via dispatcher — uninvocable command is ERROR even if expected says exit 127
test_redgate_dispatcher_expected_exit_127_is_error() {
  echo "test_redgate_dispatcher_expected_exit_127_is_error:"
  set +e; "$SD_BIN" redgate_assert_red 'this_binary_does_not_exist_xyz' 'exit 127' >/dev/null 2>&1; local rc=$?; set -e
  assert_eq "dispatcher exit 127 remains harness ERROR" "2" "$rc"
}

# 32. redgate via dispatcher — invalid expected exit code is ERROR under set -u
test_redgate_dispatcher_expected_exit_n_invalid() {
  echo "test_redgate_dispatcher_expected_exit_n_invalid:"
  set +e; "$SD_BIN" redgate_assert_red 'true' 'exit nope' >/dev/null 2>&1; local rc=$?; set -e
  assert_eq "dispatcher: invalid expected exit code is errored" "2" "$rc"
}

# ── zero-tests guard (#74) ────────────────────────────────────────────────
# sd_zero_tests_guard <cmd> <captured_output>: 0 = SAFE, 1 = VACUOUS.
# Pure(cmd, output) — fed canned runner output, no real runners invoked.

# 33. pytest — path/name filter collected nothing → VACUOUS
test_ztg_pytest_collected_zero() {
  echo "test_ztg_pytest_collected_zero:"
  set +e
  sd_zero_tests_guard 'pytest tests/x.py::test_foo' \
    "$(printf 'collected 0 items\n\nno tests ran in 0.01s\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "pytest collected 0 → VACUOUS rc=1" "1" "$rc"
}

# 34. pytest -k matched nothing (deselected all) → VACUOUS via "no tests ran"
test_ztg_pytest_k_no_match() {
  echo "test_ztg_pytest_k_no_match:"
  set +e
  sd_zero_tests_guard 'pytest -k nomatch tests/' \
    "$(printf 'collected 12 items / 12 deselected\n\nno tests ran in 0.02s\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "pytest -k no match → VACUOUS rc=1" "1" "$rc"
}

# 35. cargo test — the real incident: filter matched zero, 0 passed / N filtered out
test_ztg_cargo_filtered_all() {
  echo "test_ztg_cargo_filtered_all:"
  set +e
  sd_zero_tests_guard 'cargo test --lib domain::backtest::feed' \
    "$(printf 'running 0 tests\n\ntest result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 209 filtered out\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "cargo 0 passed; 209 filtered out → VACUOUS rc=1" "1" "$rc"
}

# 36. cargo nextest — Starting 0 tests → VACUOUS
test_ztg_nextest_starting_zero() {
  echo "test_ztg_nextest_starting_zero:"
  set +e
  sd_zero_tests_guard 'cargo nextest run -E test(feed)' \
    "$(printf 'Starting 0 tests across 7 binaries (209 skipped)\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "nextest Starting 0 tests → VACUOUS rc=1" "1" "$rc"
}

# 37. go test — package has no _test.go files (only [no test files]) → VACUOUS
test_ztg_go_no_test_files_only() {
  echo "test_ztg_go_no_test_files_only:"
  set +e
  sd_zero_tests_guard 'go test ./pkg/feed/...' \
    "$(printf '?   pkg/feed  [no test files]\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "go [no test files] only → VACUOUS rc=1" "1" "$rc"
}

# 38. go test -run matched nothing (single pkg) → VACUOUS. Modern Go appends
#     "[no tests to run]" to the package's own ok line, so there is no genuine ok.
test_ztg_go_no_tests_to_run() {
  echo "test_ztg_go_no_tests_to_run:"
  set +e
  sd_zero_tests_guard 'go test -run NoMatch ./pkg/feed' \
    "$(printf 'testing: warning: no tests to run\nPASS\nok  \tpkg/feed\t0.001s [no tests to run]\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "go single-pkg no tests to run → VACUOUS rc=1" "1" "$rc"
}

# 39. jest --passWithNoTests, zero found → VACUOUS
test_ztg_jest_passwithnotests() {
  echo "test_ztg_jest_passwithnotests:"
  set +e
  sd_zero_tests_guard 'jest --passWithNoTests src/feed' \
    "$(printf 'No tests found, exiting with code 0\nTests:       0 total\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "jest passWithNoTests → VACUOUS rc=1" "1" "$rc"
}

# 40. vitest --passWithNoTests, zero found → VACUOUS
test_ztg_vitest_passwithnotests() {
  echo "test_ztg_vitest_passwithnotests:"
  set +e
  sd_zero_tests_guard 'vitest run --passWithNoTests' \
    "$(printf 'No test files found, exiting with code 0\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "vitest passWithNoTests → VACUOUS rc=1" "1" "$rc"
}

# 41. node --test, zero tests → VACUOUS (TAP reporter summary: "# tests 0")
test_ztg_node_test_zero() {
  echo "test_ztg_node_test_zero:"
  set +e
  sd_zero_tests_guard 'node --test --test-reporter=tap test/feed.test.js' \
    "$(printf '# tests 0\n# pass 0\n# fail 0\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "node --test (tap) 0 tests → VACUOUS rc=1" "1" "$rc"
}

# 41b. node --test default (spec) reporter, zero tests → VACUOUS ("ℹ tests 0")
test_ztg_node_test_zero_default() {
  echo "test_ztg_node_test_zero_default:"
  set +e
  sd_zero_tests_guard 'node --test test/feed.test.js' \
    "$(printf '\xe2\x84\xb9 tests 0\n\xe2\x84\xb9 pass 0\n\xe2\x84\xb9 fail 0\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "node default reporter 0 tests → VACUOUS rc=1" "1" "$rc"
}

# 42. cargo test — SOME passed, SOME filtered → NOT vacuous (the headline false-positive trap)
test_ztg_cargo_some_passed_some_filtered() {
  echo "test_ztg_cargo_some_passed_some_filtered:"
  set +e
  sd_zero_tests_guard 'cargo test feed' \
    "$(printf 'running 5 tests\n.....\ntest result: ok. 5 passed; 0 failed; 0 ignored; 0 measured; 204 filtered out\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "cargo 5 passed; 204 filtered out → SAFE rc=0" "0" "$rc"
}

# 43. cargo test — multi-binary: one ran 0, another ran 12 → NOT vacuous
test_ztg_cargo_multibinary_mixed() {
  echo "test_ztg_cargo_multibinary_mixed:"
  set +e
  sd_zero_tests_guard 'cargo test' \
    "$(printf 'running 0 tests\ntest result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 5 filtered out\n\nrunning 12 tests\n............\ntest result: ok. 12 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "cargo multi-binary one>0 → SAFE rc=0" "0" "$rc"
}

# 44. pytest — real run, tests passed → NOT vacuous
test_ztg_pytest_all_passed() {
  echo "test_ztg_pytest_all_passed:"
  set +e
  sd_zero_tests_guard 'pytest tests/x.py' \
    "$(printf 'collected 8 items\n........\n8 passed in 0.30s\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "pytest 8 passed → SAFE rc=0" "0" "$rc"
}

# 45. go test — mixed packages: one ran (ok), one [no test files] → NOT vacuous
test_ztg_go_mixed_packages() {
  echo "test_ztg_go_mixed_packages:"
  set +e
  sd_zero_tests_guard 'go test ./...' \
    "$(printf 'ok  \tpkg/a\t0.01s\n?   pkg/b  [no test files]\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "go mixed (one ok) → SAFE rc=0" "0" "$rc"
}

# 46. jest — real run, tests passed → NOT vacuous
test_ztg_jest_real_run() {
  echo "test_ztg_jest_real_run:"
  set +e
  sd_zero_tests_guard 'jest src/feed' \
    "$(printf 'Tests:       3 passed, 3 total\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "jest 3 passed → SAFE rc=0" "0" "$rc"
}

# 46b. cargo with options/toolchain before `test` → still detected (Codex #3)
test_ztg_cargo_with_options() {
  echo "test_ztg_cargo_with_options:"
  set +e
  sd_zero_tests_guard 'cargo --locked test feed' \
    "$(printf 'running 0 tests\n\ntest result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 12 filtered out\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "cargo --locked test, zero collected → VACUOUS rc=1" "1" "$rc"
}

# 46c. go test -json multi-package: one pkg passed (JSON), one has no test files
#      → NOT vacuous (Codex #1: passes are embedded in JSON, not ^ok lines)
test_ztg_go_json_mixed() {
  echo "test_ztg_go_json_mixed:"
  set +e
  sd_zero_tests_guard 'go test -json ./...' \
    "$(printf '{"Action":"run","Package":"ex/pkg/a","Test":"TestA"}\n{"Action":"pass","Package":"ex/pkg/a","Test":"TestA"}\n{"Action":"output","Package":"ex/pkg/b","Output":"?   \\tex/pkg/b\\t[no test files]\\n"}\n{"Action":"skip","Package":"ex/pkg/b"}\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "go -json one pkg passed → SAFE rc=0" "0" "$rc"
}

# 46d. go test -run multi-package: one pkg ran TestA (genuine ok), one matched
#      nothing (ok ... [no tests to run]) → NOT vacuous (Codex #2)
test_ztg_go_run_multipkg() {
  echo "test_ztg_go_run_multipkg:"
  set +e
  sd_zero_tests_guard 'go test -run TestA ./...' \
    "$(printf 'ok  \tex/pkg/a\t0.005s\nok  \tex/pkg/b\t0.002s [no tests to run]\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "go -run multi-pkg one ran → SAFE rc=0" "0" "$rc"
}

# 47. non-runner — `true` → SAFE (no runner token)
test_ztg_nonrunner_true() {
  echo "test_ztg_nonrunner_true:"
  set +e
  sd_zero_tests_guard 'true' '' >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "non-runner true → SAFE rc=0" "0" "$rc"
}

# 48. non-runner — artifact check `ls dist/main.js` → SAFE
test_ztg_nonrunner_ls() {
  echo "test_ztg_nonrunner_ls:"
  set +e
  sd_zero_tests_guard 'ls dist/main.js' "$(printf 'dist/main.js\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "non-runner ls → SAFE rc=0" "0" "$rc"
}

# 49. adversarial — a non-test command whose OUTPUT merely contains "0 passed" → SAFE
#     (the guard keys off the COMMAND, not just the output, to avoid this).
test_ztg_adversarial_unrelated_output() {
  echo "test_ztg_adversarial_unrelated_output:"
  set +e
  sd_zero_tests_guard 'grep -c "0 passed" build.log' "$(printf '0 passed\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "unrelated '0 passed' in output → SAFE rc=0" "0" "$rc"
}

# 50. non-runner — migration tool → SAFE
test_ztg_nonrunner_alembic() {
  echo "test_ztg_nonrunner_alembic:"
  set +e
  sd_zero_tests_guard 'alembic upgrade head' "$(printf 'INFO running upgrade -> head\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "non-runner alembic → SAFE rc=0" "0" "$rc"
}

# 51. dispatcher — vacuous detection survives bin/sd (set -euo pipefail) → exit 1
test_ztg_dispatcher_vacuous() {
  echo "test_ztg_dispatcher_vacuous:"
  set +e
  "$SD_BIN" zero_tests_guard 'cargo test --lib feed' \
    "$(printf 'running 0 tests\n\ntest result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 209 filtered out\n')" >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "dispatcher: vacuous → rc=1" "1" "$rc"
}

# 52. dispatcher — safe (non-runner) survives bin/sd → exit 0
test_ztg_dispatcher_safe() {
  echo "test_ztg_dispatcher_safe:"
  set +e
  "$SD_BIN" zero_tests_guard 'true' '' >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "dispatcher: non-runner → rc=0" "0" "$rc"
}

# 52b. dispatcher — STDIN path (the call pattern the SKILL.md gates use): the log
#      is piped, not passed as argv, so a verbose log can't exceed ARG_MAX (#74/Codex #4)
test_ztg_dispatcher_stdin_vacuous() {
  echo "test_ztg_dispatcher_stdin_vacuous:"
  set +e
  printf 'running 0 tests\n\ntest result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 209 filtered out\n' \
    | "$SD_BIN" zero_tests_guard 'cargo test --lib feed' >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "dispatcher stdin: vacuous → rc=1" "1" "$rc"
}

# 52c. dispatcher — STDIN path, safe (real run) → rc=0
test_ztg_dispatcher_stdin_safe() {
  echo "test_ztg_dispatcher_stdin_safe:"
  set +e
  printf 'collected 8 items\n........\n8 passed in 0.30s\n' \
    | "$SD_BIN" zero_tests_guard 'pytest tests/x.py' >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "dispatcher stdin: real run → rc=0" "0" "$rc"
}

# 53. wired — sd_verify_auto_step fails an `exit 0` AC whose recognized runner
#     collected zero tests. `cargo` is stubbed so the run is offline + deterministic;
#     the cmd string still carries the real `cargo test` token the guard keys off.
test_auto_exit0_vacuous_cargo_wired() {
  echo "test_auto_exit0_vacuous_cargo_wired:"
  cargo() { printf 'running 0 tests\n\ntest result: ok. 0 passed; 0 failed; 0 ignored; 0 measured; 209 filtered out\n'; return 0; }
  set +e
  sd_verify_auto_step '- [ ] auto: `cargo test --lib feed` -> expected: exit 0' >/dev/null 2>&1
  local rc=$?; set -e
  unset -f cargo
  assert_eq "wired: vacuous cargo exit-0 AC → FAIL rc=1" "1" "$rc"
}

# 54. wired — no-regression: a non-runner `exit 0` AC still passes after the guard
test_auto_exit0_still_passes_nonrunner() {
  echo "test_auto_exit0_still_passes_nonrunner:"
  set +e
  sd_verify_auto_step '- [ ] auto: `true` -> expected: exit 0' >/dev/null 2>&1
  local rc=$?; set -e
  assert_eq "wired: non-runner exit-0 AC still passes → rc=0" "0" "$rc"
}

test_auto_exit0_pass
test_auto_exit0_fail
test_auto_exit_n_match
test_auto_exit_n_mismatch
test_auto_exit_n_invalid
test_auto_output_contains_pass
test_auto_output_contains_miss
test_auto_unknown_form
test_auto_missing_cmd
test_report_cross_check_pass
test_report_cross_check_missing
test_report_cross_check_no_report
test_report_cross_check_no_acs
test_report_cross_check_ignores_prose
test_report_cross_check_excludes_user_rows
test_report_cross_check_ignores_inline_ac_token
test_auto_output_includes_stderr
test_auto_unicode_arrow
test_redgate_red_command
test_redgate_green_command
test_redgate_errored_command
test_redgate_expected_exit_n_green
test_redgate_expected_exit_127_is_error
test_redgate_expected_exit_n_invalid
test_redgate_output_contains_missing_is_red
test_redgate_output_contains_present_is_green
test_redgate_empty_command
test_redgate_dispatcher_red
test_redgate_dispatcher_green
test_redgate_dispatcher_errored
test_redgate_dispatcher_expected_exit_n_green
test_redgate_dispatcher_expected_exit_127_is_error
test_redgate_dispatcher_expected_exit_n_invalid
test_ztg_pytest_collected_zero
test_ztg_pytest_k_no_match
test_ztg_cargo_filtered_all
test_ztg_nextest_starting_zero
test_ztg_go_no_test_files_only
test_ztg_go_no_tests_to_run
test_ztg_jest_passwithnotests
test_ztg_vitest_passwithnotests
test_ztg_node_test_zero
test_ztg_node_test_zero_default
test_ztg_cargo_some_passed_some_filtered
test_ztg_cargo_multibinary_mixed
test_ztg_pytest_all_passed
test_ztg_go_mixed_packages
test_ztg_jest_real_run
test_ztg_cargo_with_options
test_ztg_go_json_mixed
test_ztg_go_run_multipkg
test_ztg_nonrunner_true
test_ztg_nonrunner_ls
test_ztg_adversarial_unrelated_output
test_ztg_nonrunner_alembic
test_ztg_dispatcher_vacuous
test_ztg_dispatcher_safe
test_ztg_dispatcher_stdin_vacuous
test_ztg_dispatcher_stdin_safe
test_auto_exit0_vacuous_cargo_wired
test_auto_exit0_still_passes_nonrunner

sd_test_summary
