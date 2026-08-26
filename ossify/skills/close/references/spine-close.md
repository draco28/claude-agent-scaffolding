# Spine close — the middle layer

Depth for SKILL.md §5. Eleven steps in **binding order**: each step's output is
the next one's input, and the order is the whole content of the ceremony — the
demo measures a tree the merge assembled, the touch check reads the merge's own
diff, cleanup deletes branches the merge made deletable.

This layer is reached as `/close <spine-id>`, deliberately, once. The execution
lane never routes here: it hands work items to §4 one at a time and stops at the
round barrier (`work-item/references/round-orchestration.md` §7).

---

## 1. The class-scoped ceremony (spec §6.1)

| Row | Bone spine | Flesh spine |
|---|---|---|
| impl-check per work item | **core** (already run, per item, at §4) | **core** |
| Cumulative product demo | **core** | **core** |
| Bone-touch check | **core** | **core**, and a hit reclassifies the spine mid-flight |
| Memory-bank harvest | **core** | **core** |
| Handoff / state updates | **core** | **core** |
| Worktree + branch cleanup (only after harvest) | **core** | **core** |
| the adversarial audit (`challenge`) | full audit at close depth, external adversary per the ladder | one light host-only pass |
| Retrospective | full section set | lean section set |
| Grill gates (planning + fix-up replans) | offered | skipped |
| ADR check (a bone added or changed requires an ADR) | required | carried by the bone-touch row above |

**Core rows are never skippable in either class** (spec §6.1). Bone and flesh
differ in the **depth** of the optional rows — critic depth, retro length,
whether a grill gate is offered — never in whether a core row runs. That is the
structural "nothing forgotten" guarantee, and it is why this file is a fixed
checklist rather than a judgment call.

**Two of those rows have no step in the checklist below, and saying so beats a
row that reads as executed.** *Grill gates* are planning-time offers owned by
`plan-spine`; nothing here re-offers one, and a close is the wrong moment to. The
standalone *ADR check* row is **not shipped in this release**: on the bone path
the ADR obligation currently rides on step 5's reclassification reason and step
7's critic pass, which is weaker than its own checklist row. Recorded here as a
known gap rather than papered over.

---

## 2. Step 1 — every work item `complete`, or refuse and name the offender

`$spine_id` is the id `/close` was invoked with, carried from §2's routing.

```bash
open="$(oss get "[.work_items[] | select(.spine==\"$spine_id\" and .status != \"complete\") | .id] | join(\", \")")"
[ -z "$open" ] \
  || { echo "close: $spine_id has work items that are not complete: $open - halt"; exit 1; }
```

**Test the output, never the rc.** `oss get` is `jq -r` without `-e`: a `select`
matching nothing exits **0** with an empty string, so `oss get … || halt` never
fires and a spine with three unfinished items closes clean (`routing.md` §4).

`complete` means "this item's work is on the spine branch" — §4 sets it *last*,
after its merge is verified landed, precisely so this step can read it that way.

---

## 3. Step 2 — switch each hosting repo back to its base branch, then merge

**Read `references/code-review.md` before this merge.** It is the last moment the
spine's accumulated diff is reviewable as one thing, and the only reader in the
ceremony that judges *craft and fidelity* — impl-check verified the ACs pass and
that no **documented** pattern is violated; nothing has yet asked whether the code
is good, or whether it is the code the spine set out to write. Advisory: it
produces findings and a decision per finding, not a halt.

**This step repeats once per hosting repo** — the distinct `target_repo` values
across the spine's work items, the same set `round-orchestration.md` §2 looped to
cut the branch in before round 1. A spine confined to one repo loops once; a
cross-repo spine merges into every repo it touched, and none of them is optional
— a hosting repo left unmerged is work the spine did that never reached its base
branch, however green the repos that DID land make the close look.

The two facts this step needs are not in state and are recovered, not guessed:

