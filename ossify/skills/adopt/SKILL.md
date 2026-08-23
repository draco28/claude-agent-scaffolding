---
name: adopt
description: Adopt an existing project into ossify — five fail-closed gates, six conversions (journey re-marked shipped|next|later, the current cut as a present-tense clean-checkout test, bones back-derived from ADRs, Release 0 closed retroactively, artifacts reconciled, demo ledger seeded), and an adoption record. For the codebase that already has code, tests, history, and decisions; /ossify:start refuses it.
---

# adopt

You are the conductor of ossify's **adoption** — the on-ramp for a project
that already has code, tests, history, and decisions; `/start` is pre-code
ceremony and refuses such a canonical on its content gate.

**This body is thin by design, not under budget pressure.** The stations that
transfer unchanged live in `/start` — every pointer in §4 is a
do-not-restate pointer. Restating them here is how a second 500-line body goes
stale against the first; one contract in two files drifts by construction. The
target is enforced as a stated self-cap in §7.

---

## 1. The station map

`/start`'s stations, and what each becomes here:

| `/start` station | Here | Where |
|---|---|---|
| §4 vision | **confirm**, do not elicit | §4 |
| §5 journey map | **re-mark** `shipped\|next\|later` | §5 C1 |
| §6 skeleton cut | **replaced** by the current cut | §5 C2 |
| §7 bones | **back-derived** from ADRs | §5 C3 |
| §8 risk gates | **derive** from existing constraints | §4 |
| §9 smoke tests | **narrowed** to unverified external pins | §4 |
| §9a spike | unchanged | §4 |
| §10 posture | unchanged | §4 |
| §11 critic moment | unchanged, on the reconciled spec | §4 |
| §12 minimums | **replaced** by baseline completeness | §5 C4 |
| §13 outputs | **reconcile**, never author | §5 C5 |

---

## 2. When to use

**Trigger phrases (description-match):**

- `/adopt` (slash command — §8 for the `$ARGUMENTS` bridge)
- "adopt this project into ossify", "onboard a project that already has code",
  "bring an existing codebase into ossify", "we have history and ADRs already"

**Do NOT auto-invoke when:**

- The project is greenfield — that is `/start`.
- Ossify state already exists at the routed path — already onboarded; route to
  `doctor`.
- The ask is state-schema migration — `oss migrate` is a different thing and a
  dispatcher concern, not a ceremony.
- A slice is open on the legacy stack — §3 A5 refuses.

---

## 3. Pre-flight gates (fail closed, in order)

Each gate refuses fail-closed. A1 reuses `/start`'s exact refusal contract;
A3–A5's refusals name the **legacy stack's** close ceremony — the operator's
next move is scaffold-dev's slice close, then re-run `/ossify:adopt`. A refusal
that says "clean your tree" sends them to fix a symptom.

- **A1 — pairing manifest resolves.** `oss state_path` (probe; refuse exactly
  as `/start` §3's manifest probe does — that block's refusal text is verbatim,
  and its `/init-workspace` / `/pair-workspace` tokens are load-bearing; read
  them there, do not paraphrase).
- **A2 — no ossify state at the routed path.** If state exists: already
  adopted → route to `doctor`.
- **A3 — canonical tree is clean, tracked AND untracked.** `git -C "$(oss
  repo_root canonical)" status --porcelain` — empty is clean; any line is
  work in flight. On failure: refuse, naming the legacy stack's slice close.
- **A4 — no live worktrees.** `find "$(oss repo_root canonical)/.worktrees"
  -mindepth 1 -maxdepth 1 2>/dev/null` — any directory means a slice is open;
  same refusal as A3. A plain probe on purpose: `oss worktree_orphans`
  resolves ossify state, which A2 just required not to exist.
- **A5 — legacy position is on a boundary.** The live position is the
  manifest-routed memory bank's `05-active-context.md` cursor (scaffold-dev's
  `sd_state_read_cursor` resolves it; `project-roadmap.json` is inventory,
  not position). An active slice there refuses and names it.

