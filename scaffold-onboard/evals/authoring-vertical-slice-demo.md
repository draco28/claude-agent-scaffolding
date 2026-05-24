# Eval: scaffold-onboard:authoring-vertical-slice-demo

> Behavior eval for the `authoring-vertical-slice-demo` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-onboard:authoring-vertical-slice-demo` skill (per SPEC §5.6 + §9) authors `auto:`/`user:` demo criteria for a named vertical slice in `ROADMAP.md`, emits the exact grammar with the literal `→ expected:` arrow token, and behaves idempotently across initial seeding (by `planning-project-roadmap` during R1.C) and top-up authoring (by scaffold-dev's orchestrator at slice planning).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp repo, `.claude/` state, composition manifest, marketplace cache directories, and any preexisting `ROADMAP.md` content described in the scenario.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input (e.g., asking the user for 1-3 demo lines), the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**Reproducibility note:** the orchestrator MUST reset the fixture `ROADMAP.md` between scenarios. Scenarios are independent; ordering does not matter.

## Scenarios

### S1 — Initial seeding during `/plan-roadmap` R1.C (1-3 lines per slice)

**Setup:**
- Tmp repo with `git init`.
- `ROADMAP.md` exists with R1.A (phase) and R1.B (sprint) blocks complete, and a `#### VS-1.1.1: <slice name>` slice block under `### Sprint 1.1:` with the slice's 1-2 sentence summary present but NO `##### Demo criteria` subsection yet.
- `lib/demo-criteria.sh` available on the skill body's lookup path.
- No composition.json variation matters here — the skill is invoked directly by `planning-project-roadmap`.

**Trigger:** target subagent user message (orchestrator simulates `planning-project-roadmap` mid-R1.C):
`author demo criteria for slice VS-1.1.1` — followed by an injected user reply supplying two skeleton lines (one auto-exit-code, one user-outcome) when the skill prompts for them.

**Expected behavior:**
- Skill locates the `#### VS-1.1.1:` block in `ROADMAP.md` (NOT `PROJECT_PLAN.md`).
- Skill confirms no existing `##### Demo criteria` block under this slice, so this is an initial-seeding write.
- Skill prompts the user for 1-3 demo lines (skeleton form is acceptable at R1.C).
- Skill validates each user-supplied line via `sf_demo_parse_line` before writing.
- Skill writes a new `##### Demo criteria` subsection under the slice block containing the validated lines, each prefixed `- [ ] ` and using the literal `→ expected:` arrow token.
- Skill writes to `ROADMAP.md` only — no writes to `PROJECT_PLAN.md` or any other path.

