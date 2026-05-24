# SPEC: ai-mentor v2.0.0

**Status:** Draft pending user review
**Supersedes:** `docs/SPEC-ai-mentor.md` (v1.3.0 and earlier)
**Settled via:** Phase A grill-me session (this conversation, 2026-05-22 → 2026-05-24)
**Version semantics:** Breaking change (major bump). No backwards-compat shims for removed surfaces.

---

## 1. Purpose & framing

ai-mentor is the **decision-making mentor** plugin for the user's coding workflow. Whenever the user is working on a project, ai-mentor surfaces the questions, simplifications, and adversarial perspectives that help the user (not the AI) make better decisions.

v2.0 is a **scope-cut release** driven by a single grounded signal: across ~12 months of v1.x usage, the user only ever reached for `grill-me`. Every other surface (zone enforcement, quiz protocol, prompt rewriter) was scaffolding for a 2025 learning phase that's over. v2.0 deletes the dead surfaces, sharpens grill-me with cognitive-discipline content from `.claude/` transcripts, promotes the two surfaces that still earn their keep (`/eli10`, `/fool`) to auto-invocable skills, and adds one new surface (`The Council`) for multi-angle idea validation distinct from grill-me's interrogation shape.

Vision statement (anchors future additions):

> ai-mentor helps the user make good decisions during project work. The user owns the decisions; ai-mentor provides the prompts, simplifications, interrogations, and perspectives that make decisions sharper. AI never decides for the user; AI helps the user decide.

---

## 2. Scope diff vs v1.3.0

### Surfaces that survive

| Surface | Status | Change |
|---|---|---|
| `grill-me` skill | Refined | CORE posture made explicit + 4 cognitive-discipline escape valves folded in |
| `/eli10` command | Promoted to skill | Auto-invocable via natural-language triggers; slash command kept as thin wrapper |
| `/fool` command | Promoted to skill | Auto-invocable via natural-language triggers; slash command kept as thin wrapper |
| `The Council` skill | NEW | 5-persona multi-angle idea validation (Karpathy LLM Council pattern, codebase-aware Historian variant) |

### Surfaces removed (all)

**Commands** — `/z1`, `/z2-decide`, `/z2-build`, `/locked`, `/quiz`, `/improve`
**Skills** — `ai-mentor` catch-all skill (171 lines of zone reference, now ~80% dead)
**Hooks** — `PreToolUse` hook (enforced zones), `SessionStart` hook (~620-token protocol injection per session)
**State** — `state.json`, `lib/state.sh`, `~/.claude/ai-mentor/` data directory entirely
**Library code** — `lib/` directory entirely
**Hook handlers** — `hooks-handlers/` directory entirely

### Rationale for cuts

