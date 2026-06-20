#!/usr/bin/env bash
# tests/test-skeleton.sh — unit tests for lib/skeleton.sh
# Covers (per SPEC §8.1/§8.2/§8.3, ~13 tests):
#   P. Preflight  (7) — name validation + writable parent + target absence + pair-with mode
#   R. Root pair  (1) — wi_skeleton_create_root_pair
#   A. AI-only    (1) — wi_skeleton_create_root_ai_only
#   S. Seed       (4) — subdirs + .gitkeep + .gitignore content + idempotency

source "$(dirname "$0")/_helpers.sh"
source "$WI_LIB_DIR/_helpers.sh"
source "$WI_LIB_DIR/skeleton.sh"

# Shared sandbox — direct mktemp (avoids $() trap-loss).
_WI_TMP="$(mktemp -d "${TMPDIR:-/tmp}/wi-skeleton-test.XXXXXX")"
# Cleanup: restore any chmod -w dirs before removing, in case a test left one behind.
_wi_skeleton_cleanup() {
  # Walk and re-grant write on every dir to allow rm -rf to clean up.
  if [[ -d "$_WI_TMP" ]]; then
    chmod -R u+w "$_WI_TMP" 2>/dev/null || true
    rm -rf "$_WI_TMP"
  fi
}
trap _wi_skeleton_cleanup EXIT

# ---------------------------------------------------------------------------
# P. Preflight (7 tests)
# ---------------------------------------------------------------------------

test_P1_valid_name_writable_parent_no_existing() {
  local parent="$_WI_TMP/p1"
  mkdir -p "$parent"
  if ! wi_skeleton_preflight "$parent" "foo" 2>/dev/null; then
    echo "    expected success on valid input"
    return 1
  fi
}

test_P2_invalid_name_uppercase_symbols() {
  local parent="$_WI_TMP/p2"
  mkdir -p "$parent"
  local err rc
  err="$(wi_skeleton_preflight "$parent" "Foo!" 2>&1 >/dev/null)"
  rc=$?
  [[ $rc -ne 0 ]] || { echo "    expected non-zero exit for invalid name"; return 1; }
  assert_contains "invalid project name" "$err" || return 1
}

test_P3_invalid_name_with_space() {
  local parent="$_WI_TMP/p3"
  mkdir -p "$parent"
  if wi_skeleton_preflight "$parent" "foo bar" 2>/dev/null; then
    echo "    expected non-zero exit for name with space"
    return 1
  fi
}

test_P4_parent_not_writable() {
  local parent="$_WI_TMP/p4"
  mkdir -p "$parent"
  chmod -w "$parent"
  local err rc
  err="$(wi_skeleton_preflight "$parent" "foo" 2>&1 >/dev/null)"
  rc=$?
  chmod +w "$parent"  # restore so cleanup works
  [[ $rc -ne 0 ]] || { echo "    expected non-zero exit on unwritable parent"; return 1; }
  assert_contains "not writable" "$err" || return 1
}

test_P5_targets_already_exist_fresh_mode() {
  local parent="$_WI_TMP/p5"
  mkdir -p "$parent/foo-ai"
  if wi_skeleton_preflight "$parent" "foo" 2>/dev/null; then
    echo "    expected non-zero exit when AI target already exists"
    return 1
  fi
}

test_P6_pair_with_existing_git_repo_ok() {
  local parent="$_WI_TMP/p6"
  local canonical="$parent/foo"
  mkdir -p "$canonical"
  git -C "$canonical" init -q
  if ! wi_skeleton_preflight "$parent" "foo" --pair-with "$canonical" 2>/dev/null; then
    echo "    expected success on pair-with against existing git repo"
    return 1
  fi
}

test_P7_pair_with_missing_canonical() {
  local parent="$_WI_TMP/p7"
  mkdir -p "$parent"
  if wi_skeleton_preflight "$parent" "foo" --pair-with "$parent/nope" 2>/dev/null; then
    echo "    expected non-zero exit when --pair-with target missing"
    return 1
  fi
}

