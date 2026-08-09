# The patch lane — out-of-spine work

Depth for SKILL.md §6 (spec §6.1). The lane exists so that a typo fix does not
need a spine, and it is bounded so that "it was only a typo" does not become the
way real work escapes the ceremony.

**The verb already exists.** `oss patch_add` has shipped since the ledger layer;
what has never existed is the routing judgment that decides when to reach for it.
That judgment is this file, and it is the whole content — there is no new
machinery here.

---

## 1. The three-part test, and all three must hold

Spec §6.1: changes that touch **no bone**, **no risk surface**, and **no
demo-relevant behaviour** may commit directly. It is a conjunction. One failure
sends the change to a flesh spine.

| Condition | How it is decided |
|---|---|
| Touches no **bone** | **mechanical** — `oss touch_check` (§2) |
| Touches no **risk surface** | **mechanical** — the same call, different printed prefix (§2) |
| Changes no **demo-relevant behaviour** | **judgment** — yours (§3) |

Two thirds of the test is a checked fact, and leaving it a vibe is the mistake
this file exists to prevent: the bones registry and the risk gates were written
down precisely so that "does this touch anything load-bearing" stops being a
memory exercise.

---

## 2. The mechanical two thirds — run the touch check

Feed it the paths the change actually touches, one argument per path:

```bash
# "$@" = the paths this change touches, ONE ARGUMENT PER PATH. `set -- a b c`
# builds that without breaking on a path containing a space; an array is the
# obvious alternative and is worse, for the reason `spine-close.md` §6 gives.
tc=0; hits="$(oss touch_check "$@")" || tc=$?
case "$tc" in
  0) printf '%s\n' "$hits"
     echo "patch lane: this change touches a declared surface - it is a spine, not a patch" ;;
  1) echo "patch lane: no bone, no risk gate - the mechanical two thirds pass" ;;
  *) echo "patch lane: touch_check could not run (rc $tc) - INCONCLUSIVE, not clean - route it as a spine" ;;
esac
```

**rc 0 = HIT, rc 1 = clean, rc 2 = could-not-check** — the same contract
`spine-close.md` §6 reads at close time, and the opposite polarity from the two
release-close blocking gates (`fake-expiry.md` §2). Reading rc 0 as clean here
routes exactly the load-bearing changes into the unceremonied lane.

**rc 2 is not clean.** Zero paths passed, or an unreadable registry. The patch
lane is the permissive route, so an inconclusive answer resolves *against* it:
route the change as a spine and find out why the check could not run.

**A risk-gate hit is not a lesser bone hit.** `touch_check` prints `bone <adr>`
or `risk_gate <name>`; either one ends the patch-lane conversation. Harm is
orthogonal to reversibility, so a one-line change inside a guarded surface is a
Risk event and owes that gate's controls — which the patch lane has no step to
walk.

---

## 3. The judgment third — "no demo-relevant behaviour"

No verb decides this, and none is coming: the cumulative ledger describes
journeys, not paths, so nothing can mechanically answer whether a change moves
one.

The question to ask is not *"did I change a file a demo line touches"* — it is
**"if I ran the ledger's `user:` and `auto:` lines right now, could any of them
notice this?"** A change that alters an observable outcome, a message a line
asserts on, a timing a line depends on, or the shape of a command a line runs is
demo-relevant, however small the diff.

When the answer is genuinely uncertain, it is a spine. The lane is for changes
whose irrelevance is *obvious*, and "I had to think about it" is already the
answer.

---

## 4. What qualifies, and what only looks like it does

| Change | Verdict |
|---|---|
| Typo in a comment, a doc, a README | **Patch.** Nothing runs it |
| Formatter or linter run with no semantic diff | **Patch**, provided the check really is no-op — read the diff, do not trust the tool's claim |
| Pinned dependency **patch** bump with no API change and no behaviour a line observes | **Patch**, if `touch_check` is clean on the manifest and lockfile |
| Dependency **minor/major** bump | **Spine.** The version boundary is where the surprises live, and "it compiled" is not the demo |
| Adding a test | **Judgment, leaning patch** — unless it joins the ledger, in which case authoring it is `/plan-spine`'s, not yours |
| Fixing a failing demo line's *product* cause | **Spine.** The ledger just told you the product is wrong; that is the opposite of demo-irrelevant |
| Renaming an internal symbol nothing exported | **Judgment** — clean `touch_check` and no observable change, or it is a spine |
| Anything under a path a bone or risk gate declares | **Spine**, always, whatever its size (§2) |
| "It is only one line" | **Not a criterion.** The three-part test says nothing about diff size |

