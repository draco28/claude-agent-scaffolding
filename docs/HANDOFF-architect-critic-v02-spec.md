# Handoff: architect-critic v0.2 SPEC authoring

**Purpose:** seed a fresh Claude Code session to author `docs/SPEC-architect-critic-v02.md` — the v0.2 retrofit of architect-critic that fixes GitHub issue #1 bugs, redesigns to skill-first per Pass D, and exposes the skill-based invocation surface that scaffold-dev v0.1 + scaffold-onboard v0.2 need.

**Author:** carried over from the session that completed scaffold-dev v0.1 SPEC brainstorm (2026-05-20 → 2026-05-22), including a spec review pass.

**Context:** architect-critic v0.1.3 ships today (~154 assertions across 10 test files, file-IPC inbox/outbox protocol, bash-orchestrated audit flow embedded in `commands/critique.md`). GitHub issue #1 documents 8 critical/high/medium/low defects discovered in first standalone use. v0.2 is a substantial retrofit driven by three forces:
1. The 8 documented bugs from issue #1 (most critical: silent-no-op audit; $N substitution corruption; non-TTY rebuttal skip; hardcoded MASTER-SPEC path)
2. Skill-first principle (per Pass D) — current v0.1.3 is CLI-tool-shaped with bash trying to orchestrate Claude (architecturally wrong)
3. Consumer plugins (scaffold-onboard v0.2 + scaffold-dev v0.1) require skill-based in-conversation invocation, NOT inbox/outbox file IPC

---

## 1. Goal of the next session

Author `docs/SPEC-architect-critic-v02.md` and `docs/PLAN-architect-critic-v02.md`. Then implement via subagent-driven dev.

The build follows the established workflow: brainstorm → SPEC → PLAN → implement.

---

## 2. What's already settled (consume these as constraints)

### 2.1 Skill-first restructuring (Pass D)

**The CORE FIX in v0.2.** v0.1.3's architecture is wrong: bash scripts that try to orchestrate Claude (e.g., "claude self-audit instructions" written as bash comments expecting Claude to fill in JSON) can't work — Claude can't intervene mid-`bash -c` execution. This is the root cause of issue #1's #1, #2, #4.

v0.2 redesigns to skill-first per Pass D principle (settled 2026-05-17 mid-brainstorm):

- **P1** — Every plugin capability ships as a skill (description-matched auto-invocation)
- **P2** — Logic in markdown bodies that Claude reads + acts on; bash reserved for bookkeeping (state.json updates, outbox writes, lock files, jq transforms)
- **P3** — Three-layer: hooks (ambient) + skills (auto-invocable capabilities) + slash commands (explicit handles for parameters)

Reference: [project_skill_first_retrofit_queue memory] for the broader retrofit context.

### 2.2 4 target skills (vs current 0 skills, 4 commands)

v0.1.3 ships 0 skills + 4 commands. v0.2 target:

| Skill | Replaces command | Trigger phrases | Body responsibility |
|---|---|---|---|
| `critiquing-spec` | `/critique` | "audit this spec", "critique X", "adversarial review of Y", "challenge the spec" | Audit a spec / plan / diff with claude-self-audit (in-conversation) + (optionally) Codex fresh-frame audit (via Bash subprocess); consolidate challenges; present interactively with T=4 concession-scoring; rebuttal cycle in conversation; auto-promotion candidate detection |
| `reviewing-critique-history` | `/critique-list` | "show recent critiques", "critique history", "list pending audits" | Render state.json's recent_runs + pending in-flight requests; show elapsed time, adversaries used, challenge counts, cost |
| `listing-principles` | `/principles-list` | "show principles", "list principles", "what principles apply here" | Render merged principles from user-global + project context + memory-bank patterns + governance |
| `promoting-principle` | `/promote-principle` | "promote this principle", "record this as a principle", "add to principles.md" | Manually promote a principle to user-global or project-scoped principles file |

Slash commands stay as thin wrappers for explicit invocation with arguments.

### 2.3 Bug fixes from GitHub issue #1 (all CRITICAL/HIGH must be fixed)

Reference: `gh issue view 1` (issue at github.com/draco28/claude-agent-scaffolding/issues/1).

