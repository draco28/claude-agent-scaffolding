#!/usr/bin/env bash
# scaffold-dev/lib/rules.sh
# Thin consumer of scaffold-onboard v0.2's R2 mcrule API.
# Sources sf_rules_* via filesystem probe (plugin cache OR monorepo sibling).
# Gracefully falls back to AC-only verification when scaffold-onboard is absent.

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi

# _sd_rules_locate — find scaffold-onboard's lib/rules.sh.
# Probe order: plugin cache → in-repo sibling.
_sd_rules_locate() {
  if [[ "${SD_RULES_FORCE_ABSENT:-}" == "1" ]]; then
    return 1
  fi
  local cand
  for cand in "${HOME}/.claude/plugins/cache"/*/scaffold-onboard/*/lib/rules.sh; do
    [[ -f "$cand" ]] && { echo "$cand"; return 0; }
  done
  local sibling="$_SD_LIB_DIR/../../scaffold-onboard/lib/rules.sh"
  if [[ -f "$sibling" ]]; then
    echo "$(cd "$(dirname "$sibling")" && pwd)/rules.sh"
    return 0
  fi
  return 1
}

# sd_rules_load — source sf_rules_* from scaffold-onboard. Returns 1 if
# scaffold-onboard is not installed/locatable. Warning is non-fatal.
sd_rules_load() {
  local path
  if ! path="$(_sd_rules_locate)"; then
    sd_log_warn "scaffold-onboard v0.2 not found; R2 rule-checking disabled (fallback to AC-only)"
    return 1
  fi
  # shellcheck disable=SC1090
  source "$path"
  return 0
}

# sd_rules_check <file-list>
# file-list is a newline-separated list of changed files (typically relative
# paths from a worktree root).
#
# Strategy:
#   1. Locate the rules file. Honors SD_RULES_FILE env (test/override) →
#      falls back to <ai_workspace>/.claude/memory-bank/03-code-patterns.md
#      → falls back to <cwd>/memory-bank/03-code-patterns.md.
#   2. Load sf_rules_*. On absence, return 0 (fallback to AC-only).
#   3. Parse rules; for each banned_imports rule, scan each candidate file.
#
# Returns 0 when all rules pass (or none to check), 1 when any violation found.
sd_rules_check() {
  local file_list="$1"

  # Locate rules file.
  local rules_md=""
  if [[ -n "${SD_RULES_FILE:-}" && -f "${SD_RULES_FILE}" ]]; then
    rules_md="$SD_RULES_FILE"
  fi
  if [[ -z "$rules_md" ]]; then
    # Try manifest-based.
    if declare -F sd_manifest_get >/dev/null 2>&1; then
      local ai_root
      ai_root="$(sd_manifest_get '.ai_workspace.root' 2>/dev/null || true)"
      if [[ -n "$ai_root" && -f "$ai_root/.claude/memory-bank/03-code-patterns.md" ]]; then
        rules_md="$ai_root/.claude/memory-bank/03-code-patterns.md"
      fi
    fi
  fi
  if [[ -z "$rules_md" && -f "memory-bank/03-code-patterns.md" ]]; then
    rules_md="memory-bank/03-code-patterns.md"
  fi
  if [[ -z "$rules_md" ]]; then
    return 0
  fi

  # Load scaffold-onboard rules API; graceful fall-back to AC-only on miss.
  if ! sd_rules_load 2>/dev/null; then
    return 0
  fi

  # Parse rules JSON.
  local rules_json
  rules_json="$(sf_rules_parse "$rules_md" 2>/dev/null)" || return 0
  if [[ -z "$rules_json" || "$rules_json" == "[]" ]]; then
    return 0
  fi

  # Apply banned_imports.
  local banned_json
  banned_json="$(sf_rules_filter "$rules_json" "banned_imports" 2>/dev/null)"
  local nb
  nb="$(echo "$banned_json" | jq 'length' 2>/dev/null || echo 0)"

  local violation=0
  local i=0
  while (( i < nb )); do
    local forbid where
    forbid="$(echo "$banned_json" | jq -r ".[$i].forbid // empty")"
    where="$(echo "$banned_json"  | jq -r ".[$i].where  // empty")"
    i=$((i+1))
    [[ -z "$forbid" ]] && continue

    # For each candidate file in the list:
    local f
    while IFS= read -r f; do
      [[ -z "$f" ]] && continue
      # Optional path filter.
      if [[ -n "$where" && "$f" != *"$where"* ]]; then
        continue
      fi
      [[ -f "$f" ]] || continue
      # Match common import forms.
      if grep -qE "^[[:space:]]*(import[[:space:]]+|from[[:space:]]+)${forbid}([[:space:]]|\$|\\.)" "$f"; then
        sd_log_warn "sd_rules_check: $f imports banned '$forbid'"
        violation=1
      fi
    done <<<"$file_list"
  done

  [[ "$violation" == "0" ]] && return 0 || return 1
}
