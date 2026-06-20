# Eval: scaffold-dev:closing-vertical-slice

> Behavior eval for the `closing-vertical-slice` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:closing-vertical-slice` skill (per SPEC §14 + §15.2) executes the three-layer slice-close ceremony in correct order: parses `auto:`/`user:` demo criteria per §14.1 grammar from the VS README, runs each `auto:` command in canonical (post-merge state), surfaces each `user:` step for manual execution and captures the user's pass/fail/partial outcome, invokes architect-critic's `critiquing-spec` skill at close depth per §14.3 / §16.3 moment 2, authors `retrospective.md` per §16b, runs the 8-step memory-bank harvest per §15.2 (including the handoff sweep at `<ai-workspace>/.workspace/handoffs/vs-N.M.K-*.md` with source-tagged `[report]` vs `[handoff]` items), and ONLY THEN removes worktrees + deletes branches per §11 M2. Also verifies halt-on-auto-demo-failure behavior and graceful architect-critic absence per §14.3 / §16.3 last paragraph.

This eval validates the *slice-close ceremony skill's* behavior — not the orchestrator entry skill (§5, covered by `evals/planning-vertical-slice.md`), the per-work-item verification gate (§12, covered by `evals/implementation-checking.md`), or the implementer-agent subagent (§6, covered by `evals/executing-work-item.md`).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), published roadmap state at `<ai-workspace>/.workspace/project-roadmap.json` with an exact `VS-3.2.1` record whose `sprint_id` is `3.2`, a fully-merged slice at `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/` with all 4-5 work-item subdirs containing `spec.md` + `handoff.md` + `report.md`, a VS README with `auto:`/`user:` demo criteria per §14.1 grammar, canonical worktrees at `${canonical.root}/.worktrees/sprint-3.2/work-1.NN-<kebab>` still present (per §11 M2 — worktrees survive round close, removed only at slice close), all work-item branches merged into canonical main, and any scenario-specific handoffs in `<ai-workspace>/.workspace/handoffs/`.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session at slice-close time. The target subagent has access to the skill via its description-match (no slash command is invoked except where `/close-slice` is named explicitly). The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text), preserving tool-call ordering (the judge MUST be able to verify relative position of tool calls — e.g., "Bash for auto-demo at position N; Skill for architect-critic at position M with M > N")
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input (e.g., manual-demo pass/fail report, harvest accept/edit/reject per item), the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**Ceremony-order verification:** the judge is explicitly responsible for checking the relative ordering of tool-call sites. For S1 the binding order is: (1) all `auto:` demo Bash invocations → (2) manual-demo prompt surfaced + user response received → (3) `Skill(architect-critic:critiquing-spec)` invocation → (4) `Write` of `retrospective.md` → (5) harvest sweep Reads of report.md + handoff files → (6) `git worktree remove` Bash invocations. Any out-of-order observation is a fail.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST clear `${CLAUDE_PLUGIN_DATA}/scaffold-dev/` state files, rebuild the canonical worktree fixture (merged branches + still-present `.worktrees/` directories), and reset `<ai-workspace>/.workspace/handoffs/` content between runs. Each scenario starts from a freshly initialized slice-close-ready fixture.

## Scenarios

### S1 — Three-layer ceremony happy path (all demos pass, critic present, harvest with handoffs)

**Setup:**
- Dual-repo fixture: manifest at the parent, `routing.worktrees_dir` resolves to `${canonical.root}/.worktrees/`, `routing.handoffs_dir` resolves to `<ai-workspace>/.workspace/handoffs/`.
- Published roadmap fixture: `<ai-workspace>/.workspace/project-roadmap.json` contains `{"id":"VS-3.2.1","sprint_id":"3.2","name":"<kebab>",...}` so close-flow path resolution field-reads `sprint_id` instead of deriving it from the slice id.
- Slice VS-3.2.1 fully implemented: 4 work-item subdirs under `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/`, each with `spec.md` + `handoff.md` + a complete `report.md` (status `complete`, AC outcomes all pass, "Suggestions for memory bank" section written as **free-form prose** on 2 of the 4 reports — no `target_file:/suggestion:` bullet grammar; the agent reads the prose and judges what to promote).
- VS README at `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/README.md` contains 3 demo criteria per §14.1: two `auto:` lines (e.g., `- [ ] auto: \`pytest tests/integration/test_slice.py\` → expected: exit 0` and `- [ ] auto: \`curl -s localhost:8000/api/health\` → expected: output contains "ok"`) and one `user:` line (e.g., `- [ ] user: Navigate to localhost:3000/dashboard → expected: new card visible`).
- All work-item branches merged into canonical main; canonical worktrees at `${canonical.root}/.worktrees/sprint-3.2/work-1.01-<kebab>` through `work-1.04-<kebab>` still present per §11 M2.
- `<ai-workspace>/.workspace/handoffs/` contains 2 handoff files matching the slice: `vs-3.2.1-bugfix-auth-a1b2.md` (mid-slice bug-fix detour with a populated section 4 "What's NOT in memory bank yet") and `vs-3.2.1-techdebt-logging-e5f6.md` (likewise with a section-4 promote-candidate). Also present: one unrelated `sprint-3.2-context-bloat-c3d4.md` that MUST NOT be swept (different scope; not slice-tagged).
- Mock architect-critic v0.2 cache: `${HOME}/.claude/plugins/cache/test-marketplace/architect-critic/0.2.0/skills/critiquing-spec/SKILL.md` (stub) so the §16.3 probe returns present.
- Pre-injected user follow-ups: (a) "pass — card rendered with real data" after the manual-demo step is surfaced; (b) per-item harvest decisions: "accept" for the first 2 surfaced items, "edit: shorten to one line" for the 3rd, "reject" for the 4th.

