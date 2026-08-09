# ossify Capability-Gap Absorption — the seven capabilities

**Date:** 2026-08-09
**Status:** DESIGNED 2026-08-09, awaiting implementation sequencing into the v0.2/v0.3 roadmap
**Origin:** Consolidation review — "only ossify + ai-mentor + architect-critic + claude-security-audit; absorb the useful capabilities from superpowers (obra) and mattpocock/skills into ossify"
**Home:** ossify — absorbed as `references/` under existing entry skills; zero new entry skills
**Amends:** the release roadmap (`2026-08-06-ossify-release-roadmap.md`) — adds gap-absorption items to the v0.2.0 and v0.3.0 sections

---

## 0. Preamble — the lean/tree verification

A precondition for this spec was verifying that ossify's architecture already complies with the
"few agent-facing starting points, tree-based exploration down a routed intent" philosophy. It does.

**Every-call cost (what the agent sees on every turn):**
- 5 entry skills shipped today (6 with `doctor`, on the v0.3 roadmap), each surfacing only its
  frontmatter `description` (~2-3 lines).
- 8 utility commands planned at name-only cost (`/handoff`, `/defer`, `/work-pr`, `/changelog`,
  `/runbook`, `/adr`, `/flip-adr`, `/amend-spec`).
- Commands are thin `$ARGUMENTS` dispatchers — the `.md` in `commands/` parses args and invokes the
  skill, nothing more.

**Tree depth (loaded only when an entry skill routes to it):**
- `start/references/` — 12 docs (journey-map, skeleton-cut, bones-registry, posture-block,
  spike-contract, smoke-test-pass, lean-spec-schema, onboarding-question-subset, memory-bank-brief,
  risk-gates, critic-moment).
- `close/references/` — 10 docs (cumulative-demo, impl-check, harvest, spine-close, release-close,
  patch-lane, retrospective, routing, work-item-close, fake-expiry).
- `plan-spine/references/` — 8 docs (decomposition, dag-rounds, demo-authoring, demo-amendments,
  fake-ledger-discipline, spec-authoring, citation-foldin, cross-repo).

All ceremony depth lives in `references/` — zero listing cost until the router loads it. This is
exactly the progressive-disclosure model §9.1 specifies. **The tree structure absorbs capability
skills the same way it absorbs ceremony procedures: as reference docs, at zero every-call cost.**
This spec uses that property; it adds no entry skills and changes no listing cost.

---

## 1. Problem & evidence

The goal: only four plugins — **ossify + ai-mentor + architect-critic + claude-security-audit** — and
have them cover every capability that two well-regarded external skill libraries provide today:

- **superpowers** (obra/superpowers): test-driven-development, systematic-debugging,
  verification-before-completion, brainstorming, writing-plans, executing-plans,
  dispatching-parallel-agents, requesting-code-review, receiving-code-review, using-git-worktrees,
  finishing-a-development-branch, subagent-driven-development, writing-skills, using-superpowers.
- **mattpocock/skills**: ask-matt, grill-with-docs, triage, improve-codebase-architecture,
  setup-matt-pocock-skills, to-spec, to-tickets, implement, wayfinder, prototype, diagnosing-bugs,
  research, tdd, domain-modeling, codebase-design, code-review, resolving-merge-conflicts, wizard,
  grill-me, grilling, handoff, teach, to-questionnaire, wait-what, writing-for-agents.

A capability-by-capability trace (every skill in both repos mapped against ossify's 5 entry skills,
its planned v0.3 additions, and the 3 companion plugins) produced three buckets:

**Already covered (14 capabilities) — no action.** TDD, writing/executing plans, brainstorming,
verification-before-completion, git worktrees, finishing a branch, subagent-driven development,
grill-me/grilling, parallel-agent dispatch, ticket decomposition, implement, wait-what, handoff
(v0.3). These are either embedded in ossify's entry-skill contracts (TDD in the implementer gate,
worktrees in `lib/worktree.sh`, planning in `plan-release`/`plan-spine`) or owned by a companion
(grill-me in ai-mentor).

