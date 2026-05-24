# Handoff: ai-mentor v1.4 SPEC authoring

> **⚠ SUPERSEDED — kept for context on the original v1.4 design intent.** The v1.4 plan in this handoff was reshaped by a Phase A grill-me session (2026-05-22 → 2026-05-24) into a **v2.0 scope-cut release** instead of a v1.4 skill-first retrofit. v2.0 ships **4 skills** (`grill-me` refined, `eli10`, `fool`, `council`) rather than the ~13-15 promoted-skill set this handoff proposed. Cognitive-discipline content folded into `grill-me` as escape valves rather than becoming standalone skills. See [`docs/SPEC-ai-mentor-v2.md`](./SPEC-ai-mentor-v2.md) and [`docs/PLAN-ai-mentor-v2.md`](./PLAN-ai-mentor-v2.md) for the actual implementation contract.

**Purpose:** seed a fresh Claude Code session to author `docs/SPEC-ai-mentor-v14.md` — the v1.4 retrofit of ai-mentor that promotes 8 commands to skills (per Pass D skill-first), folds in cognitive-discipline content from `.claude/` transcripts, refines `grill-me` posture, and cleans up frontmatter.

**Author:** carried over from scaffold-dev v0.1 SPEC brainstorm (2026-05-20 → 2026-05-22), spec review pass, and post-spec exploration synthesis (Karpathy / Graphify / ECC research + transcripts content integration).

**Context:** ai-mentor v1.3.0 ships today (2 skills: `ai-mentor` catch-all + `grill-me`; 8 commands: improve, eli10, fool, locked, quiz, z1, z2-build, z2-decide). v1.4 was originally queued as a skill-first retrofit (promote 8 commands to skills + frontmatter cleanup). The 2026-05-22 spec review pass + external content synthesis EXPANDED v1.4's scope to also add new skills derived from cognitive-discipline transcripts (loss-function loop, separation of concerns, confidence intervals, CORE protocol, identity question).

---

## 1. Goal of the next session

Author `docs/SPEC-ai-mentor-v14.md` and `docs/PLAN-ai-mentor-v14.md`. Then implement via subagent-driven dev.

The build follows the established workflow: brainstorm → SPEC → PLAN → implement.

---

## 2. What's already settled (consume these as constraints)

### 2.1 Skill-first restructuring (Pass D principle)

v1.3.0's slash-command-primary surface is wrong for skill-first. v1.4 promotes 8 commands to skills (per Pass D principle settled 2026-05-17). Slash commands stay as thin wrappers for explicit invocation.

Reference: [project_skill_first_retrofit_queue memory] for broader retrofit context.

### 2.2 Frontmatter cleanup

v1.3.0's existing 2 skills (`ai-mentor`, `grill-me`) use a non-standard `when_to_use` frontmatter field. Anthropic's official spec has exactly two required fields: `name` and `description`. v1.4 must:
- Fold `when_to_use` content into `description` (max 1024 chars total)
- Drop the non-standard `version` field too (informational only; not part of Claude Code skill spec)

This applies to both existing skills + all 8 promoted skills + all new skills.