#### Critical bugs:

**#1 — Slash-command $N substitution corrupts bash function locals.**
- v0.1.2's fix was incomplete; v0.1.3 still broken
- Claude Code substitutes `$N` at template-render time including inside `bash -c '...'` bodies AND inside bash function definitions
- v0.2 fix: skill-first design eliminates the bash function pattern entirely. Logic lives in markdown body; Claude does the audit; no `$N` in function bodies.
- Slash command wrapper bodies use `$ARGUMENTS` env-var bridge per `feedback_slash_command_dollar_n_bug` memory

**#2 — `claude-self-audit` cannot actually execute in-session — silent no-op in normal mode.**
- Root cause: bash script contains "instructions to Claude" expecting Claude to inject audit JSON mid-bash; Claude can't intervene mid-`bash -c`
- v0.2 fix: skill body says "do claude-self-audit"; Claude does the audit IN CONVERSATION as part of executing the skill; no bash orchestration needed. Bash only for bookkeeping (write challenges to outbox AFTER audit done in conversation).

**#3 — `/critique` fails hard for projects without `MASTER-SPEC.md`; no working escape hatch.**
- Default spec path hardcoded to `$(pwd)/MASTER-SPEC.md`; `--spec PATH` flag broken due to bug #1
- v0.2 fix: skill body has discovery logic. Order: (a) `--spec PATH` from slash command arg (works now since no $N substitution issue); (b) read manifest's `well_known_paths.master_spec` if available; (c) heuristic discovery restricted to `SPEC*`/`MASTER-SPEC*` filename patterns (NOT arbitrary `.md` — that was the original bug class); (d) prompt user via AskUserQuestion with candidate files.

#### High bugs:

**#4 — Rebuttal cycle skipped in every Claude Code session (non-TTY).**
- Bash `read -r` requires TTY; Claude Code's Bash tool is non-TTY
- v0.2 fix: rebuttal cycle moves into Claude's native turn handling. Skill body presents challenges with concession-scoring rubric; user responds in conversation; Claude scores responses against T=4 threshold; no bash interactive flow needed.

#### Medium bugs:

**#5 — Codex availability not surfaced in user-facing output.**
- v0.2 fix: skill body explicitly checks Codex availability (via `command -v codex`); surfaces status in user output before audit; e.g., "Codex available; will run fresh-frame audit at close depth" or "Codex not detected; running claude-only audit. Install codex CLI for adversarial fresh-frame."

**#6 — Codex cost defaults to zero — `cost_usd` reporting meaningless.**
- v0.1.3 doesn't actually measure Codex tokens (defaults `CODEX_TOKENS_IN=0`/`OUT=0`)
- v0.2 fix candidates: (a) parse Codex stderr/stdout for actual token counts; (b) estimate via prompt-length heuristic (`chars / 4`); (c) remove cost-tracking surface if measurement infeasible. Brainstorm to decide.

#### Low bugs:

**#7 — README missing standalone-use guidance.**
**#8 — `project_class` falls back to `"unknown"` without explaining consequence.**

Both addressable as v0.2 README + skill body improvements.

### 2.4 Drop inbox/outbox file-IPC; replace with skill-based in-conversation invocation

v0.1.3 + scaffold-onboard v0.1.0's integration uses inbox/outbox file IPC:
- scaffold-onboard writes request envelope JSON to `<critic_dir>/inbox/<request_id>.json`
- architect-critic reads inbox, processes, writes response JSON to `<critic_dir>/outbox/<request_id>.json`
- scaffold-onboard polls outbox

**This whole protocol is wrong for skill-first.** Skills compose by in-conversation invocation, not file IPC. v0.2 drops the inbox/outbox protocol entirely:

- architect-critic's `critiquing-spec` skill is invocable in-conversation by any consumer (scaffold-onboard, scaffold-dev, or user directly)
- Consumer plugins probe architect-critic's presence via `composition.json` (lazy detection)
- When consumer needs adversarial audit, it invokes critic's `critiquing-spec` skill in-conversation (Claude triggers the skill the same way it triggers any skill)
- Critic's skill runs IN THE SAME conversation as the consumer (no separate process; no file passing); produces challenges; user resolves; control returns to consumer

