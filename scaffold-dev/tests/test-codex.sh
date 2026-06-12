#!/usr/bin/env bash
# tests/test-codex.sh — tests for lib/codex.sh (SS-5 Codex implementer backend).
# Every set-e-sensitive helper is exercised THROUGH bin/sd (the dispatcher runs
# `set -euo pipefail`), per the SS-4 lesson: a helper can be correct in-process
# yet abort under the dispatcher. NO real Codex / NO network — the env-driven
# fake at tests/fixtures/codex-shim/codex-companion.mjs stands in for it.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"

SD_BIN="$HERE/../bin/sd"
SHIM="$HERE/fixtures/codex-shim/codex-companion.mjs"
export SCAFFOLD_CODEX_COMPANION="$SHIM"

if ! command -v node >/dev/null 2>&1; then
  echo "SKIP test-codex: node not available (the Codex backend requires node to run codex-companion.mjs)"
  exit 0
fi

# run_sd <verb> [args…] — dispatcher-path invocation; sets OUT + RC.
run_sd() {
  OUT="$(bash "$SD_BIN" "$@" 2>&1)" && RC=0 || RC=$?
}

# --- resolve -------------------------------------------------------------

test_resolve_override() {
  echo "test_resolve_override:"
  setup_tmp_repo
  run_sd codex_resolve_companion
  assert_eq "override path echoed" "$SHIM" "$OUT"
  assert_eq "rc=0" "0" "$RC"
}

test_resolve_override_missing() {
  echo "test_resolve_override_missing:"
  setup_tmp_repo
  OUT="$(SCAFFOLD_CODEX_COMPANION=/nope/x.mjs bash "$SD_BIN" codex_resolve_companion 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 on missing override" "1" "$RC"
  assert_contains "remediation names the override env" "SCAFFOLD_CODEX_COMPANION" "$OUT"
}

test_resolve_glob_newest() {
  echo "test_resolve_glob_newest:"
  setup_tmp_repo
  local fc="$TMP_DIR/fc"
  mkdir -p "$fc/openai-codex/codex/1.0.3/scripts" "$fc/openai-codex/codex/1.0.5/scripts"
  touch "$fc/openai-codex/codex/1.0.3/scripts/codex-companion.mjs" \
        "$fc/openai-codex/codex/1.0.5/scripts/codex-companion.mjs"
  OUT="$(SCAFFOLD_CODEX_COMPANION= SCAFFOLD_CODEX_CACHE_DIRS="$fc" bash "$SD_BIN" codex_resolve_companion 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_contains "newest version chosen" "1.0.5/scripts/codex-companion.mjs" "$OUT"
}

test_resolve_absent() {
  echo "test_resolve_absent:"
  setup_tmp_repo
  mkdir -p "$TMP_DIR/empty"
  OUT="$(SCAFFOLD_CODEX_COMPANION= SCAFFOLD_CODEX_CACHE_DIRS="$TMP_DIR/empty" bash "$SD_BIN" codex_resolve_companion 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 when absent" "1" "$RC"
  assert_contains "remediation on absent" "not found" "$OUT"
}

# --- preflight -----------------------------------------------------------

test_preflight_ready() {
  echo "test_preflight_ready:"
  setup_tmp_repo
  OUT="$(CODEX_HOME="$TMP_DIR/nocodex" bash "$SD_BIN" codex_preflight "$TMP_DIR/repo" 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=0 when ready" "0" "$RC"
}

test_preflight_unauthed() {
  echo "test_preflight_unauthed:"
  setup_tmp_repo
  OUT="$(CODEX_SHIM_SETUP='{"ready":false,"codex":{"available":true},"auth":{"loggedIn":false}}' \
        CODEX_HOME="$TMP_DIR/nocodex" bash "$SD_BIN" codex_preflight "$TMP_DIR/repo" 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 when unauthed" "1" "$RC"
  assert_contains "remediation names codex login" "codex login" "$OUT"
}

test_preflight_uninstalled() {
  echo "test_preflight_uninstalled:"
  setup_tmp_repo
  OUT="$(CODEX_SHIM_SETUP='{"ready":false,"codex":{"available":false},"auth":{"loggedIn":false}}' \
        CODEX_HOME="$TMP_DIR/nocodex" bash "$SD_BIN" codex_preflight "$TMP_DIR/repo" 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 when uninstalled" "1" "$RC"
  assert_contains "remediation names Codex CLI" "Codex CLI not available" "$OUT"
}

