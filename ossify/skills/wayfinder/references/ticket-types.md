# Ticket types

Depth for `SKILL.md` §1's ticket-type pointer, and the file every wayfinder
ticket resolves through: which of ossify's uncertainty instruments a
ticket's type names, whether that instrument can run unattended, and how it
earns its label on the tracker.

Wayfinder does not add a fifth instrument to the four ossify already owns
for uncertainty — `research.md`, `smoke-test-pass.md`, `spike-contract.md`,
`prototype.md` — plus a grill (`/ossify:challenge`). A ticket's type says
which of those five its uncertainty is, or that it carries no uncertainty
at all and just wants doing.

---

## 1. The six types

| Type | Mode | Resolver | Uncertainty |
|---|---|---|---|
| `research` | AFK | `start/references/research.md` | factual, read-shaped |
| `smoke-test` | AFK | `start/references/smoke-test-pass.md` | factual, script-shaped |
| `spike` | AFK | `start/references/spike-contract.md` | technical — build a falsifier |
| `prototype` | HITL | `start/references/prototype.md` | experiential — a person chooses |
| `grilling` | HITL | `/ossify:challenge` interview + `domain-modeling.md` | none; it is the grill |
| `task` | either | no instrument | none; manual work unblocking a decision |

Resolver paths are read cross-skill via
`${CLAUDE_PLUGIN_ROOT}/skills/start/references/<file>`. This is the
established pattern — `challenge/SKILL.md` already reads references that
way, and the absorption spec sanctions it.

Each ticket carries exactly one `wayfinder:<type>` label, set when it is
filed: `wayfinder:research`, `wayfinder:smoke-test`, `wayfinder:spike`,
`wayfinder:prototype`, `wayfinder:grilling`, or `wayfinder:task`. The map
that owns them carries `wayfinder:map` and none of the six — a map is not
its own ticket.

---

## 2. AFK and HITL

**AFK** — the ticket can be worked unattended: dispatched to a subagent, or
picked up solo while the operator is elsewhere. `research`, `smoke-test`,
and `spike` are AFK because each one's instrument resolves against
something that does not need a person watching — sources that say what
they say, a script that exits 0 or doesn't, a falsifier that fires or
doesn't.

**HITL** — human-in-the-loop, and not negotiable. `prototype` and
`grilling` are HITL because the thing under resolution *is* a person's
judgment: which built variant feels right, how the operator actually
answers a question the interview predicted differently. `task` carries no
uncertainty at all — it is manual work unblocking the decision — so its
mode is whatever the work itself needs, not a property of the type.

**The falsifier is the boundary.** If a check could fail, the ticket is a
`spike`. If the answer requires a person comparing built variants, it is a
`prototype`.

**Dispatching a `prototype` or `grilling` ticket to a subagent is a bug, and
this skill refuses it.** The agent never stands in for the human's side of the
exchange. A grilling agent that answers its own questions has broken the
ticket, not resolved it.

---

## 3. Dispatching the AFK tickets

Fan `research`, `smoke-test`, and `spike` tickets out through the Agent tool
directly, not `superpowers:dispatching-parallel-agents` — Batch S ossified
`challenge` in-tree to drop plugin dependencies, and taking one back
reverses that.

This host sleeps in about a minute and kills background agents as a generic
API error. Hold `caffeinate -i` across the **whole** fan-out, not per agent.

---

## 4. Pointer direction

This file points at the four instrument docs — `research.md`,
`smoke-test-pass.md`, `spike-contract.md`, `prototype.md` — and they do not
point back. A back-pointer would mean four file edits for symmetry, and
four places to drift. The actor here is work mode, AFK or HITL, and that
contract belongs to the file that schedules the work, not to the
instruments being scheduled.