Once all five pass, **record the baseline SHA** — `git -C "$(oss repo_root
canonical)" rev-parse HEAD`; everything downstream is relative to it and the
adoption record cites it. Then `oss init "<project-name>"` — its
state-exists refusal is A2 made mechanical, and every verb below mints into
the state it creates. Nothing hand-authors `project-state.json`.

---

## 4. Stations that transfer unchanged — pointers only

**Do not restate these — read the pointer, work it against the project.**

- **Vision — confirm, do not elicit** (`/start` §4). It is already written;
  read it back for correction.
- **Risk gates — derive from existing constraints** (`/start` §8). They are
  already enumerated in the legacy spec; mint them with `oss risk_gate_add`.
- **Smoke — narrowed** (`/start` §9). Shipped tests already verify the code's
  own claims; the residue is **unverified external pins** nobody re-checked.
- **Spike — unchanged** (`/start` §9a). Rarely fires on an adopted project.
- **Posture — unchanged** (`/start` §10 + `references/posture-block.md`). A
  genuine open decision, unaffected by prior code.
- **Critic moment — unchanged** (`/start` §11 +
  `references/critic-moment.md`). Fires once, on the reconciled spec; same
  announce/wait/skip contract, same `ARCHITECT_CRITIC_ARGS` bridge.

---

## 5. The conversions

### C1 — Journey map: `shipped | next | later`

`/start` §5's line grammar and harvest carry over unchanged — with one
vocabulary change: `skeleton` presupposes unbuilt. Re-mark every step:

```text
<actor action>  |  <system responsibility>  |  <observable evidence>   [shipped|next|later]
```

`shipped` means the step passes the clean-checkout test at the baseline commit
**today** — not "code exists for it." Harvest `next` and `later` to the feature
map exactly as `/start` §5 does; `shipped` steps are the baseline, not
candidates.

### C2 — The current cut replaces the skeleton cut

`/start` §6's read-back is unanswerable here: the cut it names already shipped.
The answerable form is **§6's own clean-checkout test, in the present tense**:

> From a clean checkout at `<baseline-sha>`, a `<actor>` can `<action>` and
> `<outcome>`.

The current cut is the union of the `shipped` journey steps. Validating it is
the one place to be slow — it is the only step that establishes what is
actually true rather than what a document claims. **Where checkout and legacy
spec disagree, the checkout wins, and the gap is a recorded finding** — never a
silent re-mark.

### C3 — Bones back-derived from the ADR directory

1. Scan `<canonical>/docs/adr/` with `bones-registry.md` §3's scan — **it is
   already conversion-correct** across filename forms and gapped series; use
   it, do not rewrite it.
