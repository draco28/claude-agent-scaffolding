---
description: List all worktrees of the current repo with branch, current slice, phase, and last activity. Joins git's worktree list with each branch's scaffold state.
argument-hint: ""
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/worktree.sh"

REPO_ROOT="$(sf_repo_root)"
if ! git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "scaffold: not inside a git repo. /scaffold-worktree-list requires git."
  exit 1
fi

echo "Worktrees of $(basename "$REPO_ROOT") (hash: $(sf_repo_hash))"
echo ""
sf_worktree_list
'
```

After printing, briefly highlight which worktree the user is currently in (compare `sf_repo_root` to the `Path` column). If a worktree shows `(unmanaged)`, that means it exists on disk but `/scaffold-init` hasn't been run there — suggest they either init it or delete it if no longer needed.
