#!/usr/bin/env bash
# stop.sh — digest-gated board sync after a session turn. NEVER fails the
# session: every path exits 0. Output is discarded (async hook).
set +e
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
input="$(cat 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"
command -v jq >/dev/null 2>&1 || exit 0
# a running reconcile holds the per-workspace lock and may have captured older state than
# this event announces. Retry while "locked" so the newest state still lands when this is
# the session's last hook — a discarded locked-skip left the board stale until the next
# session. Bounded well under the hook's 600s timeout; the sleep is a test seam.
for _try in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  out="$(bash "$ROOT/bin/board" sync "$cwd" 2>/dev/null)"
  [ "$(printf '%s' "$out" | jq -r '.skipped // empty' 2>/dev/null)" = "locked" ] || break
  sleep "${BOARD_HOOK_RETRY_SLEEP:-25}"
done
exit 0
