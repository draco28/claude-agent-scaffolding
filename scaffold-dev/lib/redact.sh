#!/usr/bin/env bash
# scaffold-dev/lib/redact.sh
# Mechanical secret/PII candidate-surfacer for the handoff redaction pass (#38 leg 3).
#
# North Star split (SPEC §1): this file is the *mechanical* half only — it flags
# candidate substrings by fixed pattern (a non-reasoning fact: "does this string
# match a known token shape?"). It makes NO redact/keep decision. The *agent* half
# (handing-off-session SKILL.md redaction step) judges each candidate in context
# and drives the warn-and-confirm loop. Kept lean + high-signal on purpose: the
# agent owns recall-vs-precision judgment, so this errs toward surfacing.
#
# Contract:
#   sd_redact_candidates [<file>|-]   ; '-' or no arg = read stdin
#     → prints one candidate per line, TAB-separated: <lineno>\t<category>\t<match>
#       sorted by line number. Empty output = no candidates. Always exits 0 on a
#       readable source (returns 1 only if a named <file> is not a readable file).
#
# Categories: github-token openai-key aws-access-key slack-token pem-private-key
#             url-credentials email labeled-secret

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi

# _sd_redact_scan <category> <ci:0|1> <ere> — emits "<lineno>\t<category>\t<match>"
# for each match of <ere> in $_SD_REDACT_INPUT. Uses grep -oE (BSD-portable; no
# -P/PCRE). \S is not ERE — patterns use [^[:space:]].
#
# STRICT-MODE-SAFE: bin/sd runs `set -euo pipefail`, which is inherited here. A
# grep no-match (exit 1) must NOT abort the function or the pipeline — otherwise
# the first empty category would silently drop every later category. So grep runs
# on the RHS of an assignment guarded by `|| :`, and the fn always returns 0.
_sd_redact_scan() {
  local cat="$1" ci="$2" ere="$3"
  local flags="-noE"
  [[ "$ci" == "1" ]] && flags="-nioE"
  local matches=""
  # grep -n -o emits "<lineno>:<match>"; the `|| :` swallows the no-match exit-1.
  matches="$(printf '%s\n' "$_SD_REDACT_INPUT" | grep $flags -- "$ere" 2>/dev/null)" || :
  [[ -n "$matches" ]] || return 0
  # split on the FIRST colon only so a match that itself contains ':' (e.g.
  # url-credentials scheme://user:pass@) is preserved intact.
  while IFS=: read -r _ln _match; do
    [[ -n "$_ln" ]] || continue
    printf '%s\t%s\t%s\n' "$_ln" "$cat" "$_match"
  done <<< "$matches"
  return 0
}

sd_redact_candidates() {
  local src="${1:--}"
  if [[ "$src" == "-" ]]; then
    _SD_REDACT_INPUT="$(cat)"
  else
    if [[ ! -f "$src" || ! -r "$src" ]]; then
      sd_log_error "sd_redact_candidates: not a readable file: $src"
      return 1
    fi
    _SD_REDACT_INPUT="$(cat "$src")"
  fi

  local raw=""
  raw="$(
    _sd_redact_scan "github-token"    0 'gh[posru]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{22,}'
    _sd_redact_scan "openai-key"      0 'sk-[A-Za-z0-9_-]{20,}'
    _sd_redact_scan "aws-access-key"  0 '(AKIA|ASIA)[0-9A-Z]{16}'
    _sd_redact_scan "slack-token"     0 'xox[baprs]-[A-Za-z0-9-]{10,}'
    _sd_redact_scan "pem-private-key" 0 '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    _sd_redact_scan "url-credentials" 0 '[a-zA-Z][a-zA-Z0-9+.-]*://[^[:space:]/@:]+:[^[:space:]/@]+@'
    _sd_redact_scan "email"           0 '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
    # labeled-secret: a secret-ish keyword immediately assigned a value. Requires
    # the `:`/`=` so prose like "the auth token is fine" does NOT match (no
    # assignment follows the keyword).
    _sd_redact_scan "labeled-secret"  1 '(api[_-]?key|secret|token|password|passwd|bearer)[[:space:]]*[:=][[:space:]]*[^[:space:]]{6,}'
  )" || :
  [[ -n "$raw" ]] || return 0
  printf '%s\n' "$raw" | sort -t"$(printf '\t')" -k1,1n -k2,2 -k3,3 -u
  return 0
}
