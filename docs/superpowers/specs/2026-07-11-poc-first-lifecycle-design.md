# Skeleton-First Lifecycle — Unified Plugin Design

**Date:** 2026-07-11
**Status:** APPROVED 2026-07-11; architect-critic close audit (claude + codex) run 2026-07-12 — 11/11 concessions folded (decision log #11); part-two companion APPROVED 2026-07-12 (`2026-07-12-public-private-boundary-design.md`); proceeding to implementation planning
**Note:** retitled from "PoC-First" — "PoC" is reserved for disposable spike output per §3; filename kept for continuity
**Origin:** Brainstorm session 2026-07-11 (skeleton-first methodology redesign)
**Supersedes (per-project, opt-in):** the scaffold-onboard + scaffold-dev pair (workspace-init remains active and global — the new stack depends on it)
**Related:** issue #106 (missing sprint-planning layer, open), issue #28 (VS ID contract mismatch — closed; cited as the bug class the split state model produced), pulse360#15 / PR #110 (disposition triage), `docs/conventions/evolutionary-architecture-playbook.md` (Codex one-shot doctrine companion — this spec is its plugin translation; see §15)

---

## 1. Problem statement & evidence

The current methodology (scaffold-onboard → scaffold-dev) authors a complete multi-year
Phase → Sprint → Vertical Slice hierarchy before any code exists, then executes it
slice-by-slice. Field evidence from PulseTrader (2 sprints closed, 1 in flight,
~42 days, 84 Rust files, 402 tests):

- "User takes a trade through a UI" was scheduled at Sprint 3.1 — **sprint 7 of 12,
  ~12-18 months out**. First UI of any kind: Sprint 2.1. Completing all of Phase 1
  yields zero UI and zero trades *by explicit spec design* (MASTER-SPEC §1.3: "The CLI
  is the proof-of-concept surface, NOT the end product").
- Phases were staged by architectural layer (data → backtester → AI loop → UI →
  live execution), not by user journey. Within Phase 1, roughly half the "vertical
  slices" were horizontal component builds (e.g. VS-1.1.4's user-demo: "inspect the
  SQLite schema"; VS-1.2.3 had no `user:` line at all).
- The `user:` demo grammar legitimized this by casting the user as QA inspector
  ("inspect", "view", "open the record") rather than value recipient. scaffold-dev's
  only demo floor is "≥1 `auto:` OR `user:` line" — a slice closes fully green on
  tests alone.
- Slice demos run exactly once, at that slice's close, and are never re-run. Nothing
  in the lifecycle ever asserts "the product still runs end-to-end."
- The onboarding MVP-cut answer (Q1.3.2, "smallest thing that demos value
  end-to-end?") is captured but **orphaned** — no contract connects it to the roadmap.
  The shipped roadmap exemplar explicitly teaches foundation-first ("nothing
  user-facing yet… The Foundation is the substrate, not the product").
- The 90-day slice band actively coaches users to inflate small slices ("Want to
  group these into 2-3 month visibility windows?") — the opposite of thin-skeleton
  slicing. Zero occurrences of "walking skeleton", "PoC", "tracer bullet", or "spike"
  as methodology concepts across both plugins.
- No release unit exists (sprint close is document aggregation), and no
  architecture-evolution path exists (ADRs are one-way Proposed→Accepted; no
  supersede; amend-spec has no architecture lane).

**Consequence:** the methodology structurally back-loads usable value. The developer's
core motivation loop — *use the thing you're building* — is starved for months even
when execution is flawless.

## 2. Design goals

1. **Usable software early and continuously.** The first release IS the walking
   skeleton: the thinnest end-to-end path through the product surface. Every
   subsequent close proves the product still runs.
2. **Breadth-first features.** Many features arrive early and thin ("feature
   spines"); deepening is a deliberate later pass, not the default.
3. **Architecture without BDUF.** Load-bearing decisions (few, explicit, enumerated)
   are made upfront and validated by the skeleton; everything else emerges under
   guard rails: the ADR lifecycle with supersede, the critic veto, and the
   cumulative product demo acting as the standing fitness check.
4. **Same mechanical rigor.** The orchestration machinery (DAG rounds, worktree
   dispatch, impl-check, harvest, handoffs) survives intact; no ceremony is silently
   skippable. Ceremony *weight* scales by declared spine class, ceremony *presence*
   is deterministic.
5. **Token-budget discipline.** Front-loaded surface ≤ ~6 fully-described entry
   skills; standalone utilities surface at no more than name-only cost; ceremony
   depth loads on demand (skill-tree / progressive disclosure). Target every-call
   listing cost ≈ 0.3-0.4%, vs ~1.5% today. Budget verified against /doctor at
   implementation time.
6. **Non-breaking rollout.** New stack is an adjacent per-project plugin; existing
   projects keep the old stack until explicitly migrated.

## 3. Vocabulary

| Term | Meaning |
|---|---|
| **Skeleton spine** | The thinnest end-to-end path through the *product surface* exercising the core value loop. UI included whenever the product is UI-surfaced (all current Pulse projects); a headless product (library, DB, service) defines its journey at its real surface — e.g. a downstream API round trip — and no UI is invented. Shells allowed per the fake ledger rules (§5.3); the loop must close and be human-usable. |
| **Feature spine** | The thinnest usable version of one feature, landed end-to-end on existing bones. |
| **Deepening pass** | A spine that thickens an existing feature (more depth, polish, performance) rather than adding a new one. |
| **Bone / bones registry** | A load-bearing, hard-to-reverse architecture decision (system shape, module boundary, data ownership, cross-layer contract, stack choice). Enumerated explicitly; each is an ADR; each registry entry carries a **touch surface** (the modules/paths/contracts it governs) so bone-touch is checkable. |
| **Bone spine** (class) | A spine that creates or modifies a bone — the skeleton itself, new boundaries, new cross-cutting contracts. Full ceremony. |
| **Flesh spine** (class) | A spine entirely on existing bones — features, deepening, polish. Core ceremony only. |
| **Release** | A promise phrased as *what a user can DO at close* (never as which layers exist). Ladder: **Skeleton (Release 0) → MVP → v1 → vN**. "PoC" is reserved for what a feasibility spike produces — disposable proof; per the playbook: *if code is expected to survive, it is not a PoC*. MVP promotion is evidence-gated, not spine-counted: the release at which the product can be used independently (cold start, real data lifecycle, recovery path appropriate to solo scale). A **v2** label requires a changed product promise, a new primary journey, or an intentionally breaking public contract — accumulated features alone remain v1.x. Note: the onboarding **skeleton-cut** answer (legacy Q1.3.2 "MVP cut") defines *Release 0/Skeleton*, not the MVP release. |
| **Feature map** | Living ranked list of candidate spines/deepening passes. Replaces the exhaustive upfront BACKLOG + multi-year roadmap. |
| **Cumulative product demo** | The persistent set of demo lines (skeleton's plus each spine's journey contributions), maintained as a ledger in project-state.json. **Spine close** re-runs all accumulated `auto:` lines plus the closing spine's *own* `user:` contribution; the **release close** walkthrough has the human drive *every* accumulated `user:` journey line. Lines can be superseded/retired by later spines (see §5.3); retired lines are archived, never deleted. |
| **Risk gate** | An explicit, recorded deferral **plus control set** for harm reasons (e.g. "real money only after paper trading is proven"). Distinct from value back-loading; first-class in the spec. Each gate carries a **touch surface** (like a bone) and a **control checklist** scaled to the harm (for money/destructive gates: simulation/paper environment, human confirmation, kill switch, audit trail, progressive exposure). Harm is orthogonal to reversibility: a flesh-class change inside a risk surface still gets the gate's controls (§6.1). |
| **Fake ledger** | Per-boundary record of every shell/fake in the product: boundary, real/fake/deferred, reason, **replacement trigger**, contract evidence shared with the planned real adapter. Replacement triggers feed the feature map. See §5.3 for the banned-fakes rules. |
| **Feasibility spike** | Optional pre-spec build for high-uncertainty tech. Declares **one hypothesis, a falsifier, a timebox**, `code_fate: discard`, the evidence retained after deletion, and the decision it enables. Scratch-branch, **disposable by contract**: never merged — learned behavior is *reimplemented* inside the product (no laundering-by-cleanup); sole sanctioned output is learnings folded into the spec. Spikes inherit applicable risk-gate controls (a spike never touches live money/destructive surfaces). |

## 4. Lifecycle arc (five stations, one plugin)

1. **Pair** — workspace-init dual-repo pairing, unchanged. Manifest routing as today.
2. **Spec-core onboarding** — interrogation re-scoped to pre-code decisions only:
   - Product vision + 5-year shape → **narrative section** of the release plan doc;
     zero execution semantics; nothing sequences by it.
   - **A journey map is authored** (Patton-style): the complete user journey
     enumerated step by step — actor action, system responsibility, observable
     evidence — with each step marked **skeleton / next / later**. The map is
     explicitly NOT a build order; it is the derivation instrument for the
     skeleton cut and the seed of the feature map (unmarked/later steps become
     candidate spines).
   - **The skeleton-cut question becomes load-bearing** (renamed from legacy
     Q1.3.2's "MVP cut" to kill the terminology collision — its answer defines
     Release 0/Skeleton, not MVP): the answer is derived by marking the
     **thinnest coherent path** across the journey map, and pre-seeds Release 0
     planning.
   - **Bones registry authored** against a forced-enumeration checklist — every
     category answered or explicitly marked `not-applicable`, never silently
     omitted: system shape & deployment topology; module boundaries & dependency
     direction; data ownership & migration posture; public contracts &
     compatibility policy; trust boundaries & destructive operations; failure
     visibility; rollback/evolution strategy; stack; cross-cutting constraints
     (auth/tenancy). Each entry an ADR from birth with a declared touch surface
     and an optional **revisit trigger** (the condition that reopens it)
     (replaces the single always-Accepted ADR-0001 blob).
   - **Risk gates recorded** as first-class entries, each with touch surface +
     control checklist (§3).
   - **Smoke-test pass over unverified claims** (per promoted principle
     pp-smoke-test-pre-spec): every technology claim a bone rests on (crate
     names, versions, API surfaces, integration assumptions) is either verified
     by a minimal isolated smoke test (20-50 lines, throwaway worktree) or
     explicitly marked unverified in the bone's ADR. Routine and lightweight —
     distinct from the feasibility spike, which is for genuine architectural
     uncertainty.
   - **Critic moment at spec-core close:** an architect-critic audit runs
     against the lean MASTER-SPEC + bones registry + skeleton-cut before
     Release 0 planning (restores the old stack's Phase-5/7/close critic
     cadence, which the catalog mapping had silently dropped). Advisory,
     disposition-triaged — but it fires before the bones harden.
   - **Lean-bootstrap rule (Release-0 minimums):** every spec-core artifact has
     an explicit Release-0 minimum — journey map: the one core journey; bones:
     only what the skeleton touches; fake ledger: skeleton shells only; feature
     map: may be three lines; posture: may be "default-private, revisit at
     MVP". Onboarding-to-first-code is measured in days; artifacts grow at
     release closes like everything else. (Guard against replacing BDUF with
     ceremony sprawl at bootstrap.)
   - NOT authored here: exhaustive FR/NFR enumeration, PRD/SRS/BACKLOG,
     multi-year roadmap, PROJECT_PLAN.
   - Output: lean MASTER-SPEC, EXECUTIVE-SUMMARY, memory bank + CLAUDE.md
     (derivation re-anchored to the lean schema, see §13.2), bones-registry ADRs,
     seed feature-map entries harvested from the vision conversation.
3. **Feasibility spike (optional, explicit)** — per the spike contract above.
   Offered when spec-core surfaces genuine technical uncertainty (e.g. Forge3D's
   agent-first 3D modeling core).
4. **Release 0 — the skeleton** — mandated first release containing exactly the
   skeleton spine (bone class by definition, full ceremony). **Release 0 goes
   through the normal `plan-release` ceremony** with the skeleton spine pre-seeded
   from the skeleton-cut answer; the retro input is n/a and the feature map may be
   sparse. **Close criterion (clean-checkout test):** from a clean checkout, the
   named actor enters through the real entry point and reaches the observable
   outcome — without editing storage, invoking hidden developer operations, or
   receiving manual repair. Release 0 must also contribute **one automated
   golden-journey `auto:` line** to the cumulative ledger (the journey as a
   standing regression test, not only a ceremony walkthrough).
   - PulseTrader example: type strategy idea in chat → coach/composer → DSL →
     backtest → results on screen → one refinement iteration, in a minimal Tauri UI.
   - Anti-example (the old way): CLI-only loop declared "not the end product."
5. **Rolling releases** — MVP = skeleton + 2-3 feature spines; then v1, vN.
   Breadth-first thin spines by default; deepening passes when earned; risk gates
   honored. Post-v1 the same loop continues into maintain/scale (spines trend
   smaller and flesh-classed; runbooks accrete at release closes). No separate
   maintenance mode.

## 5. Planning system (three layers)

### 5.1 Feature map
Living ranked list. Entry schema (thin by design): `name`, one-line user value,
rough class guess (bone/flesh), known dependencies, source (journey map / spec /
release retro / deferral / **fake-ledger replacement trigger**). Groomed at every
release close. Replaces upfront BACKLOG as the planning source of truth
(BACKLOG.md becomes a derived record, see §8). Lives in project-state.json
(AI workspace).

### 5.2 Release planning  *(fixes #106 — promoted from missing-enhancement to load-bearing ceremony)*
Inputs: feature map, bones registry, previous release retro (n/a for Release 0),
and **real-use findings since the last release** (mandatory input — what broke,
what annoyed, what you reached for and didn't find while actually using the
product; this is the motivation loop feeding back into planning).
Steps:
1. Select spines from the map for the release; phrase the release exit criteria as
   user journeys ("at close, a user can …").
2. Sequence spines by inter-spine dependency (explicit DAG at spine granularity).
3. Declare each spine's class. **Critic veto — input contract:** the plugin
   submits RELEASE.md + the bones registry (with touch surfaces) + each spine's
   plan to a standard architect-critic pass and interprets its findings — a
   veto finding auto-applies as reclassification to bone (spec-aligned safety
   default per the disposition-triage policy); the user may explicitly override,
   and the override is recorded in project-state.json with a reason.
   **Ambiguous, contradictory, or stale critic findings default to ESCALATE,
   never to pass** — the veto's false-negative posture is fail-closed.
   architect-critic itself is unchanged (see §12). Independently of the critic:
   a spine whose plan touches any bones-registry touch surface is reclassified
   to bone automatically at this step. The veto and bone-touch judges are
   themselves eval-gated before ossify ships (§13.4).
4. Create release spec directory `docs/specs/release-N/` (AI workspace, manifest-
   routed); emit `RELEASE.md` (goal, spine order + dependencies, classes, exit
   criteria).
5. Sketch the **next** release (goal + candidate spines, no detail). Rolling wave:
   current release detailed, next sketched, feature map beyond.

### 5.3 Spine planning
Today's slice orchestration re-anchored. Deliberate changes from planning-vertical-slice:
- Work-item count is whatever the spine's scope needs, bounded 1-5. The old
  "4-5 items" norm and the anti-microscope rule no longer act as floors — a thin
  spine of 1-3 items is legitimate and expected. (There is no separate "weight"
  axis; class is the only declared classification, and item count simply follows
  from decomposition.)
- **Demo criteria are authored here** (planning time, with implementation context),
  not at roadmap time. **Floor rules:**
  - Every spine MUST contribute ≥1 demo line to the cumulative ledger.
  - A user-facing spine MUST contribute ≥1 `user:` **journey line** — phrased as
    an action the user performs to get value (a verb + observable outcome), never
    artifact inspection. Inspector phrasing ("inspect the schema", "view the
    record", "open the file") is banned for journey lines.
  - An internal spine (rare; must be declared at release planning) may
    contribute `auto:` lines only — and is admitted **only** if it names the
    committed user-facing spine that consumes it, scheduled in the current or
    next release (one-release-ahead cap). If the consuming spine is dropped, the
    internal spine returns to the feature map. An internal spine cannot claim
    product value. (This is the mechanical anti-foundation-phase rule: "the UI
    will consume it someday" no longer qualifies.)
  - A deepening pass claiming a measured quality (performance, reliability,
    cost) must state **before/after evidence** in its demo contribution — a
    perf spine that closes green without measuring anything is not a close.
- **Fake ledger discipline** (selective fakes reduce breadth, not truth): any
  spine that introduces or retains a shell/fake records a fake-ledger entry
  (boundary, real/fake/deferred, reason, replacement trigger, contract evidence
  shared with the planned real adapter). **Banned fakes:** faking the core
  hypothesis or the actor's outcome; bypassing the real entry point or a
  load-bearing integration seam; replacing safety/money/identity/ordering
  invariants; hiding failure signals or requiring manual state repair; a fake
  whose semantics differ from its planned replacement; speculative abstractions
  solely to make something mockable. AI providers are volatile external
  boundaries and always sit behind a product-owned swappable interface — which
  does not license speculative interfaces around unrelated internal algorithms.
  Replacement triggers feed the feature map automatically. **Fake lifecycle
  enforcement:** every fake carries a replacement trigger AND an expiry (a
  release by which it must be replaced or explicitly renewed); a fake whose
  trigger has fired or whose expiry release closes without replacement becomes
  a blocking release-close finding — deferred truth never becomes permanent
  silently.
- **Demo-line amendments:** a spine's plan may declare that it supersedes or
  retires specific accumulated lines (flow changed by a redesign or deepening
  pass), with a reason. Amendments apply at that spine's close; the release-close
  walkthrough uses the amended set; retired lines are archived in state with the
  superseding spine's ID, never deleted.
- **Citation verification** folds in as a mechanical step of spec authoring
  (command-run, not a ceremony). New target set: lean MASTER-SPEC sections +
  bones-registry ADRs + prior releases' SRS/BACKLOG increments where they exist.
  Release 0 specs cite the spec and bones only. Citation re-verification is
  **mandatory** across live spine specs after any bone change (§7).
- Upfront-all-specs ordering relaxes to per-round spec authoring where the DAG
  allows; the critic sees the full spine plan, specs may author round-by-round.
- Grill gates: offered for bone spines at planning (and on any fix-up replan, as
  today); skipped for flesh.

## 6. Execution engine

Unchanged from scaffold-dev (unit renamed slice→spine):
- Work-item execution: handoff doc in → implementer-agent (or Codex backend) in an
  isolated worktree → TDD per `auto:` ACs → staged-never-committed → orchestrator
  owns commits. Gaps-mode, RED-gate, 3-iteration cap, honest-fail reporting.
- DAG rounds, strict-order verification, merge halt-on-conflict.
- implementation-checking per work item (AC halt-on-first-fail, report cross-check,
  machine-checkable rules, zero-tests guard).

### 6.1 Spine close ceremony (class-scoped, deterministic composition)

| Step | Bone spine | Flesh spine |
|---|---|---|
| impl-check per work item | ✅ core | ✅ core |
| **Cumulative product demo** — all accumulated `auto:` lines + the closing spine's own `user:` contribution; canonical post-merge state; halt-on-first-fail; zero-tests guard | ✅ core | ✅ core |
| Memory-bank harvest | ✅ core | ✅ core |
| Handoff / state updates | ✅ core | ✅ core |
| Worktree + branch cleanup (only after harvest) | ✅ core | ✅ core |
| Grill gates (planning + fix-up replans) | ✅ | ⛔ skipped |
| architect-critic | Full audit; **external Codex adversary at close depth** | Single light host-only pass, **including a mandatory bone-touch check** (agent judgment against the bones-registry touch surfaces); a hit reclassifies the spine mid-flight to bone and triggers the bone close path |
| Retrospective | Full | Lean |
| ADR check (bone added/changed → ADR required) | ✅ | via bone-touch check above |

Disposition triage (#109 / PR #110) runs throughout: spec-aligned recommendations
auto-apply; only load-bearing escalations reach the user. (Expectation from field
observation, as a monitoring signal rather than a testable requirement: roughly
90% auto-applied / 10% escalated.)

**Core rows are never skippable in either class** — the close skill executes a fixed
checklist, not a judgment call. This is the structural "nothing forgotten" guarantee.

**Ledger operations contract** (the cumulative demo is an operated asset, not
just a list): every `auto:` line binds to a runnable command + declared
environment/fixture setup at authoring time (a line that can't state its
command doesn't enter the ledger); the ledger has a **wall-clock budget** set
at release planning — exceeding it forces a prune/parallelize/deepen decision
there, never silent growth; a line failing for causes unrelated to any open
spine may be **quarantined** (state-recorded, visible in `doctor`) but must be
fixed or retired by the next release close — quarantine is a parking ticket,
not a shrug. At release close the `user:` walkthrough is grouped by feature;
once it exceeds a user-set budget, unchanged features may rotate through
spot-checks — an explicit recorded choice, default remains the full walk.

**Patch lane (out-of-spine work):** changes that touch no bone, no risk
surface, and no demo-relevant behavior — typo fixes, dependency bumps, doc
tweaks — may commit directly, with a one-line record appended to
project-state.json (self-declared, `doctor`-visible). The next spine close's
cumulative demo re-validates the product regardless, bounding the drift
window. Anything heavier is a flesh spine, however small. This resolves the
policy half of former OQ5; routing mechanics land at implementation planning.

**Risk-gate escalation (harm is orthogonal to reversibility):** a spine whose work
touches a recorded risk gate's touch surface — regardless of bone/flesh class —
escalates to the bone close path **plus that gate's control checklist** (e.g. for
a live-money gate: paper/simulation evidence, human confirmation step, kill-switch
verification, audit-trail check). A flesh-class one-liner inside the live-order
path is still a Risk event. Detection points mirror bone-touch: release planning,
critic pass, close-time check.

### 6.2 Release close ceremony (new; replaces sprint retro as the outer gate)
1. All spines closed (refusal gate, as sprint retro today).
2. Full cumulative demo walkthrough — the human drives **every** accumulated
   `user:` journey line (using the amended line set per §5.3).
3. Release retrospective (aggregates spine retros; same mechanics as today's
   sprint retro).
4. Feature-map re-groom + next-release sketch (the rolling-wave crank).
5. Docs increment (§8).
6. Handoff cleanup for the closed release (as today's sprint-close handoff cleanup
   on the final slice).
7. Optional release tag / PR gate via the carried pr-hierarchical machinery
   (spine→release PR replaces slice→sprint PR).

## 7. Architecture evolution

- **Bones registry** written at spec-core close against the forced-enumeration
  checklist (§4 station 2); each bone an ADR carrying a declared **touch
  surface** (modules/paths/contracts it governs), an optional **revisit
  trigger**, and optionally 1-2 **mechanical fitness `auto:` lines** (dependency
  direction, schema compatibility — mechanical facts only, per the
  agent-review-over-deterministic-gates doctrine) that join the cumulative demo
  ledger; all indexed in project-state.json. Flesh spines may not touch a bone.
  Enforcement points:
  (1) release planning — a plan overlapping a touch surface auto-reclassifies;
  (2) critic veto at release planning (§5.2.3); (3) the flesh light critic pass
  at close runs a mandatory bone-touch check — a hit reclassifies mid-flight.
- **ADR lifecycle completes:** add **Superseded-by**. The "architecture was wrong"
  path: supersede ADR → amend-spec via new **architecture-revision lane** →
  **mandatory** citation re-verification across live spine specs → reconcile
  feature map (and touch-surface index).
- **`proposed-then-flip` is the default for bone spines:** the ADR ships Proposed
  with the spine that builds it and flips to Accepted only on empirical signal
  (skeleton runs; boundary held under a second feature). `/flip-adr` mechanics
  carry over.
- Why this answers the re-architecture fear: bones are few, explicit, validated
  early by the skeleton, and changing one is a visible ceremonied event. Features
  fill flesh; they don't move bones. The two historical failure modes — skeleton
  skipped a layer; boundary drawn wrong — surface in week 2, not month 9.

## 8. Docs & memory: record, not prophecy

- **At onboarding:** lean MASTER-SPEC, EXEC-SUMMARY, memory bank + CLAUDE.md,
  bones-registry ADRs. Nothing else.
- **Per release close:** docs increment — PRD/SRS grow sections describing what now
  exists + the next release's commitment; CHANGELOG release section; BACKLOG.md
  rendered from the feature map. The increment step executes a **trigger table**
  (condition-driven, not vibe-driven):

  | Trigger (first release where it holds) | Required doc/evidence |
  |---|---|
  | Always | RELEASE.md, retro, CHANGELOG section, BACKLOG render |
  | Persistent state exists | Data ownership + migration + backup/restore notes |
  | A risk gate is exposed (its surface now reachable) | Threat/failure notes + audit & recovery plan for that gate |
  | Someone other than the author uses it | Onboarding/quickstart, support path, runbook |
  | v1 (stable public contracts) | Release/rollback procedure, compatibility policy, SLO baseline |
- **Stable IDs, minted incrementally:** new FR/NFR/BACKLOG IDs at release close;
  existing IDs never renumbered (kills the wholesale re-mint defect).
- **Memory bank:** 14-file structure and harvest mechanics unchanged; harvest fires
  at every spine close (core row). Derivation prompts re-anchor to the lean spec
  schema (§13.2).
- **Routing:** release specs + RELEASE.md + project-state.json + feature map →
  **AI workspace**; rendered records (PRD/SRS increments, BACKLOG.md, CHANGELOG,
  runbooks) → **canonical**, all via new manifest logical names registered at
  pairing/migration time.

### 8.1 Capability catalog mapping (nothing falls off)

Every capability's fate names its owner in the §9.1 skill tree.

| Current capability | Fate in unified plugin |
|---|---|
| executing-work-item / implementer-agent | **Unchanged** — `work-item` entry + dispatch from `plan-spine` |
| implementation-checking | **Unchanged** — reference under `close` |
| handing-off-session (+ --ephemeral) | **Unchanged** — utility command `/handoff` (§9.1) |
| deferring-work-item | **Unchanged** — utility command `/defer` |
| working-pull-request | **Unchanged** (already slice-decoupled) — utility command `/work-pr` |
| appending-changelog-entry | **Unchanged** — utility command `/changelog`; natural cadence at release close |
| authoring-runbook | **Unchanged** — utility command `/runbook`; maintain-station cadence |
| authoring-machine-checkable-rules | **Unchanged** — routed from `doctor` |
| pr-hierarchical merge mode (lib/pr.sh) | **Carried** — trigger = release close step 7; spine→release PR |
| scaffolding-memory-bank | **Re-anchored** — derivation prompts target the lean spec schema; invoked from `start` close |
| memory-bank harvest mechanics | **Unchanged**, trigger = spine close (core row) |
| planning-vertical-slice | **Re-anchored** → spine planning (§5.3), under `plan-spine` |
| closing-vertical-slice | **Re-anchored** → spine close (§6.1), under `close` |
| writing-sprint-retrospective | **Re-anchored** → release close (§6.2), under `close` |
| onboarding-project (10-phase) | **Re-scoped** → spec-core onboarding (§4 station 2), under `start` |
| amending-spec | **Extended** → + architecture-revision lane; utility command `/amend-spec` |
| recording-architecture-decision | **Extended** → bones registry + touch surfaces; utility command `/adr` |
| flipping-adr-status | **Extended** → + Superseded-by; proposed-then-flip default for bones; utility command `/flip-adr` |
| validating-master-spec | **Carried** — validates the lean spec schema (§13.2); routed from `doctor` |
| authoring-vertical-slice-demo | **Absorbed** into spine planning (§5.3 floor rules + amendments) |
| verifying-spec-citations | **Absorbed** into spine planning; new target set (§5.3); mandatory after bone changes |
| planning-project-roadmap | **Replaced** by feature map + release planning |
| PROJECT_PLAN.md | **Retired** (RELEASE.md is the plan) |
| scaffolding-governance-docs (upfront bundle) | **Replaced** by per-release docs increments |
| checking-workspace-interoperability | **Absorbed** into `doctor` (it currently lives in scaffold-onboard, not workspace-init; relocating it into the unified plugin keeps workspace-init unchanged) |

## 9. Plugin architecture

### 9.1 Skill tree (progressive disclosure)
Front-loaded entry skills (≤6 with full descriptions; every-call listing ≈0.3-0.4%):

| Entry skill | Routes to (reference-loaded on entry) |
|---|---|
| `start` | spec-core onboarding phases, spike contract, bones-registry authoring, memory-bank derivation brief |
| `plan-release` | feature-map grooming, spine sequencing, class declaration + critic veto, RELEASE.md emission |
| `plan-spine` | decomposition, DAG rounds, spec + demo authoring grammar (floor rules, amendments), citation check, handoff templates |
| `close` | context-routed: work-item → spine (bone/flesh checklists) → release; cumulative-demo runner; harvest steps; retro templates |
| `work-item` | manual dispatch fallback (as today's /work-item) |
| `doctor` | state inspection, spec validation, machine-checkable rules authoring, interop check, migration entry point (phase 2), budget check |

**Standalone utilities** (`/handoff`, `/defer`, `/work-pr`, `/changelog`, `/runbook`,
`/adr`, `/flip-adr`, `/amend-spec`) remain user-invocable mid-session as slash
commands whose procedure docs live as references under their owning entry skill;
the ceremony checklists point to them at the moments they're relevant (e.g. the
close checklist offers `/handoff`). They must not add full skill descriptions to
the every-call listing — the exact surfacing mechanism (command-only vs name-only
listing) is parked in §13.6 and verified against the budget target at
implementation time.

All ceremony depth lives in `references/` inside the owning entry skill — zero
listing cost until the router loads it. Mechanical facts stay in a tested bash
dispatcher (`sd`/`sf` pattern carries over verbatim — the prose-vs-lib lesson).

### 9.2 State
One `project-state.json` (single owner; AI workspace): releases, spines + classes
(+ class-override log), work items, the cumulative demo-line ledger (with
supersede/retire records), bones-registry index (with touch surfaces), feature
map, mutations log. Replaces the roadmap-state / slice-state split and eliminates
the cross-plugin ID-contract class of bugs (#28 was the exemplar).

**State-safety commitments** (architectural, not implementation detail —
single-owner state concentrates every invariant into one file, so it carries
the safety obligations): atomic writes (write-temp + rename, never in-place);
a lock file honored by every mutating ceremony (interactive session vs
background workflow contention is defined, not undefined); a `schema_version`
field from v1 with an explicit migration policy for every subsequent schema
change (the upgrade-input class of bugs is a known repeat offender); the
mutations log is append-only with replay capability (corruption recovery =
replay from last good snapshot); `doctor` checks state-vs-repo drift.

**ID grammar has one owner:** the state schema defines the single ID grammar
for releases, spines, and work items; branch names, worktree paths, release
directories, ledger keys, ADR links, and PR titles all derive from it verbatim
(a parity test enforces this). The concrete grammar is settled at
implementation planning (§13.7) — deliberately NOT colliding with the old
stack's `VS-N.M.K` shapes.

### 9.3 Name — DECIDED: `ossify`
Picked by user at spec review 2026-07-11. Ossification = cartilage hardening into
bone; literally skeleton→product. Verb-able ("ossify the spike"). Rejected
shortlist: backbone, marrow, spineworks, tracer.

## 10. Rollout & migration

- **Coexistence:** unified plugin enabled per-project (project settings);
  **scaffold-onboard and scaffold-dev enter maintenance mode** (bug fixes only, no
  new features) and stay installed for legacy projects; per-project settings flip
  which stack a repo sees (also keeps every session under the 1% skill budget).
  **workspace-init stays active and global** — the new stack depends on it.
  ai-mentor and architect-critic stay global and unchanged.
- **Phase 1 (this spec's implementation plan): greenfield + adopt-forward.**
  New projects start on the new stack; **Forge3D is the greenfield pilot**.
  Phase 1 also ships **adopt-forward** — a lightweight brownfield mode for
  existing projects: freeze the old ROADMAP as historical, run all NEW work
  under ossify (release planning + spines going forward), zero artifact
  conversion; **pulse-trader is the brownfield pilot**. The full `migrate` flow
  (artifact conversion) remains phase 2; adopt-forward is its cheap precursor,
  not its replacement.
- **Pilot evidence contract** (the pilot must be able to fail, or it cannot
  validate): success criteria — time-to-first-usable-release materially under
  pulse-trader's 42-day baseline; ceremony-minutes per flesh spine below the
  old per-slice cost; zero silently-skipped core ceremony rows across the
  pilot; the user reports the motivation loop working (using the product
  between spines). Kill criteria — if the user routes around the tooling for
  ordinary work, or the skeleton isn't humanly usable within the first release
  window, halt and redesign rather than patch. Scope honesty: greenfield +
  adopt-forward evidence covers early-lifecycle mechanics; long-horizon
  behavior (ledger growth, ADR supersession, fake expiry) is validated by
  continued dogfooding, and full `migrate` waits for phase 2 regardless.
- **Phase 2 (follow-up plan, after the Forge3D pilot validates the model): the
  `migrate` flow.** Reads MASTER-SPEC / ROADMAP / memory-bank / ADRs → seeds bones
  registry (from spec Phase 5 + existing ADRs, touch surfaces authored
  interactively) → converts remaining roadmap into feature-map entries (built
  slices = baseline, not retro-fitted spines) → defines Release-next → renders
  RELEASE.md. Old ROADMAP.md archived, not deleted. Priority targets: PulseTrader,
  PulseDB, PulseHive. Early-stage projects migrate trivially.
  - PulseTrader's Release-next under migration = its actual skeleton: chat →
    strategy → backtest → results in a minimal Tauri UI.
- **In-flight work at migration time:** finish the open slice under old rules and
  cut over at the next planning boundary (default), or cut over immediately —
  which requires the open slice to be explicitly closed or abandoned first
  (abandon = harvest what exists + defer remaining items into the feature map);
  no silent conversion of a half-open slice.

## 11. Part two (companion spec — DESIGNED 2026-07-12)

Public/private project structure is now designed in
`2026-07-12-public-private-boundary-design.md` (companion spec; its §8 lists the
exact amendment touchpoints into this document). Summary: per-project posture
decided in spec-core onboarding (default-private), moat items mapped to channels
(data-overlay / private-package / repo-private), boundary contract per public
repo, boundary-as-bone, multi-repo spines via an additive `private_core`
manifest extension, composition-root demo rule, and a blocking boundary audit
at release close. Migration of PulseDB/PulseHive/PulseTrader remains a separate
task consumed by the phase-2 `migrate` flow.

## 12. Non-goals

- No changes to workspace-init, ai-mentor, or architect-critic. The critic veto
  (§5.2.3) and bone-touch check (§6.1) are implemented **plugin-side** by
  interpreting standard architect-critic findings — the critic gains no new
  interface or obligations.
- No single-repo topology work (dual-repo remains the assumption, per existing
  deferral).
- No auto-decomposition of the spec into spines (planning stays interactive;
  the feature map is human-groomed, agent-assisted).
- Old-stack feature development (maintenance mode only).

## 13. Open questions (deliberate, non-blocking)

1. ~~Final plugin name~~ — DECIDED: `ossify` (2026-07-11).
2. **Lean MASTER-SPEC package** — settle as one item at implementation planning:
   the lean spec schema (which sections survive), the onboarding question subset
   (which of the current ~54 stay upfront vs move to release-time prompts), the
   memory-bank derivation-prompt re-anchoring, and the validator rule diff.
3. `project-state.json` schema *field detail* — settle at implementation
   planning, WITHIN the §9.2 state-safety envelope (atomicity, locking,
   schema_version + migration, append-only mutations) which is committed, not
   open.
4. **Promoted to phase-1 ship gate (2026-07-12 critique):** the eval suite for
   ossify's judgment surfaces (critic-veto interpretation, bone-touch check,
   spine-class declarations, journey-line floor). Adversarial fixtures seeded
   from the playbook's ten acceptance scenarios PLUS the historical failure
   modes (a horizontal build dressed as a spine, an inspector-phrased journey
   line, a flesh claim touching a bone). LLM-judge per standing preference.
   **Ossify does not ship until its judges pass them.**
5. ~~Hotfix routing~~ — policy RESOLVED by the patch lane (§6.1, 2026-07-12
   critique); only the routing mechanics remain for implementation planning.
6. Utility surfacing mechanism (§9.1): command-only vs name-only skill listing;
   verify the ≈0.3-0.4% budget claim against /doctor with the real plugin.
7. Concrete ID grammar for releases/spines/work items (§9.2 owns the
   requirements: single owner in state, all surfaces derive verbatim, parity
   test, no collision with old-stack `VS-` shapes).

## 14. Doctrine companion & prior art

`docs/conventions/evolutionary-architecture-playbook.md` (Codex, one-shot from
the same problem statement) is adopted as this methodology's **doctrine layer**:
tool-agnostic principles, vocabulary, and failure modes. This spec is its plugin
translation; where the two conflict, this spec governs execution mechanics and
the playbook governs conceptual framing. The comparison (2026-07-11, two
opposing-bias reviewers) found 15 independent convergences — treated as
high-confidence design elements — plus the extractions in decision log #9 and
the reasoned rejections in #10.

**Failure-mode vocabulary** (adopted for grill-me/critic references): prototype
laundering · foundation phase · demo theater · fake-driven false proof ·
architecture astrology · ceremony inflation · version-number theater ·
invisible maintenance — each named anti-pattern maps to a spec countermeasure
(spike code-fate contract; internal-spine consumer rule; journey-line floor +
clean-checkout test; fake ledger; narrative-only vision + revisit triggers;
class-scoped ceremony; v2 semantics rule; runbook/docs triggers).

**Prior art** the methodology stands on: Hunt & Thomas (tracer bullets,
disposable prototypes), Cockburn (walking skeleton), Ford/Parsons/Sadalage
(evolutionary architecture, fitness functions), Fowler (evolutionary design,
reversibility), Patton (story mapping / thin release slices), Google SRE
(progressive exposure).

## 15. Decision log (from the 2026-07-11 brainstorm)

| # | Decision |
|---|---|
| 1 | Skeleton = thinnest end-to-end path through the product surface, UI always included for UI-surfaced products; coach-style components may be shells; loop must close and be human-usable |
| 2 | Lifecycle: spec-core → skeleton → docs-grow-with-product (option b); feasibility spike available as explicit disposable variant (option c) |
| 3 | Hierarchy: vision demoted to narrative; Release → Feature Spine → Work Item; current release detailed + next sketched (option b+) |
| 4 | Ceremony: two declared spine classes (bone/flesh) with critic veto (auto-applies; user override recorded); flesh skips grill, light critique + bone-touch check; bone gets full ceremony incl. external Codex adversary; core checklist never skippable (option c) |
| 5 | Packaging: one unified per-project plugin (option B); ai-mentor + architect-critic + workspace-init stay global; scaffold-onboard + scaffold-dev enter maintenance mode for legacy projects |
| 6 | Skill-tree progressive disclosure: ≤6 fully-described entry skills, utilities at ≤name-only cost, ceremony depth reference-loaded on entry |
| 7 | Public/private structure split = part two, separate brainstorm + spec |
| 8 | Codex evolutionary-architecture playbook adopted as doctrine companion (2026-07-11 comparison: 15 independent convergences); spec is its plugin translation |
| 9 | Extracted from playbook: risk-gate touch surfaces + control escalation; fake ledger + banned-fakes rules; clean-checkout Release 0 criterion + automated golden-journey line; internal-spine named-consumer rule (one-release-ahead cap); journey map as skeleton-cut derivation; spike hypothesis/falsifier/decision fields; bones forced-enumeration checklist + revisit triggers + optional mechanical fitness lines; trigger-based docs table; real-use findings as release-planning input; v2 semantics rule; MVP evidence-gated; before/after evidence for measured-quality passes; "PoC" reserved for spike output (doc retitled Skeleton-First) |
| 10 | Rejected from playbook (with reasons recorded in §14): full 4-axis taxonomy and 8-stage promotion ladder (classification overhead, honor-system enforcement, enterprise gates without consumers); critique only at D2/D3 (our flesh light pass IS the misclassification detector); horizon-tagging in place of question-cutting (capture-without-contract already failed in the field); standing fitness-function suite with scheduler (deterministic-gate doctrine) |
| 11 | architect-critic close audit 2026-07-12 (claude + codex fresh-frame): 11 challenges, 11 concessions folded — pilot evidence contract + kill criteria; state-safety commitments; critic-veto input contract fail-closed + eval suite as ship gate; patch lane; ledger operations contract; spec-core critic moment restored; bones smoke-test pass; fake expiry enforcement; ID-grammar single owner; adopt-forward in phase 1 (pulse-trader = brownfield pilot); lean-bootstrap Release-0 minimums. Codex's two-track "semi-disposable tracer" mechanism REJECTED on record — it reintroduces the prototype-laundering failure mode its own playbook bans; the disposable spike + lean Release 0 covers both tracks without the laundering seam |
