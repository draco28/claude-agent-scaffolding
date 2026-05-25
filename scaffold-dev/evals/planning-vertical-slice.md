# Eval: scaffold-dev:planning-vertical-slice

> Behavior eval for the `planning-vertical-slice` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:planning-vertical-slice` skill (per SPEC §5) drives the full vertical-slice lifecycle entry: reads `ROADMAP.md` for the named VS, proposes a 4-5 work-item decomposition, surfaces the grill-me offer (per SPEC §16.4 offer 1), identifies parallel-vs-sequential rounds via a strict-layer DAG (§5.4), authors all work-item specs upfront under `docs/specs/sprint-N/VS-N.M-<kebab>/` (§5.2 + §5.5), and invokes architect-critic's `critiquing-spec` skill via in-conversation skill invocation (§16.3 moment 1). Also verifies manifest-refusal (§4.2), missing-VS error surfacing, and graceful architect-critic absence (§16.3 last paragraph).

This eval validates the *orchestrator entry skill's* behavior — not the implementer-agent subagent (§6, covered by `evals/executing-work-item.md`), the per-work-item verification gate (§12, covered by `evals/implementation-checking.md`), or the slice-close ceremony (§14, covered by `evals/closing-vertical-slice.md`).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), `ROADMAP.md` at the manifest-routed destination with the scenario's VS content, marketplace cache directories populated or empty per scenario, and any preexisting `docs/specs/` content described in the scenario.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match (no slash command is invoked in these scenarios — the description-match path is what's under test, except where `/orchestrate VS-N.M` is named explicitly). The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input (e.g., decomposition iteration, grill-me opt-in / opt-out), the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST clear `${CLAUDE_PLUGIN_DATA}/scaffold-dev/` state files, any `docs/specs/sprint-*/` directories the prior scenario may have created, and the marketplace cache stubs between runs. Each scenario starts from a freshly initialized workspace fixture.

## Scenarios

### S1 — Happy path decomposition (manifest present, ROADMAP has target VS, architect-critic present)

**Setup:**
- Dual-repo fixture: tmp parent dir with `canonical/` and `ai_workspace/` sibling repos and a `.workspace/pairing.json` manifest at the parent (mimics workspace-init v0.1.0 output).
- cwd for the target subagent is set to `ai_workspace/` (manifest discovery walks up to find `.workspace/pairing.json`).
- `ai_workspace/ROADMAP.md` present with a well-formed Phase 3 → Sprint 3 → VS-3.2 entry. The VS-3.2 block has a `#### VS-3.2: <kebab name>` heading, a one-paragraph description, and 2-3 `auto:`/`user:` demo criteria per the v0.2 R3 grammar.
- No `docs/specs/sprint-3/VS-3.2-*/` directory exists yet (greenfield slice).
- Mock the architect-critic v0.2 cache: create `${HOME}/.claude/plugins/cache/test-marketplace/architect-critic/0.2.0/skills/critiquing-spec/SKILL.md` (stub content) so the filesystem probe per SPEC §16.3 returns `v0.2`.
- Mock ai-mentor v2.0 cache: create `${HOME}/.claude/plugins/cache/test-marketplace/ai-mentor/2.0.0/skills/grill-me/SKILL.md` (stub) so the grill-me offer probe returns present.
- Pre-injected user follow-ups for the multi-turn dialog: (a) "decomposition looks good, proceed" after the 4-5-item proposal is shown; (b) "skip grill-me" when the offer is surfaced; (c) "use the proposed rounds" when the DAG-derived rounds are shown.

**Trigger:** target subagent user message: `plan VS-3.2`

