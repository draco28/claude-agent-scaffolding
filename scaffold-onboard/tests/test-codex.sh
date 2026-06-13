#!/usr/bin/env bash
# tests/test-codex.sh — lib/codex.sh synthesis adapter (SS-5.1). Mock companion
# via SCAFFOLD_CODEX_COMPANION; every helper exercised through bin/sf
# (dispatcher-path) so the set -e safety (esp. sf_codex_wait) is under test.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
SF_BIN="$HERE/../bin/sf"
SHIM="$HERE/codex-shim/codex-companion.mjs"
export SCAFFOLD_CODEX_COMPANION="$SHIM"

if ! command -v node >/dev/null 2>&1; then
  echo "test-codex.sh: SKIP — node not found (codex_* helpers exec node <companion>)"
  exit 0
fi

assert_match() {
  local label="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then
    PASS=$((PASS+1)); echo "  $(_color_pass '✓') $label"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail '✗') $label"
    echo "    expected substring: $needle"; echo "    in: $hay"
  fi
}

# ── resolve ────────────────────────────────────────────────────────────────
test_resolve_override() {
  echo "test_resolve_override:"
  local out rc
  out="$(bash "$SF_BIN" codex_resolve_companion)" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "echoes the override shim path" "$SHIM" "$out"
}

test_resolve_absent_fails() {
  echo "test_resolve_absent_fails:"
  local out rc
  out="$(SCAFFOLD_CODEX_COMPANION=/no/such/companion.mjs bash "$SF_BIN" codex_resolve_companion 2>&1)" && rc=0 || rc=$?
  assert_eq "rc=1 when override points at a missing file" "1" "$rc"
  assert_match "remediation names the override env" "SCAFFOLD_CODEX_COMPANION" "$out"
}

# ── target_root ────────────────────────────────────────────────────────────
test_target_root_git_toplevel() {
  echo "test_target_root_git_toplevel:"
  setup_tmp_repo
  local out rc
  out="$(bash "$SF_BIN" codex_target_root "$TMP_DIR/repo/.claude/memory-bank/00-project-brief.md")" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "resolves to the git toplevel" "$(cd "$TMP_DIR/repo" && pwd -P)" "$out"
}

test_target_root_non_git_ancestor() {
  echo "test_target_root_non_git_ancestor:"
  setup_tmp_repo
  local plain="$TMP_DIR/plain"; mkdir -p "$plain"
  local out
  out="$(bash "$SF_BIN" codex_target_root "$plain/deep/nested/out.md")"
  assert_eq "non-git path → nearest existing ancestor dir" "$(cd "$plain" && pwd -P)" "$out"
}

# ── preflight ──────────────────────────────────────────────────────────────
test_preflight_ready_trust_undetermined() {
  echo "test_preflight_ready_trust_undetermined:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/ch-empty"
  local rc
  # Empty CODEX_HOME (no config.toml) → trust undetermined → warn + proceed.
  ( cd "$TMP_DIR/repo" && CODEX_HOME="$TMP_DIR/ch-empty" bash "$SF_BIN" codex_preflight "$TMP_DIR/repo" >/dev/null 2>&1 ) && rc=0 || rc=$?
  assert_eq "rc=0 when companion ready + trust undetermined" "0" "$rc"
}

test_preflight_unauthed() {
  echo "test_preflight_unauthed:"
  setup_tmp_repo
  local out rc
  out="$(cd "$TMP_DIR/repo" && CODEX_HOME="$TMP_DIR/ch-empty2" \
      CODEX_SHIM_SETUP='{"ready":false,"codex":{"available":true},"auth":{"loggedIn":false}}' \
      bash "$SF_BIN" codex_preflight "$TMP_DIR/repo" 2>&1)" && rc=0 || rc=$?
  assert_eq "rc=1 when not authed" "1" "$rc"
  assert_match "remediation says codex login" "codex login" "$out"
}

test_preflight_uninstalled() {
  echo "test_preflight_uninstalled:"
  setup_tmp_repo
  local out rc
  out="$(cd "$TMP_DIR/repo" && CODEX_HOME="$TMP_DIR/ch-empty3" \
      CODEX_SHIM_SETUP='{"ready":false,"codex":{"available":false},"auth":{"loggedIn":false}}' \
      bash "$SF_BIN" codex_preflight "$TMP_DIR/repo" 2>&1)" && rc=0 || rc=$?
  assert_eq "rc=1 when codex CLI unavailable" "1" "$rc"
  assert_match "remediation names Codex CLI" "Codex CLI not available" "$out"
}

test_preflight_untrusted_dir() {
  echo "test_preflight_untrusted_dir:"
  setup_tmp_repo
  local ch="$TMP_DIR/ch-trust"; mkdir -p "$ch"
  printf '[projects."/some/other/trusted"]\ntrust_level = "trusted"\n' > "$ch/config.toml"
  local rc
  ( cd "$TMP_DIR/repo" && CODEX_HOME="$ch" bash "$SF_BIN" codex_preflight "$TMP_DIR/repo" >/dev/null 2>&1 ) && rc=0 || rc=$?
  assert_eq "rc=1 when target root is outside all trusted roots" "1" "$rc"
}