test_preflight_untrusted_worktree() {
  echo "test_preflight_untrusted_worktree:"
  setup_tmp_repo
  local ch="$TMP_DIR/codexhome"
  mkdir -p "$ch"
  printf '[projects."/some/other/trusted"]\ntrust_level = "trusted"\n' > "$ch/config.toml"
  OUT="$(CODEX_HOME="$ch" bash "$SD_BIN" codex_preflight "$TMP_DIR/repo" 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 when worktree outside trusted roots" "1" "$RC"
  assert_contains "remediation names trust" "outside every Codex-trusted" "$OUT"
}

# --- dispatch ------------------------------------------------------------

test_dispatch_jobid_and_flags() {
  echo "test_dispatch_jobid_and_flags:"
  setup_tmp_repo
  local pf="$TMP_DIR/prompt.md"; echo "do the work item" > "$pf"
  local log="$TMP_DIR/argv.log"
  OUT="$(CODEX_SHIM_LOG="$log" bash "$SD_BIN" codex_dispatch "$TMP_DIR/repo" "$pf" 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "jobId echoed" "task-shim001" "$OUT"
  local argv; argv="$(cat "$log")"
  assert_contains "passes --background" "--background" "$argv"
  assert_contains "passes --write" "--write" "$argv"
  assert_contains "passes --prompt-file" "--prompt-file" "$argv"
  assert_contains "prompt-file is absolute" "--prompt-file $TMP_DIR" "$argv"
}

test_dispatch_model_effort() {
  echo "test_dispatch_model_effort:"
  setup_tmp_repo
  local pf="$TMP_DIR/prompt.md"; echo "x" > "$pf"
  local log="$TMP_DIR/argv.log"
  OUT="$(CODEX_SHIM_LOG="$log" bash "$SD_BIN" codex_dispatch "$TMP_DIR/repo" "$pf" --model gpt-5.5 --effort high 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  local argv; argv="$(cat "$log")"
  assert_contains "forwards --model" "--model gpt-5.5" "$argv"
  assert_contains "forwards --effort" "--effort high" "$argv"
}

# --- wait (highest-risk set -e surface; all dispatcher-path) --------------

test_wait_completed() {
  echo "test_wait_completed:"
  setup_tmp_repo
  OUT="$(CODEX_SHIM_STATUS=completed bash "$SD_BIN" codex_wait "$TMP_DIR/repo" j --poll 0 --cap 5)" && RC=0 || RC=$?
  assert_eq "token completed" "completed" "$OUT"
  assert_eq "rc=0" "0" "$RC"
}

test_wait_failed_nonthrowing() {
  echo "test_wait_failed_nonthrowing:"
  setup_tmp_repo
  # The set -e regression guard: a 'failed' job must NOT abort the helper under
  # the dispatcher's set -e — rc=0 with the token echoed.
  OUT="$(CODEX_SHIM_STATUS=failed bash "$SD_BIN" codex_wait "$TMP_DIR/repo" j --poll 0 --cap 5)" && RC=0 || RC=$?
  assert_eq "token failed" "failed" "$OUT"
  assert_eq "rc=0 (non-throwing under set -e)" "0" "$RC"
}

test_wait_stalled_cancels() {
  echo "test_wait_stalled_cancels:"
  setup_tmp_repo
  local log="$TMP_DIR/argv.log"; local old="$TMP_DIR/old.log"; : > "$old"; touch -t 202001010000 "$old"
  OUT="$(CODEX_SHIM_LOG="$log" CODEX_SHIM_STATUS=running CODEX_SHIM_LOGFILE="$old" \
        bash "$SD_BIN" codex_wait "$TMP_DIR/repo" j --poll 0 --stall 1 --cap 100)" && RC=0 || RC=$?
  assert_eq "token stalled" "stalled" "$OUT"
  assert_eq "rc=0" "0" "$RC"
  assert_file_contains "$log" "^cancel "
}

