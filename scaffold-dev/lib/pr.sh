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

# sd_merge_mode — echo during_dev.merge_mode, defaulting unknown values to "direct".
sd_merge_mode() {
  local m
  m="$(sd_manifest_get '.during_dev.merge_mode')" || m="direct"
  case "$m" in
    ""|"direct"|"pr_hierarchical") ;;
    *) m="direct" ;;
  esac
  echo "$m"
}

# sd_sprint_branch_name <sprint_id> — substitute {sprint_id} in the template
# (during_dev.sprint_branch_naming; default "sprint-{sprint_id}").
sd_sprint_branch_name() {
  local sprint_id="$1" tpl
  tpl="$(sd_manifest_get '.during_dev.sprint_branch_naming')" || tpl="sprint-{sprint_id}"
  echo "${tpl//\{sprint_id\}/$sprint_id}"
}

# sd_slice_branch_name <vs_id> — substitute {vs_id} in the template
# (during_dev.slice_branch_naming; default "slice/{vs_id}").
sd_slice_branch_name() {
  local vs_id="$1" tpl
  tpl="$(sd_manifest_get '.during_dev.slice_branch_naming')" || tpl="slice/{vs_id}"
  echo "${tpl//\{vs_id\}/$vs_id}"
}

_sd_sprint_branch_name() { sd_sprint_branch_name "$@"; }
_sd_slice_branch_name() { sd_slice_branch_name "$@"; }

