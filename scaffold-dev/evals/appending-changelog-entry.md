# Eval: scaffold-dev:appending-changelog-entry

> Behavior eval for the `appending-changelog-entry` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:appending-changelog-entry` skill (per SPEC §7.1) appends a Keep-a-Changelog 1.1.0 entry to `CHANGELOG.md` under the `[Unreleased]` section, in the correct one of six categories (Added / Changed / Deprecated / Removed / Fixed / Security), without disturbing the existing structure of the file (released sections below `[Unreleased]`, link references at the bottom, file header). Also verifies that the skill routes to the canonical repo via `lib/manifest.sh` (changelog is production-facing per §7.1) and surfaces a fail-fast error when `CHANGELOG.md` is absent (it is scaffold-onboard's `/scaffold-docs` responsibility to seed the file; this skill does NOT auto-create it).

This eval validates the *changelog-append skill's* behavior — not the broader release-cut flow (cutting a new versioned section from `[Unreleased]` is a separate concern, deferred to v0.2 or handled manually).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), `CHANGELOG.md` at the manifest-routed path with the scenario's content (or absent per S2), and any other preconditions described in the scenario's `Setup` block.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after), specifically the modified `CHANGELOG.md` content
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input (e.g., category prompt, entry-text prompt), the orchestrator pre-loads the user's follow-up responses in the dispatch prompt rather than waiting for interactive input.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST reset `CHANGELOG.md` content between runs (or remove it for S2). Each scenario starts from a freshly initialized fixture.

## Scenarios

### S1 — Happy path: append to `[Unreleased]` → `Added` (Keep-a-Changelog structure preserved)

**Setup:**
- Dual-repo fixture: manifest at the parent, `routing.changelog` resolves to `<canonical>/CHANGELOG.md`.
- `<canonical>/CHANGELOG.md` exists with valid Keep-a-Changelog 1.1.0 structure:
  - Header (`# Changelog`, intro paragraph naming Keep-a-Changelog 1.1.0 + SemVer 2.0.0)
  - `## [Unreleased]` section with empty subsection headings for the 6 categories (`### Added`, `### Changed`, etc.) OR with `### Added` already containing one prior bullet
  - `## [0.1.0] - 2026-04-01` released section with populated content
  - Link references at the bottom (`[Unreleased]: https://...`, `[0.1.0]: https://...`)
- Pre-injected user follow-ups: (a) "Added" when the skill prompts for the category; (b) "Redis-backed session cache for sub-100ms lookup" when the skill prompts for the entry text.

**Trigger:** target subagent user message: `add changelog entry`

**Expected behavior:**
- Skill triggers via description-match on the "add changelog entry" trigger phrase (per SPEC §7.1 triggers list).
- Skill discovers the manifest via `lib/manifest.sh` walk-up helpers and resolves `routing.changelog` to `<canonical>/CHANGELOG.md`.
- Skill Reads the existing `CHANGELOG.md` to locate the `## [Unreleased]` section and its category subsections.
- Skill prompts the user for the category; captures "Added".
- Skill prompts the user for the entry text; captures "Redis-backed session cache for sub-100ms lookup".
- Skill appends a new bullet line `- Redis-backed session cache for sub-100ms lookup` under the `### Added` subsection inside `## [Unreleased]`, leaving the rest of the file structurally unchanged (released sections, link refs, header all intact).
- Skill emits a final assistant message naming the modified file's absolute path AND quoting the appended line.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows at least one Bash invocation that sources or calls into `lib/manifest.sh`; no raw `jq -r '.routing.changelog' .workspace/pairing.json` style inline reads appear.
- Target subagent's tool-call log contains a Read of `<canonical>/CHANGELOG.md` BEFORE the Edit (or Write) that mutates it.
- Target subagent's tool-call log contains an `Edit` (or `Write`) of `<canonical>/CHANGELOG.md`. The diff reveals exactly one new line `- Redis-backed session cache for sub-100ms lookup` appended under the `### Added` heading inside `## [Unreleased]`. Judge confirms: (a) the new bullet is inside `## [Unreleased]` (NOT inside the released `## [0.1.0]` section); (b) the new bullet is under `### Added` specifically (NOT under `### Changed` or any other category); (c) the bullet uses Keep-a-Changelog `- ` prefix (NOT `* ` or `+ `).
- The file's `## [0.1.0] - 2026-04-01` released section content is UNCHANGED (judge diffs the released section and confirms zero modifications).
- The file's link-reference block at the bottom is UNCHANGED.
- Target subagent's assistant transcript contains explicit prompts for both the category AND the entry text — judge rejects: skill silently picks a category or composes entry text without asking.
- Target subagent's final assistant message names the absolute path of the modified file.
- No new files are created (only `CHANGELOG.md` is edited).

