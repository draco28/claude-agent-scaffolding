#!/usr/bin/env bash
# tests/test-merge.sh — 14 tests for lib/merge.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/worktree.sh"
source "$HERE/../lib/merge.sh"

# Helper: stage and commit a file in the worktree.
_make_commit() {
  local wt="$1" file="$2" content="$3"
  echo "$content" > "$wt/$file"
  git -C "$wt" add "$file"
  git -C "$wt" commit -q -m "add $file"
}

# 1. clean merge succeeds
test_clean_merge() {
  echo "test_clean_merge:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "feat" 2>/dev/null)"
  _make_commit "$wt" "feat.txt" "hello"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  set +e
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  local rc=$?
  :
  assert_eq "merge clean rc=0" "0" "$rc"
}

# 2. clean merge produces a merge commit on main
test_merge_commit_on_main() {
  echo "test_merge_commit_on_main:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "feat" 2>/dev/null)"
  _make_commit "$wt" "feat.txt" "hello"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  local msg
  msg="$(git -C "$TMP_CANONICAL" log -1 --pretty=%B main)"
  assert_contains "merge commit msg references branch" "$branch" "$msg"
}

# 3. file from branch ends up on main
test_file_lands_on_main() {
  echo "test_file_lands_on_main:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "feat" 2>/dev/null)"
  _make_commit "$wt" "feat.txt" "hello"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  local content
  content="$(git -C "$TMP_CANONICAL" show "main:feat.txt")"
  assert_eq "feat.txt content on main" "hello" "$content"
}

# 4. conflict detection — merge fails on conflict
test_conflict_detected() {
  echo "test_conflict_detected:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  # Add a conflicting line on main first.
  echo "main version" > "$TMP_CANONICAL/conflict.txt"
  git -C "$TMP_CANONICAL" add conflict.txt
  git -C "$TMP_CANONICAL" commit -q -m "main: conflict.txt"
  local wt
  wt="$(sd_worktree_add "2.02" "VS-2.1" "fix" 2>/dev/null)"
  # Branch from main — but rewrite conflict.txt going backwards.
  echo "branch version" > "$wt/conflict.txt"
  git -C "$wt" add conflict.txt
  git -C "$wt" commit -q --amend --no-edit
  # Force a divergent change on main after branch was created
  echo "main side-update" > "$TMP_CANONICAL/conflict.txt"
  git -C "$TMP_CANONICAL" add conflict.txt
  git -C "$TMP_CANONICAL" commit -q -m "diverge main"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  set +e
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  local rc=$?
  :
  assert_ne "conflict merge rc!=0" "0" "$rc"
  # Cleanup conflict state
  sd_merge_abort 2>/dev/null || true
}

# 5. sd_merge_abort clears the conflict state
test_merge_abort() {
  echo "test_merge_abort:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  echo "main" > "$TMP_CANONICAL/c.txt"
  git -C "$TMP_CANONICAL" add c.txt
  git -C "$TMP_CANONICAL" commit -q -m "main c"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "x" 2>/dev/null)"
  echo "branch" > "$wt/c.txt"
  git -C "$wt" add c.txt
  git -C "$wt" commit -q -m "branch c"
  echo "main2" > "$TMP_CANONICAL/c.txt"
  git -C "$TMP_CANONICAL" add c.txt
  git -C "$TMP_CANONICAL" commit -q -m "main c2"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  sd_merge_work_item "$wt" "$branch" 2>/dev/null || true
  set +e
  sd_merge_abort 2>/dev/null
  local rc=$?
  :
  assert_eq "abort rc=0" "0" "$rc"
  # After abort, merge state should be gone
  assert_file_missing "$TMP_CANONICAL/.git/MERGE_HEAD"
}

# 6. merge stages uncommitted changes (commits before merging)
test_merge_commits_pending() {
  echo "test_merge_commits_pending:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "f" 2>/dev/null)"
  # Stage a change but DO NOT commit. Merge should commit + merge.
  echo "data" > "$wt/staged.txt"
  git -C "$wt" add staged.txt
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  local on_main
  on_main="$(git -C "$TMP_CANONICAL" show "main:staged.txt" 2>/dev/null)"
  assert_eq "staged file on main" "data" "$on_main"
}

