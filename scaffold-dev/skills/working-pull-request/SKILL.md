---
name: working-pull-request
description: "Drive an arbitrary pull request through the full review-fix-merge loop — fetch reviewer findings, disposition each, drive the fixes, re-review on the new head, defer leftovers, and merge on explicit ack. Slice-decoupled and manifest-free: works on any gh repo. Use when the user says /work-pr, 'work this PR', 'drive PR #N to merge', 'review and fix this PR', 'run the pre-merge gate on PR N', 'get this PR mergeable', or hands you a PR number/URL to take to merge. NOT for slice/sprint close — closing-vertical-slice and writing-sprint-retrospective own those PR paths."
---

# working-pull-request

Drive a single pull request to mergeable: fetch every reviewer finding, give each a
recorded disposition, drive the fixes yourself, re-review on the new head, defer the
non-blocking leftovers, and merge only on the user's explicit ack.

This is the standalone, slice-decoupled form of the same pre-merge gate that
`closing-vertical-slice` and `writing-sprint-retrospective` run at slice/sprint close.
It reuses the **single source of truth** for the disposition contract —
`git-workflow.md` §"Agent-driven pre-merge gate" (in
`planning-vertical-slice/references/`). That file is authoritative; this skill applies
it to an arbitrary PR and adds the standalone preflight + fix-driving around it.

