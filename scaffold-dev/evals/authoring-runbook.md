# Eval: scaffold-dev:authoring-runbook

> Behavior eval for the `authoring-runbook` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:authoring-runbook` skill (per SPEC §7.1) authors a new SRE-style operational runbook under `<canonical>/docs/runbooks/<topic-kebab>.md` with the standard runbook sections — overview, symptoms, immediate response, diagnosis, mitigation, postmortem-link slot — and routes the file via `lib/manifest.sh` to the canonical repo (runbooks are production-facing operational docs). Also verifies that the skill prompts the user to disambiguate when the requested topic is ambiguous (e.g., "write a runbook" with no topic), and refuses to overwrite an existing runbook at the same path (the user must explicitly choose append-section vs new-filename if the topic collides).

This eval validates the *runbook-authoring skill's* behavior — not runbook-execution flows (e.g., "follow runbook X during an incident" is operator behavior, not skill behavior) and not the broader incident-response workflow (out of scope for v0.1).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), the `<canonical>/docs/runbooks/` directory in the state described by the scenario's `Setup` block (present with prior runbooks, present and empty, or with a colliding filename), and the `templates/runbook.md.tmpl` file (if the implementation Phase 2 chose to template the runbook structure — otherwise the skill body inlines the section list).
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after), specifically any new file under `<canonical>/docs/runbooks/` + its filename + its full contents
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input (e.g., topic disambiguation in S2, collision-resolution choice in S3), the orchestrator pre-loads the user's follow-up responses in the dispatch prompt rather than waiting for interactive input.

**6-section invariant (cross-scenario, BINDING).** Every runbook file written by the target MUST contain the six SRE-style sections from §7.1's runbook description as markdown headings, in order: (1) "Overview", (2) "Symptoms", (3) "Immediate response", (4) "Diagnosis", (5) "Mitigation", (6) "Postmortem link" (or "Postmortem"). The judge scans the written file for each section name as a `##` or `###` level markdown heading (level-agnostic); a missing or renamed section is a FAIL. Judge accepts case-insensitive variants and minor pluralization (e.g., "Symptom" / "Symptoms", "Mitigation steps" / "Mitigation"); rejects substitutes that drop a section entirely (e.g., a runbook that merges "Diagnosis" into "Mitigation" without a separate Diagnosis heading).

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST reset `<canonical>/docs/runbooks/` content between runs. Each scenario starts from a freshly initialized fixture.

## Scenarios

### S1 — Happy path: author runbook with explicit topic (6 sections, manifest-routed)