**Trigger:** target subagent user message: `close VS-3.2.1`

**Expected behavior:**
- Skill triggers via description-match on the "close VS-3.2.1" trigger phrase (per SPEC §7.1 + §14 triggers list).
- Skill discovers the manifest via `lib/manifest.sh` walk-up helpers and resolves the VS README path under `routing.specs_dir` (or equivalent).
- Skill reads the VS README, extracts the demo-criteria block, and parses each line per §14.1 grammar into `(prefix, command-or-action, expectation)` tuples.
- Skill executes each `auto:` line in sequence: runs the command in canonical (NOT in the work-item worktree — canonical now contains all rounds' merges per §14.1), checks exit code against `expected: exit 0` (deterministic), and agent-judges the captured output against `expected: output contains "ok"` (content expectation, not grep-asserted). Both `auto:` lines pass.
- Skill records each `auto:` outcome in the VS README's "Demo verification" section.
- Skill surfaces the `user:` line to the user with the expected outcome and waits for the pass/fail/partial report. User reports "pass — card rendered with real data". Skill records the result + user's note in "Demo verification".
- Skill performs the architect-critic filesystem probe per §16.3, finds the v0.2 SKILL.md, and invokes `architect-critic:critiquing-spec` in-conversation at close depth (per §14.3) with context: combined diff from VS-start commit to canonical HEAD + VS README + all work-item specs. NOT via inbox/outbox file IPC.
- After critic returns control, skill authors `retrospective.md` at `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/retrospective.md` per §16b's 7-section format.
- Skill runs the §15.2 8-step harvest: (1) reads all 4 work-item `report.md` files; (2) reads all `vs-3.2.1-*.md` handoffs at `<ai-workspace>/.workspace/handoffs/` (sweeps the 2 slice-scoped handoffs, skips the unrelated `sprint-3.2-context-bloat-c3d4.md`); (3) **agent reads** the report "Suggestions for memory bank" free-form prose sections + handoff section 4 promote-candidates and judges what to promote (no grammar parser); (4) categorizes by target memory-bank file; (5) surfaces each candidate to the user with source-tag prefix `[report]` or `[handoff]`; (6) for each candidate exceeding ~12 lines (`sd_harvest_lint_length` threshold), surfaces a tighten-to-pointer advisory before the accept/edit/reject choice; (7) consumes user accept/edit/reject decisions; (8) for each approved item, calls `sd harvest_apply` with the accepted-items JSON array and the slice-id `"VS-3.2.1"` — the dispatcher invokes the harvest writer, which writes each item with the provenance trailer `<!-- Added from VS-3.2.1 retrospective, YYYY-MM-DD; source: report -->` or `<!-- … source: handoff -->`; (9) records harvest outcomes in `retrospective.md` (including which handoff items were promoted vs left in handoff).
- ONLY AFTER harvest completes successfully: skill removes each work-item worktree via `git worktree remove` and deletes each work-item branch per §11 M2 + §14.4.
- Skill emits final "VS-3.2.1 closed" handoff message.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log contains exactly 2 Bash invocations running the 2 `auto:` demo commands. Both invocations execute in canonical (NOT in any `.worktrees/sprint-3.2/work-1.NN-<kebab>` path) — the judge confirms either the absence of a `cd <worktree>` prefix or the explicit presence of a canonical-root cwd marker. The first `auto:` step (`exit 0`) is verified deterministically; the second (`output contains "ok"`) is agent-judged — the judge asserts the orchestrator reads the captured stdout and records a reasoned pass (a one-line reason in the `## Demo verification` outcome line), not that it grep-asserts the string.
- Target subagent's assistant transcript surfaces the `user:` demo line as a manual step with the expected outcome quoted, AND the target waits for / captures the pre-injected user response ("pass — card rendered with real data") before proceeding.
- Target subagent's tool-call log contains exactly one `Skill(architect-critic:critiquing-spec)` invocation (or a description-match-triggered architect-critic skill entry by equivalent name per ac v0.2 §5.1). The invocation appears AFTER both `auto:` Bash invocations AND after the manual-demo user response is captured (judge verifies relative position in the tool-call log).
- No file writes to any `inbox/` or `outbox/` paths in the transcript (legacy file IPC must not be used per §16.3).
- Target subagent's tool-call log contains a `Write` (or equivalent) of `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/retrospective.md`, and that Write appears AFTER the architect-critic invocation in tool-call order.
- Harvest reads: target subagent's tool-call log contains Reads of all 4 work-item `report.md` files AND Reads of both `vs-3.2.1-bugfix-auth-a1b2.md` and `vs-3.2.1-techdebt-logging-e5f6.md`. The unrelated `sprint-3.2-context-bloat-c3d4.md` MUST NOT appear in any Read (handoff sweep is slice-scoped).
- Target subagent's assistant transcript surfaces each harvest candidate with a source-tag prefix that is one of the literal tokens `[report]` or `[handoff]` (verbatim, with brackets) — judge rejects messages that omit the brackets, use different spelling (e.g., `(report)`), or fail to distinguish report-origin from handoff-origin.
- If any surfaced candidate's suggestion text exceeds ~12 lines, the target subagent's transcript includes a tighten-to-pointer advisory (e.g., "this entry is long — consider trimming to a pointer") before presenting the accept/edit/reject choice for that item.
- Approved harvest items are written to memory-bank files via a dispatcher-facing `sd harvest_apply` Bash invocation (NOT a raw helper call and NOT a raw `Write` tool call hand-crafting the trailer). Judge confirms: (a) a Bash call containing `sd harvest_apply` appears in the tool-call log after the accept/edit/reject decisions are captured; (b) the resulting memory-bank file content includes the provenance trailer matching `<!-- Added from VS-3.2.1 retrospective, <date>; source: report -->` or `<!-- … source: handoff -->` (judge accepts minor date-format variation; rejects: missing trailer, missing `source:` field, missing `VS-3.2.1` reference, or `source:` label mis-matching origin).
- **Worktree removal ordering (M2 enforcement):** any `git worktree remove` Bash invocation MUST appear AFTER the `retrospective.md` Write AND after the harvest-step Reads of report/handoff files. Judge scans the tool-call log: if any `git worktree remove` or `git branch -D work-1.*` invocation precedes the retrospective Write or precedes any harvest Read, the scenario FAILS.
- All 4 work-item worktrees ARE removed by ceremony end (final filesystem state shows `${canonical.root}/.worktrees/sprint-3.2/work-1.01-<kebab>` through `work-1.04-<kebab>` absent), and all 4 work-item branches ARE deleted (final `git branch` listing in canonical does not contain any `work-1.NN-*` branch).
- Target subagent's final assistant message indicates the slice is closed (e.g., "VS-3.2.1 closed" or equivalent).

---

### S2 — Auto-demo step fails (halt, surface failing step + output, offer recovery menu)

**Setup:**
- Dual-repo fixture identical to S1: manifest present, slice VS-3.2.1 implemented, all branches merged, worktrees present at `${canonical.root}/.worktrees/sprint-3.2/work-1.NN-<kebab>`, architect-critic cache stub present, handoffs identical to S1.
- VS README contains 2 `auto:` lines + 1 `user:` line identical to S1, EXCEPT the first `auto:` command fails when executed against canonical HEAD (e.g., `pytest tests/integration/test_slice.py` exits 1 with a test-failure trace; some integration assumption broke at merge time).
- Pre-injected user follow-ups: none (skill should halt on the auto-demo failure and surface the recovery menu; user response is captured downstream, not in this eval).

**Trigger:** target subagent user message: `slice close`

**Expected behavior:**
- Skill triggers via description-match on the "slice close" trigger phrase.
- Skill discovers manifest, parses VS README demo criteria, and begins running `auto:` lines in sequence.
- First `auto:` command runs in canonical; observes exit code 1. Exit-code form (`exit 0`) → deterministic check → fail (exit 1 is a clean deterministic fact, no agent judgment needed for the failure verdict itself).
- Skill **halts immediately** — does NOT run the second `auto:` line, does NOT surface the `user:` step, does NOT invoke architect-critic, does NOT author retrospective, does NOT run harvest, does NOT remove any worktree.
- Skill surfaces a failure report naming: (a) the failing `auto:` step (verbatim line from the VS README), (b) the command that was run, (c) the observed exit code + captured stderr/stdout excerpt.
- Skill presents a recovery menu with at least 3 options: (1) Re-author the demo step (return to scaffold-onboard's `authoring-vertical-slice-demo` flow), (2) Accept-with-deferred (slice closes with the failing step marked deferred; must still be demoable despite the caveat, per §14.4 close-with-deferred), (3) Re-spawn implementer subagent for fix-up against the offending area.
- Skill does NOT auto-select an option, does NOT mutate the VS README, does NOT remove worktrees or branches.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows exactly ONE Bash invocation running an `auto:` command — the second `auto:` line MUST NOT appear in the tool-call log (halt-on-first-auto-demo-failure is binding; mirrors §12.2's AC halt semantics).
- Target subagent's assistant transcript contains the verbatim text of the failing `auto:` line from the VS README (so the user can identify which step broke) AND the observed exit code / output excerpt.
- Target subagent's assistant transcript surfaces a menu with at least 3 distinct numbered or bulleted options matching the §14.4 / §12.2 spirit: option text MUST identify "re-author" / "re-author demo step" (option 1), "accept" / "deferred" / "partial" (option 2), and "re-spawn" / "fix-up" / "implementer" (option 3) — judge accepts paraphrase but rejects a menu that collapses to fewer than 3 options.
- No `Skill(architect-critic:*)` invocation appears in the transcript (ceremony halted before the critic moment).
- No `Write` of `retrospective.md` appears in the transcript.
- No Reads of `<ai-workspace>/.workspace/handoffs/vs-3.2.1-*.md` appear in the transcript (harvest is downstream of critic; halt was upstream).
- **Worktrees preserved (M2 enforcement):** no `git worktree remove` Bash invocation appears in the tool-call log. Final filesystem state confirms `${canonical.root}/.worktrees/sprint-3.2/work-1.01-<kebab>` through `work-1.04-<kebab>` all still present. No `git branch -D work-1.*` invocation appears either.
- No `Task` tool invocation appears in the transcript (option 3 re-spawn is a user-selected action, not auto-executed by the ceremony).

---

### S3 — Architect-critic absent (warn + proceed with auto + manual demo only)

**Setup:**
- Dual-repo fixture identical to S1: manifest present, slice VS-3.2.1 implemented, all branches merged, worktrees present, handoffs at S1's positions, VS README with 2 `auto:` (both pass) + 1 `user:` line.
- **No architect-critic cache directory at all** — the filesystem probe at `~/.claude/plugins/cache/*/architect-critic/*/skills/critiquing-spec/SKILL.md` returns no matches.
- Pre-injected user follow-ups: (a) "pass — card visible" after the manual-demo step; (b) per-item harvest decisions: "accept" for all surfaced items.

**Trigger:** target subagent user message: `wrap up the slice`

**Expected behavior:**
- Skill triggers via description-match on the "wrap up the slice" trigger phrase.
- Skill proceeds through manifest discovery, demo-criteria parse, `auto:` execution (both pass), and `user:` surfacing identically to S1.
- At the architect-critic moment (after manual-demo response is captured, per §14.3), skill performs the §16.3 filesystem probe and finds no architect-critic v0.2 SKILL.md.
- Skill emits the §14.3 / §16.3 last-paragraph warning ("adversarial review skipped — architect-critic not detected" or equivalent) AND continues without blocking — the ceremony proceeds through retrospective authoring, harvest, and worktree cleanup.
- Skill does NOT halt, does NOT prompt the user to install architect-critic, does NOT retry the probe.
- Retrospective is authored; harvest runs; worktrees + branches are removed after harvest.

**Assertion (judge subagent verifies):**
- Target subagent's assistant transcript contains a warning string matching the §14.3 / §16.3 "adversarial review skipped" language — judge accepts: "adversarial review skipped", "skipping adversarial review", "architect-critic not detected, skipping review", or equivalent. Judge rejects: silent skip (no warning surfaced at all), or a blocking error.
- The warning string explicitly references either `architect-critic` (the plugin name) OR "adversarial review" (the capability name).
- Target subagent's tool-call log shows the filesystem probe attempt (e.g., a `Bash` invocation listing or globbing `~/.claude/plugins/cache/*/architect-critic/...`); the probe result is absent.
- No `Skill(architect-critic:*)` invocation appears in the transcript.
- Target subagent's tool-call log contains a `Write` of `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/retrospective.md` (ceremony proceeded; absence did not block).
- Target subagent's tool-call log contains Reads of all 4 work-item `report.md` files and both `vs-3.2.1-*.md` handoffs (harvest still runs).
- **Worktree removal ordering (M2 enforcement):** `git worktree remove` Bash invocations appear AFTER the retrospective Write AND after the harvest-step Reads; final filesystem state shows all 4 worktrees absent and all 4 work-item branches deleted.
- Target subagent's final assistant message indicates the slice is closed.

---

### S4 — Memory-bank harvest with handoffs (source-tag promote candidates as `[handoff]` vs `[report]`)

**Setup:**
- Dual-repo fixture identical to S1 happy path (architect-critic cache present, both `auto:` pass, `user:` will pass), but the report/handoff content is curated so harvest produces a mix of both source-tags:
  - 2 of the 4 work-item `report.md` files contain **free-form prose** "Suggestions for memory bank" sections (no bullet grammar; e.g., one contains a paragraph noting "subagent must use absolute paths — see worktree init issue"; another contains a paragraph noting "merge conflict on shared schema — 09-known-issues worthy"). The other 2 have empty "Suggestions for memory bank" sections.
  - `<ai-workspace>/.workspace/handoffs/vs-3.2.1-bugfix-auth-a1b2.md` section 4 ("What's NOT in memory bank yet") contains 1 promote-worthy item (e.g., "auth retry pattern not yet codified").
  - `<ai-workspace>/.workspace/handoffs/vs-3.2.1-techdebt-logging-e5f6.md` section 4 contains 1 promote-worthy item (e.g., "log-rotation cron caveat not yet codified").
  - A 3rd handoff `sprint-3.2-context-bloat-c3d4.md` exists but is sprint-scoped (not slice-scoped); MUST NOT be swept.
- Pre-injected user follow-ups: (a) "pass" for manual demo; (b) per-item harvest decisions: "accept" for both `[report]` items, "edit: tighten phrasing" for the first `[handoff]` item, "reject" for the second `[handoff]` item.

**Trigger:** target subagent user message: `run slice-close ceremony`

**Expected behavior:**
- Skill triggers via description-match on the "run slice-close ceremony" trigger phrase.
- Skill proceeds through auto-demo (both pass) → manual-demo (user reports "pass") → architect-critic invocation (cache present) → retrospective authoring identically to S1.
- At harvest step 5 (per §15.2), skill surfaces 4 distinct promote candidates to the user, each prefixed with its source tag: 2 prefixed `[report]` (one per populated report), 2 prefixed `[handoff]` (one per slice-scoped handoff section 4).
- The agent reads the free-form prose sections and handoff section 4 entries directly (no grammar parser) and produces an accepted-items JSON array after user decisions.
- If any candidate's suggestion text exceeds ~12 lines, skill surfaces a tighten-to-pointer advisory before presenting the accept/edit/reject choice for that item.
- User per-item decisions are applied: the 2 `[report]` items are accepted; the first `[handoff]` item is accepted with edit; the second `[handoff]` item is rejected. For the 3 approved items, skill calls `sd harvest_apply` with the accepted-items JSON and slice-id `"VS-3.2.1"`. Each applied item carries the provenance trailer with the matching `source: report` or `source: handoff` field written by the dispatcher-invoked harvest writer.
- Retrospective.md's harvest section records: 2 promoted from reports (with target files), 1 promoted from handoff with edit, 1 left in handoff.
- After harvest, skill removes worktrees + deletes branches per §11 M2.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows Reads of all 4 work-item `report.md` files (harvest step 1) AND Reads of exactly `vs-3.2.1-bugfix-auth-a1b2.md` + `vs-3.2.1-techdebt-logging-e5f6.md` (harvest step 2 — slice-scoped sweep). The unrelated `sprint-3.2-context-bloat-c3d4.md` MUST NOT appear in any Read.
- Target subagent's assistant transcript surfaces exactly 4 promote candidates to the user, each prefixed with one of the literal tokens `[report]` or `[handoff]` (verbatim, with brackets). Judge counts: 2 candidates prefixed `[report]` AND 2 candidates prefixed `[handoff]`.
- Target subagent's tool-call log contains a Bash invocation of `sd harvest_apply` after the accept/edit/reject decisions are consumed. Judge confirms the call receives the accepted-items JSON array (3 items: 2 report-sourced + 1 handoff-sourced with edit applied), every accepted item includes `target_file`, and the slice-id is `"VS-3.2.1"`.
- Per-item provenance trailers in the modified memory-bank files use the exact strings `source: report` (for the 2 report-sourced items) and `source: handoff` (for the 1 accepted handoff-sourced item). Judge rejects: trailers that omit the `source:` field, trailers that mis-label source (e.g., `source: report` on a handoff-origin item), or absent trailers entirely.
- The rejected handoff item is NOT written to any memory-bank file. Filesystem diff confirms only 3 memory-bank file modifications (2 report-sourced + 1 handoff-sourced edited).
- Target subagent's tool-call log contains a `Write` (or `Edit`) of `retrospective.md`, and the retrospective content distinguishes which items came from reports vs handoffs (judge confirms the harvest section names at least the 3 promoted items with their source AND notes the 1 item "left in handoff" per §15.2 step 8).
- **Worktree removal ordering (M2 enforcement):** `git worktree remove` Bash invocations appear AFTER all harvest Reads AND after all memory-bank file Writes AND after the retrospective Write. Final filesystem state shows all 4 worktrees absent and all 4 work-item branches deleted.
- Target subagent's final assistant message indicates the slice is closed.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 7 scenarios PASS.

## Out of scope for this eval

- Sprint-close ceremony (sprint-level retrospective per §16b, sprint-scope handoff cleanup per §6b.6, carry-forward handoff handling) — slice-close is the unit under test here; sprint-close is either an extension of this skill or a separate `closing-sprint` skill (resolved during PLAN per §6b.6) and gets its own eval if separate.
- grill-me opt-IN at slice close (offer 3 per §16.4 fires AFTER fix-up replan, not at clean slice close) — covered by `test-compose.sh` and ai-mentor v2.0's own evals.
- Architect-critic's internal challenge-rebuttal cycle (Codex invocation, T=4 concession scoring, sequential rebuttal loop) — that's architect-critic v0.2's territory, tested in its own suite. This eval treats the critic invocation as a black box and only asserts that it's invoked at the right ceremony position with the right context.
- `auto:`/`user:` grammar parser correctness — the closing orchestrator parses demo lines directly (split on ` → expected: ` after stripping prefix); demo evaluation for content expectations is agent-judged, validated by the eval scenarios here (S1/S2). Structural well-formedness validation is covered by scaffold-onboard's `evals/authoring-vertical-slice-demo.md`. This eval treats the combined parse+judge as a black box at the orchestrator layer.
- Retrospective.md template correctness (7-section format per §16b) — template fidelity is covered by `tests/test-retrospective.sh`. This eval asserts the file is written at the right time with source-tagged harvest content; full template-conformance is downstream.
- Memory-bank file write conflict semantics (concurrent harvest from two slices in the same sprint) — out of scope per §17; orchestrator-only writes plus serial slice-close ordering prevent the case in v0.1.
- Carry-forward handoff naming + survival across sprint-close cleanup (`sprint-N-to-N+1-handoff-XXXX.md`) — §6b.6 deferral; not exercised by slice-close.
- Manifest absence / corrupt-manifest behavior — `evals/planning-vertical-slice.md` S2 covers the absent-manifest refusal at the orchestrator entry point; if the user invokes slice close without a manifest, the same fail-fast applies but is not re-tested here (orthogonal concern, covered upstream).
- Close-with-deferred downstream effect (slice closes with a failing `auto:` marked deferred; backlog gets a follow-up work item) — option-selection downstream behavior is covered by `evals/planning-vertical-slice.md` (replan path) and `tests/test-backlog.sh`. S2 here verifies the menu is *surfaced* with all options; downstream selection is out of scope.

---

### S5 — pr_hierarchical slice close surfaces a review comment before merging

**Setup:** pr_hierarchical workspace mid-slice; demos pass; `sd pr_state` returns
`mergeStateStatus: CLEAN` AND an unresolved review thread from a review bot
(fixture `tests/fixtures/pr-view-with-review-comment.json` shape).

**Trigger:** user closes the slice (`close VS-1.1.1`).

**Expected behavior:** after harvest + worktree cleanup, the skill pushes the slice
branch, opens the slice→sprint PR, reads `sd pr_state`, and — because an unresolved
review comment exists despite green CI — SURFACES the comment and ASKS before
merging rather than auto-merging on the green check.

**Assertion (judge):** PASS iff the transcript shows the slice→sprint PR opened,
the unresolved review comment surfaced to the user, and NO `sd pr_merge` / `gh pr
merge` invocation before explicit user acknowledgment. FAIL if it merges on
`CLEAN` mergeStateStatus while the review thread is unresolved.

---

### S6 — Close-time active-context reconcile (status flip + field-read Next-up)

**Setup:**
- Dual-repo fixture identical to S1 happy path (manifest present, slice VS-3.2.1 implemented + merged, worktrees present, architect-critic cache present, both `auto:` pass, `user:` will pass, S1 harvest content).
- Published roadmap at `<ai-workspace>/.workspace/project-roadmap.json` contains BOTH `{"id":"VS-3.2.1","sprint_id":"3.2","name":"<kebab>"}` AND a later same-sprint slice `{"id":"VS-3.2.2","sprint_id":"3.2","name":"settings-panel"}`, plus a `sprints[]` array — so VS-3.2.1 is NOT the final slice of its sprint (`sd roadmap_next_slice VS-3.2.1` ⇒ `VS-3.2.2`).
- `<ai-workspace>/.claude/memory-bank/05-active-context.md` (LIVE, dev-authored) present, with a `## Current focus` block presenting the slice as `**Sprint 3.2 · VS-3.2.1 — IN FLIGHT (R1 ✅ R2 ✅ … next R3)**` followed by a round log, and a STALE `## Next up` block (e.g., still pointing at VS-3.2.1 or an earlier slice). The file ALSO contains user-authored `## Recent decisions` + `## Blockers` content and a `<!-- sd:cursor:start -->…<!-- sd:cursor:end -->` JSON block.
- Pre-injected user follow-ups: S1's (manual-demo "pass", per-item harvest decisions) PLUS (c) "confirm" when the §12 reconcile surfaces the proposed Current-focus + Next-up edit.

**Trigger:** target subagent user message: `close VS-3.2.1`

**Expected behavior:**
- Skill proceeds through the S1 happy-path ceremony (demos → critic → retrospective → harvest → worktree cleanup) on the all-pass path.
- At §12, skill field-reads the next slice via `sd roadmap_next_slice VS-3.2.1` ⇒ `VS-3.2.2` and its display name via `sd roadmap_slice_field VS-3.2.2 name` ⇒ `settings-panel` (NOT a remembered/paraphrased name, NOT a ROADMAP heading grep).
- Skill reads `05-active-context.md` and surfaces BOTH the current `## Current focus` / `## Next up` text and a proposed targeted edit — Current focus flips VS-3.2.1's `IN FLIGHT` marker to `CLOSED` + the merge ref (round log retained verbatim); Next up becomes `Next: /orchestrate VS-3.2.2 — settings-panel`. Skill waits for confirmation.
- On the pre-injected "confirm", skill applies the targeted edit to the two prose blocks ONLY — leaving `## Recent decisions`, `## Blockers`, the round log, and the structured `<!-- sd:cursor:start -->…<!-- sd:cursor:end -->` JSON block untouched — and never regenerates the file.
- Skill emits the final "VS-3.2.1 closed" message.
- **Final-slice variant (not the concrete fixture here, but the §12.2 alternate branch):** when the closed slice IS the sprint's final slice, `sd roadmap_next_slice` returns empty and the Next-up pointer is set from `sd roadmap_next_sprint` (sprint-close → next sprint, or "no next sprint in the published roadmap" when that too is empty).

**Assertion (judge subagent verifies):**
- Target's tool-call log contains a `sd roadmap_next_slice` Bash invocation during §12, and the surfaced "Next up" names `VS-3.2.2` exactly (field-read). Judge rejects a Next-up that names any slice other than the roadmap's actual next slice, or one that is hand-typed/paraphrased rather than dispatcher-derived.
- The §12 reconcile occurs on the all-pass path AFTER the `git worktree remove` invocations and BEFORE the final "closed" message (judge verifies relative tool-call position).
- Target SURFACES the proposed Current-focus + Next-up edit and WAITS for the pre-injected "confirm" before any write to `05-active-context.md` (no silent auto-write).
- The applied edit flips VS-3.2.1 from `IN FLIGHT` to `CLOSED` in `## Current focus` and sets `## Next up` to VS-3.2.2; the closed slice's round-log lines are preserved verbatim (judge confirms the round detail still present).
- The `05-active-context.md` `## Recent decisions`, `## Blockers`, and the entire `<!-- sd:cursor:start -->…<!-- sd:cursor:end -->` JSON block are UNCHANGED (judge diffs the file: only the Current-focus status line + the Next-up line changed). The file is NOT rewritten wholesale / regenerated from a template.
- No write to any spec-derived file occurs at §12.
- Target's final assistant message indicates the slice is closed.

---

### S7 — Lean-index pointer channels: restate→pointer with resolution check (#48 C/D/E)

**Setup:**
- Dual-repo fixture like S1 (slice VS-3.2.1 merged, ready to harvest), with a populated ADR dir: the manifest-routed process-ADR dir contains `adr-0007-retry-backoff-policy.md`.
- The report "Suggestions for memory bank" prose carries three harvest candidates: (a) a multi-line decision note that **restates the decision already recorded in ADR-0007**; (b) a caveat that cites `MASTER-SPEC.md §5.2`, a heading that **exists** in the fixture MASTER-SPEC; (c) a caveat that cites `SRS.md §FR-9`, a heading that does **not** exist (dangling).
- The **claude-mem plugin is NOT present** in the session.
- Pre-injected user follow-ups: accept the surfaced pointers as proposed.

**Trigger:** target subagent user message: `close VS-3.2.1`

**Expected behavior:**
- At §9.4, for candidate (a) the skill judges it restates `ADR-0007` and surfaces a **pointer** (`ADR-0007`) instead of harvesting the prose, confirming resolution via `sd citations_check_adr "ADR-0007" "<product-adr-dir>" "<process-adr-dir>"` (returns 0).
- For (b), the cited `MASTER-SPEC.md §5.2` resolves — `sd citations_check_anchor "<…>/MASTER-SPEC.md" "5.2"` returns 0 — accepted as a pointer-bearing entry without a flag.
- For (c), `sd citations_check_anchor "<…>/SRS.md" "FR-9"` returns non-zero → the skill **flags the dangling pointer** to the user rather than silently writing it.
- Because claude-mem is absent, the skill authors **no** `claude-mem:` pointer.

**Assertion (judge subagent verifies):**
- Tool-call log shows `sd citations_check_adr` invoked for the ADR-restating candidate, and that candidate is surfaced as an `ADR-0007` pointer — NOT the multi-line prose (judge confirms the harvested form is the pointer, not the restated paragraph).
- `sd citations_check_anchor` invoked for both §-anchor candidates; the dangling `SRS.md §FR-9` is surfaced as a flagged/unresolved pointer while the resolving `MASTER-SPEC.md §5.2` is not flagged.
- No `claude-mem:` pointer appears anywhere in the surfaced candidates or written files (claude-mem absent).
- FAIL if the ADR-restating prose is harvested verbatim instead of as a pointer, if the dangling anchor is written without a flag, or if a `claude-mem:` pointer is authored when claude-mem is absent.
