#!/usr/bin/env bash
# scaffold-dev/lib/worktree.sh
# Per-work-item worktree lifecycle against the canonical repo. Worktree path
# convention: <canonical.root>/.worktrees/sprint-<sprint_id>/work-<NN>-<kebab>.
# Branch name
# follows the manifest's during_dev.branch_naming template
#   "slice/sprint-{N}-work-{NN}-{kebab-name}"
# where {N} is the SPRINT segment (e.g. "1.1" for slice VS-1.1.1) — field-read
# from the structured roadmap (sprint_id) by the caller and passed in. It is NOT
# the slice id and NOT the bare first field of the id; feeding the first field was
# the #28 slice-ID arity bug (VS-1.1.1 → wrong "sprint-1").

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

# _sd_worktree_branch_name <slice-id> <work-id> <kebab> [sprint-id]
# Substitute {N}, {NN}, {kebab-name} in the manifest's branch template. {N} is the
# sprint segment: the caller field-reads sprint_id and passes it. When omitted, it
# is derived from the slice id by dropping the trailing slice segment
# (VS-1.1.1 → 1.1) — which equals sprint_id for the 3-part contract — NEVER the
# bare first field.
_sd_worktree_branch_name() {
  local slice_id="$1" work_id="$2" kebab="$3" sprint_id="${4:-}"
  local tpl
  tpl="$(sd_manifest_get '.during_dev.branch_naming')" || tpl="slice/sprint-{N}-work-{NN}-{kebab-name}"
  local n="$sprint_id"
  if [[ -z "$n" ]]; then
    n="${slice_id#VS-}"   # strip the VS- prefix
    n="${n%.*}"           # drop the trailing .<slice> segment → sprint_id
  fi
  local branch="$tpl"
  branch="${branch//\{N\}/$n}"
  branch="${branch//\{NN\}/$work_id}"
  branch="${branch//\{kebab-name\}/$kebab}"
  echo "$branch"
}

# sd_worktree_add <work-id> <slice-id> <kebab> [sprint-id] [base-branch]
# Creates a worktree under <canonical.root>/.worktrees and a fresh branch.
# Echoes the absolute worktree path on stdout. Branches from <base-branch> when
# given (the slice branch under pr_hierarchical), else canonical's default_branch.
sd_worktree_add() {
  local work_id="$1" slice_id="$2" kebab="$3" sprint_id="${4:-}" base_branch="${5:-}"
  local canonical default_branch raw_worktrees_dir worktrees_dir branch wt_path base_ref
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "no canonical.root"; return 1; }
  default_branch="$(sd_manifest_get '.canonical.default_branch')" || default_branch="main"
  if [[ -n "$base_branch" ]]; then base_ref="$base_branch"; else base_ref="$default_branch"; fi
  if raw_worktrees_dir="$(sd_manifest_get '.during_dev.worktrees_dir')"; then
    worktrees_dir="$(sd_manifest_resolve "$(sd_manifest_get '.ai_workspace.root')" "$raw_worktrees_dir")" || return 1
  else
    worktrees_dir="${canonical}/.worktrees"
  fi
  branch="$(_sd_worktree_branch_name "$slice_id" "$work_id" "$kebab" "$sprint_id")"
  local n="$sprint_id"
  if [[ -z "$n" ]]; then
    n="${slice_id#VS-}"
    n="${n%.*}"
  fi
  wt_path="${worktrees_dir}/sprint-${n}/work-${work_id}-${kebab}"

  mkdir -p "${worktrees_dir}/sprint-${n}" || return 1

  if ! git -C "$canonical" worktree add -b "$branch" "$wt_path" "$base_ref" >/dev/null 2>&1; then
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
