#!/usr/bin/env bash
# Per-work-item worktrees. rc 8 = git/worktree operation failure (see the plan's
# rc-taxonomy note); rc 2 = usage / unknown repo key; rc 1 = not found.
#
# D4: every entry point takes a REPO KEY as its first argument, even though only
# `canonical` resolves today. `target_repo` has been written into state since B4
# with no reader; this is its first. Plan D adds `private_core` by extending
# _oss_repo_root alone - retrofitting the parameter later would mean changing
# every call site and every path-shape assertion in this file.

_oss_repo_root() { # $1=repo-key
  local key="${1:-canonical}" root
  case "$key" in
    canonical|ai_workspace|private_core) ;;
    *) echo "oss: unknown repo key '$key' (canonical|ai_workspace|private_core)" >&2; return 2 ;;
  esac
  root="$(oss_manifest_get ".${key}.root" 2>/dev/null)" || root=""
  # An unconfigured key must NOT fall back to canonical: silently building a
  # private_core worktree inside the public repo is precisely the leak the
  # companion spec exists to prevent.
  [ -n "$root" ] && [ "$root" != "null" ] \
    || { echo "oss: repo '$key' is not configured in the pairing manifest" >&2; return 2; }
  printf '%s\n' "$root"
}

# `oss_worktree_dir` was REMOVED in v0.2.0: built in Plan C1 and never called by
# the dispatcher, another lib, a test, or any prose. Every consumer that needs
# the path composes it from `_oss_repo_root` inline, which is what the functions
# below do.

oss_worktree_add() { # $1=repo-key $2=work-item-id $3=slug $4=base-ref ; echoes abs path
  local key="$1" wi="$2" slug="$3" base="${4:-HEAD}" root dir path branch
  root="$(_oss_repo_root "$key")" || return $?
  dir="$root/.worktrees"; path="$dir/$wi"
  branch="$(oss_id_work_item_branch "$wi" "$slug")"
  [ -e "$path" ] && { echo "oss: worktree already exists at $path" >&2; return 8; }
  mkdir -p "$dir" || return 8
  _oss_worktree_ignore "$root" || true
  # NOT `2>&1`: this function's STDOUT IS ITS RETURN VALUE (the abs path), so
  # merging git's stderr into stdout makes any warning git decides to emit become
  # part of the path the caller captures. `-q` is silent on success today, which
  # is exactly what makes this the kind of latent bug that surfaces years later
  # on someone else's git version or with a chatty hook installed. Let stderr be
  # stderr.
  if ! git -C "$root" worktree add -q -b "$branch" "$path" "$base"; then
    echo "oss: git worktree add failed for $wi (branch $branch, base $base)" >&2
    return 8
  fi
  printf '%s\n' "$path"
}

# The worktree root lives INSIDE the repo, so without this every spawn leaves
# `?? .worktrees/` in the canonical repo's status - a dirty tree ossify itself
# created, in the very repo whose cleanliness the close ceremony checks. The
# leading dot already keeps most test runners out (pytest's default
# `norecursedirs` includes `.*`; `go test ./...` skips dirs beginning with `.`
# or `_`), so this closes the reporting half, not a demo-integrity hole.
#
# `.git/info/exclude`, NOT `.gitignore` - and this was verified empirically, not
# reasoned about. `.gitignore` is TRACKED in any real project, so appending to it
# leaves ` M .gitignore` and produces exactly the dirty tree this exists to
# prevent (measured: appending to a tracked .gitignore yields ` M .gitignore`;
# writing to .git/info/exclude yields an EMPTY status). `info/exclude` is
# repo-local, never tracked, never pushed, and is the idiomatic place for an
# ignore the tool owns rather than the project. Never edit a file the project
# owns to make a tool's own artifact disappear.
_oss_worktree_ignore() { # $1=repo-root ; best-effort, never fatal
  # Resolve the real git common dir rather than assuming `.git` is a directory.
  # A repo created with `git init --separate-git-dir` (or a submodule) has a
  # `.git` FILE pointing elsewhere — its info/exclude lives at the common dir,
  # not at `$1/.git/info/exclude`. The old `[ -d "$1/.git" ] || return 0`
  # guard skipped those repos, leaving `.worktrees/` permanently un-excluded
  # and the canonical tree dirty on every spawn. (Codex P2 finding #5.)
  local cd
  cd="$(git -C "$1" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" \
    || { echo "oss: cannot resolve git common dir for $1 - .worktrees/ not excluded" >&2; return 1; }
  local ex="$cd/info/exclude"
  mkdir -p "$cd/info" || return 1
  [ -f "$ex" ] && grep -qxF '.worktrees/' "$ex" && return 0
  printf '%s\n' '.worktrees/' >> "$ex" 2>/dev/null || return 1
}

oss_worktree_resolve() { # $1=repo-key $2=work-item-id
  local root path; root="$(_oss_repo_root "$1")" || return $?
  path="$root/.worktrees/$2"
  [ -d "$path" ] || { echo "oss: no worktree for '$2' under $root/.worktrees" >&2; return 1; }
  printf '%s\n' "$path"
}

# D9: HALT on a dirty worktree; never `--force`. The source retries with --force
# (discarding uncommitted work) and swallows the branch delete with `|| true`,
# while its own skill prose promises a halt and the close ceremony asserts no
# work-* branch survives. Both halves are fixed here.
oss_worktree_remove() { # $1=repo-key $2=work-item-id
  local key="$1" wi="$2" root path branch dirty
  root="$(_oss_repo_root "$key")" || return $?
  path="$(oss_worktree_resolve "$key" "$wi")" || return $?
  dirty="$(git -C "$path" status --porcelain 2>/dev/null)" || dirty=""
  if [ -n "$dirty" ]; then
    echo "oss: worktree $path has uncommitted changes - refusing to remove it" >&2
    printf '%s\n' "$dirty" >&2
    return 8
  fi
  branch="$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null)" || branch=""
  git -C "$root" worktree remove "$path" || { echo "oss: git worktree remove failed for $path" >&2; return 8; }
  if [ -n "$branch" ] && [ "$branch" != "HEAD" ]; then
    # `-d`, NOT `-D`. -D force-deletes an UNMERGED branch, destroying every
    # commit the implementer made. The close ceremony merges work/<wi> back into
    # the spine branch first (T9), so by the time remove runs the branch IS
    # merged and -d succeeds. If it does not, that is the signal that something
    # upstream failed to merge - surface it, never force past it.
    git -C "$root" branch -d "$branch" >/dev/null 2>&1 \
      || { echo "oss: worktree removed but branch '$branch' is not merged - refusing to force-delete it; merge or abandon it explicitly" >&2; return 8; }
  fi
}
