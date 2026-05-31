# Eval: scaffold-dev:deferring-work-item

> Behavior eval for the `scaffold-dev:deferring-work-item` skill (`/defer`). Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:deferring-work-item` skill (per SPEC §8.8 + #33) correctly handles a user-surfaced technical-debt deferral: runs `sd remote_check` before any write, composes a coherent issue (title + why-deferred + unblock-condition), files it via `sd issue_create` (not raw `gh`), captures the issue number, and appends exactly one `- [TD] … → #N` line to `tech-debt.md` with no body duplication in the memory bank. Also verifies that the skill de-duplicates against existing open issues — surfacing the match and offering to skip filing rather than opening a duplicate.

This eval validates the *deferral-filing skill's* agent decisions — not the round-close auto-file path (covered by `evals/planning-vertical-slice.md` S6), nor the blocker-recall read path (covered by `evals/executing-work-item.md` S5).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), canonical has an `origin` remote, `gh` authenticated (harness may stub `gh`), `tech-debt.md` present in the AI workspace (empty index or minimal header). Scenario-specific issue-list fixture described per scenario.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match (no slash command is invoked in these scenarios except where `/defer` is named explicitly). The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text), preserving tool-call ordering (the judge MUST be able to verify relative position of tool calls — e.g., "remote_check before any file write")
   - The final filesystem state diff (before/after)
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST clear `${CLAUDE_PLUGIN_DATA}/scaffold-dev/` state files, reset `tech-debt.md` to its pre-trigger state, and restore the issue-list fixture between runs. Each scenario starts from a freshly initialized workspace fixture.

## Scenarios

### S1 — /defer files an issue + lean index line

**Setup:** dual-repo workspace; canonical has an `origin` remote; `gh` authenticated (harness may stub gh); `tech-debt.md` present (empty index). No open issue matches the deferral.

**Trigger:** `/defer retry backoff in the ingest client is a fixed 1s sleep; should be exponential`

**Expected behavior:** the skill runs `sd remote_check`, composes a coherent issue (title + why-deferred + unblock-condition), runs `sd issue_create`, captures #N, and appends exactly one `- [TD] … → #N` line to `tech-debt.md`. No prose body duplicated into the memory bank.

**Assertion (judge):** PASS iff the transcript shows remote_check before any file write, a single `sd issue_create` (not a raw `gh` call bypassing the helper), exactly one new `[TD] …→#N` line in `tech-debt.md`, and NO multi-line issue-body copy in the memory bank. FAIL if it files without remote_check, or duplicates the body into tech-debt.md.

---

### S2 — /defer de-dups against an existing open issue

**Setup:** identical, but `sd issue_list` returns an open issue (#7) that already covers the same retry-backoff debt (fixture `tests/fixtures/issue-list.json` shape).

**Trigger:** `/defer the ingest retry backoff is still fixed — should be exponential`

**Expected behavior:** the skill reads `sd issue_list`, JUDGES that #7 already covers this, surfaces "already tracked — see #7", and offers to skip filing rather than opening a duplicate.

**Assertion (judge):** PASS iff the transcript surfaces #7 as the existing match and does NOT call `sd issue_create` for a duplicate. FAIL if it files a second issue for the same debt.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <specific deviation>` so the skill author can target a fix.

The full eval is GREEN when all 2 scenarios PASS.

## Out of scope for this eval

- Round-close auto-filing of report Deferrals (the orchestrator reads prose Deferrals sections and judges whether to file) — covered by `evals/planning-vertical-slice.md` S6.
- Blocker-recall reading the lean index during work-item execution (implementer reads `tech-debt.md` and surfaces known `[TD]` lines instead of re-deriving gaps) — covered by `evals/executing-work-item.md` S5.
- `tech-debt.md` template fidelity (section headers, entry format) — covered by `tests/test-render.sh` and the scaffold-onboard seed path. This eval asserts only that exactly one `[TD] …→#N` line is appended per deferral.
- `sd remote_check` internals (what the helper verifies — remote reachability, auth token presence, etc.) — covered by scaffold-dev's unit tests. This eval treats `remote_check` as a black-box prerequisite gate and asserts only that it is invoked before any file write.
- Issue body template correctness (title casing, unblock-condition phrasing) — advisory quality; the judge notes quality in the failure message but does not fail on stylistic variation. The binding assertion is the structural shape: one `sd issue_create` call, one `[TD]` line, no body duplication.
