#!/usr/bin/env bash
# scaffold-dev/lib/verify.sh
# Demo-line / auto-step verification + report-cross-check against ACs.
#
# Auto-step grammar (one line):
#   - [ ] auto: `<command>` -> expected: <form>
#   - [ ] auto: `<command>` → expected: <form>   (literal U+2192 arrow OK)
# Forms:
#   exit 0           — command must exit with 0
#   exit N           — command must exit with N
#   output contains <substring> — captured stdout+stderr must contain substring

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi

# sd_verify_auto_step <line>
# Parses + runs the command, applies expectation. Returns:
#   0 — expectation met
#   1 — expectation NOT met
#   2 — unknown expectation form OR malformed line
sd_verify_auto_step() {
  local line="$1"
  # Extract command between backticks.
  local cmd
  cmd="$(echo "$line" | sed -nE 's/.*auto: `([^`]+)`.*/\1/p')"
  if [[ -z "$cmd" ]]; then
    sd_log_error "sd_verify_auto_step: no command found in: $line"
    return 2
  fi
  # Extract expected: everything after "expected:" up to EOL.
  local expected
  expected="$(echo "$line" | sed -nE 's/.*expected:[[:space:]]*(.*)$/\1/p')"
  expected="${expected%"${expected##*[![:space:]]}"}"
  if [[ -z "$expected" ]]; then
    sd_log_error "sd_verify_auto_step: no expected clause in: $line"
    return 2
  fi

  local output ec
  output="$(eval "$cmd" 2>&1)"
  ec=$?

  case "$expected" in
    "exit 0")
      if [[ "$ec" -ne 0 ]]; then return 1; fi
      # #74: an exit-0 from a recognized test runner that collected ZERO tests is
      # a false-green (e.g. `cargo test <filter>` → "0 passed; N filtered out",
      # exit 0). Fail loud instead of trusting the exit code. Scoped to `exit 0`:
      # `exit N` negative-test ACs intentionally expect failure.
      if ! sd_zero_tests_guard "$cmd" "$output"; then
        sd_log_error "sd_verify_auto_step: '$cmd' exited 0 but a recognized test runner collected ZERO tests (vacuous green) — fix the filter/path or author the missing test"
        return 1
      fi
      return 0
      ;;
    "exit "*)
      local code="${expected#exit }"
      if [[ ! "$code" =~ ^[0-9]+$ ]]; then
        sd_log_error "sd_verify_auto_step: invalid exit code in expected form: $expected"
        return 2
      fi
      [[ "$ec" -eq "$code" ]] && return 0 || return 1
      ;;
    "output contains "*)
      local needle="${expected#output contains }"
      if echo "$output" | grep -qF -- "$needle"; then
        return 0
      else
        return 1
      fi
      ;;
    *)
      sd_log_error "sd_verify_auto_step: unknown expected form: $expected"
      return 2
      ;;
  esac
}