**Deliberately not covered (6 capabilities) — ossify replaces them.** triage (ossify uses feature map
+ release planning), wayfinder (release planning + rolling wave IS the long-horizon decomposition),
to-spec/to-tickets/improve-codebase-architecture (ossify does these interactively via `start` +
`plan-spine`, not as one-shot synthesizers), ask-matt (ossify's 6 entry skills are the routers).

**Seven real gaps** — capabilities with no home in any of the four plugins. These are the subject of
this spec. Each is a discipline an agent needs at a specific lifecycle moment, none is an entry point,
and all seven fit ossify's progressive-disclosure tree as `references/*.md` under the entry skill
whose lifecycle moment triggers them.

---

## 2. Design goals

1. **No new entry skills.** ossify stays at 6 (5 shipped + `doctor`). The every-call listing cost is
   unchanged.
2. **Zero every-call cost.** Every absorbed capability is a `references/*.md` doc, loaded only when
   its owning entry skill routes to it. The agent never sees the frontmatter of a capability it isn't
   using.
3. **Original content, inspired by prior art — not copied.** ossify owns and maintains these docs.
   They are authored for ossify's vocabulary (spines, bones, work items, ceremonies) and cite
   superpowers/mattpocock as prior art where the lineage is direct, not as a content source.
4. **One capability per reference doc.** Each gap maps to exactly one `references/*.md`, under exactly
   one entry skill. No doc spans two lifecycle moments; if a capability is relevant at two moments,
   the primary doc lives under the earlier moment and the later one cross-references it.
5. **Folded into the existing roadmap, not a parallel track.** Each absorption lands in the release
   whose theme and touched entry skill it belongs to (§7).

---

## 3. Decisions

| # | Decision |
|---|---|
| 1 | **References only** — all 7 capabilities are `references/*.md` under existing entry skills. No standalone utility commands, no new entry skills, no promotion to the every-call listing. |
| 2 | **All 7 gaps close** — not just the top tier. The second-tier gaps (prototype expansion, merge-conflict resolution, domain-modeling maintenance, codebase-design) are real and close under the same model. |
| 3 | **Original ossify-owned content** — authored from ossify's vocabulary and lifecycle; superpowers/mattpocock are cited as prior art, never as a content source. ossify maintains these going forward. |
| 4 | **Folded into the existing roadmap** — each absorption lands in the release (v0.2 or v0.3) whose theme and touched entry skill it matches. No separate consolidation track. |
| 5 | **The existing-skills reassessment loop is out of scope here.** After the 7 gaps close, a separate enhancement pass will re-audit ossify's inherited scaffold-dev/scaffold-onboard skills for quality. This spec only closes the 7 gaps. |

---

## 4. Architecture & ownership

```
ossify/skills/start/references/
  research.md              NEW  (gap 3)
  prototype.md             NEW  (gap 4)
  domain-modeling.md       NEW  (gap 6)

ossify/skills/plan-spine/references/
  codebase-design.md       NEW  (gap 7)

ossify/skills/work-item/references/
  debugging.md             NEW  (gap 1)

ossify/skills/close/references/
  code-review.md           NEW  (gap 2)
  merge-conflict-resolution.md  NEW  (gap 5)
```

**Ownership rule (from §9.1):** a reference lives under the entry skill whose lifecycle moment
triggers it. When a capability is relevant at two moments, the primary doc lives under the earlier
one and the later one points to it. No reference is orphaned at plugin root (a deliberate contrast
with the `/handoff` v2 design, which is plugin-root because it belongs to no lifecycle stage at all).

**Naming:** the kebab-case or single-word name of the capability, matching the existing reference-doc
convention (`bones-registry.md`, `journey-map.md`, `impl-check.md`).

---

## 5. The seven capabilities

Each entry below is the contract for the reference doc to be authored: what it covers, what lifecycle
moment triggers it, how it relates to existing ossify concepts, and the prior art it draws from.

### Gap 1 — debugging

| | |
|---|---|
| **Doc** | `work-item/references/debugging.md` |
| **Lifecycle trigger** | A work item or spine is failing (RED that won't go green, a close ceremony that won't pass, a regression surfaced by the cumulative demo) and the cause isn't obvious. |
| **Covers** | A disciplined diagnosis loop: build a reproducible red signal first, minimize it, hypothesize, instrument, fix, regression-test. The loop is: **make it red reliably → minimize → hypothesize → instrument → fix → regression-test**. Distinguishes "the bug" from "a symptom" by insisting on a reproducible signal before any fix is attempted. |
| **Relationship to existing concepts** | Distinct from TDD (which prevents bugs by writing the test first) — debugging is for bugs that escaped. Distinct from impl-check (which verifies ACs mechanically) — debugging finds why an AC fails. The `work-item` RED gate already stops on a failing test; debugging.md is what the agent reads when the RED is not a simple "implement the missing thing". |
| **Prior art** | superpowers `systematic-debugging` (4-phase root cause process: root-cause-tracing, defense-in-depth, condition-based-waiting); mattpocock `diagnosing-bugs` (build a feedback loop that goes red on this bug → minimise → hypothesise → instrument → fix → regression-test). |

### Gap 2 — code review

| | |
|---|---|
| **Doc** | `close/references/code-review.md` |
| **Lifecycle trigger** | Spine close, before merge into the spine branch. The review runs over the actual diff (the work item's staged content or the spine's accumulated diff). |
| **Covers** | Two-axis review: **Standards** (does the diff follow the repo's documented coding conventions + a Fowler smell baseline — long methods, feature envy, duplicated logic, inappropriate intimacy) and **Spec** (does the diff faithfully implement the originating work-item handoff / spine spec, or did scope creep or drift in). The two axes run as parallel sub-agent passes so neither pollutes the other; findings merge at the end. |
| **Relationship to existing concepts** | Fills the gap between **architect-critic** (which reviews specs and designs, not code diffs) and **impl-check** (which verifies ACs mechanically — halt-on-first-fail, report cross-check, machine-checkable rules). Code review is the judgment layer impl-check doesn't cover: "the code works (impl-check passed) but is it good code, and is it the right code?". Distinct from the architect-critic bone-touch check (which asks "did a flesh spine touch a bone") — code review asks about quality and fidelity, not architectural classification. |
| **Prior art** | mattpocock `code-review` (two-axis: Standards + Spec, parallel sub-agents, Fowler smell baseline); superpowers `requesting-code-review` + `receiving-code-review` (pre-review checklist + responding to feedback). |

### Gap 3 — research

| | |
|---|---|
| **Doc** | `start/references/research.md` |
| **Lifecycle trigger** | Spec-core onboarding encounters a tech claim beyond what a smoke test covers (an external API's rate limits, a framework's concurrency model, an integration's auth flow) where the bone's soundness depends on facts that must be gathered, not verified by a 20-line script. |
| **Covers** | Investigate a question against high-trust primary sources (official docs, RFCs/specs, source code, published benchmarks — not blog aggregators), capture the findings as a cited Markdown file in the repo's AI workspace, and state the confidence level of each claim. Background-agent-capable (dispatched, returns a file). The output cites sources inline so a reader can audit the chain. |
| **Relationship to existing concepts** | Distinct from **smoke-test-pass** (which verifies a single tech claim with a throwaway 20-50 line isolated test — "does this crate compile and do the thing I think"). Research is for questions that need reading, comparison, or tracing across multiple sources — "which of these three approaches fits our constraints, and what are the real trade-offs". The smoke test is the verification; research is the investigation that precedes or replaces it when a test can't answer the question. |
| **Prior art** | mattpocock `research` (investigate against high-trust primary sources, cited Markdown, background agent). |

### Gap 4 — prototype

| | |
|---|---|
| **Doc** | `start/references/prototype.md` |
| **Lifecycle trigger** | Spec-core surfaces a UI/state/logic design question where the skeleton-cut is uncertain — "what should this flow look like?", "will this state model feel right?", "which of these interaction patterns should we build?". |
| **Covers** | Build a throwaway prototype to answer a single design question. Single shareable HTML file for state/logic questions (the state machine runs in the browser, no backend); multiple radically different UI variations toggleable from one route so the user can compare them side by side. The prototype is disposable by contract — its fate is discard; learned decisions are reimplemented inside the product (no laundering by cleanup). |
| **Relationship to existing concepts** | Expands ossify's **spike family**. The existing **spike-contract** reference covers architectural uncertainty (one hypothesis, a falsifier, a timebox, `code_fate: discard`). The existing **feasibility spike** (§4 station 3) is the formalized version. Prototype is the sibling for *experiential* uncertainty — "I don't know what it should feel like until I see it" — rather than *technical* uncertainty ("I don't know if this will work until I test it"). Both share the discard-by-contract discipline; they differ in what the throwaway artifact is (a hypothesis-test vs. a UI variation). |
| **Prior art** | mattpocock `prototype` (throwaway HTML for state/logic questions, multiple UI variations from one route). |

### Gap 5 — merge-conflict resolution

| | |
|---|---|
| **Doc** | `close/references/merge-conflict-resolution.md` |
| **Lifecycle trigger** | Spine close or a DAG round merge hits a conflict. ossify currently halts on conflict ("halt-and-surface"); this reference is what the agent reads to resolve rather than surface. |
| **Covers** | Work through a conflict hunk by hunk, resolving each by **intent traced to each side's primary source** (the spine spec, the work-item handoff, the bone ADR), then finish the merge/rebase operation. Never `--abort` (that discards work irreversibly). The discipline: read both sides' intent from their originating spec/handoff, choose the resolution that preserves both intents (or escalate if they're genuinely contradictory), verify the result builds, commit. |
| **Relationship to existing concepts** | ossify's DAG round execution halts on merge conflict today (§6). The halt is correct for *detection*; this reference adds the *resolution* path. Distinct from the spine's own scope — a conflict between two work items in the same spine is resolved by reading both handoffs; a conflict between the spine branch and the target branch is resolved by reading the spine spec against the target's history. |
| **Prior art** | mattpocock `resolving-merge-conflicts` (hunk-by-hunk by intent, never `--abort`). |

### Gap 6 — domain-modeling

| | |
|---|---|
| **Doc** | `start/references/domain-modeling.md` (cross-referenced from `doctor` once it ships) |
| **Lifecycle trigger** | At onboarding: the initial domain vocabulary is authored alongside the lean MASTER-SPEC. At release closes (ongoing): when the product's understanding of its domain has evolved — a term changed meaning, a new concept emerged, an old one was renamed. |
| **Covers** | Sharpen a project's **ubiquitous language**: challenge every term against the glossary, stress-test definitions with edge-case scenarios ("is a refunded order still an order?"), update the lean MASTER-SPEC's vocabulary section and the relevant bones-registry ADRs inline. The discipline is iterative — the domain model is never "done", it deepens as the product does. Produces a `CONTEXT.md` (or the lean spec's equivalent vocabulary section) that is the single source for "what do we mean when we say X". |
| **Relationship to existing concepts** | ossify authors the initial vocabulary implicitly during spec-core onboarding (the journey map, the bones). This makes it an **explicit, repeatable discipline** rather than an implicit by-product. The revisit triggers on bones (§7) are the architectural cousin — domain-modeling is the conceptual cousin. When a bone supersedes, the domain model often needs a term update too; the two reference each other. |
| **Prior art** | mattpocock `domain-modeling` (sharpen terms against glossary, stress-test edge cases, update CONTEXT.md + ADRs inline). |

### Gap 7 — codebase-design

| | |
|---|---|
| **Doc** | `plan-spine/references/codebase-design.md` |
| **Lifecycle trigger** | Spine decomposition identifies a new module boundary (a new port, a new service, a split of an existing module) or a deepening opportunity in an existing one. |
| **Covers** | **Deep-module vocabulary**: a lot of behavior behind a small interface, placed at a clean seam (the boundary where the interface hides implementation complexity), testable through that interface alone. Guides *where* to cut module boundaries during work-item decomposition, *what* belongs inside vs. outside a module, and *how* to evaluate whether a proposed interface is deep (small surface, rich behavior) or shallow (a leaky wrapper). Provides the vocabulary for debating module boundaries in the spine spec and the bones ADRs. |
| **Relationship to existing concepts** | Complements **bones** (which are about load-bearing *decisions* — system shape, data ownership, stack choice) with module-interface *design discipline*. A bone says "we chose hexagonal architecture"; codebase-design says "this port interface should have 3 methods, not 7, and the adapter hides the retry logic". The two are referenced together when a bone-class spine creates a new boundary. |
| **Prior art** | mattpocock `codebase-design` (deep modules: small interface, clean seam, testable); superpowers `brainstorming` (Socratic design refinement, the upstream of a module-design conversation). |

---

## 6. How the agent reaches each capability

The progressive-disclosure contract: a reference is loaded when its owning entry skill is entered AND
the skill's routing logic determines the reference is relevant. No capability is a standalone slash
command or an every-call listing entry.

| Capability | Reached when | Entry skill that routes to it |
|---|---|---|
| debugging | A work-item RED won't clear or a close ceremony fails | `work-item` (the implementer or the orchestrator reads it) |
| code-review | Spine close, before merge | `close` (the spine-close ceremony references it) |
| research | Onboarding hits a tech claim a smoke test can't verify | `start` (the spec-core flow references it alongside smoke-test-pass) |
| prototype | Onboarding hits a UI/UX/state design question | `start` (the spec-core flow references it alongside spike-contract) |
| merge-conflict-resolution | A round merge or spine close hits a conflict | `close` (the merge step references it instead of halting-and-surfacing) |
| domain-modeling | Onboarding authors vocabulary; release close evolves it | `start` at onboarding; `doctor` cross-references for ongoing maintenance |
| codebase-design | Spine decomposition cuts a new module boundary | `plan-spine` (the decomposition step references it) |

---

## 7. Roadmap sequencing (folded into existing releases)

Each absorption lands in the release whose theme and touched entry skill it matches. Reference docs
are content, not engine features — they complete existing skills, consistent with each release's
theme.

### v0.2.0 — reachability + truth

Theme: *make what exists usable and true*.

- **Gap 1 `debugging.md`** under `work-item` — the execution lane is being made reachable this
  release (finding #1: the entry point for round orchestration). Debugging is the execution lane's
  natural companion: once the agent can *reach* the execution lane, it needs to know what to do when
  execution fails non-trivially.
- **Gap 2 `code-review.md`** under `close` — close is being fixed this release (findings #2-#7).
  Code review is a close-time activity; adding it while close is open is the natural moment.

These two are reference-doc authoring, not engine work — consistent with v0.2's "nothing new is
built, make what exists usable" theme.

### v0.3.0 — Plan C2: records, evolution, utilities

Theme: the version where ossify stops needing scaffold-dev alongside it. This is the explicit
"new reference content" release (`doctor`, the rule evaluator, 8 utility commands, `/amend-spec`,
`/handoff` v2).

- **Gap 3 `research.md`** under `start` — alongside `/amend-spec` architecture-revision lane work
  (both involve gathering and verifying external facts).
- **Gap 4 `prototype.md`** under `start` — expands the spike family alongside `spike-contract.md`;
  both are spec-core design-exploration tools.
- **Gap 5 `merge-conflict-resolution.md`** under `close` — alongside the release-close boundary
  work (both touch merge/close mechanics).
- **Gap 6 `domain-modeling.md`** under `start` (cross-ref from `doctor`) — alongside the `doctor`
  skill build, since `doctor` is the ongoing-maintenance entry point where domain-modeling
  maintenance is surfaced.
- **Gap 7 `codebase-design.md`** under `plan-spine` — alongside the utility-command work; both
  enrich the planning lane.

---

## 8. Scope fence

**In:**
- 7 new `references/*.md` docs, one per gap, under the entry skills specified in §4.
- The roadmap update (§7) adding gap-absorption items to v0.2 and v0.3 sections.

**Out:**
- No new entry skills. No new utility commands. No change to the every-call listing cost.
- No content copied from superpowers or mattpocock — original docs, prior art cited.
- No change to the 3 companion plugins (ai-mentor, architect-critic, claude-security-audit).
- **The existing-skills reassessment/enhancement loop** — after the 7 gaps close, a separate pass
  will re-audit ossify's inherited scaffold-dev/scaffold-onboard skills for quality (many were ported
  without enhancement). That is a follow-up, not part of this spec.
- **Ongoing synchronization with upstream superpowers/mattpocock changes** — ossify owns these docs
  once authored. Enhancements inspired by upstream updates are raised as spec amendments when the
  need is felt, not tracked automatically.

---

## 9. Open questions

1. **code-review sub-agent shape.** The two-axis parallel-sub-agent model (mattpocock) assumes the
   agent runtime supports parallel sub-agents. If ossify's close ceremony runs single-threaded, the
   two axes run sequentially instead. Settle at v0.2 implementation time against the actual close
   ceremony's dispatch model.
2. **domain-modeling artifact location.** Whether the domain vocabulary lives in the lean
   MASTER-SPEC's vocabulary section (current), a separate `CONTEXT.md` (mattpocock's convention), or
   the memory bank. Settle at v0.3 implementation time alongside the `doctor` skill, which is the
   ongoing-maintenance entry point.
3. **prototype vs. spike overlap boundary.** Both are discard-by-contract exploration tools. The line
   ("experiential uncertainty" vs. "technical uncertainty") is clear in principle but fuzzy in
   practice. Resolve at v0.3 authoring time by writing both docs and checking they don't duplicate —
   if they overlap, merge into one `exploration.md` with two modes.
