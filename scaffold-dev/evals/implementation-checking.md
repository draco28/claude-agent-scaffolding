# Eval: scaffold-dev:implementation-checking

> Behavior eval for the `implementation-checking` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:implementation-checking` skill (per SPEC §12) acts as the per-work-item verification gate between implementer-subagent return and slice-close: parses each `auto:` acceptance criterion per the §14.1 grammar, runs the verification command in the work item's worktree, halts on the first AC failure, cross-checks the implementer's `report.md` against the AC outcome, consumes scaffold-onboard's R2 machine-checkable rules via the `sf_rules_*` API (per §16.4) and surfaces violations, and on any failure presents the §12.2 failure-response menu with source-tagged error reporting (`[AC]`, `[report cross-check]`, `[rule]`). Falls back to AC-only verification when R2 rules are absent (per §12.1 + Q2 settlement).

This eval validates the *per-work-item verification gate skill's* behavior — not the orchestrator entry skill (§5, covered by `evals/planning-vertical-slice.md`), the implementer-agent subagent (§6, covered by `evals/executing-work-item.md`), or the slice-close ceremony (§14, covered by `evals/closing-vertical-slice.md`).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), published roadmap state with an exact `VS-3.2.1` record whose `sprint_id` is `3.2`, active cursor state naming `active_slice=VS-3.2.1`, a single work item's spec.md + handoff.md + report.md at `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/work-1.NN-<kebab>/`, a canonical worktree at `${canonical.root}/.worktrees/sprint-3.2/work-1.NN-<kebab>` containing the implementer-subagent's staged-but-not-committed changes, and the scenario-specific R2 rules state in the memory bank's `03-code-patterns.md` (present-and-clean, present-and-violated, or absent).
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session resuming after implementer-subagent return. The target subagent has access to the skill via its description-match (no slash command is invoked except where `/impl-check` is named explicitly). The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**No state mutation.** The skill under test is read-only with respect to repo artifacts (it inspects the worktree, runs verification commands, reads `report.md`, reads rules) and write-only with respect to its own surface output (the menu + source-tagged error report rendered into the conversation). The skill MUST NOT commit, merge, edit `report.md`, or auto-fix violations — those decisions belong to the user via the §12.2 menu.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST clear `${CLAUDE_PLUGIN_DATA}/scaffold-dev/` state files and rebuild the canonical worktree fixture (staged changes + worktree branch) between runs. Each scenario starts from a freshly initialized fixture.

## Scenarios

### S1 — Happy path AC pass (rules absent → AC-only path, all ACs green)

**Setup:**
- Dual-repo fixture: manifest at the parent, `routing.worktrees_dir` resolves to `${canonical.root}/.worktrees/`.
- Roadmap/cursor fixture: `<ai-workspace>/.workspace/project-roadmap.json` contains `{"id":"VS-3.2.1","sprint_id":"3.2","name":"<kebab>",...}` and scaffold-dev's active cursor state names `active_slice=VS-3.2.1`.
- Work item `1.01` exists at `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/work-1.01-<kebab>/` with a `spec.md` containing 3 `auto:` ACs per §14.1 grammar: e.g., `- [ ] auto: \`pytest tests/test_foo.py\` → expected: exit 0`, `- [ ] auto: \`grep -q "TARGET" src/foo.py\` → expected: exit 0`, `- [ ] auto: \`python -c "import foo; print(foo.VERSION)"\` → expected: output contains "1.0"`.
- `report.md` is authored per template, with a "Status" line stating `complete` and an "AC outcomes" section claiming all 3 ACs passed.
- Canonical worktree at `${canonical.root}/.worktrees/sprint-3.2/work-1.01-<kebab>` contains staged-but-uncommitted changes that DO satisfy all 3 ACs (i.e., running each verification command in the worktree yields the expected exit/output).
- `<ai-workspace>/.claude/memory-bank/03-code-patterns.md` exists but contains NO `<!-- mcrule:start ... -->` blocks (R2 rules absent — fallback path).
- Pre-injected user follow-ups: none required (happy path; skill should report green and surface a "ready for commit" handoff without prompting).

**Trigger:** target subagent user message: `verify work item 1.01`

