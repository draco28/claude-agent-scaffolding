#!/usr/bin/env bash
# tests/test-pr.sh — lib/pr.sh primitives (pr_hierarchical merge mode, #40).
# Uses a local bare repo as origin + a gh PATH-shim (no network).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/worktree.sh"
source "$HERE/../lib/merge.sh"
source "$HERE/../lib/pr.sh"

# Build a dual-repo workspace + bare origin + gh shim on PATH.
_setup_pr_workspace() {
  setup_tmp_workspace "$@"
  BARE_ORIGIN="$TMP_DIR/origin.git"
  git init -q --bare "$BARE_ORIGIN"
  git -C "$TMP_CANONICAL" remote add origin "$BARE_ORIGIN"
  chmod +x "$HERE/fixtures/gh-shim/gh" 2>/dev/null || true
  export PATH="$HERE/fixtures/gh-shim:$PATH"
  export GH_SHIM_LOG="$TMP_DIR/gh-calls.log"
  : > "$GH_SHIM_LOG"
  # Reset shim env to defaults each setup.
  unset GH_SHIM_AUTH_RC GH_SHIM_MERGE_RC GH_SHIM_PR_VIEW_JSON
  export GH_SHIM_PR_URL="https://github.com/test/repo/pull/123"
}

# 0. smoke — shim is reachable and records calls
test_shim_smoke() {
  echo "test_shim_smoke:"
  _setup_pr_workspace
  local out; out="$(gh pr create --head x --base y --title t --body-file /dev/null)"
  assert_contains "shim echoes canned PR url" "pull/123" "$out"
  assert_file_contains "$GH_SHIM_LOG" "pr create"
}

test_shim_smoke

# 1. merge_mode defaults to "direct" when unset
test_merge_mode_default() {
  echo "test_merge_mode_default:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  assert_eq "default merge_mode" "direct" "$(sd_merge_mode)"
}

# 2. merge_mode reads pr_hierarchical from manifest
test_merge_mode_pr() {
  echo "test_merge_mode_pr:"
  _setup_pr_workspace
  # inject merge_mode into the manifest
  local tmp; tmp="$(mktemp)"
  jq '.during_dev.merge_mode = "pr_hierarchical"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  cd "$TMP_AI_WORKSPACE"
  assert_eq "reads pr_hierarchical" "pr_hierarchical" "$(sd_merge_mode)"
}

# 3. sprint branch name default template
test_sprint_branch_name() {
  echo "test_sprint_branch_name:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  assert_eq "sprint branch default" "sprint-1.1" "$(_sd_sprint_branch_name "1.1")"
}

# 4. slice branch name default template
test_slice_branch_name() {
  echo "test_slice_branch_name:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  assert_eq "slice branch default" "slice/VS-1.1.1" "$(_sd_slice_branch_name "VS-1.1.1")"
}

test_merge_mode_default
test_merge_mode_pr
test_sprint_branch_name
test_slice_branch_name

# 5. create branch off base
test_branch_create() {
  echo "test_branch_create:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_branch_create_from "main" "sprint-1.1" 2>/dev/null
  assert_exit_code 0 git -C "$TMP_CANONICAL" rev-parse --verify --quiet "refs/heads/sprint-1.1"
}

# 6. idempotent — second create is a no-op rc 0
test_branch_create_idempotent() {
  echo "test_branch_create_idempotent:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_branch_create_from "main" "sprint-1.1" 2>/dev/null
  set +e; sd_branch_create_from "main" "sprint-1.1" 2>/dev/null; local rc=$?; :
  assert_eq "re-create rc=0" "0" "$rc"
}

# 7. missing base fails
test_branch_create_missing_base() {
  echo "test_branch_create_missing_base:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_branch_create_from "no-such-base" "x" 2>/dev/null; local rc=$?; :
  assert_ne "missing base rc!=0" "0" "$rc"
}

test_branch_create
test_branch_create_idempotent
test_branch_create_missing_base

# 8. push lands the branch on the bare origin
test_branch_push() {
  echo "test_branch_push:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_branch_create_from "main" "sprint-1.1" 2>/dev/null
  sd_branch_push "sprint-1.1" 2>/dev/null
  assert_exit_code 0 git -C "$BARE_ORIGIN" rev-parse --verify --quiet "refs/heads/sprint-1.1"
}

# 9. push fails cleanly with no origin remote
test_branch_push_no_remote() {
  echo "test_branch_push_no_remote:"
  _setup_pr_workspace
  git -C "$TMP_CANONICAL" remote remove origin
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_branch_push "main" 2>/dev/null; local rc=$?; :
  assert_ne "no-remote push rc!=0" "0" "$rc"
}

test_branch_push
test_branch_push_no_remote

# 10. remote_check passes with origin + authed gh shim
test_remote_check_ok() {
  echo "test_remote_check_ok:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_remote_check 2>/dev/null; local rc=$?; :
  assert_eq "remote_check ok rc=0" "0" "$rc"
}

# 11. remote_check fails with no origin
test_remote_check_no_remote() {
  echo "test_remote_check_no_remote:"
  _setup_pr_workspace
  git -C "$TMP_CANONICAL" remote remove origin
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_remote_check 2>/dev/null; local rc=$?; :
  assert_ne "no-remote rc!=0" "0" "$rc"
}

# 12. remote_check fails when gh auth fails
test_remote_check_auth_fail() {
  echo "test_remote_check_auth_fail:"
  _setup_pr_workspace
  export GH_SHIM_AUTH_RC=1
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_remote_check 2>/dev/null; local rc=$?; :
  unset GH_SHIM_AUTH_RC
  assert_ne "auth-fail rc!=0" "0" "$rc"
}

test_remote_check_ok
test_remote_check_no_remote
test_remote_check_auth_fail

# 13. pr_open echoes the PR url and calls gh with the right args
test_pr_open() {
  echo "test_pr_open:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  local body; body="$(mktemp)"; echo "body text" > "$body"
  local out; out="$(sd_pr_open "slice/VS-1.1.1" "sprint-1.1" "VS-1.1.1: title" "$body" 2>/dev/null)"
  assert_contains "echoes PR url" "pull/123" "$out"
  assert_file_contains "$GH_SHIM_LOG" "pr create --head slice/VS-1.1.1 --base sprint-1.1"
}

test_pr_open

# 14. pr_state passes through gh's JSON unchanged (clean state)
test_pr_state_clean() {
  echo "test_pr_state_clean:"
  _setup_pr_workspace
  export GH_SHIM_PR_VIEW_JSON="$HERE/fixtures/pr-view-clean.json"
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_pr_state 123 2>/dev/null)"
  assert_eq "mergeStateStatus passthrough" "CLEAN" "$(echo "$json" | jq -r '.mergeStateStatus')"
  assert_eq "no review comments" "0" "$(echo "$json" | jq -r '.reviewThreads | length')"
}

# 15. pr_state surfaces an unresolved review-comment state verbatim
test_pr_state_with_comment() {
  echo "test_pr_state_with_comment:"
  _setup_pr_workspace
  export GH_SHIM_PR_VIEW_JSON="$HERE/fixtures/pr-view-with-review-comment.json"
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_pr_state 123 2>/dev/null)"
  assert_eq "unresolved thread present" "false" "$(echo "$json" | jq -r '.reviewThreads[0].isResolved')"
}

test_pr_state_clean
test_pr_state_with_comment

sd_test_summary