**Assertion (judge subagent verifies):**
- After the turn, `ROADMAP.md` contains a `##### Demo criteria` heading immediately under the `#### VS-1.1.1:` block.
- Between 1 and 3 demo criterion lines exist under that heading (inclusive bounds per SPEC §9.2).
- Every emitted line starts with `- [ ] ` and matches either `- [ ] auto: <…> → expected: <…>` or `- [ ] user: <…> → expected: <…>` — the literal arrow token `→ expected:` is present on every line (judge must verify the U+2192 arrow character, not `->`).
- `sf_demo_parse_line` was invoked (visible in the target subagent's tool-call log) at least once per emitted line, with exit 0 each time.
- No write to `PROJECT_PLAN.md` or to any path outside `ROADMAP.md` for criterion content.
- Other slice blocks in `ROADMAP.md` are unmodified.

---

### S2 — Top-up by scaffold-dev (idempotent append)

**Setup:**
- Tmp repo with `git init`.
- `ROADMAP.md` contains slice `VS-2.1.1` already seeded with one existing demo criterion line:
  ```
  ##### Demo criteria

  - [ ] auto: `pytest tests/unit/test_parser.py` → expected: exit 0
  ```
- The orchestrator runs the skill twice for this slice within the same scenario, using the multi-turn injection protocol:
  - **Run A:** target is invoked with the SAME existing criterion text re-supplied (text equality with what's already on disk).
  - **Run B:** target is invoked again with a NEW criterion text that does not appear in the existing block.
- `lib/demo-criteria.sh` available.

**Trigger:** target subagent user message: `top-up demo criteria for VS-2.1.1` (orchestrator simulates scaffold-dev orchestrator at slice planning).

**Expected behavior:**
- Skill locates the `#### VS-2.1.1:` block and reads the existing `##### Demo criteria` lines before writing.
- **Run A (same-text):** skill detects text-equality match against the existing line and does NOT append a duplicate. The criterion block contains exactly one line after Run A — identical to the pre-existing line.
- **Run B (new-text):** skill detects no text-equality match for the new line and appends it to the existing block. The criterion block contains exactly two lines after Run B — the original PLUS the new line, in that order. The original line is NOT overwritten, reordered, or rewritten.
- Both runs validate the candidate line via `sf_demo_parse_line` before any write decision.

**Assertion (judge subagent verifies):**
- After Run A, `ROADMAP.md`'s `VS-2.1.1` demo block contains exactly one `- [ ] ` line, byte-identical to the pre-existing line. No duplicate `pytest tests/unit/test_parser.py` line appears.
- After Run B, `ROADMAP.md`'s `VS-2.1.1` demo block contains exactly two `- [ ] ` lines: the original first, the new line second. The original line text is unchanged (no overwrite).
- Both emitted/preserved lines retain the literal `→ expected:` arrow token.
- `sf_demo_parse_line` was invoked in both Run A and Run B before the write/no-write decision.
- No criterion lines under any other slice block were added, removed, or modified across both runs.

---

### S3 — Auto-line grammar (cmd → expected: exit 0)

**Setup:**
- Tmp repo with `git init`.
- `ROADMAP.md` contains slice `VS-1.1.2` with summary but no `##### Demo criteria` block yet.
- `lib/demo-criteria.sh` available.

**Trigger:** target subagent user message: `author demo criteria for VS-1.1.2`, with the orchestrator injecting a single user reply that supplies one auto-line with an exit-code expectation — e.g., the line text `auto: pytest tests/integration/test_pipeline.py → expected: exit 0`.

**Expected behavior:**
- Skill locates the `#### VS-1.1.2:` block in `ROADMAP.md`.
- Skill validates the supplied line via `sf_demo_parse_line`; the line conforms to the auto-exit-code form per SPEC §9.1.
- Skill writes the line under a new `##### Demo criteria` subsection of `VS-1.1.2`, prefixed `- [ ] `, preserving the literal `→ expected: exit 0` tail token verbatim.

**Assertion (judge subagent verifies):**
- `ROADMAP.md` under `#### VS-1.1.2:` contains exactly one `- [ ] auto: <…> → expected: exit 0` line.
- The line starts with `- [ ] auto:` (literal `auto:` prefix per SPEC §9.1).
- The line contains the literal arrow token `→ expected: exit 0` (judge verifies the U+2192 arrow character AND the exact string `expected: exit 0`).
- `sf_demo_parse_line` returned exit 0 for this line (visible in tool-call log).
- No `user:`-prefixed line was emitted for this slice.

---

### S4 — Auto-line grammar (cmd → expected: pattern)

**Setup:**
- Tmp repo with `git init`.
- `ROADMAP.md` contains slice `VS-1.2.1` with summary but no `##### Demo criteria` block yet.
- `lib/demo-criteria.sh` available.

**Trigger:** target subagent user message: `author demo criteria for VS-1.2.1`, with the orchestrator injecting a user reply supplying one auto-line with a pattern expectation — e.g., the line text `auto: curl -s localhost:8000/api/insights | jq '.[]' → expected: output contains "action_needed"`.

**Expected behavior:**
- Skill locates the `#### VS-1.2.1:` block in `ROADMAP.md`.
- Skill validates the supplied line via `sf_demo_parse_line`; the line conforms to the auto-pattern form per SPEC §9.1 (`expected: <pattern in output>`, not an exit code).
- Skill writes the line under a new `##### Demo criteria` subsection of `VS-1.2.1`, prefixed `- [ ] `, preserving the pattern expectation tail verbatim (no rewriting of the pattern body, including quoted substrings).

**Assertion (judge subagent verifies):**
- `ROADMAP.md` under `#### VS-1.2.1:` contains exactly one `- [ ] auto: <…> → expected: <…>` line where the expected tail describes an output pattern (NOT an exit code).
- The line starts with `- [ ] auto:` and contains the literal arrow token `→ expected:` (U+2192).
- The expected tail does NOT contain `exit 0` / `exit <N>` (judge confirms this is the pattern variant, not the exit-code variant).
- The quoted substring inside the user-supplied pattern (e.g., `"action_needed"`) is preserved byte-for-byte in the emitted line.
- `sf_demo_parse_line` returned exit 0 for this line.

---

### S5 — User-line grammar (action → expected: outcome)

**Setup:**
- Tmp repo with `git init`.
- `ROADMAP.md` contains slice `VS-2.2.1` with summary but no `##### Demo criteria` block yet.
- `lib/demo-criteria.sh` available.

**Trigger:** target subagent user message: `author demo criteria for VS-2.2.1`, with the orchestrator injecting a user reply supplying one user-line — e.g., the line text `user: Navigate to localhost:3000/insights → expected: action-needed card visible with real data`.

**Expected behavior:**
- Skill locates the `#### VS-2.2.1:` block in `ROADMAP.md`.
- Skill validates the supplied line via `sf_demo_parse_line`; the line conforms to the user-outcome form per SPEC §9.1.
- Skill writes the line under a new `##### Demo criteria` subsection of `VS-2.2.1`, prefixed `- [ ] `, preserving the literal `→ expected:` arrow token and the observable-outcome tail verbatim.

**Assertion (judge subagent verifies):**
- `ROADMAP.md` under `#### VS-2.2.1:` contains exactly one `- [ ] user: <…> → expected: <…>` line.
- The line starts with `- [ ] user:` (literal `user:` prefix per SPEC §9.1).
- The line contains the literal arrow token `→ expected:` (U+2192 arrow character, not `->`).
- The expected tail describes an observable outcome (e.g., a UI state, a visible element, a user-perceivable result) — NOT an exit code or a stdout pattern.
- `sf_demo_parse_line` returned exit 0 for this line.
- No `auto:`-prefixed line was emitted for this slice.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 5 scenarios PASS.

## Out of scope for this eval

- Demo criteria EXECUTION by scaffold-dev's `closing-vertical-slice` skill — different plugin, covered by scaffold-dev's own evals.
- `lib/demo-criteria.sh` parser unit tests — covered by PLAN T3.5 (parser unit tests).
- Multi-slice batch authoring within a single `/plan-roadmap` R1.C invocation — orchestration concern handled by `planning-project-roadmap`, not this skill.
- Slice block creation in `ROADMAP.md` — slices are created upstream by `planning-project-roadmap` R1.B; this skill assumes the slice block already exists and only authors the `##### Demo criteria` subsection.
- composition.json / architect-critic integration — this skill does not invoke architect-critic at any point.