**Expected behavior:**
- Skill triggers via description-match on the "verify work item" trigger phrase (per SPEC §7.1 + §12 triggers list).
- Skill resolves the work item's worktree path via the manifest (`${canonical.root}/.worktrees/sprint-3.2/work-1.01-<kebab>`) and reads the spec.md to extract the `auto:` AC list per §14.1 grammar (each line parsed into a `(command, expectation)` tuple).
- Skill probes `<ai-workspace>/.claude/memory-bank/03-code-patterns.md` for R2 mcrule blocks; finds none; takes the AC-only fallback path per §12.1 (no `sf_rules_*` invocation needed beyond the absence-detection probe).
- Skill executes each `auto:` command sequentially in the worktree (via `cd <abs worktree> && <cmd>` or `git -C` for git ops, per §6.5), checks exit code against `expected: exit 0` or matches output against `expected: output contains "<pattern>"` per §14.1 grammar.
- All 3 ACs pass.
- Skill reads `report.md` and cross-checks the "AC outcomes" claims against its own freshly-measured outcomes; the report's claims match observed reality.
- Skill emits a green verification summary and a handoff line indicating the work item is ready for the orchestrator's commit + merge step (per §13 step 4).
- Skill does NOT commit, does NOT merge, does NOT edit `report.md`.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows exactly 3 distinct Bash invocations running the 3 `auto:` commands, each scoped to the worktree (path prefix `${canonical.root}/.worktrees/sprint-3.2/work-1.01-<kebab>` appears in the invocation, e.g., via `cd <path>` or `git -C <path>`).
- Target subagent's tool-call log shows at least one Read of `<ai-workspace>/.claude/memory-bank/03-code-patterns.md` (the rules-absence probe).
- Target subagent's tool-call log shows at least one Read of `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/work-1.01-<kebab>/report.md` (the cross-check read).
- Target subagent's assistant transcript contains a green verification summary naming all 3 ACs as passed (e.g., "AC-1: pass · AC-2: pass · AC-3: pass" or equivalent enumerated list).
- Target subagent's final assistant message indicates the work item is ready for commit/merge (e.g., "work item 1.01 verified; ready for commit + merge" or equivalent) — control returns to the user/orchestrator for the next step.
- No `git commit`, `git merge`, `git push`, or `Write`/`Edit` to `report.md` appears in the transcript (verification gate is read-only).
- No §12.2 menu is surfaced (happy path; menu is failure-only).
- No `Task` tool invocation appears in the transcript (re-spawning the implementer subagent is a §12.2 menu option, not a happy-path action).

---

### S2 — AC fail (first AC fails → halt, surface failure-response menu)

**Setup:**
- Dual-repo fixture identical to S1: manifest present, work item `1.01` with the same 3 `auto:` ACs in spec.md, R2 rules absent (so the failure is unambiguously AC-sourced, not rule-sourced).
- Canonical worktree contains staged changes where the **first** `auto:` AC FAILS (e.g., `pytest tests/test_foo.py` returns exit code 1 with a test-failure trace) while ACs 2 and 3 would pass if reached.
- `report.md` claims all 3 ACs passed (report is inaccurate; this is the AC-fail case, not the report-cross-check case — the gate must halt on the AC outcome BEFORE concluding the report is the problem).
- Pre-injected user follow-ups: none (skill should halt and surface the menu; user response is captured downstream).

**Trigger:** target subagent user message: `check round 1`

**Expected behavior:**
- Skill triggers via description-match on the "check round 1" trigger phrase.
- Skill enumerates the round's work items (in this fixture, just `1.01`) and iterates AC verification per item.
- Skill runs the first `auto:` command in the worktree; observes exit code 1 (AC-1 fails).
- Skill **halts immediately** — does NOT proceed to run AC-2 or AC-3 in the same work item (per the green-light criterion "Verification halts on first AC failure (does NOT continue silently)").
- Skill surfaces a source-tagged error report naming the failing AC, the command that failed, the observed exit/output, and the `[AC]` source tag (per the green-light criterion "Source-tags errors as `[AC]`, `[report cross-check]`, `[rule]`").
- Skill presents the §12.2 "AC verification fail" menu with all 3 options surfaced: (1) Re-spawn implementer subagent with fix-up handoff, (2) Accept partial-with-deferred, (3) Replan work item.
- Skill does NOT auto-select an option, does NOT mutate `handoff.md` or `report.md`, does NOT re-invoke the implementer subagent on its own — option selection is the user's decision.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows exactly ONE Bash invocation running an `auto:` command in the worktree — the second and third AC commands MUST NOT appear in the tool-call log (halt-on-first-failure is binding).
- Target subagent's assistant transcript contains a source-tagged error line beginning with or containing the literal token `[AC]` (e.g., `[AC] AC-1 failed: pytest exited 1`); judge accepts minor surrounding-phrase variation but rejects messages that omit the literal `[AC]` token or use a different bracket spelling.
- Target subagent's assistant transcript surfaces a menu with at least 3 numbered/bulleted options matching §12.2's "AC verification fail" row: option text MUST identify "re-spawn" or "fix-up" (option 1), "deferred" or "partial" (option 2), and "replan" (option 3) — judge accepts paraphrase but rejects a menu that collapses to fewer than 3 options (per the green-light criterion "Failure-response menu always surfaces 3+ options").
- The failing command's observed output (exit code and/or pytest trace excerpt) is included in the error report so the user can decide which menu option to pick without re-running the command themselves.
- No `Task` tool invocation appears in the transcript (option-1 re-spawn is a user-selected action, not auto-executed by the gate).
- No `git commit`, `git merge`, or write to `report.md` / `handoff.md` appears in the transcript.