Reference: [feedback_brainstorm_artifacts_only_when_visual memory] and the writing-skills anthropic-best-practices doc (Anthropic's canonical guidance — used for our existing skill audits).

### 2.3 New cognitive-discipline skills from transcripts

Per [project_thinking_discipline_content memory], v1.4 adds these new skills derived from the two `.claude/` transcripts (ghost-notes.md + manifest-transcript.md):

#### `minimizing-loss-function` (from ghost-notes principle #2)

5-step error-minimization loop refines z2-build's TDD discipline:
1. Define the metric (what does "better" mean for this work?)
2. Predict the outcome (guess how well you'll do)
3. Deliver slowly (go slow enough to notice mistakes)
4. Find the exact failure point (loss signal)
5. Adjust ONE variable + repeat

Skill triggers in z2-build mode primarily. Composes with `superpowers:test-driven-development` (which scaffold-dev already uses). Trigger phrases: "minimize loss function", "iterate on errors", "improve via mistakes", "TDD with metrics".

#### `separating-concerns` (from manifest-transcript trap #1)

When user signals stuck-state, the answer isn't thinking harder — it's separating concerns. Working memory is finite. Walk user through dependency mapping + tackling one concern at a time.

Skill triggers in z2-decide mode primarily. Trigger phrases: "I'm stuck", "this is too much", "I can't think through this", "separate concerns", "untangle this".

#### `widening-confidence-interval` (from manifest-transcript trap #3)

When user is paralyzed seeking 100% confidence, the move is to widen the interval not narrow the precision. Output a confident-enough statement.

Skill triggers in z2-decide mode primarily. Trigger phrases: "I'm not confident", "stuck on a decision", "paralyzed", "what should I do".

#### `applying-CORE-protocol` (from ghost-notes principle #3)

CORE = Curiosity → Objectivity → Reassurance → Empathy. For handling hard conversations. Could be standalone skill OR fold into existing `grill-me` (which is itself a hard-conversation skill).

Brainstorm Q3 decides: standalone skill, fold into grill-me, or both.

#### `asking-identity-question` (from ghost-notes principle #5)

"What will this MAKE me?" vs "What will this GET me?" Philosophy / meta. Most personal of the principles. Could be standalone skill OR fold into existing `ai-mentor` catch-all skill body.

Brainstorm Q4 decides: standalone or fold.

#### `mapping-dependencies` (from manifest-transcript trap #2)

Theory of Constraints + dependency mapping for non-slice planning contexts (scaffold-dev already does this for slices; this is the standalone version for arbitrary decisions).

Skill triggers when user is decomposing a complex decision OR a non-slice planning task. Trigger phrases: "map dependencies", "what's the biggest blocker", "constraint analysis", "decompose this decision".

### 2.4 Grill-me refinement with CORE protocol

Existing `grill-me` skill (v1.3.0) is good but doesn't name its underlying tone. v1.4 refines it to explicitly use CORE protocol framing (Curiosity → Objectivity → Reassurance → Empathy). The questions asked stay the same; the FRAMING gets CORE-aware.

This is a small refinement, not a rewrite. grill-me already follows CORE intuitively; v1.4 makes it explicit.

### 2.5 Skill count target

v1.3.0: 2 skills.
v1.4 target: **~13-15 skills**.

Composition:
- 2 existing (refined): `ai-mentor`, `grill-me`
- 8 promoted from commands: `improve`, `eli10`, `fool`, `locked`, `quiz`, `z1`, `z2-build`, `z2-decide` (skill versions become e.g. `improving-prompt`, `explaining-like-im-10`, `entering-fool-mode`, `locking-decisions`, `quizzing-socratically`, `delegating-to-z1`, `engaging-z2-build`, `engaging-z2-decide`)
- 3-5 new from transcripts: `minimizing-loss-function`, `separating-concerns`, `widening-confidence-interval`, (maybe `applying-CORE-protocol`, `asking-identity-question`, `mapping-dependencies`)

Final count depends on Q3/Q4 decisions (standalone vs fold).

### 2.6 Composition stays orthogonal

ai-mentor remains orthogonal to other plugins (no manifest dependency; loose coupling). Other plugins (scaffold-dev, scaffold-onboard, architect-critic) probe for ai-mentor via composition.json and invoke its skills in-conversation. No protocol changes; just more skills available.

### 2.7 Existing functionality preserved

All v1.3.0 capabilities preserved:
- Spotter mode (z2-decide / z2-build with PreToolUse hook blocking)
- Quiz protocol (L1-L4 Socratic grilling at depth)
- Fool / beginner's mind
- Eli10 (re-invocable simplification)
- Improve (prompt rewriter)
- Curve 1 vs Curve 2 framing
- State management via state.json
- Subagent scope caveat (hooks fire on main session only)

These move to skill bodies but behavior identical.

---

## 3. What's open — questions to brainstorm

### Q1 — Skill naming convention for promoted commands

The 8 commands need skill names. Anthropic guidance: gerund form (verb + -ing) preferred. Examples:

| Command | Candidate skill name |
|---|---|
| `/improve` | `improving-prompt` or `rewriting-prompt-as-coding-agent-prompt` |
| `/eli10` | `explaining-like-im-10` or `simplifying-explanation` |
| `/fool` | `entering-fool-mode` or `embracing-beginners-mind` |
| `/locked` | `locking-decisions` or `flipping-out-of-decide-mode` |
| `/quiz` | `quizzing-socratically` or `running-socratic-quiz` |
| `/z1` | `delegating-to-z1` or `exiting-spotter-mode` |
| `/z2-build` | `engaging-z2-build-mode` or `entering-build-spotter` |
| `/z2-decide` | `engaging-z2-decide-mode` or `entering-decide-spotter` |

Brainstorm: pick names that work as trigger phrases + read naturally.

### Q2 — Skill content authoring (each skill ≤500 lines per Pass D guidance)

For each of the 8 promoted + 3-6 new skills, the body needs to be authored. ~13-15 skill bodies × ≤500 lines = 6500-7500 lines of new content. Brainstorm: what's the right skill-body shape (refer to ai-mentor catch-all skill + grill-me skill as references)?

### Q3 — CORE protocol: standalone skill or fold into grill-me?

Options:
- A. Refine grill-me to name CORE explicitly; no new skill. Simpler.
- B. New `applying-CORE-protocol` skill for explicit invocation outside grill-me contexts (e.g., user prepping for a hard conversation that isn't a plan/design grill).
- C. Both — grill-me references CORE; standalone skill exists for non-grill contexts.

### Q4 — Identity question: standalone skill or fold into ai-mentor catch-all?

Options:
- A. Fold into existing `ai-mentor` catch-all skill body (philosophy section).
- B. New `asking-identity-question` skill that triggers on decision moments.
- C. Both.

### Q5 — Build sequence

Standard Pass D 8-phase pattern + extra phase for skill-promotion file restructure. Brainstorm:
- Phase 0: Evals for new skill behaviors (3+ scenarios per new skill; pressure-tests for refined grill-me)
- Phase 1: Author SKILL.md bodies (2 refined + 8 promoted + 3-6 new = ~13-16 files)
- Phase 2: Reference sub-docs
- Phase 3: Utility scripts (slimmed lib/; preserve state.sh + hook handlers)
- Phase 4: Hook updates (preserve existing; possibly add coordination with scaffold-onboard/scaffold-dev if those plugins surfaced needs)
- Phase 5: Slash command wrappers (the 8 existing commands become wrappers over the promoted skills; preserve same invocation UX)
- Phase 6: Subagent pressure tests
- Phase 7: Integration tests (with scaffold-dev's grill-me-offer flow; with architect-critic's CORE-aware rebuttal cycle if v0.2 is built first)
- Phase 8: Publish v1.4.0

### Q6 — Backwards compat with v1.3.0 users

v1.3.0 users have state.json + may have invocation patterns built on existing commands. v1.4 must:
- Read v1.3.0's state.json (likely unchanged; verify)
- Preserve all 8 command invocations + their existing behavior (slash command UX identical)
- Document the new skill availability (so existing users know what's new)
- Migration: probably no migration needed (slash commands stay; behaviors preserved)

### Q7 — Testing strategy

ai-mentor's current test suite is small. v1.4 adds significantly more surface (~13-15 skills). Test strategy:
- Per-skill pressure tests (subagent scenarios)
- Per-command regression tests (slash command UX identical to v1.3.0)
- Hook behavior tests (PreToolUse blocking unchanged)
- Cross-skill composition tests (e.g., grill-me + applying-CORE-protocol if both exist)

Target: ~80-120 tests total.

---

## 4. Reference material the new session should read

Order matters.

1. **This document** — full briefing
2. **`docs/SPEC-ai-mentor.md`** — v1.3.0 (or earlier) SPEC; current behavior reference
3. **`ai-mentor/skills/ai-mentor/SKILL.md`** — current catch-all skill body; the v1.4 refined version mostly preserves this
4. **`ai-mentor/skills/grill-me/SKILL.md`** — current grill-me skill; v1.4 refines posture with CORE
5. **`ai-mentor/commands/*.md`** — current 8 command bodies (these get promoted to skills)
6. **`.claude/ghost-notes.md`** — transcript with 5 cognitive-discipline principles
7. **`.claude/manifest-transcript.md`** — transcript with 3 traps
8. **`/Users/draco/.claude/plugins/cache/claude-plugins-official/superpowers/5.1.0/skills/writing-skills/SKILL.md`** + `anthropic-best-practices.md` — canonical skill-authoring guidance
9. **Auto-memory** (always loaded; relevant individual files):
    - `project_thinking_discipline_content.md` — authoritative content map for transcripts → plugins
    - `project_skill_first_retrofit_queue.md` — broader retrofit context
    - `project_post_spec_exploration_queue.md` — Karpathy + ECC + Graphify research findings
    - `feedback_v01_full_over_minimal.md` — apply to v1.4 (ship full, don't defer)
    - `feedback_slash_command_dollar_n_bug.md` — slash wrapper bodies use `$ARGUMENTS`

---

## 5. Workflow conventions

- **Subagent-driven dev** per `superpowers:subagent-driven-development`
- **TDD non-negotiable**
- **Commit format**: `ai-mentor: <description> (v1.4 Phase X)`. Single-line. No co-author trailer.
- **macOS portability adaptations** per scaffold-onboard playbook
- **Slash command bodies use `$ARGUMENTS`**
- **Phase-close commits update CHANGELOG + PLAN's Implementation Status**

---

## 6. First-session game plan

### Step 1 — Orient (10-15 min)

Read this document end-to-end. Spot-read SPEC-ai-mentor.md + the two transcripts in `.claude/`. Verify baseline still green: `bash ai-mentor/tests/test-*.sh` (run all current ai-mentor tests; expect existing test count to pass).

### Step 2 — Brainstorm (1-2 hours)

Invoke `superpowers:brainstorming`. Drive Q1-Q7. Prose-only by default per [feedback_brainstorm_artifacts_only_when_visual memory].

### Step 3 — Author SPEC (1-2 hours)

Create `docs/SPEC-ai-mentor-v14.md`. Capture all skill names + bodies' outlines + frontmatter conventions + composition notes.

### Step 4 — Author PLAN (1-2 hours)

Create `docs/PLAN-ai-mentor-v14.md` with full TDD breakdown.

### Step 5 — Begin implementation (multi-session)

`git checkout -b implementation-ai-mentor-v14`. Subagent-driven workflow.

---

## 7. Definition of done (ai-mentor v1.4.0)

- All build phases complete
- ~13-15 skills shipped (2 refined + 8 promoted + 3-5 new)
- Frontmatter cleaned (no `when_to_use`, no `version`)
- v1.3.0's 8 commands preserved as thin wrappers (UX identical)
- New cognitive-discipline skills functional (loss function, separation of concerns, confidence intervals, CORE, identity, dependency mapping)
- grill-me refined with CORE protocol naming
- ~80-120 tests passing
- `ai-mentor-v1.4.0` tag pushed
- Marketplace entry updated
- Root README plugin table reflects v1.4
- v1.3.0 → v1.4 migration: zero-change for existing users; new skills + new triggers available
- scaffold-dev v0.1 + scaffold-onboard v0.2 + architect-critic v0.2 grill-me/CORE composition works against this v1.4 (verified via fixtures)

---

## 8. Opening message for the new session

To start the fresh session, paste this:

> Read `docs/HANDOFF-ai-mentor-v14-spec.md` end-to-end. ai-mentor v1.3.0 ships today with 2 skills + 8 commands. v1.4 promotes 8 commands to skills (per Pass D skill-first), adds new cognitive-discipline skills from `.claude/` transcripts (loss function loop, separation of concerns, confidence intervals, CORE protocol, identity question, dependency mapping), refines grill-me posture with CORE, and cleans up non-standard frontmatter. Target: ~13-15 skills. Use `superpowers:brainstorming` to drive Q1-Q7 in §3 to settled state, then author `docs/SPEC-ai-mentor-v14.md` and `docs/PLAN-ai-mentor-v14.md`, then begin implementation on a fresh `implementation-ai-mentor-v14` branch.
