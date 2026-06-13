#!/usr/bin/env bash
# scaffold-dev/lib/backend.sh
# SS-5 — implementer backend selector. Resolves which backend executes a work
# item: a per-invocation override, else the manifest's optional
# `.implementer_backend`, else the default `claude_subagent`. Read-with-default
# only — absent field / absent manifest resolve to claude_subagent (so existing
# projects are unchanged; no workspace-init schema change required).
#
# set -e safety (SS-4): sd_manifest_get returns rc=1 when the field/manifest is
# absent — captured set-e-safe so the (total) default does not abort under the
# dispatcher's `set -euo pipefail`.

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

# sd_backend_resolve [--backend <override>]
# Echoes the resolved backend (claude_subagent | codex). Precedence:
#   --backend override  >  manifest .implementer_backend  >  claude_subagent
# rc=0 on a valid backend; rc=1 on an invalid value (typo); rc=2 on bad usage.
sd_backend_resolve() {
  local override=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backend)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          sd_log_error "sd_backend_resolve: missing value for --backend"
          return 2
        fi
        override="$2"; shift 2 ;;
      *) sd_log_error "sd_backend_resolve: unknown arg: $1"; return 2 ;;
    esac
  done

  local resolved=""
  if [[ -n "$override" ]]; then
    resolved="$override"
  else
    local field=""
    if field="$(sd_manifest_get '.implementer_backend' 2>/dev/null)"; then :; else field=""; fi
    if [[ -n "$field" && "$field" != "null" ]]; then
      resolved="$field"
    else
      resolved="claude_subagent"
    fi
  fi

  case "$resolved" in
    claude_subagent|codex)
      echo "$resolved"
      return 0
      ;;
    *)
      sd_log_error "sd_backend_resolve: invalid backend '$resolved' (expected claude_subagent|codex)"
      return 1
      ;;
  esac
}