---

## 5. Committing it — and the branch is not optional

**A patch never lands on a spine branch.** Spec §6.1's "may commit directly"
names no branch, and the obvious reading is wrong here, because
`work-item-close.md` §4 parks canonical **on the spine branch for the whole
spine**. Committed there, an out-of-spine change lands inside that spine's diff:
it is swept into the spine's changed-path list at close, feeds its `touch_check`,
and gets attributed to its demo contribution. The one lane defined by *not*
belonging to a spine ends up inside one.

**Assert the branch before you commit — check the name, never the rc:**

```bash
canonical="$(oss repo_root canonical)"
br="$(git -C "$canonical" rev-parse --abbrev-ref HEAD)"
case "$br" in
  spine/*|work/*) echo "halt: canonical is parked on '$br' - a patch does not land in a spine's diff"; exit 1 ;;
  HEAD)           echo "halt: canonical is in DETACHED HEAD - a patch commit here belongs to no branch"; exit 1 ;;
  '')             echo "halt: could not resolve canonical's branch"; exit 1 ;;
  *)              echo "ok: patching on '$br'" ;;
esac
```

**Allow-list the destination; do not deny-list the bad cases.** `rev-parse
--abbrev-ref HEAD` prints the literal string **`HEAD`** on a detached checkout,
which a bare `*)` arm waves through as a valid branch. The patch then commits to
no ref at all: `oss patch_add` records a sha that exists only until the next gc,
the change never reaches the base branch, and `doctor`'s patch count reports a
record whose commit is unreachable. Every arm above fires on something real — a
parked spine, a work-item branch, a detached checkout, an unresolvable HEAD.

**If a spine is parked, halt and put it to the user** — two options, and it is
their call:

1. **Wait.** Close the spine first, then patch on the base branch. Right when the
   spine is nearly done.
2. **Route the change through the spine.** Right when the patch is small and
   related enough that living in that spine's diff is honest.

Do **not** silently create a worktree to get around the parked spine — that
splits the patch lane across two places and the second one has no record.

## 5b. Recording it

```bash
oss patch_add "<commit-sha>" "<one line: what changed and why it took no spine>"
```

**Two arguments, and the sha comes first.** It is recorded **after** the commit,
because the sha does not exist until then — commit, then read the sha, then
record. A patch committed and never recorded is the lane's actual failure mode:
the drift is real and invisible, and `doctor` cannot count what was never
written.

The one-liner is **self-declared and `doctor`-visible**. Write the second half —
*why it took no spine* — as the three-part test's answer, not as a restatement of
the diff. *"comment typo in the export path — no bone, no gate, no line observes
it"* is a record; *"fix typo"* is a shrug that the next reader cannot audit.

There is **no approval step and no ceremony** here, by design. The lane's
integrity rests entirely on the routing judgment being made honestly before the
commit, which is why §1's test is a conjunction and §3's uncertain case resolves
against the lane.

---

## 6. What bounds the drift

The patch lane accumulates unvalidated change between spine closes. That window
is bounded, not open-ended: **the next spine close's cumulative demo re-validates
the whole product regardless** (`cumulative-demo.md` §1) — every accumulated
`auto:` line, against canonical post-merge state, halt on the first failure. A
patch that broke something surfaces there.

Two consequences worth stating:

- **The bound is the next spine close, not the next release close.** A project
  going a long time between spines has a correspondingly long window, and that is
  a reason to close spines, not a reason to widen the lane.
- **The demo is what catches it, so a patch that dodges the demo dodges the
  bound.** That is the same sentence as §3 from the other direction, and it is
  why "no demo-relevant behaviour" is the criterion that cannot be mechanized
  away.

Anything heavier is a **flesh spine, however small**. The cost of a flesh spine
is deliberately low — that is what makes "when in doubt, spine it" an affordable
default rather than a threat.

---

## 7. Anti-patterns

- **Skipping `touch_check`** because the change is obviously small (§2).
- **Reading `touch_check` rc 0 as clean** (§2).
- **Treating rc 2 as permission.** Inconclusive routes against the lane (§2).
- **Treating a `risk_gate` hit as lesser than a `bone` hit** (§2).
- **Using diff size as the criterion** (§4).
- **Routing a demo-line fix through the lane** when the cause is in the product
  (§4).
- **Committing without recording**, or recording without the sha (§5).
- **A one-liner that restates the diff** instead of answering the three-part test
  (§5).
- **Inventing a new verb.** `oss patch_add` is the record; nothing else is
  needed (§5).
- **Treating the patch lane as a way past a red demo.** The next spine close runs
  it anyway (§6).