**Setup:**
- Dual-repo fixture: manifest at the parent, `routing.runbooks` resolves to `<canonical>/docs/runbooks/`.
- `<canonical>/docs/runbooks/` exists and contains 1 prior runbook `database-failover.md` (fixture noise — confirms the skill writes alongside, doesn't disturb peer files).
- Pre-injected user follow-ups: (a) when prompted for operational content, user provides 1-paragraph overview ("Redis cache returning stale data after node failover"), 3-bullet symptoms, 4-step immediate response, 3-step diagnosis, 2-step mitigation, and a placeholder postmortem URL slot ("link TBD after incident review").

**Trigger:** target subagent user message: `author runbook for redis-cache-stale-after-failover`

**Expected behavior:**
- Skill triggers via description-match on the "author runbook for X" trigger pattern (per SPEC §7.1 triggers list — the topic is supplied in-line).
- Skill discovers the manifest via `lib/manifest.sh` walk-up helpers and resolves `routing.runbooks` to `<canonical>/docs/runbooks/`.
- Skill extracts the topic `redis-cache-stale-after-failover` from the trigger phrase (already kebab-case; no normalization needed).
- Skill checks whether `<canonical>/docs/runbooks/redis-cache-stale-after-failover.md` already exists; finds it ABSENT; proceeds.
- Skill prompts the user for each section's content OR renders a template with placeholders the user fills (implementation choice per PLAN T1.8); user supplies the content per the pre-injected follow-ups.
- Skill writes the file at `<canonical>/docs/runbooks/redis-cache-stale-after-failover.md` with the 6 SRE-style section headings populated.
- Skill emits a final assistant message naming the new file's absolute path.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows at least one Bash invocation that sources or calls into `lib/manifest.sh`; no raw `jq -r '.routing.runbooks' .workspace/pairing.json` inline reads appear.
- Target subagent's tool-call log contains a `Write` of a file under `<canonical>/docs/runbooks/` (NOT under `<ai-workspace>/`) whose filename matches `redis-cache-stale-after-failover.md` exactly.
- The written file contains all 6 §7.1 section headings in order per the cross-scenario 6-section invariant.
- Each of the 6 sections has at least one line of substantive content (NOT just an empty heading or "TBD"). Judge confirms: Overview ≥ 1 paragraph, Symptoms ≥ 1 bullet, Immediate response ≥ 1 step, Diagnosis ≥ 1 step, Mitigation ≥ 1 step, Postmortem link section is non-empty (placeholder URL acceptable).
- The pre-existing peer runbook `database-failover.md` is UNCHANGED (judge diffs the directory and confirms zero modifications to existing files).
- Target subagent's final assistant message names the absolute path of the written file.
- No `Write` or `Edit` appears against the `<ai-workspace>/` tree (runbooks are canonical-only per §7.1).

---

### S2 — Topic ambiguous (skill prompts user to disambiguate before writing)

**Setup:**
- Dual-repo fixture identical to S1: manifest present, `<canonical>/docs/runbooks/` exists with the `database-failover.md` peer file.
- Pre-injected user follow-ups: (a) "redis-cache-stale-after-failover" when the skill prompts for the topic; (b) section-by-section content per S1's structure.

**Trigger:** target subagent user message: `write a runbook` (no topic specified)

**Expected behavior:**
- Skill triggers via description-match on the bare "write a runbook" trigger phrase.
- Skill discovers manifest; resolves `routing.runbooks` to `<canonical>/docs/runbooks/`.
- Skill detects the topic is ABSENT from the trigger phrase (no explicit "for X" clause, no in-flight incident context the orchestrator has surfaced).
- Skill **prompts the user to disambiguate** — surfaces an explicit question asking for the topic (e.g., "What's the topic for this runbook?" or "What incident scenario does this runbook cover?") with optional guidance on the kebab-case naming convention.
- After the user supplies "redis-cache-stale-after-failover", skill proceeds identically to S1: writes the file with the 6 SRE-style sections, emits the absolute path.
- Skill does NOT silently pick a topic, does NOT write a file named `runbook.md` or `untitled.md` as a fallback.

**Assertion (judge subagent verifies):**
- Target subagent's assistant transcript contains an explicit topic-disambiguation prompt as the FIRST user-facing question (judge confirms: the prompt appears before any section-content prompts AND before any Write tool call). The prompt explicitly asks for a topic/scenario/incident name — judge accepts paraphrase but rejects: skill silently proceeds, skill picks a default topic, skill writes a file with a generic name.
- After the pre-injected topic response is captured, target subagent's tool-call log contains a `Write` of `<canonical>/docs/runbooks/redis-cache-stale-after-failover.md`.
- The written file satisfies the cross-scenario 6-section invariant.
- No file is written under any name OTHER than the user-supplied topic (judge confirms: no `runbook.md`, no `untitled-runbook.md`, no fallback names appear in the filesystem diff).
- Target subagent's tool-call log contains at least one `lib/manifest.sh` helper invocation.

---

### S3 — Topic collides with existing runbook (refuse overwrite, surface choice menu)

**Setup:**
- Dual-repo fixture identical to S1: manifest present, `<canonical>/docs/runbooks/` exists with the `database-failover.md` peer file AND a 2nd file `redis-cache-stale-after-failover.md` (the topic the user is about to request) already present with substantive content from a prior incident.
- Pre-injected user follow-ups: (a) "redis-cache-stale-after-failover" when the skill prompts for the topic. No follow-up beyond that — the skill should bail to a menu and the user's downstream menu selection is out of scope (this scenario tests that the menu IS surfaced without auto-overwrite).

**Trigger:** target subagent user message: `create operational runbook` (topic supplied via pre-injected follow-up — see Setup item (a))

**Expected behavior:**
- Skill triggers via description-match on the "create operational runbook" trigger phrase.
- Skill discovers manifest; resolves runbooks dir; prompts for topic; captures "redis-cache-stale-after-failover".
- Skill checks whether `<canonical>/docs/runbooks/redis-cache-stale-after-failover.md` already exists; finds it PRESENT.
- Skill **refuses to overwrite** — surfaces a menu with at least 2 options: (1) Append a new dated section to the existing runbook (e.g., `## Incident 2026-05-25` appended below the original content), (2) Author under a different filename (skill prompts for a new kebab topic).
- Skill does NOT auto-pick an option, does NOT overwrite the existing file, does NOT silently proceed.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log contains a file-existence check (e.g., `test -f`, Read attempt, `ls`) against `<canonical>/docs/runbooks/redis-cache-stale-after-failover.md` BEFORE any Write attempt.
- Target subagent's assistant transcript surfaces a menu with at least 2 distinct numbered or bulleted options: option text MUST identify "append" / "append section" / "add to existing" (option 1) AND "new filename" / "different name" / "rename" (option 2). Judge accepts paraphrase but rejects a menu that collapses to a single auto-overwrite choice.
- No `Write` or `Edit` of `redis-cache-stale-after-failover.md` appears in the tool-call log (skill must bail to the menu and wait — the downstream selection is out of scope for S3).
- The existing `redis-cache-stale-after-failover.md` file content is UNCHANGED (judge diffs the file pre/post and confirms zero modifications).
- No `Write` of any new file under `<canonical>/docs/runbooks/` appears (no premature creation of an alternative-filename file before the user picks).
- Target subagent's final assistant message names the existing-runbook path explicitly (so the user can identify what would have been overwritten).

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true AND the cross-scenario 6-section invariant is satisfied on every file written (S1, S2). If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>`.

The full eval is GREEN when all 3 scenarios PASS.

## Out of scope for this eval

- Runbook template fidelity (the exact placeholders in `templates/runbook.md.tmpl` if Phase 2 chose to template the structure — alternatively, the skill body inlines the section list) — covered by `tests/test-render.sh`. This eval asserts the 6 section headings appear with substantive content; full template-conformance is downstream.
- Runbook execution / operational use during incidents — operator behavior, not skill behavior.
- Cross-runbook linking (one runbook referencing another via `See also: docs/runbooks/<other>.md`) — deferred to v0.2; v0.1 authors standalone runbooks.
- Auto-extraction of symptoms/diagnosis content from prior incident postmortems — deferred to v0.2; v0.1 collects all content from the user during authoring.
- Runbook archival / retirement (marking a runbook as superseded or obsolete) — out of scope for v0.1.
- Manifest absence / corrupt-manifest behavior — `evals/planning-vertical-slice.md` S2 covers the absent-manifest refusal at the orchestrator entry point; if the user invokes this skill without a manifest, the same fail-fast applies but is not re-tested here.
- The append-vs-new-filename downstream branch of S3 — S3 verifies the menu is surfaced; option-selection behavior (e.g., appending a dated section vs picking a new name) is implementation downstream and would be exercised in a follow-up scenario if needed.
