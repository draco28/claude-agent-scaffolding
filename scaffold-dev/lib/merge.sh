#!/usr/bin/env bash
# scaffold-dev/lib/merge.sh
# Per-work-item branch merge into canonical's default branch (typically main).
# Commits any staged changes in the worktree (orchestrator-driven policy);
# then merges via --no-ff. Halts on conflict; sd_merge_abort aborts the
# in-progress merge state on canonical.

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi
if ! declare -F sd_manifest_get >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/manifest.sh"
fi

# sd_merge_work_item <wt-path> <branch>
# Commits any staged changes in the worktree, then merges <branch> into the
# canonical default_branch via --no-ff. Returns non-zero on conflict.
sd_merge_work_item() {
  local wt="$1" branch="$2"
  local canonical default_branch
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_merge_work_item: no canonical.root"; return 1; }
  default_branch="$(sd_manifest_get '.canonical.default_branch')" || default_branch="main"

  if [[ ! -d "$wt" ]]; then
    sd_log_error "sd_merge_work_item: worktree path missing: $wt"
    return 1
  fi

  # Verify the branch ref exists in canonical's object store.
  if ! git -C "$canonical" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null; then
    sd_log_error "sd_merge_work_item: branch not found: $branch"
    return 1
  fi

  # If staged changes exist in the worktree, commit them.
  if ! git -C "$wt" diff --cached --quiet 2>/dev/null; then
    if ! git -C "$wt" commit -q -m "Implement ${branch}"; then
      sd_log_error "sd_merge_work_item: failed to commit staged changes in $wt"
      return 1
    fi
  fi

  # Ensure canonical is on default_branch before merging (worktrees use the
  # branch on their own checkout; canonical itself stays on default_branch).
  local cur_branch
  cur_branch="$(git -C "$canonical" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ "$cur_branch" != "$default_branch" ]]; then
    if ! git -C "$canonical" checkout -q "$default_branch" 2>/dev/null; then
      sd_log_error "sd_merge_work_item: canonical not on $default_branch (got $cur_branch); checkout failed"
      return 1
    fi
  fi

  # Merge with --no-ff so the merge boundary is recorded.
  if ! git -C "$canonical" merge --no-ff -m "Merge ${branch}" "$branch" >/dev/null 2>&1; then
    sd_log_error "sd_merge_work_item: merge conflict on $branch; halt and resolve manually"
    return 1
  fi
  return 0
}

# sd_merge_abort — abort an in-progress merge on canonical.
sd_merge_abort() {
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')" || return 1
  git -C "$canonical" merge --abort 2>/dev/null
}
