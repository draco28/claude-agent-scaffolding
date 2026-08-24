# Ticket types

Depth for `SKILL.md` §1's ticket-type pointer, and the file every wayfinder
ticket resolves through: which of ossify's uncertainty instruments a
ticket's type names, whether that instrument can run unattended, and how it
earns its label on the tracker.

Ossify already owns five ways to resolve uncertainty — four instrument docs
(`research.md`, `smoke-test-pass.md`, `spike-contract.md`, `prototype.md`)
plus a grill (`challenge`) — and wayfinder adds none of its own. A
ticket's type says which of those five its uncertainty is, or that it
carries no uncertainty at all and just wants doing.

---

## 1. The six types

| Type | Mode | Resolver | Uncertainty |
|---|---|---|---|
| `research` | AFK | `start/references/research.md` | factual, read-shaped |
| `smoke-test` | AFK | `start/references/smoke-test-pass.md` | factual, script-shaped |
| `spike` | AFK | `start/references/spike-contract.md` | technical — build a falsifier |
| `prototype` | HITL | `start/references/prototype.md` | experiential — a person chooses |
| `grilling` | HITL | `challenge` interview + `start/references/domain-modeling.md` | none; it is the grill |
| `task` | either | no instrument | none; manual work unblocking a decision |

Resolver paths are read cross-skill via
`${CLAUDE_PLUGIN_ROOT}/skills/start/references/<file>`. This is the
established pattern — `challenge/SKILL.md` already reads references that
way, and the absorption spec sanctions it. **The grill is reached the same
way** — read `${CLAUDE_PLUGIN_ROOT}/skills/challenge/references/interview.md`,
as every other ossify caller of the grill does. Never name the slash command:
`/ossify:challenge` is the Claude Code spelling, and wayfinder now ships on
the OpenCode bundle too, where the same skill is registered as a native
`/challenge` and no `ossify:` alias exists. The reference path is the one
address that is correct on every surface.

**Take each instrument's method; do not take its storage.** All four were
written for an ossify project and name ossify artifacts as their
destination — `research.md` writes `docs/research/<slug>.md` in the AI
workspace and folds verified claims into a bone's ADR, `smoke-test-pass.md`
and `spike-contract.md` both land in the affected bone's ADR, and
`prototype.md` records against a journey-map step or a bone ADR. A wayfinder
map does not require any of that: `references/tracker.md` §1 branches 2 and 3
put a map on any repository's tracker, and such a repo may have no bones, no
ADRs, no journey map, and no AI workspace at all. The instrument's *procedure*
— the question form, the falsifier, the timebox, the variant comparison — is
what the type points at and it transfers whole. Its *write target* does not.

Where the named artifact does not exist, the resolution's home is the one
every ticket already has: the resolution comment on the ticket and its one
line in the map's Decisions so far (`references/working.md` §1 step 4). That
is the durable record on this branch. **Never invent a parallel artifact tree
to satisfy a resolver path** — a `docs/adr/` written into a repo that has no
bones is scaffolding nobody asked for and nothing else reads. In an ossify
project the instrument's own destination stands, and the ticket's comment is
the pointer to it.

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

Fan `research`, `smoke-test`, and `spike` tickets out through the `Task` tool
directly, not `superpowers:dispatching-parallel-agents` — Batch S ossified
`challenge` in-tree to drop plugin dependencies, and taking one back
reverses that.

**The map body is the dispatcher's to write, never a worker's.**
`references/working.md` §1 step 4 has each resolved ticket append one line to
the map's Decisions so far — and a map body is edited by whole-body
replacement (`gh issue edit --body`), so two workers that finish together read
the same body and the second write silently erases the first's line. Split
step 4 for a fan-out: **each worker** posts its own resolution comment and
closes its own ticket, which touch nothing shared; **the dispatching session**
collects the resolutions the batch returns and appends them to the map itself,
one at a time, after the batch is in. The per-ticket half is already
conflict-free; only the map line needs serialising, and the session that
launched the fan-out is the one place it can be serialised.

**Dispatch only what the frontier predicate admits** — open, unassigned, and
blocked by nothing still open (`references/tracker.md` §2). AFK is a property
of the type; it is not permission to run. A blocked `spike` handed to a
subagent resolves against evidence that does not exist yet and records that
answer on the ticket as if it were real, which is worse than not running it.
This binds on every caller — `charting.md` step 6's post-chart fan-out and any
batch a work-mode session launches alike — and it is stated here, at the
fan-out, rather than in each of them.

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
