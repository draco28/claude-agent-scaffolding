# Handoff: workflow + collaboration brainstorm (next plugins)

**Purpose:** seed a fresh Claude Code session to brainstorm the next two design areas in the `claude-agent-scaffolding` marketplace — **the overall project-workflow cadence** and **the discuss/collaborate-with-others layer**. This document is a self-contained briefing — read it first, then drive a brainstorm with `superpowers:brainstorming` per the workflow established in `docs/HANDOFF-architect-critic-build.md`.

**Author:** carried over from the session that shipped architect-critic v0.1.0 → v0.1.3 (2026-05-14 → 2026-05-16). At handoff time, the marketplace has 4 plugins (all at first-stable release); the two design areas below are genuinely new territory not covered by what already exists.

---

## 1. Current marketplace state (what's already shipped)

| Plugin | Version | Scope | What it covers |
|---|---|---|---|
| **ai-mentor** | v1.3.0 | User-level | *Cognitive partner* — spotter mode (Curve 2: `/z2-decide`, `/z2-build`, `/locked`), quiz (`/quiz l1`..`l4`), beginner's mind (`/fool`), simplifier (`/eli10`), prompt rewriter (`/improve`). Plus the `grill-me` sibling skill for Socratic plan/design interrogation. |
| **scaffold-onboard** | v0.1.0 | Project-level (run-once) | *Project bootstrap* — 10-phase `/onboard` conversation authors `MASTER-SPEC.md`; deterministic `/scaffold-project` derives 11-file memory-bank + `CLAUDE.md` + 5/14 governance docs. |
| **scaffold** | v1.0.0 | Project-level (continuous) | *Slice-driven implementation* — 5-phase per-slice workflow (`/slice-contract` → `/slice-scaffold` → `/slice-implement` → `/slice-verify`); living governance (ADRs, CHANGELOG, runbooks); per-repo memory bank with semantic search via Ollama; worktree-safe. 18 slash commands + 10 MCP tools. |
| **architect-critic** | v0.1.3 | User-level | *Anti-sycophancy reviewer* — `/critique` runs claude-self-audit + (optionally) codex fresh-frame audit; T=4 concession scoring (1–5 rubric); auto-promotion of recurring patterns to user-global `principles.md`. File-IPC counterparty to scaffold-onboard at Phase 5/7/MASTER-SPEC-close. |

**All four are at first-stable release with green test suites** (ai-mentor 28, scaffold-onboard 163, architect-critic 249; scaffold ships its own coverage as part of v1.0.0). v0.2 refinement candidates exist for scaffold-onboard and architect-critic — none are blockers.

**Key composition story:** ai-mentor enforces *when AI vs you types* (cognitive mode), scaffold-onboard runs once to author the source-of-truth, scaffold owns continuous slice implementation, architect-critic provides on-demand or auto-fired anti-sycophancy review. Disjoint slash-command namespaces, distinct state paths.

---

## 2. What the marketplace does NOT cover (the gap)

Two design areas are real and currently unmet:

### 2.1 Overall workflow / project cadence

`scaffold` owns *within-slice* mechanics — but the broader cadence (when to start a slice, when to merge, when to ship a release, when to write retrospectives, when to revisit memory-bank for stale assumptions, when to bring others in) is not formalized. The user runs many projects; today this cadence lives in their head.

Things this layer might cover (brainstorm targets — not pre-committed):
- A "project tick" rhythm — daily/weekly checkpoints that pull from `06-progress.md`, surface stale slices, suggest ADR re-reviews, prompt CHANGELOG hygiene.
- Cross-slice planning — when 2+ slices interact, who arbitrates, what's the dependency graph render.
- Release cadence — bump-tag-publish hygiene per plugin (we just hit this with architect-critic v0.1.0→0.1.3 in 3 days; needs codification).
- Memory-bank refresh — `03-code-patterns.md`/`08-governance.md` drift relative to actual code; periodic rescan/diff.
- Switching context between projects — when juggling 3+ active repos, how does the workflow plugin help orient quickly on re-entry.

