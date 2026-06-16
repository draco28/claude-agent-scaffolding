# Eval: scaffold-dev:recording-architecture-decision

> Behavior eval for the `recording-architecture-decision` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-dev:recording-architecture-decision` skill (per SPEC §7.1) authors a new MADR-lite ADR file under the manifest-routed target directory: product ADRs (architectural decisions about the user's project) route to `canonical` per `routing.product_adrs`; process ADRs (decisions about the agent-workflow itself) route to `ai_workspace` per `routing.process_adrs`. Also verifies that the skill scans existing `adr-NNNN-*.md` files to pick the next ADR number, renders the four MADR-lite sections (status, context, decision, consequences) via `templates/adr.md.tmpl`, and refuses to proceed when neither manifest-routing field resolves (the ADR dir is required, not optional).

This eval validates the *ADR-authoring skill's* behavior — not slice-close ADR harvest (no automatic ADR generation in v0.1; ADRs are user-invoked) and not architect-critic principle promotion (covered by architect-critic's own `promoting-principle` eval).

## Harness

Each scenario is executed inside a single Claude Code subscription session by an orchestrator. The orchestrator is a top-level conversation (or a dispatching subagent) that runs three steps per scenario:

1. **Setup** — orchestrator (or a setup subagent it dispatches) prepares the fixture: tmp dual-repo workspace (canonical + AI workspace siblings with a `.workspace/pairing.json` manifest at the parent), the target ADR directories per the scenario's routing config, any pre-existing `adr-NNNN-*.md` files described in the scenario's `Setup` block, and the `templates/adr.md.tmpl` file present in the plugin (template-rendering fidelity is downstream of this eval but the template must exist for the skill to render).
2. **Trigger** — orchestrator dispatches a fresh **target subagent** with the trigger phrase as the user message and instructs it to act as if it were the user-facing Claude session. The target subagent has access to the skill via its description-match. The orchestrator captures the subagent's tool calls, transcript, and final filesystem state.
3. **Judge** — orchestrator dispatches a **judge subagent** with:
   - The scenario's `Expected behavior` and `Assertion` text
   - The target subagent's full transcript (tool calls + assistant text)
   - The final filesystem state diff (before/after), specifically any new file under the resolved ADR dir + its filename + its full contents
   The judge returns `PASS` (all assertion bullets satisfied) or `FAIL: <specific deviation>`.

**No external CLI.** All evaluation happens through Claude Code Agent dispatch. The judge is an LLM scoring against natural-language assertions — there are no bash truthy-tests in this doc.

**Multi-turn dialogs:** when a scenario requires the target subagent to pause for user input (e.g., the product-vs-process disambiguation prompt, the title prompt), the orchestrator pre-loads the user's follow-up responses in the dispatch prompt (as a "transcript injection") rather than waiting for interactive input. The judge subagent verifies the target's behavior matches the expected flow given the pre-injected responses.

**Reproducibility note:** scenarios are independent; ordering does not matter. The orchestrator MUST reset the target ADR directories' content between runs so the "next ADR number" computation has a known prior state. Each scenario starts from a freshly initialized fixture.

## Scenarios

### S1 — Product ADR (manifest-routed to canonical, next number computed from existing files)

**Setup:**
- Dual-repo fixture: manifest at the parent, `routing.product_adrs` resolves to `<canonical>/docs/adr/`, `routing.process_adrs` resolves to `<ai-workspace>/docs/adr/`.
- `<canonical>/docs/adr/` exists and contains 2 existing files: `adr-0001-record-architecture-decisions.md` (the seed entry from scaffold-onboard's `/scaffold-docs` output) and `adr-0002-choose-postgres-over-mysql.md`.
- `<ai-workspace>/docs/adr/` exists and contains 1 existing file: `adr-0001-dual-repo-topology.md` (process ADR from earlier scaffold-onboard onboarding). This sibling state is fixture noise — the product-ADR numbering MUST NOT cross-count with the process-ADR series.
- `scaffold-dev/templates/adr.md.tmpl` is present in the plugin.
- Pre-injected user follow-ups: (a) "product ADR" when the skill prompts for the product-vs-process disambiguation; (b) "use redis for session cache" when the skill prompts for the kebab-case title; (c) the user pastes a 2-paragraph context + 1-paragraph decision + 3-bullet consequences block as authoring content.

**Trigger:** target subagent user message: `record ADR`

**Expected behavior:**
- Skill triggers via description-match on the "record ADR" trigger phrase (per SPEC §7.1 triggers list).
- Skill prompts the user to disambiguate product-vs-process; user responds "product ADR".
- Skill discovers the manifest via `lib/manifest.sh` walk-up helpers (not raw inline jq) and resolves `routing.product_adrs` to `<canonical>/docs/adr/`.
- Skill scans the resolved dir for existing `adr-NNNN-*.md` files; finds `0001` and `0002`; picks `0003` as the next number.
- Skill prompts for a kebab-case title; user responds "use redis for session cache"; skill composes filename `adr-0003-use-redis-for-session-cache.md`.
- Skill renders `templates/adr.md.tmpl` with the user-provided context/decision/consequences content and the MADR-lite four sections.
- Skill writes the file at `<canonical>/docs/adr/adr-0003-use-redis-for-session-cache.md`.
- Skill emits a final assistant message naming the new file's absolute path.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log shows at least one Bash invocation that sources or calls into `lib/manifest.sh` (e.g., a function name matching `sd_manifest_*` or `mi_manifest_*`); no raw `jq -r '.routing.product_adrs' .workspace/pairing.json` style inline reads appear.
- Target subagent's assistant transcript contains an explicit prompt asking the user to choose product vs process (e.g., "Is this a product ADR or a process ADR?" or equivalent) — judge rejects: skill auto-selects without prompting.
- Target subagent's tool-call log contains a directory listing (Read of dir, `ls`, or glob) of `<canonical>/docs/adr/` BEFORE the file Write — confirming the next-number scan happened.
- Target subagent's tool-call log contains a `Write` of a file under `<canonical>/docs/adr/` (NOT under `<ai-workspace>/docs/adr/`) whose filename matches the literal regex `^adr-0003-use-redis-for-session-cache\.md$`. Judge confirms: number is exactly `0003` (NOT `0002` — would collide; NOT `0004` — would skip; NOT cross-counted with the process-ADR `0001` next door).
- The written file contains the four MADR-lite section headings as markdown `##` or `###` headings: `Status`, `Context`, `Decision`, `Consequences` (judge accepts case-insensitive variants and the "Status" heading may appear as a field in a metadata block instead of a `##` heading — but the other three MUST appear as headings).
- Target subagent's final assistant message names the absolute path of the written file.
- No `Write` or `Edit` appears against the `<ai-workspace>/docs/adr/` directory (routing must not leak across the product/process boundary).