---

### S3 — Project rule check fail (R2 rules present, banned-imports violation → halt, `[rule]` tag, menu)

**Setup:**
- Dual-repo fixture identical to S1, but `<ai-workspace>/.claude/memory-bank/03-code-patterns.md` contains a populated `## Machine-checkable rules` section with one `<!-- mcrule:start type=banned_imports -->` block per scaffold-onboard v0.2's R2 grammar (e.g., banning `import requests` in favor of `httpx`).
- Canonical worktree contains staged changes where all 3 `auto:` ACs would pass (and DO pass when run by the gate), BUT one of the modified files in the worktree contains a `import requests` line that violates the banned-imports rule.
- `report.md` claims all 3 ACs passed and does not mention any rule violation (implementer subagent did not catch the rule).
- Pre-injected user follow-ups: none.

**Trigger:** target subagent user message: `is this work item done`

**Expected behavior:**
- Skill triggers via description-match on the "is this work item done" trigger phrase.
- Skill runs the AC-only verification path first (all 3 ACs pass in the worktree).
- Skill invokes scaffold-onboard's rules API (function name matching `sf_rules_parse` or `sf_rules_filter` — the published v0.2 API surface; PLAN T3.3 may pin the exact entry point) to load the parsed R2 rules from `03-code-patterns.md` and evaluate them against the worktree's staged diff.
- The banned-imports rule fires on the offending file.
- Skill halts and surfaces a source-tagged error report naming the violated rule, the offending file + line, and the `[rule]` source tag.
- Skill presents the §12.2 "Project rule check fail" menu with all 3 options surfaced: (1) Re-spawn with rule context in fix-up handoff, (2) Accept-with-deferred TODO, (3) Replan if rule is fundamental.
- Skill does NOT auto-fix the import, does NOT mutate `handoff.md`, does NOT re-invoke the implementer subagent.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows at least one Bash invocation sourcing or calling into scaffold-onboard's `lib/rules.sh` (function name matching the `sf_rules_*` prefix family, e.g., `sf_rules_parse`, `sf_rules_filter`, or `sf_rules_validate_block`); no raw inline regex parsing of `mcrule:start` HTML sentinels appears (consumption goes through the published API per the green-light criterion "consumes scaffold-onboard's `sf_rules_*` output").
- Target subagent's assistant transcript contains a source-tagged error line containing the literal token `[rule]` (e.g., `[rule] banned-imports: src/foo.py:12 — \`import requests\` forbidden`); judge rejects messages that use a different bracket spelling or omit the rule name.
- Target subagent's assistant transcript surfaces a menu with at least 3 options matching §12.2's "Project rule check fail" row: option text MUST identify "re-spawn with rule context" (option 1), "deferred" or "TODO" (option 2), and "replan" (option 3).
- The error report names the specific rule type (e.g., `banned_imports`) and the offending file path within the worktree, so the user can locate the violation without re-running detection.
- The 3 `auto:` ACs are reported as passed BEFORE the rule violation is surfaced — the verification summary makes clear the failure source is the rule check, not an AC (so the user picks the right menu).
- No `Write`/`Edit` to any worktree source file appears in the transcript (no auto-fix).
- No `Task` tool invocation appears in the transcript.

---

### S4 — Rules absent (R2 not authored → AC-only fallback per §12.1 + Q2)

