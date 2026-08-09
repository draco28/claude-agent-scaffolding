# Memory-bank harvest — spine close step 9

Depth for `spine-close.md` §9 and SKILL.md §5. This is the **only copy** of the
harvest ceremony: the payload shape, the two-file allowlist, the tagging
convention and the one-call rule live here and nowhere else.

The harvest is a **core row in both classes** (spec §6.1) — bone and flesh differ
in the depth of the optional rows, never in whether this one runs. What it does
is narrow and worth stating up front: it moves a handful of durable lines out of
artifacts nobody re-reads (`report.md`, `handoff.md`) and into the two live
memory-bank files that every future session loads. Everything else in the bank is
derived from the lean spec and is off limits here.

---

## 1. Where it sits, and why the order is what it is

Step 8 authors the retrospective. **Step 9 is this.** Step 10 is worktree +
branch cleanup. The harvest runs **before cleanup, always**.

**The reason is that cleanup is terminal, not that the inputs live in the
worktree.** They do not: `report.md` and `handoff.md` sit beside `spec.md` in the
work item's docs directory under the AI workspace (`work-item/SKILL.md` §7), which
worktree removal never touches. `oss worktree_remove` runs `git branch -d`, refuses
an unmerged branch at rc 8, and once it succeeds the branch is gone — so every step
that might still need to **halt** must run first. That is the whole ordering
argument; do not restate the false one.

**The harvest never removes a handoff.** It reads them and leaves them where they
are. Nothing in this release deletes a handoff at either scope.

---

## 2. Enumerate the inputs — this is the step that silently returns nothing

A ceremony that cannot find its inputs refuses everything, authors an empty
payload, and gets an honest `wrote 0` back. That reads exactly like "there was
nothing to harvest". Resolve the paths deliberately.

**The work items come from state:**

```bash
items="$(oss get "[.work_items[] | select(.spine==\"$spine_id\") | .id] | join(\" \")")"
[ -n "$items" ] || { echo "close: no work items recorded for $spine_id - halt"; exit 1; }
```

**Test the output, never the rc.** `oss get` is `jq -r` without `-e`: a `select`
matching nothing exits **0** with an empty string (`routing.md` §4).

**The directory comes from a glob, and it is hoisted once per spine.** Nothing in
state holds a spine slug, so the spine directory is recovered exactly as
`work-item-close.md` §1 **Route B** recovers it — including its ambiguity guard,
which is the part that matters:

```bash
ai_root="$(oss repo_root ai_workspace)"
parts="$(oss id_parse "$spine_id")" || parts=""
rel_id="r$(printf '%s\n' "$parts" | awk '{print $2}')"

matches="$(find "$ai_root/docs/specs/$rel_id" -maxdepth 1 -type d -name "$spine_id-*" 2>/dev/null)"
n="$(printf '%s\n' "$matches" | grep -c . || true)"
[ "$n" -eq 1 ] || { echo "close: expected exactly one spine dir for $spine_id, found $n - halt"; exit 1; }
spine_dir_abs="$matches"
```

Route B derives that directory from a **single work-item id**; running it
literally per item re-globs N times for one answer. Hoist it, then compose each
item's paths:

```text
<spine_dir_abs>/work-<wi-id>/report.md
<spine_dir_abs>/work-<wi-id>/handoff.md
```

`oss spine_dir "<release-id>" "<spine-id>" "<slug>"` re-composes the same path
**relatively** once the glob has recovered the slug, which makes it a useful
cross-check against `$spine_dir_abs`. Prefix it with `oss repo_root ai_workspace`;
it is never the way in.

A work item whose `report.md` is missing is **named, not skipped silently** — a
`complete` item with no report is a gap in the record, and the close summary is
where it belongs. (**The close summary** is the ceremony's final assistant
message, defined in `close/SKILL.md` §10 — a message, not a file. This reference
routes three things there; that section is what they route to.)

---

## 3. What `handoff` means in this release

**Only the per-work-item `handoff.md`** — the one the execution lane writes at
`<ai-workspace>/docs/specs/<release-id>/<spine-id>-<spine-slug>/work-<wi-id>/handoff.md`
(`work-item/references/handoff-contract.md`). Session handoffs are a different
artifact belonging to a `/handoff` redesign, and **this release ships no handoff
authoring at either scope** (`spine-close.md` §9). Scope the read to the
per-work-item files and do not go looking for session handoffs; there are none,
and a sweep that expects them reports an empty harvest as a finding.

Inside a handoff, the durable candidates are the appended **`## Clarifications`**
— the mid-flight answers to spec ambiguity (`handoff-contract.md` §3). The
retrospective reads those too, for a different purpose: the retro is this spine's
story, the memory bank is what the *next* spine needs to not re-learn.

---

## 4. Read `## 9. Suggestions for memory bank`, byte-exact

That heading is the report contract's, pinned in `work-item/references/report-contract.md`
§1, and it is matched **by exact string**. A section that reads "Memory bank
suggestions" is a section that never gets harvested. If a report is missing the
heading altogether, say so by name — a missing section reads as "not run", an
empty one reads as "considered, nothing to say", and only one of those is a
finding.

---

## 5. Categorise — two live files, and one thing that is not an append

