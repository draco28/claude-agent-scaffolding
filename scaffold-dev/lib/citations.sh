#!/usr/bin/env bash
# scaffold-dev/lib/citations.sh
# Mechanical legs of verifying-spec-citations (#7). Semantic legs (REQ-ID denotes
# the same requirement? ARCH §-ref still points at the right content?) are the
# agent's — they are NOT in this file.

set -u

_SD_CIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_CIT_DIR/_helpers.sh"
fi

# sd_citations_check_file <path>
# Return 0 if the file exists, else 1 (logs a warning). Echoes the path either way.
sd_citations_check_file() {
  local p="$1"
  if [[ -f "$p" ]]; then echo "$p"; return 0; fi
  sd_log_warn "citation: file not found: $p"
  echo "$p"
  return 1
}

# sd_citations_check_signature <file> <signature>
# Return 0 if <file> contains the exact <signature> literal (grep -F — fixed string,
# no regex interpretation), else 1 (logs a warning). Catches paraphrase / parameter drift.
sd_citations_check_signature() {
  local file="$1" sig="$2"
  if [[ ! -f "$file" ]]; then
    sd_log_warn "citation: signature host missing: $file"
    return 1
  fi
  if grep -Fq -- "$sig" "$file"; then return 0; fi
  sd_log_warn "citation: signature not found verbatim in $file: $sig"
  return 1
}
