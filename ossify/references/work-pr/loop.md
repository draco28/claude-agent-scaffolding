# Working a pull request — the review-fix-merge loop

Drive one PR to mergeable: fetch every reviewer finding, give each a recorded
disposition, drive the fixes yourself, re-review on the new head, defer the
non-blocking leftovers as tracked issues, and merge only on the operator's
explicit ack. The loop is judgment; the shell is only for mechanical `git`/`gh`
facts. Nothing here needs a manifest, a worktree, or any ossify state — the
lane works on any repository `gh` can reach.

## 1. Preflight — resolve the target, stop early, stop loudly

- **The repo:** the one you are in, unless `--repo-root DIR` says otherwise —
  and with `--repo-root`, **every** `git`/`gh` command below runs against that
  directory (run them from it, or `git -C <dir>` / `gh --repo <owner>/<repo>`):
  a bare `gh` in the invoking repo resolves the PR number against the wrong
  repository, and if both repos have that number, even the head verification
  checks the wrong one against itself. Not inside a git repo and no flag → say
  so and stop; this is the one gap judgment cannot bridge.
- **The PR exists and is OPEN:** `gh pr view <PR> --json state,isDraft`
  before anything else; a typo'd number fails here, not three steps in — and
  a closed or merged PR stops here too, because `gh pr view` succeeds on
  those and the loop would otherwise edit and push a branch nothing can
  merge. A draft is surfaced (workable, not mergeable) rather than stopped.
- **Clean tree:** a dirty target repo means someone's work is in the blast
  radius of your fixes — say what is dirty and stop until the operator
  commits, stashes, or cleans. Never stash on their behalf.
- **The head you will edit:** check out the PR branch (`gh pr checkout`) and
  confirm the branch and commit you landed on are the PR's own head (`gh pr
  view --json headRefName,headRefOid` against `git rev-parse`). Editing the
  wrong branch writes fixes nowhere the PR can see; a mismatch is a stop, said
  plainly.

Each stop names what failed and what would unblock it. None of them is a
refusal to work the PR — they are the order that keeps fixes attributable.

## 2. Fetch the findings — both signals, always

Reviewers leave findings in two places, and each alone misses what the other
carries:

- the **review + conversation stream** — review summaries, CI rollup, top-level
  comments (`gh pr view --comments`, `gh pr checks`, review listings — the
  `--comments` flag matters: the bare view omits top-level comments, and a
  finding that lives only there would silently miss the ledger);
- the **inline line-level comments** — where review bots put nearly everything
  (`gh api --paginate repos/{owner}/{repo}/pulls/{n}/comments`, or the
  equivalent — paginated, because a second page of findings that never loads
  is a ledger hole wearing a clean look).

Read both, then build the **disposition ledger**: one line per finding, every
line ending in exactly one of `fixed in <sha>` / `deferred → #N` /
`invalid — <why>`. The ledger is the loop's working memory and its terminus
report; a finding missing from it was never dispositioned.

## 3. The disposition contract

This section is authoritative for this lane. (scaffold-dev's gate keeps its
own copy of the same rules; what another stack does with them is that stack's
contract.)

- **P1 / blocking** — correctness, security, data loss, a broken public
  contract: **must be fixed before merge.** Never ack-to-merge, never
  deferrable, no matter which review round surfaced it or who asks.
- **Non-blocking** — fix it or defer it. A deferral is a **tracked issue in
  the target repo** recorded as `deferred → #N`; a silent pass is not a
  disposition. File it with `gh issue create` and enough body that a stranger
  can act on it without this conversation.
- **Invalid** — a finding can be wrong. Refuting it is a disposition, but the
  refutation is evidence-shaped (walked against the tree, quoted), never
  "disagree".
- **You drive the fix yourself:** edit, commit, push. Record `fixed in <sha>`
  only when the fix is on the PR head the reviewer can see.
- **Staleness:** a fix commit landing after a review makes that verdict stale.
  Re-fetch (§2) and re-review on the **new** head; the old verdict does not
  carry forward.
- **Reviewer completeness:** green CI is not proof a reviewer ran; a skipped
  reviewer is not approval; a queued reviewer is waited for or surfaced —
  never assumed. Confirm each expected reviewer actually left something on the
  current head. Do not busy-wait a queued reviewer: say it is pending and let
  the operator decide.

Loop §2→§3 until every finding is dispositioned, every P1 is fixed, and the
reviewer signal is complete on the current head.

## 4. Terminus — surface everything, then ask

In one place, give the operator:

- the full disposition ledger,
- CI state and per-reviewer status (ran / skipped / pending / stale),
- a mergeability verdict: clean to merge, or exactly what still blocks —
  **grounded in GitHub's own answer, fetched here** (`gh pr view --json
  mergeable,mergeStateStatus,isDraft`): a draft, a conflict with the base, a
  branch the ruleset calls BEHIND, or a blocked review state each falsifies
  "clean to merge" however green CI and the reviewers look, and discovering
  that only after the operator acks is the loop soliciting an impossible
  merge.

Then **ask**: merge, wait, or leave open. Merge only on explicit ack, and the
ack covers **the head the ledger describes**: pass the reviewed OID
(`gh pr merge --match-head-commit <oid>`, with the repo's merge convention —
ask if the convention is not evident from the repo's history or settings), so
a head that moved between the report and the answer refuses and re-enters §2
instead of merging unreviewed commits. The pin guards **commits, not
verdicts** — a blocking review or a red CI rerun can land on the *same* head
while the operator considers the ask — so after the ack and immediately
before merging, re-fetch both finding signals and the checks once more;
anything newly blocking re-enters §2 instead of merging. On a branch governed
by a merge queue, required checks must be **finished** before accepting the
ack — with checks still pending, `gh pr merge` does not merge, it *enables
auto-merge*, and this lane never auto-merges. Never merge over an unresolved
P1, a stale or incomplete reviewer signal, or a red gate. If the operator leaves it open,
report the PR URL and stop — the loop does not poll.

## Anti-patterns

- **Growing the loop into tooling.** No wrapper scripts, no state files — the
  ledger lives in the conversation and the terminus report.
- **Ack-to-merging a P1**, or letting a "just merge it" instruction reclassify
  a correctness finding as style.
- **Silent-passing a non-blocking finding** — untracked is undispositioned.
- **Trusting a pre-fix verdict on a post-fix head.**
- **Auto-merging.** The merge is always the operator's explicit call.