# sd_zero_tests_guard <cmd> [captured_output]   (#74)
# Detect a VACUOUS test run: a recognized test runner that exited 0 having
# collected ZERO tests (a name/path filter matched nothing, so `exit 0` is a
# false-green). Pure + side-effect-free — it never executes <cmd>; it inspects
# the already-captured combined stdout+stderr — so it is unit-testable with
# canned output. ALLOWLIST-ONLY + FAIL-SOFT: an unrecognized runner returns SAFE,
# preserving today's behavior (no regression). Biased hard toward false-negatives
# (miss → today's behavior) over false-positives (wrongly failing a real green).
# Markers are best-effort against common runner output and may drift across
# runner versions; drift degrades to a miss, never a false fire.
#
# The captured output is taken from $2 when given, else read from STDIN. Callers
# that exec the dispatcher (`sd zero_tests_guard "$cmd"`) should PIPE the log via
# stdin — a verbose log passed as argv can exceed ARG_MAX (Codex #4); in-process
# callers may pass it as $2.
# Returns:
#   0 — SAFE     (not a recognized runner, or it collected >=1 test)
#   1 — VACUOUS  (recognized runner collected zero tests)
# set -e-safe: every match runs inside an if/&&/! condition.
sd_zero_tests_guard() {
  local cmd="${1:-}" out
  if [[ $# -ge 2 ]]; then out="$2"; else out="$(cat)"; fi

  # cargo nextest — check BEFORE plain `cargo test` (more specific). The token
  # regexes allow options/toolchain between `cargo` and the subcommand
  # (`cargo --locked test`, `cargo +nightly test`) — Codex #3.
  if printf '%s' "$cmd" | grep -Eq 'cargo[[:space:]]+([^[:space:]]+[[:space:]]+)*nextest([[:space:]]|$)'; then
    if printf '%s' "$out" | grep -Eq 'Starting 0 tests'; then return 1; fi
    return 0
  fi

  # cargo test (libtest). Fire only on genuine zero-result, and NEVER when any
  # binary in the same run reported tests running / passing (multi-binary safe).
  if printf '%s' "$cmd" | grep -Eq 'cargo[[:space:]]+([^[:space:]]+[[:space:]]+)*test([[:space:]]|$)'; then
    if printf '%s' "$out" | grep -Eq 'running 0 tests' \
       && ! printf '%s' "$out" | grep -Eq 'running [1-9][0-9]* tests?'; then
      return 1
    fi
    if printf '%s' "$out" | grep -Eq 'test result:.* 0 passed;.*filtered out' \
       && ! printf '%s' "$out" | grep -Eq 'test result:.* [1-9][0-9]* passed'; then
      return 1
    fi
    return 0
  fi

  # pytest.
  if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]])pytest([^[:alnum:]]|$)|python[0-9.]*[[:space:]]+-m[[:space:]]+pytest'; then
    if printf '%s' "$out" | grep -Eq 'collected 0 items|no tests ran'; then return 1; fi
    return 0
  fi

  # go test. Zero-collection markers: `[no test files]` (no _test.go in a pkg) or
  # `no tests to run` (a -run filter matched nothing). A multi-package `./...` run
  # is NOT vacuous if any sibling package actually ran — so before firing, suppress
  # on any genuine-pass evidence in EITHER plain or -json form (Codex #1/#2):
  #   • `--- PASS:`                  (verbose plain)
  #   • -json `"Action":"pass"|"run"`(passes are embedded in JSON, not `^ok` lines)
  #   • an `ok <pkg>` summary line that does NOT carry a `[no tests…]` note
  #     (a bare `ok pkg` is a real pass; `ok pkg [no tests to run]` is not).
  if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]])go[[:space:]]+test'; then
    if printf '%s' "$out" | grep -Eq 'no tests to run|no test files'; then
      if printf '%s' "$out" | grep -Eq '[-]{3} PASS:|"Action":"(pass|run)"'; then return 0; fi
      if printf '%s' "$out" | grep -E '^ok[[:space:]]' | grep -vqE '\[no tests'; then return 0; fi
      return 1
    fi
    return 0
  fi

  # jest — only reaches exit 0 on no-tests via --passWithNoTests (plain exits 1).
  if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]])jest([^[:alnum:]]|$)|npx[[:space:]]+jest'; then
    if printf '%s' "$out" | grep -Eq 'No tests found|Tests:[[:space:]]+0 total'; then return 1; fi
    return 0
  fi

  # vitest — likewise exit 0 on no-tests only via --passWithNoTests.
  if printf '%s' "$cmd" | grep -Eq '(^|[^[:alnum:]])vitest([^[:alnum:]]|$)'; then
    if printf '%s' "$out" | grep -Eq 'No test files found|Test Files[[:space:]]+0([^0-9]|$)'; then return 1; fi
    return 0
  fi

  # node --test (TAP summary line).
  if printf '%s' "$cmd" | grep -Eq 'node[[:space:]].*--test'; then
    if printf '%s' "$out" | grep -Eq '# tests 0([^0-9]|$)'; then return 1; fi
    return 0
  fi

  # Unrecognized runner → fail-soft, behavior unchanged.
  return 0
}