**Expected behavior:**
- Skill triggers via description-match on the "plan VS-3.2" trigger phrase (per SPEC §5.1 triggers list).
- Skill discovers the manifest via `lib/manifest.sh` walk-up helpers (not raw inline jq) and resolves `routing.roadmap` to locate `ROADMAP.md`.
- Skill reads `ROADMAP.md`, extracts the VS-3.2 block (heading + description + demo criteria), and proposes a 4-5 work-item decomposition (per §5.3) — surfaced to the user as a numbered list with one-line summaries.
- After user confirms the decomposition, skill **offers grill-me** (per §16.4 offer 1) — the offer is a single explicit prompt the user can accept or decline, not auto-invoked.
- After user declines grill-me, skill performs strict-layer DAG topological sort (per §5.4) and surfaces the proposed parallel-vs-sequential round structure for user confirmation.
- After user confirms rounds, skill authors the slice scaffold under `<ai-workspace>/docs/specs/sprint-3/VS-3.2-<kebab>/`: `README.md`, per-work-item `work-N.NN-<kebab>/spec.md` for all decomposed items (specs upfront per §5.5), empty `handoff.md` + `report.md` placeholders alongside each spec.
- Skill invokes architect-critic's `critiquing-spec` skill in-conversation (per §16.3 moment 1) with the authored specs as context. Invocation is via the skill-invocation pattern (description-match or explicit Skill tool call), NOT via legacy inbox/outbox file IPC.
- After critic returns control, skill surfaces "VS-3.2 specs authored and audited; ready for round-1 execution." or equivalent handoff text, and does NOT proceed to spawn implementer-agent subagents on this same turn (round execution is a separate user-initiated step).

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows at least one Bash invocation that sources or calls into `lib/manifest.sh` (e.g., a function name matching `sd_manifest_*` or `mi_manifest_*`); no raw `jq -r '.routing.roadmap' .workspace/pairing.json` style inline reads appear (the green-light criterion "Manifest field reads use the `lib/manifest.sh` helpers (not raw jq inline)" is binding).
- Target subagent's assistant transcript contains a decomposition proposal listing between 4 and 5 work items, each with a short summary line and a stable `N.NN` numbering convention (e.g., `3.2.01`, `3.2.02`, …).
- Transcript contains an explicit grill-me offer prompt (e.g., "Want to grill-me on this decomposition before proceeding?") surfaced as a user-decidable question, not as a silent skip. The offer appears AFTER decomposition settles and BEFORE the architect-critic invocation.
- Transcript contains a round-structure proposal naming at least one round (e.g., "Round 1: work items 3.2.01, 3.2.02 (parallel); Round 2: 3.2.03 (depends on 3.2.01)" or equivalent).
- After the multi-turn confirmations, the filesystem contains: `<ai-workspace>/docs/specs/sprint-3/VS-3.2-<kebab>/README.md`, `<ai-workspace>/docs/specs/sprint-3/VS-3.2-<kebab>/work-3.2.01-<kebab>/spec.md` (and a `spec.md` for each of the 4-5 decomposed items), and empty `handoff.md` + `report.md` placeholders alongside each spec.
- Target subagent's tool-call log contains exactly one `Skill(architect-critic:critiquing-spec)` invocation (or a description-match-triggered architect-critic skill entry by equivalent name per ac v0.2 §5.1). The invocation appears AFTER all spec files are written, not before.
- No file writes to any `inbox/` or `outbox/` paths in the transcript (legacy file IPC must not be used per §16.3).
- Target subagent does NOT invoke the Task tool with `subagent_type="scaffold-dev:implementer-agent"` on this turn — implementer subagent dispatch is a later step in the lifecycle (§6.2) and is out of scope for the entry skill's first invocation.
- No work-item branches or worktrees are created in `canonical/.worktrees/` on this turn (worktree creation is per-round per §11, and round-1 execution is a separate user-initiated step).

---

### S2 — Manifest absent (fail-fast refusal)

**Setup:**
- Tmp repo with `git init` at cwd. No parent directory containing `.workspace/pairing.json`; manifest walk-up discovery returns absent.
- No `ROADMAP.md`, no `docs/specs/`, no marketplace cache stubs.
- Pre-injected user follow-ups: none (skill should refuse without prompting).

**Trigger:** target subagent user message: `orchestrate VS-3.2`

