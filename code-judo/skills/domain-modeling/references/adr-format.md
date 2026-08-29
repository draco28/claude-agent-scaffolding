# ADR format

ADRs live in `docs/adr/` and are numbered sequentially: `0001-slug.md`, `0002-slug.md`, and
so on. Create the directory lazily — only when the first ADR is actually needed.

## Template

```md
# {Short title of the decision}

{One to three sentences: what the context was, what was decided, and why.}
```

That is the whole thing. An ADR can be a single paragraph. The value is in recording *that*
a decision was made and *why*, not in filling out sections.

## Optional sections

Include these only when they add something. Most ADRs need none of them.

- **Status** frontmatter (`proposed | accepted | deprecated | superseded by ADR-NNNN`) —
  useful once decisions start being revisited.
- **Considered options** — only when the rejected alternatives are worth remembering.
- **Consequences** — only when a non-obvious downstream effect needs calling out.

## Numbering

Scan `docs/adr/` for the highest existing number and add one.

## When to offer an ADR

All three must hold:

1. **Hard to reverse** — changing your mind later carries meaningful cost.
2. **Surprising without context** — a future reader will look at the code and wonder why on
   earth it was done this way.
3. **The result of a real trade-off** — there were genuine alternatives and one was picked
   for specific reasons.

Miss any one and skip it.

## What qualifies

- **Architectural shape.** "We use a monorepo." "The write model is event-sourced; the read
  model is projected into Postgres."
- **Integration patterns between contexts.** "Ordering and Billing communicate by domain
  events, not synchronous HTTP."
- **Technology choices carrying lock-in.** Database, message bus, auth provider, deployment
  target. Not every library — the ones that would take a quarter to swap out.
- **Boundary and scope decisions.** "Customer data is owned by the Customer context; others
  reference it by id only." The explicit no-s are as valuable as the yes-s.
- **Deliberate deviations from the obvious path.** "Manual SQL instead of an ORM, because X."
  Anything a reasonable reader would assume the opposite of. These are what stop the next
  engineer from "fixing" something that was deliberate.
- **Constraints not visible in the code.** "We cannot use that provider, for compliance
  reasons." "Responses must be under 200ms, because of the partner API contract."
- **Rejected alternatives, where the rejection is non-obvious.** If GraphQL was considered
  and REST chosen for subtle reasons, record it — otherwise someone proposes GraphQL again
  in six months.

## Recording a rejection

An ADR is also the right home for a *rejected* proposal, when the reason for rejecting it
would otherwise be lost and the same proposal would come back. Frame the offer to the user
plainly: *"Want me to record this as an ADR so future architecture reviews don't re-suggest
it?"*

Only offer when the reason is one a future explorer would actually need. Skip ephemeral
reasons ("not worth it right now") and self-evident ones — neither survives contact with the
next quarter, and an ADR full of them stops being read.