# sd_redgate_assert_red <command> [expected]
# Pre-flight RED-gate mechanical leg (#5): run <command> and classify whether
# the AC's expected predicate is already satisfied.
#   predicate NOT met             -> RED (desired pre-flight state)   -> return 0
#   predicate met                 -> already GREEN before any work    -> return 1
#   exit 126/127                  -> ERROR (harness broken, not RED)  -> return 2
# If [expected] is omitted, defaults to "exit 0" for backward compatibility.
sd_redgate_assert_red() {
  local cmd="${1:-}" expected="${2:-exit 0}" output rc=0
  if [[ -z "$cmd" ]]; then
    sd_log_error "sd_redgate_assert_red: command cannot be empty"
    return 2
  fi

  if output="$(bash -c "$cmd" 2>&1)"; then rc=0; else rc=$?; fi
  case "$rc" in
    126|127) return 2 ;;
  esac

  case "$expected" in
    "exit "*)
      local code="${expected#exit }"
      if [[ ! "$code" =~ ^[0-9]+$ ]]; then
        sd_log_error "sd_redgate_assert_red: invalid exit code in expected form: $expected"
        return 2
      fi
      if [[ "$rc" -eq "$code" ]]; then return 1; fi
      ;;
    "output contains "*)
      local needle="${expected#output contains }"
      if echo "$output" | grep -qF -- "$needle"; then return 1; fi
      ;;
    *)
      sd_log_error "sd_redgate_assert_red: unknown expected form: $expected"
      return 2
      ;;
  esac

  return 0
}

# sd_verify_report_cross_check <report.md> <spec.md>
# Confirms each AC-N: ... line in spec.md is referenced (by ID) in report.md.
# Returns 0 when every AC ID is covered; 1 when one or more are missing OR
# when files are missing.
sd_verify_report_cross_check() {
  local report="$1" spec="$2"
  if [[ ! -f "$report" ]]; then
    sd_log_error "sd_verify_report_cross_check: report not found: $report"
    return 1
  fi
  if [[ ! -f "$spec" ]]; then
    sd_log_error "sd_verify_report_cross_check: spec not found: $spec"
    return 1
  fi

  # Collect AC IDs ONLY from declared auto-AC rows — list items ("- AC-1: ...") or
  # checklist rows ("- [ ] AC-1 auto: ..."). Do NOT grep the whole file: prose,
  # blockquotes, and template boilerplate often mention an AC id (or a literal
  # "AC-N" placeholder), which would otherwise be required in report.md and fail
  # every normally-authored spec. Also exclude "- [ ] AC-N user: ..." rows: manual
  # demo steps are verified at slice-close, not recorded in the work-item report,
  # so requiring them here would wrongly fail every spec that has a manual AC.
  # Extract ONLY the leading label of each row (the AC id right after the bullet /
  # checkbox), so an AC-looking token inside the command or the expected predicate
  # (e.g. `printf AC-99` or `output contains AC-99`) cannot become a phantom
  # required outcome.
  local ids
  ids="$(grep -E '^- (\[[ xX]\] )?AC-[A-Za-z0-9.]+' "$spec" \
    | grep -vE '^- \[[ xX]\] AC-[A-Za-z0-9.]+[[:space:]]+user:' \
    | sed -nE 's/^- (\[[ xX]\] )?(AC-[A-Za-z0-9.]+).*/\2/p' | sort -u)"
  if [[ -z "$ids" ]]; then
    return 0
  fi

  local missing=""
  local id
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if ! grep -qF -- "$id" "$report"; then
      missing="${missing}${id} "
    fi
  done <<<"$ids"

  if [[ -n "$missing" ]]; then
    sd_log_error "sd_verify_report_cross_check: ACs missing from $report: $missing"
    return 1
  fi
  return 0
}
