#!/usr/bin/env bash
# test-codex-async.sh — async codex spine (companion task --background) for v0.3 (#39).
# Drives the env-driven codex-companion shim via bin/arc (no real Codex, no network).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# shellcheck source=../_helpers.sh
source "$TESTS_DIR/_helpers.sh"

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
ARC="$PLUGIN_ROOT/bin/arc"

echo "=== test-codex-async.sh (v0.3) ==="

# Async spine drives the companion via `node`; loud-skip if node is absent.
if ! command -v node >/dev/null 2>&1; then
  echo "  ! node not found — skipping async codex tests (loud skip)"
  exit 0
fi

ROOT="$(setup_tmp_repo)"
setup_codex_companion_shim
# Isolate CODEX_HOME so preflight's trust check never reads the developer's real
# ~/.codex/config.toml (undetermined trust → preflight proceeds under approval=never).
export CODEX_HOME="$ROOT/codex-home"; mkdir -p "$CODEX_HOME"

echo ""
echo "-- resolve_companion honors override --"
got="$(bash "$ARC" codex_resolve_companion 2>/dev/null)"
assert_eq "resolve returns override path" "$ARCHITECT_CRITIC_CODEX_COMPANION" "$got"

echo ""
echo "-- preflight ready --"
assert_exit_code 0 bash "$ARC" codex_preflight "$ROOT/repo"

echo ""
echo "-- preflight unauthed → rc1 --"
export CODEX_SHIM_SETUP='{"ready":false,"codex":{"available":true},"auth":{"loggedIn":false}}'
assert_exit_code 1 bash "$ARC" codex_preflight "$ROOT/repo"
unset CODEX_SHIM_SETUP

echo ""
echo "-- dispatch echoes jobId; logs --background, NOT --write --"
pf="$ROOT/prompt.md"; printf 'audit this spec\n' > "$pf"
export CODEX_SHIM_JOBID="job-xyz"
export CODEX_SHIM_LOG="$ROOT/argv.log"; : > "$CODEX_SHIM_LOG"
got="$(bash "$ARC" codex_dispatch "$ROOT/repo" "$pf" 2>/dev/null)"
assert_eq "dispatch echoes jobId" "job-xyz" "$got"
grep -q -- "--background" "$CODEX_SHIM_LOG" && { echo "  ✓ passes --background"; PASS=$((PASS+1)); } || { echo "  ✗ no --background"; FAIL=$((FAIL+1)); }
grep -q -- "--write" "$CODEX_SHIM_LOG" && { echo "  ✗ unexpected --write (adversary is read-only)"; FAIL=$((FAIL+1)); } || { echo "  ✓ read-only (no --write)"; PASS=$((PASS+1)); }
unset CODEX_SHIM_LOG

echo ""
echo "-- dispatch with no jobId → rc1 --"
export CODEX_SHIM_NO_JOBID=1
assert_exit_code 1 bash "$ARC" codex_dispatch "$ROOT/repo" "$pf"
unset CODEX_SHIM_NO_JOBID

echo ""
echo "-- wait: completed token (rc0) --"
export CODEX_SHIM_STATUS="completed"
got="$(bash "$ARC" codex_wait "$ROOT/repo" "job-xyz" --poll 0 2>/dev/null)"
assert_eq "wait completed" "completed" "$got"

echo ""
echo "-- wait: legacy 'done' normalizes to completed --"
export CODEX_SHIM_STATUS="done"
got="$(bash "$ARC" codex_wait "$ROOT/repo" "job-xyz" --poll 0 2>/dev/null)"
assert_eq "wait done→completed" "completed" "$got"

echo ""
echo "-- wait: failed token, non-throwing (rc0) --"
export CODEX_SHIM_STATUS="failed"
got="$(bash "$ARC" codex_wait "$ROOT/repo" "job-xyz" --poll 0 2>/dev/null)"
assert_eq "wait failed token" "failed" "$got"
assert_exit_code 0 bash "$ARC" codex_wait "$ROOT/repo" "job-xyz" --poll 0
export CODEX_SHIM_STATUS="completed"

echo ""
echo "-- result extracts {challenges,gaps} (prose before fence) --"
export CODEX_SHIM_RESULT_RAWOUTPUT='reasoning first
```json
{"challenges":[{"text":"X","severity":"high","rationale":"r"}],"gaps":[]}
```'
got="$(bash "$ARC" codex_result "$ROOT/repo" "job-xyz" 2>/dev/null | jq -r '.challenges[0].text')"
assert_eq "result extracts challenge text" "X" "$got"

echo ""
echo "-- result with no fenced JSON → rc1 --"
export CODEX_SHIM_RESULT_RAWOUTPUT='no json here at all'
assert_exit_code 1 bash "$ARC" codex_result "$ROOT/repo" "job-xyz"
unset CODEX_SHIM_RESULT_RAWOUTPUT

echo ""
echo "-- size hint: big→background, small→foreground --"
big="$ROOT/big.md"; i=0; while [[ $i -lt 500 ]]; do echo "line $i"; i=$((i+1)); done > "$big"
small="$ROOT/small.md"; printf 'tiny spec\n' > "$small"
assert_eq "big artifact → background" "background" "$(bash "$ARC" codex_size_hint "$big")"
assert_eq "small artifact → foreground" "foreground" "$(bash "$ARC" codex_size_hint "$small")"
assert_eq "threshold override honored" "background" "$(ARCHITECT_CRITIC_ASYNC_HINT_LINES=1 bash "$ARC" codex_size_hint "$small")"

echo ""
echo "-- seam-prose lints (critiquing-spec) --"
SK="$PLUGIN_ROOT/skills/critiquing-spec/SKILL.md"
grep -q -- "--async" "$SK" && { echo "  ✓ --async branch documented"; PASS=$((PASS+1)); } || { echo "  ✗ no --async branch"; FAIL=$((FAIL+1)); }
grep -qi "Consolidate + Rebuttal + Append" "$SK" && { echo "  ✓ shared procedure labelled"; PASS=$((PASS+1)); } || { echo "  ✗ no shared-procedure label"; FAIL=$((FAIL+1)); }
grep -qi "no silent\|NO silent\|do not silently\|no foreground fallback\|hard-fail" "$SK" && { echo "  ✓ no-silent-fallback rule present"; PASS=$((PASS+1)); } || { echo "  ✗ fallback rule missing"; FAIL=$((FAIL+1)); }
grep -q "codex_size_hint" "$SK" && { echo "  ✓ size hint wired"; PASS=$((PASS+1)); } || { echo "  ✗ size hint not referenced"; FAIL=$((FAIL+1)); }

report_results