2. Map each ADR to one of the nine categories (`/start` §7's checklist).
   Multiple ADRs may share a category; a category may have none.
3. Mint each: `oss bone_add "<ADR-ref>" "<title>" "<touch-glob-csv>" "<revisit
   trigger>"` — touch surfaces from the paths the decision actually governs,
   at module granularity (`/start` §7's glob semantics).
4. **Status `Accepted`, not `Proposed`.** `/start` §7's protocol is Proposed,
   flipped to Accepted once a release exercises it; the adopted baseline **is**
   that exercise. Minting shipped decisions as Proposed misstates the record.
5. **Categories with no ADR still get the forced-enumeration question.** The
   failure mode `/start` §7 guards is unasked questions; adoption does not
   change that. Answer, or `not-applicable` with a reason.

An ADR that no longer describes the code is a **finding** for the read-out,
not a bone to write.

### C4 — The adopted baseline is Release 0, retroactively closed

```bash
oss release_add "Release 0" "adopted baseline: everything shipped under <legacy-stack> through <baseline-sha>"
oss release_status "<release-id>" closed
```

The skeleton exists — it was built before ossify arrived. `release_status`
accepts `closed`; no new verb, no spine tree. **Do not reconstruct per-slice
history as spines and work items** — that would put unearned records in the
ledger. The first ossify-planned release is Release 1.

Then author the **stub retrospective** at
`"$(oss release_dir r0)/release-retrospective.md"` — recording the adoption,
not a spine retro. That filename is `plan-release` §4's previous-release
input, measured as the one thing it needs and lacks after a
retroactively-closed Release 0.

### C5 — Reconcile artifacts; read the destination before writing it

**No destination is opened for writing until it has been read.** Adoption has
no blank destinations — an adopted project is all occupied surface.

| Destination | Action |
|---|---|
| `MASTER-SPEC.md` | map legacy phases → the 7 lean sections; keep legacy sections (spec-validation reads their presence as legal) |
| `CLAUDE.md` | merge ossify's loop section; preserve hand-authored zones |
| `EXECUTIVE-SUMMARY.md` | leave; no gate reads it |
| memory bank | append with harvest's provenance trailer (`close/references/harvest.md`); **never truncate**. For `09-known-issues.md` / `10-decisions-log.md`, harvest's never-regenerate rule wins — they hold the history adoption preserves (#268; the brief's conditional is still owed) |
| `tech-debt.md`, `PUBLIC_BOUNDARY.md` | author (absent) |
| `<canonical>/docs/adr/` | append only, continuing the series |

### C6 — Seed the demo ledger, or the first close passes vacuously

The only ledger verb, `oss ledger_add_auto`, keys every line to a spine — and
C4 deliberately creates none. So adoption **records the seed candidates**
(small, end-to-end, from the current cut's journey — not a transcription of
the test suite) in the adoption record, and **the first `/plan-spine` mints
them as `auto:` lines on that spine**. No close can run before a spine
exists, so the first close runs them: the vacuous window closes without
minting unearned spine records.

---

## 6. Outputs

| Output | Routed to | Mode |
|---|---|---|
| Lean spec sections 1–7 | AI workspace | merge into the existing MASTER-SPEC |
| Memory bank | AI workspace | append-with-trailer; author only what is absent |
| `CLAUDE.md` | AI workspace | merge |
| Bones ADRs | `<canonical>/docs/adr/` | append, continuing the series |
| Bones / risk gates / feature map / posture | `project-state.json` | `oss` verbs — into §3's init state |
| Release 0, closed | `project-state.json` | `oss` verbs |
| `PUBLIC_BOUNDARY.md` | each public repo root | author |
| Stub retrospective | `"$(oss release_dir r0)/release-retrospective.md"` | author — records the adoption |
| **Adoption record** | `<ai-workspace>/ADOPTION.md` | author — baseline SHA, gates passed, merged-vs-authored, **every C2 gap**, the C6 seed candidates |

The adoption record is the point: it is the only artifact that says what
adoption actually did, and it is what a later `doctor` run reads when the spec
and the state disagree (doctor §1's routing list routes it there).

Close with `oss doctor` (the state gate: `state`, `schema`, `replay`,
`shape`) and name the next step: **`/plan-release`** for Release 1.

---

## 7. Never

- **State-schema migration.** `oss migrate` is a different thing. Do not
  overload the word.
- **Touching the legacy stack's files.** `.workspace/project-roadmap.json` and
  scaffold-dev's artifacts are read, never written. Adoption is additive; the
  operator retires the old stack when they choose.
- **Mid-slice adoption.** §3 A5 refuses it by design.
- **Repairing what it finds.** C2 gaps and stale ADRs are findings.
- **Letting this body exceed 250 lines.** Thin-by-design is a stated
  constraint, not an aspiration — the cap sits close enough to the target
  that the first unjustified addition hits it. Depth belongs in pointers,
  never restated.

---

## 8. Slash-command interaction

The `/adopt` command exports the raw argument as `$ARGUMENTS` via the env-var
bridge — parse it in bash; never reference `$1`/`$2`/`$N`. The only argument
is an optional project name, passed to `oss init`; when absent, ask before
initializing. The command registers on Claude Code only — as no ossify
command registers on OpenCode, #131 tracks that gap for all of them — while
this skill body reaches OpenCode by path as the native `adopt` skill.