# #84: wi_git_is_linked_worktree must flag ONLY genuine linked worktrees — a standalone
# repo whose .git is a FILE (--separate-git-dir, or a submodule) keeps its own hooks dir
# and must NOT be over-matched (CodeRabbit). Discriminates via --git-dir vs --git-common-dir.
test_W1_is_linked_worktree_discriminates() {
  local root="$_WI_TMP/w1"; mkdir -p "$root"
  # main repo + a linked worktree
  git -C "$root" init -q main
  git -C "$root/main" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$root/main" worktree add -q "$root/wt" 2>/dev/null || { echo "    worktree add failed"; return 1; }
  # a standalone --separate-git-dir repo (its .git is a FILE, but it's not a worktree)
  mkdir -p "$root/sep"
  git init -q --separate-git-dir="$root/sep-gitdir" "$root/sep" 2>/dev/null
  # a plain non-repo dir
  mkdir -p "$root/plain"

  wi_git_is_linked_worktree "$root/wt"   || { echo "    linked worktree not detected"; return 1; }
  if wi_git_is_linked_worktree "$root/main"; then echo "    main worktree mis-flagged"; return 1; fi
  if wi_git_is_linked_worktree "$root/sep";  then echo "    separate-git-dir repo mis-flagged (over-match)"; return 1; fi
  if wi_git_is_linked_worktree "$root/plain"; then echo "    non-repo mis-flagged"; return 1; fi
  if wi_git_is_linked_worktree ""; then echo "    empty arg mis-flagged"; return 1; fi
}