**Expected behavior:**
- Skill triggers via description-match on the "orchestrate VS-3.2" trigger phrase.
- Skill attempts manifest discovery via `lib/manifest.sh` helpers; discovery returns absent.
- Skill refuses to proceed per SPEC §4.2 ("Refuses to start without manifest. workspace-init sole writer.") and surfaces a fail-fast error message naming the two remediation slash commands.
- Skill does NOT read `ROADMAP.md` (no manifest → no `routing.roadmap` to resolve).
- Skill does NOT author any spec files, does NOT create `docs/specs/sprint-*/` directories, and does NOT invoke architect-critic.

**Assertion (judge subagent verifies):**
- Target subagent's final assistant message contains the verbatim sentence (or a string semantically equivalent and containing the literal slash-command tokens): `scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first.` Judge accepts: minor punctuation/quoting variation around the slash-command tokens; rejects: paraphrased substitutes that omit either `/init-workspace` or `/pair-workspace`.
- Target subagent's tool-call log shows at least one attempt to invoke a `lib/manifest.sh` helper (e.g., walk-up discovery function) — the refusal is grounded in the helper's absent-result, not in a heuristic guess.
- No write-flavored tool calls (`Write`, `Edit`, `mkdir` of any `docs/specs/*` path) appear in the transcript.
- No `Skill(architect-critic:*)` invocations appear in the transcript.
- No Task tool invocations appear in the transcript.

---

### S3 — ROADMAP missing target VS (error + remediation hint)

**Setup:**
- Dual-repo fixture identical to S1 (manifest present, walk-up resolves, `routing.roadmap` points at `ai_workspace/ROADMAP.md`).
- `ai_workspace/ROADMAP.md` exists and is well-formed BUT contains only Phase 1 / Sprint 1 / VS-1.1 and VS-1.2 entries. VS-3.2 is NOT in the file.
- Architect-critic cache stub present (not exercised in this scenario but kept consistent).
- Pre-injected user follow-ups: none.

**Trigger:** target subagent user message: `let's plan the next slice — VS-3.2`

**Expected behavior:**
- Skill triggers via description-match on the "let's plan the next slice" trigger phrase.
- Skill discovers the manifest and reads `ROADMAP.md` via `lib/manifest.sh` helpers.
- Skill searches `ROADMAP.md` for a `VS-3.2` block (heading match `#### VS-3.2:` or equivalent stable anchor).
- Search returns no match.
- Skill surfaces an error message that: (a) names `VS-3.2` explicitly as the missing slice, (b) names the resolved `ROADMAP.md` path (so the user sees which file was searched), and (c) provides the remediation slash-command hint pointing at scaffold-onboard's `--add-slice` invocation.
- Skill does NOT proceed to decomposition, does NOT author spec files, and does NOT invoke architect-critic.

**Assertion (judge subagent verifies):**
- Target subagent's final assistant message names `VS-3.2` explicitly (quoted or otherwise identifiable as the missing slice).
- The message cites the resolved `ROADMAP.md` path (e.g., `<ai-workspace>/ROADMAP.md` or the absolute path equivalent the manifest resolved to) — the judge confirms the cited path matches the fixture's manifest-routed destination.
- The message includes the remediation hint with the slash-command token `/plan-roadmap` and the `--add-slice 3.2` argument (or argument equivalent — `--add-slice VS-3.2` is also accepted). Judge accepts minor surrounding-phrase variation; rejects: paraphrased substitutes that omit either `/plan-roadmap` or the slice-id argument.
- Target subagent's tool-call log shows at least one Read of `ROADMAP.md` and at least one `lib/manifest.sh` helper invocation.
- No `docs/specs/sprint-3/` directory is created on the filesystem.
- No write-flavored tool calls to `ROADMAP.md` or any new spec file appear in the transcript (the skill surfaces and bails; it does not auto-fix the roadmap).
- No `Skill(architect-critic:*)` invocations appear in the transcript.

---

### S4 — Architect-critic absent (graceful degradation, no blocking)

**Setup:**
- Dual-repo fixture identical to S1: manifest present, `ROADMAP.md` contains a well-formed VS-3.2 block, ai-mentor v2.0 cache stub present (so grill-me offer still surfaces).
- **No architect-critic cache directory at all** — the filesystem probe at `~/.claude/plugins/cache/*/architect-critic/*/skills/critiquing-spec/SKILL.md` returns no matches.
- Pre-injected user follow-ups identical to S1: "decomposition looks good, proceed" / "skip grill-me" / "use the proposed rounds".

