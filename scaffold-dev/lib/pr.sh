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

# _sd_repo_target <caller> [args...] — shared `--repo-root` parser + target resolver
# for the gh-wrapping helpers (sd_pr_state / sd_pr_review_comments / sd_pr_merge /
# sd_remote_check / sd_issue_create / sd_issue_list). Parses an optional
# `--repo-root DIR` / `--repo-root=DIR` out of [args...] and resolves the repo to act on:
#   explicit --repo-root DIR  → that DIR (e.g. /work-pr's current repo, /defer --tooling)
#   otherwise                 → .canonical.root from the manifest (byte-compatible default)
# Returns via two globals — command substitution runs in a subshell (can't write back an
# array) and bash 3.2 has no namerefs, so the caller reads them after the call:
#   _SD_TARGET — the resolved repo dir
#   _SD_REST   — the remaining non-`--repo-root` args, to forward to gh (empty array ok)
# rc 1 + message when `--repo-root` is given with no value (the #48 shift-2 infinite-loop
# / silent-canonical-fallback guard) or when neither a DIR nor a canonical.root resolves.
_sd_repo_target() {
  local caller="$1"; shift
  local repo_root=""
  _SD_REST=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root)
        [[ $# -ge 2 && -n "$2" ]] || { sd_log_error "$caller: --repo-root requires a non-empty DIR"; return 1; }
        repo_root="$2"; shift 2 ;;
      --repo-root=*)
        repo_root="${1#*=}"
        [[ -n "$repo_root" ]] || { sd_log_error "$caller: --repo-root requires a non-empty DIR"; return 1; }
        shift ;;
      *) _SD_REST+=("$1"); shift ;;
    esac
  done
  if [[ -n "$repo_root" ]]; then
    _SD_TARGET="$repo_root"
  else
    _SD_TARGET="$(sd_manifest_get '.canonical.root')" || { sd_log_error "$caller: no canonical.root"; return 1; }
  fi
  return 0
}

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

# sd_remote_check [--repo-root DIR] — verify the target repo has an 'origin' remote
# AND gh is present + authenticated. Default target: canonical (manifest); --repo-root
# checks a caller-chosen repo (e.g. /work-pr's current repo). rc 0 on success; rc 1 +
# actionable message otherwise.
sd_remote_check() {
  local target
  _sd_repo_target "sd_remote_check" "$@" || return 1
  target="$_SD_TARGET"
  if ! git -C "$target" remote get-url origin >/dev/null 2>&1; then
    sd_log_error "sd_remote_check: no 'origin' remote in $target. Add one (git remote add origin <url>) — PR operations resolve the repo from it."
    return 1
  fi
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_remote_check: 'gh' not in PATH. Install GitHub CLI — PR operations run via gh."
    return 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    sd_log_error "sd_remote_check: 'gh' is not authenticated. Run 'gh auth login' — PR operations need it."
    return 1
  fi
  if ! (cd "$target" && gh repo view >/dev/null 2>&1); then
    sd_log_error "sd_remote_check: $target is not a GitHub repo that gh can resolve from origin. Use a different repo or pass a different --repo-root."
    return 1
  fi
  return 0
}

# sd_pr_open <head> <base> <title> <body-file> — wraps gh pr create (run from
# canonical so gh resolves the repo from origin). Echoes the PR url. rc 1 if gh
# absent or the create fails.
# IDEMPOTENT: if an open PR already exists for <head>, reuse it (echo its url)
# instead of erroring with "a pull request for branch … already exists" — so a
# slice/sprint close that left the PR open for async CI can be safely re-run.
sd_pr_open() {
  local head="$1" base="$2" title="$3" body_file="$4" canonical out existing
  canonical="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_pr_open: no canonical.root"; return 1; }
  body_file="$(sd_abs_path "$body_file")"
  [[ -f "$body_file" ]] || { sd_log_error "sd_pr_open: body file not found: $body_file"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_open: 'gh' not in PATH."
    return 1
  fi
  existing="$(cd "$canonical" && gh pr list --head "$head" --state open --json url --jq '.[0].url // empty' 2>/dev/null)"
  if [[ -n "$existing" ]]; then
    echo "$existing"
    return 0
  fi
  if ! out="$(cd "$canonical" && gh pr create --head "$head" --base "$base" --title "$title" --body-file "$body_file" 2>&1)"; then
    sd_log_error "sd_pr_open: gh pr create failed: $out"
    return 1
  fi
  echo "$out"
  return 0
}