- **The spine slug**, once, from the spine directory's name, exactly as the
  execution lane recovers it (`work-item/references/round-orchestration.md` §2).
  Nothing persists a slug, and it is the same slug in every repo.
- **`base_branch`, once per hosting repo.** The primary source is that repo's own
  handoffs' `## 2. Spine context` `base_branch:` lines
  (`work-item/references/handoff-contract.md` §2) — the lane records there the
  branch *that repo* was ACTUALLY on when it cut the spine branch — with
  `SPINE.md`'s spine-context **base-branch table**
  (`plan-spine/references/spec-authoring.md` §1), where `plan-spine` authored
  one planned base **per hosting repo** at planning time, as the cross-check —
  read that repo's row, never a single spine-wide value. **If the two disagree for a repo, halt and name both, and the
  repo** — the lane cuts from HEAD (issue 133), so a planned base that never
  matched the cut base is exactly the wrong-merge hazard, repo by repo. **If
  either cannot be resolved for a repo, halt** — guessing the default branch
  merges that repo's share of the spine into the wrong line of development, and
  every downstream step then reports green.

```bash
# $spine_slug is NOT ambient — nothing in state holds it. Recover it from the
# spine directory's name with the ambiguity guard, exactly as `harvest.md` §2
# does in this same skill, and hoist it once for the whole ceremony:
#   spine_dir="$(…the glob…)"; spine_slug="${spine_dir##*/}"; spine_slug="${spine_slug#$spine_id-}"
# Using it unset under `set -u` aborts the close here, before any of the guards
# below can report anything.

# DERIVE the spine branch; never read it off HEAD. HEAD is durable git state
# that a session boundary, a hotfix or a halted close can move. One value for
# every hosting repo - the branch name carries no repo in it.
spine_branch="$(oss branch_name "$spine_id" "$spine_slug")"

# $repo_base_branches is NOT ambient either: one "<repo>:<base_branch>" pair per
# line, one line per hosting repo, recovered by the cross-check above and
# hoisted once, same as the slug. Branch names cannot contain ":" (git refuses
# it), so splitting each line on the first colon is unambiguous.

merge_shas=""
while IFS= read -r repo; do
  [ -n "$repo" ] || continue

  repo_root="$(oss repo_root "$repo")" \
    || { echo "close: $spine_id names undeclared repo '$repo' - halt"; exit 1; }
  base_branch="$(printf '%s\n' "$repo_base_branches" | awk -F: -v r="$repo" '$1==r{print $2; exit}')"

  [ -n "$base_branch" ] \
    || { echo "close: no base_branch recorded for $spine_id in $repo - halt"; exit 1; }
  pre="$(git -C "$repo_root" rev-parse "$spine_branch")" \
    || { echo "close: cannot resolve '$spine_branch' in $repo - halt"; exit 1; }

  # ALREADY LANDED? This is the resume arm, and it lives inside the merge loop
  # rather than in a probe of its own: a separate probe can only report, and
  # step 2 would still halt on its own HEAD assertion the moment it ran.
  # Against $base_branch, NOT HEAD. On a first close HEAD *is* $spine_branch, so
  # the tip is trivially its own ancestor and this arm would fire every time,
  # skipping the merge and leaving the repo parked on the spine branch.
  if git -C "$repo_root" merge-base --is-ancestor "$pre" "$base_branch" 2>/dev/null; then
    # Recover this repo's merge commit from history - the commit on this branch
    # whose SECOND parent is the spine tip. $merge_shas is a shell variable that
    # does not outlive the invocation, and §6's touch check needs every pair, so
    # a resumed close has to reconstruct what the first one recorded.
    merges="$(git -C "$repo_root" log --format='%H %P' --merges "$base_branch")"
    merge_sha="$(printf '%s\n' "$merges" \
      | awk -v t="$pre" 'found=="" { for (i = 3; i <= NF; i++) if ($i == t) found = $1 } END { print found }')"
    [ -n "$merge_sha" ] \
      || { echo "close: $base_branch in $repo already contains $spine_branch but no merge commit has it as a second parent - a fast-forward or a rebase landed it, and §6 cannot compute this repo's first-parent diff - halt"; exit 1; }
    git -C "$repo_root" checkout -q "$base_branch" \
      || { echo "close: $repo already landed but cannot check out '$base_branch' - halt"; exit 1; }
    echo "close: $repo already landed at $merge_sha - not re-merging"
  else
    head_branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)"
    [ "$head_branch" = "$spine_branch" ] \
      || { echo "close: $repo is on '$head_branch', not '$spine_branch', and does not contain $spine_branch - halt"; exit 1; }

    git -C "$repo_root" checkout -q "$base_branch" \
      || { echo "close: cannot check out base branch '$base_branch' in $repo - halt"; exit 1; }
    now_on="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)"
    [ "$now_on" = "$base_branch" ] \
      || { echo "close: switch-back left $repo on '$now_on', not '$base_branch' - halt"; exit 1; }

    git -C "$repo_root" merge --no-ff "$spine_branch" -m "merge $spine_id" \
      || { echo "close: merge conflict in $repo - halt"; exit 1; }
    git -C "$repo_root" merge-base --is-ancestor "$pre" HEAD \
      || { echo "close: merge reported success but $pre is not reachable from HEAD in $repo - halt"; exit 1; }
    merge_sha="$(git -C "$repo_root" rev-parse HEAD)"
  fi
  merge_shas="$merge_shas
$repo:$merge_sha"
done < <(oss get ".work_items[] | select(.spine==\"$spine_id\") | .target_repo" | sort -u)
```

