# The nested Run — mechanics of an activated ossify spine

The contract these mechanics serve is `references/ossify-execution.md`.

## 1. Nested depth is a prerequisite, not a fallback

Orca's `Settings → Orchestration → Nested worker depth` must be `2`, because the spine
session dispatches item sessions of its own. No CLI read exposes that setting, so get
the operator's confirmation before starting the spine session; the first real child
dispatch is the runtime proof.

If a child dispatch returns `nested_worker_depth_exceeded`, the spine session stays
the lane owner, reports the blocker, and waits for an operator decision. It does not
substitute a Claude subagent, move item tasks into the parent Run, create a
replacement writer, or restart the lane.

## 2. The nested Run

Your brief injects the spine session's identities explicitly (`ossify-briefs.md`); that
session then creates and binds a **child Run** for item tasks, which does not reset
nested depth.

- child `task-create`, `worker-start`/`dispatch` and `check` always name
  `--run $CHILD_RUN_ID`;
- plan, gap, depth and other spine-level questions come up as `ask --run $PARENT_RUN_ID`;
- replies to item questions go back on each original child message id;
- its final completion uses the **injected parent** task and dispatch ids, settling
  your Dispatch while the child Run is still bound;
- the spine session is the only waiter on the child Run; you, on the parent.

The child Run keeps item plan traffic and item `worker_done` out of your inbox: you see
a batched plan relay, genuine spine-level decisions, and one final completion.

**Teardown is the pairs, not the Run.** The spine session releases every item pair
before its final `worker_done` and names the child Run id in that body. There is no
close-the-Run step: the CLI exposes none.

## 3. The round procedure, as the spine session runs it

1. Validate `SPINE.md`, the sidecar and the round's item set
   (`ossify-execution.md` §3).
2. Invoke the ossify lane in external-executor mode. ossify prepares every
   same-round worktree and handoff first, then hands over one request per item.
3. For each item, launch a **fresh implementer terminal** from that row's exact command
   — the verifier is not created yet; it has nothing to verify until step 5. Where a
   custom alias is required, create the terminal directly and inject the Dispatch.
4. Each implementer confirms its model, reads, and posts a detailed plan, then waits.
   Gather the round's plans into **one** ordered ask to you; return an independent
   approve-or-amend per item; reply on each original child id, before which no edit
   starts.
5. On each complete return, capture the item's four-part fingerprint, then create and
   dispatch that item's **fresh verifier terminal** from its row's exact command, in the
   same worktree, against the fixed all-claims procedure. `cannot determine` = fail.
6. On the **first** verifier failure, send one `ask --run $PARENT_RUN_ID` with the
   verifier's summary and three options —
   correct with the same pair, replace the pair, halt — and it **blocks: the pair idles**
   and nothing on that item moves until the reply. *Correct* is one consolidated
   correction to the same implementer, then the full recheck to the same verifier.
   *Replace* is the one exception to one pair per item: the old pair is released first,
   then a fresh pair at that item's ratified row, in the same worktree and at the
   branch, `HEAD` and staged tree the correction packet names, confirmed before any
   edit — never two pairs live on one item. A replacement at a **different** profile is
   a sidecar rewrite: the top rewrites the row, the operator ratifies it, the digest
   updates, and you revalidate before launching. A second failure asks again, with the
   same three options.
7. Initial gaps are handled inside the spine session: it asks you for the operator's
   answers, remains the handoff writer, appends clarifications, and re-requests the item
   within ossify's three-attempt cap.
8. Feed accepted results into the lane in declared decomposition order. Keep each pair
   until its item closes or escalates, then release it. **No terminal is ever
   transferred to another item.**

Same-round pairs may run concurrently. Closes and merges stay serial and the
round barrier is ossify's, unchanged.

## 4. The spine close is dispatched, and it comes next

The spine session stops at the final round barrier — where `/ossify:run-spine` hands
the baton to `/close <spine-id>` — and never runs the close on its own initiative.
When its `worker_done` lands, **you dispatch** `/ossify:close <spine-id>` to a close
session that is **always a fresh terminal** you create, never the spine driver's: it
creates nothing, runs the close, and returns what the close opened
(`ossify-pr-briefs.md`). You do not run it here — SKILL.md §6 lists `close` among the
dispatched commands, and the delegation floor keeps suites out of your session.

**The first close opens one PR per hosting repo and halts while any is open**,
recording nothing (`close/references/spine-close.md`); its `worker_done` names **every**
PR it opened, repo and number — or the single word `closed`, when every hosting repo
was remote-less and it recorded the spine outright.

**Then one work-PR session per returned PR**, each created in that PR's own
hosting-repo worktree and briefed with the two profiles you decided at the PR
transition (`ossify-execution.md` §5). It owns both PR seats in a child Run of its own,
relays one summary per round, and asks you for the merge word; you ask the operator,
and it merges bound to the SHA the reply names. `lifecycle.md` steps 8-12 are that
session's loop, not yours.

**Then, once every returned PR has merged, one record pass** — a second
`/ossify:close <spine-id>`, to another fresh close session. **Hold step 12's teardown —
worker release, branch deletion — until that pass returns:** it resolves the spine
branch again.

That second dispatch is **conditional and single**: it happens
only when the first returned at its open-PR halt naming at least one PR, and only once
every one of those has merged — one record pass per spine, never a scheduled step. A
first close that returned `closed` — every hosting repo remote-less, so it landed and
recorded outright — is the whole ceremony, and dispatching a second one against it is
a wrong turn, not a safety net.