# sd_pr_state <pr> [--repo-root DIR] — emit gh pr view JSON for the agent-driven gate
# to reason over. NO interpretation here. Default target: canonical; --repo-root acts on
# a caller-chosen repo (e.g. /work-pr's current repo). rc 1 if gh absent.
sd_pr_state() {
  local pr="$1"; shift
  local target
  _sd_repo_target "sd_pr_state" "$@" || return 1
  target="$_SD_TARGET"
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_state: 'gh' not in PATH."
    return 1
  fi
  (cd "$target" && gh pr view "$pr" --json mergeStateStatus,statusCheckRollup,reviews,latestReviews,comments,reviewDecision,commits)
}

# sd_pr_review_comments <pr> [--repo-root DIR] — fetch INLINE (line-level) review
# comments via the REST API. Default target: canonical; --repo-root acts on a
# caller-chosen repo (e.g. /work-pr's current repo).
# `gh pr view --json` returns only review summaries (reviews/
# latestReviews) and conversation comments — NOT the line-level comments where a
# bot (Codex/CodeRabbit) or human leaves inline findings. The pre-merge gate must
# fetch these so it never merges over unresolved inline feedback while CI is green.
# Emits one raw JSON array. NO interpretation. rc 1 if gh/jq/api fails.
sd_pr_review_comments() {
  local pr="$1"; shift
  local target num out
  _sd_repo_target "sd_pr_review_comments" "$@" || return 1
  target="$_SD_TARGET"
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_pr_review_comments: 'gh' not in PATH."
    return 1
  fi
  # Accept a PR URL (gh pr create echoes one) OR a bare number — the REST path
  # needs the numeric id. Strip everything up to the last '/'.
  num="${pr##*/}"
  # Capture stdout ONLY — folding gh's stderr (warnings / paginate progress) into
  # stdout via 2>&1 would corrupt the JSON and break the jq parse below on the
  # SUCCESS path. Send stderr to a temp file so a real failure stays diagnosable.
  local errf; errf="$(mktemp)"
  if ! out="$(cd "$target" && gh api --paginate --slurp "repos/{owner}/{repo}/pulls/$num/comments" 2>"$errf")"; then
    sd_log_error "sd_pr_review_comments: gh api failed: $(cat "$errf")"
    rm -f "$errf"
    return 1
  fi
  rm -f "$errf"
  # Empty stdout (no body) → emit an empty array, not an empty string.
  [[ -n "$out" ]] || { printf '%s\n' '[]'; return 0; }
  # Real `gh api --slurp` wraps paginated array responses as [page1, page2, ...].
  # The test shim emits a flat array directly; accept both while preserving one
  # flat-array contract for the agent gate.
  printf '%s\n' "$out" | jq 'if type == "array" and (.[0] | type) == "array" then add else . end // []'
}

