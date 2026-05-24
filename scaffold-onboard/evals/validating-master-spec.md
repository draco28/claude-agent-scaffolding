# Eval: scaffold-onboard:validating-master-spec

> Behavior eval for the `validating-master-spec` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-onboard:validating-master-spec` skill (per SPEC §5.7) wraps `sf_spec_validate` from lib/parser.sh correctly, surfaces validation errors with line numbers + remediation hints, and confirms validity with the verbatim success message from SPEC §5.7 when the spec is clean. Parser unit semantics (the 7 validation rules + 9 project-class enums) are covered by v0.1.0's `tests/test-parser.sh` and are not re-exercised here; this eval validates the *skill wrapper's* surfacing behavior.

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp repo, a `MASTER-SPEC.md` file at a known path with the content described in the scenario, and any other preconditions.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input, the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST place a fresh `MASTER-SPEC.md` per scenario and clear any prior validation artifacts between runs.

## Scenarios

### S1 — Valid MASTER-SPEC (happy path)

**Setup:**
- Tmp repo with `git init`.
- A well-formed `MASTER-SPEC.md` at repo root that satisfies all 7 validation rules per v0.1.0 SPEC §6.5:
  - Top-level heading `# <name> — Master Specification`
  - `## Executive Summary` section present
  - All 10 phase markers present (`<!-- master-spec:phase id=1 name=... -->` … `id=10`)
  - `**Project class:**` field set to a known enum value (e.g., `CLI tool` from `SF_PROJECT_CLASS_ENUM` in `lib/parser.sh`)
  - `**Spec version:** 1.0`
  - Other required fields populated per v0.1.0 phases.yaml

**Trigger:** target subagent user message: `validate MASTER-SPEC`

**Expected behavior:**
- Skill triggers on the "validate MASTER-SPEC" description-match phrase (per SPEC §5.7 triggers list).
- Skill invokes `sf_spec_validate` against the on-disk file (e.g., via a Bash tool call into `lib/parser.sh`).
- `sf_spec_validate` exits 0 (no errors).
- Skill responds with the verbatim confirmation string from SPEC §5.7: `MASTER-SPEC valid. Ready for /scaffold-project and /scaffold-docs.`
- No filesystem mutations (validation is read-only).

**Assertion (judge subagent verifies):**
- Target subagent's final assistant message contains the verbatim string `MASTER-SPEC valid. Ready for /scaffold-project and /scaffold-docs.` (the backticks around the slash commands per SPEC §5.7 are acceptable; phrasing must otherwise match exactly — no synonyms, no rewording).
- Target subagent's tool-call log shows at least one Bash invocation that executes `sf_spec_validate` (directly or via sourcing `lib/parser.sh`).
- No write-flavored tool calls (`Write`, `Edit`, `mv`, `>` redirects to anything inside the repo) appear in the transcript — validation must not mutate the workspace.
- No remediation language ("fix", "expected", "missing", "invalid") appears in the assistant message — false-positive errors would surface as such.

---

### S2 — Invalid `Project class` enum (error + remediation)

**Setup:**
- Tmp repo with `git init`.
- A `MASTER-SPEC.md` that is otherwise well-formed BUT has `**Project class:** Spaceship OS` on a known line (e.g., line 14). `Spaceship OS` is not a member of `SF_PROJECT_CLASS_ENUM` (the 9 valid enums are: `CLI tool`, `Library or SDK`, `Web app`, `Web service (API only)`, `Mobile app`, `ML or AI system`, `Agent or plugin`, `Data pipeline`, `Other`).

**Trigger:** target subagent user message: `is my master spec ready for derivation?`

**Expected behavior:**
- Skill triggers via description-match on the "is my master spec ready for derivation?" phrase (per SPEC §5.7 triggers list).
- Skill invokes `sf_spec_validate`; the function exits non-zero with the parser's stderr error `Project class 'Spaceship OS' not in enum. Expected one of: CLI tool Library or SDK Web app ...`.
- Skill surfaces the parser error to the user with: (a) the offending enum value (`Spaceship OS`) named explicitly, (b) the list of valid alternatives from `SF_PROJECT_CLASS_ENUM`, and (c) the line number in `MASTER-SPEC.md` where the bad enum appears.
- Skill includes a remediation hint suggesting the user edit that line to one of the valid enum values.

