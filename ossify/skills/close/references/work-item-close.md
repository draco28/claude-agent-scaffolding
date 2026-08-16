# Work-item close — the innermost layer

Depth for SKILL.md §4. Six steps in **binding order**: each step's output is the
next one's input, so running them out of order does not fail — it runs the gate
against paths nobody resolved and merges a branch nobody checked.

This layer is reached two ways and must work identically in both: from the
execution lane, holding a `complete` return (`work-item/references/round-orchestration.md`
§6), and standalone as `/close <wi-id>` with nothing else in scope.

---

## 1. Resolve the three absolute paths

You need **`spec.md`**, **`report.md`** and the **worktree**. Nothing in state
holds a spec path, a report path, or a slug — a work item is
`{spine, title, target_repo, status, created_at, id, branch, worktree_path,
base_sha}` — so the docs paths are reconstructed, and the reconstruction is where
this layer most easily goes silently wrong.

**The worktree is the easy one**: state holds it, written by the execution lane.

```bash
wi="<work-item id>"
wt="$(oss get ".work_items[] | select(.id==\"$wi\") | .worktree_path")"
[ -n "$wt" ] && [ "$wt" != "null" ] && [ -d "$wt" ] \
  || { echo "close: no recorded worktree for $wi - halt"; exit 1; }
```

**Test for `null`, not just emptiness.** `oss get` is `jq -r`: a field that is
absent or JSON-null prints the four characters `null`, which is non-empty and
passes `[ -n … ]`. Every state read in this layer is guarded that way, and the
merge target in step 4 is the one where it matters most — `git merge null`
resolves nothing and the guard that was supposed to catch it already passed.

A missing `worktree_path` means the lane skipped `oss work_item_exec`. That is a
halt, not something to reconstruct: `oss worktree_resolve <target_repo> <wi>`
will happily echo a conventional path whether or not it is the one this item was
built in.

### Route A — in the round flow

The report's *content* is deliberately not in the return payload, but
`report_path` **is**, and it is guaranteed absolute and ending in `report.md`
(`work-item/references/returns.md` §2). `spec.md` is its sibling: `work-item/SKILL.md`
§7 authors the report next to `spec.md` and `handoff.md` in the work item's
directory.

```bash
report="<report_path from the complete return>"
spec="$(dirname "$report")/spec.md"
```

Route A gives you the paths and nothing else. Step 4 additionally needs the
**spine branch**, which a round-flow caller already holds — it cut and checked it
out before round 1 (`round-orchestration.md` §2). A standalone caller has neither,
and recovers both from Route B.

### Route B — standalone

Reconstruct from the id alone. The directory shape is the one the execution lane
writes the handoff into (`round-orchestration.md` §4) — the two must stay
byte-identical, because a drift between them has no runtime signal:

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<spine-slug>/work-<wi-id>/
```

The release and spine ids come out of
`oss id_parse`'s numeric components (`routing.md` §2); the **spine slug** does
not — nothing persists one (spines store `name`, work items store `title`), so it
is recovered by globbing the spine directory, exactly as the execution lane
recovers it for the spine branch.

```bash
ai_root="$(oss repo_root ai_workspace)"
parts="$(oss id_parse "$wi")" || parts=""
rel_id="r$(printf '%s\n' "$parts" | awk '{print $2}')"
spine_id="$rel_id.s$(printf '%s\n' "$parts" | awk '{print $3}')"

matches="$(find "$ai_root/docs/specs/$rel_id" -maxdepth 1 -type d -name "$spine_id-*" 2>/dev/null)"
n="$(printf '%s\n' "$matches" | grep -c . || true)"
[ "$n" -eq 1 ] || { echo "close: expected exactly one spine dir for $spine_id, found $n - halt"; exit 1; }

spine_dir_abs="$matches"
spine_slug="$(basename "$spine_dir_abs")"; spine_slug="${spine_slug#"$spine_id-"}"
wi_dir="$spine_dir_abs/work-$wi"
spec="$wi_dir/spec.md"
report="$wi_dir/report.md"
```

Three things that look like shortcuts and are not:

- **`oss spine_dir` returns a RELATIVE path** — `docs/specs/<rel>/<spine>-<slug>`
  — and it takes the slug as an argument, so it cannot *find* the directory. Once
  the glob has recovered the slug it re-composes the same relative path, which
  makes it a useful cross-check against `$spine_dir_abs`; it is never the way in.
- **Do not recover the slug from `work_items[].branch`.** That carries the
  *work-item* slug (`work/<wi-id>-<slug>`). Feeding it to a spine path builds a
  directory name that has never existed.
- **`$n` must be exactly 1.** Zero means the spine was never planned here; two
  means a rename left a stale directory, and `head -1` would pick one at random.

### Both routes end the same way

```bash
[ -f "$spec" ] || { echo "close: no spec.md for $wi at $spec - halt"; exit 1; }
```

**A missing or wrong spec path is a halt, named.** `oss verify_acs` returns rc 2
on a spec it cannot find, and a silently wrong path therefore fails the gate for
the wrong reason — the run reports a verification problem when what it has is a
path problem, and the recovery menu sends someone to fix code that is fine.

Carry `$spec`, `$report` and `$wt` forward as absolute paths. Nothing below
re-derives them, and nothing anywhere in this layer `cd`s (SKILL.md §3).

---

## 2. The gate

Run the three-layer implementation gate per **`references/impl-check.md`**, using
the `$spec`, `$report` and `$wt` resolved above. Never a bare placeholder: a
gate invoked on `<spec path>` runs against a file called `<spec path>`.

Green → step 3. Anything else → step 5.

---

## 3. Prove there is something to commit

The gate ran against the **working tree**; the commit runs against the **index**,
and they are not the same thing.

```bash
staged="$(git -C "$wt" diff --cached --name-only)"
[ -n "$staged" ] || { echo "close: gate is green but the index is empty in $wt - halt"; exit 1; }
```

The implementer also reports `stage_status` — `all_staged`, `partial`, or `none`
(`returns.md` §2):

| `stage_status` | Action |
|---|---|
| `all_staged` | proceed, once the index check above passes |
| `partial` | **halt** unless the report explains it in its blockers-and-advisories section |
| `none` | **halt** |

**Never `git add` on the implementer's behalf.** Staging is its job; a silent
re-stage hides the discrepancy and commits whatever the worktree happens to hold,
including files the gate never saw.

---

## 4. On green — commit, then merge

The commit boundary is the orchestrator's: the implementer stages, this layer
commits. The merge is what actually moves the work onto the spine.

```bash
canonical="$(oss repo_root canonical)"

