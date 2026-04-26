#!/usr/bin/env bash
# scaffold/lib/worktree.sh — git worktree fork + listing helpers.
#
# Worktree fork creates a new branch via `git worktree add -b`, copies the
# parent branch's state.json into the new branch's plugin-data slot (with
# current_slice reset), and materializes CLAUDE.md inside the new worktree.
#
# Listing wraps `git worktree list --porcelain` and joins each worktree to
# its state.json for current-slice + phase context.
#
# Sources lib/claude-md.sh (which transitively pulls in state.sh + repo.sh).

SF_WT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./claude-md.sh
source "${SF_WT_LIB_DIR}/claude-md.sh"

# ── Fork ────────────────────────────────────────────────────────────────────

# sf_worktree_fork <new-branch> [target-path]
# Returns 0 on success, non-zero on failure with message on stderr.
# Echoes a status block on stdout for the slash command to surface.
sf_worktree_fork() {
  local new_branch="$1"
  local target_path="$2"

  if [[ -z "$new_branch" ]]; then
    echo "scaffold: branch name required" >&2
    return 1
  fi

  if ! sf_is_managed; then
    echo "scaffold: this branch is not initialized. Run /scaffold-init first." >&2
    return 1
  fi

  local repo_root parent_branch_safe repo_hash data_dir
  repo_root="$(sf_repo_root)"
  parent_branch_safe="$(sf_branch_safe)"
  repo_hash="$(sf_repo_hash)"
  data_dir="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/scaffold}"

  # Default target path: ../<repo>-<branch-slug>
  if [[ -z "$target_path" ]]; then
    local repo_name branch_slug
    repo_name="$(basename "$repo_root")"
    branch_slug="$(sf_slug "$new_branch")"
    target_path="$(dirname "$repo_root")/${repo_name}-${branch_slug}"
  fi

  # Pre-flight: branch must not already exist
  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/${new_branch}" 2>/dev/null; then
    echo "scaffold: branch '${new_branch}' already exists. Pick a different name or check it out manually." >&2
    return 1
  fi

  # Pre-flight: target path must be available
  if [[ -e "$target_path" ]]; then
    echo "scaffold: target path '${target_path}' already exists. Pass a different --path or remove the dir." >&2
    return 1
  fi

  # Create the worktree (forks from current HEAD)
  local git_out
  if ! git_out="$(git -C "$repo_root" worktree add "$target_path" -b "$new_branch" 2>&1)"; then
    echo "scaffold: git worktree add failed:" >&2
    echo "$git_out" >&2
    return 1
  fi

  # Fork branch state. Sanitize new branch name for dir use.
  local new_branch_safe="${new_branch//\//__}"
  local new_state_dir="${data_dir}/projects/${repo_hash}/branches/${new_branch_safe}"
  local parent_state_path="${data_dir}/projects/${repo_hash}/branches/${parent_branch_safe}/state.json"
  mkdir -p "$new_state_dir"

  local now; now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ -r "$parent_state_path" ]]; then
    # Inherit parent's accounting (adr_counter, stack, llm_project, etc.)
    # but reset slice context: current_slice → null, slices → {} (the new
    # branch starts fresh; parent's completed slices don't apply here).
    jq --arg now "$now" '
      .current_slice = null
      | .slices = {}
      | .last_audit_at = null
      | .audit_results_path = null
      | .updated_at = $now
    ' "$parent_state_path" > "${new_state_dir}/state.json"
  else
    sf_default_state > "${new_state_dir}/state.json"
  fi

  # Materialize CLAUDE.md inside the new worktree.
  # Run sf_generate_claude_md from inside the new worktree so all path helpers
  # (sf_repo_root, sf_repo_hash, sf_branch) resolve to the new worktree.
  ( cd "$target_path" && sf_generate_claude_md ) >/dev/null 2>&1 || true

  # Status output
  cat <<EOF
Created worktree:
  path:        ${target_path}
  branch:      ${new_branch}
  parent:      $(sf_branch)
  state forked from: branches/${parent_branch_safe}/
  state file:  ${new_state_dir}/state.json
  CLAUDE.md:   materialized in worktree

Inherited from parent: stack, llm_project, adr_counter, claude_md_managed.
Reset for fresh start: current_slice, slices map, audit history.

Next: cd into the worktree and start a slice with /slice-new <name>.
EOF
}

# ── List ────────────────────────────────────────────────────────────────────

# sf_worktree_list — emit a markdown table of worktrees with state context.
sf_worktree_list() {
  local repo_root data_dir repo_hash
  repo_root="$(sf_repo_root)"
  data_dir="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/scaffold}"
  repo_hash="$(sf_repo_hash)"

  echo "| Path | Branch | Current slice | Phase | Updated |"
  echo "|---|---|---|---|---|"

  # Parse `git worktree list --porcelain` blocks.
  # Each block: `worktree <path>` line, optional `HEAD <sha>`, then
  # `branch refs/heads/<name>` OR `detached` OR `bare`.
  git -C "$repo_root" worktree list --porcelain 2>/dev/null | awk '
    /^worktree / { wt = $2; head = ""; branch = ""; mode = "" }
    /^HEAD / { head = $2 }
    /^branch refs\/heads\// { branch = $2; sub(/^refs\/heads\//, "", branch); mode = "branch" }
    /^detached/ { mode = "detached" }
    /^bare/ { mode = "bare" }
    /^$/ {
      if (wt) {
        if (mode == "branch") print wt "\t" branch
        else if (mode == "detached") print wt "\t_detached_" substr(head, 1, 7)
        else if (mode == "bare") print wt "\t_bare"
        wt = ""
      }
    }
    END {
      if (wt) {
        if (mode == "branch") print wt "\t" branch
        else if (mode == "detached") print wt "\t_detached_" substr(head, 1, 7)
        else if (mode == "bare") print wt "\t_bare"
      }
    }
  ' | while IFS=$'\t' read -r wt_path branch; do
    local safe_branch="${branch//\//__}"
    local state_path="${data_dir}/projects/${repo_hash}/branches/${safe_branch}/state.json"
    local current_slice="(unmanaged)"
    local phase="—"
    local updated="—"
    if [[ -r "$state_path" ]]; then
      current_slice="$(jq -r '.current_slice // "(none)"' "$state_path" 2>/dev/null)"
      local cs; cs="$(jq -r '.current_slice // ""' "$state_path" 2>/dev/null)"
      if [[ -n "$cs" ]]; then
        phase="$(jq -r --arg s "$cs" '.slices[$s].phase // "—"' "$state_path" 2>/dev/null)"
      fi
      updated="$(jq -r '.updated_at // "—"' "$state_path" 2>/dev/null)"
    fi
    # Display the wt path relative to repo_root's parent for readability
    local display_path="${wt_path}"
    echo "| ${display_path} | ${branch} | ${current_slice} | ${phase} | ${updated} |"
  done
}