---

### S2 — Process ADR (manifest-routed to AI workspace, fresh series — number `0002`)

**Setup:**
- Dual-repo fixture identical to S1: same manifest, same routing fields, `templates/adr.md.tmpl` present.
- `<canonical>/docs/adr/` contains the same 2 files as S1 (fixture noise — product-ADR numbering not exercised this scenario).
- `<ai-workspace>/docs/adr/` contains 1 existing file: `adr-0001-dual-repo-topology.md` (the only prior process ADR).
- Pre-injected user follow-ups: (a) "process ADR" when prompted for the disambiguation; (b) "switch implementer subagent to opus-4-7" when prompted for the kebab-case title; (c) user-provided context/decision/consequences content.

**Trigger:** target subagent user message: `log this decision`

**Expected behavior:**
- Skill triggers via description-match on the "log this decision" trigger phrase.
- Skill prompts product-vs-process; user responds "process ADR".
- Skill discovers manifest and resolves `routing.process_adrs` to `<ai-workspace>/docs/adr/`.
- Skill scans the resolved dir for existing `adr-NNNN-*.md` files; finds `0001`; picks `0002` as the next number.
- Skill prompts for title; composes filename `adr-0002-switch-implementer-subagent-to-opus-4-7.md`.
- Skill renders the template and writes the file at `<ai-workspace>/docs/adr/adr-0002-switch-implementer-subagent-to-opus-4-7.md`.
- Skill emits a final assistant message naming the absolute path.

**Assertion (judge subagent verifies):**
- Target subagent's assistant transcript contains the product-vs-process disambiguation prompt AND the target captures the "process ADR" pre-injected response before proceeding.
- Target subagent's tool-call log contains a directory listing of `<ai-workspace>/docs/adr/` BEFORE the file Write.
- Target subagent's tool-call log contains a `Write` of a file under `<ai-workspace>/docs/adr/` (NOT under `<canonical>/docs/adr/`) whose filename matches the literal regex `^adr-0002-switch-implementer-subagent-to-opus-4-7\.md$`. Judge confirms: number is exactly `0002` (the process-ADR series is independent of the product-ADR series next door — `0003` would mean the skill mis-counted by including product ADRs in scope).
- The written file contains the four MADR-lite section headings.
- No `Write` or `Edit` appears against the `<canonical>/docs/adr/` directory (routing must not leak).
- Target subagent's tool-call log shows at least one `lib/manifest.sh` helper invocation; no raw inline jq reads of `.routing.process_adrs`.

---

### S3 — ADR directory missing (fail-fast, surface scaffold-onboard remediation hint)

