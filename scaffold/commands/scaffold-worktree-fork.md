---
description: Create a git worktree on a new branch AND fork the current branch's scaffold state into it. Materializes CLAUDE.md inside the new worktree. Refuses if branch already exists or target path is occupied.
argument-hint: "<branch> [--path <p>]"
allowed-tools: Bash(bash:*)
---

```bash
bash -c '
set +e
source "${CLAUDE_PLUGIN_ROOT}/lib/worktree.sh"

ARGS="${ARGUMENTS:-$*}"
BRANCH=""
TARGET_PATH=""

# Parse args: first positional → branch; --path <p> → target path
expect_path=0
for tok in $ARGS; do
  if [[ $expect_path -eq 1 ]]; then
    TARGET_PATH="$tok"
    expect_path=0
    continue
  fi
  case "$tok" in
    --path) expect_path=1 ;;
    --path=*) TARGET_PATH="${tok#--path=}" ;;
    *) [[ -z "$BRANCH" ]] && BRANCH="$tok" ;;
  esac
done

if [[ -z "$BRANCH" ]]; then
  echo "Usage: /scaffold-worktree-fork <branch> [--path <p>]"
  echo ""
  echo "Examples:"
  echo "  /scaffold-worktree-fork auth-rewrite-alt"
  echo "  /scaffold-worktree-fork feat/payments --path ../payments-spike"
  exit 1
fi

sf_worktree_fork "$BRANCH" "$TARGET_PATH"
exit $?
' "$ARGUMENTS"
```

After running, the new worktree exists on disk and has its own scaffold state. Briefly confirm what was created and offer to `cd` mentally to it:

- Suggest the user run their next slice work *from* the new worktree (a separate Claude Code session if they want true parallel exploration).
- Mention that the memory bank is shared per-repo, so decisions/notes recorded in either worktree are visible to the other via `recall`.
- ADR numbering is also shared (driven by `state.adr_counter` which was inherited from the parent's state) — so worktree-A creating ADR-0005 means worktree-B's next ADR is `0006`.

If the fork failed (branch exists, path occupied), help the user pick a different name or path. Don't suggest deleting the existing branch/dir without explicit user confirmation.
