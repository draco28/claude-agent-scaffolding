# Eval: scaffold-onboard:authoring-machine-checkable-rules

> Behavior eval for the `authoring-machine-checkable-rules` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-onboard:authoring-machine-checkable-rules` skill (per SPEC §5.5 + §8) drives the rule-authoring conversation, emits the correct HTML-sentinel `mcrule` block grammar for each of the four v0.2 rule types (banned_imports, coverage_floor, style_invariants, required_pattern), appends rather than overwrites a pre-existing `## Machine-checkable rules` section, and degrades gracefully on unknown rule types per the extensibility contract (§8.5).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp repo, `.claude/` state, composition manifest, marketplace cache directories, and any preexisting MASTER-SPEC fragments described in the scenario.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input, the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**Reproducibility note:** the orchestrator MUST clear any `.claude/memory-bank/03-code-patterns.md` artifacts and any `.claude/marker-*` files between scenarios. Scenarios are independent; ordering does not matter.

## Scenarios

### S1 — `banned_imports` rule authoring (fresh patterns file)

**Setup:**
- Tmp repo with `git init`.
- `.claude/memory-bank/` directory exists but `03-code-patterns.md` is absent (or present without a `## Machine-checkable rules` section).
- No composition.json (skill is invoked directly, not via composition).
- Project context: Python codebase with async code paths under `src/`.

**Trigger:** target subagent user message: `add a project rule: forbid synchronous HTTP libraries inside async code paths under src/`

