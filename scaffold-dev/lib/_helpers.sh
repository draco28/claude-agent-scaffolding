#!/usr/bin/env bash
# scaffold-dev/lib/_helpers.sh
# Shared helpers used by every scaffold-dev lib module: logging, jq guard,
# path-abs, jq value reader.
#
# Bash 3.2+ compatible (stock macOS). Safe to double-source.

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Log levels — always to stderr.
sd_log_info()  { echo "[scaffold-dev] $*" >&2; }
sd_log_warn()  { echo "[scaffold-dev WARN] $*" >&2; }
sd_log_error() { echo "[scaffold-dev ERROR] $*" >&2; }

# Require jq in PATH. Returns 1 with an actionable error otherwise.
sd_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    sd_log_error "jq not in PATH; scaffold-dev requires jq. Install via brew install jq (macOS) or apt install jq (Linux)."
    return 1
  fi
  return 0
}

# Convert a possibly-relative path to absolute. No symlink resolution.
sd_abs_path() {
  local p="$1"
  if [[ "$p" == /* ]]; then
    echo "$p"
  else
    echo "$(cd "$(dirname "$p")" 2>/dev/null && pwd)/$(basename "$p")"
  fi
}

# Read a jq expression from a file. Echoes empty string on null/missing.
sd_jq_get() {
  local file="$1" expr="$2"
  jq -r "${expr} // empty" "$file" 2>/dev/null
}
