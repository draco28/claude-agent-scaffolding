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
| architect-critic | full audit, external adversary at close depth (`--close`) | one light host-only pass (no `--close`) |
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

## 3. Step 2 — switch canonical back to its base branch, then merge

The two facts this step needs are not in state and are recovered, not guessed:

- **The spine slug** from the spine directory's name, exactly as the execution
  lane recovers it (`round-orchestration.md` §2). Nothing persists a slug.
- **`base_branch`** from the spine plan document `SPINE.md`'s spine-context
  section, where the execution lane recorded it (`round-orchestration.md` §2).
  Every handoff in the spine carries the same fact under `## 2. Spine context`
  (`handoff-contract.md` §2), which makes a useful cross-check. **If it cannot be
  resolved, halt** — guessing the default branch merges a spine into the wrong
  line of development, and every downstream step then reports green.

```bash
canonical="$(oss repo_root canonical)"

# DERIVE the spine branch; never read it off HEAD. HEAD is durable git state
# that a session boundary, a hotfix or a halted close can move.
spine_branch="$(oss branch_name "$spine_id" "$spine_slug")"
head_branch="$(git -C "$canonical" rev-parse --abbrev-ref HEAD)"
[ "$head_branch" = "$spine_branch" ] \
  || { echo "close: canonical is on '$head_branch', not '$spine_branch' - halt"; exit 1; }

[ -n "${base_branch:-}" ] \
  || { echo "close: no base_branch recorded for $spine_id - halt"; exit 1; }

pre="$(git -C "$canonical" rev-parse "$spine_branch")" \
  || { echo "close: cannot resolve '$spine_branch' - halt"; exit 1; }

git -C "$canonical" checkout -q "$base_branch" \
  || { echo "close: cannot check out base branch '$base_branch' - halt"; exit 1; }
now_on="$(git -C "$canonical" rev-parse --abbrev-ref HEAD)"
[ "$now_on" = "$base_branch" ] \
  || { echo "close: switch-back left canonical on '$now_on', not '$base_branch' - halt"; exit 1; }

git -C "$canonical" merge --no-ff "$spine_branch" -m "merge $spine_id" \
  || { echo "close: merge conflict - halt"; exit 1; }
git -C "$canonical" merge-base --is-ancestor "$pre" HEAD \
  || { echo "close: merge reported success but $pre is not reachable from HEAD - halt"; exit 1; }
merge_sha="$(git -C "$canonical" rev-parse HEAD)"
```

**Four guards, and every one of them exists because the failure it catches is
rc 0 all the way to a green close.**

- **Derive the spine branch and assert HEAD matches it.** Reading it off HEAD
  instead makes the switch-back a no-op and the merge "Already up to date" — the
  spine never lands, and steps 3-11 all run green against a tree it never
  reached. §4 ships the same assertion for the same reason
  (`work-item-close.md` §4): *a merge onto the wrong branch succeeds silently at
  rc 0.*
- **Require `base_branch` to be non-empty, and check the checkout's rc.** An
  empty one makes `git checkout -q ""` fail at rc 128; unguarded, the ceremony
  continues with canonical still on the spine branch and merges it into itself.
- **Assert HEAD actually moved.** This is a separate guard from the rc check and
  catches what the rc check cannot: `base_branch` resolving to a **tracked file
  name** rather than a branch. `git checkout -q <tracked-file>` restores that file
  and exits **0** without moving HEAD, so the rc guard passes and the self-merge
  runs anyway.
- **Check reachability after the merge**, which catches a merge that reports
  success without landing the tip. It cannot replace the branch assertion: on a
  self-merge `$pre` is trivially its own ancestor, so `--is-ancestor` returns 0.
  Both legs, always.

**A merge conflict halts with rc-8 semantics.** Surface the conflicted paths
verbatim, leave the merge in progress for the human, and run **no** later step.
Never `--abort` on the user's behalf, never auto-resolve, never `-X` a strategy
option. Resuming means finishing *this* step and continuing, not re-running the
layer.

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

**Compute the path list first — it is the merge's own diff**, which is the merge
commit against its **first parent**:

```bash
set --
while IFS= read -r p; do
  [ -n "$p" ] || continue
  set -- "$@" "$p"
done < <(git -C "$canonical" diff --name-only "$merge_sha^1" "$merge_sha")

[ "$#" -gt 0 ] \
  || { echo "close: the merge changed no paths - the touch check is INCONCLUSIVE, not clean - halt"; exit 1; }

tc=0; touch_hits="$(oss touch_check "$@")" || tc=$?
case "$tc" in
  0) printf '%s\n' "$touch_hits" ;;          # HIT - §7 and §8 act on these lines
  1) echo "touch check: clean" ;;            # clean - change nothing, record nothing
  *) echo "close: touch_check could not run (rc $tc) - INCONCLUSIVE, not clean - halt"; exit 1 ;;
esac
```

**`$merge_sha^1 $merge_sha`, not `$base_branch..$spine_branch`.** The range form
looks right and is wrong in both directions. After the merge, `git diff A..B` is
just `git diff A B` — a comparison of two *trees*, not a range — and the base
branch's tree now already contains the spine. When the base never moved, the two
trees are identical and the list comes back **empty**, which halts every close.
When the base *did* move, the list names the files the **other** work changed and
omits the spine's own. The first-parent diff is the only form that answers "what
did this merge bring in", and it is stable whether or not the base moved.