---

### S2 — `CHANGELOG.md` missing (fail-fast, surface scaffold-docs remediation hint)

**Setup:**
- Dual-repo fixture: manifest at the parent, `routing.changelog` field present in the manifest BUT the resolved file `<canonical>/CHANGELOG.md` does NOT exist on disk (scaffold-onboard's `/scaffold-docs` was never run, or was run with a stripped-down config that omitted the changelog seed).
- Pre-injected user follow-ups: none (skill should refuse before reaching the category/entry prompts).

**Trigger:** target subagent user message: `append to changelog`

**Expected behavior:**
- Skill triggers via description-match on the "append to changelog" trigger phrase.
- Skill discovers manifest; resolves `routing.changelog` to `<canonical>/CHANGELOG.md`.
- Skill checks whether the file exists; finds it ABSENT.
- Skill refuses to proceed (does NOT auto-create the file with a Keep-a-Changelog template — that's scaffold-onboard's responsibility per §16.2) and surfaces a fail-fast error message naming: (a) the resolved-but-missing file path, (b) the remediation slash command pointing at scaffold-onboard (`/scaffold-docs` to seed the changelog).
- Skill does NOT write any file, does NOT mutate the workspace, does NOT prompt for category/entry-text.

**Assertion (judge subagent verifies):**
- Target subagent's final assistant message names the resolved-but-missing path explicitly (e.g., `<canonical>/CHANGELOG.md` or the absolute path) AND the slash-command token `/scaffold-docs` as the remediation route. Judge accepts minor surrounding-phrase variation; rejects: paraphrased substitutes that omit the `/scaffold-docs` token, or messages that offer to create the changelog inline.
- Target subagent's tool-call log contains at least one `lib/manifest.sh` helper invocation AND a file-existence check (e.g., `test -f`, Read attempt, or equivalent) against the resolved path.
- No `Write` or `Edit` tool calls appear in the transcript.
- No category/entry-text prompt appears in the assistant transcript (the skill must bail BEFORE reaching the user-input collection step).

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when both scenarios PASS.

## Out of scope for this eval

- Release cutting (moving `[Unreleased]` content into a new `[X.Y.Z] - YYYY-MM-DD` section, updating link references, bumping version) — deferred to v0.2 or handled manually in v0.1.
- Multi-line entry text formatting (entries that span multiple lines with sub-bullets, code blocks, or links) — v0.1 supports single-line bullet entries; multi-line formatting fidelity is downstream.
- Category-validation strictness (rejecting invalid category names like "Featured" instead of "Added") — v0.1 trusts the user; if the user supplies an unrecognized category, the skill either prompts for clarification or appends under a new heading (resolved during PLAN T1.7 implementation). This eval does not exercise the invalid-category branch.
- Changelog file structural repair (the file exists but is missing the `[Unreleased]` section, or has malformed category headings) — out of scope; the skill assumes Keep-a-Changelog 1.1.0 structural validity as a precondition (seeded by scaffold-onboard's `/scaffold-docs`).
- Link-reference auto-creation (entries that reference issue/PR numbers and need a `[#123]: https://...` link added) — deferred to v0.2.
- Manifest absence / corrupt-manifest behavior — `evals/planning-vertical-slice.md` S2 covers the absent-manifest refusal at the orchestrator entry point; if the user invokes this skill without a manifest, the same fail-fast applies but is not re-tested here.