# sd_pr_merge <pr> [--repo-root DIR] [extra gh args...] — wraps gh pr merge. Defaults
# to --merge when no explicit --merge/--rebase/--squash strategy is supplied. Pass
# --auto to enable auto-merge once required checks pass. Default target: canonical;
# --repo-root merges a PR in a caller-chosen repo (e.g. /work-pr's current repo) and is
# parsed out here, never forwarded to gh.
sd_pr_merge() {
  local pr="$1"; shift
  local target has_strategy arg
  _sd_repo_target "sd_pr_merge" "$@" || return 1
  target="$_SD_TARGET"
  if [[ ${#_SD_REST[@]} -gt 0 ]]; then set -- "${_SD_REST[@]}"; else set --; fi
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
  (cd "$target" && gh pr merge "$pr" "$@")
}

# sd_issue_create <title> <body-file> [--repo-root DIR] [extra gh args...] —
# wraps gh issue create (run from the target repo so gh resolves it from origin).
# Echoes gh's stdout (issue url/number). rc 1 if gh absent or the create fails.
# --repo-root DIR targets a caller-chosen repo (e.g. /defer --tooling routing to
# .tooling_repo.root); absent → canonical, byte-compatible with pre-#48 callers.
# --repo-root is parsed out here, never forwarded to gh.
sd_issue_create() {
  local title="$1" body_file="$2"; shift 2
  local target out
  _sd_repo_target "sd_issue_create" "$@" || return 1
  target="$_SD_TARGET"
  if [[ ${#_SD_REST[@]} -gt 0 ]]; then set -- "${_SD_REST[@]}"; else set --; fi
  body_file="$(sd_abs_path "$body_file")"
  [[ -f "$body_file" ]] || { sd_log_error "sd_issue_create: body file not found: $body_file"; return 1; }
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_issue_create: 'gh' not in PATH."
    return 1
  fi
  if ! out="$(cd "$target" && gh issue create --title "$title" --body-file "$body_file" "$@" 2>&1)"; then
    sd_log_error "sd_issue_create: gh issue create failed: $out"
    return 1
  fi
  echo "$out"
  return 0
}

# sd_issue_list [--repo-root DIR] [extra gh args...] — emit open issues as JSON
# for the agent to reason over (blocker-recall / de-dup). NO interpretation here.
# rc 1 if gh absent. Defaults to --limit 200 (gh's own default is only 30, which
# would hide older matching issues from de-dup/recall); a caller-supplied --limit
# overrides it. --repo-root DIR targets a caller-chosen repo (default canonical);
# it is parsed out here, never forwarded to gh.
sd_issue_list() {
  local target has_limit=0 arg
  _sd_repo_target "sd_issue_list" "$@" || return 1
  target="$_SD_TARGET"
  if [[ ${#_SD_REST[@]} -gt 0 ]]; then set -- "${_SD_REST[@]}"; else set --; fi
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
  (cd "$target" && gh issue list --state open --json number,title,body,labels "$@")
}

# sd_label_ensure <label> [repo-root] — idempotent `gh label create <label>` run
# from the target repo (default canonical). rc 0 if the label exists or was just
# created; rc 1 + actionable message on a real failure. #48 Stage 2: the
# deferring-work-item §4 retry path OFFERS this when a repo lacks `tech-debt`; it
# is NEVER a blocker for recording the debt (label setup is best-effort).
sd_label_ensure() {
  local label="${1:-}" repo_root="${2:-}" target out
  [[ -n "$label" ]] || { sd_log_error "sd_label_ensure: label name required"; return 1; }
  if [[ -n "$repo_root" ]]; then
    target="$repo_root"
  else
    target="$(sd_manifest_get '.canonical.root')" || { sd_log_error "sd_label_ensure: no canonical.root"; return 1; }
  fi
  if ! command -v gh >/dev/null 2>&1; then
    sd_log_error "sd_label_ensure: 'gh' not in PATH."
    return 1
  fi
  if out="$(cd "$target" && gh label create "$label" 2>&1)"; then
    return 0
  fi
  # Idempotent: an "already exists" / "already been taken" rejection means the
  # label is present — which is all we need. Treat it as success, not failure.
  if printf '%s' "$out" | grep -qiE 'already (exists|been taken)|already_exists'; then
    return 0
  fi
  sd_log_error "sd_label_ensure: gh label create '$label' failed: $out"
  return 1
}
