#!/usr/bin/env bash
# scaffold-dev/lib/pr.sh
# PR-hierarchical merge-mode primitives (issue #40). Thin, MECHANICAL wrappers
# over git + gh — ONE operation each, clean exit code / raw JSON out, NO semantic
# parsing. The agent-driven merge gate (references/git-workflow.md) reasons over
# the output. Only invoked when during_dev.merge_mode == "pr_hierarchical"; the
# default "direct" path never sources behavior from here.
#
# Bash 3.2+ compatible. Safe to double-source.

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

# sd_merge_mode — echo during_dev.merge_mode, defaulting to "direct".
sd_merge_mode() {
  local m
  m="$(sd_manifest_get '.during_dev.merge_mode')" || m="direct"
  [[ -z "$m" ]] && m="direct"
  echo "$m"
}

# _sd_sprint_branch_name <sprint_id> — substitute {sprint_id} in the template
# (during_dev.sprint_branch_naming; default "sprint-{sprint_id}").
_sd_sprint_branch_name() {
  local sprint_id="$1" tpl
  tpl="$(sd_manifest_get '.during_dev.sprint_branch_naming')" || tpl="sprint-{sprint_id}"
  echo "${tpl//\{sprint_id\}/$sprint_id}"
}

# _sd_slice_branch_name <vs_id> — substitute {vs_id} in the template
# (during_dev.slice_branch_naming; default "slice/{vs_id}").
_sd_slice_branch_name() {
  local vs_id="$1" tpl
  tpl="$(sd_manifest_get '.during_dev.slice_branch_naming')" || tpl="slice/{vs_id}"
  echo "${tpl//\{vs_id\}/$vs_id}"
}

# sd_branch_create_from <base> <new> — create <new> off <base> in canonical.
# Idempotent: rc 0 if <new> already exists. rc 1 if <base> is missing.
sd_branch_create_from() {
  local base="$1" new="$2" canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_branch_create_from: no canonical.root"; return 1; }
  if git -C "$canonical" rev-parse --verify --quiet "refs/heads/$new" >/dev/null; then
    return 0
  fi
  if ! git -C "$canonical" rev-parse --verify --quiet "refs/heads/$base" >/dev/null; then
    sd_log_error "sd_branch_create_from: base branch not found: $base"
    return 1
  fi
  if ! git -C "$canonical" branch "$new" "$base" >/dev/null 2>&1; then
    sd_log_error "sd_branch_create_from: failed to create $new off $base"
    return 1
  fi
  return 0
}

# sd_branch_push <branch> — push <branch> to origin with upstream. rc 1 if no
# 'origin' remote configured on canonical.
sd_branch_push() {
  local branch="$1" canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_branch_push: no canonical.root"; return 1; }
  if ! git -C "$canonical" remote get-url origin >/dev/null 2>&1; then
    sd_log_error "sd_branch_push: no 'origin' remote on canonical; pr_hierarchical mode requires a remote."
    return 1
  fi
  if ! git -C "$canonical" push -u origin "$branch" >/dev/null 2>&1; then
    sd_log_error "sd_branch_push: failed to push $branch to origin"
    return 1
  fi
  return 0
}

# sd_remote_check — verify canonical has an 'origin' remote AND gh is present +
# authenticated. rc 0 on success; rc 1 + actionable message otherwise.
sd_remote_check() {
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_remote_check: no canonical.root"; return 1; }
  if ! git -C "$canonical" remote get-url origin >/dev/null 2>&1; then
    sd_log_error "sd_remote_check: no 'origin' remote on canonical. Add one (git remote add origin <url>) — pr_hierarchical mode opens PRs against it."
    return 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_remote_check: 'gh' not in PATH. Install GitHub CLI — pr_hierarchical mode opens PRs via gh."
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    sd_log_error "sd_remote_check: 'gh' is not authenticated. Run 'gh auth login' — pr_hierarchical mode needs it to open PRs."
    return 1
  fi
  return 0
}

# sd_pr_open <head> <base> <title> <body-file> — wraps gh pr create (run from
# canonical so gh resolves the repo from origin). Echoes gh's stdout (PR url or
# number). rc 1 if gh absent or the create fails.
sd_pr_open() {
  local head="$1" base="$2" title="$3" body_file="$4" canonical out
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_pr_open: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_open: 'gh' not in PATH."
    return 1
  fi
  if ! out="$(cd "$canonical" && gh pr create --head "$head" --base "$base" --title "$title" --body-file "$body_file" 2>&1)"; then
    sd_log_error "sd_pr_open: gh pr create failed: $out"
    return 1
  fi
  echo "$out"
  return 0
}

# sd_pr_state <pr> — emit gh pr view JSON for the agent-driven gate to reason
# over. NO interpretation here. rc 1 if gh absent.
sd_pr_state() {
  local pr="$1" canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_pr_state: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_state: 'gh' not in PATH."
    return 1
  fi
  (cd "$canonical" && gh pr view "$pr" --json mergeStateStatus,statusCheckRollup,reviews,reviewThreads,latestReviews,comments)
}

# sd_pr_merge <pr> [extra gh args...] — wraps gh pr merge. Pass --auto to enable
# auto-merge once required checks pass.
sd_pr_merge() {
  local pr="$1"; shift
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_pr_merge: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_merge: 'gh' not in PATH."
    return 1
  fi
  (cd "$canonical" && gh pr merge "$pr" "$@")
}

# sd_issue_create <title> <body-file> [extra gh args...] — wraps gh issue create
# (run from canonical so gh resolves the repo from origin). Echoes gh's stdout
# (issue url/number). rc 1 if gh absent or the create fails.
sd_issue_create() {
  local title="$1" body_file="$2"; shift 2
  local canonical out
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_issue_create: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_issue_create: 'gh' not in PATH."
    return 1
  fi
  if ! out="$(cd "$canonical" && gh issue create --title "$title" --body-file "$body_file" "$@" 2>&1)"; then
    sd_log_error "sd_issue_create: gh issue create failed: $out"
    return 1
  fi
  echo "$out"
  return 0
}

# sd_issue_list [extra gh args...] — emit open issues as JSON for the agent to
# reason over (blocker-recall / de-dup). NO interpretation here. rc 1 if gh absent.
sd_issue_list() {
  local canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_issue_list: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_issue_list: 'gh' not in PATH."
    return 1
  fi
  (cd "$canonical" && gh issue list --state open --json number,title,body,labels "$@")
}