**Assertion (judge subagent verifies):**
- Target subagent's final assistant message names the offending value `Spaceship OS` explicitly (quoted or otherwise identifiable as the bad input).
- The message lists at least 7 of the 9 valid project-class enums verbatim from `SF_PROJECT_CLASS_ENUM` (judge accepts: minor whitespace, comma-separated vs space-separated; rejects: paraphrased substitutes like "command-line tool" for `CLI tool`).
- The message cites the line number where the offending `**Project class:**` field appears (e.g., "line 14"); the judge confirms the cited line matches the fixture's actual line.
- The message includes an actionable remediation hint — e.g., "change to one of the valid values above" or "edit line 14 to use a supported enum" — not just a raw parser error dump.
- Skill does NOT emit the SPEC §5.7 success string (`MASTER-SPEC valid. Ready for ...`); a false-positive success would fail the scenario.
- No write-flavored tool calls to `MASTER-SPEC.md` (the skill surfaces; it does not auto-fix).

---

### S3 — Missing phase marker (error + line number + insertion hint)

**Setup:**
- Tmp repo with `git init`.
- A `MASTER-SPEC.md` that is otherwise well-formed BUT is missing the Phase 5 marker comment. Phase 5's heading section starts where `<!-- master-spec:phase id=5 name=... -->` should appear (e.g., line 62 in the fixture), but the marker comment line itself is absent — only the prose body of Phase 5 is present.

**Trigger:** target subagent user message: `check the spec`

**Expected behavior:**
- Skill triggers via description-match on "check the spec" (per SPEC §5.7 triggers list).
- Skill invokes `sf_spec_validate`; the function exits non-zero with the parser's stderr error `Missing phase markers: id=5. Phases must be authored via /onboard.`
- Skill surfaces the error with: (a) identification that Phase 5 is the missing phase, (b) the line number in `MASTER-SPEC.md` where the marker was expected (i.e., the line where the Phase 5 content begins and the marker should precede it), and (c) a remediation hint quoting the exact comment syntax to add: `<!-- master-spec:phase id=5 name=... -->` (with `...` either as a placeholder or filled in with the canonical phase 5 name from phases.yaml).

**Assertion (judge subagent verifies):**
- Target subagent's final assistant message identifies Phase 5 (or `id=5`) as the missing phase marker — not Phase 1, not a generic "a phase is missing", not a different id.
- The message cites the line number where the Phase 5 marker was expected (e.g., "around line 62" or "line 62"); the judge confirms the cited line is within ±2 lines of the fixture's Phase 5 content start.
- The message includes an HTML-comment insertion hint that matches the pattern `<!-- master-spec:phase id=5 name=... -->` (the `...` portion may be a literal placeholder or the canonical phase-5 name from v0.1.0's phases.yaml — judge accepts either).
- The skill does NOT silently re-author or insert the marker itself — only surfaces the gap. No write-flavored tool calls to `MASTER-SPEC.md`.
- Skill does NOT emit the SPEC §5.7 success string.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 3 scenarios PASS.

## Out of scope for this eval

- Parser unit tests for `sf_spec_validate` — covered by v0.1.0's `tests/test-parser.sh` (kept unchanged in v0.2 per SPEC §5.7 wording "unchanged — 7 validation rules + 9 project-class enums").
- The 4 other validation rules from v0.1.0 SPEC §6.5 not exercised in S1–S3 (top-level heading malformed, missing `## Executive Summary`, missing `**Project class:**` field entirely, unrecognized `Spec version`). These pass through the same surfacing pipeline as the rules tested in S2 + S3; a regression in the wrapper's error-presentation logic would surface in any of the three scenarios above.
- Multi-error surfacing — `sf_spec_validate` short-circuits on first ERROR (per parser.sh comment line 88-89), so the skill's behavior with multiple simultaneous validation failures is defined by parser semantics, not by the skill wrapper, and is not in scope here.
- WARNING-level surfacing (e.g., unrecognized spec version) — `sf_log_warn` does not block validation; surface behavior for WARNINGs is not specified in SPEC §5.7 and is deferred.
