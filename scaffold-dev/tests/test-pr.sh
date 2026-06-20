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
  unset GH_SHIM_AUTH_RC GH_SHIM_MERGE_RC GH_SHIM_PR_VIEW_JSON GH_SHIM_ISSUE_LIST_JSON GH_SHIM_ISSUE_URL GH_SHIM_PR_COMMENTS_JSON GH_SHIM_PR_COMMENTS_PAGED_JSON GH_SHIM_API_RC GH_SHIM_API_ERR GH_SHIM_PR_LIST_URL GH_SHIM_LABEL_RC GH_SHIM_LABEL_ERR GH_SHIM_LABEL_OUT GH_SHIM_CWD_LOG
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

# 13a. pr_open resolves a relative body-file before cd'ing into canonical
test_pr_open_relative_body_file() {
  echo "test_pr_open_relative_body_file:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  echo "body text" > pr-body.md
  sd_pr_open "slice/VS-1.1.1" "sprint-1.1" "VS-1.1.1: title" "pr-body.md" >/dev/null 2>&1
  assert_file_contains "$GH_SHIM_LOG" "--body-file $TMP_AI_WORKSPACE/pr-body.md"
}

test_pr_open_relative_body_file

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

# 19a. issue_create resolves a relative body-file before cd'ing into canonical
test_issue_create_relative_body_file() {
  echo "test_issue_create_relative_body_file:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  echo "deferred: tune backoff" > issue-body.md
  sd_issue_create "Tune retry backoff" "issue-body.md" --label tech-debt >/dev/null 2>&1
  assert_file_contains "$GH_SHIM_LOG" "--body-file $TMP_AI_WORKSPACE/issue-body.md"
}

test_issue_create_relative_body_file

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

# --- #48 Stage 2: tech-debt label auto-create + --repo-root marketplace routing ---

# 27. label_ensure creates the label (gh label create) and returns rc 0
test_label_ensure_creates() {
  echo "test_label_ensure_creates:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_label_ensure tech-debt 2>/dev/null; local rc=$?; :
  assert_eq "create rc=0" "0" "$rc"
  assert_file_contains "$GH_SHIM_LOG" "label create tech-debt"
}

# 28. label_ensure is idempotent — an "already exists" rejection is success (rc 0)
test_label_ensure_idempotent() {
  echo "test_label_ensure_idempotent:"
  _setup_pr_workspace
  export GH_SHIM_LABEL_RC=1
  export GH_SHIM_LABEL_ERR='Label "tech-debt" already exists; use --force to update'
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_label_ensure tech-debt 2>/dev/null; local rc=$?; :
  unset GH_SHIM_LABEL_RC GH_SHIM_LABEL_ERR
  assert_eq "already-exists rc=0" "0" "$rc"
}

# 29. label_ensure surfaces a real failure as rc 1 (not swallowed as success)
test_label_ensure_hard_failure() {
  echo "test_label_ensure_hard_failure:"
  _setup_pr_workspace
  export GH_SHIM_LABEL_RC=1
  export GH_SHIM_LABEL_ERR='HTTP 500: server error'
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_label_ensure tech-debt 2>/dev/null; local rc=$?; :
  unset GH_SHIM_LABEL_RC GH_SHIM_LABEL_ERR
  assert_ne "hard-failure rc!=0" "0" "$rc"
}

# 30. label_ensure [repo-root] runs gh from the given repo, not canonical
test_label_ensure_repo_root() {
  echo "test_label_ensure_repo_root:"
  _setup_pr_workspace
  local tooling="$TMP_DIR/tooling"; mkdir -p "$tooling"
  export GH_SHIM_CWD_LOG="$TMP_DIR/gh-cwd.log"; : > "$GH_SHIM_CWD_LOG"
  cd "$TMP_AI_WORKSPACE"
  sd_label_ensure tech-debt "$tooling" >/dev/null 2>&1
  assert_file_contains "$GH_SHIM_CWD_LOG" "$tooling"
}

# 31. issue_create --repo-root routes gh to the given repo (not canonical) and
#     strips --repo-root from the gh passthrough (gh issue create can't grok it)
test_issue_create_repo_root() {
  echo "test_issue_create_repo_root:"
  _setup_pr_workspace
  local tooling="$TMP_DIR/tooling"; mkdir -p "$tooling"
  export GH_SHIM_CWD_LOG="$TMP_DIR/gh-cwd.log"; : > "$GH_SHIM_CWD_LOG"
  cd "$TMP_AI_WORKSPACE"
  local body; body="$(mktemp)"; echo "deferred: tune backoff" > "$body"
  sd_issue_create "Tune retry backoff" "$body" --repo-root "$tooling" --label tech-debt >/dev/null 2>&1
  assert_file_contains "$GH_SHIM_CWD_LOG" "$tooling"
  assert_file_not_contains "$GH_SHIM_LOG" "repo-root"
  assert_file_contains "$GH_SHIM_LOG" "--label tech-debt"
}

