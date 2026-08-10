# Round orchestration — the execution lane

Depth for SKILL.md §1, Mode B. This is the **caller's** half of the contract: the
lane that walks one spine's rounds, spawns a worktree per work item, dispatches
one worker per item, and owns every boundary the implementer is forbidden to
cross — the clarification loop, the commit, the merge.

It runs in the orchestrator's session, holding the state lock (spec §9.2). **An
implementer never runs any of it**, and `Task` is on the implementer's NEVER list
precisely so it cannot try.

Read this when you are driving a spine. If you are the worker executing one
handoff, this file is context, not instruction — your contract is SKILL.md §3-§9.

---

## 1. Where the rounds come from

The work-item rounds live in the **spine plan document** that `plan-spine`
authored, under:

```bash
# /run-spine hands you ONLY the spine id. The release id and the slug are not
# arguments — derive one, recover the other, exactly as close does (Route B in
# `close/references/work-item-close.md` §1, inlined in `harvest.md` §2).
ai_root="$(oss repo_root ai_workspace)"
rel_id="r$(oss id_parse "$spine_id" | awk '{print $2}')"       # r1.s2 -> r1
matches="$(find "$ai_root/docs/specs/$rel_id" -maxdepth 1 -type d -name "$spine_id-*" 2>/dev/null)"
n="$(printf '%s\n' "$matches" | grep -c . || true)"
[ "$n" -eq 1 ] || { echo "halt: expected exactly one spine dir for $spine_id, found $n"; exit 1; }
spine_dir_abs="$matches"
spine_slug="${spine_dir_abs##*/}"; spine_slug="${spine_slug#$spine_id-}"
```

**Nothing in state holds the slug**, so the directory is recovered by glob with
an ambiguity guard and the slug falls out of the directory name. Inventing it
from the spine's `name`, or asking the user, produces a path that does not match
what `plan-spine` actually wrote.

**`oss spine_dir` returns a RELATIVE path** (`docs/specs/<release-id>/<spine-id>-<slug>`)
— it must be prefixed with the ai_workspace root, exactly as every sibling
consumer in `close` does. Used bare it resolves against whatever directory the
agent happens to be standing in, which during a round is usually a worktree
under the canonical repo — so the read silently misses, or worse, finds a
different project's file. (`oss release_dir <release-id>` returns the release
level of the same tree already absolute, if that is all you need.)

Read them from there. Two ways to get this wrong, both silent:

- **Not from `releases[].spine_dag`.** That field is `plan-release`'s
  **inter-spine** DAG — it sequences whole *spines*. Reading it here yields spine
  ids where work-item ids are needed, and the mistake surfaces as an empty or
  nonsensical round list, not as an error.
  `plan-spine/references/dag-rounds.md` draws the line: same idea, finer
  altitude, different owner.
- **Not re-derived here.** The rounds are planning output. If reality disagrees
  with the plan, that is a replan — go back to `plan-spine`, re-record, and come
  back. Improvising a new order at execution time produces a spine that is wrong
  in a way nobody can see later (`dag-rounds.md` §7).

**No state field holds the work-item rounds.** `work_items[]` carries
`{spine, title, target_repo, status, created_at}`, plus the
`{branch, worktree_path, base_sha}` this lane writes — no dependency key, no
round key. Persisting the round structure as state is **deferred**; until it
lands the plan document is the only record. Say so if a user asks where the
rounds are stored; do not imply the read is machine-backed.

---

## 2. Before round 1 — cut **and check out** the spine integration branch

Once per spine — but **this block runs again on every `/run-spine`**, so it has
to be safe to re-enter after an earlier invocation halted:

```bash
canonical="$(oss repo_root canonical)"
[ -z "$(git -C "$canonical" status --porcelain)" ] || { echo "canonical is dirty - halt"; exit 1; }
spine_branch="$(oss branch_name "<spine-id>" "<spine-slug>")"
if git -C "$canonical" show-ref --verify --quiet "refs/heads/$spine_branch"; then
  git -C "$canonical" checkout -q "$spine_branch" \
    || { echo "cannot check out the existing '$spine_branch' - halt"; exit 1; }
else
  base_branch="$(git -C "$canonical" rev-parse --abbrev-ref HEAD)"
  [ "$base_branch" != "HEAD" ] \
    || { echo "canonical is in DETACHED HEAD - no base_branch to record - halt"; exit 1; }
  git -C "$canonical" checkout -q -b "$spine_branch"
fi
```

Five things here, each load-bearing:

**`oss repo_root canonical`, never a bare `<canonical>` placeholder.** The verb
reads `.canonical.root` from the pairing manifest and fails rc 2 rather than
defaulting to the working directory. A placeholder that a reader fills in by hand
is how a spine gets built in whichever repo the session happened to start in.