**The invoking agent does the whole loop.** Whichever agent runs this skill — Claude
Code or Codex — performs every step itself: fetch, disposition, fix, re-review, merge.
There is no cross-agent hand-off. (You choose the agent at invocation time; run it in
Codex when you want the fix-heavy back-and-forth off your main session's context.)

**Skill-driven, not a script.** The loop is your judgment. Determinism stays only in the
mechanical `sd`/`gh` primitives (`sd pr_state`, `sd pr_review_comments`, `sd pr_merge`);
never grow the gate into bash reviewer semantics.

## Boundary (what this skill does NOT do)
- Does NOT require a workspace-init manifest, a slice, a worktree, or a roadmap.
- Does NOT compose a slice/sprint PR body, invoke architect-critic, or touch the
  memory-bank — those are slice-ceremony concerns owned by the close skills.
- Does NOT auto-merge. It stops at the merge ask and merges only on explicit ack.

## 1. When to use
Trigger on `/work-pr <PR>`, "work this PR", "drive PR #N to merge", "review and fix this
PR", "run the pre-merge gate on PR N", "get this PR mergeable", or when the user hands
you a PR number/URL to take to merge.

Do NOT auto-invoke at slice or sprint close — `closing-vertical-slice` §10a and
`writing-sprint-retrospective` §8a own those PR gates (they call the same `git-workflow.md`
contract with the slice/sprint PR body they compose).

## 2. Preflight (resolve the target, refuse fast)
From `$SCAFFOLD_DEV_ARGS` (or the conversation) you have a PR ref (number or URL) and an
optional `--repo-root DIR`. Resolve the repo to act on — **manifest-free**: the repo you
are in, unless `--repo-root` overrides.

```bash
REPO_ROOT=""
set -- ${SCAFFOLD_DEV_ARGS:-}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      [[ $# -ge 2 && -n "$2" ]] || { echo "--repo-root requires DIR" >&2; exit 1; }
      REPO_ROOT="$2"; shift 2 ;;
    --repo-root=*)
      REPO_ROOT="${1#*=}"
      [[ -n "$REPO_ROOT" ]] || { echo "--repo-root requires DIR" >&2; exit 1; }
      shift ;;
    *) shift ;;
  esac
done
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
    echo "not inside a git repository; cd into the PR's repo or pass --repo-root DIR" >&2; exit 1; }
fi
sd remote_check --repo-root "$REPO_ROOT" || exit 1   # target has 'origin' + authed gh (generic, NOT canonical)
```

Confirm the PR exists before doing anything else:

```bash
sd pr_state "<PR>" --repo-root "$REPO_ROOT" >/dev/null || { echo "PR <PR> not found in $REPO_ROOT" >&2; exit 1; }
```

Refuse to start the fix loop from a dirty target repo, then check out and verify the PR
head branch before any edits:

```bash
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
  echo "target repo has local changes; commit/stash/clean before /work-pr so fixes stay isolated" >&2
  exit 1
fi
(cd "$REPO_ROOT" && gh pr checkout "<PR>" --force) || { echo "failed to check out PR <PR>" >&2; exit 1; }
head_branch="$(cd "$REPO_ROOT" && gh pr view "<PR>" --json headRefName --jq .headRefName)"
head_oid="$(cd "$REPO_ROOT" && gh pr view "<PR>" --json headRefOid --jq .headRefOid)"
current_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
current_oid="$(git -C "$REPO_ROOT" rev-parse HEAD)"
[[ "$current_branch" == "$head_branch" ]] || {
  echo "checked out $current_branch, expected PR head $head_branch; refusing to edit" >&2
  exit 1
}
[[ "$current_oid" == "$head_oid" ]] || {
  echo "checked out $current_oid, expected PR head commit $head_oid; refusing to edit" >&2
  exit 1
}
```

If any check fails, surface the actionable message and STOP. There is **no
`manifest_require`** here — that is what makes `/work-pr` work on any gh repo.

Pass `--repo-root "$REPO_ROOT"` to EVERY `sd pr_*` / `sd issue_*` call below — it routes
the mechanical gh wrappers at the target repo without needing a manifest.

## 3. Fetch the findings
Read BOTH signals — each alone misses findings the other carries:

```bash
sd pr_state "<PR>" --repo-root "$REPO_ROOT"            # CI rollup + review summaries + conversation + commits
sd pr_review_comments "<PR>" --repo-root "$REPO_ROOT"  # INLINE line-level review comments (bots leave findings here)
```

Reason over the JSON and build a **disposition ledger** — one line per finding.

## 4. The disposition + fix loop (apply git-workflow.md §7 — binding judgment)
Apply the authoritative contract in `git-workflow.md` §"Agent-driven pre-merge gate".
Its load-bearing rules, as the operational loop you run here (read §7 for the full
statement — keep this in step with it, do not let it drift into a divergent spec):

- **P1/blocking** (correctness, security, data loss, broken contract) → MUST be fixed
  before merge. Never ack-to-merge; never deferrable.
- **Non-blocking** → fix OR defer. Deferral is a tracked issue recorded as
  `deferred → #N`, never a silent pass (see §5).
- **You drive the fix yourself**: edit the code, commit, push. Record `fixed in <sha>`
  only once the reviewer signal is current on that head.
- **Staleness / re-review**: a fix commit landing after a review makes that verdict
  stale — re-fetch (§3) and re-review on the NEW head; the old verdict is not still valid.
- **Reviewer-completeness**: a green check is not proof a reviewer ran; a skipped
  reviewer is not approval; a queued/in-progress reviewer must be waited for. Confirm
  each expected reviewer actually left a review/comment (e.g. CodeRabbit may skip a
  non-default base), not just that CI is green.

Loop §3→§4 until every finding has a disposition, every P1 is fixed, and the reviewer
signal on the current head is complete. Do NOT busy-wait/poll a queued reviewer — if one
is still running, surface that and let the user decide to wait or stop.

## 5. Defer the non-blocking leftovers
For each non-blocking finding the user accepts rather than fixes, record tracked debt so
it is never a silent pass. Pick exactly ONE owner for issue creation:

- If `REPO_ROOT` is the paired workspace's canonical repo, invoke `deferring-work-item`
  (`/defer`) and let it own both the GitHub issue and the lean `[TD]` index line.
- If `REPO_ROOT` is the paired workspace's configured tooling repo, invoke
  `deferring-work-item` with `--tooling`; it keeps the issue ref repo-qualified.
- Otherwise, including manifest-less repos and explicit `--repo-root` targets outside
  the paired workspace, file directly in the target repo:

```bash
# write the body to a temp file, then file it in the TARGET repo:
sd issue_create "<title>" "<body-file>" --repo-root "$REPO_ROOT" --label tech-debt
```

Record `deferred → #N` in the ledger. Do NOT create an issue directly and then invoke
`/defer`; that duplicates the issue-filing owner. For direct target-repo filing, the
tracked issue IS the record — there is no safe memory-bank pointer to append for an
unrelated repo, so stop at the issue. Never block recording the debt on label setup
(`sd label_ensure <label> "$REPO_ROOT"` is the offered, idempotent fallback if the repo
lacks the label).

## 6. Terminus — surface, then merge on ack
Surface to the user, in one place:
- the disposition ledger (every finding → `fixed in <sha>` / `deferred → #N`),
- CI state + per-reviewer status (ran / skipped / pending / stale),
- a mergeability verdict (clean to merge, or exactly what is still blocking).

Then ASK: merge, wait, or leave open. Merge ONLY on explicit ack:

```bash
sd pr_merge "<PR>" --repo-root "$REPO_ROOT" [--squash|--rebase|--merge] [--auto]
```

Never auto-merge over an unresolved P1, an incomplete/stale reviewer signal, or a red
gate. If the user leaves the PR open for async CI/review, report the PR URL and STOP — do
not busy-wait.

## Anti-patterns
- **No determinism in the loop** — disposition + completeness are your judgment; bash is
  only for the mechanical `sd`/`gh` facts.
- **Never ack-to-merge a P1**, and **never silent-pass a non-blocking finding** (file it).
- **Never auto-merge** — the merge is always an explicit, user-acked step.
- **No slice/worktree/manifest assumptions** — this is PR-generic; do not require a
  pairing manifest or invoke architect-critic.
- **Do not fork the gate contract** — the disposition rules are authoritative once in
  `git-workflow.md` §7; this skill applies them, it must not drift into a second spec.
