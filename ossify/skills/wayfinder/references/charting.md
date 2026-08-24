# Charting a map

Depth for `SKILL.md` §1's chart-mode branch, and the file that turns a
loose question into a map: the six steps that get there, the test that
decides ticket versus fog, the map body's shape, and the tracker commands
that create it. It files against the tracker `references/tracker.md` §1
resolved and types each ticket with one of the six labels
`references/ticket-types.md` names.

Charting is deliberately incomplete. It charts only what can be phrased
sharply now, leaves the rest as fog, and resolves nothing. A session that
charts a map and then starts answering its tickets has broken the mode —
that is work mode's job, once the map exists, not this one's.

---

## 1. The six steps

1. **Name the destination.** Call `/ossify:challenge` in interview mode
   plus `start/references/domain-modeling.md`. The destination fixes the
   scope, so it settles first.
2. **Map the frontier, breadth-first** — fan out across the whole space
   rather than deep on one thread.
3. **If step 2 surfaces no fog, there is no map to make.** Say so and
   stop.
4. **Create the map** (label `wayfinder:map`): Destination and Notes
   filled, Decisions so far empty, the fog sketched into Not yet
   specified.
5. **Create the specifiable tickets, then wire blocking in a second
   pass** — issues need ids before they can reference each other.
6. **Fire the AFK tickets** (`research`, `smoke-test`, `spike`) in
   parallel, then **stop**. Charting hand-resolves nothing.
   `references/ticket-types.md` §3 has the fan-out mechanics and the
   `caffeinate` discipline the dispatch needs; this step only decides
   which tickets qualify.

Step 3 has to actually stop the session, not just get mentioned in
passing. If the breadth-first pass in step 2 turns up nothing that clears
§2's test below, say so and stop before step 4 — do not create a map with
an empty Not yet specified to look thorough, and do not go looking for
fog that was not there.

---

## 2. The fog-or-ticket test

The test is whether the question can be **phrased** precisely now, not
whether it can be **answered** now.

- **Ticket** when the question is already sharp, even if blocked.
- **Not yet specified** when it cannot be phrased that sharply. Do not
  pre-slice fog into ticket-sized pieces; one patch may graduate into
  several tickets, or none.

A blocked-but-sharp question is still a ticket, wired to whatever blocks
it in step 5's second pass — being unable to act on it yet is not the
same as being unable to phrase it.

---

## 3. The map body

Every map's issue body carries five headings, in this fixed order:
`## Destination`, `## Notes`, `## Decisions so far`,
`## Not yet specified`, `## Out of scope`. Step 4 writes three of them and
touches a fourth only to leave it empty:

- **Destination** — the question named in step 1, the one this map
  exists to resolve.
- **Notes** — context a later session would otherwise have to re-derive:
  why now, what prompted the question, anything the interview surfaced
  that is not itself a decision.
- **Decisions so far** — empty. A map is chartered with nothing yet
  decided; work mode is the only writer of this heading, one entry per
  ticket it resolves.
- **Not yet specified** — the fog §2 could not phrase sharply enough to
  file as a ticket, sketched in prose. It is not a queue and not a list
  of future tickets — some of it may never become one.
- **Out of scope** — what step 1's interview explicitly ruled out while
  naming the destination, so a later session does not reopen it. Left
  empty when nothing was ruled out.

---

## 4. Bootstrap the labels first

`gh issue create --label` fails on a label the repo does not have, and no
repo has these yet — verified: zero `wayfinder:*` labels exist anywhere.
Chart mode ensures all seven before creating anything, idempotently and
without clobbering a label someone already customised:

```bash
for L in map research smoke-test spike prototype grilling task; do
  gh label create "wayfinder:$L" -R "$OWNER_REPO" \
    --description "wayfinder $L" 2>/dev/null || true
done
```

Deliberately **not** `--force`: that would overwrite the colour and
description of a label the repo already has. Failing silently when the
label exists is the behaviour wanted here. Do not reach for
`... | grep -q` to test existence first — under `set -o pipefail` a
`grep -q` that matches early closes the pipe and the whole pipeline
reports failure.

---

## 5. Create the map and its tickets

`$OWNER_REPO` is `references/tracker.md` §1's resolved tracker. `$TYPE` is
one of the six words from `references/ticket-types.md` §1 — `research`,
`smoke-test`, `spike`, `prototype`, `grilling`, or `task`. `$MAP_TITLE`
and `$TICKET_TITLE` are the map's and the ticket's own names — never a
bare number, on the tracker exactly as in conversation.

```bash
# the map
gh issue create -R "$OWNER_REPO" --label "wayfinder:map" \
  --title "$MAP_TITLE" --body-file map-body.md

# a ticket, as a sub-issue of the map
gh issue create -R "$OWNER_REPO" --label "wayfinder:$TYPE" \
  --title "$TICKET_TITLE" --body-file ticket-body.md
```

`gh issue create` has no parent argument, so every ticket the map wants
gets created first, as a plain issue, and only wired to the map and to
each other in a second pass — both calls below need the issue numbers
`gh issue create` already returned:

```bash
# second pass: parent it, then wire blocking
gh issue edit "$MAP"    -R "$OWNER_REPO" --add-sub-issue  "$TICKET"
gh issue edit "$TICKET" -R "$OWNER_REPO" --add-blocked-by "$BLOCKER"
```

`$TICKET` and `$BLOCKER` are ordinary issue numbers — the same kind used
everywhere else in this file, not a REST database id. A `gh` too old to
carry these three relationship flags still has the REST sub-issue and
dependency endpoints to fall back to, at the cost of a database-id lookup
per call — and a trap in that lookup: `gh issue view --json id` returns
the GraphQL node id, not the database id the endpoints want; only
`gh api "repos/$OWNER_REPO/issues/$N" --jq .id` returns the right one.
