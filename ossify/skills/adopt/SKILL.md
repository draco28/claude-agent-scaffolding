---
name: adopt
description: Adopt an existing project into ossify — five fail-closed gates, six conversions (journey re-marked shipped|next|later, the current cut as a present-tense clean-checkout test, bones back-derived from ADRs, Release 0 closed retroactively, artifacts reconciled, demo-ledger seed candidates recorded), and an adoption record. For the codebase that already has code, tests, history, and decisions; /ossify:start refuses it.
---

# adopt

You are the conductor of ossify's **adoption** — the on-ramp for a project
that already has code; `/start` is pre-code ceremony and refuses such a
canonical on its content gate.

**This body is thin by design, not under budget pressure.** The stations that
transfer unchanged live in `/start` — every pointer in §4 is a
do-not-restate pointer. Restating them here is how a second 500-line body goes
stale against the first. The target is enforced as a stated self-cap in §7.

---

## 1. The station map

`/start`'s stations, and what each becomes here — **§4 carries the
transfers** (vision confirmed, not elicited; risk gates derived from the
legacy spec's constraints; smoke narrowed to unverified external pins; spike
and posture unchanged; critic moment on the reconciled spec), and **§5
carries the replacements** (C1 re-marks the journey `shipped|next|later`;
C2 replaces the skeleton cut with the current cut; C3 back-derives bones;
C4 replaces the Release-0 minimums with the closed baseline; C5 reconciles
outputs instead of authoring them).

---

## 2. When to use

**Trigger phrases (description-match):**

- `/adopt` (slash command — §8 for the `$ARGUMENTS` bridge)
- "adopt this project into ossify", "onboard a project that already has code"

**Do NOT auto-invoke when:**

- The project is greenfield — that is `/start`.
- The project has no scaffold-dev legacy stack — no roadmap state, no
  active-context cursor, no legacy spec. This version adopts THAT stack;
  anything else is out of scope today.
- Ossify state already exists at the routed path — already onboarded; route to
  `doctor`.
- The ask is state-schema migration — `oss migrate` is a different thing and a
  dispatcher concern, not a ceremony.
- A slice is open on the legacy stack — §3 A5 refuses.

---

## 3. Pre-flight gates (fail closed, in order)

Each gate refuses fail-closed. A1 reuses `/start`'s exact refusal contract;
A3–A5's refusals name the **legacy stack's** close ceremony — scaffold-dev's
slice close, then re-run — never "clean your tree", which fixes a symptom.

- **A0 — no inherited state override.** If `OSS_STATE_FILE` is set, stop:
  `_oss_resolve_state` lets it override the manifest for every verb below —
  adoption would mint into another project's state while A1/A2 inspected
  this one. Unset it and re-run (same guard as plan-release §3).
- **A1 — topology declaration resolves.** `oss state_path` (probe; refuse
  exactly as `/start` §3's topology probe does — refusal text verbatim,
  load-bearing tokens and all; read it there, never paraphrased).
- **A2 — no ossify state at the routed path.** State exists: already
  onboarded → route to `doctor`, full stop — every `/start` project has
  state and no adoption record, so the record's absence distinguishes
  nothing.
- **A3 — every tree adoption will edit is clean, tracked and untracked.**
  Iterate the declared repos read at A1 plus the AI workspace — C5 edits
  all of them: `git -C "$(oss repo_root <name>)" status --porcelain` each.
  Any line, in any one, is work in flight; refuse, naming the legacy
  stack's slice close. Each repo must also be on its own default branch —
  a parked checkout is refused and named.
- **A4 — no live worktrees.** Resolve the legacy worktree directory per
  repo — the manifest's `.during_dev.worktrees_dir`, falling back to
  `<repo-root>/.worktrees` — then `find <dir> -mindepth 1 -maxdepth 1` per
  repo: any directory means a slice is open (a plain probe; the oss verb
  needs the state A2 just forbade).
- **A5 — legacy position is on a boundary.** The live position is the
  manifest-routed memory bank's `05-active-context.md` cursor (the roadmap
  file is inventory, not position). An active slice there refuses and
  names it.

Once all five pass, **record a baseline SHA per declared repo** — `git -C
"$(oss repo_root <name>)" rev-parse HEAD` for each; the adoption record
cites a **baseline table**, not one SHA, and everything downstream is
relative to each repo's own baseline. Then `oss init "<project-name>"` —
its state-exists refusal is A2 made mechanical, and every verb below mints
into the state it creates. Nothing hand-authors `project-state.json`.

