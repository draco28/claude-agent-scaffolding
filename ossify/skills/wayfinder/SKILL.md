---
name: wayfinder
description: Decision-ticket maps on an issue tracker — chart a question into a map plus its research/smoke-test/spike/prototype/grilling/task tickets, or work an existing map's frontier one ticket per session. Activate on a wayfinder map name, number, or URL, a loose decision-shaped question too big for one session, or /ossify:wayfinder. Not release or spine planning — those stay build-slice DAGs (/ossify:plan-release, /ossify:plan-spine).
---

# wayfinder

Decision-ticket maps on an issue tracker, for a question whose resolution is
a decision rather than a build slice — too big to settle in one session, but
not a feature to plan as a spine. This body is a router: it resolves the
tracker and picks a mode, and nothing else.

---

## 1. Route

Resolve the tracker first, either way — read
`${CLAUDE_PLUGIN_ROOT}/skills/wayfinder/references/tracker.md` §1 and follow
its ladder before doing anything else.

- **No argument, or a loose idea** → **chart mode.** The operator has a
  question, not yet a map: turn it into a map ticket plus its first tickets,
  filed on the tracker §1 resolved.
- **A map name, number, or URL** → **work mode.** The map already exists:
  read its frontier — the tickets that are open, unassigned, and
  unblocked — and work one.
- **A map plus a ticket** → work mode, that ticket specifically, skipping
  the frontier read.

Charting that question into a map — the six steps, the fog-or-ticket
test, and the commands that create it — is read from
`${CLAUDE_PLUGIN_ROOT}/skills/wayfinder/references/charting.md`.

A ticket's type decides how it resolves — read
`${CLAUDE_PLUGIN_ROOT}/skills/wayfinder/references/ticket-types.md` for the
six types, which of ossify's uncertainty instruments each one points at, and
whether it runs AFK or needs a human in the loop.

## 2. Nevers

- **Never resolve branch 0's conflict silently.** A manifest and a
  `.wayfinder.json` naming different trackers is a stop, not a default —
  `references/tracker.md` §1 explains why.
- **Never refer to a map or a ticket by a bare number.** Name it — the map's
  or ticket's own name — a number alone is not how a session or an operator
  can tell two tickets apart in conversation.
