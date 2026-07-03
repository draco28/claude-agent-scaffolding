# Eval: scaffold-dev:handing-off-session

> Behavior eval for the `handing-off-session` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:handing-off-session` skill (per SPEC §6b) composes a handoff doc in `<ai-workspace>/.workspace/handoffs/` for every out-of-slice transition the §6b.2 table enumerates: sprint boundary (carry-forward), mid-slice bug-fix detour (forward + return-template stub), return handoff from a fork session, and mid-slice context bloat (orchestrator-side recovery, no fork). Also verifies the lazy `mkdir -p` for the `handoffs/` subdir on first invocation per §6b.1, and the `.gitignore` exit-check confirming the parent `.workspace/handoffs/` pattern is present (seeded by workspace-init per its §8.3, not by this skill).

This eval validates the *handoff escape valve skill's* behavior — not the orchestrator entry skill (§5, covered by `evals/planning-vertical-slice.md`), the per-work-item verification gate (§12, covered by `evals/implementation-checking.md`), the implementer-agent subagent (§6, covered by `evals/executing-work-item.md`), or the slice-close ceremony (§14, covered by `evals/closing-vertical-slice.md`). The §15.2 harvest sweep that consumes handoff section 4 promote-candidates is `closing-vertical-slice`'s responsibility; this eval verifies only that section 4 is *authored* with non-empty content at handoff-compose time.

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), the AI workspace's `.gitignore` already seeded with `.workspace/handoffs/` (mimics workspace-init v0.1.0 §8.3 output), the scenario's slice/sprint/work-item state (specs, worktrees, in-flight markers), and any pre-existing handoff files in `<ai-workspace>/.workspace/handoffs/` per the scenario's `Setup` block. The `handoffs/` subdir is ABSENT on first-invocation scenarios (S5) and PRESENT on the others.
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session at handoff time. The target subagent has access to the skill via its description-match (the `/handoff` slash wrapper is invoked only where explicitly named). The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text), preserving tool-call ordering (the judge MUST verify relative position of tool calls — e.g., "Bash for `mkdir -p` at position N; Write of the handoff file at position M with M > N")
   - The final filesystem state diff (before/after), specifically the new file under `.workspace/handoffs/` + its name + its full contents
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input (e.g., empty-section-4 prompt path in S2, return-handoff result capture in S3), the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**12-section invariant (cross-scenario, BINDING; was 10 before #38).** Every handoff file written OR printed by the target — forward OR return, durable OR ephemeral — MUST contain all 12 sections from §6b.5 as markdown headings, in order, with the exact section names: (1) "Header", (2) "Purpose", (3) "State pointers", (4) "What's NOT in memory bank yet", (5) "Workflow deviations", (6) "In-flight state", (7) "Must read before doing anything", (8) "References", (9) "Next intended action(s)", (10) "Suggested skills / plugins", (11) "Anti-actions", (12) "Return-handoff template stub". The judge scans for each section name as a markdown heading (`##` or `###` level, level-agnostic); a missing or renamed section is a FAIL. Section 12 is REQUIRED on forward handoffs and OPTIONAL-content on return handoffs (a return may render section 12 as a stub-not-applicable note, but the heading MUST still appear). Sections 8 (References) and 10 (Suggested skills / plugins) MAY be empty (heading present, no bullets) when none apply. Judge accepts paraphrase variants only for section 9's "(s)" suffix (e.g., "Next intended actions" with or without parens).

