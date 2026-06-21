# Slice-close under `merge_mode=pr_hierarchical`

Referenced by `closing-vertical-slice` §5 (pre-demo checkout) and §10a (slice→sprint PR). These steps run **only** when `sd merge_mode` == `pr_hierarchical`; the default `direct` mode skips both (work items are already merged into `default_branch` at §8.6). See also `planning-vertical-slice/references/git-workflow.md` for the full topology and the agent-driven pre-merge gate.

## Pre-demo: check out the slice branch (before §5 auto-demo)

Under `pr_hierarchical` the slice's work lives on the slice branch, not `default_branch`. Check it out in canonical before running the auto-demos:

```bash
if [[ "$(sd merge_mode)" == "pr_hierarchical" ]]; then
  git -C "$canonical" checkout -q "$(sd slice_branch_name "$vs_id")" \
    || { printf 'Cannot check out the slice branch in canonical (dirty tree or checked out elsewhere?); resolve before running auto-demos.\n' >&2; exit 1; }
fi
```

**Guard the checkout.** A failed `checkout` (dirty canonical tree, branch checked out in another worktree) would leave canonical on the *wrong* branch and the `auto:` demos would run against it — a silent false green/red. HALT on failure and surface it; never demo against an unverified checkout. Restore is unnecessary on success — the slice branch is the integration target until its PR merges.

## After cleanup: open the slice→sprint PR (§10a)

Runs AFTER §9 harvest + §10 worktree cleanup (work-item worktree/branch cleanup is decoupled from this PR — the slice branch already holds every work-item commit).

1. **Resolve and push the integration branches:**
   ```bash
   slice_branch="$(sd slice_branch_name "$vs_id")"
   sprint_branch="$(sd sprint_branch_name "$sprint_id")"
   sd branch_sync "$sprint_branch"
   sd branch_push "$sprint_branch"
   sd branch_push "$slice_branch"
   ```
2. **Compose the PR body** to a temp file: the slice README (with the populated Demo-verification section) + the architect-critic close-depth summary (§7) + any linked tech-debt/issue references.
3. **Open the PR:**
   ```bash
   slice_pr="$(sd pr_open "$slice_branch" "$sprint_branch" "${vs_id}: <slice title>" "<body-file>")"
   ```
4. **Run the agent-driven pre-merge gate** per `git-workflow.md` (`sd pr_state "$slice_pr"` + `sd pr_review_comments "$slice_pr"` → reason over CI **and** inline review comments → per-finding disposition (P1 fixed pre-merge, P2 fix-or-defer) + reviewer-completeness (a skipped/absent reviewer ≠ green) → surface → ask). Merge via `sd pr_merge` only on explicit user acknowledgment. If the PR is left open for asynchronous CI/review, HALT before §11: report the PR URL/number and do NOT run sprint-close cleanup or tell the user the slice/sprint is closed. Do NOT busy-wait.