**Four guards per repo, and every one of them exists because the failure it
catches is rc 0 all the way to a green close.**

- **Derive the spine branch and assert HEAD matches it, in this repo.** Reading
  it off HEAD instead makes the switch-back a no-op and the merge "Already up to
  date" in that repo — the spine's share of work there never lands, and steps
  3-11 still run green against a tree that repo never reached. §4 ships the same
  assertion for the same reason (`work-item-close.md` §4): *a merge onto the
  wrong branch succeeds silently at rc 0.*
- **Require this repo's `base_branch` to be non-empty, and check the checkout's
  rc.** An empty one makes `git checkout -q ""` fail at rc 128; unguarded, the
  ceremony continues with that repo still on the spine branch and merges it into
  itself.
- **Assert HEAD actually moved, in this repo.** This is a separate guard from
  the rc check and catches what the rc check cannot: `base_branch` resolving to
  a **tracked file name** rather than a branch. `git checkout -q <tracked-file>`
  restores that file and exits **0** without moving HEAD, so the rc guard passes
  and the self-merge runs anyway.
- **Check reachability after the merge, in this repo**, which catches a merge
  that reports success without landing the tip. It cannot replace the branch
  assertion: on a self-merge `$pre` is trivially its own ancestor, so
  `--is-ancestor` returns 0. Both legs, always, every repo.

**A merge conflict halts with rc-8 semantics — in whichever repo it happens.**
Surface the conflicted paths verbatim, leave that repo's merge in progress for
the human, and run **no** later step in any repo, including one this loop has
not reached yet. Never `--abort` on the user's behalf, never auto-resolve,
never `-X` a strategy option. If the operator says *resolve it*, the discipline
is `merge-conflict-resolution.md` — hunk by hunk, by each side's recorded
intent. Resuming means finishing *this* repo's merge and continuing the loop
from there, not re-running the layer or restarting a repo that already landed.

**Resuming a halted spine close.** A halt at steps 4-11 leaves step 2's merge
already landed in **every** hosting repo. A halt **inside** step 2 is the other
case a cross-repo spine introduces: the loop may have landed the merge in one or
two hosting repos before a later one failed, so "already landed" is a per-repo
question now, not one yes/no for the whole step.

