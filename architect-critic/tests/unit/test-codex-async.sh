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
echo "-- dispatch missing model value → rc1 --"
assert_exit_code 1 bash "$ARC" codex_dispatch "$ROOT/repo" "$pf" --model

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
got="$(bash "$ARC" codex_wait "$ROOT/repo" "job-xyz" --poll 2>/dev/null)"
assert_eq "wait missing poll value returns error token" "error" "$got"
export CODEX_SHIM_STATUS="completed"

echo ""
echo "-- result extracts last {challenges,gaps} fence (prose before fence) --"
export CODEX_SHIM_RESULT_RAWOUTPUT='reasoning first
```json
{"challenges":[{"text":"X","severity":"premise","rationale":"r"}],"gaps":[]}
```
noise
```json
{"challenges":[{"text":"Y","severity":"gap","rationale":"r2"}],"gaps":[]}
```'
got="$(bash "$ARC" codex_result "$ROOT/repo" "job-xyz" 2>/dev/null | jq -r '.challenges[0].text')"
assert_eq "result extracts last fenced challenge text" "Y" "$got"

echo ""
echo "-- result rejects non-contract severity labels --"
export CODEX_SHIM_RESULT_RAWOUTPUT='```json
{"challenges":[{"text":"X","severity":"high","rationale":"r"}],"gaps":[]}
```'
assert_exit_code 1 bash "$ARC" codex_result "$ROOT/repo" "job-xyz"

echo ""
echo "-- result rejects non-object gaps --"
export CODEX_SHIM_RESULT_RAWOUTPUT='```json
{"challenges":[{"text":"X","severity":"gap","rationale":"r"}],"gaps":["missing auth plan"]}
```'
assert_exit_code 1 bash "$ARC" codex_result "$ROOT/repo" "job-xyz"

echo ""
echo "-- result with no fenced JSON → rc1 --"
export CODEX_SHIM_RESULT_RAWOUTPUT='no json here at all'
assert_exit_code 1 bash "$ARC" codex_result "$ROOT/repo" "job-xyz"
unset CODEX_SHIM_RESULT_RAWOUTPUT

echo ""
echo "-- status: one-shot running check does not cancel --"
export CODEX_SHIM_STATUS="running"
export CODEX_SHIM_LOG="$ROOT/status.log"; : > "$CODEX_SHIM_LOG"
got="$(bash "$ARC" codex_status "$ROOT/repo" "job-xyz" 2>/dev/null)"
assert_eq "status reports running" "running" "$got"
grep -q '^cancel ' "$CODEX_SHIM_LOG" && { echo "  ✗ status unexpectedly cancelled job"; FAIL=$((FAIL+1)); } || { echo "  ✓ status did not cancel job"; PASS=$((PASS+1)); }
unset CODEX_SHIM_LOG

echo ""
echo "-- status: unknown companion token normalizes to error --"
export CODEX_SHIM_STATUS="mystery"
got="$(bash "$ARC" codex_status "$ROOT/repo" "job-xyz" 2>/dev/null)"
assert_eq "unknown status returns error" "error" "$got"

echo ""
echo "-- cancel: completed race preserves completed status --"
export CODEX_SHIM_STATUS="completed"
export CODEX_SHIM_LOG="$ROOT/cancel-completed.log"; : > "$CODEX_SHIM_LOG"
got="$(bash "$ARC" codex_cancel "$ROOT/repo" "job-xyz" 2>/dev/null)"
assert_eq "cancel preserves already-completed job" "completed" "$got"
grep -q '^cancel ' "$CODEX_SHIM_LOG" && { echo "  ✗ cancel called companion cancel for completed job"; FAIL=$((FAIL+1)); } || { echo "  ✓ cancel skipped terminal completed job"; PASS=$((PASS+1)); }
unset CODEX_SHIM_LOG
export CODEX_SHIM_STATUS="completed"

echo ""
echo "-- cancel: unknown companion token normalizes to error --"
export CODEX_SHIM_STATUS="running"
export CODEX_SHIM_CANCEL_STATUS="mystery"
got="$(bash "$ARC" codex_cancel "$ROOT/repo" "job-xyz" 2>/dev/null)"
assert_eq "unknown cancel status returns error" "error" "$got"
unset CODEX_SHIM_CANCEL_STATUS
export CODEX_SHIM_CANCEL_RAW='{"job":{}}'
got="$(bash "$ARC" codex_cancel "$ROOT/repo" "job-xyz" 2>/dev/null)"
assert_eq "unparseable cancel status returns error" "error" "$got"
unset CODEX_SHIM_CANCEL_RAW
export CODEX_SHIM_STATUS="completed"

echo ""
echo "-- size hint: big→background, small→foreground --"
big="$ROOT/big.md"; i=0; while [[ $i -lt 500 ]]; do echo "line $i"; i=$((i+1)); done > "$big"
small="$ROOT/small.md"; printf 'tiny spec\n' > "$small"
assert_eq "big artifact → background" "background" "$(bash "$ARC" codex_size_hint "$big")"
assert_eq "small artifact → foreground" "foreground" "$(bash "$ARC" codex_size_hint "$small")"
assert_eq "threshold override honored" "background" "$(ARCHITECT_CRITIC_ASYNC_HINT_LINES=1 bash "$ARC" codex_size_hint "$small")"
assert_exit_code 0 env ARCHITECT_CRITIC_ASYNC_HINT_LINES=large bash "$ARC" codex_size_hint "$small"
assert_eq "invalid threshold falls back to default" "foreground" "$(ARCHITECT_CRITIC_ASYNC_HINT_LINES=large bash "$ARC" codex_size_hint "$small" 2>/dev/null)"

echo ""
echo "-- seam-prose lints (critiquing-spec) --"
SK="$PLUGIN_ROOT/skills/critiquing-spec/SKILL.md"
grep -q -- "--async" "$SK" && { echo "  ✓ --async branch documented"; PASS=$((PASS+1)); } || { echo "  ✗ no --async branch"; FAIL=$((FAIL+1)); }
grep -qi "Consolidate + Rebuttal + Append" "$SK" && { echo "  ✓ shared procedure labelled"; PASS=$((PASS+1)); } || { echo "  ✗ no shared-procedure label"; FAIL=$((FAIL+1)); }
grep -qi "no silent\|NO silent\|do not silently\|no foreground fallback\|hard-fail" "$SK" && { echo "  ✓ no-silent-fallback rule present"; PASS=$((PASS+1)); } || { echo "  ✗ fallback rule missing"; FAIL=$((FAIL+1)); }
grep -q "codex_size_hint" "$SK" && { echo "  ✓ size hint wired"; PASS=$((PASS+1)); } || { echo "  ✗ size hint not referenced"; FAIL=$((FAIL+1)); }

report_results
