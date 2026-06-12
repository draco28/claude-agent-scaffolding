#!/usr/bin/env bash
# tests/test-verify.sh — 14 tests for lib/verify.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
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

# 5. auto step — output contains pattern matches
test_auto_output_contains_pass() {
  echo "test_auto_output_contains_pass:"
  set +e
  sd_verify_auto_step '- [ ] auto: `echo hello world` -> expected: output contains hello' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "output contains match → rc=0" "0" "$rc"
}

# 6. auto step — output contains pattern miss
test_auto_output_contains_miss() {
  echo "test_auto_output_contains_miss:"
  set +e
  sd_verify_auto_step '- [ ] auto: `echo goodbye` -> expected: output contains hello' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "output miss → rc=1" "1" "$rc"
}

# 7. auto step — unknown expected form returns rc=2
test_auto_unknown_form() {
  echo "test_auto_unknown_form:"
  set +e
  sd_verify_auto_step '- [ ] auto: `true` -> expected: stars align' >/dev/null 2>&1
  local rc=$?
  :
  assert_eq "unknown form → rc=2" "2" "$rc"
}

# 8. auto step — missing command parse → rc=2
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

test_auto_exit0_pass
test_auto_exit0_fail
test_auto_exit_n_match
test_auto_exit_n_mismatch
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

sd_test_summary
