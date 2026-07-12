#!/usr/bin/env bash
# Cumulative auto-demo runner (spec §6.1 core row). Halt-on-first-fail.

_oss_demo_zero_tests() { # $1=output ; rc 0 if vacuous
  printf '%s' "$1" | { grep -Eq 'collected 0 items|running 0 tests|0 passing|no tests to run' || return 1; }
}
_oss_demo_is_runner() { # $1=command
  printf '%s' "$1" | { grep -Eq 'pytest|cargo test|npm test|go test|bash .*test' || return 1; }
}

oss_demo_run_auto() { # $1=state-file
  local sf="$1" n i line id text cmd expected out rc passed=0
  n="$(jq '[.demo_ledger[] | select(.type=="auto" and (.status=="active" or .status=="quarantined"))] | length' "$sf" 2>/dev/null)" \
    || { echo "oss: cannot read state $sf" >&2; return 1; }
  i=0
  while [ "$i" -lt "$n" ]; do
    line="$(jq -c "[.demo_ledger[] | select(.type==\"auto\" and (.status==\"active\" or .status==\"quarantined\"))][$i]" "$sf")"
    id="$(printf '%s' "$line" | jq -r '.id')"
    text="$(printf '%s' "$line" | jq -r '.text')"
    if [ "$(printf '%s' "$line" | jq -r '.status')" = "quarantined" ]; then
      echo "SKIP $id (quarantined) - $text"
      i=$((i+1)); continue
    fi
    cmd="$(printf '%s' "$line" | jq -r '.command')"
    expected="$(printf '%s' "$line" | jq -r '.expected')"
    set +e; out="$(bash -c "$cmd" 2>&1)"; rc=$?; set -e 2>/dev/null || true
    case "$expected" in
      exit:*)
        if [ "$rc" -ne "${expected#exit:}" ]; then
          echo "FAIL $id - $text (rc=$rc, wanted ${expected#exit:})"; printf '%s\n' "$out" | tail -5; return 1
        fi ;;
      contains:*)
        case "$out" in *"${expected#contains:}"*) ;; *)
          echo "FAIL $id - $text (output missing '${expected#contains:}')"; printf '%s\n' "$out" | tail -5; return 1;; esac ;;
    esac
    # Vacuous-green guard (spec §6.1): a RECOGNIZED TEST RUNNER that collected zero
    # tests FAILs even on exit 0. Both conditions are required - the command must name
    # a known runner AND the output must show a zero-tests result. Dropping the runner
    # check would destroy precision: a legitimate demo line like `echo '0 passing ...'`
    # merely mentions a zero-tests phrase but is not a test suite, and must NOT be
    # flagged (see the negative regression test in test-demo-runner.sh).
    if _oss_demo_is_runner "$cmd" && _oss_demo_zero_tests "$out"; then
      echo "FAIL $id - $text (vacuous-green: recognized runner executed zero tests)"; return 1
    fi
    passed=$((passed+1)); i=$((i+1))
  done
  echo "PASS $passed lines"
}

oss_cmd_demo_run() { oss_demo_run_auto "${1:-.ossify/project-state.json}"; }