# 32. issue_create WITHOUT --repo-root still targets canonical (byte-compat)
test_issue_create_default_canonical() {
  echo "test_issue_create_default_canonical:"
  _setup_pr_workspace
  export GH_SHIM_CWD_LOG="$TMP_DIR/gh-cwd.log"; : > "$GH_SHIM_CWD_LOG"
  cd "$TMP_AI_WORKSPACE"
  local body; body="$(mktemp)"; echo "deferred" > "$body"
  sd_issue_create "T" "$body" --label tech-debt >/dev/null 2>&1
  assert_file_contains "$GH_SHIM_CWD_LOG" "$TMP_CANONICAL"
}

# 33. issue_list --repo-root routes gh to the given repo (not canonical)
test_issue_list_repo_root() {
  echo "test_issue_list_repo_root:"
  _setup_pr_workspace
  local tooling="$TMP_DIR/tooling"; mkdir -p "$tooling"
  export GH_SHIM_CWD_LOG="$TMP_DIR/gh-cwd.log"; : > "$GH_SHIM_CWD_LOG"
  cd "$TMP_AI_WORKSPACE"
  sd_issue_list --repo-root "$tooling" >/dev/null 2>&1
  assert_file_contains "$GH_SHIM_CWD_LOG" "$tooling"
  assert_file_not_contains "$GH_SHIM_LOG" "repo-root"
}

# 34. dispatcher exposes label_ensure
test_dispatcher_lists_label_ensure() {
  echo "test_dispatcher_lists_label_ensure:"
  local listed; listed="$("$HERE/../bin/sd" --list)"
  assert_contains "lists label_ensure" "label_ensure" "$listed"
}

# 35. --repo-root with NO value fails fast (rc 1), never spins the parse loop
#     forever (regression: `shift 2` on a 1-arg tail leaves $1 unchanged).
test_issue_create_repo_root_no_value() {
  echo "test_issue_create_repo_root_no_value:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  local body; body="$(mktemp)"; echo x > "$body"
  set +e; sd_issue_create "t" "$body" --repo-root 2>/dev/null; local rc=$?; :
  assert_eq "no-value --repo-root rc=1" "1" "$rc"
}

# 36. --repo-root= (explicit empty) fails loud, not a silent canonical fallback
test_issue_create_repo_root_empty() {
  echo "test_issue_create_repo_root_empty:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  local body; body="$(mktemp)"; echo x > "$body"
  set +e; sd_issue_create "t" "$body" --repo-root= 2>/dev/null; local rc=$?; :
  assert_eq "empty --repo-root= rc=1" "1" "$rc"
}

# 37. same no-value guard on sd_issue_list (rc 1, no infinite loop)
test_issue_list_repo_root_no_value() {
  echo "test_issue_list_repo_root_no_value:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_issue_list --repo-root 2>/dev/null; local rc=$?; :
  assert_eq "no-value --repo-root rc=1" "1" "$rc"
}

# 24. pr_review_comments fetches inline review comments via gh api (not gh pr view),
#     accepts a PR URL (normalizes to the numeric id), and returns one flat array.
test_pr_review_comments() {
  echo "test_pr_review_comments:"
  _setup_pr_workspace
  export GH_SHIM_PR_COMMENTS_JSON="$HERE/fixtures/pr-review-comments.json"
  cd "$TMP_AI_WORKSPACE"
  # Pass a PR URL (what sd_pr_open echoes) — must normalize to pulls/7/comments.
  local json; json="$(sd_pr_review_comments "https://github.com/test/repo/pull/7" 2>/dev/null)"
  assert_eq "flat top-level array" "1" "$(echo "$json" | jq -r 'if type=="array" then length else "notarray" end')"
  assert_eq "inline comment path" "scaffold-dev/lib/pr.sh" "$(echo "$json" | jq -r '.[0].path')"
  assert_contains "inline comment body" "unresolved inline finding" "$(echo "$json" | jq -r '.[0].body')"
  assert_file_contains "$GH_SHIM_LOG" "api"
  assert_file_contains "$GH_SHIM_LOG" "--slurp"
  assert_file_contains "$GH_SHIM_LOG" "pulls/7/comments"
}

# 25. pr_review_comments propagates gh api failures instead of returning []
test_pr_review_comments_api_failure() {
  echo "test_pr_review_comments_api_failure:"
  _setup_pr_workspace
  export GH_SHIM_API_RC=42
  export GH_SHIM_API_ERR="rate limit"
  cd "$TMP_AI_WORKSPACE"
  set +e; sd_pr_review_comments 7 >/tmp/sd-pr-review-comments.out 2>/dev/null; local rc=$?; :
  unset GH_SHIM_API_RC GH_SHIM_API_ERR
  assert_ne "api failure rc!=0" "0" "$rc"
}

# 26. branch_sync fast-forwards a stale local integration branch to origin
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