### 2.2 Discuss / collaborate with others

Today the marketplace is single-user. None of the four plugins has a multi-person surface. Things this layer might cover:
- **Code-review collaboration** — beyond `code-review:code-review` skill, how does the user share a critique session (e.g., export architect-critic's challenges as a PR comment, or hand off a slice spec for async peer review).
- **Spec sharing** — handing MASTER-SPEC.md or a slice's contract to a collaborator who needs to understand context fast.
- **Async handoff** — like the `docs/HANDOFF-*.md` pattern this very doc uses; could be plugin-formalized (`/handoff-create`, `/handoff-resume`).
- **Decision logs that others can audit** — ADRs already exist but the "why now, who agreed, what alternatives were rejected" trail is often thin.
- **Shared principles** — currently `architect-critic`'s `principles.md` is per-user. Could there be a team-principles file? Or a way to export a project's `03-code-patterns.md` as a teaching artifact for new contributors?

These two areas might end up as one plugin or two — that's a brainstorm question.

---

## 3. Open item carried over: architect-critic Q4 rubric refinement (v0.2 candidate)

While building architect-critic, a self-audit surfaced an issue that's been deferred to v0.2 and needs a dedicated brainstorm:

**Q4 rubric collapses score 4 ("material new info") and score 5 ("premise invalidated") into the same `concede` outcome.** That loses the second-order signal — score 5 means the *critic itself* was off-base, which is genuinely different from "user added new info I didn't know." Current behavior treats both identically. Worth distinguishing in v0.2:

- Score 5 → mark challenge as `critic_invalid: true` in `state.json.recent_runs[].challenges[]`
- Suppress similar-topic candidates longer than the standard 30-day decline window (e.g., 90 days)
- Feed back into auto-promotion's pattern detection as a negative signal ("the critic is overfitting on topic X")

**Why deferred:** Q4 is inherited verbatim from `docs/SPEC-scaffold-onboard.md §9` and is described there as "single threshold, not adaptive." Distinguishing 4 vs 5 makes it slightly adaptive, which means cross-plugin coordination + a Q4 amendment in scaffold-onboard's SPEC. Not a patch-release change.

**Brainstorm needed:** confirm distinct outcomes, decide on the `critic_invalid` field shape, decide on the longer-suppression policy, draft the Q4 amendment language, schedule it alongside the workflow + collaboration brainstorms.

---

## 4. Reference material the new session should read

Order matters. Read these first to ground the brainstorm:

1. **This document** — full briefing.
2. **`README.md` (root)** — 4-plugin marketplace table; install commands.
3. **`docs/SPEC-scaffold-onboard.md` §1–§5** — the 10-phase model + 3-command surface; gives shape for what "workflow plugin" could mirror or extend.
4. **`docs/SPEC-scaffold.md`** — the slice-driven implementation plugin; understand the slice cadence as the *baseline* the workflow plugin would build on.
5. **`docs/SPEC-ai-mentor.md`** — cognitive-mode plugin's shape; the multi-skill model is a precedent for the discuss/collaborate layer.
6. **`docs/SPEC-architect-critic.md`** — anti-sycophancy reviewer; especially §8.3 (file-IPC pattern) since the workflow/collaboration plugins may want similar composition primitives.
7. **`docs/HANDOFF-architect-critic-build.md`** — the workflow that built architect-critic; mirror this shape for the new plugins (brainstorm → SPEC → PLAN → implement, with subagent-driven build).
8. **Auto-memory** — `MEMORY.md` is always loaded; relevant individual files:
   - `project_skill_factory_direction.md` — marketplace direction; v1.x scope decisions.
   - `project_architect_critic_v01_settlements.md` — most recent build's lessons learned.
   - `feedback_v01_full_over_minimal.md` — user pattern: prefer richer v0.1.0 over deferred-then-iterate when design is locked.
   - `feedback_subagent_vs_inline_threshold.md` — when to pivot from subagent dispatches to inline work.
   - `feedback_plugin_version_bump_required.md` — `/plugin update` is version-keyed; bump on every change.
   - `feedback_slash_command_dollar_n_bug.md` — never use bash `$1`/`$2`/etc. inside slash command bodies; use `$ARGUMENTS` bridged via env var.
   - `feedback_two_axis_skill_eval.md` — always evaluate on (A) dev cycle + (B) product integration.
   - `feedback_custom_over_adapted.md` — prefer custom builds over community adaptations for thin orchestration.

---

## 5. Suggested first-session game plan

1. **Orient** (10 min) — read this doc + the SPECs above + auto-memory; confirm the marketplace state via `git log --oneline -5` on `main` (should show `architect-critic-v0.1.3` tag at HEAD).
2. **Brainstorm Phase 0** (1–2 hours, two passes):
   - **Pass A — workflow plugin scope.** Drive these questions with `superpowers:brainstorming`:
     - Is this one plugin or two (workflow + collaboration as separate plugins, or unified)?
     - What's the cadence (daily tick? per-slice? per-release? user-triggered only)?
     - Does it sit at user-level (across projects) or project-level (per-repo state)?
     - What command surface? (Mirror scaffold's 5-phase or define something new?)
     - How does it compose with scaffold's slice workflow? Does it WRAP `/slice-*` or sit alongside?
     - State storage — does it need its own memory-bank slice or piggyback on scaffold's?
   - **Pass B — collaboration plugin scope.** Same brainstorm shape:
     - What's the multi-person primitive? (Async handoff? Shared spec? Team principles file?)
     - Single-user-with-collaborator-mock OR true multi-user with shared state?
     - File-based IPC (like architect-critic) or something else (git-based exchange? web-based?)?
     - Composition with architect-critic — can `/critique` results become shareable artifacts?
3. **Decide structure** — separate plugins or one plugin with two skill surfaces? Naming.
4. **SPEC + PLAN authoring** for whichever plugin is highest priority — mirror `docs/SPEC-architect-critic.md` + `docs/PLAN-architect-critic.md` shape.
5. **Q4 brainstorm (parallel item)** — at some point during this session or a sibling one, do the architect-critic Q4 refinement brainstorm per §3 above. Smaller scope; could be 30 min.

---

## 6. Workflow conventions (inherited from architect-critic build)

Same as `docs/HANDOFF-architect-critic-build.md §4`:

- **Subagent-driven dev** for implementation phases (with the inline-fallback rule from `feedback_subagent_vs_inline_threshold`).
- **TDD non-negotiable**: red → green → regression → commit.
- **Commit format**: `<plugin-name>: <description> (Phase X)`. Single-line `git commit -m`. **No `Co-Authored-By:` trailer.** No HEREDOC for routine commits.
- **macOS portability adaptations**: BSD awk `sub()` chains, bash 3.2 parallel arrays, no `trap RETURN`.
- **Plugin version bump on every change** that should reach users via `/plugin update`. Slash command bodies use `$ARGUMENTS` env-var bridge (never bash `$1`/`$2`).
- **Phase-close commits** update CHANGELOG + the PLAN's Implementation Status section.
- **Never amend, never `--no-verify`, never force-push** without explicit consent.

---

## 7. Opening message for the new session

To start the fresh session, paste this single message:

> Read `docs/HANDOFF-workflow-collaboration-brainstorm.md` end-to-end. The marketplace is at 4 plugins (all first-stable release per the table in §1). I want to brainstorm two new design areas — the overall project-workflow cadence (§2.1) and the discuss/collaborate-with-others layer (§2.2) — plus the small architect-critic Q4 refinement that's been deferred to v0.2 (§3). Use `superpowers:brainstorming` per the workflow established in `docs/HANDOFF-architect-critic-build.md`. Drive each design area to settled-enough state to author SPEC + PLAN docs; we'll build them in subsequent sessions using the subagent-driven workflow.

That's all the context the new session needs. The marketplace state, the workflow conventions, the user-direction signals — all inherited via the files referenced in §4.
