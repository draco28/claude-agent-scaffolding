# Eval: scaffold-dev:writing-sprint-retrospective

> Behavior eval for the `writing-sprint-retrospective` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:writing-sprint-retrospective` skill (per SPEC §7.1 + §16b) aggregates all per-slice retrospectives under `<ai-workspace>/docs/specs/sprint-N/VS-*/retrospective.md` for a closed sprint, harvests cross-slice patterns + sprint-level memory-bank items, and authors `<ai-workspace>/docs/specs/sprint-N/sprint-retrospective.md` per the §16b 6-section format (sprint metadata · sprint goal vs delivered · per-slice rollup · cross-slice patterns · memory bank impact totals · lessons for next sprint · reference index — note: §16b lists 6 sections in the rollup table; the 7th "reference index" item is appended in practice per the slice-retrospective parallel, but for THIS eval the 6-section invariant from §16b's text is binding). Also verifies that the skill refuses to author a sprint retro mid-sprint (when not all sprint-N slices have closed), and that it composes via `templates/sprint-retrospective.md.tmpl` (per §10b).

This eval validates the *sprint-retrospective skill's* behavior — not the per-slice retrospective authoring (that's `closing-vertical-slice`'s §14.4 + §16b 7-section format, covered by `evals/closing-vertical-slice.md` S1 implicitly) and not the broader sprint-close ceremony (cleanup of sprint-scoped handoffs, carry-forward handoff handling — covered separately per §6b.6 deferral).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), `<ai-workspace>/docs/specs/sprint-N/` populated with the scenario's slice directories + retrospective files, `templates/sprint-retrospective.md.tmpl` present in the plugin, and `<ai-workspace>/ROADMAP.md` with the sprint-N goal block referenced from manifest routing.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session at sprint-close time. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after), specifically the new `sprint-retrospective.md` file + its contents
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input (e.g., user confirmation of cross-slice pattern phrasing, accept/edit/reject for sprint-level memory-bank items), the orchestrator pre-loads the user's follow-up responses in the dispatch prompt rather than waiting for interactive input.

**6-section invariant (cross-scenario, BINDING).** Every sprint-retrospective file written by the target MUST contain the six §16b sections as markdown headings, in order: (1) "Sprint metadata", (2) "Sprint goal vs delivered", (3) "Per-slice rollup", (4) "Cross-slice patterns", (5) "Memory bank impact totals", (6) "Lessons for next sprint". The judge scans the written file for each section name as a `##` or `###` level markdown heading (level-agnostic); a missing or renamed section is a FAIL. Judge accepts case-insensitive variants and minor pluralization (e.g., "Lesson for next sprint" / "Lessons for next sprint"); rejects substitutes that drop a section or merge two sections under one heading. A 7th "Reference index" appended section is acceptable but not required.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST reset `<ai-workspace>/docs/specs/sprint-N/` content between runs (re-seed the slice retrospectives, remove any prior `sprint-retrospective.md`). Each scenario starts from a freshly initialized fixture.

## Scenarios

### S1 — Happy path: all sprint-3 slices closed, aggregate 3 slice retros into sprint retro

**Setup:**
- Dual-repo fixture: manifest at the parent, `routing.specs_dir` resolves to `<ai-workspace>/docs/specs/`.
- `<ai-workspace>/docs/specs/sprint-3/` contains 3 closed slice directories:
  - `VS-3.1-user-auth/retrospective.md` (7-section slice retro per §16b; populated content)
  - `VS-3.2-redis-cache/retrospective.md` (likewise)
  - `VS-3.3-feature-flags/retrospective.md` (likewise)
- Each slice retro has a populated "Memory bank harvest" section naming the specific memory-bank files it modified (e.g., VS-3.1 added 2 items to `03-code-patterns.md`; VS-3.2 added 1 item to `09-known-issues.md` and 1 to `03-code-patterns.md`; VS-3.3 added 1 to `04-data-models.md`).
- Each slice retro has a populated "Lessons learned" section with 2-3 bullets.
- `<ai-workspace>/ROADMAP.md` contains the sprint-3 goal block ("Sprint 3 goal: ship user auth + caching + feature-flags MVP") at a manifest-routed path.
- `templates/sprint-retrospective.md.tmpl` is present.
- No prior `sprint-retrospective.md` exists at `<ai-workspace>/docs/specs/sprint-3/sprint-retrospective.md`.
- Pre-injected user follow-ups: (a) user confirms the auto-derived cross-slice patterns ("all 3 slices touched 03-code-patterns.md → opportunity to consolidate"); (b) "accept" decisions for the surfaced sprint-level lessons.

