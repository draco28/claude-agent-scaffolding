# Cross-repo work items (`target_repo`)

Depth for SKILL.md §4/§5. A spine may span repos; **each work item targets exactly
one repo.**

---

## 1. The field

```bash
oss work_item_add "$spine" "<title>" [target_repo]     # defaults to "canonical"
```

`target_repo` is stored on the work item and defaults to `canonical`. A project
with a private side passes that repo's key (e.g. `private_core`) for items that
land there. The spine itself also carries a `target_repo` (set at `plan-release`);
the item's value is what the execution engine reads, because the item is what gets
a worktree.

Read them back:

```bash
oss get '[.work_items[] | select(.spine == "r1.s2") | {id, title, target_repo}]'
```

**Why one repo per item, strictly:** the item is the unit that gets a worktree, a
branch, and a merge. An item spanning two repos has two branches and two merges,
which means it has two failure points and no single place to halt. Split it — the
split is almost always the public port / private adapter seam, and that seam is
worth making explicit anyway.

---

## 2. The DAG orders cross-repo dependencies

A cross-repo dependency is a **real edge**, not a preference: the private adapter
cannot compile against a port that does not exist.

> **Round 1** — `r1.s2.w1` public port change (`canonical`)
> **Round 2** — `r1.s2.w2` private adapter implementing it (`private_core`)

Reversing the order is not a style choice, it is a build failure. Putting both in
one round is the same failure with extra parallelism.

The general rule: **the repo that owns the contract goes first; the repo that
implements or consumes it follows.** For an open-core posture that is nearly
always public-then-private, because the public core is what the private
composition depends on.

---

## 3. The build-mechanics consequence

Mid-spine, the public change exists **only on a local spine branch** — it is not
published, not tagged, not on a registry. So the private side cannot resolve it
through its normal dependency declaration.

The resolution (companion spec §4.2): the private worktree gets a
**worktree-scoped local dependency override** pointing at the canonical repo's
current spine state — Cargo `[patch]` / path override, pip editable or path
install, npm `file:` / `overrides`, as the stack requires.

Two properties of that override matter at **planning** time, because they change
what the plan must contain:

- **It is never committed.** Implementation-check and spine close verify its
  absence from staged and tracked content. Plan for it as environment, not as a
  file change; do not add "update Cargo.toml" as a work item.
- **The spine-close cumulative demo builds the composition *with* the override**,
  against both repos' post-merge state. So an `auto:` line that builds the
  composition is legitimate and will pass mid-flight — and the *release*-close
  pin/publish step is what proves it also works against real pinned dependencies.

Spinning the multi-repo worktrees up is the execution engine's job, not this
skill's. Plan the rounds so it is possible; do not attempt it here.

---

## 4. Per-repo branch and merge semantics

Planning-relevant facts, so the round structure does not promise something the
execution engine cannot do:

- Each touched repo carries **its own spine branch** (`spine/<spine-id>-<slug>`,
  the same name in both).
- Rounds merge **per repo, in DAG order**.
- A merge conflict in **either** repo **halts the whole spine** at the last
  cross-repo-consistent round. Halt-and-surface; there is no automated cross-repo
  rollback.
- The release PR gate emits **one PR per touched repo**.

The consequence for planning: **keep the number of cross-repo round boundaries
small.** Every alternation between repos is another point where a conflict halts
both sides. A spine that alternates public/private/public/private four times is
usually two spines.

---

## 5. Boundary discipline still applies

A cross-repo spine is the moment the public/private boundary gets tested, so:

- **No moat item is ever named in a public-side artifact** — including a work-item
  spec, a branch name, or a demo line's text. The private boundary inventory lives
  in the AI workspace.
- A demo line whose command only runs against the private composition is still a
  legitimate ledger line; a demo line whose *text* leaks what the private side
  contains is not.
- The public edition must remain buildable and demoable on its own. If a spine
  makes the public core depend on something only the private side has, that is a
  bone change and a boundary decision, not a work item.

---

## 6. Anti-patterns

- **A work item spanning two repos.** Split it at the port/adapter seam (§1).
- **Private-before-public ordering**, or both in one round (§2).
- **Planning a work item to edit the dependency override.** It is worktree-scoped
  environment, never committed (§3).
- **Alternating repos every round.** Usually two spines (§4).
- **Assuming a cross-repo conflict rolls back.** It halts; plan the round
  boundaries where a halt is survivable (§4).
- **Naming a moat item in any public-side artifact**, demo lines included (§5).
- **Spinning up worktrees here.** Planning skill; the execution engine owns
  worktrees (§3).