**Step 2's loop above is itself the resume path — there is no separate probe.**
An earlier draft had one: a loop that tested containment and printed
`already landed` / `NOT landed` per repo, next to a step 2 that still asserted
`HEAD == $spine_branch`. Nothing consumed the probe's result, so a resumed close
read a correct report and then halted in the very next step on a repo the report
had just called finished. The containment test now lives in the merge loop and
decides what that iteration does, which also means `$merge_shas` comes out
populated for **every** repo — reconstructed for the ones that already landed —
rather than only for the ones this invocation happened to merge.

Re-invoke `/close <spine-id>` and let step 2 run. It re-merges only the repos
that have not landed, and never re-merges one that has (that repeats the merge
into a tree already containing it — at best a no-op, at worst a second, spurious
merge commit). Step 2 is complete only once **every** hosting repo is landed;
then continue at the first unfinished step, saying which. Restart properties,
one line each: the demo (§5) re-runs whole; the touch check (§6) re-runs from
`$merge_shas`, which step 2 has just rebuilt; the critic (§7) re-runs; the retro
(§8) is **amended, never re-authored** (the same rule `release-close.md` §8
states); the harvest is idempotent by `harvest.md` §7's skip-identical rule, and
cleanup is idempotent (both §9).

The one resume this cannot serve is a spine whose branch was already deleted by
§9's cleanup — then the tip is unresolvable and step 2 halts naming it. That is
a completed close, not a halted one.

Issue #133 is the execution-lane counterpart, not a substitute for
this.

---

## 4. Step 3 — apply the pending demo amendments

```bash
oss ledger_apply_pending "$spine_id"
```

`supersede` and `retire` are **planning** verbs: they record intent and leave the
line live, so a sibling spine closing first still runs the flow. This is where
the intent becomes real, and it runs **after the merge and before the demo** so
the demo measures the amended line set against a product where the replaced flow
really is gone. Applying it before the merge measures a promise; applying it
after the demo measures the wrong set.

An unknown spine id is rc 7 with a message, not a silent no-op.

---

## 5. Step 4 — the cumulative demo

`oss demo_run` for every active `auto:` line, then walk
`oss demo_user_lines "$spine_id"` — **this spine's own `user:` lines only** — with
the human. Full detail, the §6.1-vs-§6.2 scoping, quarantine handling and the
ledger's wall-clock budget in **`references/cumulative-demo.md`**.

**Halt on the first failure, and the halt is terminal**: no touch check, no
critic, no retro, no harvest, no cleanup, no status write. A demo failure is the
product telling you the spine is not closeable; recording it closed anyway is how
the cumulative ledger stops meaning anything.

---

## 6. Step 5 — the changed-path list, then the touch check

**Compute the path list first — it is every hosting repo's own first-parent
diff, concatenated into ONE call.** §3 merges once per hosting repo, and each
merge is a separate commit in a separate repository — there is no single
`$merge_sha` any more, so this step reads `$merge_shas`, the `repo:sha` pairs §3
recorded at each repo's own merge step, and computes each repo's diff the exact
same way §3's single-repo predecessor did: the merge commit against its **first
parent**.

```bash
# Collect into a FILE, and let each repo's failure halt on the spot. The earlier
# form nested the per-repo loop in a process substitution: the outer `while`
# consumed only its stdout and never saw its exit status, so a repo whose
# `oss repo_root` or `git diff` failed AFTER another repo had already emitted
# paths contributed nothing and said nothing. `$#` was then non-zero, the guard
# below passed, and `touch_check` ran over a partial list - which is how a bone
# or risk-gate hit in the failing repo goes unreported and the close continues
# looking clean. A partial list is the INCONCLUSIVE case, not the clean one.
paths="$(mktemp)"; : > "$paths"
while IFS=: read -r repo sha; do
  [ -n "$repo" ] || continue
  root="$(oss repo_root "$repo")" \
    || { echo "close: \$merge_shas names undeclared repo '$repo' - the changed-path list would be INCOMPLETE - halt"; exit 1; }
  git -C "$root" diff --name-only "$sha^1" "$sha" >> "$paths" \
    || { echo "close: cannot diff $sha against its first parent in $repo - the changed-path list would be INCOMPLETE - halt"; exit 1; }