This dramatically simplifies architect-critic's plugin layout:
- Drop `inbox/` and `outbox/` directories
- Drop `lib/compose.sh`'s request/response envelope code (or simplify radically)
- Drop the polling timeout machinery
- Keep state.json bookkeeping (recent_runs, principles tracking)

### 2.5 Codex invocation pattern in skill-first model

Codex CLI invocation remains relevant in v0.2 (for fresh-frame adversarial audit at "close" depth). But it's now a bash subprocess invocation INSIDE the skill body, not bash orchestrating Claude:

```
critiquing-spec skill body (Claude reads + acts on):

  1. Read artifact to audit
  2. Read principles (user-global + project)
  3. Do claude-self-audit IN-CONVERSATION:
     - identify challenges, gaps, divergences
     - Claude's native judgment work
  4. IF audit depth = "close" AND Codex CLI installed:
     a. Compose Codex prompt (fresh-frame: artifact + principles + adversarial framing)
     b. Invoke Codex via Bash tool:
        codex audit --input /path/artifact --principles /path/principles.md --output /tmp/codex-audit-<id>.json
     c. Wait for subprocess (timeout: 5min default; configurable)
     d. Parse Codex output (JSON or prose)
     e. Extract Codex's challenges
  5. Consolidate Claude-self + Codex challenges (dedup by similarity)
  6. Present to user with T=4 concession-scoring rubric
  7. Interactive rebuttal cycle (in conversation)
  8. Bash bookkeeping: append to state.json; detect auto-promotion candidates
```

Key: bash invokes Codex SUBPROCESS (subprocess subprocess; no deadlock); Claude orchestrates the flow via skill body. The bug fix in #2 is precisely this — claude-self-audit happens in conversation; Codex is just another subprocess.

### 2.6 Auto-promotion (the deferred design from v0.1)

v0.1.3 ships auto-promotion design intent but implementation deferred. v0.2 should ship the full auto-promotion implementation:

- After each `/critique` run, check if recurring patterns across `state.json.recent_runs` warrant promotion to user-global `principles.md`
- 30-day suppression window for rejected promotion candidates (already documented in v0.1 SPEC)
- Score 5 vs score 4 distinction (per the Q4 refinement deferred from v0.1.3): score 5 (critic invalid) extends suppression to 90 days vs standard 30

Reference: scaffold-onboard SPEC §9 Q4 + the deferred Q4 refinement from architect-critic v0.1 brainstorm (per `docs/HANDOFF-workflow-collaboration-brainstorm.md` §3).

---

## 2.7 External patterns to integrate (from spec review + research synthesis, 2026-05-22)

### Ghost notes principle for `critiquing-spec` skill body (from `.claude/ghost-notes.md` transcript)

The "Hidden Rules of Success" transcript principle #1 (Abraham Wald survivor-bias example, WWII fighter planes) describes **"listening to ghost notes"** — looking for what's NOT being said; Bayesian filtering on absent data.

This IS literally the adversarial spec review pattern. Wald's insight (armor the engines/cockpit where there are NO bullet holes, because planes hit THERE didn't return) translates directly to critic posture: **find the assumptions the spec doesn't surface, the dependencies it doesn't acknowledge, the failure modes it doesn't enumerate**.

**Implementation in v0.2:** embed in `critiquing-spec` skill body explicitly. Name the pattern ("the ghost notes pattern"); include the survivor-bias example as illustrative; frame the audit posture as "look for what should logically be in this spec but isn't." Mention as a touchstone the critic returns to during the rebuttal cycle.

Reference: `.claude/ghost-notes.md` lines 1-32 + [project_thinking_discipline_content memory].

### CORE protocol for rebuttal-cycle tone (from same transcript)

Principle #3 of the transcript: **CORE protocol** for hard conversations — Curiosity → Objectivity → Reassurance → Empathy. Adversarial review's rebuttal cycle IS a hard conversation (challenger and user push back on each other). Tone matters; combative critics get dismissed.