- **Zone surfaces** (`/z1`, `/z2-decide`, `/z2-build`, `/locked`): user does not invoke. PreToolUse hook + state machinery exists only to enforce zones. Without zones, the infrastructure is dead weight.
- **`/quiz`**: user does not invoke. Quiz-level state in state.json dies with state.json.
- **`/improve`**: user does not invoke. Prompt-rewriting is an in-context inline operation; if needed, just ask Claude to rewrite without a dedicated skill.
- **`ai-mentor` catch-all skill**: 171-line reference doc for zones/quiz/override grammar. ~80% of content references deleted surfaces. The remaining 20% (Curve 1 vs Curve 2 framing, beginner's mind philosophy) is either preserved in the new skills or moves to README.
- **SessionStart hook**: injects ~620 tokens into every Claude Code session. With zones gone, most of the content is dead. Skill auto-invocation via descriptions makes ambient discoverability work without the per-session token cost. **Drop entirely.**

---

## 3. Plugin layout after cut

```
ai-mentor/
├── .claude-plugin/
│   └── plugin.json                  # version: "2.0.0"
├── README.md                        # rewritten for v2.0 (4 skills, no hooks, no state)
├── CHANGELOG.md                     # v2.0.0 entry with breaking-change manifest
├── skills/
│   ├── grill-me/
│   │   └── SKILL.md                 # refined: CORE-explicit + 4 cognitive-discipline folds
│   ├── eli10/
│   │   └── SKILL.md                 # promoted from /eli10 command
│   ├── fool/
│   │   └── SKILL.md                 # promoted from /fool command
│   └── council/
│       └── SKILL.md                 # NEW
└── commands/
    ├── grill-me.md                  # thin $ARGUMENTS wrapper
    ├── eli10.md                     # thin $ARGUMENTS wrapper
    ├── fool.md                      # thin $ARGUMENTS wrapper
    └── council.md                   # thin $ARGUMENTS wrapper (NEW)
```

**Removed directories**: `hooks/`, `hooks-handlers/`, `lib/`, `tests/test-hooks.sh` (state + hook regression suite), `skills/ai-mentor/`.

**New tests directory**: `tests/test-skill-triggers.sh` (skill auto-invocation pressure tests) + `tests/test-council-personas.sh` (Council multi-persona output evals).

---

## 4. Frontmatter convention (compliance with Anthropic spec)

All skills use exactly two frontmatter fields:

```yaml
---
name: <slug-form-skill-name>
description: <triggering conditions + when to use; ≤1024 chars total>
---
```

**Rules:**
- **No `version` field** (non-standard; informational only)
- **No `when_to_use` field** (non-standard; fold into `description`)
- **Description content rule**: triggering conditions and example phrases ONLY. Do NOT summarize the skill's workflow in the description — Anthropic guidance is explicit that doing so causes Claude to follow the description instead of reading the skill body.
- **Description char limit**: 1024 chars hard ceiling. Audit each skill against this before commit.
- **Naming**: ai-mentor uses **verb / noun forms** (e.g., `grill-me`, `eli10`, `fool`, `council`) intentionally — not the gerund pattern that superpowers and other plugins use. This is per [feedback_skill_naming_gerund_convention memory]: "ai-mentor uses verbs intentionally."

---

## 5. Skill specs

### 5.1 `grill-me` (refined)

**Frontmatter draft:**

```yaml
---
name: grill-me
description: Interview the user one question at a time, walking down each branch of a plan or design until shared understanding is reached. Stress-test assumptions, surface unmade decisions, challenge weak spots, and detect stuck-state (tangled concerns, paralysis, missing temporal frame, decision framed tactical but actually identity-shaping) — apply the right escape valve. Activate on "grill me", "grill my plan", "stress-test this", "pressure-test this", "challenge my design", "interrogate this", "poke holes", "what am I missing", "find weak spots", "play devil's advocate", "rigorous review", "what would break this", "tear this apart", "adversarial review", or when the user shares a draft plan or design and explicitly asks for adversarial / critical review. Do NOT activate for cooking-related "grill" usage, code review of an existing implementation, or simple Q&A.
---
```

(Draft is ~885 chars — within 1024 limit.)

**Body shape:**

1. **Posture: CORE protocol (explicit)** — Curiosity → Objectivity → Reassurance → Empathy. The interview tone the skill already used implicitly, now named.
2. **Core rules (preserved from v1.3.0)** — one question per turn; surface don't lecture; recommend only when asked; explore before asking.
3. **7 categories to grill on (preserved)** — requirements & users, assumptions, edge cases & failure modes, trade-offs, operability, composition, reversibility.
4. **4 escape valves (NEW — fold from cognitive-discipline content)**, each as diagnosis + reframe:
   - **separating-concerns**: When the user can't answer a question because too many concerns are tangled (their answer becomes hedged, contains "but also", references 3+ subsystems). Reframe: "Pause — you're answering 3 questions at once. Name them. Grill one at a time."
   - **widening-confidence-interval**: When the user is paralyzed seeking 100% confidence on a close call. Reframe: "You're chasing 100% confidence on a 60-40 decision. Pick X with interval [40%, 80%]. Commit. Adjust as signal arrives."
   - **asking-identity-question**: When the user frames a decision as tactical/reversible but it actually shapes what the codebase becomes. Reframe: "Even if reversible — what does picking this make this codebase in 3 years? What behaviors does it normalize?"
   - **widening-time-horizon**: When the user says "I'm optimizing for X" without naming the timescale. Reframe: "Velocity for the next 90 days, 18 months, or 5 years? Those answers conflict — pick one."
5. **Exit conditions (preserved)** — user signals stop, branches converge, all major branches resolved.
6. **Exit format (preserved)** — "Locked decisions / Open / deferred / Worth re-checking later" summary.
7. **Composition notes** — with The Council (different mechanic: 5 voices at once vs 1 question at a time), with eli10 (yield if user invokes mid-grill).

**Source provenance note in body**: cognitive-discipline content derived from `.claude/ghost-notes.md` (principles #2, #3, #4, #5) + `.claude/manifest-transcript.md` (traps #1, #3). CORE acronym is our framing — transcript teaches the sequence but doesn't acronymize.

**Target body size**: ~250-400 words. If it grows past 500 words, spill the 4 escape-valve sections into a reference sub-doc (`grill-me/escape-valves.md`) referenced via Read.

### 5.2 `eli10`

**Frontmatter draft:**

```yaml
---
name: eli10
description: Re-explain the current topic at a 10-year-old's comprehension level. Repeatable — each invocation simplifies further (ELI10 → ELI5 → ELI3). No jargon, concrete analogies, short. Activate on "eli10", "ELI10", "ELI5", "ELI3", "explain like I'm 10", "explain in simpler terms", "explain this simpler", "make it simpler", "too complex", "I don't get it", "break it down simpler", "dumb it down", "/eli10". End with "Want me to make it simpler?" so the user can re-invoke.
---
```

**Body shape:**

1. **What this skill does** — re-explanation, not first explanation. Assumes there's a current topic.
2. **Levels** — ELI10 (concrete analogies, short sentences) → ELI5 (story shape, no abstractions) → ELI3 (everyday objects only). Each re-invocation drops a level.
3. **Rules** — no jargon, concrete > abstract, short > thorough, analogies grounded in everyday life.
4. **End-of-explanation prompt** — "Want me to make it simpler?" — gives user explicit re-invocation handle.
5. **Composition** — yield to grill-me / council mid-flow if they're active; can be invoked from within those flows when a question's framing is too dense.

**Target body size**: ~80-120 words.

### 5.3 `fool`

**Frontmatter draft:**

```yaml
---
name: fool
description: Enter beginner's-mind mode for the conversation (sticky). Walk concepts from first principles, no jargon assumed, welcome obvious questions, model the same beginner's mind for the user. Activate on "fool mode", "consider me a fool", "consider me a beginner", "treat me as a beginner", "explain like I'm new to this", "no jargon", "beginner's mind", "from scratch", "I'm new to this", "ground truth", "/fool".
---
```

**Body shape:**

1. **What this skill does** — sticky mode (lasts the conversation, not just one response). Beginner-friendly framing applied to all subsequent answers.
2. **How it differs from eli10** — eli10 simplifies an already-given explanation; fool sets the baseline for upcoming explanations.
3. **Rules** — no assumed background; welcome basic questions; walk from first principles; surface vocabulary as you introduce it.
4. **Exit conditions** — explicit user signal ("ok normal mode now", "stop fool mode"), or topic shift to something where the user obviously has expertise.

**Target body size**: ~80-120 words.

### 5.4 `council` (NEW)

**Frontmatter draft:**

```yaml
---
name: council
description: Run the LLM Council pattern (Karpathy) — 5 advisor personas attack an idea from different angles, then the user (as Chairman) synthesizes a verdict. Use when the user wants multi-angle validation of an idea, decision, design choice, or strategy — distinct from grill-me which is one-voice-one-question-at-a-time interrogation. Activate on "council", "/council", "council me on this", "convene the council", "validate this idea", "stress-test from multiple angles", "different perspectives on this", "is this idea good", "is this a good idea", "should I do X", "what would the council say".
---
```

**Body shape:**

1. **What the skill does** — 5 personas respond to the user's idea in a single Claude response. Each gives a 2-3 paragraph in-character take. After all 5, prompt the user (as Chairman) for a synthesized verdict.
2. **The 5 personas** (each as a labeled markdown section):
   - **The Contrarian** — hunts fatal flaws. Assumes the idea breaks; finds where. If everything looks solid, digs deeper.
   - **The First Principles Thinker** — ignores the surface question. Asks "what are we actually solving?" Strips assumptions; rebuilds from ground up.
   - **The Outsider** — fresh eyes; catches curse-of-knowledge. Names what's obvious to the user but confusing to anyone else.
   - **The Executor** — "what do you do Monday morning?" Demands a concrete path to action; ignores theory and big-picture.
   - **The Historian** — codebase-aware. Greps git history / file tree / changelogs for prior occurrences of the proposed pattern. Quotes specific commits where the user tried this before and what happened. Degrades gracefully on greenfield ("no priors in this codebase — what makes you reach for THIS pattern vs standard alternatives?").
3. **Natural tensions** (preserved from Karpathy's original) — Contrarian vs (no Expansionist here — Historian fills the codebase-aware slot); First Principles vs Executor (rethink vs just do); Outsider center.
4. **Output format** — single Claude response with 5 markdown-headed sections (`## The Contrarian`, `## The First Principles Thinker`, etc.). After all 5: `**Chairman, your synthesis?**` prompt. User writes their verdict or asks Claude to propose one.
5. **Historian special note** — this is the only persona that actually does codebase work. Body instructs Claude: before authoring Historian's take, run `git log --all --oneline | head -50`, `git log -S '<pattern>' --oneline`, and grep for relevant filenames. Quote specific commits/files. If genuinely nothing found, say so explicitly.
6. **When NOT to use** — for "drill MY plan" (use grill-me, different shape), for simple yes/no factual questions, for code review (use code-review skill).

**Target body size**: ~300-450 words. May spill persona definitions into a reference sub-doc if it grows.

**Composition** — does not compose with grill-me in the same session (one-shot vs interactive); eli10/fool can be invoked on any persona's response that needs simplifying.

---

## 6. Slash command wrappers

Each wrapper is ≤15 lines, uses `$ARGUMENTS` env-var bridge (NOT bash `$1`/`$2` — per [feedback_slash_command_dollar_n_bug memory]). Wrappers just pass through to the skill; the skill body does the work.

```
commands/grill-me.md  # invokes grill-me skill with $ARGUMENTS as the topic to grill (optional — may be empty)
commands/eli10.md     # invokes eli10 skill with $ARGUMENTS as the topic to simplify (optional)
commands/fool.md      # invokes fool skill (no args needed)
commands/council.md   # invokes council skill with $ARGUMENTS as the idea to validate
```

All 4 surfaces also auto-invoke via their description-matched natural-language triggers — slash commands are explicit handles, not the only path in.

---

## 7. Plugin metadata

**`plugin.json` (v2.0.0):**

```json
{
  "name": "ai-mentor",
  "version": "2.0.0",
  "description": "Decision-making mentor. Four surfaces: grill-me (one-question-at-a-time plan interrogation with CORE posture + 4 cognitive-discipline escape valves), council (5-persona multi-angle idea validation, Karpathy pattern), eli10 (repeatable simplification), fool (beginner's-mind mode). No hooks, no state — pure skill-first.",
  "author": { "name": "Pras" }
}
```

**README rewrite scope** — 4 skills documented, vision statement at top, install/uninstall guidance, migration note from v1.x (uninstall + install, no data migration). Platforms section unchanged (Linux/macOS, since there's no bash code left to worry about).

**CHANGELOG v2.0.0 entry** — breaking-changes section listing removed commands + hooks + state file; new-features section for The Council + cognitive-discipline folds; removed-features section for the cuts.

---

## 8. Test strategy

Much smaller test surface than v1.3.0's 28 tests (no hooks, no state to verify). New surface:

| Test file | Coverage | Count target |
|---|---|---|
| `test-skill-triggers.sh` | Natural-language phrases auto-invoke the right skill. e.g., "explain in simpler terms" → eli10; "consider me a beginner" → fool; "council me on this" → council; "grill me on this plan" → grill-me. Verify no cross-skill collision. | ~12-16 tests |
| `test-council-personas.sh` | Council fixtures: feed a sample idea, assert each of 5 personas produces in-character output, distinguishable from the others (no two personas should give the same take). Historian fixture also verifies codebase-grounding behavior (mock git context, assert quoted commits appear). | ~6-8 tests |
| `test-grill-escape-valves.sh` | Grill-me escape valves trigger on the right diagnosis cues. Fixtures: tangled-answer message → separating-concerns reframe; paralyzed-answer → widening-confidence-interval; tactical-framing → identity-question; no-timescale → time-horizon. | ~4-6 tests |

**Total target: ~22-30 tests.** (vs. v1.3.0's 28, but covering different ground — skills, not state machinery.)

Pressure tests run via subagent fixtures where possible (more realistic than transcript injection).

---

## 9. Definition of done

- [ ] `plugin.json` version = 2.0.0
- [ ] 4 SKILL.md files exist with compliant frontmatter (name + description only; description ≤1024 chars; no `version`/`when_to_use`)
- [ ] 3 slash command wrappers exist (eli10, fool, council) using `$ARGUMENTS`
- [ ] All removed surfaces are gone from the filesystem (no commented-out vestiges)
- [ ] `hooks/`, `hooks-handlers/`, `lib/`, `skills/ai-mentor/` directories deleted
- [ ] state.json data directory removed from documentation; no references in any surviving code
- [ ] README + CHANGELOG reflect v2.0 shape
- [ ] All tests pass (target ~22-30 tests across 3 files)
- [ ] Manual smoke: fresh Claude Code session with v2.0 installed, verify:
  - "grill me on this design" → grill-me skill activates, asks one question at a time, uses CORE posture
  - "explain this simpler" → eli10 activates, no slash command needed
  - "consider me a beginner here" → fool activates, no slash command needed
  - "council me on this idea" → council activates, 5 personas respond, Chairman prompt at end
  - Tangled-answer / paralyzed-answer / tactical-framing / no-timescale messages during a grill-me session → the right escape valve fires
- [ ] Marketplace entry updated
- [ ] Root README plugin table reflects v2.0 (4 skills, no hooks)
- [ ] `ai-mentor-v2.0.0` tag pushed

---

## 10. Out of scope (deferred to future versions)

- **Pillars 1 (DRAG) + 2 (Hill)** — still deferred from v1.0; not revisited in v2.0.
- **Subagent-dispatched Council** — if multi-persona-in-one-response feels weak in practice, future v2.x could dispatch 5 actual subagents in parallel for stronger persona separation (cost-bearing).
- **Council peer-review step** — Karpathy's original includes personas reviewing each other before Chairman synthesis. v2.0 ships flat 5-takes-then-Chairman; peer-review can layer in v2.1 if value clear.
- **State persistence for ELI10 level** — v1.3.0 quiz_level field is gone; if user wants ELI10 → ELI5 → ELI3 progression tracked across messages, future v2.x could re-introduce minimal state.
- **Hook re-introduction** — if a future ai-mentor surface genuinely needs ambient enforcement, hooks can come back. v2.0 ships with none.
- **Plugin-internal composition with architect-critic / scaffold-dev / scaffold-onboard** — orthogonal. Other plugins may probe for ai-mentor surfaces via composition.json, but no manifest dependency is declared from ai-mentor's side.

---

## 11. Migration from v1.3.0

**For the user (the only known user):**

1. Uninstall v1.3.0: `claude plugin remove ai-mentor` (or whatever the current CLI verb is).
2. Install v2.0.0 from the marketplace once tagged.
3. No data migration. `~/.claude/ai-mentor/state.json` is no longer used; can be deleted manually if desired (harmless if left).
4. Slash commands `/z1`, `/z2-decide`, `/z2-build`, `/locked`, `/quiz`, `/improve` will return "command not found" — this is intentional. They are removed.
5. Skills auto-invoke on natural-language triggers; the user does not need to remember new slash commands.

**For any unknown v1.3.0 users (defensive):** CHANGELOG breaking-changes section + README v2.0 migration note serve as the public-facing explanation.

---

## Appendix A: Source provenance

- **Cognitive-discipline content folded in:**
  - From `.claude/ghost-notes.md`: principle #3 (CORE protocol → grill-me posture), principle #4 (time horizon → escape valve), principle #5 (identity question → escape valve).
  - From `.claude/manifest-transcript.md`: trap #1 (separating concerns → escape valve), trap #3 (widening confidence interval → escape valve).
- **Cognitive-discipline content dropped** (per Phase A grill-me decision, poor fit for interview shape):
  - Ghost-notes principle #2 (loss-function loop) — iteration discipline, not interview discipline.
  - Manifest-transcript trap #2 (dependency mapping) — already half-covered by grill-me's existing composition category.
- **CORE acronym** — our framing. Transcript teaches the sequence narratively without acronymizing.
- **The Council pattern** — Andrej Karpathy's "LLM Council" method. Adapted from Claude-skill ports by tenfoldmarc, charlomrt-boop, andyx5-26, YonasValentin, RyanHouchin, ciphertxt. Our variant swaps the canonical "Expansionist" for "Historian" (codebase-aware) per Phase A grill-me decision.
- **Anthropic skill-authoring guidance** — `superpowers:writing-skills` SKILL.md + `anthropic-best-practices.md` (Anthropic-canonical frontmatter rules, description length limits, body-shape guidance).
- **Phase A grill-me settlements** — this conversation, 2026-05-22 → 2026-05-24, 11 questions resolved.