# sd_branch_create_from <base> <new> — ensure local <new> exists in canonical.
# Idempotent: rc 0 if <new> already exists locally. Otherwise, if `origin/<new>`
# exists (the integration branch already advanced on the remote — e.g. a fresh
# clone or a deleted local branch, where the remote holds earlier merged slice
# PRs), create <new> from `origin/<new>` to REUSE that history rather than
# recreating it off <base> and diverging. Only when there is no `origin/<new>`
# does it fall back to creating <new> off <base> (the first-slice path).
# rc 1 if neither `origin/<new>` nor <base> is available.
sd_branch_create_from() {
  local base="$1" new="$2" canonical
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_branch_create_from: no canonical.root"; return 1; }
  if git -C "$canonical" rev-parse --verify --quiet "refs/heads/$new" >/dev/null; then
    return 0
  fi
  # Prefer an existing remote <new> (reuse merged integration history) over <base>.
  if git -C "$canonical" remote get-url origin >/dev/null 2>&1; then
    git -C "$canonical" fetch -q origin "$new" 2>/dev/null || true
    if git -C "$canonical" rev-parse --verify --quiet "refs/remotes/origin/$new" >/dev/null; then
      if ! git -C "$canonical" branch "$new" "origin/$new" >/dev/null 2>&1; then
        sd_log_error "sd_branch_create_from: failed to create $new from origin/$new"
        return 1
      fi
      return 0
    fi
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

# sd_branch_sync <branch> — fast-forward the local <branch> to origin/<branch>
# before it is reused as a base. An integration branch (e.g. sprint-N) advances
# on the remote when a child slice PR merges; a stale local base would omit those
# commits and a later push would be rejected non-fast-forward.
#
# rc 0 (no-op) when: no 'origin' remote, no remote <branch>, no local <branch>,
#   or the local branch already CONTAINS origin/<branch> (up-to-date or ahead).
# Fast-forwards when the local branch is strictly behind origin.
# rc 1 (HARD FAIL) when the local branch has DIVERGED from origin/<branch> or
#   cannot be fast-forwarded (dirty checkout, checked out in another worktree).
#   The caller MUST NOT reuse a diverged base — these gates halt and surface it
#   rather than silently building off stale history.
sd_branch_sync() {
  local branch="$1" canonical cur
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_branch_sync: no canonical.root"; return 1; }
  git -C "$canonical" remote get-url origin >/dev/null 2>&1 || return 0
  git -C "$canonical" fetch -q origin "$branch" 2>/dev/null || return 0
  git -C "$canonical" rev-parse --verify --quiet "refs/remotes/origin/$branch" >/dev/null || return 0
  git -C "$canonical" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null || return 0
  # Local already contains origin (equal or ahead) → nothing to fast-forward.
  if git -C "$canonical" merge-base --is-ancestor "origin/$branch" "$branch" 2>/dev/null; then
    return 0
  fi
  # Local is NOT strictly behind origin (and not ahead) → diverged. HARD FAIL.
  if ! git -C "$canonical" merge-base --is-ancestor "$branch" "origin/$branch" 2>/dev/null; then
    sd_log_error "sd_branch_sync: $branch has diverged from origin/$branch; reconcile manually before reusing it as a base."
    return 1
  fi
  # Local strictly behind origin → fast-forward.
  cur="$(git -C "$canonical" rev-parse --abbrev-ref HEAD 2>/dev/null)"
  if [[ "$cur" == "$branch" ]]; then
    git -C "$canonical" merge --ff-only -q "origin/$branch" 2>/dev/null \
      || { sd_log_error "sd_branch_sync: cannot fast-forward checked-out $branch (dirty working tree?); reconcile manually."; return 1; }
  else
    git -C "$canonical" branch -f "$branch" "origin/$branch" >/dev/null 2>&1 \
      || { sd_log_error "sd_branch_sync: cannot fast-forward $branch to origin/$branch (checked out in another worktree?); reconcile manually."; return 1; }
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
  body_file="$(sd_abs_path "$body_file")"
  [[ -f "$body_file" ]] || { sd_log_error "sd_pr_open: body file not found: $body_file"; return 1; }
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
  (cd "$canonical" && gh pr view "$pr" --json mergeStateStatus,statusCheckRollup,reviews,latestReviews,comments,reviewDecision,commits)
}

# sd_pr_review_comments <pr> — fetch INLINE (line-level) review comments via the
# REST API. `gh pr view --json` returns only review summaries (reviews/
# latestReviews) and conversation comments — NOT the line-level comments where a
# bot (Codex/CodeRabbit) or human leaves inline findings. The pre-merge gate must
# fetch these so it never merges over unresolved inline feedback while CI is green.
# Emits one raw JSON array. NO interpretation. rc 1 if gh/jq/api fails.
sd_pr_review_comments() {
  local pr="$1" canonical num out
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_pr_review_comments: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_review_comments: 'gh' not in PATH."
    return 1
  fi
  # Accept a PR URL (gh pr create echoes one) OR a bare number — the REST path
  # needs the numeric id. Strip everything up to the last '/'.
  num="${pr##*/}"
  if ! out="$(cd "$canonical" && gh api --paginate --slurp "repos/{owner}/{repo}/pulls/$num/comments" 2>&1)"; then
    sd_log_error "sd_pr_review_comments: gh api failed: $out"
    return 1
  fi
  # Real `gh api --slurp` wraps paginated array responses as [page1, page2, ...].
  # The test shim emits a flat array directly; accept both while preserving one
  # flat-array contract for the agent gate.
  printf '%s\n' "$out" | jq 'if type == "array" and (.[0] | type) == "array" then add else . end // []'
}

# sd_pr_merge <pr> [extra gh args...] — wraps gh pr merge. Defaults to --merge
# when no explicit --merge/--rebase/--squash strategy is supplied. Pass --auto
# to enable auto-merge once required checks pass.
sd_pr_merge() {
  local pr="$1"; shift
  local canonical has_strategy arg
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_pr_merge: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_merge: 'gh' not in PATH."
    return 1
  fi
  has_strategy=0
  for arg in "$@"; do
    case "$arg" in
      --merge|--rebase|--squash) has_strategy=1 ;;
    esac
  done
  if [[ "$has_strategy" -eq 0 ]]; then
    set -- --merge "$@"
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
  body_file="$(sd_abs_path "$body_file")"
  [[ -f "$body_file" ]] || { sd_log_error "sd_issue_create: body file not found: $body_file"; return 1; }
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
# Defaults to --limit 200 (gh's own default is only 30, which would hide older
# matching issues from de-dup/recall); a caller-supplied --limit overrides it.
sd_issue_list() {
  local canonical has_limit=0 arg
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_issue_list: no canonical.root"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_issue_list: 'gh' not in PATH."
    return 1
  fi
  for arg in "$@"; do
    case "$arg" in --limit|--limit=*) has_limit=1 ;; esac
  done
  if [[ "$has_limit" -eq 0 ]]; then
    set -- --limit 200 "$@"
  fi
  (cd "$canonical" && gh issue list --state open --json number,title,body,labels "$@")
}