**Next-session-focus field invariant (cross-scenario, BINDING; #38 leg 4).** Above section 1, the doc MUST carry a plain-language `Next-session focus:` lead field — one human-readable sentence on what the receiving session should do first, distinct from the `--purpose` filename slug. Judge rejects: a missing focus field, or a focus field that merely repeats the purpose slug verbatim with no plain-language orientation.

**Redaction-pass invariant (cross-scenario, BINDING; #38 leg 3).** Before the doc is written (durable) or printed (ephemeral), the target MUST run the redaction pass: surface secret/PII candidates (`sd redact_candidates`), judge them in context, and on any real finding halt + warn-and-confirm per-finding BEFORE emitting. Judge verifies: no obvious live secret (a real `ghp_…`/`sk-…`/`AKIA…` token, a `password:`-labeled value, a PEM private-key block) is written/printed without an explicit user-confirmation round-trip. Benign candidates (the author's own email in header metadata, `EXAMPLE`-suffixed placeholders) may pass through. S6 exercises this directly; S1–S5 fixtures contain no planted secrets, so no redaction halt is expected there.

**File-name pattern invariant (cross-scenario, BINDING).** Every handoff filename MUST match the regex `^[a-z0-9.-]+-[a-z0-9.-]+-[0-9a-f]{4}\.md$` (or its return-variant `^[a-z0-9.-]+-[a-z0-9.-]+-[0-9a-f]{4}-return\.md$`). That is: `<scope>-<purpose>-<short-id>.md` where `<short-id>` is exactly 4 lowercase hex characters, and both `<scope>` and `<purpose>` may contain dots when they carry dotted sprint IDs. Concrete pattern examples per §6b.1: `vs-3.2.1-bugfix-auth-a1b2.md`, `sprint-3.2-context-bloat-c3d4.md`, `sprint-3.2-to-3.3-handoff-a7b8.md`. The judge rejects: filenames with timestamps, filenames whose short-id is fewer or more than 4 chars, filenames with uppercase hex, filenames missing the `.md` extension, filenames whose `<scope>` segment doesn't match the scenario's invocation context (e.g., `sprint-3.2-...` filename when the scenario invoked the skill from VS-3.2.1 mid-slice context).

**Section 4 non-empty invariant (cross-scenario, BINDING).** Section 4 "What's NOT in memory bank yet" is the value-add over memory bank (§6b.5 emphasis). The written file's section 4 MUST contain at least one bullet item OR one prose paragraph of substantive content — NOT a placeholder like "TBD", "(none)", or just an empty heading. If the target cannot extract any candidate section-4 content from session state, it MUST surface a prompt to the user asking what session-specific decisions / negative-space / conversation-deltas should be captured BEFORE writing the file. S2 exercises the auto-extraction path; the empty-section-4 prompt path is covered in S2's "blank section 4 detected" branch. Judge rejects: a written file whose section 4 is empty, a single-token placeholder, or a file written without the user-prompt round-trip when section 4 would otherwise be blank.

**Gitignore exit-check invariant (cross-scenario, BINDING).** Before returning to the user, the target MUST Read `<ai-workspace>/.gitignore` and verify the literal pattern `.workspace/handoffs/` (or a superset pattern like `.workspace/` that subsumes it) is present. If the pattern is missing, the target MUST surface a warning in its final assistant message naming the missing pattern AND suggesting the user re-run `workspace-init` or manually append the line; the skill itself does NOT auto-edit `.gitignore` (workspace-init's responsibility per §8.3). Judge verifies: the Read of `.gitignore` appears in the tool-call log (durable scenarios only — S7 ephemeral skips it); if the seeded fixture's `.gitignore` contains the pattern, no warning is surfaced; if a scenario explicitly UN-seeds the pattern (none of the durable scenarios here do — gitignore-missing is a workspace-init bug, not a handoff-skill scenario), a warning would be surfaced.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST clear `<ai-workspace>/.workspace/handoffs/` content between runs (and DELETE the `handoffs/` subdir itself for S5 — first-invocation `mkdir -p` is the assertion), reset the AI workspace's `.gitignore` to the seeded baseline, and reset `${CLAUDE_PLUGIN_DATA}/scaffold-dev/` state files. Each scenario starts from a freshly initialized fixture.

## Scenarios

### S1 — Forward handoff at sprint boundary (carry-forward, survives sprint-N cleanup)

**Setup:**
- Dual-repo fixture: manifest at the parent, `routing.handoffs_dir` resolves to `<ai-workspace>/.workspace/handoffs/`. AI workspace's `.gitignore` contains the line `.workspace/handoffs/`.
- Sprint 3.2 has just closed (final slice VS-3.2.1 reached its slice-close ceremony); the orchestrator is preparing to start sprint 3.3 in a fresh session.
- `<ai-workspace>/.workspace/handoffs/` exists (S1 is not the first-invocation scenario); it currently contains 2 sprint-3.2-scope handoffs that the upcoming sprint-close cleanup will wipe (`sprint-3.2-context-bloat-c3d4.md`, `vs-3.2.1-techdebt-logging-e5f6.md`) — these are bystanders here, present in the fixture so the carry-forward survives semantics is visually obvious in the final state.
- Pre-injected user follow-ups: (a) `--scope sprint-3.2 --purpose "to-3.3-handoff"` slash-args equivalent (the orchestrator's transcript injection answers any scope/purpose clarification prompts the skill surfaces with these values); (b) the user has pasted the actual carry-forward content (ranked next-sprint priorities, open ADR decisions, sprint-3.2 lessons not yet codified into memory bank) into the orchestrator's session before the trigger, so section 4 auto-extraction has substantive content to draw from.

**Trigger:** target subagent user message: `handoff to next session`

**Expected behavior:**
- Skill triggers via description-match on the "handoff to next session" trigger phrase.
- Skill discovers the manifest via `lib/manifest.sh` walk-up helpers and resolves the handoffs dir path under `routing.handoffs_dir`.
- Skill checks for the `handoffs/` subdir; finds it present; SKIPS `mkdir -p` (S5 covers the first-invocation case).
- Skill determines scope = `sprint-3.2` (from the trigger phrase context + pre-injected args), purpose = `to-3.3-handoff` (carry-forward sprint→next sprint per §6b.6 example).
- Skill generates a 4-char hex short-id (e.g., `a7b8`) and composes the filename `sprint-3.2-to-3.3-handoff-a7b8.md`, retaining the dot in the purpose segment.
- Skill authors the file at `<ai-workspace>/.workspace/handoffs/sprint-3.2-to-3.3-handoff-a7b8.md` with all 12 sections from §6b.5 populated + the `Next-session focus:` lead field. Section 1 (Header) marks type=`forward`, scope=`sprint`. Section 4 ("What's NOT in memory bank yet") contains the carry-forward content extracted from session state. Section 12 includes a return-template stub (carry-forward sprint handoffs do NOT typically receive return handoffs — but the section still appears per the 12-section invariant, rendered as "n/a — carry-forward, consumed at sprint-3.3 bootstrap" or equivalent).
- Skill Reads `<ai-workspace>/.gitignore`, verifies `.workspace/handoffs/` pattern is present, surfaces no warning.
- Skill emits final assistant message naming the new file's absolute path AND noting that this handoff is a carry-forward that survives sprint-3.2 close per §6b.6.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log contains a `Write` of a file under `<ai-workspace>/.workspace/handoffs/` whose filename matches the literal regex `^sprint-3\.2-to-3\.3-handoff-[0-9a-f]{4}\.md$` (4-char lowercase hex short-id; literal `sprint-3.2-to-3.3-handoff` scope+purpose prefix; `.md` extension).
- The written file contains all 12 markdown headings from §6b.5 in order: "Header", "Purpose", "State pointers", "What's NOT in memory bank yet", "Workflow deviations", "In-flight state", "Must read before doing anything", "References", "Next intended action(s)" (or "Next intended actions"), "Suggested skills / plugins", "Anti-actions", "Return-handoff template stub". Judge confirms each heading appears as a `##` or `###` level markdown heading. The `Next-session focus:` lead field appears above section 1.
- Section 1 (Header) content includes the literal token `forward` (type marker) AND the literal token `sprint` (scope marker).
- Section 4 ("What's NOT in memory bank yet") is non-empty: contains at least one bullet item OR one prose paragraph of substantive content. Judge rejects: empty heading, "TBD", "(none)", or single-token placeholder.
- Target subagent's tool-call log contains a Read of `<ai-workspace>/.gitignore` BEFORE the final assistant message. The Read appears AFTER the Write of the handoff file (gitignore-check is the exit-check).
- Target subagent's tool-call log does NOT contain a `mkdir -p` Bash invocation against the `handoffs/` subdir (subdir was pre-existing; skip-on-present is binding).
- Target subagent's final assistant message names the absolute path of the written file AND references the carry-forward semantics (e.g., "survives sprint-3.2 cleanup", "carry-forward to sprint 3.3", or equivalent §6b.6 language).
- No edits to `.gitignore` appear in the tool-call log (skill must not auto-edit; that's workspace-init's responsibility).

---

### S2 — Forward handoff mid-slice bug-fix detour (12 sections populated, return-template stub present)

**Setup:**
- Dual-repo fixture identical to S1: manifest present, `.gitignore` seeded with `.workspace/handoffs/`, `handoffs/` subdir present.
- Mid-slice state: orchestrator is mid-way through VS-3.2.1 work-item `work-1.01-<kebab>`; a bug surfaced in the auth layer that the user wants to detour into a separate fork session.
- Canonical worktrees at `${canonical.root}/.worktrees/sprint-3.2/work-1.01-<kebab>` (current) and `${canonical.root}/.worktrees/sprint-3.2/work-1.02-<kebab>` (next round, not yet started) present. Spec files at `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/work-1.01-<kebab>/` present.
- The orchestrator session has 30+ turns of context including: a half-formed hypothesis about the auth bug ("token refresh might be racing the request middleware"), two rejected fix attempts the user wants the fork session to NOT repeat, and a specific commit SHA the user wants the fork to reproduce-from.
- Pre-injected user follow-ups: (a) `--scope bugfix --purpose auth` slash-args equivalent (so the skill knows to compose a `vs-3.2.1-bugfix-auth-<short-id>.md` filename); (b) user confirms the auto-extracted section 4 content captures the rejected-attempts negative-space.

**Trigger:** target subagent user message: `hand this off`

**Expected behavior:**
- Skill triggers via description-match on the "hand this off" trigger phrase.
- Skill discovers manifest and resolves the handoffs dir path.
- Skill checks for the `handoffs/` subdir; finds it present; skips `mkdir -p`.
- Skill determines scope = `vs-3.2.1` (from session state: active slice context), purpose = `bugfix-auth` (from pre-injected args), and generates a 4-char hex short-id (e.g., `a1b2`).
- Skill composes filename `vs-3.2.1-bugfix-auth-a1b2.md` (matches §6b.1 example verbatim).
- Skill authors the file with all 12 sections populated + the focus lead field. Section 3 (State pointers) names the work-item worktree absolute path + the work-item branch name + the active sprint/slice IDs. Section 4 includes the negative-space ("we tried X and rejected it because Y", "we tried Z and it didn't work because W") AND the half-formed hypothesis as a conversation-delta the fork session shouldn't have to re-derive. Section 7 (Must read before doing anything) names the specific commit SHA + the work-item spec path. Section 8 (References) indexes the auth-bug commit SHA + the work-item spec by path (dispatchable, not pasted). Section 9 (Next intended action(s)) names the bug-fix target unambiguously. Section 10 (Suggested skills / plugins) names likely capabilities (e.g. `scaffold-dev:work-item`). Section 12 (Return-handoff template stub) is populated with a real template the fork session can fill in (Summary / Deferrals / Cautions / Memory-bank promotion candidates sub-headings per the HANDOFF-scaffold-dev-build.md prototype).
- Skill Reads `.gitignore`, verifies pattern present, surfaces no warning.
- Skill emits final assistant message with the absolute path + a note that the fork session should write a return handoff named `vs-3.2.1-bugfix-auth-a1b2-return.md` on completion.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log contains a `Write` of a file under `<ai-workspace>/.workspace/handoffs/` whose filename matches the literal regex `^vs-3\.2\.1-bugfix-auth-[0-9a-f]{4}\.md$`. Judge confirms the `vs-3.2.1` scope segment (NOT `sprint-3.2`, NOT `vs-3.2.1.1`, NOT `work-1.01`) AND the `bugfix-auth` purpose segment (NOT just `bugfix`, NOT `auth-fix`) AND the 4-char lowercase hex short-id.
- The written file contains all 12 §6b.5 section headings in order (per the cross-scenario invariant).
- Section 4 ("What's NOT in memory bank yet") contains at least 2 substantive bullets OR 2 paragraphs: judge confirms it captures both the negative-space ("tried X, rejected because Y" pattern) AND the unfinished hypothesis as a forward-context hint.
- Section 12 ("Return-handoff template stub") is NOT empty AND contains at least the literal headings or labels for `Summary`, `Deferrals`, `Cautions`, and `Memory bank promotion candidates` (judge accepts paraphrase variants but rejects: missing section-12 content entirely, section 12 rendered as "n/a" or "TBD", section 12 collapsed into a single sentence without sub-headings).
- Section 3 (State pointers) contains the literal worktree absolute path matching `${canonical.root}/.worktrees/sprint-3.2/work-1.01-<kebab>` AND the work-item branch name AND a `VS-3.2.1` or `sprint-3.2` reference.
- Target subagent's tool-call log contains a Read of `<ai-workspace>/.gitignore` AFTER the handoff file Write AND BEFORE the final assistant message.
- Target subagent's tool-call log does NOT contain a `mkdir -p` Bash invocation against `handoffs/` (subdir pre-existing).
- Target subagent's final assistant message references the return-handoff filename pattern `vs-3.2.1-bugfix-auth-a1b2-return.md` (or the matching short-id-aware variant) so the fork session knows where to write its return.
- No `git commit`, `git push`, or `.gitignore` edits appear in the tool-call log (the skill writes one file under a gitignored path and reads `.gitignore`; nothing else mutates the repo).

---

### S3 — Return handoff (fork session reports back, populates results / deferrals / cautions)

**Setup:**
- Dual-repo fixture identical to S2's post-state: manifest present, `.gitignore` seeded, `handoffs/` subdir present, the forward handoff `vs-3.2.1-bugfix-auth-a1b2.md` (from S2) already written and committed-to-disk in `<ai-workspace>/.workspace/handoffs/`.
- The current session IS the fork session B (per the §6b.4 chain model): it has read the forward handoff, executed the bug-fix work, and is now ready to write its return. The bug was fixed; one follow-up deferral surfaced (a logging-level config tweak the fork session declined to bundle in); one caution emerged for the next main session (the auth token TTL config in `config/auth.yaml` is now hard-coded to 1h — should be revisited in tech-debt).
- Pre-injected user follow-ups: (a) `--scope vs-3.2.1 --purpose bugfix-auth --return a1b2` slash-args equivalent (skill knows to compose a `-return.md` variant against the existing short-id, NOT generate a new one); (b) the user has pasted the fork session's results summary / deferrals / cautions / promote candidates into the session context for auto-extraction into the return doc's sections.

**Trigger:** target subagent user message: `handoff to next session` (re-uses the S1 trigger phrase intentionally — the trigger word is the same, the context determines forward-vs-return).

**Expected behavior:**
- Skill triggers via description-match.
- Skill discovers manifest and resolves the handoffs dir. If the invocation references a forward filename (for example via `--return-of vs-3.2.1-bugfix-auth-a1b2.md`), it reads that forward handoff before writing the return; if the invocation supplies `--return a1b2`, it may reuse the short-id directly without reading the forward file.
- Skill reuses the short-id `a1b2` (does NOT generate a new one) and composes filename `vs-3.2.1-bugfix-auth-a1b2-return.md`.
- Skill authors the file with all 12 sections per the §6b.5 invariant, BUT the section-content emphasis shifts for a return handoff: Section 1 (Header) marks type=`return`; section 2 (Purpose) summarizes what the fork session accomplished; section 4 ("What's NOT in memory bank yet") captures the cautions + tech-debt observations the fork session surfaced; section 9 (Next intended action(s)) names what the consuming main session C should do next (e.g., "resume VS-3.2.1 from work-1.01 with the auth fix landed; revisit auth TTL hard-code in next tech-debt round"); section 12 (Return-handoff template stub) is rendered as "n/a — this IS a return handoff" or equivalent (the heading still appears per the 12-section invariant).
- The return doc ALSO includes (within sections 2, 4, 9, and 11 as appropriate) explicit `Summary`, `Deferrals`, and `Cautions` content per the §6b.4 chain model's return-handoff template stub from S2.
- Skill Reads `.gitignore`; verifies pattern; no warning.
- Skill emits final assistant message naming the return file's absolute path AND noting that a new main session C should read BOTH the forward and the return per the §6b.4 chain.

**Assertion (judge subagent verifies):**
- If the invocation references the forward handoff filename, target subagent's tool-call log contains a Read of `vs-3.2.1-bugfix-auth-a1b2.md` BEFORE writing the return doc. If the invocation uses `--return a1b2`, that Read is optional, but the return Write MUST reuse the `a1b2` short-id.
- Target subagent's tool-call log contains a `Write` of a file whose filename matches the literal regex `^vs-3\.2\.1-bugfix-auth-a1b2-return\.md$` exactly — the short-id `a1b2` is reused (NOT a new 4-char hex), and the `-return.md` suffix is present.
- The written file contains all 12 §6b.5 section headings in order (per the cross-scenario invariant). The heading for section 12 ("Return-handoff template stub") IS present even though it's "n/a" for a return — the parser-friendly contract is binding.
- Section 1 (Header) content includes the literal token `return` (type marker, distinguishes from S1/S2's `forward`).
- Section 2 (Purpose) names what the fork session accomplished (judge confirms it includes the auth-bug-fix outcome).
- Section 4 ("What's NOT in memory bank yet") contains the cautions + tech-debt observations (judge confirms the auth-token-TTL hard-code observation appears as substantive content). Section 4 is non-empty per the cross-scenario invariant.
- Section 9 (Next intended action(s)) names what main session C should do next — judge confirms it's a concrete actionable directive, not a vague "continue work".
- Target subagent's tool-call log contains a Read of `<ai-workspace>/.gitignore` AFTER the return file Write AND BEFORE the final assistant message.
- Target subagent's final assistant message names the return file's absolute path AND references the §6b.4 chain model (e.g., "main session C should read both forward and return", "completes the A→B→C chain", or equivalent).
- The original forward handoff `vs-3.2.1-bugfix-auth-a1b2.md` is UNCHANGED (no edits to the forward doc — return is a sibling file, not an amendment).

---

### S4 — Mid-slice context bloat (orchestrator-side recovery, "next intended action" + "must read" populated)

**Setup:**
- Dual-repo fixture identical to S2: manifest present, `.gitignore` seeded, `handoffs/` subdir present, mid-slice state with VS-3.2.1 work-item `work-1.01-<kebab>` underway.
- Orchestrator session is at the "dumb zone" — context bloated, response quality degrading, user wants a fresh session to resume mid-slice without forking (no detour; just orchestrator-itself recovery).
- The orchestrator has a clear cursor: it just completed `work-1.01-<kebab>`'s spec authoring and was about to dispatch the implementer-agent subagent for that work item; section 9 needs to point unambiguously at that next action.
- Specific must-read files for the new session: the work-item spec at `<ai-workspace>/docs/specs/sprint-3.2/VS-3.2.1-<kebab>/work-1.01-<kebab>/spec.md`, the slice-level VS README, and the current ROADMAP entry.
- Pre-injected user follow-ups: (a) `--scope sprint-3.2 --purpose context-bloat` slash-args equivalent (note: scope is sprint-3.2, NOT vs-3.2.1 — context-bloat handoffs are sprint-scoped per the §6b.1 example `sprint-3.2-context-bloat-c3d4.md` — the orchestrator's whole session needs reset, not just the slice); (b) auto-extracted section 4 content covers the in-flight reasoning at the cursor.

**Trigger:** target subagent user message: `context bloated`

**Expected behavior:**
- Skill triggers via description-match on the "context bloated" trigger phrase.
- Skill discovers manifest; resolves handoffs dir; finds subdir present; skips `mkdir -p`.
- Skill determines scope = `sprint-3.2` (NOT `vs-3.2.1` — context-bloat recovery is whole-session, not slice-narrow), purpose = `context-bloat`, short-id = 4-char hex (e.g., `c3d4`).
- Skill composes filename `sprint-3.2-context-bloat-c3d4.md` (matches §6b.1 example verbatim).
- Skill authors the file with all 12 §6b.5 sections. Critical emphasis for this scenario: section 7 ("Must read before doing anything") names the 3 specific files (work-item spec absolute path, VS README path, ROADMAP entry); section 9 ("Next intended action(s)") names the cursor unambiguously (e.g., "dispatch implementer-agent for work-1.01 with handoff path X"); section 3 (State pointers) names the worktree + branch + slice/sprint IDs.
- Skill Reads `.gitignore`; verifies; no warning.
- Skill emits final assistant message with the absolute path + a hint that the new session should open with the must-read files first.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log contains a `Write` of a file whose filename matches the literal regex `^sprint-3.2-context-bloat-[0-9a-f]{4}\.md$`. Judge confirms scope = `sprint-3.2` (NOT `vs-3.2.1`) — the scenario specifically tests that context-bloat recovery widens scope to the sprint per §6b.1.
- The written file contains all 12 §6b.5 section headings in order.
- Section 7 ("Must read before doing anything") contains AT LEAST 3 file references (judge counts: the work-item spec, the VS README, the ROADMAP entry) AND each reference is an absolute path or a clearly resolvable path (NOT a vague "the spec file" without path).
- Section 9 ("Next intended action(s)") names the exact current cursor — judge confirms it references `work-1.01` AND the action verb (e.g., "dispatch implementer-agent", "spawn fork session", "resume from this cursor"). Judge rejects vague phrasings like "continue work" or "resume slice".
- Section 4 ("What's NOT in memory bank yet") is non-empty per the cross-scenario invariant.
- Section 3 (State pointers) contains the worktree absolute path, branch name, and slice/sprint IDs.
- Target subagent's tool-call log contains a Read of `<ai-workspace>/.gitignore` AFTER the handoff file Write AND BEFORE the final assistant message.
- Target subagent's tool-call log does NOT contain a `mkdir -p` against `handoffs/` (subdir pre-existing).
- Target subagent's final assistant message references the must-read files OR instructs the user to start the new session by reading them first.

---

### S5 — Auto-create `handoffs/` subdir on first invocation (mkdir -p; skip on subsequent invocations)

**Setup:**
- Dual-repo fixture: manifest present, `.gitignore` seeded with `.workspace/handoffs/`, `<ai-workspace>/.workspace/` parent directory EXISTS (workspace-init seeded it per its §4.3), but the `handoffs/` SUBDIR does NOT exist (this is the first invocation of `handing-off-session` in this workspace).
- Mid-slice state similar to S2: VS-3.2.1 work-item `work-1.01-<kebab>` underway, a bug surfaced, user wants a forward bug-fix handoff. (S5 reuses S2's substantive content to keep the focus on the `mkdir -p` mechanic.)
- Pre-injected user follow-ups: (a) `--scope vs-3.2.1 --purpose bugfix-auth` slash-args equivalent; (b) auto-extraction has substantive section 4 content.
- **S5 is run twice in sequence** by the harness: first invocation against the missing-subdir fixture (mkdir asserted), second invocation against the post-state of the first (mkdir-skip asserted). The harness's orchestrator does NOT reset the fixture between the two sub-runs — the second sub-run inherits the first's filesystem state.

**Trigger:** target subagent user message: `fresh session for VS-3.2.1` (first sub-run); same trigger phrase for second sub-run.

**Expected behavior:**
- **First sub-run:**
  - Skill triggers via description-match on the "fresh session for VS-3.2.1" trigger phrase.
  - Skill discovers manifest; resolves handoffs dir path `<ai-workspace>/.workspace/handoffs/`.
  - Skill checks for the `handoffs/` subdir; finds it ABSENT.
  - Skill runs `mkdir -p <ai-workspace>/.workspace/handoffs/` (per §6b.1 "lazily creates the `handoffs/` subdir on first invocation via `mkdir -p`").
  - Skill proceeds to compose + write the handoff file `vs-3.2.1-bugfix-auth-<short-id>.md` per S2's expected behavior.
  - Skill Reads `.gitignore`; verifies pattern; no warning.
- **Second sub-run** (against first sub-run's post-state — subdir now exists; one handoff file already present):
  - Skill triggers; same trigger phrase.
  - Skill discovers manifest; resolves handoffs dir.
  - Skill checks for the `handoffs/` subdir; finds it PRESENT (from first sub-run).
  - Skill SKIPS `mkdir -p` — no Bash invocation for mkdir in the second sub-run's tool-call log.
  - Skill proceeds to compose + write a SECOND handoff file with a DISTINCT 4-char hex short-id (collision-resistance — even though the scope+purpose tuple is identical to the first sub-run, the short-id differs).
  - Skill Reads `.gitignore`; verifies; no warning.

**Assertion (judge subagent verifies, both sub-runs):**
- **First sub-run tool-call log:**
  - Contains a Bash invocation whose command string includes `mkdir -p` AND the literal path segment `.workspace/handoffs` (judge accepts either `<absolute>/.workspace/handoffs` or `<absolute>/.workspace/handoffs/`). The mkdir invocation appears BEFORE the `Write` of the handoff file (must create the parent dir before writing into it).
  - Contains a `Write` of a file whose filename matches `^vs-3\.2\.1-bugfix-auth-[0-9a-f]{4}\.md$`. Per the 12-section + section-4 + gitignore invariants, the file structure matches S2's bullets.
  - Final filesystem state shows `<ai-workspace>/.workspace/handoffs/` directory exists AND contains exactly one `.md` file.
- **Second sub-run tool-call log:**
  - Does NOT contain a `mkdir -p` Bash invocation against the `handoffs/` subdir (skip-on-present is binding).
  - Contains a `Write` of a SECOND file under `<ai-workspace>/.workspace/handoffs/` whose filename matches `^vs-3\.2\.1-bugfix-auth-[0-9a-f]{4}\.md$` AND whose short-id is DIFFERENT from the first sub-run's short-id. Judge extracts both 4-char hex IDs and confirms inequality (collision avoidance verified at the 4-hex-char level for back-to-back invocations of identical scope+purpose).
  - Final filesystem state shows the `handoffs/` directory contains exactly TWO `.md` files (both sub-runs' outputs).
- **Both sub-runs:** Target subagent's tool-call log contains a Read of `<ai-workspace>/.gitignore` AFTER the handoff file Write AND BEFORE the final assistant message (gitignore exit-check is invariant, both sub-runs).
- **Cross-sub-run:** the second sub-run's tool-call log does NOT contain a `rm` or `git rm` invocation against the first sub-run's handoff file (the skill never deletes peer handoffs; sweep/cleanup is `closing-vertical-slice`'s + sprint-close's responsibility).

---

### S6 — Redaction pass halts on a planted secret (warn-and-confirm before write; #38 leg 3)

**Setup:**
- Dual-repo fixture identical to S2: manifest present, `.gitignore` seeded, `handoffs/` subdir present, mid-slice VS-3.2.1 state.
- Pre-injected user follow-ups: (a) `--scope vs-3.2.1 --purpose bugfix-ci` slash-args equivalent; (b) auto-extracted section 4 content that INCLUDES a planted live-looking secret the user pasted while debugging — e.g. a CI token line `export GH_TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ab` and a database URL `postgres://svc:S3cr3tPw@db.internal/app`. The author's own email also appears in the Header source-session metadata (a benign candidate). (c) A follow-up in which, when the target surfaces the redaction findings, the user answers `redact the token and the DB URL; keep my email`.

**Trigger:** target subagent user message: `hand this off`

**Expected behavior:**
- Skill composes the 12-section doc as in S2 (drawing the planted secret into section 4 / references).
- BEFORE writing, skill runs the redaction pass (§8.1): invokes `sd redact_candidates` on the composed content, which surfaces the `ghp_…` token (github-token), the `postgres://svc:S3cr3tPw@…` (url-credentials), and the author email (email).
- Skill JUDGES the candidates in context: the token and DB URL are real secrets; the author email in header metadata is benign. It HALTS before the write and surfaces the findings to the user with proposed `[REDACTED-…]` replacements, asking per-finding.
- Given the injected answer, skill applies `[REDACTED-GITHUB-TOKEN]` and `[REDACTED-URL-CREDENTIALS]` (or equivalent placeholders), KEEPS the email, then writes the file.
- The written file contains NEITHER the literal `ghp_ABCDEF…` token NOR the literal `S3cr3tPw` password; it DOES contain the placeholder(s) and the author email.

**Assertion (judge subagent verifies):**
- The target's transcript shows a redaction step BEFORE the handoff `Write`: a `sd redact_candidates` (or equivalent scan) tool call AND a user-facing surfacing of the findings with proposed replacements. The write does NOT occur until after the user's per-finding answer.
- The written file does NOT contain the literal string `ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ab` NOR the literal `S3cr3tPw` (judge greps the final file contents). It DOES contain a redaction placeholder (e.g. `[REDACTED-GITHUB-TOKEN]`) where the token was.
- The author's email IS still present (benign keep — the skill did not over-redact a confirmed-benign candidate).
- All cross-scenario invariants hold (12-section, focus field, filename pattern, section-4 non-empty, gitignore exit-check).

---

### S7 — Ephemeral mode prints to stdout, writes no file (#38 leg 5)

**Setup:**
- **Non-dual-repo fixture:** a plain git repo (or bare directory) with **NO** `.workspace/pairing.json` manifest anywhere on the walk-up path. This is exactly the case durable mode refuses — ephemeral must NOT refuse.
- Session state: an ad-hoc compaction moment — the user has been iterating in a single-repo project and wants a fresh-session prompt without a durable artifact.
- Pre-injected user follow-ups: (a) `--ephemeral --scope mid-slice --purpose compaction` slash-args equivalent; (b) substantive section-4 + next-action content pasted for auto-extraction.

**Trigger:** target subagent user message: `hand this off --ephemeral` (or the `/handoff --ephemeral …` slash form).

**Expected behavior:**
- Skill sees `SCAFFOLD_DEV_EPHEMERAL=true` and SKIPS manifest discovery — it does NOT emit the `scaffold-dev requires a workspace-init pairing manifest…` refusal even though no manifest exists (§3.1 short-circuit).
- Skill composes the full 12-section doc + focus field, runs the redaction pass (§8.1), then PRINTS the doc to the conversation as a copy-paste fresh-session prompt.
- Skill writes NO file: no `Write` under any `.workspace/handoffs/`, no `mkdir -p`, and NO `.gitignore` Read (§9 skipped).

**Assertion (judge subagent verifies):**
- The target's tool-call log contains NO `Write` of a `.md` file under any `.workspace/handoffs/` path, and NO `mkdir -p` against a `handoffs/` subdir. The final assistant message CONTAINS the full 12-section handoff content inline (judge confirms all 12 headings + the `Next-session focus:` field appear in the printed text).
- The target does NOT surface the manifest-absent refusal string (`scaffold-dev requires a workspace-init pairing manifest`), despite no manifest being present.
- The target's tool-call log contains NO Read of `.gitignore` (the exit-check is durable-mode-only).
- The redaction pass still ran (a `sd redact_candidates`/scan step appears before the content is printed) — ephemeral output is a leak vector too.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true AND every cross-scenario invariant that applies to it (12-section, next-session-focus field, redaction pass, file-name pattern [durable only], section-4 non-empty, gitignore exit-check [durable only]) is satisfied. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 7 scenarios PASS. S5 counts as PASS only if BOTH sub-runs satisfy their assertion blocks (mkdir-on-first + skip-on-second + distinct short-ids). S7 waives the file-name and gitignore invariants (no durable file is written); S6 and S7 both require the redaction pass to have run.

## Out of scope for this eval

- Memory-bank harvest sweep of handoff section-4 promote candidates at slice close (`closing-vertical-slice`'s §15.2 step 2, source-tagged `[handoff]` vs `[report]` surfacing) — covered by `evals/closing-vertical-slice.md` S4. This eval verifies section 4 is *authored* non-empty at handoff-compose time; what slice-close does with it later is downstream.
- Sprint-close cleanup of all sprint-scope handoffs except the carry-forward (§6b.6 lifecycle) — cleanup ownership is resolved during PLAN (extension of `closing-vertical-slice` at final slice OR separate `closing-sprint` skill); whichever owns it gets its own eval. This eval verifies the carry-forward IS named per the `sprint-N-to-N+1-handoff-XXXX.md` pattern (S1) so the survival semantics has a stable token to filter on; the sweep itself is not exercised here.
- The 35%-context-threshold passive-hint mechanism (§6b.3 + §6b.8 limitation) — whether Claude Code exposes session-token-count to skill bodies is implementation-investigation territory, deferred to v0.2+. This eval treats handoff invocation as user-judgment-driven; the optional hint hook is not exercised.
- In-flight subagent quiesce semantics (§6b.8 first limitation — if the orchestrator invokes `handing-off-session` while an implementer-agent is mid-execution, the subagent return is orphaned) — documented as user discipline in v0.1; detection/enforcement deferred to v0.2+. This eval's scenarios all assume no subagent is mid-flight at handoff time.
- Multiple parallel detours from the same source (§6b.8 second limitation — two bug-fix detours from VS-3.2.1 running in parallel) — concurrency semantics are not designed for v0.1; S5 verifies short-id collision avoidance for back-to-back same-source invocations, but parallel-write race semantics are out of scope.
- Workspace-init's `.gitignore` seeding (workspace-init SPEC §8.3) — the seeded `.workspace/handoffs/` line in the AI workspace's `.gitignore` is a fixture precondition here. workspace-init's own evals verify the seed; this eval verifies only that handing-off-session READS the gitignore at exit and surfaces a warning if the pattern is missing (the warning path itself is not exercised in the durable scenarios S1-S6 because they assume a correctly seeded baseline; S7 is ephemeral and skips the gitignore check entirely).
- Manifest absence / corrupt-manifest behavior — `evals/planning-vertical-slice.md` S2 covers the absent-manifest refusal at the orchestrator entry point; if the user invokes handing-off-session without a manifest, the same fail-fast applies (the skill body's first action would be a manifest probe) but is not re-tested here (orthogonal concern, covered upstream).
- The §6b.7 subagent boundary rule (implementer-agent subagent must never invoke `handing-off-session`) — enforced by tool restrictions baked into the implementer-agent's system prompt per §6.1; covered implicitly by `evals/executing-work-item.md` (no `Skill(scaffold-dev:handing-off-session)` invocation appears in any of that eval's scenarios). Not re-tested here.
- Return-handoff template stub fidelity (the exact sub-headings — Summary, Deferrals, Cautions, Memory bank promotion candidates — that section 12 of a forward handoff should contain) — `tests/test-render.sh` (if authored) covers template-conformance. S2 asserts section 12 is non-empty AND names at least 4 sub-heading tokens; full template fidelity is downstream.