**Trigger:** target subagent user message: `close sprint 3`

**Expected behavior:**
- Skill triggers via description-match on the "close sprint N" trigger phrase (per SPEC §7.1 triggers list).
- Skill discovers the manifest via `lib/manifest.sh` walk-up helpers and resolves `routing.specs_dir` to `<ai-workspace>/docs/specs/`.
- Skill enumerates slice directories under `sprint-3/` matching the `VS-3.*` pattern; finds 3.
- Skill Reads each slice's `retrospective.md`; confirms each one has status indicating slice-closed.
- Skill extracts cross-slice patterns from the aggregate (e.g., shared memory-bank targets, common deviations, repeated lessons).
- Skill renders `templates/sprint-retrospective.md.tmpl` with the aggregated content + the 6 §16b sections populated:
  - **Sprint metadata** — sprint ID, dates, slice IDs included
  - **Sprint goal vs delivered** — pulls the goal from ROADMAP.md, summarizes actual delivery
  - **Per-slice rollup** — one row/block per slice with status + key outcome
  - **Cross-slice patterns** — patterns the user confirmed
  - **Memory bank impact totals** — count of items added per memory-bank file across all 3 slices
  - **Lessons for next sprint** — aggregated lessons + user-edited additions
- Skill writes the file at `<ai-workspace>/docs/specs/sprint-3/sprint-retrospective.md`.
- Skill emits a final assistant message naming the new file's absolute path.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows at least one `lib/manifest.sh` helper invocation; no raw `jq` inline reads of `.routing.specs_dir`.
- Target subagent's tool-call log contains Reads of ALL 3 slice retrospectives: `VS-3.1-user-auth/retrospective.md`, `VS-3.2-redis-cache/retrospective.md`, `VS-3.3-feature-flags/retrospective.md`. Judge counts exactly 3 distinct slice-retro Reads; if any is missing, the aggregation is incomplete.
- Target subagent's tool-call log contains a Read of `<ai-workspace>/ROADMAP.md` (to pull the sprint goal) BEFORE the Write of `sprint-retrospective.md`.
- Target subagent's tool-call log contains a `Write` of `<ai-workspace>/docs/specs/sprint-3/sprint-retrospective.md` (NOT under a slice subdirectory; NOT in `<canonical>/`).
- The written file contains all 6 §16b section headings in order per the cross-scenario 6-section invariant.
- The "Per-slice rollup" section names all 3 slices explicitly (judge confirms: `VS-3.1`, `VS-3.2`, `VS-3.3` all appear as identifiers).
- The "Memory bank impact totals" section aggregates the counts across slices — judge confirms it names at least 2 memory-bank files (e.g., `03-code-patterns.md` with a count of 3 items aggregated from VS-3.1 + VS-3.2 contributions) AND the counts are NUMERIC (NOT "several" or "many").
- The "Sprint goal vs delivered" section quotes or paraphrases the ROADMAP sprint-3 goal AND contrasts it against delivered slice outcomes.
- Target subagent's final assistant message names the absolute path of the written file.
- No edits to any slice's `retrospective.md` appear (the skill READS slice retros; never mutates them).

---

### S2 — Mid-sprint refusal (not all sprint-3 slices closed, skill bails with slice-close suggestion)

**Setup:**
- Dual-repo fixture identical to S1: manifest present, ROADMAP with sprint-3 goal, template present.
- `<ai-workspace>/docs/specs/sprint-3/` contains 3 slice directories BUT only 2 have `retrospective.md` (slice-closed):
  - `VS-3.1-user-auth/retrospective.md` (present, closed)
  - `VS-3.2-redis-cache/retrospective.md` (present, closed)
  - `VS-3.3-feature-flags/` (slice directory present; spec files + work-item subdirs present; NO `retrospective.md` — slice is still mid-execution, work item 3.3.02 is in flight)
- Pre-injected user follow-ups: none (skill should refuse before reaching aggregation).