**Expected behavior:**
- Skill triggers via description-match on "add a project rule".
- Skill walks the user through banned_imports authoring (identifies rule type from the request, prompts for missing fields if any).
- Skill generates an HTML-sentinel `mcrule` block with `type=banned_imports` containing:
  - Required field: `forbid: [requests, urllib3, ...]` (list form, names drawn from the user's intent — sync HTTP libraries)
  - Optional field: `in: src/**/*.py` (glob scoping to the requested directory + language)
  - Optional field: `where: any_function_marked_async` (semantic predicate matching the async-paths constraint)
- Skill validates the generated block via `lib/rules.sh:sf_rules_parse` round-trip before writing.
- Skill creates `## Machine-checkable rules` section in `03-code-patterns.md` (since none existed) and appends the rule under it.
- Block uses `<!-- mcrule:start type=banned_imports -->` … `<!-- mcrule:end -->` sentinel form (NOT a fenced ```mcrule code block).

**Assertion (judge subagent verifies):**
- `03-code-patterns.md` contains a `## Machine-checkable rules` H2 section after the turn.
- The file contains exactly one `<!-- mcrule:start type=banned_imports -->` … `<!-- mcrule:end -->` block (HTML comment sentinels, not fenced markdown code blocks).
- The block body contains a `forbid:` key with a non-empty list value naming synchronous HTTP libraries (e.g., `requests`, `urllib3`, or equivalent).
- The block body contains an `in:` glob scoping rule to Python source under `src/`.
- The block body contains a `where:` predicate matching async-function semantics (e.g., `any_function_marked_async`).
- Target subagent's tool-call log shows a `sf_rules_parse` (or equivalent rules-lib validation) invocation BEFORE the file write — round-trip validation occurred.
- No file writes outside `.claude/memory-bank/03-code-patterns.md`.

---

### S2 — `coverage_floor` rule authoring

**Setup:**
- Tmp repo with `git init`.
- `.claude/memory-bank/03-code-patterns.md` exists with prose content but no `## Machine-checkable rules` section yet.
- Project context: API layer at `src/api/` requires high test coverage.

**Trigger:** target subagent user message: `author a machine-checkable rule: src/api/ must maintain at least 80% test coverage`

**Expected behavior:**
- Skill triggers on "author … machine-checkable rule".
- Skill identifies rule type as `coverage_floor`.
- Skill generates an HTML-sentinel `mcrule` block with `type=coverage_floor` containing both required fields:
  - `paths: [src/api/]` (list form)
  - `threshold: 80` (numeric, no `%` suffix per §8.3 semantics)
- Skill does NOT add `in:`, `where:`, or pattern fields (coverage_floor has no optional fields per §8.3).
- Skill validates via `sf_rules_parse` round-trip before write.
- Skill creates `## Machine-checkable rules` section and appends the rule.

**Assertion (judge subagent verifies):**
- `03-code-patterns.md` gains a `## Machine-checkable rules` section.
- The file contains exactly one `<!-- mcrule:start type=coverage_floor -->` … `<!-- mcrule:end -->` block.
- The block body contains `paths:` with a list value that includes `src/api/` (or `src/api`).
- The block body contains `threshold:` with the integer value `80`.
- The block body does NOT contain `forbid_pattern:`, `require_pattern:`, `forbid:`, `in:`, or `where:` fields (none of those apply to coverage_floor per §8.3).
- Pre-existing prose content in `03-code-patterns.md` is preserved unchanged.
- Target subagent's tool-call log shows a rules-lib validation pass before the file write.

---

### S3 — `style_invariants` rule authoring (with exclude glob)

**Setup:**
- Tmp repo with `git init`.
- `.claude/memory-bank/03-code-patterns.md` exists; no `## Machine-checkable rules` section yet.
- Project context: Python codebase; production code lives in `src/`, tests in `tests/`.

**Trigger:** target subagent user message: `add a rule that forbids print() calls anywhere except inside test files`

**Expected behavior:**
- Skill triggers on "add a rule".
- Skill identifies rule type as `style_invariants` (forbid-pattern semantics).
- Skill generates an HTML-sentinel `mcrule` block with `type=style_invariants` containing:
  - Required field: `forbid_pattern: '\bprint\('` (regex matching `print(` as a word boundary call)
  - Optional field: `in: src/**/*.py` (or equivalent scoping glob to Python sources)
  - Optional field: `exclude: tests/**/*.py` (or equivalent exclusion for test files)
- Skill validates via `sf_rules_parse` round-trip before write.

**Assertion (judge subagent verifies):**
- `03-code-patterns.md` contains exactly one `<!-- mcrule:start type=style_invariants -->` … `<!-- mcrule:end -->` block.
- The block body contains a `forbid_pattern:` key with a regex value that matches `print(` invocations (e.g., `\bprint\(` or equivalent boundary-aware pattern).
- The block body contains an `in:` glob scoping to Python source (e.g., `src/**/*.py` or similar).
- The block body contains an `exclude:` glob excluding the test tree (e.g., `tests/**/*.py`).
- The block body does NOT contain `require_pattern:` (that's a different rule type per §8.3).
- Target subagent's tool-call log shows a rules-lib validation pass before the file write.

---

### S4 — `required_pattern` rule authoring (with `where:` predicate)

**Setup:**
- Tmp repo with `git init`.
- `.claude/memory-bank/03-code-patterns.md` exists; no `## Machine-checkable rules` section yet.
- Project context: API handlers live at `src/api/handlers/`; team policy requires every handler function to have a docstring with `Args:` and `Returns:` sections.

**Trigger:** target subagent user message: `add a rule: every function in src/api/handlers/ must have a docstring with Args: and Returns: sections`

**Expected behavior:**
- Skill triggers on "add a rule".
- Skill identifies rule type as `required_pattern` (must-contain semantics, not must-not-contain).
- Skill generates an HTML-sentinel `mcrule` block with `type=required_pattern` containing:
  - Required field: `require_pattern:` with a regex matching both `Args:` and `Returns:` markers in proximity (e.g., `Args:\s+.*\s+Returns:` or equivalent).
  - Optional field: `in: src/api/handlers/*.py` (or equivalent glob for the handler tree).
  - Optional field: `where: function_def` (per §8.3 `where:` extensible values).
- Skill validates via `sf_rules_parse` round-trip before write.

**Assertion (judge subagent verifies):**
- `03-code-patterns.md` contains exactly one `<!-- mcrule:start type=required_pattern -->` … `<!-- mcrule:end -->` block.
- The block body contains a `require_pattern:` key with a regex value that requires both `Args:` and `Returns:` markers.
- The block body contains an `in:` glob scoping to `src/api/handlers/` (Python files).
- The block body contains a `where:` predicate with value `function_def` (or an equivalent §8.3-listed value such that the predicate scopes the requirement to function definitions, not module-level or class-level).
- The block body does NOT contain `forbid_pattern:` or `forbid:` (those are different rule types per §8.3).
- Target subagent's tool-call log shows a rules-lib validation pass before the file write.

---

### S5 — Append to existing `## Machine-checkable rules` section (no overwrite)

**Setup:**
- Tmp repo with `git init`.
- `.claude/memory-bank/03-code-patterns.md` exists with prose content AND a `## Machine-checkable rules` section that already contains ONE rule — a `banned_imports` block forbidding synchronous HTTP libraries in async paths (verbatim from SPEC §8.2 example):

  ```
  ## Machine-checkable rules

  We forbid synchronous HTTP libraries in async code paths because they block the event loop.

  <!-- mcrule:start type=banned_imports -->
  in: src/**/*.py
  where: any_function_marked_async
  forbid: [requests, urllib3, httpx.Client]
  <!-- mcrule:end -->
  ```
- Project context: same codebase wants to add a second, unrelated rule (a coverage floor on `src/api/`).

**Trigger:** target subagent user message: `add another project rule: src/api/ must keep ≥ 80% test coverage`

**Expected behavior:**
- Skill triggers on "add another project rule".
- Skill detects the pre-existing `## Machine-checkable rules` section and does NOT create a duplicate H2 header.
- Skill generates a `coverage_floor` mcrule block (per S2 semantics).
- Skill appends the new block AFTER the existing `banned_imports` block, inside the same `## Machine-checkable rules` section.
- The original `banned_imports` block is preserved verbatim (sentinel comments, body, surrounding prose all unchanged).
- The pre-existing prose ("We forbid synchronous HTTP libraries in async code paths because they block the event loop.") is preserved unchanged.

**Assertion (judge subagent verifies):**
- `03-code-patterns.md` contains exactly ONE `## Machine-checkable rules` H2 header (no duplicate sections were created).
- The file contains the original `<!-- mcrule:start type=banned_imports -->` block with body lines (`in:`, `where:`, `forbid:`) BYTE-IDENTICAL to the pre-existing fixture (no reformatting, no field reordering, no whitespace changes inside the original block).
- The file ALSO contains a new `<!-- mcrule:start type=coverage_floor -->` block with `paths:` and `threshold:` fields per S2 semantics.
- The new block appears AFTER the original banned_imports block in source order.
- The pre-existing prose paragraph ("We forbid synchronous HTTP libraries…") is preserved verbatim.
- Total count of `<!-- mcrule:start ` sentinels in the file is exactly 2.
- Target subagent's tool-call log shows a rules-lib validation pass before the file write.

---

### S6 — Unknown rule type encountered during parse (warn + skip, no crash)

**Setup:**
- Tmp repo with `git init`.
- `.claude/memory-bank/03-code-patterns.md` exists with a `## Machine-checkable rules` section that contains TWO rules:
  1. A valid `banned_imports` block (verbatim from §8.2 example).
  2. A forward-compat block with an unknown type — e.g., `<!-- mcrule:start type=dependency_age -->` body `max_days: 365` `<!-- mcrule:end -->` (a v0.3+ type that v0.2 parser does NOT recognize, per §8.5 examples).
- Project context: user wants to add a third rule (a `style_invariants` no-print rule, per S3 semantics).

**Trigger:** target subagent user message: `add a rule that forbids print() in src/ except inside tests/`

**Expected behavior:**
- Skill triggers on "add a rule".
- Skill (or the rules-lib parser it invokes) reads the existing patterns file as part of pre-write validation / section-detection.
- On encountering the unknown `type=dependency_age` block, the parser **warns and skips** that block (per §8.5 extensibility contract) — it MUST NOT crash, error out, or abort the authoring flow.
- Skill continues and appends a new `style_invariants` block per S3 semantics.
- Both the original valid `banned_imports` block AND the unknown `dependency_age` block are preserved unchanged in the final file (skip means skip during semantic processing — not delete from disk).
- The final file contains three mcrule blocks total: banned_imports (original), dependency_age (original, untouched), style_invariants (newly authored).

**Assertion (judge subagent verifies):**
- The skill RUN completed successfully (no crash, no fatal error, no abort — target subagent reached an assistant turn confirming the rule was authored).
- The target subagent's transcript (or tool-call stderr capture) contains a visible warning referencing the unknown rule type `dependency_age` (e.g., a stderr line like `warning: unknown mcrule type 'dependency_age', skipping` or equivalent natural-language acknowledgment that an unknown type was encountered and skipped).
- The final `03-code-patterns.md` contains all THREE mcrule blocks: original `banned_imports` (unchanged), original `dependency_age` (unchanged — extensibility means forward-compat preservation, not deletion), and the newly authored `style_invariants`.
- The original two blocks are byte-identical to the pre-existing fixture in their bodies.
- Total count of `<!-- mcrule:start ` sentinels in the file is exactly 3.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 6 scenarios PASS.

## Out of scope for this eval

- scaffold-dev `implementation-checking` consumer behavior — covered by scaffold-dev's own evals; this eval verifies authoring + storage only, not enforcement at diff-check time
- `lib/rules.sh:sf_rules_parse` parser unit tests (per PLAN T3.3 — those exercise the parser library directly via bash, independent of this skill's authoring conversation)
- Round-trip parse → re-emit fidelity for arbitrary rule blocks beyond the four v0.2 types (lib-level concern, not a skill-behavior concern)
- Composition with onboarding-project Phase 5/6 invocation flow (orthogonal; this eval invokes the skill directly via its own trigger phrases, not through `/onboard`)
- Manifest-aware output routing for `03-code-patterns.md` (covered by routing integration tests per PLAN T7.1; this eval assumes single-repo / cwd-rooted `.claude/memory-bank/` placement)
- Demo-criteria DSL (`auto:`/`user:`) — that's the sibling `authoring-vertical-slice-demo` skill (eval lives in its own file)
