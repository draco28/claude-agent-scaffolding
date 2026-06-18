#!/usr/bin/env bash
# scaffold-dev/lib/review_gate.sh
# #39 Phase B — review-gate selector. Resolves whether (and where) an opt-in
# architect-critic async close-depth audit runs at slice/spec close: a
# per-invocation override, else the manifest's optional `.review_gate`, else
# the default `off` (today's behavior, unchanged). Read-with-default only —
# absent field / absent manifest resolve to `off`, so existing projects are
# unchanged and no workspace-init schema change is required.
#
# Values: off | slice_close | spec_close | both
#   off          — no review gate (default; existing sync §7 paths untouched)
#   slice_close  — async close-depth audit at closing-vertical-slice §7
#   spec_close   — async close-depth audit at planning-vertical-slice §7
#                  (upgrades the default author-depth audit to close-depth)
#   both         — both attach points
#
# set -e safety (SS-4): sd_manifest_get returns rc=1 when the field/manifest is
# absent — captured set-e-safe so the (total) default does not abort under the
# dispatcher's `set -euo pipefail`. Mirrors lib/backend.sh.

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi
if ! declare -F sd_manifest_get >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/manifest.sh"
fi

# sd_review_gate_resolve [--gate <override>]
# Echoes the resolved gate (off | slice_close | spec_close | both). Precedence:
#   --gate override  >  manifest .review_gate  >  off
# rc=0 on a valid gate; rc=1 on an invalid value (typo); rc=2 on bad usage.
sd_review_gate_resolve() {
  local override=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --gate)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          sd_log_error "sd_review_gate_resolve: missing value for --gate"
          return 2
        fi
        override="$2"; shift 2 ;;
      *) sd_log_error "sd_review_gate_resolve: unknown arg: $1"; return 2 ;;
    esac
  done

  local resolved=""
  if [[ -n "$override" ]]; then
    resolved="$override"
  else
    local field=""
    if field="$(sd_manifest_get '.review_gate' 2>/dev/null)"; then :; else field=""; fi
    if [[ -n "$field" && "$field" != "null" ]]; then
      resolved="$field"
    else
      resolved="off"
    fi
  fi

  case "$resolved" in
    off|slice_close|spec_close|both)
      echo "$resolved"
      return 0
      ;;
    *)
      sd_log_error "sd_review_gate_resolve: invalid review_gate '$resolved' (expected off|slice_close|spec_close|both)"
      return 1
      ;;
  esac
}
