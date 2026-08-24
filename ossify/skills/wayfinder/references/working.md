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
   (created and parented in one call, §4), clearing each graduated patch from
   Not yet specified so it lives only as its new ticket. If the answer reveals
   a ticket sits beyond the destination, **rule it out of scope** rather than
   resolving it.

Step 2's "first frontier ticket" is `references/tracker.md` §2's query, run
once; a map plus a named ticket skips the query entirely, because the
operator already made the choice by naming it. A session that resolves a
ticket first and assigns it after has broken step 2 — the assignment is
what a concurrent session reads to know the ticket is spoken for, and an
assignment made after the work is not a claim at all.

**A named ticket skips the frontier read, never the parent check.** Confirm
the ticket the operator named is one of `$MAP`'s sub-issues — `gh issue view
"$TICKET" --json parent` — and **stop** on a mismatch, naming both the map the
ticket actually belongs to and the one that was asked for. The shortcut exists
because the operator already chose, not because the number is trusted: step 4
**closes** that issue and appends its answer to `$MAP`'s Decisions so far, so a
typo or a stale link mutates two wrong things at once — an unrelated issue
closed, and a decision recorded on a map that never asked the question. The
frontier query is what implicitly validates parentage in the unnamed case,
which is exactly why the named case has to do it explicitly.

Resolve `$MAP` the same way: confirm it carries `wayfinder:map` before working
it. A map name that lands on an ordinary issue otherwise gets a Decisions so
far heading appended to something that was never a map.

**The claim is a marker, not a lock.** `--add-assignee` succeeds whether or not
the ticket was already assigned — GitHub offers no compare-and-set on
assignment — so two sessions that run the frontier query before either
assignment lands will both select the same ticket and both claims will
succeed. Re-read the chosen ticket's assignees immediately before claiming
(`gh issue view "$TICKET" --json assignees`) and skip it if someone already
holds it; that shrinks the window to the gap between the read and the write
but does not close it. **Two sessions working one map concurrently can still
double-resolve a ticket**, and no mechanism here prevents it. Work a map from
one session at a time; the assignment is what makes a claim *visible*, not
what makes it exclusive.

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
it is time to hand off. An effort may override this in its `Notes`
(`references/charting.md` §3 names Notes as the override channel);
**absent that override, the default binds.**

---

## 3. Out of scope

Ruling something out of scope is a scoping act, not a step on the route.
**Close** the ticket — a closed ticket is unambiguously off the frontier —
and leave one line in Out of scope: the gist, why it is out, and a link. It
never enters Decisions so far, which records the route actually walked.

---

## 4. The commands

`$OWNER_REPO` is `references/tracker.md` §1's resolved tracker. **On a
`local` tracker it is unbound and none of the commands in this section run**
— `references/tracker.md` §3 gives the file form each one takes instead, and
every rule on this page binds unchanged.
`$RESOLUTION` is the answer this session is recording, fed on **stdin** —
`--body-file -` — so no scratch file lands in the operator's working tree.
In the claim and record calls below, `$MAP` and `$TICKET` are the map's and
the session's own ticket — the one chosen and claimed in step 2 — resolved
once from the name the operator gave or the frontier query returned, never
re-asked for and never how either is referred to in conversation.

```bash
# load the map low-res: its body is the whole index, tickets are a separate query
gh issue view "$MAP" -R "$OWNER_REPO" --json title,body,url

# claim FIRST, before any work — "@me" needs no login lookup
gh issue edit "$TICKET" -R "$OWNER_REPO" --add-assignee "@me"

# record: comment, then close
printf '%s\n' "$RESOLUTION" \
  | gh issue comment "$TICKET" -R "$OWNER_REPO" --body-file -
gh issue close "$TICKET" -R "$OWNER_REPO"

# §3's out-of-scope ruling is this same close with NO resolution comment
# before it: the one line goes to the map's Out of scope, never to
# Decisions so far
```

`@me` is documented gh behaviour (`gh issue edit --help`: *"Use `@me` to
assign yourself"*) and is exactly the semantics the claim wants — the
session assigns the operator it is running as. Do not resolve a login with
`gh api user --jq .login` first; it is an extra call for the same result.

Graduating a ticket the answer made specifiable reuses
`references/charting.md` §5's create call, `--parent "$MAP"` and all — the
map already has a number, so a graduated ticket needs no second pass unless
something blocks it that does not exist yet.

In a graduate context, `$TICKET` is not the ticket claimed in step 2 but
the new one step 5 creates — `references/charting.md` §5 defines its
`$TYPE` and `$TICKET_TITLE`. Wired or claimed, a ticket is always
addressed by its issue number, never a database id.

---

## 5. The empty frontier, and closing the map

An empty frontier is not an error and not an edge case — it is the state
every map reaches. `references/tracker.md` §2's query returning nothing means
one of exactly two things, and the session says which:

- **Every ticket is closed.** The map has no open work left.
- **Tickets remain, but none is workable** — each is blocked by something
  still open, or already claimed by another session. Name them and what holds
  each one. Close nothing; there is nothing to decide here.

On the first, read the map's Destination against its Decisions so far and say
whether the question is answered. If it is, **ask the operator, then close the
map** — `gh issue close "$MAP"` — leaving Decisions so far as the record of
the route walked. If it is not, the remaining uncertainty is fog that never
graduated: say what is still open, and let the operator decide whether to
chart the next ticket or stop.

**The close is the operator's, not the session's.** A map's destination is a
judgment about whether a question is settled, which is the one thing work mode
does not decide on its own — the same reason `prototype` and `grilling`
tickets are HITL. What binds here is that the session must **reach** the
question rather than reporting an empty frontier and stopping.

A closed map is a real state, not a hypothetical one: `references/preflight.md`
§1 queries `--state all` precisely so a closed map's Decisions so far still
reaches the ceremony that comes after it. This section is what produces one.
