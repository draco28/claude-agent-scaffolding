#!/usr/bin/env bash
# Live smoke against the real instance. Needs Task 0 env. Creates and deletes
# a throwaway project; touches nothing else.
set -u
[ "${BOARD_LIVE:-0}" = "1" ] || { echo "set BOARD_LIVE=1 to run against ${HULY_URL:-<unset>}"; exit 0; }
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../.."; . "$ROOT/lib/cli.sh"
WS="$(mktemp -d)/smoke-ai"; mkdir -p "$WS/.ossify"; cp "$ROOT/tests/fixtures/state/dag.json" "$WS/.ossify/project-state.json"
P="BRDSMK$(date +%H%M)"
echo "== first sync (bind $P)"; r1="$(bash "$ROOT/bin/board" sync "$WS" --bind "$P")"; rc=$?; echo "$r1"; [ $rc -eq 0 ] || exit 1
echo "== second sync (force)"; r2="$(bash "$ROOT/bin/board" sync "$WS" --force)"; rc=$?; echo "$r2"; [ $rc -eq 0 ] || exit 1
c="$(jq -r '.created' <<<"$r2")"; u="$(jq -r '.updated' <<<"$r2")"
echo "== cleanup"; board_cli projects delete "$P" --yes >/dev/null 2>&1 || echo "(delete $P by hand)"
[ "$c" = "0" ] && [ "$u" = "0" ] && echo "SMOKE OK: second run created=0 updated=0" || { echo "SMOKE FAIL: second run created=$c updated=$u"; exit 1; }