**Setup:**
- Dual-repo fixture identical to S1: manifest present, work item `1.01` with 3 `auto:` ACs.
- `<ai-workspace>/.claude/memory-bank/03-code-patterns.md` either does not exist OR exists with NO `<!-- mcrule:start ... -->` blocks under `## Machine-checkable rules` (the R2 section is empty per scaffold-onboard's v0.2 default seeding behavior).
- Canonical worktree contains staged changes where all 3 ACs pass AND any rule-style violation that WOULD exist (e.g., the same `import requests` line as S3) is present in the diff — but because no rule is authored, the violation is invisible to the gate.
- `report.md` claims all 3 ACs passed.
- Pre-injected user follow-ups: none.

**Trigger:** target subagent user message: `verify the implementation`

**Expected behavior:**
- Skill triggers via description-match on the "verify the implementation" trigger phrase.
- Skill probes `03-code-patterns.md` for the `## Machine-checkable rules` section and finds no rule blocks (or finds the file absent).
- Skill takes the AC-only fallback path per §12.1 + Q2 settlement: rule evaluation is skipped, AC verification proceeds normally.
- All 3 `auto:` ACs are executed in the worktree and pass.
- Skill cross-checks `report.md` against observed AC outcomes; claims match.
- Skill emits a green verification summary and a one-line advisory noting that project rules were absent and only AC verification ran (so the user is not silently misled into thinking rule coverage existed).
- Skill does NOT halt, does NOT surface the §12.2 menu (no failure occurred), does NOT prompt the user to author rules.
- Skill does NOT invoke `sf_rules_*` evaluation functions for the empty-rules case (the absence-detection probe is sufficient; no need to run zero rules against the diff).

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows the absence-detection probe of `03-code-patterns.md` (a Read or Grep against the file looking for `mcrule:start` sentinels).
- Target subagent's tool-call log shows exactly 3 Bash invocations running the 3 `auto:` AC commands in the worktree (full AC sweep, since none fail).
- Target subagent's assistant transcript contains an advisory naming the rules-absent condition — judge accepts: "no project rules authored", "R2 rules absent — AC-only verification", "machine-checkable rules section empty; skipping rule checks", or equivalent. Judge rejects: silent skip (no advisory surfaced; user can't tell whether rules ran).
- The advisory string explicitly references either "rules" or "R2" so the user can identify what was skipped (mirrors the S4 "adversarial review skipped" pattern from `evals/planning-vertical-slice.md`).
- Target subagent's assistant transcript contains a green verification summary naming all 3 ACs as passed.
- No `[rule]` source-tagged error appears in the transcript (no rule fired; no error to tag).
- No §12.2 menu is surfaced.
- No call into `sf_rules_*` evaluation functions appears beyond the absence-detection probe (no point evaluating zero rules).
- Target subagent's final assistant message indicates the work item is ready for commit/merge.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 4 scenarios PASS.

## Out of scope for this eval

- Report cross-check mismatch as a primary failure source (where ACs pass in the gate but `report.md` claims they failed, or vice versa, AND ACs are not themselves failing) — the standalone report-cross-check failure path with §12.2 row 2 menu is covered by `evals/executing-work-item.md` (report authoring is the implementer subagent's responsibility) and by a focused mismatch test in `tests/test-verify.sh`.
- Merge conflict handling (§12.2 row 4 menu — `git merge --continue` / `git merge --abort`) — merges happen AFTER this gate passes, per the §13 round-close flow; covered by `tests/test-merge.sh`.
- Subagent crash / timeout / malformed return handling (§12.2 row 5 menu) — those failures occur DURING subagent execution, before this gate runs; covered by `evals/executing-work-item.md` and the subagent pressure tests in `tests/test-subagent.sh`.
- Multi-work-item round-level orchestration (strict sequential processing per §13, halt-on-fail propagation across items in a round) — the gate is per-work-item; round-level halt cascade is covered by `tests/test-merge.sh` and the e2e fixture in `tests/test-e2e.sh`.
- The §12.2 menu's downstream effect of each option (re-spawn → Task tool call with appended `## Fix-up iteration N` handoff section; replan → return to spec authoring) — this eval verifies the menu is *surfaced* with all options; option-selection downstream behavior is covered by `evals/executing-work-item.md` (re-spawn) and `evals/planning-vertical-slice.md` (replan).
- `sf_rules_parse` / `sf_rules_validate_block` parser correctness for the four v0.2 rule types (banned_imports, coverage_floor, style_invariants, required_pattern) — that's scaffold-onboard v0.2's territory, tested in its `tests/test-rules.sh`. This eval treats the API as a black box and only asserts that the gate consumes it via the published entry point.
- R2 rule-authoring behavior (how rules get into `03-code-patterns.md` in the first place) — covered by scaffold-onboard v0.2's `evals/authoring-machine-checkable-rules.md`.
- `user:` demo step verification (manual steps per §14.2) — those run at slice-close, not per-work-item, and are covered by `evals/closing-vertical-slice.md`.
- Manifest absence / corrupt-manifest behavior — `evals/planning-vertical-slice.md` S2 covers the absent-manifest refusal at the orchestrator entry point; if the user invokes this gate without a manifest, the same fail-fast applies but is not re-tested here (orthogonal concern, covered upstream).