**Feed one argument per path.** `set --` plus `"$@"` does that without breaking
on a path containing a space and without depending on `$IFS`. An **array** is the
obvious alternative and is worse here: under `set -u`, expanding an empty one is
a fatal *unbound variable* abort on the bash macOS ships (3.2), so the empty case
would die before reaching the halt that explains it.

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

## 7. Step 7 — architect-critic, and the flag differs by class

```bash
oss critic_detect || true        # prints "v0.3"/"v0.2" (rc 0) or "absent" (rc 1)
```

**Guard the call.** The verb prints `absent` and **returns rc 1**, so an
unguarded invocation aborts the whole ceremony under `set -e` at the one moment
the answer is "not installed, carry on".

On `absent`: **exactly one warning, then proceed.** A silent skip and a blocking
error are both wrong — *"architect-critic not installed — skipping the spine
close audit. Install via `/plugin install architect-critic` (v0.2+)."*

Otherwise, export the bridge and invoke. **One string cannot serve both classes**:

```bash
# bone — full audit, external adversary at close depth
export ARCHITECT_CRITIC_ARGS="--spec \"<abs path to the spine's SPINE.md>\" --close"

# flesh — the light host-only pass: the SAME string WITHOUT --close
export ARCHITECT_CRITIC_ARGS="--spec \"<abs path to the spine's SPINE.md>\""
```

```text
Skill(architect-critic:critiquing-spec)
```

- **`--close` is the depth switch.** It is what recruits the external adversary,
  so carrying it on the flesh path is the opposite of "one light pass". Nothing
  else selects depth — announcement wording does not.
- **`export` it.** A bare assignment is invisible to the bash that reads it.
- **`--spec` takes one quoted absolute path to a real file.** Point it at the
  spine's `SPINE.md` under `oss spine_dir "<release-id>" "<spine-id>" "<slug>"` —
  the same artifact `plan-spine` hands the critic
  (`plan-spine/references/spec-authoring.md` §6). That verb returns a
  **relative** path, so prefix it with `oss repo_root ai_workspace`. A path that
  does not resolve triggers the critic's glob fallback and audits the wrong
  artifact, silently.
- **A bare `Skill(...)` call.** There is no `target=` / `depth=` /
  `artifact_path=` parameter; passing one resolves the wrong artifact at the
  wrong depth with no error.

Both failure modes — not installed, and installed but returning nothing — are
silent by design. Neither blocks the close.

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

**Step 9 — memory-bank harvest, always before cleanup.**

**Step 10 — worktree + branch cleanup, per work item, and only now:**

```bash
oss worktree_remove "$(oss get ".work_items[] | select(.id==\"$wi\") | .target_repo")" "$wi"
```

**Cleanup is last because of the branch, not the report.** `oss worktree_remove`
runs `git branch -d` and **refuses an unmerged branch at rc 8**, so it can only
succeed once step 2's merge has landed. Running it earlier converts a recoverable
state into a halt and leaves the work reachable only from a branch the ceremony
already tried to delete. It also refuses a **dirty** worktree at rc 8 rather than
forcing — an rc 8 here is a real signal, never something to force past.

(`report.md` is **not** in the worktree. It lives beside `spec.md` in the work
item's docs directory under the ai-workspace, which worktree removal never
touches — `work-item/SKILL.md` §7. The harvest's ordering constraint is its own,
and it is not this one.)

**Step 11 — state updates:**

```bash
oss spine_status "$spine_id" closed
oss demo_record spine "$spine_id" "<true|false>" "<line-count>" "<notes>"
```

`demo_record` takes `passed` as the literal `true` or `false` and rejects
anything else at rc 2.

**The session-handoff half of spec §6.1's "handoff / state updates" row is
deferred to a later release.** Offering `/handoff` at the spine boundary depends
on a redesign of that skill, and this release ships no handoff authoring. Saying
so beats leaving the row looking complete.

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
first-parent changed-path computation, and all four of `touch_check`'s exit
codes.

---

## 11. Anti-patterns

- **Reading the spine branch off HEAD** instead of deriving it with
  `oss branch_name` and asserting the match (§3).
- **Merging without switching back** — the spine merges into itself at rc 0.
- **Trusting the checkout's rc alone.** A tracked file name checks out clean and
  leaves HEAD where it was (§3).
- **Guessing the default branch** when `base_branch` cannot be resolved.
- **Computing the changed paths as `$base_branch..$spine_branch`** after the
  merge. Empty when the base never moved, wrong when it did (§6).
- **Folding `touch_check`'s rc 2 into clean**, or reading rc 0 as clean (§6).
- **Calling `oss class_set` with two arguments.** The reason is required, and a
  missing one is a crash, not a default (§6.1).
- **Assuming a touch hit is a bone.** Read the printed prefix (§6.2).
- **Letting `oss critic_detect` run unguarded** — `absent` is rc 1 (§7).
- **Carrying `--close` on the flesh path**, or dropping it on the bone path (§7).
- **Passing `target=` or `depth=` to the critic skill** (§7).
- **Cleaning up before the harvest**, or before the merge (§9).
- **Writing `spine_status closed` after any halt.** A halt records nothing.
- **Re-running the touch check after a mid-flight reclassification** (§6.1).
