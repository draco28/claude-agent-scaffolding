---
name: domain-modeling
description: Build and sharpen a project's domain model as you design. Use when discussing what a codebase's terms actually mean, when a term is fuzzy or overloaded, when writing or editing a CONTEXT.md glossary, or when recording an architecture decision as an ADR. Triggers on "what do we call this", "that term is overloaded", "add this to the glossary", "write a CONTEXT.md", "should this be an ADR", "record this decision", "domain model", "ubiquitous language".
---

# Domain modeling

Actively build and sharpen the project's domain model while you design: challenge terms,
invent edge-case scenarios, and write the glossary and the decisions down the moment they
crystallise.

This is the *active* discipline. Merely reading `CONTEXT.md` to pick up the right nouns is
not this skill — that is a one-line habit any skill can have. This skill is for when you are
**changing** the model, not consuming it.

## Where the model lives

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

A `CONTEXT-MAP.md` at the root means the repo has more than one context; the map says where
each lives and how they relate:

```
/
├── CONTEXT-MAP.md
├── docs/adr/                    ← system-wide decisions
└── src/
    ├── ordering/
    │   ├── CONTEXT.md
    │   └── docs/adr/            ← context-specific decisions
    └── billing/
        ├── CONTEXT.md
        └── docs/adr/
```

**Create files lazily** — only when there is something to write. No `CONTEXT.md` yet? Create
it when the first term is resolved. No `docs/adr/` yet? Create it when the first ADR is
needed. Do not scaffold empty structure.

**Projects with their own home for this.** A repo running an ossify lifecycle, or a dual-repo
workspace, may already keep its domain language in a memory-bank document rather than at the
repo root. Where such a home exists, point at it and write there instead of creating a
competing `CONTEXT.md`. One glossary per project; a second one is drift with a filename.

## During a session

**Challenge against the glossary.** When a term conflicts with the language already recorded,
say so immediately. *"Your glossary defines cancellation as X, but you seem to mean Y. Which
is it?"*

**Sharpen fuzzy language.** When a word is vague or carries two meanings, propose the precise
one. *"You're saying account — do you mean the Customer or the User? Those are different
things."*

**Discuss concrete scenarios.** When domain relationships are on the table, stress-test them
with specific cases. Invent scenarios that probe the edges and force precision about where
one concept stops and the next begins.

**Cross-reference with the code.** When the user states how something works, check whether
the code agrees. Surface any contradiction. *"Your code cancels whole Orders, but you just
said partial cancellation is possible. Which is right?"*

**Update the glossary inline.** When a term is resolved, write it down right then. Do not
batch these up — a batch is a list of things you will paraphrase later from memory. The
format is in `references/context-format.md`.

`CONTEXT.md` must be **totally devoid of implementation details**. It is not a spec, not a
scratch pad, and not a home for implementation decisions. It is a glossary and nothing else.

## Offering ADRs

Offer to record an ADR only when **all three** are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful.
2. **Surprising without context** — a future reader will look at this and wonder why on earth
   it was done this way.
3. **The result of a real trade-off** — there were genuine alternatives, and one was chosen
   for specific reasons.

If any of the three is missing, skip it. Easy to reverse? You will just reverse it.
Unsurprising? Nobody will wonder. No real alternative? There is nothing to record beyond "we
did the obvious thing." The format, the numbering, and the full list of what qualifies are in
`references/adr-format.md`.

**A recorded ADR is not re-litigated.** Once a decision is written down, a later review does
not get to re-open it as though it were never made. Surface a conflict with an ADR only when
the friction is real enough to be worth reopening the decision, and say plainly that that is
what you are doing.
