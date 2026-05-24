# PLAN: ai-mentor v2.0.0 implementation

**Status:** Draft pending user review
**Implements:** `docs/SPEC-ai-mentor-v2.md`
**Branch:** `implementation-ai-mentor-v2` (off main)
**Methodology:** Subagent-driven development (`superpowers:subagent-driven-development`) + TDD-shaped where applicable (`superpowers:test-driven-development`). Verification-before-completion at every phase boundary.

---

## Overall shape

8 phases. Each phase produces a clean working tree, passes all currently-written tests, and ends with a single-line commit `ai-mentor: <description> (v2 Phase N)`. Phase-close ritual: update CHANGELOG (running v2.0.0 entry) + this PLAN's Implementation Status section before commit.

```
Phase 0 — Aggressive deletion baseline (no subagent; filesystem-only)
Phase 1 — RED: write test fixtures + evals for skills (subagent dispatched)
Phase 2 — grill-me refined skill body (subagent — biggest skill)
Phase 3 — eli10 + fool promoted skill bodies (2 parallel subagents)
Phase 4 — The Council skill body (subagent — most design-heavy)
Phase 5 — 4 slash command wrappers (no subagent; trivial)
Phase 6 — Plugin metadata + docs rewrite (no subagent)
Phase 7 — Verification + v2.0.0 tag + release housekeeping
```

Estimated duration assuming subagent dispatch works well: 2-3 working sessions.

---

## TDD nuance for skill-based plugins

Skill auto-invocation isn't testable with bash unit tests the way state.sh was. The PLAN's test discipline is:

1. **Eval fixtures** (RED-first in Phase 1) — natural-language phrases → expected skill match. Driven via subagent dispatch (we feed the subagent a message and inspect which Skill tool calls it makes).
2. **Output evals** (RED-first in Phase 1) — Council multi-persona distinguishability, Historian's codebase-grounding behavior. Driven via subagent dispatch with fixture decisions.
3. **Grill-me escape valve evals** (RED-first in Phase 1) — feed grill-me a tangled-answer / paralyzed / tactical-framing / no-timescale message and assert the right escape valve fires.

So "TDD" here means: write the eval fixture before the skill body, watch it fail, author the body until it passes, refactor.

---

## Phase 0 — Aggressive deletion baseline

**Goal:** Clean slate. Everything that doesn't survive v2.0 is gone.

**No subagent.** Direct filesystem operations; user can sanity-check the diff.

**Actions:**

1. Delete directories outright:
   - `ai-mentor/hooks/`
   - `ai-mentor/hooks-handlers/`
   - `ai-mentor/lib/`
   - `ai-mentor/skills/ai-mentor/` (the catch-all skill)
2. Delete command files:
   - `ai-mentor/commands/z1.md`
   - `ai-mentor/commands/z2-decide.md`
   - `ai-mentor/commands/z2-build.md`
   - `ai-mentor/commands/locked.md`
   - `ai-mentor/commands/quiz.md`
   - `ai-mentor/commands/improve.md`
3. Delete old test file:
   - `ai-mentor/tests/test-hooks.sh` (state + hook regression; both gone)
4. Verify no remaining references to deleted surfaces:
   - `grep -r "state.sh\|am_set_zone\|am_read_state\|am_set_quiz\|PreToolUse\|SessionStart\|z2-decide\|z2-build\|/locked\|/quiz\|/improve" ai-mentor/` returns empty.
   - `grep -r "state.sh\|am_set_zone\|am_read_state" docs/` does NOT count — historical docs can reference the cut surfaces.

**Acceptance criteria:**
- `ls ai-mentor/skills/` shows only `grill-me/` (the surviving skill from v1.3, to be refined in Phase 2)
- `ls ai-mentor/commands/` shows only `eli10.md` and `fool.md` (to be rewritten as thin wrappers in Phase 5)
- `ls ai-mentor/` shows no `hooks/`, `hooks-handlers/`, `lib/`
- The grep verification above passes (empty result)

**Commit:** `ai-mentor: v2.0 scope cut — delete dead surfaces (Phase 0)`

---

## Phase 1 — RED: test fixtures + evals

