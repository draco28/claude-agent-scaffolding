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
   filled, the fog sketched into Not yet specified, whatever step 1 ruled
   out written into Out of scope, and Decisions so far empty.
5. **Create the specifiable tickets, parented in the creating call, then
   wire any forward blocking reference in a second pass** — a ticket
   cannot name a blocker the map has not created yet.
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
it as step 5 creates it, or in step 5's second pass when the blocker is
created later — being unable to act on it yet is not the same as being
unable to phrase it.

---

## 3. The map body

Every map's issue body carries five headings, in this fixed order:
`## Destination`, `## Notes`, `## Decisions so far`,
`## Not yet specified`, `## Out of scope`. Step 4 writes four of them — Out
of scope only when step 1's interview actually ruled something out — and
touches the fifth, Decisions so far, only to leave it empty:

- **Destination** — the question named in step 1, the one this map
  exists to resolve.
- **Notes** — context a later session would otherwise have to re-derive:
  why now, what prompted the question, anything the interview surfaced
  that is not itself a decision. Notes is also the one **override
  channel**: an effort that means to override work mode's "plan, don't
  do" default (`references/working.md` §2) writes that override here and
  nowhere else, because here is where work mode reads for it.
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

`gh issue create --label` fails on a label the repo does not have. Chart
mode ensures all seven before creating anything, idempotently and
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
bare number, on the tracker exactly as in conversation. `$MAP_BODY` and
`$TICKET_BODY` are the bodies §3 shapes, fed on **stdin** — `--body-file -`
— so charting drops no scratch file into the operator's working tree.

`gh issue create` prints the new issue's URL and nothing else, so the
number every later call needs is captured here, at the one step that
mints it:

```bash
# the map
MAP="$(printf '%s\n' "$MAP_BODY" \
  | gh issue create -R "$OWNER_REPO" --label "wayfinder:map" \
      --title "$MAP_TITLE" --body-file - \
  | grep -oE '[0-9]+$')"

# a ticket, parented to the map in the same call
TICKET="$(printf '%s\n' "$TICKET_BODY" \
  | gh issue create -R "$OWNER_REPO" --label "wayfinder:$TYPE" \
      --title "$TICKET_TITLE" --parent "$MAP" --body-file - \
  | grep -oE '[0-9]+$')"
```

**Only a forward reference needs the second pass.** `gh issue create`
takes `--parent` and `--blocked-by`, both by issue number, so a ticket is
parented — and wired to any blocker that already exists — in the call that
creates it. What cannot run in the first pass is a ticket blocked by a
sibling the map has not created yet: it has no number to name. Create in
dependency order wherever the map allows it, and wire what is left once
every ticket has a number:

```bash
# second pass: forward blocking references only, once both issues exist
gh issue edit "$TICKET" -R "$OWNER_REPO" --add-blocked-by "$BLOCKER"
```

`$TICKET` and `$BLOCKER` are ordinary issue numbers — the same kind used
everywhere else in this file, not a REST database id. A `gh` too old to
carry these relationship flags still has the REST sub-issue and
dependency endpoints to fall back to, at the cost of a database-id lookup
per call — and a trap in that lookup: `gh issue view --json id` returns
the GraphQL node id, not the database id the endpoints want; only
`gh api "repos/$OWNER_REPO/issues/$N" --jq .id` returns the right one.