# The merge target comes from STATE, written by the execution lane.
wi_branch="$(oss get ".work_items[] | select(.id==\"$wi\") | .branch")"
[ -n "$wi_branch" ] && [ "$wi_branch" != "null" ] \
  || { echo "close: no recorded branch for $wi - halt"; exit 1; }

# The spine branch: in the round flow it is already in scope; standalone,
# recompose it from the slug step 1 recovered.
spine_branch="$(oss branch_name "$spine_id" "$spine_slug")"
head_branch="$(git -C "$canonical" rev-parse --abbrev-ref HEAD)"
[ "$head_branch" = "$spine_branch" ] \
  || { echo "close: canonical is on '$head_branch', not '$spine_branch' - halt"; exit 1; }

git -C "$wt" commit -m "<message>"
wi_sha="$(git -C "$wt" rev-parse HEAD)"

git -C "$canonical" merge --no-ff "$wi_branch" -m "merge $wi" || { echo "close: merge conflict - halt"; exit 1; }
git -C "$canonical" merge-base --is-ancestor "$wi_sha" HEAD \
  || { echo "close: merge reported success but $wi_sha is not reachable from HEAD - halt"; exit 1; }

oss work_item_status "$wi" complete
```

**Read the branch from state; never re-derive it from a slug.** This layer is
invoked with an id only and derives its scope from the id's shape — it has no
work-item slug, and none is persisted. The execution lane writes the branch it
actually created into `work_items[].branch` precisely so this step can read it
back. `oss work_item_branch "$wi" "$slug"` needs a `$slug` that does not exist
here; it is the id grammar's name generator, not a lookup.

**Verify the merge target before merging.** `git merge` lands on whatever
canonical has checked out. The execution lane parks canonical on the spine branch
for the whole spine; if `rev-parse --abbrev-ref HEAD` says anything else, **halt**
— a merge onto the wrong branch **succeeds silently at rc 0**, the work never
reaches the spine, and the first thing that notices is a cumulative demo
measuring a tree assembled by accident.

**Status is set last, after the merge is verified landed.** Spine close reads
`complete` as "this item's work is on the spine branch" — it is the only signal
the status enum can carry (`planned|active|complete`). Setting it before the
merge means a conflict halt leaves state asserting a merge that never happened,
and the next spine close believes it.

**A merge conflict halts.** Surface the conflicted paths verbatim and stop. Never
auto-resolve, never `--abort` on the user's behalf, and never `-X` a strategy
option to make it go away. If the operator says *resolve it*, the discipline is
`merge-conflict-resolution.md` — hunk by hunk, by each side's recorded intent.
Resuming after the human resolves means finishing
*this* step — the merge and its reachability check, then the status — not
re-running the layer: the commit already landed on the work-item branch, so a
re-run halts at step 3 with an empty index and reports the wrong problem.

**This merge is not optional bookkeeping.** Without it the commits live only on a
branch that spine close cannot delete — `oss worktree_remove` refuses an unmerged
branch (rc 8) — so the round halts at cleanup, *after* the cumulative demo has
already reported green against a canonical tree that never received the work.

---

## 5. On any failure — halt

Terminal, at every layer. No later step runs, no status is written, nothing is
recorded as closed.

1. Surface the errors with their **source tags** — `[AC]`,
   `[report cross-check]`, `[rule]` (`impl-check.md`).
2. Present the **recovery menu**.
3. **Stop. No auto-select.** The user picks.

The disposition-triage policy that auto-applies spec-aligned recommendations
(SKILL.md §4) governs the *disposition rows* at spine close. It does not reach
here: a failed gate is a human decision, and the menu's options have different
costs and different blast radii.

---

## 6. Worktree cleanup does not happen here

It happens at **spine close, as the last step**, and the reason is the branch —
not the report.

`oss worktree_remove` runs `git branch -d` and **refuses an unmerged branch at
rc 8**. Cleanup can therefore only succeed after step 4's merge has landed;
running it here, before the merge, converts a recoverable state into a halt and
leaves the work reachable only from a branch the ceremony has already tried to
delete.

(`report.md` is *not* in the worktree — it lives next to `spec.md` in the work
item's docs directory under the ai-workspace, which worktree removal never
touches. The harvest reads it from there, and its ordering constraint is its own.)