| Candidate | Goes to |
|---|---|
| A caveat, a gotcha, an unverified claim, a landmine the next session will step on | `09-known-issues.md` |
| A decision with its rationale, a road not taken, a parked question | `10-decisions-log.md` |
| An **enforceable** pattern ("imports must…", "every handler shall…") | **neither — see below** |

`09-known-issues.md` is Tier 0 and loaded on every call; `10-decisions-log.md` is
on-demand (`start/references/memory-bank-brief.md` §1). Both are LIVE files —
dev-authored, never regenerated from the spec.

**An enforceable pattern is never a raw append.** It belongs in the
machine-checkable rules surface, and **rule authoring is deferred to Plan C2** —
this release ships none. Record the referral in the close summary so the pattern
is not lost, and do not smuggle it into `09` as prose; a rule filed as a caveat
reads as advice and is enforced by nobody.

**Everything else in the bank is derived from the lean spec and is off limits.**
`oss harvest_apply` rejects the **entire payload** at rc 2 if any item names a
target outside `09-known-issues.md` / `10-decisions-log.md` — no partial write, no
seeded empty file. That is a guard, not the plan: choose the target correctly.

---

## 6. Surface the candidates — one numbered list, every entry tagged

Present the full candidate list to the user as a numbered list, and **every
entry's first line starts with the literal `[report]` or `[handoff]`**:

```text
1. [report] r1.s2.w1 - the duplicate-suffix scheme is now owned in two places.
2. [handoff] r1.s2.w3 - anchors were confirmed case-folding; recorded as a
   clarification mid-dispatch, never written down anywhere durable.
```

**The tag is a trust-calibration signal, not decoration.** A report-origin
candidate was written by the agent that had just finished the code and is
grounded in a diff; a handoff-origin one comes out of conversational context and
is likelier to be a half-remembered intention. The user is calibrating on that
difference when they accept or reject, so the tag is on the **first** line, where
it cannot be missed.

Then consume the response per candidate: **accept**, **edit** (the user's text
wins verbatim), or **reject**. Do not argue a rejection back, and do not fold two
candidates into one to make the list shorter.

---

## 7. Apply the accepted array in ONE call

```text
oss harvest_apply '<payload-json>'
```

The payload is a JSON array of items:

```json
[{"source": "report|handoff",
  "source_id": "<work-item id or handoff filename>",
  "target_file": "09-known-issues.md|10-decisions-log.md",
  "text": "<markdown, may be multi-line>"}]
```

**One call, with everything accepted in it.** Whole-payload rejection is only
meaningful over the whole payload; N calls turn one refusal into N partial states
and give the user N count lines to reconcile.

The rc contract, and each arm means something different:

| rc | Meaning |
|---|---|
| **0** | at least one entry was written, **or** the payload was empty |
| **1** | the payload was non-empty and **nothing** was written — every item was already there, or the memory-bank directory did not resolve |
| **2** | the payload was **rejected** — bad shape, a `source` outside `report`/`handoff`, or a target outside the allowlist. Nothing was written and nothing was created |

Both rc 0 and rc 1 echo `harvest: wrote <N>, skipped <M>` on stdout. **rc 1 is
not a failure to fix by re-running** — an all-duplicate payload is the honest
answer that this spine's suggestions are already in the bank. rc 2 *is* yours to
fix: correct the payload and call again.

Idempotency is an exact-entry match on a content hash carried in the provenance
trailer each entry gets:

```text
<!-- ossify harvest: <source-id>, <date>; source: report|handoff; h:<hash> -->
```

so re-running the harvest after a halt cannot duplicate anything, and an entry
whose text merely *resembles* an existing one is still a new entry.

**`oss harvest_dir`** echoes the resolved memory-bank directory and is worth
running first when a harvest reports a count you did not expect — it is
manifest-routed, and it returns rc 1 rather than guessing when the routed path
cannot be resolved.

---

## 8. Record the outcomes — and where they go

Four buckets, one line each: **applied**, **applied-with-edit**,
**left-in-handoff** (a rejection that the user wants kept where it is), and
**dropped**.

**They go in the harvest's own return and the close summary — not in the
retrospective.** The retro is authored at **step 8** and is a completed artifact
by the time this step starts; nothing here reopens it. Writing outcomes "into the
retrospective" means editing a document the ceremony already finished, which is
why this file names the destination instead of leaving it to be inferred.

---

## 9. Anti-patterns

- **Cleaning up before the harvest.** Step 10 is terminal (§1).
- **Justifying that order with "the report is in the worktree".** It is not (§1).
- **Enumerating from the directory tree instead of from state**, or trusting
  `oss get`'s rc instead of its output (§2).
- **Re-globbing the spine directory per work item**, or `head -1`-ing an
  ambiguous glob instead of halting (§2).
- **Hunting for session handoffs.** This release authors none (§3).
- **Paraphrasing the `## 9.` heading** or accepting a renamed one (§4).
- **Appending an enforceable pattern as prose** instead of recording the C2
  rule-authoring referral (§5).
- **Naming any target outside the two live files.** The whole payload is
  rejected, and the fix is the target, not a retry (§5).
- **Dropping the `[report]` / `[handoff]` tag**, or moving it off the first line
  (§6).
- **Calling `oss harvest_apply` once per candidate** (§7).
- **Treating rc 1 as a failure to re-run** (§7).
- **Editing an accepted candidate's text on the user's behalf** (§6).
- **Recording the outcomes into the retrospective** authored at step 8 (§8).
