# Feature-map grooming

Depth for SKILL.md §5a. The feature map is the planning **source of truth** — it
replaced the exhaustive upfront BACKLOG and the multi-year roadmap. Grooming is
what turns it from a list into a release.

---

## 1. What the map holds

A living ranked list of candidate spines, thin by design. Each entry:

| Field | Meaning |
|---|---|
| `name` | short, the action ("save a named strategy") |
| `value` | one line: why the actor wants it |
| `class_guess` | `bone` or `flesh` — a **guess**, made before any plan existed |
| `source` | `journey-map` · `spec` · `release-retro` · `deferral` · `real-use` · `fake-replacement` · `feature-map-return` |

```bash
oss feature_list                                   # the whole map, as JSON
oss feature_add "<name>" "<value>" "<bone|flesh>" "<source>"
```

`class_guess` is **not** the class. It ranks and warns; the class ladder
(`references/class-declaration.md`) re-derives the real class from the actual
plan at declaration time. Never carry the guess through to `oss spine_add`
without re-running the ladder.

The map is groomed at **every** release close (and again here at planning). It is
allowed to be three lines at Release 0 — that is a documented Release-0 minimum,
not a gap.

---

## 2. Grooming, in four passes

**Pass 1 — absorb.** Fold in everything that arrived since the last groom:
real-use findings (`references/real-use-findings.md`), deferrals filed during
execution, fake-ledger replacement triggers that have fired, retro follow-ups, and
any internal-enabler that returned because its consumer was dropped. Nothing that
surfaced in the last release should be living only in someone's memory.

**Pass 2 — rank against *this* release's goal.** Not global priority — fit. The
question is *"does this move the promise this release is making?"*, and the
promise is a user journey, so the ranking is by user value, not by architectural
tidiness. A high-value entry that does not serve this release's promise stays on
the map, ranked, and waits.

**Pass 3 — cut candidates into spines.** An entry becomes a spine only if it can
cross the product end to end (§3). Entries that cannot are split or deferred.

**Pass 4 — prune.** Entries superseded by shipped work, or by a decision that made
them meaningless, are removed with a one-line reason said out loud. An
ever-growing map is a map nobody reads.

---

## 3. Candidate → spine: the four tests

A feature-map entry is ready to be a spine when it passes all four:

1. **End-to-end, not end-to-layer.** It crosses every layer its journey needs and
   surfaces where the actor actually is. "Backend now, UI next release" is a
   horizontal build — it fails rung 1 of the class ladder and is not a spine.
2. **One journey, not a capability list.** "Strategy management" is three spines
   wearing one name. Split it.
3. **Thinnest usable version.** A feature spine is *the thinnest usable version of
   one feature*, not the complete feature. Depth is a later deepening pass, and
   deferring depth is free — deferring usability is not.
4. **Its scope can name its changed paths.** If nobody can say roughly which
   modules it touches, the bone-touch judge cannot run on it, and the class
   declaration would be a guess. Scope it further first.

**Splitting a too-large candidate**: cut it along the *journey*, not along the
*stack*. "Users can save and reload a strategy" splits into "save one strategy and
see it in the list" then "reload a saved strategy into the editor" — each usable
alone. It does **not** split into "persistence layer" then "UI wiring"; that is
the horizontal cut in disguise.

---

## 4. Breadth-first by default; deepening when earned

Default: **breadth-first thin spines**. Reach across the journey map before
thickening anything, because breadth is what makes the product usable and
usability is what feeds the motivation loop.

A **deepening pass** (more depth, polish, performance, reliability) is selected
when it is *earned* — there is evidence, normally from the real-use findings, that
the thin version is costing something real. "It feels unfinished" is not
evidence; "I stopped using it because the import takes four minutes" is.

A deepening pass claiming a measured quality (performance, reliability, cost)
owes **before/after evidence** in its demo contribution at spine planning. Say so
here, at selection, so the baseline gets measured *before* the work starts —
after the fact it is unrecoverable.

---

## 5. How many spines

Whatever the release's promise needs — there is no target count. Two calibration
points from the spec:

- **Release 0** contains exactly the skeleton spine (plus, rarely, a second).
- **MVP** ≈ skeleton + 2-3 feature spines.

If the list is long enough that the exit criteria read like a product brochure,
the release is too big; move the tail to the next release's sketch. A release
nobody can finish is the old sprint failure mode with new vocabulary.

---

## 6. What grooming does *not* do

- It does not decompose spines into work items or author demo lines — `plan-spine`.
- It does not author specs — `plan-spine`.
- It does not re-rank the whole map into a multi-release plan. Current release
  detailed, next sketched, map beyond (`references/rolling-wave.md`).
- It does not delete an entry to make the release look tidy. Deferral is a
  recorded decision, not an omission.

---

## 7. Anti-patterns

- **Selecting by `class_guess`.** The guess is a warning label; the ladder decides.
- **Selecting the architecturally satisfying entry over the user-visible one.**
  The release's promise is a journey.
- **Letting a horizontal candidate through** because splitting it "isn't worth
  the ceremony". It is the ceremony that stops seven sprints of layers.
- **Grooming the map into a roadmap.** Rank it; do not schedule it.
- **Dropping real-use findings on the floor** because they arrived as complaints
  rather than as feature requests. That is exactly what they are supposed to
  arrive as.
- **A map that only ever grows.** Prune in pass 4, out loud, with reasons.