# ── dispatch ───────────────────────────────────────────────────────────────
test_dispatch_jobid_and_flags() {
  echo "test_dispatch_jobid_and_flags:"
  setup_tmp_repo
  local pf="$TMP_DIR/prompt.md"; printf 'synthesize X\n' > "$pf"
  local logf="$TMP_DIR/argv.log"
  local out
  out="$(cd "$TMP_DIR/repo" && CODEX_SHIM_LOG="$logf" bash "$SF_BIN" codex_dispatch "$TMP_DIR/repo" "$pf")"
  assert_eq "echoes shim job id" "task-shim001" "$out"
  assert_match "passed --write"        "--write"        "$(cat "$logf")"
  assert_match "passed --background"   "--background"   "$(cat "$logf")"
  assert_match "passed --prompt-file"  "--prompt-file"  "$(cat "$logf")"
}

test_dispatch_missing_prompt_file() {
  echo "test_dispatch_missing_prompt_file:"
  setup_tmp_repo
  local rc
  ( cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_dispatch "$TMP_DIR/repo" "$TMP_DIR/nope.md" >/dev/null 2>&1 ) && rc=0 || rc=$?
  assert_eq "rc=1 on missing prompt-file" "1" "$rc"
}

test_dispatch_resume_fresh_conflict() {
  echo "test_dispatch_resume_fresh_conflict:"
  setup_tmp_repo
  local pf="$TMP_DIR/p.md"; printf 'x\n' > "$pf"
  local rc
  ( cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_dispatch "$TMP_DIR/repo" "$pf" --resume-last --fresh >/dev/null 2>&1 ) && rc=0 || rc=$?
  assert_eq "rc=1 on --resume-last + --fresh conflict" "1" "$rc"
}

test_dispatch_no_jobid() {
  echo "test_dispatch_no_jobid:"
  setup_tmp_repo
  local pf="$TMP_DIR/p.md"; printf 'x\n' > "$pf"
  local rc
  ( cd "$TMP_DIR/repo" && CODEX_SHIM_NO_JOBID=1 bash "$SF_BIN" codex_dispatch "$TMP_DIR/repo" "$pf" >/dev/null 2>&1 ) && rc=0 || rc=$?
  assert_eq "rc=1 when launch payload has no jobId" "1" "$rc"
}

# ── wait (the set -e-critical surface — ALWAYS rc=0) ───────────────────────
test_wait_completed() {
  echo "test_wait_completed:"
  setup_tmp_repo
  local out rc
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_wait "$TMP_DIR/repo" task-shim001 --poll 0)" && rc=0 || rc=$?
  assert_eq "rc=0" "0" "$rc"
  assert_eq "completed token" "completed" "$out"
}

test_wait_done_normalized() {
  echo "test_wait_done_normalized:"
  setup_tmp_repo
  local out
  out="$(cd "$TMP_DIR/repo" && CODEX_SHIM_STATUS=done bash "$SF_BIN" codex_wait "$TMP_DIR/repo" task-shim001 --poll 0)"
  assert_eq "legacy done normalized to completed" "completed" "$out"
}

test_wait_failed_nonthrowing() {
  echo "test_wait_failed_nonthrowing:"
  setup_tmp_repo
  local out rc
  out="$(cd "$TMP_DIR/repo" && CODEX_SHIM_STATUS=failed bash "$SF_BIN" codex_wait "$TMP_DIR/repo" task-shim001 --poll 0)" && rc=0 || rc=$?
  assert_eq "rc=0 (non-throwing under set -e)" "0" "$rc"
  assert_eq "failed token" "failed" "$out"
}

test_wait_stall_cancels() {
  echo "test_wait_stall_cancels:"
  setup_tmp_repo
  local logfile="$TMP_DIR/joblog"; : > "$logfile"; touch -t 200001010000 "$logfile"
  local argv="$TMP_DIR/argv-stall.log"
  local out
  out="$(cd "$TMP_DIR/repo" && CODEX_SHIM_STATUS=running CODEX_SHIM_LOGFILE="$logfile" CODEX_SHIM_LOG="$argv" \
        bash "$SF_BIN" codex_wait "$TMP_DIR/repo" task-shim001 --poll 0 --stall 1 --cap 9999)"
  assert_eq "stalled token" "stalled" "$out"
  assert_match "issued cancel on stall" "cancel" "$(cat "$argv")"
}

test_wait_cap_cancels() {
  echo "test_wait_cap_cancels:"
  setup_tmp_repo
  local argv="$TMP_DIR/argv-cap.log"
  local out
  out="$(cd "$TMP_DIR/repo" && CODEX_SHIM_STATUS=running CODEX_SHIM_LOG="$argv" \
        bash "$SF_BIN" codex_wait "$TMP_DIR/repo" task-shim001 --poll 0 --cap 0)"
  assert_eq "capped token" "capped" "$out"
  assert_match "issued cancel on cap" "cancel" "$(cat "$argv")"
}