**`checkout -b`, not `branch`.** `git branch` creates the ref and leaves you
standing where you were. Canonical then stays on its previous branch for the
whole spine, and every consequence is rc 0:

| Step | With the checkout | With `git branch` only |
|---|---|---|
| Work-item merge (`close`) | lands on the spine branch | lands on the *previous* branch, rc 0 |
| Spine-close merge (`close`) | a real merge | "Already up to date", rc 0 |
| `oss worktree_remove` | deletes a merged branch | deletes it too — it *is* merged, into the wrong target |
| Cumulative demo | measures the spine's work | measures a tree assembled by accident, green |

Nothing in that column reports a failure. **Canonical stays parked on
`$spine_branch` for the duration of the spine**, and spine close is what moves it
off.

**The existing-branch arm is what makes `/run-spine` re-enterable.** A first
invocation that halts — a gap returned, a round deferred, a session interrupted —
leaves the spine branch cut and its work items journaled. The next invocation has
to land back on that branch: an unconditional `checkout -b` exits non-zero the
second time and takes the lane down at its very first step, so the durable run
the command just created becomes unreachable by the command that created it.
Reuse the ref; never re-cut it.

**Record `base_branch` in the plan doc's spine-context section** on the run that
cuts the branch, and carry it into every handoff (`handoff-contract.md` §2).
Spine close switches back to it before merging the spine branch in. No state
field holds it, and guessing the default branch merges a spine into the wrong
line of development. If it cannot be resolved later, that close **halts**. The
resume arm above **deliberately does not re-derive it** — HEAD is the spine
branch by then, so re-deriving would record the spine as its own base. `SPINE.md`
is where it already lives, and spine close reads it from there.

**The slug is not in state.** Spines store `name`, work items store `title`;
neither is a kebab slug, and nothing persists one. `plan-spine` minted the spine
slug when it created the spine directory — **recover it from that directory
name** rather than re-kebabing `name`, so the branch and the directory cannot
drift apart. For work items there is no such anchor, which is exactly why §3
writes the branch it actually created into state.

---

## 3. Per work item in the round

**Before spawning anything: confirm the round's specs exist and parse.**
`plan-spine` may legitimately defer a later round's specs until that round starts
(`plan-spine/references/spec-authoring.md` §3), so for round *K > 1* the spec may
not have been authored yet:

```bash
spec="$spine_dir_abs/work-<wi-id>/spec.md"
[ -f "$spec" ] || { echo "halt: no spec for <wi-id> - re-enter /plan-spine for this round"; exit 1; }
# Test the OUTPUT, not the rc. `oss verify_acs` returns 0 on a spec that yields
# zero parseable rows — the same empty-but-successful shape `report_cross_check`
# guards with `[ -n "$rows" ] || return 2`. An `|| { … }` here cannot fire for
# the condition its own message names, which is a guard that reads as coverage.
rows="$(oss verify_acs "$spec")" || { echo "halt: <wi-id>'s spec could not be read"; exit 1; }
[ -n "$rows" ] || { echo "halt: <wi-id>'s spec parses to no ACs - grammar drift, or it was never authored"; exit 1; }
```

**This lane does not author specs** — it dispatches workers who read them. A
missing spec means the round was dispatched before it was planned, so the fix is
to re-enter `plan-spine` for this round, not to write one here. Checked now, the
recovery is one skill invocation; left to the worker's Gate 2 it comes back as a
gaps-mode return that reads like an under-specified work item rather than a
skipped planning step.

Then, in **declared decomposition order** — the order the plan lists them, never
the order returns arrive.

```bash
target_repo="$(oss get '.work_items[] | select(.id=="<wi-id>") | .target_repo')"
# FIRST — before anything is created or journaled. `_oss_repo_root` accepts
# ai_workspace and private_core, so worktree_add would succeed against them.
[ "$target_repo" = "canonical" ] \
  || { echo "halt: work item <wi-id> targets '$target_repo'; only canonical executes in this release"; exit 1; }
wt="$(oss worktree_add "$target_repo" "<wi-id>" "<wi-slug>" "$spine_branch")"
branch="$(git -C "$wt" rev-parse --abbrev-ref HEAD)"
oss work_item_exec "<wi-id>" "$branch" "$wt" "$(git -C "$wt" rev-parse HEAD)"
oss work_item_status "<wi-id>" active
```

**The order of those two lines is the whole guard.** Placed after
`worktree_add`, it fires having already created the worktree in the wrong repo,
journaled its path through `work_item_exec`, and marked the item `active` — so
the "prevention" is a report of damage already done, and undoing it means
removing a worktree and reversing two state mutations.

