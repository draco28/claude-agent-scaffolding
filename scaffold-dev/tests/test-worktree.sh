#!/usr/bin/env bash
# tests/test-worktree.sh — 12 tests for lib/worktree.sh

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/worktree.sh"

# 1. add creates worktree dir under canonical/.worktrees
test_add_creates_worktree() {
  echo "test_add_creates_worktree:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "2.04" "VS-3.2" "auth-flow" 2>/dev/null)"
  assert_file_exists "$wt"
  assert_eq "wt path under canonical/.worktrees" "$TMP_CANONICAL/.worktrees/work-2.04-auth-flow" "$wt"
}

# 2. add prints the worktree path on stdout
test_add_emits_path() {
  echo "test_add_emits_path:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "first-thing" 2>/dev/null)"
  assert_contains "stdout contains .worktrees" ".worktrees/work-1.01-first-thing" "$wt"
}

# 3. add creates a branch following manifest naming template
test_add_branch_name() {
  echo "test_add_branch_name:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_worktree_add "5.10" "VS-2.3" "thing" >/dev/null 2>&1
  local branches
  branches="$(git -C "$TMP_CANONICAL" branch --format='%(refname:short)')"
  # branch_naming = slice/sprint-{N}-work-{NN}-{kebab-name}
  # {N} from slice VS-2.3 → 2.3; {NN} from work-item 5.10; {kebab-name} = thing
  assert_contains "branch matches template" "slice/sprint-2.3-work-5.10-thing" "$branches"
}

# 4. list returns at least one entry after add
test_list_after_add() {
  echo "test_list_after_add:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_worktree_add "1.01" "VS-1.1" "x" >/dev/null 2>&1
  local out
  out="$(sd_worktree_list)"
  assert_contains "list shows the worktree path" ".worktrees/work-1.01-x" "$out"
}

# 5. remove cleans up the worktree directory
test_remove_dir() {
  echo "test_remove_dir:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "x" 2>/dev/null)"
  sd_worktree_remove "$wt" >/dev/null 2>&1
  assert_file_missing "$wt"
}

# 6. remove deletes the branch
test_remove_branch() {
  echo "test_remove_branch:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "2.04" "VS-3.2" "auth" 2>/dev/null)"
  sd_worktree_remove "$wt" >/dev/null 2>&1
  local branches
  branches="$(git -C "$TMP_CANONICAL" branch --format='%(refname:short)' 2>/dev/null)"
  if [[ "$branches" == *"slice/sprint-3.2-work-2.04-auth"* ]]; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') branch still present: $branches"
  else
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') branch removed"
  fi
}

# 7. add fails if branch already exists
test_add_duplicate() {
  echo "test_add_duplicate:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_worktree_add "1.01" "VS-1.1" "dup" >/dev/null 2>&1
  set +e
  sd_worktree_add "1.01" "VS-1.1" "dup" >/dev/null 2>&1
  local rc=$?
  set -e 2>/dev/null || true
  assert_ne "second add fails" "0" "$rc"
}

# 8. list works when no worktrees beyond main
test_list_baseline() {
  echo "test_list_baseline:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local out
  out="$(sd_worktree_list)"
  assert_contains "list contains canonical root" "$TMP_CANONICAL" "$out"
}

# 9. add with kebab containing hyphens preserves them
test_add_kebab_hyphens() {
  echo "test_add_kebab_hyphens:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "3.07" "VS-4.5" "multi-word-name" 2>/dev/null)"
  assert_contains "kebab hyphens preserved" "work-3.07-multi-word-name" "$wt"
}

# 10. worktree branched from main
test_add_branched_from_main() {
  echo "test_add_branched_from_main:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  local wt
  wt="$(sd_worktree_add "1.01" "VS-1.1" "thing" 2>/dev/null)"
  local main_sha wt_sha
  main_sha="$(git -C "$TMP_CANONICAL" rev-parse main)"
  wt_sha="$(git -C "$wt" rev-parse HEAD)"
  assert_eq "wt HEAD == main HEAD at create time" "$main_sha" "$wt_sha"
}

# 11. add creates .worktrees parent dir
test_add_creates_parent() {
  echo "test_add_creates_parent:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  sd_worktree_add "1.01" "VS-1.1" "thing" >/dev/null 2>&1
  assert_file_exists "$TMP_CANONICAL/.worktrees"
}

# 12. remove fails on nonexistent worktree path
test_remove_nonexistent() {
  echo "test_remove_nonexistent:"
  setup_tmp_workspace
  cd "$TMP_AI_WORKSPACE"
  set +e
  sd_worktree_remove "$TMP_CANONICAL/.worktrees/nope" >/dev/null 2>&1
  local rc=$?
  set -e 2>/dev/null || true
  assert_ne "remove nonexistent fails" "0" "$rc"
}

test_add_creates_worktree
test_add_emits_path
test_add_branch_name
test_list_after_add
test_remove_dir
test_remove_branch
test_add_duplicate
test_list_baseline
test_add_kebab_hyphens
test_add_branched_from_main
test_add_creates_parent
test_remove_nonexistent

sd_test_summary
