#!/usr/bin/env bash
# test-doctor.sh — adversary readiness doctor (ac_codex_doctor), #39.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/_helpers.sh"

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
ARC="$PLUGIN_ROOT/bin/arc"

echo "=== test-doctor.sh ==="
if ! command -v node >/dev/null 2>&1; then
  echo "  ! node not found — skipping doctor tests (loud skip)"; exit 0
fi

ROOT="$(setup_tmp_repo)"
setup_codex_companion_shim

echo "-- ready path: fail-soft (rc0) + reports companion + ready --"
out="$(bash "$ARC" codex_doctor 2>&1)"
assert_exit_code 0 bash "$ARC" codex_doctor
echo "$out" | grep -qi "companion" && { echo "  ✓ reports companion"; PASS=$((PASS+1)); } || { echo "  ✗ no companion line"; FAIL=$((FAIL+1)); }
echo "$out" | grep -qi "ready" && { echo "  ✓ reports ready (shim setup ready:true)"; PASS=$((PASS+1)); } || { echo "  ✗ no ready line"; FAIL=$((FAIL+1)); }

echo "-- unauthed: rc0 + surfaces 'codex login' --"
export CODEX_SHIM_SETUP='{"ready":false,"codex":{"available":true},"auth":{"loggedIn":false}}'
out="$(bash "$ARC" codex_doctor 2>&1)"
assert_exit_code 0 bash "$ARC" codex_doctor
echo "$out" | grep -qi "codex login" && { echo "  ✓ surfaces login remediation"; PASS=$((PASS+1)); } || { echo "  ✗ no login hint"; FAIL=$((FAIL+1)); }
unset CODEX_SHIM_SETUP

echo "-- missing companion: rc0 + surfaces install/override remediation --"
export ARCHITECT_CRITIC_CODEX_COMPANION="$ROOT/nope.mjs"
out="$(bash "$ARC" codex_doctor 2>&1)"
assert_exit_code 0 bash "$ARC" codex_doctor
echo "$out" | grep -qiE "not found|install|ARCHITECT_CRITIC_CODEX_COMPANION" && { echo "  ✓ surfaces remediation"; PASS=$((PASS+1)); } || { echo "  ✗ no remediation"; FAIL=$((FAIL+1)); }

report_results