**The CORE protocol applied to critic rebuttal:**
- **Curiosity** — phrase challenges as *"I might be missing something, but is there a reason the spec doesn't address X?"* rather than *"you missed X"*. Lower defensiveness.
- **Objectivity** — shift to facts/processes/specs not people/stories/intentions. *"Where should we adjust the spec?"* not *"why did you skip this?"*.
- **Reassurance** — signal mutual purpose. *"I'm raising this because I want the spec to be robust before implementation."* not *"this is wrong."*
- **Empathy** — acknowledge user's work + intent. *"I see you've thought through X carefully; here's a related angle that might also need consideration."*

**Implementation in v0.2:** embed CORE explicitly in `critiquing-spec` skill body's rebuttal-cycle subsection. Each challenge presented to user should be framed in CORE tone. The T=4 concession-scoring stays the same; tone changes.

Reference: `.claude/ghost-notes.md` lines 70-89 + [project_thinking_discipline_content memory].

### ECC instincts pattern-extraction concept for auto-promotion (from research)

Everything Claude Code (`affaan-m/everything-claude-code`) has an "instincts" pattern: session-pattern frequency as a signal source for auto-promotion to skills (different mechanism from architect-critic's user-vote-based promotion).

**For v0.2 auto-promotion design:** consider pattern frequency as a supplementary signal alongside vote-recurrence (which remains primary per Q4 settlement T=4 threshold). Study ECC's `hooks/memory-persistence` + `skills/continuous-learning-v2` + `commands/instinct-*` for design ideas. Don't copy wholesale; the user-vote signal is more rigorous and stays primary.

**Specifically:** v0.2 could promote a principle automatically when EITHER (a) user has voted ≥T threshold on similar challenges across N runs (vote-recurrence — current design), OR (b) similar patterns appear across N consecutive critique sessions even without explicit votes (instinct-style — new supplementary signal). Settled in brainstorm.

Reference: [project_post_spec_exploration_queue memory] for ECC details.

---

## 3. What's open — questions to brainstorm

### Q1 — Multi-step skill body design (how does `critiquing-spec` handle the interactive rebuttal cycle?)

The rebuttal cycle is interactive (per T=4 settlement). In v0.1.3 it used bash `read -r` (broken). In v0.2 it's native Claude conversation. Question: how does the skill body structure the rebuttal loop? Options:

- **Linear:** present all challenges at once; user responds with `accept/rebut/dismiss` per challenge in one message; skill scores all responses
- **Sequential:** present one challenge at a time; wait for user response; score; advance
- **User-paced:** present challenges as a list; user replies in chat with their thinking; skill picks up rebuttals as they come

Tradeoffs: sequential is more rigorous (each challenge gets focused attention); linear is faster; user-paced is most natural conversation.

### Q2 — Codex output parsing (JSON or prose?)

Codex CLI's output format isn't standardized across versions. v0.2 needs:
- Detect Codex version
- Prefer JSON output mode if available (codex --json or similar)
- Fall back to prose parsing if JSON mode not available

Brainstorm: write a small parser that handles both. Or constrain to JSON-only (refuse if Codex doesn't support JSON output).

### Q3 — `cost_usd` measurement (bug #6)

Three candidates:
- (a) Parse codex stderr/stdout for token counts where available (Codex CLI variants vary)
- (b) Estimate via prompt-length heuristic (`prompt_chars / 4 ≈ input tokens`)
- (c) Remove cost-tracking surface; don't pretend to track what we can't measure

Decide.

### Q4 — Composition.json schema for cross-plugin detection

scaffold-onboard v0.2 + scaffold-dev v0.1 probe `composition.json` to detect architect-critic. What's the schema? Where does it live?

Probably: `${CLAUDE_PLUGIN_DATA}/composition.json` (each plugin updates a shared file on install/uninstall). Schema:

```json
{
  "schema_version": "1.0",
  "installed_plugins": {
    "architect-critic": {
      "version": "0.2.0",
      "skills": ["critiquing-spec", "reviewing-critique-history", "listing-principles", "promoting-principle"],
      "commands": ["/critique", "/critique-list", "/principles-list", "/promote-principle"]
    },
    "ai-mentor": {
      "version": "1.3.0",
      "skills": ["grill-me", "ai-mentor"],
      "commands": ["/z2-decide", "/z2-build", "/locked", "/quiz", "/eli10", "/fool"]
    },
    ...
  },
  "last_updated_at": "2026-05-22T..."
}
```

Architect-critic v0.2's install/uninstall hooks update this file. Other plugins read it to probe for available skills.

### Q5 — Backwards compatibility with existing v0.1.3 users

v0.1.3 users have state.json files, principles.md files. v0.2 must:
- Read v0.1.3's state.json (schema may need migration)
- Read v0.1.3's principles.md (likely unchanged)
- Drop inbox/outbox: any pending requests in v0.1.3's inbox at upgrade time should be surfaced to user with a "manually re-invoke /critique" message
- Document migration: `architect-critic-v0.2` is a major-version-style break (skill-first redesign); recommend users finish in-flight critique flows before upgrading

### Q6 — Hook strategy

v0.1.3 has hooks? (Verify by reading current SPEC.) v0.2 likely needs:
- SessionStart hook (per scaffold-onboard pattern): surface "architect-critic installed; principles loaded from <path>"; ~50 tokens; fail-open

Other hooks (PreToolUse, etc.) probably not needed in skill-first design.

### Q7 — Build sequence for v0.2 retrofit

v0.1.3 has ~154 assertions across 10 test files. v0.2 must:
- Author 4 new SKILL.md bodies
- Drop inbox/outbox code (significant deletion)
- Fix the 8 bugs from issue #1
- Add auto-promotion implementation (was design-intent in v0.1)
- Maintain backwards compatibility with v0.1.3's principles.md + state.json

Build sequence (likely):
1. Phase 0 — Evals for new skill behaviors + bug repro scenarios
2. Phase 1 — Author 4 SKILL.md bodies (critiquing-spec, reviewing-critique-history, listing-principles, promoting-principle)
3. Phase 2 — Reference sub-docs (rebuttal cycle examples; principles examples)
4. Phase 3 — Utility scripts (slimmed lib/: keep state.sh + principles.sh + scorer.sh + promotion.sh; drop inbox.sh + outbox.sh; decide cost.sh per Q3; add auto-promotion logic)
5. Phase 4 — Hooks (SessionStart)
6. Phase 5 — Slash command wrappers (thin shells over skills; $ARGUMENTS bridge)
7. Phase 6 — Subagent pressure tests
8. Phase 7 — Integration tests (with scaffold-onboard v0.2 in-conversation invocation; with scaffold-dev v0.1 — both via fixtures)
9. Phase 8 — Drop inbox/outbox protocol; verify no consumer plugins depend on it
10. Phase 9 — Publish v0.2.0

---

## 4. Reference material the new session should read

Order matters.

1. **This document** — full briefing
2. **GitHub issue #1** — full bug inventory: `gh issue view 1`
3. **`docs/SPEC-architect-critic.md`** — current v0.1 spec (the shipping plugin)
4. **`docs/SPEC-scaffold-onboard.md`** §8.3 — current inbox/outbox integration (to be REMOVED)
5. **`docs/SPEC-scaffold-dev.md`** §16.3 — what scaffold-dev expects from architect-critic v0.2 (in-conversation skill invocation)
6. **`docs/SPEC-workspace-init.md`** §6 — manifest contract (architect-critic v0.2 reads `well_known_paths.principles_user_global` + `well_known_paths.master_spec` as optional fast-paths)
7. **`architect-critic/commands/critique.md`** (lines ~230-266: "CLAUDE SELF-AUDIT INSTRUCTIONS" comment block) — current bash-orchestrates-Claude pattern lives here, NOT in a `lib/compose.sh` (no such file exists). Much of this 465-line command body gets dissolved into the `critiquing-spec` skill.
8. **`architect-critic/commands/critique.md`** — current /critique slash command (has the $N substitution bug; becomes thin wrapper over critiquing-spec skill)
9. **`architect-critic/tests/test-compose.sh`** — current tests (some will be removed as inbox/outbox drops)
10. **Auto-memory** (always loaded; relevant individual files):
    - `project_architect_critic_v01_settlements.md` — context from v0.1 brainstorm
    - `project_skill_first_retrofit_queue.md` — broader retrofit context
    - `feedback_slash_command_dollar_n_bug.md` — directly relevant to bug #1 fix
    - `feedback_v01_full_over_minimal.md` — apply to v0.2 (ship full, don't defer)
    - `feedback_subagent_vs_inline_threshold.md` — relevant for build pattern

---

## 5. Workflow conventions

- **Subagent-driven dev** per `superpowers:subagent-driven-development`
- **TDD non-negotiable**
- **Commit format**: `architect-critic: <description> (v0.2 Phase X)`. Single-line. No co-author trailer.
- **macOS portability adaptations** (per scaffold-onboard's playbook)
- **Slash command bodies use `$ARGUMENTS`** (this is precisely what bug #1 demands)
- **Phase-close commits update CHANGELOG + PLAN's Implementation Status**

---

## 6. First-session game plan

### Step 1 — Orient (10-15 min)

Read this document end-to-end. Spot-read SPEC-architect-critic.md (v0.1) + issue #1 + SPEC-scaffold-dev.md §16.3. Verify v0.1.3 baseline still green by running each `architect-critic/tests/test-*.sh` (10 files: inbox, outbox, state, codex, consolidator, principles, scorer, promotion, commands, e2e). Expected total: ~154 assertions across the 10 files.

### Step 2 — Brainstorm (1-2 hours)

Invoke `superpowers:brainstorming`. Drive Q1-Q7 in §3 above. Visual artifacts ONLY when genuinely visual (per `feedback_brainstorm_artifacts_only_when_visual` memory).

### Step 3 — Author SPEC (1-2 hours)

Create `docs/SPEC-architect-critic-v02.md`. Capture all 8 bug fixes explicitly. Document the skill-first architecture clearly (vs v0.1.3's CLI-tool-shape).

### Step 4 — Author PLAN (1-2 hours)

Create `docs/PLAN-architect-critic-v02.md` with full TDD breakdown. Plan the inbox/outbox removal carefully (don't break consumers that might still be calling it during the migration window).

### Step 5 — Begin implementation (multi-session)

`git checkout -b implementation-architect-critic-v02`. Subagent-driven workflow.

---

## 7. Definition of done (architect-critic v0.2.0)

- All build phases complete
- 4 SKILL.md bodies authored (critiquing-spec, reviewing-critique-history, listing-principles, promoting-principle)
- All 8 bugs from issue #1 fixed (with regression tests for each)
- Inbox/outbox file IPC removed; consumers use in-conversation skill invocation
- composition.json schema authored + plugin install/uninstall hooks update it
- Auto-promotion implementation shipped (was design-intent in v0.1)
- v0.1.3 backwards-compat: existing principles.md + state.json readable; migration path documented
- `architect-critic-v0.2.0` tag pushed
- Marketplace entry updated
- Root README plugin table reflects v0.2
- scaffold-onboard v0.2's drop of inbox/outbox can proceed (this is part of the gate)
- scaffold-dev v0.1's skill-based invocation works against this v0.2 (verified via fixture)
- Issue #1 closed (link the v0.2 PR/commit)

---

## 8. Opening message for the new session

To start the fresh session, paste this:

> Read `docs/HANDOFF-architect-critic-v02-spec.md` end-to-end. The marketplace currently has 4 plugins; architect-critic v0.1.3 has 8 documented bugs (GitHub issue #1) plus the wrong architecture (CLI-tool-shape; bash orchestrating Claude). v0.2 is a substantial retrofit: skill-first design (per Pass D), 8 bug fixes, drop inbox/outbox file IPC in favor of in-conversation skill invocation that scaffold-onboard v0.2 + scaffold-dev v0.1 will use. Use `superpowers:brainstorming` to drive Q1-Q7 in §3 to settled state, then author `docs/SPEC-architect-critic-v02.md` and `docs/PLAN-architect-critic-v02.md`, then begin implementation on a fresh `implementation-architect-critic-v02` branch. Pay particular attention to fixing the silent-no-op audit (bug #2) — that's the architecture-level fix that makes all the other bugs go away by design.
