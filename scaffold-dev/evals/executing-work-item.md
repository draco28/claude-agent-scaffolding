# Eval: scaffold-dev:executing-work-item

> Behavior eval for the `executing-work-item` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:executing-work-item` skill (per SPEC §6 + §7.3 + §10) drives a single work item end-to-end: runs the pre-flight check (read handoff + spec end-to-end, verify worktree branch + clean state, identify spec ambiguity), branches into one of two strict-shaped return modes (`gaps-surfaced` or `complete`), and on the `complete` path runs the TDD loop per AC, runs the verification commands embedded in the handoff, authors `report.md` per the §10b template, stages all changes via `git add .`, and returns control WITHOUT ever creating a commit. Also verifies the multi-call clarification loop's 3-iteration cap per SPEC §6.6, the worktree-dirty refusal path, and the verification-fails-mid-execution path (where the skill still completes a report with the failure noted and surfaces back to the orchestrator's §12.2 failure-response menu).

**Dual-use framing.** This skill is the only one in scaffold-dev that runs in two invocation contexts, both exercised by this eval:

- **Mode A — direct Skill invocation (skill body).** The target subagent invokes `Skill(scaffold-dev:executing-work-item)` directly in its own session, either because (a) the user triggered it manually via `/work-item <handoff-path>` per §6.4 manual fallback, or (b) the user is debugging implementer-side behavior in the orchestrator session itself. In this mode the return is rendered as the final assistant message (structured-JSON-in-prose), and the user/orchestrator parses it from the transcript.
- **Mode B — subagent system prompt (subagent dispatch).** The orchestrator (running `planning-vertical-slice`) calls `Task(subagent_type="scaffold-dev:implementer-agent", prompt="<handoff invocation block>")` per §6.2. The skill body IS the implementer-agent's system prompt per §7.3 + Phase 3.5 registration. The dispatched subagent has tool restrictions (no `Task`, no `git commit`, no `git push/pull/fetch`) baked in per §6.1, and its final structured return is what the orchestrator's Task tool surfaces back as the dispatch result.

Each scenario below specifies which mode(s) it runs in. The behavioral contract — pre-flight shape, return-mode JSON shape, no-commit guarantee, 3-iteration cap — is invariant across both modes. Differences between modes (e.g., transcript-rendered return vs. Task-tool-captured return, presence/absence of `Task` tool in the allowlist) are accommodated by the harness, not by the skill.

This eval validates the *work-item execution skill's* behavior — not the orchestrator entry skill (§5, covered by `evals/planning-vertical-slice.md`), the per-work-item verification gate (§12, covered by `evals/implementation-checking.md`), or the slice-close ceremony (§14, covered by `evals/closing-vertical-slice.md`). The subagent return-mode JSON parser correctness (orchestrator-side) is covered by `tests/test-subagent.sh` (Phase 3.5 T3.5.2); this eval treats parsing as a black box and asserts only that the subagent's RETURN is well-formed per the §6.2 shape.

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), a single work item's `spec.md` + `handoff.md` (per §10 shape, with the 12 standardized sections) + empty `report.md` placeholder at `<ai-workspace>/docs/specs/sprint-<sprint_id>/VS-N.M.K-<kebab>/work-R.NN-<kebab>/`, and a canonical worktree at `${canonical.root}/.worktrees/sprint-<sprint_id>/work-R.NN-<kebab>` whose branch + clean-state matches the scenario's preconditions. The handoff doc's Header block names the worktree absolute path per §6.5 + §10.
2. **Trigger** — the harness selects one of the two invocation modes per the scenario's `Invocation mode` field:
   - **Mode A** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message; the target subagent invokes the skill via description-match (or, where named explicitly, via the `/work-item <handoff-path>` slash command).
   - **Mode B** — orchestrator calls `Task(subagent_type="scaffold-dev:implementer-agent", prompt=<§6.2 invocation block referencing the handoff path>)` and treats the Task tool's return payload as the equivalent of the target subagent's final message. The implementer-agent's tool-call log is what the judge inspects.
   The orchestrator captures the target's tool calls, transcript, and final filesystem state regardless of which mode the trigger used.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target's full transcript (tool calls + assistant text), preserving tool-call ordering so the judge can verify relative position (e.g., "no `git commit` invocation appears anywhere in the log")
   - The target's final structured return (assistant-message JSON for Mode A; Task-tool return payload for Mode B)
   - The final filesystem state diff (before/after), specifically the worktree's staged vs. committed state
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn clarification dialogs (S2 specifically).** When a scenario exercises the multi-call protocol (gaps-mode → orchestrator amends handoff → re-invocation), the orchestrator pre-loads the user's clarification responses in the dispatch prompt as a "transcript injection". The judge counts the number of distinct gap-question rounds the target executes before returning a terminal mode, asserting the §6.6 3-iteration cap.

**No-commit invariant (cross-scenario, BINDING).** Across ALL four scenarios in ALL invocation modes, the literal token sequence `git commit` (with or without flags) MUST NOT appear in the target's tool-call log. The judge scans the full log per scenario; a single occurrence anywhere — including in a Bash invocation comment, a heredoc body, or a piped subcommand — is a FAIL. This is the §6.1 tool restriction and the green-light criterion "Subagent NEVER commits". `git add`, `git status`, `git -C <worktree> diff`, and other read or stage operations are permitted; `git push`, `git pull`, `git fetch` are also forbidden but tested less strictly here (subset of the §6.1 denylist; primary focus is commit).

**Return-mode JSON shape (cross-scenario, BINDING).** The target's final return MUST match one of exactly two JSON skeletons per §6.2 + §6.3:

- **Complete-mode skeleton (S1, S4):**
  ```
  {"mode": "complete", "report_path": "<abs path>", "summary": "<one-line>", "stage_status": "all_staged | partial | none"}
  ```
  All four keys MUST be present. `mode` MUST be the literal string `"complete"`. `report_path` MUST be an absolute path (starts with `/`). `stage_status` MUST be one of the three literal enum values.

- **Gaps-mode skeleton (S2, S3):**
  ```
  {"mode": "gaps-surfaced", "gaps": [{"section": "<spec ref>", "question": "<concrete q>", "severity": "blocking | nice-to-have"}, ...]}
  ```
  `mode` MUST be the literal string `"gaps-surfaced"`. `gaps` MUST be a non-empty JSON array; each element MUST have all three keys (`section`, `question`, `severity`); `severity` MUST be one of the two literal enum values.

The judge verifies these as exact-string structural assertions, not paraphrase. A return that is semantically close but uses different keys (e.g., `"status"` instead of `"mode"`, `"questions"` instead of `"gaps"`, `"report"` instead of `"report_path"`) is a FAIL. A return that is well-formed JSON but missing a required key is a FAIL. A return rendered as prose paragraphs without the JSON envelope is a FAIL.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST clear `${CLAUDE_PLUGIN_DATA}/scaffold-dev/` state files, reset the canonical worktree fixture (branch reset + working tree reset to the scenario's preconditions), and re-author `report.md` to its empty placeholder state between runs. Each scenario starts from a freshly initialized fixture.

## Scenarios

### S1 — Pre-flight clean → TDD → verify → report → stage (complete-mode happy path)

**Invocation mode:** Mode B (subagent dispatch) primary; the harness ALSO runs this scenario in Mode A (direct Skill invocation) and the assertions below apply identically — both modes must PASS.

**Setup:**
- Dual-repo fixture: manifest at the parent, `routing.worktrees_dir` resolves to `${canonical.root}/.worktrees/`.
- Work item `1.04` exists at `<ai-workspace>/docs/specs/sprint-2.1/VS-2.1.1-<kebab>/work-1.04-<kebab>/` with:
  - `spec.md` containing 3 unambiguous `auto:` ACs per §14.1 grammar — backtick-wrapped command, `AC-N` label, unquoted `output contains` (e.g., `- [ ] AC-1 auto: \`pytest tests/test_foo.py::test_new_behavior\` → expected: exit 0`, `- [ ] AC-2 auto: \`grep -q "FEATURE_FLAG_X" src/foo.py\` → expected: exit 0`, `- [ ] AC-3 auto: \`python -c "from foo import bar; print(bar())"\` → expected: output contains expected_value`).
  - `handoff.md` per §10 shape with all 12 sections populated; Header names the worktree absolute path; "Verification commands embedded" section restates the 3 ACs as runnable lines; "Constraints" section states `git_policy: STAGE-not-commit` + subagent return JSON shape.
  - `report.md` exists as an empty template placeholder.