done <<EOF
$merge_shas
EOF

set --
while IFS= read -r p; do
  [ -n "$p" ] || continue
  set -- "$@" "$p"
done < "$paths"

[ "$#" -gt 0 ] \
  || { echo "close: the merge changed no paths in any hosting repo - the touch check is INCONCLUSIVE, not clean - halt"; exit 1; }

tc=0; touch_hits="$(oss touch_check "$@")" || tc=$?
case "$tc" in
  0) printf '%s\n' "$touch_hits" ;;          # HIT - §7 and §8 act on these lines
  1) echo "touch check: clean" ;;            # clean - change nothing, record nothing
  *) echo "close: touch_check could not run (rc $tc) - INCONCLUSIVE, not clean - halt"; exit 1 ;;
esac
```

**One `oss touch_check` call over the union of every repo's paths, never one call
per repo.** A bone or a risk gate is a project-wide surface, not a per-repo one,
and `touch_check`'s own rc contract (0 = HIT, 1 = clean, 2 = could-not-check) has
no way to combine three separate verdicts into one close decision. Calling it
once per repo and OR-ing the results by hand is the associative-array trap in a
different shape: it works until someone reads it back the wrong way. Build the
full path list first, across every repo, and let the one call judge all of it —
the same discipline §3's loop already established for the merge itself.

**The inner loop, never a bash associative array.** `$merge_shas` is a flat
`repo:sha` list, one pair per line — exactly what §3 built, one line appended
per repo at that repo's own merge. A single `while IFS=: read -r repo sha` loop
splits each line on its first colon (git ref names cannot contain `:`, so the
split is unambiguous) and calls `oss repo_root` fresh for each — there is no
`$merge_sha_by_repo[$repo]`-style lookup anywhere in this file, because bash 3.2
has no associative arrays to hold one. The outer `while IFS= read -r p` loop is
unchanged from the single-repo form: it still collects one path per line into
`"$@"`, it merely now reads from a pipeline that visits every hosting repo
instead of one `git diff` on a single `$canonical`.

**`$merge_shas`'s pairs, not `$base_branch..$spine_branch`, and per repo for the
same reason the single-repo form gave.** The range form looks right and is wrong
in both directions, in every repo it is tried in: after the merge, `git diff
A..B` is just `git diff A B` — a comparison of two *trees*, not a range — and
the base branch's tree now already contains the spine. When the base never
moved, the two trees are identical and that repo's list comes back **empty**.
When the base *did* move, that repo's list names the files the **other** work
changed and omits the spine's own. The first-parent diff is the only form that
answers "what did this merge bring in," per repo, and it is stable whether or
not that repo's base moved.

**Feed one argument per path, still.** `set --` plus `"$@"` does that without
breaking on a path containing a space and without depending on `$IFS` — true of
the aggregate list exactly as it was true of a single repo's. An **array** is
the obvious alternative and is worse here: under `set -u`, expanding an empty
one is a fatal *unbound variable* abort on the bash macOS ships (3.2), so the
empty case (every hosting repo's merge genuinely changed nothing) would die
before reaching the halt that explains it.

**rc 0 = HIT, rc 1 = clean, rc 2 = could-not-check.** Reading that backwards
inverts the judge and reclassifies exactly the wrong spines — the single most
consequential mistake available in this file. **rc 2 is not clean.** It means no
paths were passed, or the registries were unreadable; the state is broken exactly
when degrading to the permissive answer is least acceptable, so it halts. The
empty-list guard above fires first so the two causes get different messages.

Full glob semantics and the path-selection discipline are in
`plan-release/references/bone-touch-judge.md` §3 — the same judge, run here at
the third of spec §6.1's three detection points (release planning, critic pass,
close-time check).

### 6.1 On a bone hit — reclassify mid-flight

```bash
oss class_set "$spine_id" bone "bone-touch at close: <ADR-ref> (<matched surface>)"
```

**Three arguments; the reason is required** and is the audit trail for a class
change made mid-ceremony. Take `<ADR-ref>` from the `bone <adr>` line
`touch_check` just printed — not from memory, not from the spine's plan.

**The reclassification takes effect for every remaining row, including this one.**
Re-read this step on the bone column, then continue forward. **Do not re-run the
touch check**: it will hit again, and a second `class_set` records a `bone`→`bone`
transition that never happened. Nothing above this step is class-scoped — steps
1-4 are core rows identical in both columns — which is why the re-entry is a
re-read and not a rewind.

### 6.2 Step 6 — risk-gate escalation

**Distinguish the two hit kinds by the printed prefix**, never by assuming a hit
is a bone. `touch_check` prints `bone <adr>` for a bone and `risk_gate <name>`
for a gate. A gate hit escalates to the bone path **plus that gate's controls**,
*regardless of class* — harm is orthogonal to reversibility, and a flesh-class
one-liner inside a guarded surface is still a Risk event.

```bash
oss get '.risk_gates[] | select(.name=="<name>") | .controls'
```

Those are the `controls` recorded when the gate was registered. **Walk each one
as a checklist row** — they are required work, not advice. A single path can hit
both a bone and a gate; then both apply.

---

## 7. Step 7 — the adversarial audit, and the depth differs by class

Run ossify's own audit — `challenge` in audit mode. Read
`${CLAUDE_PLUGIN_ROOT}/skills/challenge/references/audit.md` end to end and
follow it. The audit always runs; there is no plugin whose absence skips it,
and nothing here blocks the close on an adversary that is not configured.

**The depth differs by class, and one call cannot serve both:**

- **bone** — close depth. The adversary ladder
  (`challenge/references/adversaries.md`) decides whether an external
  fresh-frame adversary joins; the audit's summary names what ran.
- **flesh** — the light host-only pass: the same reference, shallow depth.

The artifact is the spine's `SPINE.md` under
`oss spine_dir "<release-id>" "<spine-id>" "<slug>"` — the same artifact
`plan-spine` hands the audit (`plan-spine/references/spec-authoring.md` §6).
That verb returns a **relative** path, so prefix it with
`oss repo_root ai_workspace`; the audit wants one absolute path.

The findings come back as **disposition rows**, and this is where spec §6.1's
triage policy applies: spec-aligned recommendations auto-apply, and only
load-bearing escalations reach the user. Record a class-moving disposition with
`oss veto_add "$spine_id" "<finding>" auto-bone|override|escalate "<reason>"`.

---

## 8. Step 8 — the retrospective

Authored against a **fixed section contract**, full for bone and lean for flesh.
Both section sets, verbatim, in **`references/retrospective.md`**. It is the only
copy; do not invent a heading per spine.

---

## 9. Steps 9-11 — harvest, then cleanup, then the state writes

**Step 9 — memory-bank harvest, always before cleanup.** Enumerate this spine's
work items, read each `report.md`'s `## 9. Suggestions for memory bank` and each
per-work-item `handoff.md`, surface the candidates for accept/edit/reject, and
apply the accepted set in **one** pass. There is no `oss` verb for any of it:
the bank is manifest-routed and you perform the appends yourself.

