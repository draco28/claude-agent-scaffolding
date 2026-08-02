# The spine retrospective

Depth for SKILL.md §5, step 8 (`spine-close.md` §8). One `retrospective.md` per
closed spine, authored against a **fixed section contract** — full for a bone
spine, lean for a flesh one.

This file is the **only copy** of both section sets. Headings exactly as written,
in the order written — the same pinned-headings discipline the work-item report
contract uses, and for the same reason: the memory-bank harvest (step 9) sweeps
these files, and a heading invented per spine makes the retro series unreadable
as a series.

Where it goes — beside the spine plan it closes, never in the worktree (which
step 10 removes):

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<spine-slug>/retrospective.md
```

**Which set applies is the spine's class at the moment step 8 runs**, not the
class it was planned as. A flesh spine that step 5 reclassified to bone owes the
**full** set — that is what "the reclassification takes effect for every
remaining row" means (`spine-close.md` §6.1).

---

## 1. Bone — the full set

Nine sections. A bone spine moved something the project declared load-bearing, so
the retro carries the audit trail as well as the lessons.

### `## 1. What the spine set out to do`

The spine id, its class (and the class it was *declared* as, if they differ), the
release it belongs to, and one paragraph of intent in the project's own terms —
not a restatement of the work items.

### `## 2. What shipped`

The work items, by id and title, with what each actually delivered. Where the
delivery differs from the plan, say so here rather than quietly matching the plan
back to the code.

### `## 3. Demo outcome`

The `auto:` result (`PASS <n> lines`, or the line that failed and what was done
about it) and the `user:` walk — which journeys the human drove and whether each
outcome matched. Name any line that was **quarantined during this close**, with
its expiry release.

### `## 4. Class movement`

Whether the class changed and why. If step 5 reclassified this spine mid-flight,
record the `bone <adr>` or `risk_gate <name>` line `touch_check` printed and the
reason string given to `oss class_set`. If the class did not move, one line
saying so — an absent section reads as an omission, not as "nothing happened".

### `## 5. Bone and risk-surface findings`

What this spine did to the surfaces the project declared. For a risk-gate hit,
walk the gate's `controls` list and record the evidence for each, one row per
control. **A control with no evidence is an open item, not a pass**, and it
belongs in §9.

### `## 6. Critic findings and their dispositions`

Every finding the close-depth critic pass returned, with its disposition
(`auto-bone` / `override` / `escalate`) and the reason. Auto-applied dispositions
are recorded here too — the point of auto-apply is that it is fast, not that it
is invisible.

If the critic was not installed, say that in one line. A missing section is
indistinguishable from a clean pass.

### `## 7. Fakes, deferrals and quarantines still standing`

Everything this spine leaves owed: fakes still on `active`, deferrals accepted
during the gate, quarantined demo lines. Each with the trigger or release that
retires it. This is the section the next release close reads first.

### `## 8. What we learned about the work`

The durable lessons — what the estimate missed, which seam turned out to be the
hard one, what a future spine on this surface should know. Prose, not bullets of
process platitude. If nothing was learned, write that; it is a real finding about
a spine that went exactly as planned.

### `## 9. Carried forward`

The concrete open items, each with an owner or a named next step: unmet controls
from §5, escalations from §6, obligations from §7. **Nothing arrives here without
appearing above** — this is a roll-up, not a place to introduce new work.

---

## 2. Flesh — the lean set

Four sections. A flesh spine is reversible by construction, so the retro records
what happened and what is owed, and stops.

### `## 1. What shipped`

Spine id, release, and the work items by id and title with what each delivered.

### `## 2. Demo outcome`

The `auto:` result and the `user:` walk, same content as the bone set's §3.

### `## 3. Still standing`

Fakes, deferrals and quarantines this spine leaves owed, each with its trigger or
expiry release. The bone set's §7, unchanged — this one is **not** the section to
shorten, because it is what the release close needs.

### `## 4. Carried forward`

Open items with a named next step.

**What the lean set drops, and why it is safe to drop:** intent (§1 of the bone
set) is already in `SPINE.md`; class movement (§4) is vacuous when the class
never moved — and a flesh spine whose class *did* move is a bone spine by step 8
and owes the full set; bone/risk findings (§5) are empty by definition on a clean
touch check; the critic's dispositions (§6) come from a light host-only pass with
no external adversary; and the lessons section (§8) is where retro cost actually
lands, which is the deliberate difference between "full" and "lean".

**The lean set is not an optional set.** All four sections are written, every
flesh close.

---

## 3. Anti-patterns

- **Inventing a heading**, renaming one, or reordering the set.
- **Dropping a section because it would be empty.** Write the one line that says
  it is empty; a missing section and a clean result are indistinguishable to
  every later reader.
- **Using the lean set for a spine that was reclassified to bone.** The class at
  step 8 is the one that counts, not the class it was planned as.
- **Writing the retro before the demo has passed.** A halt records nothing, and a
  retro authored over a failed close is a document asserting a close that did not
  happen.
- **Introducing new work in `Carried forward`** that appears nowhere above it.
- **Recording an auto-applied disposition as "no findings"** (bone set, §6).
- **Placing the file in the worktree.** Step 10 removes it.
- **Letting §8 become process platitudes.** If there is no lesson, say there is
  no lesson.