# #71: a linked git worktree passes the bare git-repo check but has no own
# .git/hooks dir, so the trace-filter hook would silently fail — reject it.
test_P8_pair_with_linked_worktree_rejected() {
  local parent="$_WI_TMP/p8"
  local main="$parent/foo"
  mkdir -p "$main"
  git -C "$main" init -q
  git -C "$main" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  local wt="$parent/foo-wt"
  git -C "$main" worktree add -q "$wt" 2>/dev/null || { echo "    could not create test worktree"; return 1; }
  if wi_skeleton_preflight "$parent" "bar" --pair-with "$wt" 2>/dev/null; then
    echo "    expected non-zero exit when --pair-with is a linked worktree"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# R. Root pair (1 test)
# ---------------------------------------------------------------------------

test_R1_create_root_pair_creates_both_and_logs() {
  local parent="$_WI_TMP/r1"
  mkdir -p "$parent"
  wi_skeleton_create_root_pair "$parent" "foo" >/dev/null 2>&1 || {
    echo "    create_root_pair failed"
    return 1
  }
  assert_dir_exists "$parent/foo-ai" || return 1
  assert_dir_exists "$parent/foo"    || return 1
  local log="$parent/foo-ai/.workspace/init-log"
  assert_file_exists "$log" || return 1
  # Both roots should appear in log
  grep -qE "^MKDIR	${parent}/foo-ai\$"  "$log" || { echo "    ai_root not in log"; return 1; }
  grep -qE "^MKDIR	${parent}/foo\$"     "$log" || { echo "    canonical not in log"; return 1; }
}

# ---------------------------------------------------------------------------
# A. AI-only (1 test)
# ---------------------------------------------------------------------------

test_A1_create_root_ai_only_creates_only_ai() {
  local parent="$_WI_TMP/a1"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1 || {
    echo "    create_root_ai_only failed"
    return 1
  }
  assert_dir_exists "$parent/foo-ai" || return 1
  if [[ -d "$parent/foo" ]]; then
    echo "    canonical dir unexpectedly created"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# S. Seed subdirs (4 tests)
# ---------------------------------------------------------------------------

test_S1_seed_subdirs_creates_all_with_gitkeep_and_gitignore() {
  local parent="$_WI_TMP/s1"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1
  local ai="$parent/foo-ai"
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1 || {
    echo "    seed_subdirs failed"
    return 1
  }
  local subdirs=(".workspace" ".claude" "docs" "docs/specs" ".superpowers" ".archive")
  local sd
  for sd in "${subdirs[@]}"; do
    assert_dir_exists "$ai/$sd"          || return 1
    assert_file_exists "$ai/$sd/.gitkeep" || return 1
  done
  assert_file_exists "$ai/.gitignore" || return 1
  # Log should contain WRITE_FILE for .gitignore
  local log="$ai/.workspace/init-log"
  grep -qE "^WRITE_FILE	${ai}/\.gitignore\$" "$log" || {
    echo "    .gitignore not logged"
    return 1
  }
}

test_S2_gitignore_content_matches_spec() {
  local parent="$_WI_TMP/s2"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1
  local ai="$parent/foo-ai"
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1
  local body; body="$(cat "$ai/.gitignore")"
  assert_contains ".workspace/handoffs/"              "$body" || return 1
  assert_contains ".claude/.onboarding-state.json"    "$body" || return 1
  assert_contains ".DS_Store"                          "$body" || return 1
  assert_contains "*.swp"                              "$body" || return 1
}

test_S3_seed_subdirs_idempotent_no_double_log() {
  local parent="$_WI_TMP/s3"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1
  local ai="$parent/foo-ai"
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1
  local log="$ai/.workspace/init-log"
  local lines_first; lines_first="$(wc -l < "$log" | tr -d ' ')"
  # Second invocation should be a no-op (no duplicate log entries)
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1 || {
    echo "    second seed_subdirs invocation failed"
    return 1
  }
  local lines_second; lines_second="$(wc -l < "$log" | tr -d ' ')"
  assert_eq "$lines_first" "$lines_second" || {
    echo "    log grew on idempotent re-invocation: $lines_first -> $lines_second"
    return 1
  }
  # And no path appears twice in the log
  local dups; dups="$(sort "$log" | uniq -d)"
  if [[ -n "$dups" ]]; then
    echo "    duplicate log entries found:"
    echo "$dups"
    return 1
  fi
}

test_S4_seed_subdirs_logs_each_gitkeep() {
  local parent="$_WI_TMP/s4"
  mkdir -p "$parent"
  wi_skeleton_create_root_ai_only "$parent" "foo" >/dev/null 2>&1
  local ai="$parent/foo-ai"
  wi_skeleton_seed_subdirs "$ai" >/dev/null 2>&1
  local log="$ai/.workspace/init-log"
  local subdirs=(".workspace" ".claude" "docs" "docs/specs" ".superpowers" ".archive")
  local sd
  for sd in "${subdirs[@]}"; do
    grep -qE "^WRITE_FILE	${ai}/${sd}/.gitkeep\$" "$log" || {
      echo "    .gitkeep for $sd not logged"
      return 1
    }
  done
}

# ---------------------------------------------------------------------------
# Run all
# ---------------------------------------------------------------------------

wi_test_run test_P1_valid_name_writable_parent_no_existing
wi_test_run test_P2_invalid_name_uppercase_symbols
wi_test_run test_P3_invalid_name_with_space
wi_test_run test_P4_parent_not_writable
wi_test_run test_P5_targets_already_exist_fresh_mode
wi_test_run test_P6_pair_with_existing_git_repo_ok
wi_test_run test_P7_pair_with_missing_canonical
wi_test_run test_W1_is_linked_worktree_discriminates
wi_test_run test_P8_pair_with_linked_worktree_rejected

wi_test_run test_R1_create_root_pair_creates_both_and_logs

wi_test_run test_A1_create_root_ai_only_creates_only_ai

wi_test_run test_S1_seed_subdirs_creates_all_with_gitkeep_and_gitignore
wi_test_run test_S2_gitignore_content_matches_spec
wi_test_run test_S3_seed_subdirs_idempotent_no_double_log
wi_test_run test_S4_seed_subdirs_logs_each_gitkeep

wi_test_summary
