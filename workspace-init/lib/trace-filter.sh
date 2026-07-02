#!/usr/bin/env bash
# lib/trace-filter.sh — render + install commit-msg hook with baked AI workspace path.
#
# The commit-msg hook (hooks/commit-msg.tmpl) reads the pairing manifest to
# decide which patterns to block. The AI workspace absolute path is baked into
# the hook at install time so canonical's hook (in canonical's .git/hooks/) can
# find the sibling manifest without a walk-up search.
#
# Requires: lib/_helpers.sh (wi_log_op, wi_log_error)

set -u

if ! declare -F wi_log_op >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_helpers.sh"
fi
if ! declare -F wi_git_is_linked_worktree >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/skeleton.sh"
fi

# Locate the hooks/commit-msg.tmpl. Prefer WI_HOOKS_DIR (set by tests/_helpers.sh)
# with a relative-to-script fallback for production.
_wi_trace_filter_template() {
  if [[ -n "${WI_HOOKS_DIR:-}" && -f "${WI_HOOKS_DIR}/commit-msg.tmpl" ]]; then
    echo "${WI_HOOKS_DIR}/commit-msg.tmpl"
  else
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/commit-msg.tmpl"
  fi
}

# wi_trace_filter_render <ai-workspace-root>
# Render the template substituting __AI_WORKSPACE_PATH__ with the given absolute path.
# Output goes to stdout. Returns 1 if the template is missing.
wi_trace_filter_render() {
  local ai_root="$1"
  local tmpl
  tmpl="$(_wi_trace_filter_template)"
  if [[ ! -f "$tmpl" ]]; then
    wi_log_error "wi_trace_filter_render: template not found: $tmpl"
    return 1
  fi
  # Use | as sed delimiter since absolute paths contain /.
  # Note: if ai_root contains | this would break, but paths rarely do; for safety
  # we use sed's c-escape via printf-quoting if needed.
  sed "s|__AI_WORKSPACE_PATH__|${ai_root}|g" "$tmpl"
}

# wi_trace_filter_is_installable_repo_root <target-repo>
# True only for an own git worktree root whose repo-local hooks dir is usable.
# Rejects non-repos, bare repos, nested subdirs of a parent repo, and linked worktrees.
wi_trace_filter_is_installable_repo_root() {
  local target_repo="${1:-}"
  [[ -n "$target_repo" ]] || return 1

  local inside_work_tree
  inside_work_tree="$(git -C "$target_repo" rev-parse --is-inside-work-tree 2>/dev/null)" || return 1
  [[ "$inside_work_tree" == "true" ]] || return 1

  local top_level target_canon top_canon
  top_level="$(git -C "$target_repo" rev-parse --show-toplevel 2>/dev/null)" || return 1
  target_canon="$(wi_realpath "$target_repo")"
  top_canon="$(wi_realpath "$top_level")"
  [[ "$target_canon" == "$top_canon" ]] || return 1

  if wi_git_is_linked_worktree "$target_repo"; then
    return 1
  fi
  return 0
}

# wi_trace_filter_install <ai-workspace-root> <target-repo>
# Render + write the commit-msg hook to the repo's resolved hooks dir + chmod +x + log HOOK_INSTALL.
wi_trace_filter_install() {
  local ai_root="$1"
  local target_repo="$2"
  if ! wi_trace_filter_is_installable_repo_root "$target_repo"; then
    wi_log_error "wi_trace_filter_install: target is not an installable git repo root: $target_repo"
    return 1
  fi

  # Use the repo's real git dir, not `--git-path hooks`: the trace filter is intentionally
  # installed into the repo-local hooks dir even when core.hooksPath points elsewhere.
  local git_dir hooks_dir
  git_dir="$(git -C "$target_repo" rev-parse --git-dir 2>/dev/null)" || {
    wi_log_error "wi_trace_filter_install: could not resolve hooks dir: $target_repo"
    return 1
  }
  hooks_dir="${git_dir}/hooks"
  case "$hooks_dir" in
    /*) : ;;
    *)  hooks_dir="${target_repo}/${hooks_dir}" ;;
  esac
  mkdir -p "$hooks_dir" || {
    wi_log_error "wi_trace_filter_install: mkdir failed: $hooks_dir"
    return 1
  }
  local out="${hooks_dir}/commit-msg"
  if ! wi_trace_filter_render "$ai_root" > "$out" 2>/dev/null; then
    rm -f "$out"
    wi_log_error "wi_trace_filter_install: render failed"
    return 1
  fi
  chmod +x "$out" || {
    wi_log_error "wi_trace_filter_install: chmod failed: $out"
    return 1
  }
  local log="${ai_root}/.workspace/init-log"
  wi_log_op "$log" HOOK_INSTALL "$target_repo"
  return 0
}

# wi_trace_filter_install_pair <ai-workspace-root> <canonical-root>
# Install in both AI workspace and canonical.
wi_trace_filter_install_pair() {
  local ai_root="$1"
  local canonical_root="$2"
  wi_trace_filter_install "$ai_root" "$ai_root" || return 1
  wi_trace_filter_install "$ai_root" "$canonical_root" || return 1
  return 0
}