The full ceremony — how the candidates are enumerated, the `[report]`/`[handoff]`
tagging, the entry shape, the two-file allowlist, where the bank is, the append
rules (whole-set validation before a single write; an all-skipped apply is
honest, not a failure to re-run) and where the outcomes are recorded — is in
**`references/harvest.md`** §2 and §5-§8. It is the only copy.

**Step 10 — worktree + branch cleanup, per work item, and only now:**

```bash
oss worktree_remove "$(oss get ".work_items[] | select(.id==\"$wi\") | .target_repo")" "$wi"
```

**Already per repo, because the target is per item.** Walking every work item
in the spine and reading each one's own `target_repo` runs this in whichever
repo that item actually lives in — the same repo §3 merged its branch into and
§4 already closed it from. A spine hosted across two repos removes worktrees
and branches from both, one call per item, with no separate per-repo loop of
its own: the loop is already the walk over work items.

**Cleanup is last because of the branch, not the report** — the full ordering
argument, and the false one it is often confused with, are in `harvest.md` §1.

**Step 11 — state updates:**

```bash
oss spine_status "$spine_id" closed
oss demo_record spine "$spine_id" "<true|false>" "<line-count>" "<notes>"
```

`demo_record` takes `passed` as the literal `true` or `false` and rejects
anything else at rc 2.

