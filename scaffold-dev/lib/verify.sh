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
      [[ "$ec" -eq 0 ]] && return 0 || return 1
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

# sd_redgate_assert_red <command> [expected]
# Pre-flight RED-gate mechanical leg (#5): run <command> and classify whether
# the AC's expected predicate is already satisfied.
#   predicate NOT met             -> RED (desired pre-flight state)   -> return 0
#   predicate met                 -> already GREEN before any work    -> return 1
#   exit 126/127 when unmet       -> ERROR (harness broken, not RED)  -> return 2
# If [expected] is omitted, defaults to "exit 0" for backward compatibility.
sd_redgate_assert_red() {
  local cmd="${1:-}" expected="${2:-exit 0}" output rc=0
  if [[ -z "$cmd" ]]; then
    sd_log_error "sd_redgate_assert_red: command cannot be empty"
    return 2
  fi

  if output="$(bash -c "$cmd" 2>&1)"; then rc=0; else rc=$?; fi

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

  case "$rc" in
    126|127)  return 2 ;;
    *)        return 0 ;;
  esac
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
