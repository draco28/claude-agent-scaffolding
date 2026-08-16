# Round identification (the work-item DAG)

Depth for SKILL.md §5. Work items are sequenced into **rounds** by a strict-layer
topological sort over their declared dependencies.

Not to be confused with `plan-release`'s **inter-spine DAG**, which sequences
whole spines and is already recorded in the release's `spine_dag`. Same idea,
finer altitude, different owner.

---

## 1. What a round is

Round *K* contains every work item whose dependencies are fully covered by rounds
1…*K-1*. Items inside a round are **parallelizable**; rounds themselves are
strictly ordered.

> Round 1: `r1.s2.w1`, `r1.s2.w2` (parallel)
> Round 2: `r1.s2.w3` (depends on w1, w2)

The round structure is planning output. It is what the execution engine walks, and
it is why a false edge is expensive: a spurious dependency silently serializes
work that could have gone out together, and nobody reviews a dependency they never
questioned.

---

## 2. Is this a real edge?

`B depends on A` means **B cannot start until A is merged.** One of these must be
true, and you must be able to say which:

- **B builds on a seam A creates.** The function, the schema column, the route,
  the trait does not exist until A lands.
- **B's verification cannot run without A's outcome.** B's `auto:` ACs exercise
  something A produces.
- **A's decision changes B's shape.** Building B first means building it twice.

If none holds, it is **not an edge**. Say so and drop it.

Common false edges:

| Looks like | Actually |
|---|---|
| "the read path should come first" | Preference dressed as dependency |
| "both items edit `main.rs`" | A merge conflict to sequence at execution, not a planning edge |
| "do the risky one first" | A legitimate ordering choice *among round-1 items*, not an edge |
| "both touch the same bone" | Only an edge if one *changes* the bone the other depends on |
| "B builds against A's interface" | An edge only if B cannot **build or verify** without A's landed artifact. Coding to a contract fixed in the spec is not an edge; needing A's port to *compile* — the cross-repo case, §6 — is |

---

## 3. Deriving the rounds

1. List the items and their declared dependencies (§4).
2. Test each proposed edge against §2, out loud, once each. Keep the survivors.
   What that sounds like, over one proposed edge:

   > *"`w3` (order history view) depends on `w1` (order submission)?* Which §2
   > test? Not the seam — the orders table lands in `w2`, not `w1`. Not
   > verification — `w3`'s ACs seed rows directly. 'Users submit before they
   > browse' is journey order, not build order. **Dropped.**"

3. **Round 1 = every item with no surviving dependency.** If that set is empty,
   you have a cycle (§5).
4. Layer the rest: an item joins the first round after all its dependencies.
5. Sanity-check the shape. A spine whose DAG is a straight chain of 4 items is
   suspicious — it usually means edges 2-4 were assumed. A spine with no edges at
   all is fine and common.

---

## 4. Loosening and tightening

- **Loosening that violates a declared dependency is refused**, naming the edge:
  *"`w3` depends on `w1`; they can't share a round. Drop the dependency (and say
  why it was never real), or keep the proposed rounds."*
- **Tightening is always allowed.** The DAG produces the *minimum* round count;
  the user may serialize further for any reason — reviewer bandwidth, risk
  appetite, one pair of hands. That is soft ordering, not a dependency violation.
- **No empty rounds.** If edits leave a round with zero items, collapse and
  renumber.

---

## 5. Cycles

A cycle means the items are cut wrong, never that the DAG needs a tie-breaker.
Two items that each need the other are one item, or the seam between them is in
the wrong place.

Fix by re-cutting — **merge** them, **re-cut** so the shared seam lands entirely
inside the first, or **extract** the seam as its own round-1 item. Deleting an
arbitrary edge to make the graph acyclic produces a plan that is wrong in a way
nobody can see later.

---

## 6. Cross-repo ordering

A cross-repo dependency is a **real edge** by §2's first test — the private
adapter cannot compile against a port that does not exist yet. The worked
ordering example and the general rule (contract-owning repo first) live in
`cross-repo.md` §2; the build mechanics — the worktree-scoped local dependency
override the private side needs mid-spine — in `cross-repo.md` §3.

---

## 7. Anti-patterns

- **A linear chain masquerading as a DAG.** If every item depends on its
  predecessor, the edges were assumed, not tested.
- **Spine-level edges here.** Different altitude — `plan-release` owns those, and
  they are already recorded.
- **Deleting an edge to break a cycle** instead of re-cutting (§5).
- **Refusing a tightening request.** Always allowed (§4).
- **Allowing a loosening that violates a real edge** because the user asked
  firmly. Name the edge and offer to drop the dependency explicitly instead.
- **Re-deriving the rounds at execution time.** If reality disagrees with the
  plan, re-plan and re-record; do not improvise a new order silently.
- **Putting a cross-repo pair in one round** (§6).
