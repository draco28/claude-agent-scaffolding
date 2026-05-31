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
  unset GH_SHIM_AUTH_RC GH_SHIM_MERGE_RC GH_SHIM_PR_VIEW_JSON GH_SHIM_ISSUE_LIST_JSON GH_SHIM_ISSUE_URL GH_SHIM_PR_COMMENTS_JSON
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

# 2a. merge_mode normalizes unknown manifest values to "direct"
test_merge_mode_unknown_defaults_direct() {
  echo "test_merge_mode_unknown_defaults_direct:"
  _setup_pr_workspace
  local tmp; tmp="$(mktemp)"
  jq '.during_dev.merge_mode = "banana"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  cd "$TMP_AI_WORKSPACE"
  assert_eq "unknown merge_mode defaults direct" "direct" "$(sd_merge_mode)"
}

# 3. sprint branch name default template
test_sprint_branch_name() {
  echo "test_sprint_branch_name:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  assert_eq "sprint branch default" "sprint-1.1" "$(sd_sprint_branch_name "1.1")"
}

# 4. slice branch name default template
test_slice_branch_name() {
  echo "test_slice_branch_name:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  assert_eq "slice branch default" "slice/VS-1.1.1" "$(sd_slice_branch_name "VS-1.1.1")"
}

test_merge_mode_default
test_merge_mode_pr
test_merge_mode_unknown_defaults_direct
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
  assert_eq "no reviews" "0" "$(echo "$json" | jq -r '.reviews | length')"
  assert_file_contains "$GH_SHIM_LOG" "pr view 123 --json mergeStateStatus,statusCheckRollup,reviews,latestReviews,comments,reviewDecision,commits"
  if grep -q 'reviewThreads' "$GH_SHIM_LOG"; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') gh pr view requested unsupported reviewThreads field"
  else
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') gh pr view omits unsupported reviewThreads field"
  fi
}

# 15. pr_state surfaces review-comment state verbatim through supported gh fields
test_pr_state_with_comment() {
  echo "test_pr_state_with_comment:"
  _setup_pr_workspace
  export GH_SHIM_PR_VIEW_JSON="$HERE/fixtures/pr-view-with-review-comment.json"
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_pr_state 123 2>/dev/null)"
  assert_contains "review body present" "Possible off-by-one" "$(echo "$json" | jq -r '.reviews[0].body')"
}

test_pr_state_clean
test_pr_state_with_comment

# 16. pr_merge invokes gh pr merge with a non-interactive default strategy
test_pr_merge() {
  echo "test_pr_merge:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_pr_merge 123 2>/dev/null; local rc=$?; :
  assert_eq "merge rc=0" "0" "$rc"
  assert_file_contains "$GH_SHIM_LOG" "pr merge 123 --merge"
}

# 17. pr_merge --auto keeps the default strategy and passes the flag through
test_pr_merge_auto() {
  echo "test_pr_merge_auto:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_pr_merge 123 --auto 2>/dev/null
  assert_file_contains "$GH_SHIM_LOG" "pr merge 123 --merge --auto"
}

# 17a. pr_merge preserves an explicit strategy
test_pr_merge_explicit_strategy() {
  echo "test_pr_merge_explicit_strategy:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_pr_merge 123 --squash --auto 2>/dev/null
  assert_file_contains "$GH_SHIM_LOG" "pr merge 123 --squash --auto"
}

# 18. dispatcher exposes the new functions
test_dispatcher_lists_pr_fns() {
  echo "test_dispatcher_lists_pr_fns:"
  local listed; listed="$("$HERE/../bin/sd" --list)"
  assert_contains "lists branch_create_from" "branch_create_from" "$listed"
  assert_contains "lists pr_open" "pr_open" "$listed"
  assert_contains "lists pr_state" "pr_state" "$listed"
  assert_contains "lists merge_mode" "merge_mode" "$listed"
  assert_contains "lists sprint_branch_name" "sprint_branch_name" "$listed"
  assert_contains "lists slice_branch_name" "slice_branch_name" "$listed"
  assert_contains "lists branch_sync" "branch_sync" "$listed"
  assert_contains "lists pr_review_comments" "pr_review_comments" "$listed"
}

test_pr_merge
test_pr_merge_auto
test_pr_merge_explicit_strategy
test_dispatcher_lists_pr_fns