**Goal:** Write all evals/fixtures FIRST. They will all fail (the skills they test don't exist yet or are still in v1.3 form). The failing state captures the contract for Phases 2-4.

**Subagent dispatch:** Yes. Dispatch a `feature-dev:code-architect` (or general-purpose) subagent with:
- The SPEC as input
- Existing `tests/README.md` as reference
- Instruction to author the three test files below — fixtures only, NO skill body work

**Files to create:**

1. `ai-mentor/tests/test-skill-triggers.sh` — natural-language phrases → expected skill match. Driven via subagent fixture: spawn a subagent with the 4 skill descriptions in context, feed it a message, inspect which skill it invokes. ~12-16 fixtures total. Examples:
   - "grill me on this plan" → grill-me
   - "pressure-test this design" → grill-me
   - "explain in simpler terms" → eli10
   - "I don't get it" → eli10
   - "consider me a beginner" → fool
   - "no jargon" → fool
   - "council me on this idea" → council
   - "is this a good idea?" → council (council triggers on idea-validation phrases)
   - "should I do X?" → council
   - Negative test: "let's grill some chicken" → no skill (grill-me NOT activated)
   - Cross-skill collision: "consider me a beginner — explain this simpler" → both fool AND eli10 ARE acceptable; not a collision per se

2. `ai-mentor/tests/test-grill-escape-valves.sh` — feed grill-me a stuck-state message, assert the right escape valve fires. ~4-6 fixtures:
   - Tangled answer ("the cache invalidation depends on the auth state which depends on whether we're offline...") → separating-concerns reframe expected
   - Paralyzed answer ("I just can't decide — both have downsides and I need to be 100% sure") → widening-confidence-interval reframe expected
   - Tactical framing ("yeah we can rip it out later, it's reversible") → identity-question follow-up expected
   - No-timescale ("I'm optimizing for developer velocity") → time-horizon clarification expected

3. `ai-mentor/tests/test-council-personas.sh` — Council multi-persona output evals. ~6-8 fixtures:
   - Sample idea fed to council → 5 markdown-headed sections produced (Contrarian, First Principles, Outsider, Executor, Historian)
   - Each persona's section contains in-character language (Contrarian negates, Executor demands Monday-morning steps, etc.)
   - No two personas produce semantically identical takes (rough heuristic: their N-gram overlap is below a threshold OR a manual review checklist)
   - Historian section: when fed a fixture with mocked git history (a temp repo or fixture file), Historian's output references specific commits/files. When fed a greenfield fixture, Historian explicitly says "no priors found" and pivots to "why this pattern vs alternatives".
   - End-of-response prompt: "Chairman, your synthesis?" appears.

**Acceptance criteria:**
- 3 new test files exist
- Running them all FAILS predictably (skills not yet in v2.0 shape) — capture the failure as the RED state in a commit message footnote
- `tests/README.md` updated to document the 3 new test files

**Commit:** `ai-mentor: RED — write skill-trigger + escape-valve + council evals (v2 Phase 1)`

---

## Phase 2 — grill-me refined skill body

**Goal:** Make `test-skill-triggers.sh` (grill-me portions) + `test-grill-escape-valves.sh` GREEN.

**Subagent dispatch:** Yes. Dispatch a subagent with:
- SPEC §5.1 (grill-me spec)
- Current `ai-mentor/skills/grill-me/SKILL.md` as starting point
- `.claude/ghost-notes.md` principle #3 (CORE), #4 (time horizon), #5 (identity)
- `.claude/manifest-transcript.md` traps #1 (separating concerns), #3 (confidence interval)
- The two test files from Phase 1
- Anthropic skill-authoring guidance (writing-skills SKILL.md + anthropic-best-practices.md from superpowers cache)
- Instruction: refine SKILL.md until tests pass; preserve all v1.3 mechanics; add CORE-explicit posture + 4 escape valves as diagnosis+reframe pairs; verify description ≤1024 chars; drop `when_to_use` and `version` frontmatter fields.

**Files modified:**
- `ai-mentor/skills/grill-me/SKILL.md` (refined)
- Possibly `ai-mentor/skills/grill-me/escape-valves.md` (spill-out reference doc if SKILL.md grows past 500 words)

**Acceptance criteria:**
- `test-skill-triggers.sh` grill-me fixtures all pass
- `test-grill-escape-valves.sh` all fixtures pass
- SKILL.md description ≤1024 chars, contains only `name` + `description` frontmatter
- SKILL.md body ≤500 words (or reference sub-doc exists if larger)
- Manual smoke: invoke grill-me on a sample design; verify CORE posture is visible (curiosity-first questions, reassuring tone) and that a tangled-answer triggers separating-concerns

**Commit:** `ai-mentor: refine grill-me with CORE posture + 4 escape valves (v2 Phase 2)`

---

## Phase 3 — eli10 + fool promoted skill bodies

**Goal:** Make `test-skill-triggers.sh` (eli10 + fool portions) GREEN.

**Subagent dispatch:** Yes. Dispatch 2 subagents IN PARALLEL (independent skills, no shared state):

**Subagent A (eli10):**
- SPEC §5.2 (eli10 spec)
- Current `ai-mentor/commands/eli10.md` for behavior reference
- Phase 1 trigger tests
- Instruction: create `ai-mentor/skills/eli10/SKILL.md` with body ~80-120 words; description-only frontmatter ≤1024 chars; include all the natural-language triggers from SPEC §5.2.

**Subagent B (fool):**
- SPEC §5.3 (fool spec)
- Current `ai-mentor/commands/fool.md` for behavior reference
- Phase 1 trigger tests
- Instruction: create `ai-mentor/skills/fool/SKILL.md` with body ~80-120 words; description-only frontmatter ≤1024 chars; include all the natural-language triggers from SPEC §5.3.

**Files created:**
- `ai-mentor/skills/eli10/SKILL.md`
- `ai-mentor/skills/fool/SKILL.md`

**Acceptance criteria:**
- All eli10 and fool fixtures in `test-skill-triggers.sh` pass
- Both SKILL.md files have compliant frontmatter (name + description only; ≤1024 chars; no version, no when_to_use)
- Both bodies fall within target word count (~80-120 words)
- Manual smoke: "explain this simpler" auto-invokes eli10; "consider me a beginner" auto-invokes fool

**Commit:** `ai-mentor: promote eli10 + fool to skills (v2 Phase 3)`

---

## Phase 4 — The Council skill body (NEW)

**Goal:** Make `test-skill-triggers.sh` (council portions) + `test-council-personas.sh` GREEN.

**Subagent dispatch:** Yes. Single subagent (Council body is one cohesive design):

- SPEC §5.4 (Council spec)
- The web-search findings on Karpathy's LLM Council (references in SPEC Appendix A)
- Phase 1 council tests
- Instruction: create `ai-mentor/skills/council/SKILL.md` with body ~300-450 words; 5 personas (Contrarian, First Principles, Outsider, Executor, Historian); single-Claude multi-persona within one response; markdown-headed sections; Chairman-synthesis prompt at end; Historian persona explicitly runs git/grep commands in its body instructions; description-only frontmatter ≤1024 chars.

**Files created:**
- `ai-mentor/skills/council/SKILL.md`
- Possibly `ai-mentor/skills/council/personas.md` if persona definitions push body past 500 words

**Acceptance criteria:**
- All council fixtures in `test-skill-triggers.sh` pass
- All fixtures in `test-council-personas.sh` pass — 5 distinguishable personas + Chairman prompt + Historian codebase-grounding
- SKILL.md description ≤1024 chars
- SKILL.md body ≤500 words (or reference sub-doc exists)
- Manual smoke: "council me on this idea" produces 5 markdown sections; Historian section quotes git history if run inside a repo with priors, or says "no priors" cleanly on greenfield

**Commit:** `ai-mentor: add Council skill with 5 personas (v2 Phase 4)`

---

## Phase 5 — 4 slash command wrappers

**Goal:** All 4 surfaces have explicit slash command handles.

**No subagent.** Each wrapper is ~10 lines.

**Files modified/created:**
- `ai-mentor/commands/grill-me.md` (NEW) — invokes grill-me skill, passes `$ARGUMENTS` as topic
- `ai-mentor/commands/eli10.md` (rewrite from v1.3) — invokes eli10 skill, passes `$ARGUMENTS` as topic
- `ai-mentor/commands/fool.md` (rewrite from v1.3) — invokes fool skill, no args needed
- `ai-mentor/commands/council.md` (NEW) — invokes council skill, passes `$ARGUMENTS` as idea

**Wrapper template:**
```markdown
---
description: <skill description, 1-line>
---

Invoke the `ai-mentor:<skill-name>` skill with the following input from the user: $ARGUMENTS
```

(Adjust per-skill argument-hint per [feedback_slash_command_dollar_n_bug memory].)

**Acceptance criteria:**
- All 4 command files exist with `$ARGUMENTS` (not `$1`/`$2`)
- Each is ≤15 lines
- Manual smoke in a fresh Claude Code session: `/grill-me my plan`, `/eli10 quantum entanglement`, `/fool`, `/council should I rewrite my API in Rust` — each invokes its skill correctly

**Commit:** `ai-mentor: add 4 slash command wrappers (v2 Phase 5)`

---

## Phase 6 — Plugin metadata + docs rewrite

**Goal:** Plugin self-describes v2.0 correctly; docs are clean.

**No subagent.**

**Files modified:**
- `ai-mentor/.claude-plugin/plugin.json` — version → 2.0.0, description updated (see SPEC §7)
- `ai-mentor/README.md` — full rewrite for v2.0 (vision statement, 4 skills documented, no hooks/state, install/uninstall, migration note for v1.x users)
- `ai-mentor/CHANGELOG.md` — v2.0.0 entry with three sections: breaking changes (removed commands/hooks/state), new features (Council, cognitive-discipline folds in grill-me, eli10/fool promoted), removed features (zone surfaces, quiz, improve, ai-mentor catch-all skill)
- `README.md` (root) — plugin table: ai-mentor row updated to reflect v2.0 (4 skills, no hooks)
- (If a marketplace metadata file exists) — update entry to reflect v2.0

**Acceptance criteria:**
- `plugin.json` version is exactly `2.0.0`
- README has no references to removed surfaces (no /z2-decide, no PreToolUse hook, no state.json mentions in active content)
- CHANGELOG v2.0.0 entry exists and lists all breaking changes explicitly
- Root README plugin table accurate

**Commit:** `ai-mentor: v2.0 metadata + docs rewrite (v2 Phase 6)`

---

## Phase 7 — Verification + v2.0.0 release

**Goal:** Tag, push, ship.

**No subagent for the release itself; verification subagent OPTIONAL if a fresh-eyes audit is wanted.**

**Actions:**

1. **Full test suite green:**
   - `bash ai-mentor/tests/test-skill-triggers.sh`
   - `bash ai-mentor/tests/test-grill-escape-valves.sh`
   - `bash ai-mentor/tests/test-council-personas.sh`
   - All pass.
2. **Manual smoke** (per SPEC §9 DoD):
   - Fresh Claude Code session with v2.0 installed
   - "grill me on this design" → grill-me activates; one-question-at-a-time; CORE posture visible
   - "explain this simpler" → eli10 activates; no slash command needed
   - "consider me a beginner here" → fool activates; no slash command needed
   - "council me on this idea" → council activates; 5 sections appear; Chairman prompt at end
   - During a grill-me session, feed a tangled-answer message → separating-concerns escape valve fires
   - During a grill-me session, feed a paralyzed-answer message → widening-confidence-interval fires
   - Slash command path: `/grill-me`, `/eli10`, `/fool`, `/council` all work as explicit handles
3. **Frontmatter lint:**
   - For each `skills/*/SKILL.md`, verify frontmatter has ONLY `name` + `description`
   - Verify description ≤1024 chars
   - Run a quick `awk`/`yq` check or manual review
4. **Verify deletion is clean** (regression check):
   - `grep -r "state.sh\|PreToolUse\|/z2-decide\|/quiz\|/improve" ai-mentor/` returns empty
   - `ls ai-mentor/hooks ai-mentor/hooks-handlers ai-mentor/lib ai-mentor/skills/ai-mentor 2>/dev/null` returns "No such file or directory" for all four
5. **Tag and push:**
   - `git tag ai-mentor-v2.0.0`
   - `git push origin main && git push origin ai-mentor-v2.0.0`
6. **Marketplace update** (if applicable — depends on registry layout):
   - Update marketplace entry to v2.0.0
7. **Housekeeping (post-release):**
   - Mark `docs/SPEC-ai-mentor.md` (v1.3) as superseded by `docs/SPEC-ai-mentor-v2.md` (add a deprecation note at the top)
   - Mark `docs/HANDOFF-ai-mentor-v14-spec.md` as superseded by Phase A grill-me session + `docs/SPEC-ai-mentor-v2.md` (deprecation note)
   - Update project memory:
     - `project_thinking_discipline_content.md` → reflect v2.0 mapping (which transcript pieces folded into grill-me, which were dropped)
     - `project_skill_first_retrofit_queue.md` → mark ai-mentor v2.0 as shipped; remove from queue (or update from "v1.4 retrofit" to "v2.0 scope cut")

**Acceptance criteria:**
- All tests pass
- Manual smoke clean
- Frontmatter lint clean
- Tag pushed
- SPEC + HANDOFF deprecation notes added
- Memory updated

**Commit:** `ai-mentor: v2.0.0 release (v2 Phase 7)`

---

## Test budget summary

| File | Count target | Type |
|---|---|---|
| `test-skill-triggers.sh` | 12-16 | Fixture-based (subagent dispatch evals) |
| `test-grill-escape-valves.sh` | 4-6 | Fixture-based (grill-me response inspection) |
| `test-council-personas.sh` | 6-8 | Fixture-based (5-persona output evals + Historian codebase fixture) |
| **Total** | **~22-30** | |

vs. v1.3.0's 28 tests (which covered state.sh + hooks — both gone). Net: similar count, completely different ground covered.

---

## Implementation Status

(Update this section in the phase-closing commit of each phase.)

- [x] Phase 0 — Aggressive deletion baseline (branch `implementation-ai-mentor-v2`)
- [x] Phase 1 — RED test fixtures (hybrid bash + markdown approach; frontmatter lint failing as predicted on v1.3 grill-me)
- [x] Phase 2 — grill-me refined (CORE explicit; 4 escape valves in `escape-valves.md`; frontmatter lint GREEN 9/9)
- [ ] Phase 3 — eli10 + fool promoted
- [ ] Phase 4 — The Council added
- [ ] Phase 5 — 4 slash command wrappers
- [ ] Phase 6 — Metadata + docs rewrite
- [ ] Phase 7 — Verification + v2.0.0 release

---

## Risks + mitigations

| Risk | Mitigation |
|---|---|
| Skill auto-invocation isn't perfectly reliable on natural-language triggers | Phase 1 fixtures explicitly test this; if triggers miss, sharpen descriptions in iteration. Worst case, slash commands are the fallback handle for all 4 surfaces. |
| Council 5-persona output collapses into a single voice (Claude's default voice bleeds through) | Phase 4 evals explicitly check distinguishability. If collapsed, the skill body needs sharper persona prompts (specific verbal tics, hard constraints per persona). |
| Historian's codebase-grounding makes Council invocation slow (extra git/grep work) | Acceptable trade-off — Council is invoked deliberately, not in a hot path. If too slow, gate Historian's codebase work behind a "if relevant priors are likely" check. |
| Grill-me's escape valves dilute the existing 7-category interview structure | Phase 2 testing explicitly verifies the existing categories still work + the new escape valves fire ONLY when stuck-state is detected (not on every question). |
| Description ≤1024 char limit is hit before all triggers fit | Prioritize the user's stated phrases + 3-4 standard alternatives. Extra triggers can move to the skill body as documented activation cues. |
| User installs v2.0 over v1.3 and confused by missing commands | CHANGELOG + README migration note explicitly lists removed commands. Slash commands return "command not found" — Claude Code's built-in error is sufficient. |

---

## Out of scope (deferred — same as SPEC §10)

Pillars 1+2, subagent-dispatched Council, Council peer-review step, ELI level state persistence, hook re-introduction, plugin-internal manifest dependencies.
