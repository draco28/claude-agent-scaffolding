#!/usr/bin/env bash
# scaffold-dev/lib/slice_meta.sh
# Per-slice runtime metadata recorded at planning and read at slice-close.
#
# #76: the slice-start baseline — the canonical default-branch HEAD captured when
# the slice's first worktree is created (planning-vertical-slice §8.1). Read at
# closing-vertical-slice §7.2a so direct-mode async review bundles can diff
# <recorded-base>..HEAD (in direct mode the slice is already merged into the
# default branch by close, so the live merge-base==HEAD yields an empty diff).
#
# Stored as a JSON block between sentinels in the (committed) VS README, mirroring
# the cursor pattern in lib/state.sh:
#   <!-- sd:baseline:start -->
#   ```json
#   {"recorded_base_sha":"…","recorded_base_branch":"main"}
#   ```
#   <!-- sd:baseline:end -->
#
# Record-once: a single orchestrator writes this exactly once per slice (round 1),
# so writes are append-if-absent / no-op-if-present (no lock needed, unlike the
# raceable active-context cursor). Atomic via tmp+mv.

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_error >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi

_sd_slice_readme() { echo "$1/README.md"; }

# sd_slice_baseline_write <slice_root> <sha> <branch>
# Append-once: writes the baseline sentinel block into <slice_root>/README.md only
# if none exists yet (round 2+ re-runs no-op, preserving the round-1 baseline).
# Creates the README defensively if absent. rc 0 on write-or-noop; rc 2 on usage.
sd_slice_baseline_write() {
  local slice_root="${1:-}" sha="${2:-}" branch="${3:-}"
  if [[ -z "$slice_root" || -z "$sha" || -z "$branch" ]]; then
    sd_log_error "sd_slice_baseline_write: usage: <slice_root> <sha> <branch>"
    return 2
  fi
  local readme; readme="$(_sd_slice_readme "$slice_root")"
  mkdir -p "$slice_root"
  # Record-once: if a baseline block already exists, preserve it.
  if [[ -f "$readme" ]] && grep -q '<!-- sd:baseline:start -->' "$readme"; then
    return 0
  fi
  local json
  json="$(jq -nc --arg s "$sha" --arg b "$branch" \
    '{recorded_base_sha: $s, recorded_base_branch: $b}')"
  local tmp="${readme}.tmp.$$"
  {
    [[ -f "$readme" ]] && cat "$readme"
    printf '\n<!-- sd:baseline:start -->\n```json\n%s\n```\n<!-- sd:baseline:end -->\n' "$json"
  } > "$tmp"
  if ! mv "$tmp" "$readme"; then
    rm -f "$tmp"
    sd_log_error "sd_slice_baseline_write: failed to write $readme"
    return 2
  fi
  return 0
}

# sd_slice_baseline_read <slice_root> — emit the baseline JSON object to stdout.
# rc 1 if the README or the baseline block is absent; rc 2 on usage error.
sd_slice_baseline_read() {
  local slice_root="${1:-}"
  if [[ -z "$slice_root" ]]; then
    sd_log_error "sd_slice_baseline_read: usage: <slice_root>"
    return 2
  fi
  local readme; readme="$(_sd_slice_readme "$slice_root")"
  if [[ ! -f "$readme" ]]; then
    return 1
  fi
  local json
  json="$(awk '
    /<!-- sd:baseline:start -->/ { in_block = 1; next }
    /<!-- sd:baseline:end -->/   { in_block = 0; next }
    in_block == 1 { if ($0 ~ /^[[:space:]]*```/) next; print }
  ' "$readme")"
  # Trim leading/trailing blank lines.
  json="$(echo "$json" | awk 'NF { found = 1 } found { print }')"
  if [[ -z "$json" ]]; then
    return 1
  fi
  echo "$json" | jq -c '.'
}