**Setup:**
- Dual-repo fixture: manifest present at the parent, `routing.product_adrs` field present in the manifest BUT the resolved directory `<canonical>/docs/adr/` does NOT exist on disk (scaffold-onboard's `/scaffold-docs` was never run, or was run with a stripped-down config that omitted the ADR seed).
- `<ai-workspace>/docs/adr/` likewise does NOT exist.
- `templates/adr.md.tmpl` is present in the plugin (template is fine; the dir is what's missing).
- Pre-injected user follow-ups: (a) "product ADR" when prompted for the disambiguation (skill should reach the dir-resolution step before bailing).

**Trigger:** target subagent user message: `add architecture decision`

**Expected behavior:**
- Skill triggers via description-match on the "add architecture decision" trigger phrase.
- Skill prompts product-vs-process; captures "product ADR" response.
- Skill discovers manifest; resolves `routing.product_adrs` to `<canonical>/docs/adr/`.
- Skill checks whether the resolved dir exists; finds it ABSENT.
- Skill refuses to proceed (does NOT auto-create the dir — that's scaffold-onboard's responsibility per §16.2) and surfaces a fail-fast error message naming: (a) the resolved-but-missing directory path, (b) the remediation slash command pointing at scaffold-onboard (`/scaffold-docs` to seed the ADR directory + ADR-0001 template).
- Skill does NOT write any file, does NOT mutate the workspace.

**Assertion (judge subagent verifies):**
- Target subagent's final assistant message names the resolved-but-missing path explicitly (e.g., `<canonical>/docs/adr/` or the absolute path the manifest resolved to) AND the slash-command token `/scaffold-docs` as the remediation route. Judge accepts minor surrounding-phrase variation; rejects: paraphrased substitutes that omit the `/scaffold-docs` token, or messages that suggest the user create the directory manually (the ADR-0001 seed entry from `/scaffold-docs` is the contract anchor).
- Target subagent's tool-call log contains at least one `lib/manifest.sh` helper invocation AND a directory-existence check (e.g., `test -d`, `ls`, or equivalent) against the resolved path.
- No `Write` or `Edit` tool calls appear in the transcript (skill must not auto-create the dir or write a seed file).
- No `mkdir -p` Bash invocation appears (skill must not auto-create the ADR dir; scaffold-onboard owns that seeding).

---

### S4 — `proposed-then-flip` status protocol authors `Status: Proposed` (#6)

**Setup:**
- Dual-repo fixture identical to S1: 2 existing product ADRs (`adr-0001-…`, `adr-0002-…`) under `<canonical>/docs/adr/`; `templates/adr.md.tmpl` present.
- Pre-injected user follow-ups: (a) "product ADR"; (b) status protocol = `proposed-then-flip`; (c) title `use-event-sourcing-for-ledger`; (d) context / decision / consequences body content.

**Trigger:** target subagent user message: `record ADR`

**Expected behavior:**
- Skill prompts product-vs-process; captures "product ADR".
- Skill prompts the **status protocol** (per §9.1) naming both options — `accepted-on-author` (default) and `proposed-then-flip`; captures `proposed-then-flip`.
- Skill scans the product dir → next number `0003`; authors `adr-0003-use-event-sourcing-for-ledger.md` with **`- Status: Proposed`** (NOT `Accepted`) and the four MADR-lite sections.

**Assertion (judge):**
- Target's transcript surfaces a status-protocol prompt naming both `accepted-on-author` and `proposed-then-flip` (or clear paraphrases) AND captures the pre-injected `proposed-then-flip` pick before writing.
- The written ADR's Status metadata line is `- Status: Proposed` — the judge FAILs if it is `Accepted`.
- Filename matches `^adr-0003-use-event-sourcing-for-ledger\.md$`; the four MADR-lite sections are present.
- (Non-binding) the final message may note the ADR is Proposed pending `/flip-adr` empirical validation.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 4 scenarios PASS.

## Out of scope for this eval

- MADR-lite template fidelity (the exact placeholders in `templates/adr.md.tmpl`, the formatting of the Status/Context/Decision/Consequences blocks) — covered by `tests/test-render.sh` (template-rendering correctness). This eval asserts the four section headings appear in the written file; full template-conformance is downstream.
- Duplicate-decision detection (warn if the user is authoring an ADR whose decision overlaps an existing entry) — deferred to v0.2; v0.1 trusts the user.
- ADR amendment / supersedes-status updates (modifying an existing ADR to mark it superseded by a newer one) — deferred; this skill authors new ADRs only. The Proposed → Accepted flip (for `proposed-then-flip` ADRs) is a *separate* skill, `flipping-adr-status`, covered by `evals/flipping-adr-status.md`.
- Architect-critic principle promotion → ADR conversion (the architect-critic `promoting-principle` flow that surfaces a principle as a candidate ADR) — orthogonal; covered by architect-critic v0.2's own evals.
- Manifest absence / corrupt-manifest behavior — `evals/planning-vertical-slice.md` S2 covers the absent-manifest refusal at the orchestrator entry point; if the user invokes this skill without a manifest, the same fail-fast applies (the skill body's first action would be a manifest probe) but is not re-tested here.
- Auto-numbering edge cases beyond the simple +1 rule (gaps in the existing series, e.g., `0001`, `0003` but no `0002`) — v0.1 picks `max(existing) + 1`; gap-filling is not exercised.