**The session-handoff half of spec §6.1's "handoff / state updates" row stays
unwired.** `/ossify:handoff` exists as a standalone utility, but offering it at
the spine boundary is a deliberate non-wiring: handoff belongs to no ceremony —
a session handoff is written when context runs out, not because a spine closed
— and its design left close-wiring an open call. Saying so beats leaving the
row looking complete.

---

## 10. What has no executable surface

Stated plainly so nobody infers coverage that does not exist.

**"Apply-pending runs before the demo" and "a failing demo halts before the
critic, the harvest and cleanup" are orderings of prose steps with no executable
surface.** A bash script that calls apply-pending and then the demo runner
asserts nothing about the ceremony — it tests a fixture written to pass. The
harness checks that every `oss` verb this file names resolves; beyond that these
orderings have no automated coverage in this release.

The mechanical seams **are** covered in `tests/test-close.sh`: the derived-branch
assertion, the `base_branch` guards, the switch-back's HEAD assertion, the
first-parent changed-path computation, and all three of `touch_check`'s exit
codes across the four cases `tests/test-close.sh` E6 drives: zero paths, a hit,
clean, and an unreadable registry.

---

## 11. Anti-patterns

- **Reading the spine branch off HEAD** instead of deriving it with
  `oss branch_name` and asserting the match (§3).
- **Merging without switching back** — the spine merges into itself at rc 0.
- **Trusting the checkout's rc alone.** A tracked file name checks out clean and
  leaves HEAD where it was (§3).
- **Guessing the default branch** when `base_branch` cannot be resolved.
- **Merging canonical alone and calling the spine closed** when other repos
  host the spine's items too. Every hosting repo needs its own switch-back and
  merge — a partially-merged spine that only canonical's share reached is not
  a closed spine, however green the close otherwise looks (§3).
- **Computing the changed paths as `$base_branch..$spine_branch`** after the
  merge. Empty when the base never moved, wrong when it did (§6).
- **Calling `touch_check` once per repo and combining the verdicts by hand**
  instead of building one aggregated path list and calling it once. A bone or
  risk gate is a project-wide surface; the touch check judges the union, not a
  repo at a time (§6).
- **Folding `touch_check`'s rc 2 into clean**, or reading rc 0 as clean (§6).
- **Calling `oss class_set` with two arguments.** The reason is required, and a
  missing one is a crash, not a default (§6.1).
- **Assuming a touch hit is a bone.** Read the printed prefix (§6.2).
- **Carrying close depth onto the flesh path** — the light host-only pass is
  the flesh contract (§7).
- **Running the flesh pass at close depth**, or the bone pass at shallow depth (§7).
- **Reading the audit reference halfway** — the depth (close or shallow) and the artifact path both arrive in the invoking prose (§7).
- **Cleaning up before the harvest**, or before the merge (§9).
- **Writing `spine_status closed` after any halt.** A halt records nothing.
- **Re-running the touch check after a mid-flight reclassification** (§6.1).