- `oss worktree_add` derives and cuts `work/<wi-id>-<slug>` internally and echoes
  the worktree's absolute path. Its **stdout is its return value** — capture it,
  do not let anything else write to that stream.
- **Read the branch back off the worktree; do not re-derive it.** The name git
  actually checked out is the only version that cannot be wrong.
- **`oss work_item_exec` is load-bearing beyond bookkeeping.** It persists
  `branch`, `worktree_path` and `base_sha` into state, and the work-item close
  layer reads `branch` back from there to pick its merge target. Close is invoked
  with an id and derives its scope from the id's shape — it has no slug and
  cannot re-derive the branch. Skip this call and the merge target is
  unrecoverable.
- **`target_repo` comes from state, not from you**, and **only `canonical` is a
  supported execution target today.** Cross-repo execution is a later release;
  the field is carried now so that release changes one resolver rather than every
  call site.

  **The halt is yours to make — the lib will not make it for you**, which is
  why the assertion is the first line of the spawn block above rather than a
  note here. `_oss_repo_root` accepts `canonical`, `ai_workspace` and
  `private_core`, so `oss worktree_add ai_workspace …` **returns rc 0 and
  creates a worktree inside the AI workspace** (reproduced). `private_core` is
  unconfigured in a normal manifest and does fail at rc 2, which is what makes
  the gap easy to miss: two of the three unsupported values behave as
  documented and the third does not.

  Skipped, the failure is quiet and awkward to undo: the work lands in a
  worktree under the AI workspace, `.worktrees/` appears in the repo that holds
  the specs, and the spine's merge step then looks for a branch in canonical
  that was never cut there.

---

## 4. Author the handoff

One `handoff.md` per work item, authored **against
`references/handoff-contract.md`** — its twelve sections, in order, no template
rendering. It goes in the work item's own directory, beside the `spec.md`
`plan-spine` wrote:

```text
<ai-workspace>/docs/specs/<release-id>/<spine-id>-<spine-slug>/work-<wi-id>/handoff.md
```

**Do not pre-place a `report.md`.** The implementer authors it, and its own
contract tells it there is no placeholder to fill and to prefer Edit over Write on
a file that already exists. An orchestrator-created empty file puts the worker in
conflict with its own binding prose at the moment it writes the report. Nothing in
its pre-flight expects the file to exist.

---

## 5. Dispatch

```text
Task(subagent_type="ossify:implementer-agent", prompt=<invocation block naming the absolute handoff path>)
```

**Never pass the Task tool's `isolation: "worktree"`.** The worktree already
exists — you created it in §3, in a different repo, at a path the handoff names.
Letting the harness make its own would run the item somewhere the merge never
looks and silently discard the work.

The prompt names the absolute handoff path and nothing else load-bearing. Every
behavioural rule the worker needs is in its system prompt (SKILL.md) and in the
handoff; restating rules in the invocation block creates a third copy that drifts
from both.

---

## 6. Handling the return

Two shapes come back on the normal path (`references/returns.md`). Route on
`mode` — and treat anything that is neither as a third, explicitly handled case
(below), never as a shape to be salvaged.

**`gaps-surfaced`** — pre-flight stopped the run and no work was done.

1. Surface the gaps to the user **grouped blocking-first**; nice-to-haves ride
   along so one round-trip answers both.
2. Capture the answers.
3. **Append a `## Clarifications` section to the handoff doc.** Not to the
   invocation block, not to the spec. The worker re-reads the handoff end to end
   on every dispatch, and that re-read is exactly how the resolutions reach it —
   a fresh subagent has no memory of the previous attempt.
4. Re-dispatch.

**The 3-iteration cap is orchestrator-side and binding** (spec §6): after three
total dispatches of one work item with no `complete` return, **stop**. Surface the
accumulated gap list and escalate to the user — the item is under-specified and
another round-trip will not fix it. **The worker never counts iterations**; it
cannot, because each dispatch is a fresh context that has no idea it is the third.
The count lives here or nowhere.

**`complete`** — the execution loop ran to the end. Hand the item to the work-item
close layer (`close`), which runs the gate, commits in the worktree, and merges
`work/<wi-id>-<slug>` into the spine branch you are parked on.

`complete` fires **even when verification failed** — `mode` reports the loop, not
the AC outcomes. Read `summary` and the report before deciding anything; a
`complete` return is not a green gate, and the gate is close's to run, not yours.

**Anything else — malformed, crashed, or timed out.** A payload that is not one
of the two shapes (unparseable, missing `mode`, a `mode` outside the enum, an
empty return, a subagent that died mid-run) is a **third case with its own
handling**, not a `complete` with rough edges:

1. **Do not parse around it.** Do not infer the outcome from prose in the
   payload, do not go read the worktree to decide whether it "basically
   finished", and do not treat a missing `report_path` as a green gate. A broken
   envelope means you do not know what state the work item is in, and guessing
   is how unverified work reaches a merge.
2. **Check the worktree BEFORE re-dispatching** — a crash after the worker
   started editing leaves it dirty, and a re-dispatch cannot recover from that:

   ```bash
   [ -z "$(git -C "$wt" status --porcelain)" ] || { echo "halt: <wi-id>'s worktree is dirty after a broken return"; exit 1; }
   ```

   **Two different dirty worktrees reach you by two different routes, and only
   one of them lands here.** A worktree that was *already* dirty when the worker
   reached pre-flight never produces a broken envelope at all: Gate 3 requires a
   clean worktree and SKILL.md §10 forbids the worker from tidying one, so it
   returns a **well-formed `gaps-surfaced`** envelope and you are in §5, not
   here. The halt above is for the other route — a worker that crashed
   **mid-edit**, leaving the worktree dirty *and* returning no payload. That is
   the case this step exists for, and it does fire.

   Re-dispatching into it cannot converge: every retry fails Gate 3 for a
   condition no clarification can answer, and burns the 3-dispatch cap. **Halt
   here and surface the dirty worktree to the user** — respawning it or keeping
   the partial work is their call, and neither is yours to make silently.

3. **Only if the worktree is clean, re-dispatch once** on the same handoff,
   unchanged. A crash or timeout with nothing written is usually transient, and
   the worker re-reads the handoff end to end anyway.
4. **If the second dispatch also returns a broken envelope, halt and surface it**
   to the user with the raw payload. This counts against the 3-iteration cap
   like any other dispatch.

The worktree is left exactly as the worker left it. Do not clean it up — its
state is the evidence for diagnosing what happened.

---

## 7. The round barrier

**Every work item in a round reaches `complete` before the next round starts** —
strict-order verification, spec §6. A work item still `active` at the barrier
**halts the round**; name it and stop.

The barrier is what the DAG's edges bought. Round *K+1*'s items were declared to
depend on round *K*'s, so starting one early means building against a seam that is
not merged yet — which fails as a confusing compile error inside a worker that has
no way to know why.

Items *within* a round are parallel by construction, and dispatching them
concurrently is fine. Their merges are not parallel: each one lands on the spine
branch through close, one at a time, and a conflict halts (never auto-resolve).

**Returns are processed in declared decomposition order, never arrival order.**
§3 says this about the *spawn* step, where it is nearly free — no returns exist
yet. It binds here, where it costs something: when a concurrent round's items
come back out of order, **work item N+1 is not verified, closed or merged until
N is fully committed and merged**. Hold the early return and wait.

This is spec §6's strict-order verification, and dispatching concurrently is
exactly what makes it easy to violate — an orchestrator that closes items as
they arrive is following §3 to the letter and breaking the contract anyway. The
DAG guarantees the items do not depend on each other *logically*; it says
nothing about two of them touching the same file, which is what serial merges
onto one spine branch protect against.

**When the final round clears this barrier, the spine is ready for
`/close <spine-id>`.** That is where this lane ends — hand the baton over
explicitly rather than stopping silently.

---

## 8. What is not covered by any test

Stated plainly so nobody infers coverage that does not exist:

**The dispatch loop, the 3-iteration cap and the round barrier are prose
contracts with no executable surface.** Nothing asserts that a fourth dispatch
does not happen, or that a round waits for its stragglers. No eval fixture
exercises them either.

The mechanical half *is* covered — `tests/test-worktree.sh` asserts that a
worktree spawned off the spine branch starts at the spine branch's tip, that two
work items in one spine get distinct branches and distinct worktrees, and that a
work-item branch merged while canonical is parked on the spine branch is
**reachable from the spine branch afterwards** (with a negative control proving
the assertion fails when canonical is parked anywhere else).

A bash test asserting agent behaviour here would be testing a fixture, not the
contract. The honest statement is that the judgment half is uncovered.

---

## 9. Anti-patterns

- **`git branch` without the checkout** (§2). The whole failure chain is rc 0.
- **Reading rounds from `releases[].spine_dag`**, or re-deriving them (§1).
- **Skipping `oss work_item_exec`** because the worktree path is already in
  scope. Close cannot recover the branch without it (§3).
- **Passing `isolation: "worktree"` to Task** (§5).
- **Appending clarifications anywhere but the handoff** (§6).
- **Counting iterations in the worker**, or expecting it to (§6).
- **Pre-placing `report.md`** (§4).
- **Starting round *K+1* with an `active` item behind you** (§7).
- **Committing inside the worktree yourself.** The implementer stages; the
  work-item close layer commits, after its gate. A commit here is a commit that
  skipped the gate.
