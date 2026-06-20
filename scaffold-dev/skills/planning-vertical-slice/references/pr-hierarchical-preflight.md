# `pr_hierarchical` merge-mode pre-flight (§3.3a)

Referenced by `planning-vertical-slice` §3.3a. Runs ONLY when `sd merge_mode` == `pr_hierarchical`; the default `direct` mode skips all of this (behavior unchanged from v0.1). See `references/git-workflow.md` for the full topology and primitive contracts. The mode gates §8.1 (worktree base), §8.6 (merge target), and slice-close.

```bash
merge_mode="$(sd merge_mode)"   # "direct" (default) | "pr_hierarchical"
```

When `merge_mode == "pr_hierarchical"`:

1. **Refuse fast if the remote/gh prerequisites are missing** — do NOT silently fall back to `direct`:
   ```bash
   sd remote_check || exit 1   # surfaces the actionable error verbatim
   ```

2. **Ensure the sprint integration branch exists — on origin and current** (create off `default_branch` at the first slice; reuse otherwise):
   ```bash
   sprint_branch="$(sd sprint_branch_name "$sprint_id")"
   default_branch="$(sd manifest_get '.canonical.default_branch')" || default_branch="main"
   sd branch_sync "$default_branch"   # fast-forward local main/default after prior sprint→main PRs
   sd branch_create_from "$default_branch" "$sprint_branch"   # reuses origin/$sprint_branch when it exists (fresh clone / deleted local); else cuts from $default_branch (first slice)
   sd branch_sync "$sprint_branch"   # FIRST: fast-forward a reused base if a prior slice PR already merged
   sd branch_push "$sprint_branch"   # THEN: ensure the base exists on origin for the slice→sprint PR
   ```
   **Halt on any non-zero return above.** `branch_sync` HARD-FAILS when a local base has *diverged* from `origin` (or cannot be fast-forwarded); surface the error verbatim and have the user reconcile manually — never branch the slice off a stale or diverged base.

   **Order matters.** Sync the local `$default_branch` before cutting a new sprint branch (a prior sprint→main PR advances `origin/$default_branch`; a stale local default would omit landed commits). Then `branch_sync "$sprint_branch"` runs **before** `branch_push`: a merged slice PR advances `sprint-N` on the remote, so the local base is stale and pushing first would be rejected non-fast-forward. Sync fast-forwards the reused local `$sprint_branch` to origin (no-op on the first slice); then `branch_push` creates it on origin (first slice) or is a no-op fast-forward (later slices).

3. **Slice-ordering check:** if a prior slice's PR into `$sprint_branch` is still open, surface it per `git-workflow.md` (slice-ordering rule) and wait for the user before continuing.

4. **Create the slice branch off the sprint branch** and carry it forward (§8.1 bases work-item worktrees on it; §8.6 merges into it):
   ```bash
   slice_branch="$(sd slice_branch_name "$vs_id")"
   sd branch_create_from "$sprint_branch" "$slice_branch"
   ```
