# External-executor mode — the caller-supplied execution seam

Depth for `round-orchestration.md` §5. Reached **only** from
`/run-spine <spine-id> --external-executor`. Without the flag none of this
applies and the lane dispatches its own nested implementer exactly as it always
has; that path is not deprecated, not degraded, and not the fallback for
anything here.

This mode is **provider-neutral by construction.** It names no orchestrator, no
product, no terminal, no model and no alias. It defines two records and a
handshake; who executes the work between them is entirely the caller's business,
and ossify neither knows nor asks. If you find yourself about to write the name
of a specific tool into this file, you have started designing the caller.

> **Editing note.** This file is asserted to contain no subagent *invocation*
> form — the `Task` tool's call syntax, an `Agent` call, or the argument that
> names a registered subagent. That is deliberate and it is checked
> (`tests/test-external-executor-contract.sh`). State the prohibition in words;
> do not paste the call shape you are prohibiting.

---

## 1. What changes, and what does not

External mode replaces **one step** of the lane: the dispatch in
`round-orchestration.md` §5. Everything on either side of that step is the same
document it was.

| Still owned by the lane, unchanged | Handed to the caller |
|---|---|
| the spine-branch cut and checkout (§2) | executing one work item against its handoff |
| the per-item worktree, `oss work_item_exec`, `oss work_item_status` (§3) | |
| authoring every `handoff.md` (§4) | |
| the return contract it accepts back (`references/returns.md`) | |
| the close, the commit, the merge, the round barrier (§7) | |
| the 3-iteration cap and the gap loop (§6) | |
| operator ownership of every recovery choice | |

**The lane does not call a subagent in this mode**, and it does not fall back to
calling one. The caller's procedure is a requirement, not a preference: a
`--external-executor` run with no caller-supplied procedure in scope is a
refusal before the spine-branch cut, not a run that quietly reverts to the
default.

---

## 2. Round sequencing

Do all of §3 and §4 for **every item in the round, in declared decomposition
order, before building any request.** Worktrees created and journaled, handoffs
authored, specs confirmed to parse — the whole round's preparation lands first.

Then build one request per item, still in declared order, and invoke the
caller-supplied procedure **once for the round**, handing it the whole set.

The caller may execute the round's requests concurrently; nothing here requires
otherwise, and §7's note that items within a round are parallel by construction
is exactly as true through this seam as through the default one. What stays
serial is everything after the returns — see §5.

---

## 3. The request record

One per work item, every field required, no field optional and none added:

```yaml
external_execution_request:
  work_item_id: r7.s2.w1
  target_repo: canonical
  handoff_path: /abs/docs/specs/r7/r7.s2-schema/work-r7.s2.w1/handoff.md
  spec_path: /abs/docs/specs/r7/r7.s2-schema/work-r7.s2.w1/spec.md
  worktree_path: /abs/project/.worktrees/r7.s2.w1-schema
  branch: work/r7.s2.w1-schema
  base_sha: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
```

Every value comes from what §3 and §4 just did — `worktree_path` and `branch`
are read back off the worktree, never re-derived, for the same reason §3 gives.
Paths are absolute. The request carries no instructions: the handoff is the
contract, and restating rules here would create a third copy that drifts from
both it and the implementer's own body.

---

## 4. The result record

The caller returns exactly one of these per request:

```yaml
external_execution_result:
  work_item_id: r7.s2.w1
  coordinator_verdict: accepted
  implementer_return:
    mode: complete
    report_path: /abs/docs/specs/r7/r7.s2-schema/work-r7.s2.w1/report.md
    summary: All declared acceptance criteria pass
    stage_status: all_staged
  tree_oid: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
  head_oid: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  report_oid: cccccccccccccccccccccccccccccccccccccccc
  spec_oid: dddddddddddddddddddddddddddddddddddddddd
```

`implementer_return` is ossify's **existing** complete-return object
(`references/returns.md` §2), unextended. External mode adds no third return
mode and widens no enum; a caller that needs to say something else says it
in `summary` and in the report, exactly as every implementer does.

`coordinator_verdict` is the caller's own statement that it accepted the work it
is handing back. It is not a gate ossify delegates — the gate is still
`close`'s — it is the caller declaring that what follows is a result rather
than a fragment.

The four `*_oid` values are the item's identity at the moment the caller
finished: the staged index (`git write-tree`), `HEAD`, and the blob ids of
`report.md` and `spec.md`. They are the same four components
`close/references/work-item-close.md` §2 fingerprints, and for the same reason.

---

## 5. Validating the round's results

Five checks before any result reaches close. **Checks 1, 2, 3 and 5 halt;
check 4 routes.**

1. **Item-set equality.** Exactly one result for every request — no missing
   item, no extra item, no duplicate `work_item_id`.
2. **Field parity.** Every result carries every field in §4 and no other, and
   `implementer_return` carries exactly the four keys of the complete return.
3. **`coordinator_verdict` is `accepted`.** Any other value, including one that
   reads as a softer accept, is not an accepted result.
4. **`mode` is `complete` — or the item enters the gap loop.** This one is a
   route, not a halt. A `gaps-surfaced` return goes to
   `round-orchestration.md` §6 exactly as it always has: the lane surfaces the
   gaps, appends the clarifications to that item's handoff, and re-dispatches
   the same live implementer within the 3-iteration cap. It **never reaches
   close as a result** — the round continues, and the item returns as a §4
   result record when it completes.
5. **The fingerprint still holds.** Recompute all four ids from the worktree and
   the two documents, and compare against what the result declared. A mismatch
   means the item moved after the caller finished — halt and name which of the
   four changed.

**Checks 1, 2, 3 and 5 are terminal.** A malformed, non-accepted, stale or
mismatched result halts the round; it never degrades into the default nested
path, and there is no stop-and-reinvoke step to reach for. The lane holds the
state lock and the operator owns the recovery choice, exactly as everywhere
else. Check 4 is the exception and it is not a halt: an under-specified item is
a round-trip the lane already knows how to make.

Results that pass are fed into close **in declared decomposition order, never
arrival order** — `round-orchestration.md` §7's rule, unchanged and doubly
relevant here because a concurrent caller makes out-of-order arrival the normal
case. Closes and merges stay serial; the round barrier is untouched.

---

## 6. Layer 4 under this mode

External mode **runs Layer 4 inline** — the lenses applied by the close itself,
per `close/references/impl-check.md` §4b's inline path — even where the
delegated path's own conditions would otherwise be satisfied. The reason is
arithmetic, not doctrine: the caller has already put a reviewer of its own on
this item, and following it with a fan-out of hidden delegated agents spends a
second review nobody asked for on a diff that has just been read.

The lenses, the finding schema and the verdict rule are `impl-check.md`'s and do
not change. Nothing about the default no-flag path changes either — it keeps
choosing the delegated path under exactly the conditions it chose it under
before.

---

## 7. Correcting an item without re-running the command

A result that close rejects cannot simply be re-dispatched: ordinary
`/work-item` begins with a clean-tree pre-flight that correctly refuses a
worktree holding staged output. `references/correction-continuation.md` is the
provider-neutral continuation for that case, and it goes to the **same**
executor the caller used for that item. Everything else about recovery —
who chooses, what the menu offers, the second-failure escalation — is
`close/references/impl-check.md` §6's and stays there.
