#!/usr/bin/env bash
# stop.sh — digest-gated board sync after a session turn. NEVER fails the
# session: every path exits 0. Output is discarded (async hook).
set +e
ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
input="$(cat 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"
command -v jq >/dev/null 2>&1 || exit 0
bash "$ROOT/bin/board" sync "$cwd" >/dev/null 2>&1
exit 0
