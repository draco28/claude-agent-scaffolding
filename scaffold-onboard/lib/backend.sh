#!/usr/bin/env bash
# scaffold-onboard/lib/backend.sh
# SS-5.1 — synthesizer backend selector. Resolves which backend runs a synthesis
# dispatch: a per-invocation override, else the manifest's optional
# `.synthesizer_backend`, else the default `claude_subagent`. Read-with-default
# only — absent field / absent manifest resolve to claude_subagent (existing
# projects unchanged; no workspace-init schema change required).
#
# set -e safety: sf_manifest_get returns rc=1 when the field/manifest is absent —
# captured set-e-safe so the default does not abort under bin/sf's set -euo pipefail.

set -u

_SF_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sf_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SF_LIB_DIR/_helpers.sh"
fi
if ! declare -F sf_manifest_get >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SF_LIB_DIR/routing.sh"
fi

# sf_backend_resolve [--backend <override>]
# Echoes the resolved backend (claude_subagent | codex). Precedence:
#   --backend override  >  manifest .synthesizer_backend  >  claude_subagent
# rc=0 on a valid backend; rc=1 on an invalid value; rc=2 on bad usage.
sf_backend_resolve() {
  local override=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --backend)
        if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
          sf_log_error "sf_backend_resolve: missing value for --backend"
          return 2
        fi
        override="$2"; shift 2 ;;
      *) sf_log_error "sf_backend_resolve: unknown arg: $1"; return 2 ;;
    esac
  done

  local resolved=""
  if [[ -n "$override" ]]; then
    resolved="$override"
  else
    local field=""
    if field="$(sf_manifest_get '.synthesizer_backend' 2>/dev/null)"; then :; else field=""; fi
    if [[ -n "$field" && "$field" != "null" ]]; then
      resolved="$field"
    else
      resolved="claude_subagent"
    fi
  fi

  case "$resolved" in
    claude_subagent|codex) echo "$resolved"; return 0 ;;
    *) sf_log_error "sf_backend_resolve: invalid backend '$resolved' (expected claude_subagent|codex)"; return 1 ;;
  esac
}
