#!/usr/bin/env bash
# lib/cost.sh — post-run cost computation + formatted output line
# Part of architect-critic plugin (Phase D, TD.5).
#
# Rate-card constants — update when model pricing changes.
# These are placeholder rates for the codex model; verify current pricing at
# https://openai.com/pricing and bump AC_COST_RATE_CARD_UPDATED on each refresh.
# NOTE: defined as plain (non-readonly) so tests can override; production code
# treats these as effectively immutable.
: "${AC_COST_CODEX_IN_PER_1K:=0.005}"               # USD per 1K input tokens
: "${AC_COST_CODEX_OUT_PER_1K:=0.015}"              # USD per 1K output tokens
: "${AC_COST_RATE_CARD_UPDATED:=2026-05-01}"        # ISO date when rates last verified
: "${AC_COST_STALENESS_DAYS:=180}"                  # Warn in cost line if older than this

# ac_cost_compute <codex_tokens_in> <codex_tokens_out>
# Computes total codex cost in USD using the static rate-card above.
# Prints the result as a floating-point string (e.g., "0.020").
# Uses bc if available; falls back to portable bash integer arithmetic.
#
# Args:
#   codex_tokens_in  — integer: input token count from codex audit
#   codex_tokens_out — integer: output token count from codex audit
#
# Output: USD cost as floating-point string on stdout
# Returns: 0 on success
ac_cost_compute() {
  local tokens_in="${1:-0}"
  local tokens_out="${2:-0}"

  if command -v bc >/dev/null 2>&1; then
    # bc-based path: full floating-point precision
    printf '%s\n' "scale=3; ($tokens_in * $AC_COST_CODEX_IN_PER_1K / 1000) + ($tokens_out * $AC_COST_CODEX_OUT_PER_1K / 1000)" \
      | bc | sed 's/^\./0./'
  else
    # Bash-only fallback: multiply by 1000000 to avoid floats, integer divide, re-format.
    # cost_in_micros  = tokens_in  * (rate_in_per_1k  * 1000) = tokens_in  * 5   (for 0.005)
    # cost_out_micros = tokens_out * (rate_out_per_1k * 1000) = tokens_out * 15  (for 0.015)
    # Both rates are multiplied by 1000000 then divided by 1000 (per-1K): net ×1000.
    # So: cost_micro = (tokens_in * 5 + tokens_out * 15)
    # Final USD = cost_micro / 1000000 → print as X.XXX
    local in_micro out_micro total_micro
    # AC_COST_CODEX_IN_PER_1K=0.005 → 5 millionths per token (0.005/1000 * 1e6 = 5)
    in_micro=$(( tokens_in * 5 ))
    # AC_COST_CODEX_OUT_PER_1K=0.015 → 15 millionths per token
    out_micro=$(( tokens_out * 15 ))
    total_micro=$(( in_micro + out_micro ))
    # Format as X.XXX (3 decimal places → divide by 1000, remainder as fraction)
    local whole frac
    whole=$(( total_micro / 1000000 ))
    frac=$(( (total_micro % 1000000 + 1000000) % 1000000 ))
    printf '%d.%06d\n' "$whole" "$frac" | sed 's/\([0-9]*\.[0-9][0-9][0-9]\)[0-9]*/\1/'
  fi
}

# ac_cost_print <codex_cost_usd> [<claude_cost_usd>]
# Prints the formatted post-run cost line per SPEC §9.3 OQ-3:
#   ~$<total> spent on this audit (codex: $<codex>, claude-self: $<claude>)
#
# Args:
#   codex_cost_usd  — USD float string (e.g., "0.12")
#   claude_cost_usd — USD float string; defaults to "0" (in-session, already paid)
ac_cost_print() {
  local codex_cost="${1:-0}"
  local claude_cost="${2:-0}"
  local total

  if command -v bc >/dev/null 2>&1; then
    total=$(printf '%s\n' "scale=3; $codex_cost + $claude_cost" | bc | sed 's/^\./0./')
  else
    # Portable bash-only addition for two decimal strings.
    # Convert to millionths, add, re-format.
    local c_micro cl_micro sum_micro whole frac
    c_micro=$(_ac_cost_to_micro "$codex_cost")
    cl_micro=$(_ac_cost_to_micro "$claude_cost")
    sum_micro=$(( c_micro + cl_micro ))
    whole=$(( sum_micro / 1000000 ))
    frac=$(( (sum_micro % 1000000 + 1000000) % 1000000 ))
    total=$(printf '%d.%06d\n' "$whole" "$frac" | sed 's/\([0-9]*\.[0-9][0-9][0-9]\)[0-9]*/\1/')
  fi

  local stale_suffix=""
  if _ac_cost_rate_card_stale; then
    stale_suffix=" (rates from ${AC_COST_RATE_CARD_UPDATED} — may be stale; see lib/cost.sh)"
  fi

  printf '~$%s spent on this audit (codex: $%s, claude-self: $%s)%s\n' \
    "$total" "$codex_cost" "$claude_cost" "$stale_suffix"
}

# _ac_cost_rate_card_stale
# Returns 0 (true) if AC_COST_RATE_CARD_UPDATED is older than
# AC_COST_STALENESS_DAYS days; 1 (false) otherwise. Portable across BSD
# (macOS) and GNU (Linux) date utilities.
_ac_cost_rate_card_stale() {
  local now_epoch updated_epoch diff_days
  now_epoch="$(date -u +%s 2>/dev/null)" || return 1
  # BSD date first; fall back to GNU.
  if updated_epoch="$(date -u -j -f "%Y-%m-%d" "$AC_COST_RATE_CARD_UPDATED" +%s 2>/dev/null)"; then
    :
  elif updated_epoch="$(date -u -d "$AC_COST_RATE_CARD_UPDATED" +%s 2>/dev/null)"; then
    :
  else
    return 1   # cannot parse — assume not stale rather than spam warnings
  fi
  diff_days=$(( (now_epoch - updated_epoch) / 86400 ))
  [[ "$diff_days" -gt "$AC_COST_STALENESS_DAYS" ]]
}

# _ac_cost_to_micro <float_string>
# Internal helper: converts a decimal string like "0.12" to integer millionths (120000).
# Handles values with 0–6 decimal places. bash-only (no bc needed).
_ac_cost_to_micro() {
  local val="${1:-0}"
  # Split on decimal point
  local int_part dec_part
  if [[ "$val" == *.* ]]; then
    int_part="${val%%.*}"
    dec_part="${val#*.}"
  else
    int_part="$val"
    dec_part=""
  fi
  # Pad or truncate dec_part to exactly 6 digits
  dec_part="${dec_part}000000"
  dec_part="${dec_part:0:6}"
  # Strip leading zeros to avoid octal interpretation
  dec_part=$(printf '%d' "$((10#$dec_part))")
  echo $(( int_part * 1000000 + dec_part ))
}