test_wait_capped_cancels() {
  echo "test_wait_capped_cancels:"
  setup_tmp_repo
  local log="$TMP_DIR/argv.log"; local fresh="$TMP_DIR/fresh.log"; : > "$fresh"
  OUT="$(CODEX_SHIM_LOG="$log" CODEX_SHIM_STATUS=running CODEX_SHIM_LOGFILE="$fresh" \
        bash "$SD_BIN" codex_wait "$TMP_DIR/repo" j --poll 0 --stall 300 --cap 0)" && RC=0 || RC=$?
  assert_eq "token capped" "capped" "$OUT"
  assert_file_contains "$log" "^cancel "
}

# --- result --------------------------------------------------------------

test_result_complete() {
  echo "test_result_complete:"
  setup_tmp_repo
  OUT="$(bash "$SD_BIN" codex_result "$TMP_DIR/repo" j)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_contains "mode complete extracted" '"mode":"complete"' "$OUT"
}

test_result_gaps_prose_before_fence() {
  echo "test_result_gaps_prose_before_fence:"
  setup_tmp_repo
  local raw='Some reasoning prose first.
```json
{"mode":"gaps-surfaced","gaps":[{"q":"which db?"}]}
```'
  OUT="$(CODEX_SHIM_RESULT_RAWOUTPUT="$raw" bash "$SD_BIN" codex_result "$TMP_DIR/repo" j)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_contains "mode gaps extracted" '"mode":"gaps-surfaced"' "$OUT"
}

test_result_no_fence() {
  echo "test_result_no_fence:"
  setup_tmp_repo
  OUT="$(CODEX_SHIM_RESULT_RAWOUTPUT='just narrating, no json block' bash "$SD_BIN" codex_result "$TMP_DIR/repo" j 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 when no fenced block" "1" "$RC"
}

# --- verify_nocommit -----------------------------------------------------

_commit_initial() { ( cd "$TMP_DIR/repo" && echo a > a && git add a && git commit -q -m init ); }

test_verify_unchanged_clean() {
  echo "test_verify_unchanged_clean:"
  setup_tmp_repo; _commit_initial
  local base; base="$(git -C "$TMP_DIR/repo" rev-parse HEAD)"
  OUT="$(bash "$SD_BIN" codex_verify_nocommit "$TMP_DIR/repo" "$base")" && RC=0 || RC=$?
  assert_eq "rc=0 unchanged" "0" "$RC"
  assert_eq "ok-clean on clean tree" "ok-clean" "$OUT"
}

test_verify_unchanged_dirty() {
  echo "test_verify_unchanged_dirty:"
  setup_tmp_repo; _commit_initial
  local base; base="$(git -C "$TMP_DIR/repo" rev-parse HEAD)"
  echo new > "$TMP_DIR/repo/newfile"
  OUT="$(bash "$SD_BIN" codex_verify_nocommit "$TMP_DIR/repo" "$base")" && RC=0 || RC=$?
  assert_eq "rc=0 unchanged" "0" "$RC"
  assert_eq "ok-dirty when staged/untracked present" "ok-dirty" "$OUT"
}

test_verify_head_moved() {
  echo "test_verify_head_moved:"
  setup_tmp_repo; _commit_initial
  local base; base="$(git -C "$TMP_DIR/repo" rev-parse HEAD)"
  ( cd "$TMP_DIR/repo" && echo b > b && git add b && git commit -q -m sneaky )
  OUT="$(bash "$SD_BIN" codex_verify_nocommit "$TMP_DIR/repo" "$base" 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 on commit violation" "1" "$RC"
  assert_contains "echoes commit-violation" "commit-violation" "$OUT"
}

test_resolve_override
test_resolve_override_missing
test_resolve_glob_newest
test_resolve_absent
test_preflight_ready
test_preflight_unauthed
test_preflight_uninstalled
test_preflight_untrusted_worktree
test_dispatch_jobid_and_flags
test_dispatch_model_effort
test_wait_completed
test_wait_failed_nonthrowing
test_wait_stalled_cancels
test_wait_capped_cancels
test_result_complete
test_result_gaps_prose_before_fence
test_result_no_fence
test_verify_unchanged_clean
test_verify_unchanged_dirty
test_verify_head_moved

sd_test_summary