**Trigger:** target subagent user message: `start a new vertical slice — VS-3.2`

**Expected behavior:**
- Skill triggers via description-match on the "start a new vertical slice" trigger phrase.
- Skill proceeds through manifest discovery, ROADMAP read, decomposition proposal, grill-me offer, round identification, and spec authoring identically to S1.
- At the architect-critic invocation moment (after specs are written, per §5.5 + §16.3 moment 1), skill performs the filesystem probe per §16.3 and finds no architect-critic v0.2 SKILL.md.
- Skill emits the warning per §16.3 last paragraph ("adversarial review skipped — architect-critic not detected" or equivalent string from §14.3's "adversarial review skipped" language) AND continues without blocking — the slice scaffold is still authored, the warning is surfaced once, and the skill exits with the normal "ready for round-1 execution" handoff.
- Skill does NOT halt, does NOT prompt the user to install architect-critic, and does NOT retry the probe.

**Assertion (judge subagent verifies):**
- Target subagent's assistant transcript contains a warning string matching the SPEC §16.3 / §14.3 "adversarial review skipped" language — judge accepts: "adversarial review skipped", "skipping adversarial review", "architect-critic not detected, skipping review", or equivalent. Judge rejects: silent skip (no warning surfaced at all), or a blocking error ("install architect-critic first").
- The warning string explicitly references either `architect-critic` (the plugin name) OR "adversarial review" (the capability name) — the user must be able to identify what was skipped.
- Filesystem after the turn contains the full slice scaffold identical to S1's success criteria: `<ai-workspace>/docs/specs/sprint-3/VS-3.2-<kebab>/README.md` + 4-5 `work-N.NN-<kebab>/spec.md` files + empty `handoff.md` / `report.md` placeholders.
- Target subagent's tool-call log shows the filesystem probe attempt (e.g., a `Bash` invocation listing or globbing `~/.claude/plugins/cache/*/architect-critic/...`); the probe result is absent.
- No `Skill(architect-critic:*)` invocations appear in the transcript (the probe returned absent before any invocation attempt).
- The skill's final assistant message indicates the slice is ready for round-1 execution (i.e., the lifecycle proceeded; the absence did not block forward progress).

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 4 scenarios PASS.

## Out of scope for this eval

- Implementer-agent subagent dispatch (Task tool invocation, multi-call gaps-mode / complete-mode return parsing) — covered by `evals/executing-work-item.md` and the `test-subagent.sh` suite.
- Per-work-item verification gate (AC checks, report cross-check, project rule checks) — covered by `evals/implementation-checking.md` (PLAN T0.2).
- Round-close orchestrator flow (strict-sequential processing per §13, merge orchestration, halt-on-conflict semantics) — covered by `test-merge.sh` and the e2e fixture in `test-e2e.sh`.
- Slice-close ceremony (auto-demo execution, manual-demo prompting, slice-close adversarial review per §14.3, memory-bank harvest per §15.2) — covered by `evals/closing-vertical-slice.md`.
- grill-me opt-IN path (user accepts the offer and ai-mentor's `grill-me` skill takes over) — the offer-surfacing behavior is tested here in S1 + S4 via the opt-out branch; the opt-in branch is covered by `test-compose.sh` and ai-mentor v2.0's own evals.
- Worktree creation mechanics (`git worktree add` at `${canonical.root}/.worktrees/work-N.NN-<kebab>`, branch naming, base-at-canonical-main-HEAD) — worktrees are created at round start (per §11), not at slice-plan time; this eval explicitly excludes worktree state from S1's success criteria.
- The handoff escape valve skill (`handing-off-session` per §6b) — orthogonal; covered by `evals/handing-off-session.md`.
- Manifest schema validation / corrupt-manifest behavior — S2 covers absent-manifest only; corrupt-but-present manifest semantics are defined by workspace-init's contract and tested in its own suite.