---

## 4. Stations that transfer unchanged — pointers only

**Do not restate these — read the pointer, work it against the project.**

- **Vision — confirm, do not elicit** (`/start` §4): read it back for correction.
- **Risk gates — derive from existing constraints** (`/start` §8 owns the
  families and the control menu); mint with `oss risk_gate_add`.
- **Smoke — narrowed** (`/start` §9) to **unverified external pins** —
  shipped tests already cover the code's own claims.
- **Spike — unchanged** (`/start` §9a). Rarely fires on an adopted project.
- **Posture — unchanged** (`/start` §10 + `references/posture-block.md`): a
  genuine open decision, unaffected by prior code.
- **Critic moment — unchanged** (`/start` §11 +
  `references/critic-moment.md`): fires once on the reconciled spec, same
  skip contract and the internal `challenge` audit.

---

## 5. The conversions

### C1 — Journey map: `shipped | next | later`

`/start` §5's line grammar and harvest carry over unchanged — with one
vocabulary change: `skeleton` presupposes unbuilt. Re-mark every step:

```text
<actor action>  |  <system responsibility>  |  <observable evidence>   [shipped|next|later]
```

`shipped` means the step passes the clean-checkout test at the baseline commit
**today** — not "code exists for it." Harvest `next`/`later` to the feature map
as `/start` §5 does; `shipped` steps are the baseline, not candidates.

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

### C3 — Bones back-derived from every repo's ADR directory, aggregated

1. Scan **each declared repo's** `docs/adr/` with `bones-registry.md` §3's
   scan — already conversion-correct across filename forms and gapped
   series; use it, do not rewrite it — and aggregate: an ADR anywhere in
   the product's repos is a decision the registry owes an entry.
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

The skeleton exists — it was built before ossify arrived; `release_status`
accepts `closed`. **Do not reconstruct per-slice history as spines and work
items** — unearned records. The first ossify-planned release is Release 1.

Then author the **stub retrospective** at
`"$(oss release_dir r0)/release-retrospective.md"` — recording the adoption,
not a spine retro. That filename is `plan-release` §4's previous-release
input — the one thing it lacks after a retroactively-closed Release 0.

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

### C6 — Record the demo-ledger seed candidates

The only ledger verb, `oss ledger_add_auto`, keys every line to a spine, and
C4 deliberately creates none — adoption cannot mint them, and **no ceremony
consumes the candidates yet** (#293 wires the first post-adoption spine
to). Record them in the adoption record anyway — small, end-to-end, from
the current cut's journey, not a transcription of the test suite: the first
spine close should exercise the shipped surface, and until that wiring
exists the vacuous-window risk stands, named rather than hidden.

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
| **Adoption record** | `<ai-workspace>/ADOPTION.md` | author — baseline table, gates passed, merged-vs-authored, **every C2 gap**, the C6 seed candidates |

The adoption record is the point: it is the only artifact that says what
adoption actually did, and it is what a later `doctor` run reads when the spec
and the state disagree (doctor §1's routing list routes it there).

Close with `oss doctor` (the state gate: `state`, `schema`, `replay`,
`shape`) and name the next step: **`/plan-release`** for Release 1.

---

## 7. Never

- **State-schema migration.** `oss migrate` is a different thing. Do not
  overload the word.
- **Touching the legacy stack's STATE** — roadmap position, cursor, slice
  and worktree structure: read, never written. Reconciling the legacy
  ARTIFACTS (spec, `CLAUDE.md`, memory bank, ADRs) is C5's job. Adoption
  is additive; the operator retires the old stack at their choosing.
- **Mid-slice adoption.** §3 A5 refuses it by design.
- **Repairing what it finds.** C2 gaps and stale ADRs are findings.
- **Letting this body exceed 250 lines.** Thin-by-design is a stated
  constraint, not an aspiration. Depth belongs in pointers, never restated.

---

## 8. Slash-command interaction

The `/adopt` command exports the raw argument as `$ARGUMENTS` via the env-var
bridge — parse it in bash; never reference `$1`/`$2`/`$N`. The only argument
is an optional project name, passed to `oss init`; when absent, ask before
initializing. The command is Claude-Code-only; the skill body reaches
OpenCode by path as the native `adopt` skill (#131 tracks the command gap
for all eleven).
