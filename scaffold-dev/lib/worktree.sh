#!/usr/bin/env bash
# scaffold-dev/lib/worktree.sh
# Per-work-item worktree lifecycle against the canonical repo. Worktree path
# convention: <canonical.root>/.worktrees/work-<NN>-<kebab>. Branch name
# follows the manifest's during_dev.branch_naming template
#   "slice/sprint-{N}-work-{NN}-{kebab-name}"
# where {N} is the slice id with the leading "VS-" stripped.

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

# _sd_worktree_branch_name <slice-id> <work-id> <kebab>
# Substitute {N}, {NN}, {kebab-name} in the manifest's branch template.
_sd_worktree_branch_name() {
  local slice_id="$1" work_id="$2" kebab="$3"
  local tpl
  tpl="$(sd_manifest_get '.during_dev.branch_naming')" || tpl="slice/sprint-{N}-work-{NN}-{kebab-name}"
  local n="${slice_id#VS-}"
  local branch="$tpl"
  branch="${branch//\{N\}/$n}"
  branch="${branch//\{NN\}/$work_id}"
  branch="${branch//\{kebab-name\}/$kebab}"
  echo "$branch"
}

# sd_worktree_add <work-id> <slice-id> <kebab>
# Creates a worktree under <canonical.root>/.worktrees and a fresh branch.
# Echoes the absolute worktree path on stdout. Branches from canonical's
# default_branch (typically main).
sd_worktree_add() {
  local work_id="$1" slice_id="$2" kebab="$3"
  local canonical default_branch branch wt_path
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "no canonical.root"; return 1; }
  default_branch="$(sd_manifest_get '.canonical.default_branch')" || default_branch="main"
  branch="$(_sd_worktree_branch_name "$slice_id" "$work_id" "$kebab")"
  wt_path="${canonical}/.worktrees/work-${work_id}-${kebab}"

  mkdir -p "${canonical}/.worktrees" || return 1

  if ! git -C "$canonical" worktree add -b "$branch" "$wt_path" "$default_branch" >/dev/null 2>&1; then
    sd_log_error "sd_worktree_add: git worktree add failed for $wt_path (branch=$branch)"
    return 1
  fi
  echo "$wt_path"
  return 0
}

# sd_worktree_remove <wt-path>
# Removes the worktree and deletes its branch. Returns 1 on any failure.
sd_worktree_remove() {
  local wt_path="$1"
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "no canonical.root"; return 1; }
  if [[ ! -d "$wt_path" ]]; then
    sd_log_error "sd_worktree_remove: worktree path not found: $wt_path"
    return 1
  fi
  local branch
  branch="$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if ! git -C "$canonical" worktree remove "$wt_path" >/dev/null 2>&1; then
    # Try --force as second pass — but only if directory still exists.
    if ! git -C "$canonical" worktree remove --force "$wt_path" >/dev/null 2>&1; then
      sd_log_error "sd_worktree_remove: failed to remove $wt_path"
      return 1
    fi
  fi
  if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
    git -C "$canonical" branch -D "$branch" >/dev/null 2>&1 || true
  fi
  return 0
}

# sd_worktree_list — echo canonical's worktree list.
sd_worktree_list() {
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')" || return 1
  git -C "$canonical" worktree list
}