test_wait_bad_option_error_rc0() {
  echo "test_wait_bad_option_error_rc0:"
  setup_tmp_repo
  local out rc
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_wait "$TMP_DIR/repo" task-shim001 --poll notanum 2>/dev/null)" && rc=0 || rc=$?
  assert_eq "rc=0 even on bad option" "0" "$rc"
  assert_eq "error token" "error" "$out"
}

test_wait_unparseable_status_error() {
  echo "test_wait_unparseable_status_error:"
  setup_tmp_repo
  local out
  out="$(cd "$TMP_DIR/repo" && CODEX_SHIM_STATUS_RAW='not json at all' bash "$SF_BIN" codex_wait "$TMP_DIR/repo" task-shim001 --poll 0 2>/dev/null)"
  assert_eq "error token on unparseable status" "error" "$out"
}

# ── result ─────────────────────────────────────────────────────────────────
test_result_complete() {
  echo "test_result_complete:"
  setup_tmp_repo
  local out
  out="$(cd "$TMP_DIR/repo" && bash "$SF_BIN" codex_result "$TMP_DIR/repo" task-shim001)"
  assert_eq "mode complete" "complete" "$(printf '%s' "$out" | jq -r '.mode')"
  assert_eq "carries output_path" "/tmp/out.md" "$(printf '%s' "$out" | jq -r '.output_path')"
}

test_result_failed_mode() {
  echo "test_result_failed_mode:"
  setup_tmp_repo
  local raw='```json
{"mode":"failed","reason":"could not satisfy brief","partial_output_path":null}
```'
  local out
  out="$(cd "$TMP_DIR/repo" && CODEX_SHIM_RESULT_RAWOUTPUT="$raw" bash "$SF_BIN" codex_result "$TMP_DIR/repo" task-shim001)"
  assert_eq "mode failed extracted" "failed" "$(printf '%s' "$out" | jq -r '.mode')"
}

test_result_prose_before_fence() {
  echo "test_result_prose_before_fence:"
  setup_tmp_repo
  local raw='Reasoning prose first.

```json
{"mode":"complete","output_path":"/x.md","ids_minted":{},"ids_cited":[],"summary":"ok"}
```'
  local out
  out="$(cd "$TMP_DIR/repo" && CODEX_SHIM_RESULT_RAWOUTPUT="$raw" bash "$SF_BIN" codex_result "$TMP_DIR/repo" task-shim001)"
  assert_eq "extracts despite leading prose" "complete" "$(printf '%s' "$out" | jq -r '.mode')"
}

test_result_multi_fence_takes_last() {
  echo "test_result_multi_fence_takes_last:"
  setup_tmp_repo
  local raw='```json
{"mode":"complete","summary":"FIRST"}
```
then more
```json
{"mode":"complete","summary":"LAST"}
```'
  local out
  out="$(cd "$TMP_DIR/repo" && CODEX_SHIM_RESULT_RAWOUTPUT="$raw" bash "$SF_BIN" codex_result "$TMP_DIR/repo" task-shim001)"
  assert_eq "takes the LAST fenced block" "LAST" "$(printf '%s' "$out" | jq -r '.summary')"
}

test_result_no_fence_rc1() {
  echo "test_result_no_fence_rc1:"
  setup_tmp_repo
  local rc
  ( cd "$TMP_DIR/repo" && CODEX_SHIM_RESULT_RAWOUTPUT="just prose, no fence" bash "$SF_BIN" codex_result "$TMP_DIR/repo" task-shim001 >/dev/null 2>&1 ) && rc=0 || rc=$?
  assert_eq "rc=1 when no fenced JSON" "1" "$rc"
}

test_result_fence_without_mode_rc1() {
  echo "test_result_fence_without_mode_rc1:"
  setup_tmp_repo
  local raw='```json
{"output_path":"/x.md","summary":"no mode here"}
```'
  local rc
  ( cd "$TMP_DIR/repo" && CODEX_SHIM_RESULT_RAWOUTPUT="$raw" bash "$SF_BIN" codex_result "$TMP_DIR/repo" task-shim001 >/dev/null 2>&1 ) && rc=0 || rc=$?
  assert_eq "rc=1 when fenced block lacks .mode" "1" "$rc"
}

test_resolve_override
test_resolve_absent_fails
test_target_root_git_toplevel
test_target_root_non_git_ancestor
test_preflight_ready_trust_undetermined
test_preflight_unauthed
test_preflight_uninstalled
test_preflight_untrusted_dir
test_dispatch_jobid_and_flags
test_dispatch_missing_prompt_file
test_dispatch_resume_fresh_conflict
test_dispatch_no_jobid
test_wait_completed
test_wait_done_normalized
test_wait_failed_nonthrowing
test_wait_stall_cancels
test_wait_cap_cancels
test_wait_bad_option_error_rc0
test_wait_unparseable_status_error
test_result_complete
test_result_failed_mode
test_result_prose_before_fence
test_result_multi_fence_takes_last
test_result_no_fence_rc1
test_result_fence_without_mode_rc1
report_results
