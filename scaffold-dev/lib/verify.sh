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

  # Collect AC IDs from spec (e.g., "AC-1", "AC-12a").
  local ids
  ids="$(grep -oE 'AC-[A-Za-z0-9.]+' "$spec" | sort -u)"
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
