# Onboarding question subset — what stays upfront

Depth for SKILL.md §4. Settles the second half of spec §13 open question 2: of
the legacy 10-phase / ~54-question onboarding, which questions are **pre-code
decisions** (asked in `start`) and which are **release-time** questions (asked
when the release that needs them is planned).

The test is one question: **does an answer change what we build first, or only
what we build later?** Only the former stays upfront.

---

## 1. Stays upfront (asked in `start`)

| Legacy area | What survives | Why it is pre-code | Lands in |
|---|---|---|---|
| **Vision / product framing** | Problem, actor, five-year shape, what "obviously worth having" means | Orientation for every later decision; the source of the journey map | Vision narrative + journey map |
| **Domain model & data ownership** | What the core entities are; who owns each piece of persistent state; migration posture | Data ownership is the hardest bone to reverse | Bones category 3 |
| **Security & trust boundaries** | Where untrusted input enters; which operations are destructive/irreversible; auth & tenancy shape | A trust boundary discovered late is a rewrite; risk gates need their surfaces now | Bones categories 5 + 9, risk gates |
| **Architecture / system shape** | What runs where; module boundaries and dependency direction; public contracts + compatibility policy; failure visibility; rollback/evolution; stack | This *is* the bones registry | Bones categories 1, 2, 4, 6, 7, 8 |
| **Privacy posture** | Posture, moat inventory, channels, override seam | Public → private is impossible; the seam must exist before code loads data | Posture block, bones category 9 |
| **The skeleton cut** | The thinnest coherent path | Defines Release 0 | Skeleton cut |

That is roughly four legacy phases' worth of substance (Foundation, Domain,
Security, Architecture) plus the new posture block — asked as a *conversation
about decisions*, not as a 54-item questionnaire.

---

## 2. Moves to release time

| Legacy area | Moved to | Why |
|---|---|---|
| **UX / surfaces detail** (screen inventories, flows, component choices) | Spine planning, per feature | Designing screens for features that do not exist is prophecy |
| **Implementation approach** (patterns, libraries per feature, testing depth per module) | Spine planning | Decided with implementation context, which does not exist yet |
| **DevOps & environments** (CI matrix, staging, deploy pipeline, secrets management beyond "don't commit them") | The release where deployment first matters — usually Release 0 close or MVP | Release 0 often deploys to one machine |
| **Quality / eval strategy** (coverage targets, eval suites, load testing) | Release close docs increments; the trigger table | Quality bars for unwritten code are aspirational |
| **Operations & support** (runbooks, on-call, SLOs, support path) | Triggered: "someone other than the author uses it" → onboarding/quickstart + runbook; "v1" → release/rollback + SLO baseline | Solo-scale products need none of it at Release 0 |
| **Exhaustive FR/NFR** | Release-close docs increments | See `references/lean-spec-schema.md` §3 |
| **Strategy** (legacy Phase 2: target weeks-to-MVP, milestone pacing) | Cut outright — no trigger | Timeboxes for unplanned releases are prophecy; pacing emerges from the release cadence. Cut deliberately, not lost in the port |

Moving a question does **not** delete it. Each has a named trigger; the docs
trigger table (spec §8) fires them. The Strategy row is the one deliberate
exception: per §4, a question with no trigger does not come back, and that is
the correct outcome.

---

## 3. The genuinely contested cuts — escalate, do not decide silently

Two or three cuts are judgment calls where reasonable people disagree, and where
guessing wrong is expensive. **Surface these to the user at authoring time** as
an explicit choice rather than applying the default silently:

1. **How much security is Release-0 minimum?** The defensible default is: trust
   boundaries and destructive operations are *enumerated* now (they are bones
   and gates), while the *controls* land in the spine that first reaches the
   surface. But a product handling real money or real user data from day one may
   want auth and an audit trail inside Release 0 itself. Ask.
2. **Does Release 0 need a deployment story?** Default: no — a skeleton that runs
   on the author's machine satisfies the clean-checkout test. But if the product
   is only meaningful deployed (a service, a scheduled job), deployment is part
   of the thin path. Ask when the journey's observable evidence requires a
   remote environment.
3. **Is the data model a bone at Release 0, or deferred?** Default: data
   ownership is answered now, schema detail is not. A product whose entire value
   is the data model (a database, a sync engine) may need more upfront. Ask when
   the skeleton's core value loop *is* persistence.

Frame each as: *"Default is X because Y. Your project looks like it might want Z
because W. Which?"* Record the answer in the relevant bone's ADR — including the
rejected alternative, so the reasoning survives.

---

## 4. Question-cutting, not horizon-tagging

An alternative was considered and **rejected on record** (spec §15 decision #10):
tagging every legacy question with a "horizon" and keeping all of them in the
flow. Capture-without-contract already failed in the field — tagged questions
accumulate, nobody answers them, and the ceremony returns with worse ergonomics.

Questions are **cut** from the upfront flow and **re-entered** at a named
trigger. If a question has no trigger, it does not come back, and that is the
correct outcome.

---

## 5. Anti-patterns

- **Turning §1 into a questionnaire.** It is a decision conversation. Ask what
  the project actually needs; skip what obviously does not apply.
- **Answering a §2 question upfront "while we're here".** That is how spec-core
  becomes a 10-phase interrogation again.
- **Silently applying a §3 default.** These are the cuts most likely to be wrong
  for a given project. Escalate all of them that apply.
- **Deleting a moved question instead of triggering it.** Then it never comes
  back and the gap ships.