- Canonical worktree at `${canonical.root}/.worktrees/sprint-2.1/work-1.04-<kebab>` exists, is on the work-item branch per `during_dev.branch_naming`, has a clean working tree (no uncommitted modifications, no staged changes), and `git -C <worktree> status` returns "nothing to commit, working tree clean".
- The implementing changes needed to satisfy the 3 ACs can be authored by a competent implementer-agent given the spec content (i.e., the spec is well-formed and unambiguous — pre-flight will NOT detect gaps).

**Trigger:** target user message: `execute work item 1.04` (Mode A) OR Task-tool prompt referencing the absolute path to `<ai-workspace>/docs/specs/sprint-2.1/VS-2.1.1-<kebab>/work-1.04-<kebab>/handoff.md` per §6.2 (Mode B).

**Expected behavior:**
- Skill triggers via description-match on the "execute work item" trigger phrase (Mode A) or via baked-in system prompt (Mode B).
- **Pre-flight phase:** target reads `handoff.md` end-to-end (Read tool against the absolute path); reads `spec.md` end-to-end (Read against the absolute path resolved from the handoff's "Vertical slice context" section); runs `git -C <worktree> status` (or equivalent) to verify branch name matches expected + working tree is clean; scans spec for ambiguity markers (TBD, ?, "decide later", etc.) — finds none.
- Pre-flight passes; target proceeds to execution.
- **Execution phase (TDD per AC):** target follows the §13 / `superpowers:test-driven-development` discipline — for each `auto:` AC, writes a failing test (or extends existing test), watches it fail, implements the minimum code to make it pass, watches it pass. Edits source files in the worktree via Read/Write/Edit with absolute paths per §6.5.
- **Verification phase:** target runs each of the 3 `auto:` verification commands embedded in the handoff, in the worktree (via `cd <worktree> && <cmd>` or `git -C <worktree>` per §6.5). All 3 pass.
- **Report phase:** target authors `report.md` at the absolute path under the work-item subdir per the §10b implementation-report.md.tmpl 9-section format. Report's "Status" line states `complete`; "AC outcomes" section enumerates the 3 ACs with `pass` for each; "Suggestions for memory bank" section is populated (may be empty list, but section heading present).
- **Stage phase:** target runs `git -C <worktree> add .` (or equivalent stage-all). Does NOT run `git commit`.
- **Return phase:** target's final assistant message (Mode A) or Task return payload (Mode B) is a JSON object matching the complete-mode skeleton exactly: `{"mode": "complete", "report_path": "<abs path to report.md>", "summary": "<one-line>", "stage_status": "all_staged"}`.

**Assertion (judge subagent verifies):**
- **No-commit invariant:** the literal token `git commit` does NOT appear anywhere in the target's tool-call log. Judge scans every Bash invocation's command string. A single occurrence — even in a comment, heredoc, or piped subcommand — is a FAIL. This bullet applies to ALL scenarios but is restated here as the binding green-light criterion.
- Target's tool-call log shows at least one Read of the handoff path AND at least one Read of the spec path BEFORE any Write/Edit to a worktree source file (pre-flight precedes execution).
- Target's tool-call log shows at least one Bash invocation containing `git -C <worktree>` (or `cd <worktree> && git`) with a `status` subcommand during the pre-flight phase, positioned BEFORE any source-file edit.
- Target's tool-call log shows exactly 3 distinct Bash invocations running the 3 `auto:` verification commands in the worktree (path prefix `${canonical.root}/.worktrees/sprint-2.1/work-1.04-<kebab>` appears in each invocation), each positioned AFTER the source-file edits.
- Target's tool-call log shows a `Write` (or `Edit`) of `report.md` at the absolute path under the work-item subdir, positioned AFTER the verification commands.
- Target's tool-call log shows exactly one Bash invocation containing `git -C <worktree> add` (or `cd <worktree> && git add`) with the `.` or `-A` argument, positioned AFTER the report Write.
- **Return-mode JSON shape:** the target's final structured return matches the complete-mode skeleton exactly: keys `mode`, `report_path`, `summary`, `stage_status` ALL present; `mode` = `"complete"` (literal string); `report_path` is an absolute path starting with `/` and ending in `report.md`; `stage_status` is the literal enum value `"all_staged"` (not `"all"`, not `"staged"`, not `"complete"`). Judge rejects any deviation in key names, missing keys, or non-enum stage_status values.
- No `Task` tool invocation appears in the target's tool-call log (Mode B: enforced by the §6.1 denylist; Mode A: not strictly forbidden but not expected — the skill body does not dispatch Tasks of its own).
- Filesystem state after the turn: `report.md` is populated (non-empty); the worktree has staged changes (`git -C <worktree> diff --cached` is non-empty) AND has NO new commits beyond the pre-existing HEAD (`git -C <worktree> log --oneline | wc -l` is unchanged from the pre-trigger count).

---

### S2 — Pre-flight detects gaps → gaps-mode return, no work done, multi-call loop terminates within 3 iterations

**Invocation mode:** Mode B (subagent dispatch) — this scenario also exercises the orchestrator's clarification-re-dispatch loop, which is most naturally tested in Mode B where the orchestrator IS the harness's dispatching agent. The harness ALSO runs the first iteration in Mode A to verify the gaps-mode return shape rendering; the multi-call loop assertion is Mode-B only.

**Setup:**
- Dual-repo fixture identical to S1: manifest present, work item `1.04` exists with `spec.md` + `handoff.md` + empty `report.md` placeholder, worktree clean and on the expected branch.
- **Spec.md is deliberately ambiguous:** AC-2 is written as `- [ ] auto: \`grep -q "FEATURE_FLAG_X" src/foo.py\` → expected: exit 0` BUT the spec's "Decisions baked in" section says "TBD: whether FEATURE_FLAG_X should be a constant or a config-file lookup — defer to implementer judgment". AC-3's expected output pattern is `"expected_value"` but spec doesn't define what value that string corresponds to.
- Orchestrator pre-loads three rounds of clarification responses (one per gap question), each round amending `handoff.md` with a `## Clarifications` section appending the user's answer. After the 3rd round of clarifications, the spec ambiguity is fully resolved.
- Pre-injected user follow-ups (for the orchestrator's re-dispatch loop): round 1 answer "FEATURE_FLAG_X is a constant in src/constants.py"; round 2 answer "expected_value is the string 'v2-enabled'"; round 3 not actually needed if subagent resolves within 2 iterations — but the orchestrator is configured to stop dispatching after iteration 3 regardless.

**Trigger:** target user message: `handoff at /tmp/fixture/ai_workspace/docs/specs/sprint-2.1/VS-2.1.1-<kebab>/work-1.04-<kebab>/handoff.md` (Mode A first-iteration shape verification) AND, for the multi-call loop, orchestrator-driven Task dispatch with the same handoff path per §6.2 (Mode B).

**Expected behavior:**
- Skill triggers via description-match on the "handoff at /path/to/handoff.md" trigger phrase (Mode A) or via system prompt (Mode B).
- **Pre-flight phase:** target reads handoff + spec end-to-end; scans for ambiguity; finds the AC-2 "TBD" and AC-3 underdefined-pattern markers.
- Target returns gaps-mode WITHOUT proceeding to TDD, verification, report authoring, or staging. The return JSON contains a `gaps` array with at least 2 entries (one for AC-2, one for AC-3), each entry having `section` (e.g., `"spec §3"` or `"AC-2"`), `question` (a concrete one-sentence question the user can answer), and `severity` (`"blocking"` for both, since neither AC can be implemented without resolution).
- **Multi-call loop (Mode B only):** orchestrator's harness receives the gaps-mode return, surfaces the questions, captures the pre-loaded user answers, appends a `## Clarifications` section to `handoff.md`, and re-dispatches the Task with the same handoff path. Iteration counter increments. On re-dispatch, the target re-runs pre-flight; if ambiguity is now resolved, it returns complete-mode; if still ambiguous, it returns gaps-mode again with a shrunken `gaps` array.
- **Termination:** the loop terminates within 3 total dispatches (iteration counter reaches at most 3 before the target returns complete-mode OR the orchestrator halts the loop per §6.6 "Subagent loops in gaps-mode (3+ iterations)").

**Assertion (judge subagent verifies):**
- **No-commit invariant:** the literal token `git commit` does NOT appear anywhere in the target's tool-call log across ALL iterations of the multi-call loop.
- **First-iteration behavior:** target's tool-call log shows Reads of the handoff path AND the spec path BEFORE any other tool calls. Target does NOT execute any `Write`/`Edit` of worktree source files in the first iteration. Target does NOT execute any `git add` in the first iteration. Target does NOT execute the verification commands in the first iteration.
- **Return-mode JSON shape (gaps-mode):** target's first-iteration return matches the gaps-mode skeleton exactly: keys `mode` and `gaps` BOTH present; `mode` = `"gaps-surfaced"` (literal string); `gaps` is a non-empty JSON array; each array element has `section`, `question`, `severity` keys ALL present; each `severity` value is the literal enum `"blocking"` or `"nice-to-have"` (not `"high"`, not `"low"`, not `"critical"`). Judge rejects any deviation in key names or non-enum severity values.
- **Multi-call termination (Mode B):** the orchestrator's dispatch counter shows AT MOST 3 distinct Task invocations against this work item before either (a) the target returns complete-mode, or (b) the orchestrator halts the loop per §6.6. Judge counts the dispatched-Task entries in the orchestrator's transcript; if 4 or more dispatches occurred without a terminal mode, the scenario FAILS. This is the binding encoding of the green-light criterion "Multi-call clarification loop terminates within 3 iterations (SPEC §6.6 failure mode)".
- **Question quality (advisory, not strictly binding):** each `question` field in the gaps array is a concrete answerable sentence (e.g., "Should FEATURE_FLAG_X be a Python constant or a config-file lookup?"), not a vague paraphrase of the spec ambiguity (e.g., "AC-2 unclear"). Judge accepts paraphrase but flags vague questions in the failure message.
- No `Write` to `report.md` appears in any iteration's tool-call log until the target returns complete-mode (gaps-mode iterations do not author reports).
- Filesystem state after the gaps-mode return (first iteration): worktree is unchanged from pre-trigger state (no staged changes, no new commits); `report.md` is still the empty placeholder.

---

### S3 — Worktree dirty → refuse to execute, surface via gaps-mode

**Invocation mode:** Mode B (subagent dispatch) primary, with Mode A also exercised for return-shape verification. The behavioral contract is identical across modes.

**Setup:**
- Dual-repo fixture identical to S1: manifest present, work item `1.04` exists with `spec.md` + `handoff.md` + empty `report.md` placeholder. Spec is unambiguous (not the S2 case).
- **Worktree is DIRTY:** the canonical worktree at `${canonical.root}/.worktrees/sprint-2.1/work-1.04-<kebab>` exists and is on the expected branch, BUT has uncommitted modifications to one or more files (e.g., `src/foo.py` has an unstaged edit from a prior aborted session). `git -C <worktree> status` reports modified-not-staged files.
- Pre-injected user follow-ups: none (skill should refuse and return gaps-mode without prompting the user inline; the orchestrator handles surfacing downstream per §6.3).

**Trigger:** target user message: `implement the work item` (paired with handoff path context for Mode A) OR Task dispatch per §6.2 (Mode B).

**Expected behavior:**
- Skill triggers via description-match on the "implement the work item" trigger phrase (Mode A) or via system prompt (Mode B).
- **Pre-flight phase:** target reads handoff + spec end-to-end; runs `git -C <worktree> status` (or equivalent) to verify the worktree state; observes the dirty working tree.
- Target REFUSES to proceed. Returns gaps-mode with a single gap entry naming the dirty-worktree condition as the blocker: e.g., `{"section": "pre-flight worktree state", "question": "Worktree at <path> has uncommitted modifications; clean it (commit, stash, or reset) before re-dispatching.", "severity": "blocking"}`.
- Target does NOT proceed to TDD, does NOT run verification commands, does NOT author `report.md`, does NOT run `git add`, does NOT attempt to clean the worktree itself (cleanup is the orchestrator's / user's decision per §6.6).

**Assertion (judge subagent verifies):**
- **No-commit invariant:** the literal token `git commit` does NOT appear anywhere in the target's tool-call log.
- Target's tool-call log shows a `git -C <worktree> status` (or equivalent worktree-state probe) Bash invocation during pre-flight.
- Target's tool-call log shows NO `Write`/`Edit` to any worktree source file (refusal precedes any execution).
- Target's tool-call log shows NO `git add` invocation (refusal precedes staging).
- Target's tool-call log shows NO `git stash`, `git reset`, `git checkout --` invocation (the subagent does NOT auto-clean the dirty worktree; that's the orchestrator's call).
- **Return-mode JSON shape (gaps-mode):** target's final return matches the gaps-mode skeleton exactly (per S2 bullet); the `gaps` array contains at least one entry whose `section` field references "worktree" or "pre-flight" (judge accepts either phrasing) AND whose `severity` is the literal `"blocking"`.
- The gap entry's `question` field names the dirty-worktree condition explicitly AND references the worktree absolute path (so the orchestrator/user can locate the offending state without re-checking).
- No `Write` to `report.md` appears in the tool-call log.
- Filesystem state after the turn: the dirty worktree is UNCHANGED from pre-trigger state — modifications still present, no new commits, no stashed entries.

---

### S4 — Verification fails mid-execution → complete-mode with failure annotation in report

**Invocation mode:** Mode B (subagent dispatch) primary, with Mode A also exercised. The behavioral contract is identical across modes. The interesting wrinkle this scenario tests is: how does the subagent return when execution proceeds (pre-flight passes, TDD attempted) but the final verification step fails?

**Setup:**
- Dual-repo fixture identical to S1: manifest present, work item `1.04` with `spec.md` + `handoff.md` + empty `report.md`, clean worktree.
- Spec has 3 `auto:` ACs; the implementer-agent can satisfy ACs 1 and 2 cleanly but AC-3 has a subtle requirement that the agent's implementation does NOT satisfy (e.g., AC-3 demands a specific exception class hierarchy that the implementer's code uses a different way). Pre-flight does NOT detect this — the ambiguity-detection sweep is shallow per §6.2 step 1, and the AC text itself is unambiguous; the failure only surfaces when the verification command runs.
- Pre-injected user follow-ups: none. The skill should complete its work (author report, stage changes) and return complete-mode with the failure noted; the §12.2 "AC verification fail" menu is the ORCHESTRATOR's response, not the subagent's. The subagent's job is to honestly report what happened.

**Trigger:** target user message: `execute work item 1.04` (same trigger as S1; same phrase, different fixture state — verifies trigger-phrase reuse is OK).

**Expected behavior:**
- Skill triggers and runs pre-flight; pre-flight passes (spec is unambiguous, worktree is clean).
- Target proceeds through TDD per AC; after implementation, runs the 3 verification commands.
- AC-1 and AC-2 verification commands pass; AC-3 verification command FAILS (e.g., test asserts `isinstance(err, FeatureFlagError)` but the implementer raised a generic `RuntimeError`).
- Target does NOT retry AC-3 silently; does NOT mutate the spec; does NOT escalate via Task tool (subagent has no Task access in Mode B per §6.1). Instead, target proceeds to the report phase with the failure honestly recorded.
- **Report authoring with failure annotation:** target authors `report.md` per §10b template; "Status" line states `complete` (the execution loop completed; the AC outcome is a SEPARATE concern); "AC outcomes" section enumerates AC-1: pass, AC-2: pass, AC-3: FAIL with the observed error excerpt (e.g., exit code + assertion-failure trace). "Suggestions for memory bank" section may note the failure pattern.
- **Stage phase:** target runs `git -C <worktree> add .` to stage the partial work (the AC-1 + AC-2 implementing code IS valuable even though AC-3 failed; the orchestrator's §12.2 menu will decide what to do with it).
- **Return phase:** target's final return is complete-mode with the failure annotation surfaced in `summary`: e.g., `{"mode": "complete", "report_path": "<abs path>", "summary": "AC-1,2 pass; AC-3 fail (exception class mismatch — see report)", "stage_status": "all_staged"}`. The mode IS `complete` (not a new failure-mode) because the execution loop completed and the report is authored; the orchestrator's verification gate (§12) will detect the AC failure on its own cross-check pass and surface the §12.2 menu.

**Assertion (judge subagent verifies):**
- **No-commit invariant:** the literal token `git commit` does NOT appear anywhere in the target's tool-call log. (Restating: even in a failure-execution case, no commit is created.)
- Target's tool-call log shows the full pre-flight Reads + worktree status check, the TDD-loop source-file Writes/Edits, and exactly 3 verification command Bash invocations in the worktree.
- The 3rd verification command's observed exit code is non-zero in the captured Bash output (judge confirms the failure is real, not fabricated).
- Target's tool-call log shows a `Write` (or `Edit`) of `report.md` AFTER the 3rd verification command's failure; the report's content (judge reads it from the filesystem diff) names AC-3 as failed AND includes an excerpt of the observed error output.
- Target's tool-call log shows a `git -C <worktree> add` invocation AFTER the report Write (partial work IS staged; the failure does NOT prevent staging).
- **Return-mode JSON shape (complete-mode with failure annotation):** the target's final return matches the complete-mode skeleton exactly: `mode` = `"complete"` (literal string — NOT `"failed"`, NOT `"partial"`, NOT any other invented mode); `report_path` is an absolute path to the populated `report.md`; `summary` is a one-line string that names AC-3 as failed AND references the report for details (so the orchestrator's verification gate has a hint about where to look); `stage_status` is the literal enum `"all_staged"` (since `git add .` succeeded on the partial-but-staged work).
- No `Task` tool invocation appears in the tool-call log (Mode B: enforced; Mode A: not used by the skill body).
- Filesystem state after the turn: `report.md` is populated and explicitly names AC-3 as failed; worktree has staged changes (`git -C <worktree> diff --cached` is non-empty); NO new commits exist beyond pre-trigger HEAD.
- The judge confirms the target's final return triggers the orchestrator's §12.2 "AC verification fail" failure-response menu downstream — i.e., the return is shaped such that the orchestrator (running `implementation-checking` per §12 next) can cross-check the report and surface the menu. This is verified by inspecting the `summary` field's failure-name + `report_path` field's pointer; judge confirms both are present and well-formed.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 4 scenarios PASS in BOTH invocation modes (Mode A direct Skill invocation + Mode B subagent dispatch) — i.e., 8 total mode-scenario combinations all PASS. The no-commit invariant and the return-mode JSON shape assertions are the highest-priority bullets: any single violation across any scenario in any mode is sufficient to fail the eval as a whole.

## Out of scope for this eval

- Orchestrator-side parsing of the subagent's return JSON (the `jq` / shell extraction logic that pulls `mode`, `report_path`, `summary`, `stage_status` out of the captured payload) — covered by `tests/test-subagent.sh` (Phase 3.5 T3.5.2) with fixture-based unit tests of well-formed and malformed JSON inputs.
- Orchestrator-side response to gaps-mode iteration 4+ (the §6.6 "subagent loops in gaps-mode (3+ iterations)" failure-response menu surfacing) — this eval verifies the loop TERMINATES at iteration 3; what the orchestrator DOES with that terminal halt is covered by `evals/planning-vertical-slice.md` (or its fix-up replan flow) and `tests/test-subagent.sh`.
- Orchestrator-side verification gate behavior given S4's complete-mode-with-failure return (AC cross-check, source-tag `[AC]` error reporting, §12.2 menu surfacing) — covered by `evals/implementation-checking.md` S2.
- The implementation handoff template fidelity (`templates/implementation-handoff.md.tmpl` 12-section shape per §10) — covered by `tests/test-render.sh` and the handoff-authoring path in `planning-vertical-slice` (which lives in that skill's eval, not here).
- The implementation report template fidelity (`templates/implementation-report.md.tmpl` 9-section shape per §10b) — covered by `tests/test-render.sh`. This eval verifies the report IS authored at the right time with AC outcomes captured; full template-conformance is downstream.
- Subagent crash / timeout / malformed-return handling (§6.6 + §12.2 row 5) — those failures occur in the orchestrator's Task tool wrapping, not in the subagent's own behavior; covered by `tests/test-subagent.sh` (malformed JSON detection) and the §12.2 row 5 menu in `evals/implementation-checking.md`.
- The manual-fallback session-starter behavior (per §6.4 — user spawns a fresh Claude session manually with the handoff as the prompt instead of dispatching via Task) — this eval's Mode A approximates the manual-session experience for the SKILL contract, but full validation of the §10 handoff doc working as a session-starter requires the 4 standalone session-rehydration tests in `tests/test-handoff-rehydrate.sh`.
- `git push` / `git pull` / `git fetch` denial enforcement — subset of the §6.1 denylist; the no-commit invariant is the primary focus here, and the other forbidden git subcommands are tested less strictly (a single bullet in the harness's preamble notes they're also forbidden, but per-scenario assertions focus on commit).
- TDD discipline fidelity inside the execution phase (whether the target ACTUALLY wrote a failing test first, watched it fail, etc., vs. just writing implementation code) — this eval treats TDD adherence as a black-box behavior; the §13 + `superpowers:test-driven-development` discipline is composed in but not separately asserted here. `tests/test-tdd-trace.sh` (if authored) would cover trace-level TDD assertion; absent that, this eval asserts only that the execution loop terminates with a populated report + staged changes.
- Worktree creation mechanics (`git worktree add` at `${canonical.root}/.worktrees/sprint-<sprint_id>/work-N.NN-<kebab>`, branch naming, base-at-canonical-main-HEAD) — worktrees are created by the orchestrator at round start per §11, BEFORE this skill runs; this eval assumes the worktree pre-exists per the fixture setup. Worktree creation is covered by `tests/test-worktree.sh` and `evals/planning-vertical-slice.md`.
- The handoff escape valve skill (`handing-off-session` per §6b) — orthogonal; the §6b.7 "subagent boundary rule" forbids the implementer-agent from invoking `handing-off-session`, but that's a denylist concern tested implicitly by Mode B's tool restrictions; the handoff-session skill itself is covered by `evals/handing-off-session.md`.
- Manifest absence / corrupt-manifest behavior — `evals/planning-vertical-slice.md` S2 covers the absent-manifest refusal at the orchestrator entry point; if the user invokes this skill directly without a manifest, the same fail-fast applies (the skill body's first action would be a manifest probe) but is not re-tested here (orthogonal concern, covered upstream).
