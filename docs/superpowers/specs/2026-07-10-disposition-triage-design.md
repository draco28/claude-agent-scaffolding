# Design: Disposition triage (standing delegation)

- **Date:** 2026-07-10
- **Status:** Design approved in brainstorm; pending implementation plan
- **Source:** [pulseai-labs/pulse360#15](https://github.com/pulseai-labs/pulse360/issues/15) (agent-ops finding `grill-recommendation-default`)
- **Builds on:** #93 recommend-by-default (CLOSED) — `docs/conventions/recommendation-policy.md`
- **Fix surfaces:** `ai-mentor:grill-me`, `architect-critic:critiquing-spec` (Step 8), `scaffold-dev:planning-vertical-slice` gates, + the recommendation-policy SoT itself

## 1. Problem

The recommend-by-default policy (#93) shipped and works: every grill question,
critique challenge, and orchestrate gate carries a firm, vision-grounded,
cited recommendation. But the user still typed some variant of *"proceed with
your recommendation"* **380 times across 55 sessions** (evidence window ends
2026-07-04, after #93 shipped). The residual friction is the **sequential
confirmation treadmill**: the gates disposition items one at a time even
though the user's near-universal action (~90%) is to accept the
recommendation. The ~10% that genuinely needs the user is the high-stakes
class: vision-misaligned, scope-threatening, high-severity.

Issue #15 proposes a *batch-confirm* vocabulary (`accept all` / `accept all
except <ids>` / `walk them`) offered up front. That saves **typing** but not
**attention** — the user still reads all N items to decide the set is safe.
This design ships the stronger model the user asked for: the agent itself
**triages** — findings answerable from the project's source-of-truth are
processed without being presented; only load-bearing items reach the user.

## 2. Decision summary (locked in brainstorm, 2026-07-10)

| # | Fork | Decision |
|---|------|----------|
| 1 | Core model | **Auto-triage + escalate** — agent auto-applies predicate-clean recommendations same-turn with an audit digest; walks escalated items with full #93 rigor |
| 2 | Escalation criterion | **Composite predicate** (§3.2) — ungrounded / vision-scope-touching / one-way door / top severity / contested |
| 3 | grill-me semantics | **Rule 4 extension: self-answer** — SoT-answerable, predicate-clean questions are never asked; dependent chains + escalations keep one-question-per-turn |
| 4 | Delegation model | **Default-on + per-invocation opt-outs** (`--walk`, `--neutral`) |
| 5 | SoT location | **Amend `recommendation-policy.md` in place** (one policy, one lifecycle, one parity test) |
| 6 | Orchestrate gates | **Gates auto-advance** when their recommendation clears the predicate; escalated gates pause |

## 3. Policy amendment (`docs/conventions/recommendation-policy.md`)

The doc remains the single source of truth, amended in place. Per-plugin
byte-identical copies are re-copied (never hand-edited); the existing parity
test `tests/test-recommendation-policy-parity.sh` continues to enforce
byte-identity.

### 3.1 New rule — disposition triage

Every adopting surface classifies each surfaced decision against the
escalation predicate (§3.2):

- **Clears the predicate** → the recommended disposition is **applied
  immediately** — no user turn spent. Only `accept` and `defer`
  recommendations are auto-appliable.
- **Trips the predicate** → **escalated**: walked with the surface's full
  existing #93 cadence (recommendation attached, accept/rebut/defer,
  rebuttal scoring where the surface has it).

A `rebut`-recommended item is contested by definition and always escalates.

### 3.2 Escalation predicate

Escalate if **ANY** of the following holds:

1. **UNGROUNDED** — the recommendation cannot be cited to a reachable
   source-of-truth (MASTER-SPEC §, memory-bank file, onboarding digest,
   referenced issue/PR). A "(general best practice)" lean **never**
   auto-applies. Citation is the objective proxy for "answerable from our
   documentation."
2. **VISION/SCOPE-TOUCHING** — the finding challenges or would change the
   vision, the scope, or a previously locked/settled decision (as recorded
   in ADRs, memory-bank settlements, or locked-decision sections of specs
   and grill exit summaries), rather than operating within them.
3. **ONE-WAY DOOR** — hard to reverse: public contracts, schema/data
   migrations, deletions, pushes or PR-merges to the canonical repo.
   (Local worktree→slice-branch merges are reversible and do not trip this.)
4. **TOP SEVERITY** — the surface's own top class: `premise`-severity
   challenges in critique; restart-class options at orchestrate gates.
5. **CONTESTED** — the recommended disposition is `rebut`, or the host agent
   and an external adversary (e.g. Codex at close depth) disagree about the
   finding. Agent-vs-agent disagreement needs a human referee.

### 3.3 Rule 5 rewrite (final authority → standing delegation)

Replace the current Rule 5 body with:

> **The user is the final authority.** That authority is exercised two ways:
> **directly**, on every escalated decision; and by **standing delegation**
> on decisions that clear the escalation predicate — a delegation this
> policy documents, the digest makes auditable, and any single invocation
> can revoke (`--walk`). Escalated classes never auto-apply, and an explicit
> user direction always overrides. A recommendation is still a lean, not a
> decision; what changes is that the user has pre-decided, in this policy,
> who dispositions the low-stakes class.

Delegation is itself a user decision — the same shape as the user's standing
"agent does all git ops" authorization in this repo.

### 3.4 Audit digest contract (identical across surfaces)

The same turn that auto-applies emits a compact digest:

```
⚡ Auto-applied K of N
<id> · <finding one-liner> · <accept|defer> · <citation>
...
```

- The stable header string `⚡ Auto-applied` is a **contract** — pulse360's
  regression watch counts it; anchor tests grep for it.
- `reopen <ids>` pulls any auto-applied item back into a full walk — honored
  any time before the run's state append / while the session lives.
- Auto-applied `defer`s remain **tracked** (deferred-challenges JSON in
  critique; `/defer` issue filing in scaffold-dev) — never silently dropped.

### 3.5 Vocabulary (identical across surfaces)

| Phrase / flag | Effect |
|---|---|
| `--walk` / "walk them" | Full sequential #93 walk; nothing auto-applied |
| `--neutral` / "no recommendations" | Unchanged meaning: no recommendations at all → transitively disables triage (nothing grounded to apply); full neutral walk (pre-#93) |
| `reopen <ids>` | Pull auto-applied item(s) back into a full walk |
| `accept all` / `accept all except <ids>` | Honored as explicit bulk responses **on the escalated set** (a human is actually deciding there) |

Opt-outs are per-invocation, not sticky.

## 4. Per-surface rendering

### 4.1 `architect-critic:critiquing-spec` (Step 8)

New **Step 8.0 — Triage**, before the walk:

1. Classify the consolidated challenge list against the predicate.
2. Emit the digest (§3.4): auto-applied accepts are recorded as concessions;
   auto-applied defers append to `DEFERRED_CHALLENGES_JSON` as today.
3. Run today's sequential rebuttal cycle **on the escalated subset only** —
   rebuttal scoring rubric, CORE tone, and emotional-state handling
   unchanged.

The existing `alternative`-severity end-batching is **subsumed** by triage
(alternatives will almost always clear the predicate). Existing escape
hatches (`linear from here` etc.) stay. `--neutral` behavior unchanged.

### 4.2 `ai-mentor:grill-me`

Framed as a **Rule 4 extension**, not a new mode: *a question whose answer is
citable from the source-of-truth and clears the escalation predicate is never
asked* — the agent adopts its own lean as the working answer.

Two hard guards keep strict one-question-per-turn (Rule 1):

- **Escalated questions** (predicate-tripping).
- **Dependent chains** — where the next question hinges on the user's
  previous answer; auto-answering mid-branch risks exploring a path the user
  would never have chosen.

The exit summary gains a fourth section: **Self-answered (delegated)** —
question, adopted answer, citation, per item. `reopen` works here too.

### 4.3 `scaffold-dev:planning-vertical-slice` (orchestrate gates)

Gates (§4 decomposition, §5 rounds, §7.2 audit-skip, §8.5 fix-up, §8.7
round/slice-close) **auto-advance** when their recommendation clears the
predicate — one digest line each; escalated gates pause exactly as today.

Natural consequences of the predicate (documented as examples in the skill):

- Slice-close canonical PR/merge → **escalates** (one-way door).
- A decomposition that reshapes scope → **escalates** (vision-touching).
- Routine round-close worktree→slice-branch merges → auto-advance.
- grill-me offers at gates 1/2/3 (default no) → auto-resolve with a digest
  line — visible, not silent; `--walk` restores the explicit offer.

`--neutral` and `--walk` forward into nested skill invocations
(architect-critic, grill-me) as `--neutral` forwarding does today.

### 4.4 `ai-mentor:council`

Untouched — already one-shot (issue #15 itself cites it as the reference
model for "surface everything, decide once").

## 5. State & auto-promotion semantics

- `state.json` schema v3 `recent_runs[]` gains two **backward-compatible
  optional fields**: `auto_applied_count`, `escalated_count` (new optional
  flags on `arc state_append_run`; default 0 when omitted — same pattern as
  the deferred fields).
- **Concession semantics unchanged**: auto-applied accepts *are*
  concessions, just separately countable via `auto_applied_count`.
- **Auto-promotion pipeline untouched**: the candidates pile only collects
  challenges that stood after a rebuttal; auto-applied items never rebut, so
  no semantic drift.
- grill-me stays stateless — the exit summary's *Self-answered (delegated)*
  section is the record.
- scaffold-dev records auto-advanced gates in the round-complete handoff.

## 6. Settled decisions this supersedes (explicit)

1. **"Sequential rebuttal" (architect-critic v0.2 grill settlement,
   2026-05-22→24)** — narrowed, not removed: sequential now governs the
   escalated subset only.
2. **Eval S1 "explicit grill-me offer — no silent skip/invoke"
   (scaffold-dev)** — offers now auto-resolve *with a digest line*; S1's
   target was silence, and the digest is not silent. `--walk` restores the
   explicit offer.
3. **Issue #15's literal ACs** — written for the weaker batch-confirm model;
   superseded by this design. Its regression AC survives verbatim (§8).

## 7. Testing & rollout

- **Parity:** re-copy the amended SoT to the three plugin copies
  (`ai-mentor/references/`, `architect-critic/templates/`,
  `scaffold-dev/skills/planning-vertical-slice/references/`); existing
  parity test enforces byte-identity.
- **Anchor tests:** extend the existing grep-anchor tests (scaffold-dev
  `tests/test-recommendation-policy.sh`, architect-critic
  `tests/unit/test-recommendation-policy.sh`) for the new policy section
  headers + the `⚡ Auto-applied` digest marker — mechanical facts only;
  semantic quality stays agent-reviewed (standing principle:
  agent-review over deterministic gates).
- **Versions:** minor bumps to ai-mentor, architect-critic, scaffold-dev
  (`plugin.json` + marketplace metadata) — required for `/plugin update`
  visibility.
- **Process:** file a marketplace-repo issue carrying this design (the #93
  pattern) → implement on a branch → Codex runs the PR-fix cycle → Claude
  independently verifies unresolved threads by GraphQL count → merge + tags
  → close the marketplace issue → mark pulse360 finding
  `grill-recommendation-default` as built.
- **Dogfood AC:** one live critique + one live grill on a real multi-item
  artifact; digest fires; zero manual proceed-repetitions; `--walk` and
  `reopen` exercised once each.

## 8. Acceptance criteria (mapped from issue #15)

- [ ] `/critique` with N challenges triages before walking: predicate-clean
      challenges auto-applied with digest; escalated subset walked with the
      full rebuttal cycle.
- [ ] `/grill-me` self-answers SoT-answerable, predicate-clean questions
      into the *Self-answered (delegated)* exit-summary section; dependent
      chains and escalated questions remain one-question-per-turn.
- [ ] scaffold-dev orchestrate gates auto-advance on predicate-clean
      recommendations; escalated gates (incl. canonical merge boundaries)
      pause.
- [ ] Disposition vocabulary (`--walk` / "walk them", `reopen <ids>`,
      `accept all [except <ids>]` on escalated sets) identical across the
      three skills.
- [ ] `--neutral` unchanged and transitively disables triage; opt-outs are
      per-invocation.
- [ ] Convention documented in `docs/conventions/recommendation-policy.md`
      (single SoT); parity copies byte-identical; parity + anchor tests
      green.
- [ ] **Regression (verbatim from #15):** a fresh critique/grill session on
      a multi-item plan requires **zero** manual "proceed with your
      recommendation" repetitions to accept the set.

## 9. Out of scope

- `ai-mentor:council` changes (not implicated).
- Sticky per-project delegation config (rejected at fork 4 — coupling cost;
  revisit only if per-invocation opt-outs prove insufficient).
- Any change to *what* the surfaces challenge or ask (#93 boundary holds:
  policy governs presentation and disposition, never content).
- pulse360/agent-ops dashboard changes (it already regression-watches built
  findings; the digest header gives it a countable marker).
