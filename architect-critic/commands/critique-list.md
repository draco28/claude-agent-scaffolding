---
description: Show recent /critique runs and pending in-flight requests with elapsed time, adversaries used, challenge counts, and cost
argument-hint: "[--limit N]"
allowed-tools: Bash, Read
---

# /critique-list

Display the recent runs from state.json with a formatted table, plus any in-flight markers.

```bash
# $ARGUMENTS bridge — Claude Code substitutes $N at template time, so we parse
# from the raw arg string instead of bash positionals (v0.1.1 bug fix).
RAW_ARGS_FROM_CLAUDE="$ARGUMENTS" bash -c '
set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"

source "${PLUGIN_ROOT}/lib/_helpers.sh"
source "${PLUGIN_ROOT}/lib/state.sh"

# ── Argument parsing ────────────────────────────────────────────────────────
RAW_ARGS="${RAW_ARGS_FROM_CLAUDE:-}"
LIMIT="$(printf "%s" "$RAW_ARGS" | sed -nE "s|.*--limit[= ]+([0-9]+).*|\\1|p" | head -1)"
[[ -z "$LIMIT" ]] && LIMIT=10

# ── Bootstrap ──────────────────────────────────────────────────────────────
ac_state_init

# ── Read state.json ────────────────────────────────────────────────────────
STATE="$(ac_state_read)"

# ── List in-flight markers ────────────────────────────────────────────────────
IN_FLIGHT="$(printf "%s\n" "$STATE" | jq -r ".in_flight[]? | .request_id")"

if [[ -n "$IN_FLIGHT" ]]; then
  echo "=== Currently running ==="
  printf "%s\n" "$IN_FLIGHT" | while read -r rid; do
    echo "  $rid"
  done
  echo ""
fi

# ── Render recent runs table ────────────────────────────────────────────────
echo "=== Recent runs (most recent first, limit ${LIMIT}) ==="

# Slice last LIMIT runs and reverse in jq (macOS-portable, no tac needed, limit enforced in jq)
RECENT_RUNS="$(printf "%s\n" "$STATE" | jq -r ".recent_runs[-${LIMIT}:] | reverse[] | @json")"

if [[ -z "$RECENT_RUNS" ]]; then
  echo "(no runs yet)"
  exit 0
fi

# ── Format and display table ──────────────────────────────────────────────────
# Table columns: timestamp | request_id (truncated) | depth | adversaries | challenges + divergences | elapsed | cost

echo ""
echo "┌────────────────────┬──────────────────┬──────────────┬────────────┬──────────┬──────────┬──────────┐"
echo "│ Timestamp          │ Request ID       │ Depth        │ Adversaries│ Chall+Div│ Elapsed  │ Cost     │"
echo "├────────────────────┼──────────────────┼──────────────┼────────────┼──────────┼──────────┼──────────┤"

COUNT=0
printf "%s\n" "$RECENT_RUNS" | while read -r line; do
  COUNT=$((COUNT + 1))

  # Parse each run JSON
  REQUEST_ID="$(printf "%s" "$line" | jq -r ".request_id")"
  COMPLETED_AT="$(printf "%s" "$line" | jq -r ".completed_at")"
  DEPTH="$(printf "%s" "$line" | jq -r ".depth")"
  ADVERSARIES="$(printf "%s" "$line" | jq -r ".adversaries_used | join(\",\")")"
  CHALLENGE_COUNT="$(printf "%s" "$line" | jq -r ".challenge_count")"
  DIVERGENCE_COUNT="$(printf "%s" "$line" | jq -r ".divergence_count")"
  ELAPSED_MS="$(printf "%s" "$line" | jq -r ".elapsed_ms")"
  COST_USD="$(printf "%s" "$line" | jq -r ".cost_usd // \"0.00\"")"

  # Format relative timestamp (5m ago, 2h ago, yesterday, etc.)
  NOW_EPOCH="$(date +%s)"
  COMPLETED_EPOCH="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$COMPLETED_AT" "+%s" 2>/dev/null || echo "$NOW_EPOCH")"
  DIFF=$((NOW_EPOCH - COMPLETED_EPOCH))

  if [[ $DIFF -lt 60 ]]; then
    REL_TIME="now"
  elif [[ $DIFF -lt 3600 ]]; then
    MINS=$((DIFF / 60))
    REL_TIME="${MINS}m ago"
  elif [[ $DIFF -lt 86400 ]]; then
    HOURS=$((DIFF / 3600))
    REL_TIME="${HOURS}h ago"
  elif [[ $DIFF -lt 604800 ]]; then
    DAYS=$((DIFF / 86400))
    REL_TIME="${DAYS}d ago"
  else
    REL_TIME="$(printf "%s" "$COMPLETED_AT" | cut -c1-10)"
  fi

  # Truncate request_id to 16 chars
  REQUEST_ID_TRUNC="${REQUEST_ID:0:16}"

  # Format adversaries (c=claude, x=codex)
  ADV_SHORT=""
  if [[ "$ADVERSARIES" == *"claude"* ]]; then ADV_SHORT="${ADV_SHORT}C"; fi
  if [[ "$ADVERSARIES" == *"codex"* ]]; then ADV_SHORT="${ADV_SHORT}X"; fi

  # Format depth (short form)
  DEPTH_SHORT="${DEPTH:0:4}"

  # Format challenges + divergences
  TOTAL=$((CHALLENGE_COUNT + DIVERGENCE_COUNT))

  # Format elapsed (ms → human)
  if [[ $ELAPSED_MS -lt 1000 ]]; then
    ELAPSED_FMT="${ELAPSED_MS}ms"
  else
    SECS=$((ELAPSED_MS / 1000))
    ELAPSED_FMT="${SECS}s"
  fi

  # Format cost (2 decimal places)
  COST_FMT="$(printf "%.2f" "$COST_USD")"

  # Print row (fixed widths for alignment)
  printf "│ %-18s │ %-16s │ %-12s │ %-10s │ %7s  │ %8s │ $%-7s │\n" \
    "$REL_TIME" "$REQUEST_ID_TRUNC" "$DEPTH_SHORT" "$ADV_SHORT" "$TOTAL" "$ELAPSED_FMT" "$COST_FMT"
done

echo "└────────────────────┴──────────────────┴──────────────┴────────────┴──────────┴──────────┴──────────┘"
'
```
