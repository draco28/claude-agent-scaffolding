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

sd_test_summary