# 7. idempotency — re-merge of already-merged branch produces no-op (rc=0)
test_remerge_noop() {
  echo "test_remerge_noop:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "f" 2>/dev/null)"
  _make_commit "$wt" "f.txt" "x"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  set +e
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  local rc=$?
  :
  assert_eq "re-merge rc=0 (already up to date)" "0" "$rc"
}

# 8. abort with no merge in progress is benign
test_abort_no_merge() {
  echo "test_abort_no_merge:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e
  sd_merge_abort 2>/dev/null
  local rc=$?
  :
  # Either rc=0 (silent) or rc!=0 (git complains) is acceptable;
  # we just check it doesn't crash the shell.
  if [[ "$rc" == "0" || "$rc" == "128" || "$rc" == "1" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') abort no-merge returns expected rc"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') unexpected rc=$rc"
  fi
}

# 9. merge from worktree with multiple commits
test_merge_multi_commit() {
  echo "test_merge_multi_commit:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "f" 2>/dev/null)"
  _make_commit "$wt" "a.txt" "1"
  _make_commit "$wt" "b.txt" "2"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  local a b
  a="$(git -C "$TMP_CANONICAL" show "main:a.txt")"
  b="$(git -C "$TMP_CANONICAL" show "main:b.txt")"
  assert_eq "a.txt" "1" "$a"
  assert_eq "b.txt" "2" "$b"
}

# 10. merge uses --no-ff (merge commit even for fast-forwardable branch)
test_merge_no_ff() {
  echo "test_merge_no_ff:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "f" 2>/dev/null)"
  _make_commit "$wt" "f.txt" "x"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  # A --no-ff merge produces a commit with 2 parents.
  local parents
  parents="$(git -C "$TMP_CANONICAL" log -1 --pretty=%P main | wc -w | tr -d ' ')"
  assert_eq "merge has 2 parents (no-ff)" "2" "$parents"
}

# 11. merge fails with no manifest
test_merge_no_manifest() {
  echo "test_merge_no_manifest:"
  setup_tmp_repo
  set +e
  sd_merge_work_item "/nope" "br" 2>/dev/null
  local rc=$?
  :
  assert_ne "no manifest rc!=0" "0" "$rc"
}

# 12. merge fails on bogus branch name
test_merge_bogus_branch() {
  echo "test_merge_bogus_branch:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "f" 2>/dev/null)"
  set +e
  sd_merge_work_item "$wt" "no-such-branch" 2>/dev/null
  local rc=$?
  :
  assert_ne "bogus branch rc!=0" "0" "$rc"
}

# 13. merge halts and logs error message on conflict
test_merge_conflict_logs() {
  echo "test_merge_conflict_logs:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  echo "a" > "$TMP_CANONICAL/c.txt"
  git -C "$TMP_CANONICAL" add c.txt
  git -C "$TMP_CANONICAL" commit -q -m "main c"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "f" 2>/dev/null)"
  echo "b" > "$wt/c.txt"
  git -C "$wt" add c.txt
  git -C "$wt" commit -q -m "branch c"
  echo "c" > "$TMP_CANONICAL/c.txt"
  git -C "$TMP_CANONICAL" add c.txt
  git -C "$TMP_CANONICAL" commit -q -m "diverge"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  local out
  out="$(sd_merge_work_item "$wt" "$branch" 2>&1 >/dev/null)"
  assert_contains "logs conflict" "conflict" "$out"
  sd_merge_abort 2>/dev/null || true
}

# 14. merge with empty branch (no new commits) is a no-op fast path
test_merge_empty_branch() {
  echo "test_merge_empty_branch:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "empty" 2>/dev/null)"
  local branch
  branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
  set +e
  sd_merge_work_item "$wt" "$branch" 2>/dev/null
  local rc=$?
  :
  # Empty branch = already-up-to-date: rc=0 is expected.
  assert_eq "empty branch merge rc=0" "0" "$rc"
}

test_clean_merge
test_merge_commit_on_main
test_file_lands_on_main
test_conflict_detected
test_merge_abort
test_merge_commits_pending
test_remerge_noop
test_abort_no_merge
test_merge_multi_commit
test_merge_no_ff
test_merge_no_manifest
test_merge_bogus_branch
test_merge_conflict_logs
test_merge_empty_branch

sd_test_summary
