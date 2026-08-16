# Merge-conflict resolution

Depth for the two merge moments: work-item close step 4
(`work-item-close.md` §4) and spine close step 2 (`spine-close.md` §3). Both
halt on conflict by contract — conflicted paths surfaced verbatim, the merge
left in progress, no later step run — **and that halt is unchanged by this
file.** The ceremony never resolves a conflict on its own initiative.

This file is what gets read **at** the halt, when the operator says *resolve
it* rather than doing it themselves. Resolution is deliberate work with its
own discipline, and "the merge is in progress, make it go away" is exactly
the framing under which work gets destroyed.

---

## 1. The two rules that survive everything below

- **Never `--abort` on your own initiative** — the same scope the shipped
  halts pin (`work-item-close.md` §4, `spine-close.md` §3: never on the
  user's behalf). Abort discards the in-progress resolution work and re-parks
  the ceremony behind the same conflict, minus everything learned; whether
  that price is worth paying is the operator's call, never the resolver's.
- **Never resolve a side wholesale.** `--ours`/`--theirs`, or `-X` strategy
  options, answer a *file-shaped* question when the conflict is
  *intent-shaped*. The unit of resolution is the hunk, and the authority is
  each side's originating intent — never the diff text's plausibility.

---

## 2. Where intent lives

Every conflicted side was put there by work that has a written source. Read
the sources, not the tea leaves:

| The side came from | Its intent lives in |
|---|---|
| A work item in this spine | That item's **`spec.md`** — the binding ACs, reachable via the handoff's `spec_path` (the handoff's own AC section is non-binding by contract) — plus the handoff for spine context and `report.md` for what was actually done |
| The spine itself, merging to base | The **spine spec** (`SPINE.md`) — what this spine set out to change |
| The base branch since the spine cut | The merged PRs / spine records that landed there — `git log` names them; their specs say why. An out-of-spine change's source is its patch record (`patch-lane.md` §5b) |
| A registered architectural surface | The **bone ADR** whose touch surface the path sits in — a conflict inside a bone's surface is architecture, not text |

A conflict between two work items in the same spine is resolved by reading
both handoffs. A conflict between the spine branch and base is resolved by
reading the spine spec against what landed on base since the cut.

---

## 3. The loop, per hunk

1. **Read both sides' intent from §2's sources** — what was each side *for*?
   Not "what does each side's text do."
2. **Classify the pair:**
   - **Independent** — both intents stand; the text merely collided. Compose
     a resolution that preserves both. Most conflicts are this.
   - **Overlapping** — one side supersedes the other, *and a source says
     so*: the later spec amended the earlier behaviour, the ADR moved the
     boundary. Take the superseding side and be able to cite why.
   - **Contradictory** — the sources genuinely disagree about what should be
     true. **Stop resolving. This is a plan defect surfacing as text**, the
     same shape as `work-item/references/debugging.md` §3's AC-contradiction
     halt: picking a side
     silently makes the other side's tests wrong and defers the fight to
     someone with less context. Surface both intents, with their sources,
     and let the owner decide.
3. **Resolve the hunk, remove its markers, stage the file** when every hunk
   in it is done.

Not every conflict has a hunk. A **modify/delete**, a **binary add/add**, or
a **submodule pointer** conflict is resolved by the same §2 intent reading —
the disposition (keep, delete, recreate, or pick a side's artifact) is chosen
*after* both intents are read and is cited like any hunk resolution. What
stays banned is blind side-selection, not deliberate selection.

---

## 4. After the hunks — verification, then the ceremony resumes

A build that compiles proves the text merged; it does not prove intent
survived. The proof is the ceremony's own gates, which is why resumption
matters more than the merge commit:

- finish **this** step, whole — the merge commit, its reachability check,
  and on the work-item side the `complete` status write, **last** (its step 4
  ends there; a resolver who skips it leaves the item `active` and the next
  spine close halts naming it) — then continue forward; never re-run the
  layer (both merge docs pin the rule; `work-item-close.md` §4 carries the
  why for its side — the commit already landed on the work-item branch, and
  a re-run reports the wrong problem);
- for a work-item merge, **re-run the item's AC commands against the
  resolved tree before the status write** — the gate ran in the isolated
  worktree, *before* your resolution existed, and a mis-composed hunk passes
  reachability while failing the ACs;
- for a spine merge, step 4's cumulative demo walks every accumulated line
  against the merged tree — a resolution that quietly dropped a side fails
  exactly there, which is the system working.

The resolution is part of the record: the merge commit carries it, and a
contradictory-pair escalation that changed a spec belongs in the close
summary.

---

## 5. Anti-patterns

- **`--abort` to get unstuck.** Both sides' commits survive on their
  branches, but every resolved hunk and the halt's context do not — and the
  decision to pay that was never yours.
- **Wholesale `--ours`/`--theirs`.** Somebody's spine just silently lost.
- **Resolving from the diff alone.** Text that reads plausibly merged is not
  intent preserved — the two failure modes look identical in the editor.
- **Resolving a contradiction yourself.** You have no mandate; the sources
  disagree and their owners do not know yet.
- **Markers left in a "resolved" file.** The build catches `<<<<<<<` in code
  and misses it in Markdown and config — grep before staging.
- **"It builds" as the finish line.** The gates are the finish line; the
  build is the entry fee.

---

*Prior art: mattpocock `resolving-merge-conflicts` (hunk-by-hunk by intent,
never abort). Lineage, not source — this doc is ossify's own, and ossify's
halt-first contract is stricter: resolution is operator-sanctioned, never the
ceremony's own move.*
