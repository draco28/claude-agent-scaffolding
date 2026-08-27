#!/usr/bin/env bash
# Minimal test harness. Source from test files. Never enables -e itself:
# tests must observe failures, not die on them.
T_PASS=0; T_FAIL=0; T_OUT=""; T_RC=0
t_capture() { T_OUT="$("$@" 2>&1)"; T_RC=$?; }
t_assert_eq() { if [ "$1" = "$2" ]; then T_PASS=$((T_PASS+1)); else T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (expected '$1' got '$2')"; fi; }
t_assert_contains() { case "$1" in *"$2"*) T_PASS=$((T_PASS+1));; *) T_FAIL=$((T_FAIL+1)); echo "FAIL: $3 (no '$2' in output)";; esac; }
t_assert_rc() { t_assert_eq "$1" "$T_RC" "$2"; }
t_summary() { echo "pass=$T_PASS fail=$T_FAIL"; [ "$T_FAIL" -eq 0 ]; }
