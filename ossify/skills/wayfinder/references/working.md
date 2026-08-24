# Working a map

Depth for `SKILL.md` §1's work-mode branch, and the file that resolves an
existing map's frontier, one ticket per session: the five steps that do it,
the claim that keeps two sessions from resolving the same ticket, and the
rule that keeps a ticket ruled out of scope from posing as a decision made.
It runs `references/tracker.md` §2's frontier query when no ticket is
named, and resolves whichever ticket it lands on through the instrument
`references/ticket-types.md` names for that ticket's type.

Work mode moves the frontier forward by exactly one ticket, then records
and stops. A session that resolves a second ticket, or claims a ticket
after resolving it instead of before, has broken the mode — not bent it.

---

## 1. The five steps

1. **Load the map** — the low-resolution view, not every ticket body.
2. **Choose and claim.** The operator's ticket if named, otherwise the first
   frontier ticket. **Assign it to the operator before any work** — that
   assignment *is* the claim, and it is what lets concurrent sessions skip it.
3. **Resolve it** through its type's instrument (`ticket-types.md`). Zoom as
   needed: fetch any related or closed ticket's full body on demand.
4. **Record the resolution** — post the answer as a resolution comment,
   **close** the issue, then append one line to the map's Decisions so far.
5. **Graduate and re-scope.** Add tickets the answer made specifiable
   (create-then-wire), clearing each graduated patch from Not yet specified so
   it lives only as its new ticket. If the answer reveals a ticket sits beyond
   the destination, **rule it out of scope** rather than resolving it.

Step 2's "first frontier ticket" is `references/tracker.md` §2's query, run
once; a map plus a named ticket skips the query entirely, because the
operator already made the choice by naming it. A session that resolves a
ticket first and assigns it after has broken step 2 — the assignment is
what a concurrent session reads to know the ticket is spoken for, and an
assignment made after the work is not a claim at all.

---

## 2. One ticket per session

**Never resolve more than one ticket per session**, except AFK types.
AFK tickets — `research`, `smoke-test`, `spike`; `references/ticket-types.md`
§2 — are the exception: §3's fan-out already dispatches several of them at
once from a single session, so the one-per-session limit binds what a
session resolves itself, not a batch it only launched and is waiting on.

**Plan, don't do.** Tickets produce decisions, not deliverables. Ossify is a
build lifecycle, so the pull to start building mid-map is stronger here than
elsewhere — and that pull is the signal the map's edge has been reached and
it is time to hand off. An effort may override this in its `Notes`.

---

## 3. Out of scope

Ruling something out of scope is a scoping act, not a step on the route.
**Close** the ticket — a closed ticket is unambiguously off the frontier —
and leave one line in Out of scope: the gist, why it is out, and a link. It
never enters Decisions so far, which records the route actually walked.

---

## 4. The commands

`$OWNER_REPO` is `references/tracker.md` §1's resolved tracker. In the
claim and record calls below, `$MAP` and `$TICKET` are the map's and the
session's own ticket — the one chosen and claimed in step 2 — resolved
once from the name the operator gave or the frontier query returned, never
re-asked for and never how either is referred to in conversation.

```bash
# load the map low-res: its body is the whole index, tickets are a separate query
gh issue view "$MAP" -R "$OWNER_REPO" --json title,body,url

# claim FIRST, before any work — "@me" needs no login lookup
gh issue edit "$TICKET" -R "$OWNER_REPO" --add-assignee "@me"

# record: comment, then close
gh issue comment "$TICKET" -R "$OWNER_REPO" --body-file resolution.md
gh issue close "$TICKET" -R "$OWNER_REPO"
```

`@me` is documented gh behaviour (`gh issue edit --help`: *"Use `@me` to
assign yourself"*) and is exactly the semantics the claim wants — the
session assigns the operator it is running as. Do not resolve a login with
`gh api user --jq .login` first; it is an extra call for the same result.

Graduating a ticket the answer made specifiable reuses
`references/charting.md` §5's create-then-wire pattern — an issue needs a
number before anything can be wired to it, so create runs first:

```bash
# graduate: create the ticket, then wire it to the map and its blocker
gh issue create -R "$OWNER_REPO" --label "wayfinder:$TYPE" \
  --title "$TICKET_TITLE" --body-file ticket-body.md

gh issue edit "$MAP"    -R "$OWNER_REPO" --add-sub-issue  "$TICKET"
gh issue edit "$TICKET" -R "$OWNER_REPO" --add-blocked-by "$BLOCKER"
```

`$TICKET` is reused here for the ticket this step just created — a
different issue than the one claimed in step 2, wired the same way
`references/charting.md` §5 wires any new ticket, by the issue number
`gh issue create`'s own output carries, never a database id. `$BLOCKER` is
the issue number of whichever ticket the graduated one is blocked by, when
it is blocked by one.