# 19. issue_create echoes the issue url and calls gh with the right args
test_issue_create() {
  echo "test_issue_create:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  local body; body="$(mktemp)"; echo "deferred: tune backoff" > "$body"
  local out; out="$(sd_issue_create "Tune retry backoff" "$body" --label tech-debt 2>/dev/null)"
  assert_contains "echoes issue url" "issues/7" "$out"
  assert_file_contains "$GH_SHIM_LOG" "issue create --title Tune retry backoff --body-file"
  assert_file_contains "$GH_SHIM_LOG" "--label tech-debt"
}

test_issue_create

# 20. issue_list passes gh's JSON through (for agent recall/de-dup)
test_issue_list() {
  echo "test_issue_list:"
  _setup_pr_workspace
  export GH_SHIM_ISSUE_LIST_JSON="$HERE/fixtures/issue-list.json"
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_issue_list 2>/dev/null)"
  assert_eq "first issue number" "7" "$(echo "$json" | jq -r '.[0].number')"
  assert_eq "first issue label" "tech-debt" "$(echo "$json" | jq -r '.[0].labels[0].name')"
}

# 21. issue_list returns empty array when no issues
test_issue_list_empty() {
  echo "test_issue_list_empty:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_issue_list 2>/dev/null)"
  assert_eq "empty list" "0" "$(echo "$json" | jq -r 'length')"
}

test_issue_list
test_issue_list_empty

# 22. issue_list defaults to a high --limit (gh's own default of 30 hides older issues)
test_issue_list_default_limit() {
  echo "test_issue_list_default_limit:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_issue_list >/dev/null 2>&1
  assert_file_contains "$GH_SHIM_LOG" "issue list --state open --json number,title,body,labels --limit 200"
}

# 23. a caller-supplied --limit overrides the default (no double --limit)
test_issue_list_explicit_limit() {
  echo "test_issue_list_explicit_limit:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_issue_list --limit 5 >/dev/null 2>&1
  assert_file_contains "$GH_SHIM_LOG" "--limit 5"
  if grep -q -- "--limit 200" "$GH_SHIM_LOG"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') default --limit 200 should not be added when caller passes --limit"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') caller --limit overrides the default"
  fi
}

# 24. pr_review_comments fetches inline review comments via gh api (not gh pr view)
test_pr_review_comments() {
  echo "test_pr_review_comments:"
  _setup_pr_workspace
  export GH_SHIM_PR_COMMENTS_JSON="$HERE/fixtures/pr-review-comments.json"
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_pr_review_comments 7 2>/dev/null)"
  assert_eq "inline comment path" "scaffold-dev/lib/pr.sh" "$(echo "$json" | jq -r '.[0].path')"
  assert_contains "inline comment body" "unresolved inline finding" "$(echo "$json" | jq -r '.[0].body')"
  assert_file_contains "$GH_SHIM_LOG" "api"
  assert_file_contains "$GH_SHIM_LOG" "pulls/7/comments"
}

# 25. branch_sync fast-forwards a stale local integration branch to origin
test_branch_sync() {
  echo "test_branch_sync:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  # Create + push an integration branch, then advance origin behind the local ref's back.
  sd_branch_create_from "main" "sprint-9.9" 2>/dev/null
  sd_branch_push "sprint-9.9" 2>/dev/null
  # Simulate a child PR merging on the remote: add a commit to origin's sprint-9.9
  # via a second clone, so the local sprint-9.9 is now stale (behind origin).
  local clone="$TMP_DIR/clone"
  git clone -q "$BARE_ORIGIN" "$clone"
  git -C "$clone" config user.email t@e.com; git -C "$clone" config user.name T
  git -C "$clone" checkout -q sprint-9.9
  echo "merged-on-remote" > "$clone/remote-only.txt"
  git -C "$clone" add remote-only.txt; git -C "$clone" commit -q -m "merged slice on remote"
  git -C "$clone" push -q origin sprint-9.9
  # Local sprint-9.9 does NOT yet have remote-only.txt.
  set +e; git -C "$TMP_CANONICAL" rev-parse --verify --quiet "sprint-9.9:remote-only.txt" >/dev/null 2>&1; local before=$?; :
  assert_ne "local stale before sync" "0" "$before"
  sd_branch_sync "sprint-9.9" 2>/dev/null
  set +e; git -C "$TMP_CANONICAL" rev-parse --verify --quiet "sprint-9.9:remote-only.txt" >/dev/null 2>&1; local after=$?; :
  assert_eq "local fast-forwarded after sync" "0" "$after"
}

test_issue_list_default_limit
test_issue_list_explicit_limit
test_pr_review_comments
test_branch_sync

sd_test_summary