**Trigger:** target subagent user message: `write sprint retro`

**Expected behavior:**
- Skill triggers via description-match on the "write sprint retro" trigger phrase.
- Skill discovers manifest; resolves specs dir.
- Skill enumerates slice directories under `sprint-3/`; finds 3.
- Skill checks each slice for a closed-state signal (presence of `retrospective.md` per §14.4 — the closing-vertical-slice skill writes this file as part of slice close).
- Skill detects VS-3.3 is NOT closed (no `retrospective.md` present).
- Skill **refuses to proceed** and surfaces a message naming: (a) the un-closed slice (`VS-3.3` or the kebab name), (b) a remediation hint pointing at `closing-vertical-slice` (e.g., "close VS-3.3 first via `/close-slice VS-3.3` or by triggering the closing-vertical-slice skill") — NOT a suggestion to skip the un-closed slice and aggregate the other two.
- Skill does NOT write any `sprint-retrospective.md` file, does NOT mutate any slice retro, does NOT prompt for aggregation content.

**Assertion (judge subagent verifies):**
- Target subagent's final assistant message names `VS-3.3` explicitly as the un-closed slice (quoted or otherwise identifiable). Judge rejects: vague "a slice is still open", or refusal that omits the slice ID.
- The message includes the remediation hint with either: (a) a slash-command token referencing slice close (e.g., `/close-slice VS-3.3`), OR (b) an explicit naming of the `closing-vertical-slice` skill as the prerequisite. Judge accepts either phrasing; rejects messages that suggest aggregating the 2 closed slices and skipping VS-3.3.
- Target subagent's tool-call log contains a directory listing of `<ai-workspace>/docs/specs/sprint-3/` AND existence checks for `retrospective.md` in each slice subdirectory.
- No `Write` of `sprint-retrospective.md` appears in the tool-call log.
- No `Read` of any slice's `retrospective.md` proceeds past the existence-check step (the skill bails before aggregation; it MAY have Read the 2 present ones for status confirmation but MUST NOT have begun composing the sprint retro).

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true AND the cross-scenario 6-section invariant is satisfied on every file written (S1). If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>`.

The full eval is GREEN when both scenarios PASS.

## Out of scope for this eval

- Sprint-retrospective template fidelity (the exact placeholders in `templates/sprint-retrospective.md.tmpl`, the formatting of each section's blocks) — covered by `tests/test-render.sh`. This eval asserts the 6 §16b section headings appear with substantive content; full template-conformance is downstream.
- Sprint-close cleanup of sprint-scoped handoffs (§6b.6 lifecycle — wiping `sprint-N-*.md` handoffs except the carry-forward) — sprint-close cleanup ownership is resolved during PLAN (extension of `closing-vertical-slice` at the final slice OR a separate `closing-sprint` skill); whichever owns it gets its own eval. This eval focuses on the retrospective authoring step only.
- Carry-forward handoff handling (composing `sprint-N-to-N+1-handoff-XXXX.md` at sprint close) — covered by `evals/handing-off-session.md` S1.
- Cross-sprint pattern detection (patterns that span multiple sprints — e.g., "sprint 2 and sprint 3 both had auth-related deferrals") — deferred to v0.2; v0.1 aggregates only within the current sprint.
- Memory-bank harvest at sprint level (promote sprint-aggregate observations to memory-bank files with `source: sprint-retro` provenance trailers) — the per-slice harvest at §15.2 covers slice-scope items; sprint-level promotion is documented as an open question for v0.1 and may surface during PLAN. This eval asserts the retro's "Memory bank impact totals" section aggregates the counts but does NOT re-promote items.
- Sprint goal mismatch handling (the ROADMAP-stated sprint goal differs significantly from what was actually delivered — does the skill flag it as a deviation requiring user attention?) — deferred to v0.2.
- Manifest absence / corrupt-manifest behavior — `evals/planning-vertical-slice.md` S2 covers the absent-manifest refusal at the orchestrator entry point; if the user invokes this skill without a manifest, the same fail-fast applies but is not re-tested here.
- The `/close-sprint N` slash-command wrapper vs description-match triggering — both paths reach the same skill body; S1 + S2 exercise description-match. The slash-command wrapper (if added in PLAN) has identical body behavior.