# 25a. branch_sync HARD-FAILS (rc 1) when the local branch has diverged from origin
test_branch_sync_diverged() {
  echo "test_branch_sync_diverged:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_branch_create_from "main" "sprint-8.8" 2>/dev/null
  sd_branch_push "sprint-8.8" 2>/dev/null
  # Advance origin/sprint-8.8 with a remote-only commit (via a clone).
  local clone="$TMP_DIR/clone8"
  git clone -q "$BARE_ORIGIN" "$clone"
  git -C "$clone" config user.email t@e.com; git -C "$clone" config user.name T
  git -C "$clone" checkout -q sprint-8.8
  echo remote > "$clone/r.txt"; git -C "$clone" add r.txt; git -C "$clone" commit -q -m "remote commit"
  git -C "$clone" push -q origin sprint-8.8
  # Diverge the LOCAL sprint-8.8 with a different commit (not a fast-forward of origin).
  git -C "$TMP_CANONICAL" checkout -q sprint-8.8
  echo local > "$TMP_CANONICAL/l.txt"; git -C "$TMP_CANONICAL" add l.txt; git -C "$TMP_CANONICAL" commit -q -m "local commit"
  git -C "$TMP_CANONICAL" checkout -q main
  set +e; sd_branch_sync "sprint-8.8" 2>/dev/null; local rc=$?; :
  assert_ne "diverged sync hard-fails" "0" "$rc"
}

# 25b. branch_create_from REUSES origin/<new> when local is absent (fresh clone)
test_branch_create_reuses_origin() {
  echo "test_branch_create_reuses_origin:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  # Put a sprint-only commit on origin/sprint-7.7, then delete the local branch.
  sd_branch_create_from "main" "sprint-7.7" 2>/dev/null
  git -C "$TMP_CANONICAL" checkout -q sprint-7.7
  echo on-sprint > "$TMP_CANONICAL/sprint-only.txt"
  git -C "$TMP_CANONICAL" add sprint-only.txt; git -C "$TMP_CANONICAL" commit -q -m "sprint-only commit"
  sd_branch_push "sprint-7.7" 2>/dev/null
  git -C "$TMP_CANONICAL" checkout -q main
  git -C "$TMP_CANONICAL" branch -D sprint-7.7 >/dev/null 2>&1
  # Recreate: must reuse origin/sprint-7.7 (has sprint-only.txt), NOT cut fresh from main.
  sd_branch_create_from "main" "sprint-7.7" 2>/dev/null
  assert_eq "reused origin sprint history" "on-sprint" "$(git -C "$TMP_CANONICAL" show sprint-7.7:sprint-only.txt 2>/dev/null)"
}

# 13a. pr_open is idempotent — reuse an existing open PR for <head>, no gh pr create
test_pr_open_idempotent() {
  echo "test_pr_open_idempotent:"
  _setup_pr_workspace
  cd "$TMP_AI_WORKSPACE"
  export GH_SHIM_PR_LIST_URL="https://github.com/test/repo/pull/999"
  local body; body="$(mktemp)"; echo body > "$body"
  local out; out="$(sd_pr_open "slice/VS-1.1.1" "sprint-1.1" "T" "$body" 2>/dev/null)"
  assert_eq "reuses existing open PR url" "https://github.com/test/repo/pull/999" "$out"
  if grep -q 'pr create' "$GH_SHIM_LOG"; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') should NOT call gh pr create when an open PR exists"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') idempotent: no gh pr create when an open PR exists"
  fi
}

# 24b. pr_review_comments flattens real --slurp multi-page output into one array
test_pr_review_comments_paginated() {
  echo "test_pr_review_comments_paginated:"
  _setup_pr_workspace
  export GH_SHIM_PR_COMMENTS_PAGED_JSON="$HERE/fixtures/pr-review-comments-paged.json"
  cd "$TMP_AI_WORKSPACE"
  local json; json="$(sd_pr_review_comments 7 2>/dev/null)"
  assert_eq "paginated pages flattened" "2" "$(echo "$json" | jq -r 'length')"
  assert_eq "first page entry" "page-one finding" "$(echo "$json" | jq -r '.[0].body')"
  assert_eq "second page entry" "page-two finding" "$(echo "$json" | jq -r '.[1].body')"
}

test_pr_open_idempotent
test_issue_list_default_limit
test_issue_list_explicit_limit
test_pr_review_comments
test_pr_review_comments_paginated
test_pr_review_comments_api_failure
test_branch_sync
test_branch_sync_diverged
test_branch_create_reuses_origin

# #48 Stage 2
test_label_ensure_creates
test_label_ensure_idempotent
test_label_ensure_hard_failure
test_label_ensure_repo_root
test_issue_create_repo_root
test_issue_create_default_canonical
test_issue_list_repo_root
test_dispatcher_lists_label_ensure
test_issue_create_repo_root_no_value
test_issue_create_repo_root_empty
test_issue_list_repo_root_no_value

sd_test_summary
