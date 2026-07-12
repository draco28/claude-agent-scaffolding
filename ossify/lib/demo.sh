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
  n="$(jq '[.demo_ledger[] | select(.type=="auto" and (.status=="active" or .status=="quarantined"))] | length' "$sf")"
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
    # Deviation from brief: the brief's literal gate was `_oss_demo_is_runner "$cmd" &&
    # _oss_demo_zero_tests "$out"`, requiring the command text to literally name a known
    # runner (pytest/cargo test/npm test/go test/bash .*test). Real demo commands are
    # routinely wrapper scripts ("make test", "./run.sh", CI aliases) whose command text
    # never names the underlying tool, so that AND-gate under-fires - the brief's own
    # shipped test ("echo 'collected 0 items'; true") proves it, since neither the command
    # nor the output contains any of the five runner substrings. The four zero-tests
    # messages are themselves tool-specific fingerprints (pytest/go-or-cargo/mocha/generic),
    # so matching output alone is sufficient signal without a redundant command-name check.
    # _oss_demo_is_runner is kept (unused in the gate) for future stricter-mode reuse.
    if _oss_demo_zero_tests "$out"; then
      echo "FAIL $id - $text (vacuous-green: recognized runner executed zero tests)"; return 1
    fi
    passed=$((passed+1)); i=$((i+1))
  done
  echo "PASS $passed lines"
}

oss_cmd_demo_run() { oss_demo_run_auto "${1:-.ossify/project-state.json}"; }
