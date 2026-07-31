# Demo-line amendments (supersede / retire)

Depth for SKILL.md §8e. A spine's plan may declare that it changes lines the
ledger already carries. Amendments are **planned here** and **applied at that
spine's close**.

---

## 1. The two planning verbs

```bash
oss ledger_supersede <line-id> <by-spine> "<reason>"
oss ledger_retire    <line-id> <by-spine> "<reason>"
```

| Verb | Means | Use when |
|---|---|---|
| **supersede** | This line is replaced by a line this spine adds | The flow still exists but is reached differently — a redesign, a moved entry point, a deepening pass that subsumes the old check |
| **retire** | This line describes a flow the product no longer has | The capability was removed, or the journey it walked no longer exists |

Both are keyed by the **line id** (`d3`, `d7`) — the value `oss ledger_add_auto` /
`ledger_add_user` printed when the line was created. Not the text. An unknown line
id exits **7** and writes nothing.

Find the id before you amend:

```bash
oss get '[.demo_ledger[] | {id, type, status, text, source_spine}]'
```

---

## 2. Archived, never deleted

Neither verb removes anything. Both set the line's `status` (`superseded` /
`retired`) and record **who** did it (`status_by` = the superseding spine) and
**why** (`status_reason`). The line stays in `demo_ledger` forever.

That is deliberate. The ledger is the product's demo history: it is how a release
retro can say *"the CLI entry point was the journey until `r2.s1` replaced it with
the ticket"*. A deleted line takes that with it, and it also takes the audit trail
for a line someone removed because it was inconvenient.

Consequences worth knowing:

- `oss ledger_active_auto` returns only `active` `auto:` lines. A **planned**
  amendment does not change that — the line keeps running until this spine's
  close applies it, so a sibling spine closing in between still exercises the
  flow. Coverage is never dropped for work that has not landed.
- The release-close walkthrough uses the **amended** set.
- Counting `.demo_ledger | length` counts history, not the live suite. Filter on
  `.status == "active"` when you want the live set.

---

## 3. Every amendment names a reason, and the reason is a change

The reason field is not decoration — it is what a reader six months out has. Write
the **change that caused it**, not the feeling:

| Bad reason | Good reason |
|---|---|
| "no longer needed" | "the order ticket replaced the CLI entry point in r2.s1" |
| "flaky" | "…" — see §4; a flaky line is not an amendment |
| "cleanup" | "the CSV export flow was removed by this spine" |
| "superseded" | "subsumed by the p50 latency bound this spine adds" |

**A superseding spine must actually add the replacement.** Superseding a line and
contributing nothing in its place is a retire wearing the wrong verb, and it
quietly shrinks the demo's coverage of the product.

`<by-spine>` **is validated against known spines**: an unknown spine id exits
**7** and writes nothing. This is not cosmetic — `<by-spine>` is the join key
`close` matches on to find and apply this spine's pending amendments, so a
typo'd id here would mean the amendment is never applied by any close, silently
and forever. Paste the id you resolved at pre-flight (§3), do not retype it.

---

## 4. Quarantine is not a planning verb

```bash
oss ledger_quarantine <line-id> "<reason>" <release>    # NOT a planning action
```

Quarantine exists for a line failing for causes **unrelated to any open spine** —
an upstream outage, a broken CI image. It is a **parking ticket, not a shrug**: a
quarantined line is state-recorded, visible in `doctor`, skipped by the runner, and
**must be fixed or retired by the next release close**. The `<release>` argument
is what makes that enforceable — it is the parking ticket's date. Omit it and the
next release close has no way to tell which quarantines are overdue.

It belongs to `close` and `doctor`, at the moment a line actually fails. Do not
reach for it at planning time to make an inconvenient line go away — that is
exactly the misuse the "parking ticket" framing exists to name. If a line is wrong,
supersede or retire it with a reason.

---

## 5. When to amend, and when not to

**Amend when:**

- this spine changes the flow an existing line walks (supersede);
- this spine removes the capability a line demonstrates (retire);
- a deepening pass replaces a coarse line with a measured one (supersede);
- the ledger will not fit the release's `ledger_budget` and the release-planning
  decision was **prune** — retire the lines that no longer earn their runtime,
  with the budget as the recorded reason.

**Do not amend when:**

- the line is slow but still true — that is a budget conversation at
  `plan-release`, or a parallelize decision, not a retire;
- the line is failing because *this spine broke it* — that is a bug in the spine,
  and the cumulative demo just did its job;
- the line is inconvenient to keep green;
- you did not write it and are not sure why it exists. Ask. `source_spine` and the
  spine's retro say who to ask.

The third and fourth are the failure mode: a ledger that shrinks whenever it is
inconvenient stops being evidence about the product.

---

## 6. Anti-patterns

- **Amending by text instead of by line id** (§1).
- **Superseding without adding the replacement** (§3).
- **Quarantining at planning time** (§4).
- **A reason that names a feeling instead of a change** (§3).
- **Retiring a failing line instead of fixing the spine that broke it** (§5).
- **Planning an amendment and never closing the spine.** A pending amendment is
  consumed by `close`. If the spine is replanned or abandoned, clear it with
  `oss ledger_unplan <line-id>` — otherwise it sits in state waiting for a close
  that will never come, and `oss doctor` will keep reporting it. There is no
  `reactivate` for an amendment `close` has already applied: at that point the
  flow really is gone and the ledger is recording history.
- **Deleting from `demo_ledger` directly.** There is no such operation, and there
  should not be.
