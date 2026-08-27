#!/usr/bin/env bash
# Live smoke against the real instance. Needs Task 0 env, and a project 'SMK' created
# ONCE by hand in Tracker with the Ossify type — typed project creation is UI-only (the
# CLI cannot do it), so the smoke can no longer create, and must never delete, its project.
set -u
[ "${BOARD_LIVE:-0}" = "1" ] || { echo "set BOARD_LIVE=1 to run against ${HULY_URL:-<unset>}"; exit 0; }
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$HERE/../.."; . "$ROOT/lib/cli.sh"
P="SMK"
board_cli_project_get "$P" || {
  cat <<EOF
smoke: project '$P' does not exist in workspace '${HULY_WORKSPACE:-?}'.
Create it once, by hand: Tracker › New project — name 'smoke', identifier '$P',
project type 'Ossify project'. Then rerun this smoke test.
EOF
  exit 1
}
WS="$(mktemp -d)/smoke-ai"; mkdir -p "$WS/.ossify"; cp "$ROOT/tests/fixtures/state/dag.json" "$WS/.ossify/project-state.json"
echo "== first sync (bind $P)"; r1="$(bash "$ROOT/bin/board" sync "$WS" --bind "$P")"; rc=$?; echo "$r1"; [ $rc -eq 0 ] || exit 1
echo "== second sync (force)"; r2="$(bash "$ROOT/bin/board" sync "$WS" --force)"; rc=$?; echo "$r2"; [ $rc -eq 0 ] || exit 1
c="$(jq -r '.created' <<<"$r2")"; u="$(jq -r '.updated' <<<"$r2")"
[ "$c" = "0" ] && [ "$u" = "0" ] && echo "SMOKE OK: second run created=0 updated=0" || { echo "SMOKE FAIL: second run created=$c updated=$u"; exit 1; }
