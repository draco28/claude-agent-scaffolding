# Handoff: architect-critic plugin build

**Purpose:** resume the build of the `architect-critic` plugin in a fresh Claude Code session. This document is a self-contained briefing — read it first, follow the game plan at the end, and execute.

**Author:** carried over from the session that shipped `scaffold-onboard v0.1.0` (2026-05-14). At handoff time, the marketplace has 3 plugins (ai-mentor, scaffold-onboard, scaffold); architect-critic is the fourth, **not yet built**, with **design intent settled but engineering shape unspec'd**.

---

## 1. Goal of the next session

Author `docs/SPEC-architect-critic.md` and `docs/PLAN-architect-critic.md`, then implement the plugin via the same subagent-driven workflow used for scaffold-onboard. Target release: `architect-critic-v0.1.0` shipped to the marketplace.

The build should follow these stages (mirror of how scaffold-onboard was done):

1. **Brainstorm** — invoke `superpowers:brainstorming` (visual companion HTML artifacts where they help). Drive each of the 6–8 open engineering design points listed in §3 to a settled answer. Output: brainstorm transcript + visual artifacts.
2. **SPEC** — author `docs/SPEC-architect-critic.md` mirroring the shape of `docs/SPEC-scaffold-onboard.md` (similar sections: TL;DR, motivation, goals/non-goals, architecture, commands, schema, derivations, integration, decisions, error handling, edge cases, testing, build sequence, risks, open questions, iteration log).
3. **PLAN** — author `docs/PLAN-architect-critic.md` with full task-by-task TDD breakdown, mirror of `docs/PLAN-scaffold-onboard.md`. Include an "Implementation Status" section at the top (initially "Phase A pending"; the new session can update it as a resume point).
4. **Implement** — subagent-driven, phase-by-phase. Each task: implementer subagent (TDD: failing test → impl → passing test → commit) → spec+quality reviewer subagent → TaskUpdate.

---

## 2. What's already settled

### 2.1 Product design (Q1–Q5)

All five live in `docs/SPEC-scaffold-onboard.md` §9 (lines 607–642). Brief recap:

| Q | Question | Decision |
|---|---|---|
| Q1 | Insertion point | **Selective per-phase + final pass** — auto-fire after Phase 5 (Architecture) and Phase 7 (Implementation) recaps (claude-only premise audit, ~30s each), plus full pass at MASTER-SPEC close (claude gap sweep + Codex fresh-frame, ~2–3 min). Phases 1–4, 6, 8–10 rely on user inspection only. |
| Q2 | Cross-model adversary | **Codex only.** Single fresh-frame lineage, ~$0.05–0.20 per run. Fresh-frame given just MASTER-SPEC + project class (no Claude reasoning context). |
| Q3 | Activation default | **Always-on with per-phase `--skip-critic` flag.** No session-wide kill switch, no ask-each-time prompt. Anti-sycophancy is structural. |
| Q4 | Concession threshold | **T=4 firm** (borrowed from academic-research-skills). Critic scores user rebuttals 1–5; concedes only at score ≥4. Single threshold, not adaptive. |
| Q5 | Principle ingestion | **User-global + project, accumulating.** User-global at `${CLAUDE_PLUGIN_DATA}/architect-critic/principles.md` (plugin-owned, user-editable, seeded on first install). Project-specific from in-flight MASTER-SPEC (only previously-answered phases at each gate) + post-onboarding from `.claude/memory-bank/03-code-patterns.md` + `08-governance.md`. Auto-promotion design intent **yes** (critic offers to promote repeated patterns into `principles.md`), implementation **deferred**. |

### 2.2 Integration contract (file-based IPC, scaffold-onboard side already implemented)

`docs/SPEC-scaffold-onboard.md` §8.3 defines the request + response envelope schemas. The scaffold-onboard side is built and tested:

- `sf_compose_build_critic_request(depth, phase_id)` writes a JSON envelope to `<critic_dir>/inbox/<request_id>.json`. Request schema (verbatim, see TF.6):
  ```json
  {
    "request_id": "crit-2026-05-14T...-phaseN-PID.RANDOM",
    "depth": "premise-audit" | "close",
    "adversaries": ["claude"] | ["claude","codex"],
    "target": {
      "type": "master-spec-phase" | "master-spec-full",
      "path": "/abs/path/to/MASTER-SPEC.md",
      "phase_id": N            /* only when type == master-spec-phase */
    },
    "sources": {
      "principles": "/abs/path/to/principles.md",
      "accumulated_phases": [1,...,N-1]
    },
    "concession_threshold": 4,
    "project_class": "CLI tool"
  }
  ```
- `sf_compose_read_critic_response(request_id, timeout_s)` polls `<critic_dir>/outbox/<request_id>.json` with a sleep-1 loop. Response schema (per the TF.7 mock):
  ```json
  {
    "request_id": "<matches the request>",
    "adversaries_used": ["claude"],
    "challenges": [
      {"severity": "premise" | "gap" | "divergence", "text": "...", "references": ["Phase 5.2"]}
    ],
    "gaps": [],
    "divergences": [],
    "elapsed_ms": 25000
  }
  ```

**The critic plugin must honor these schemas.** Look at `scaffold-onboard/lib/compose.sh` and `scaffold-onboard/tests/test-compose.sh` (especially `test_critic_request_premise_audit`, `test_critic_request_close`, `test_critic_dispatch_with_mock_outbox`, `test_critic_response_timeout`) for the exact field shapes the critic must respond to.

---

## 3. What's open — the 6–8 engineering design points to brainstorm

These are the questions the new session must drive to a settled answer before authoring SPEC:

1. **Codex CLI dispatch mechanism**
   - How is Codex CLI invoked? Subprocess via `bash -c` or named tool?
   - Timeout policy (request specifies cost-implicit; what's the upper bound?)
   - Error handling: Codex CLI not installed, Codex returns non-JSON, Codex hangs past timeout
   - Output parsing: does Codex emit JSON natively or do we need a wrapper prompt?
   - Test fixture strategy: how to test Codex dispatch hermetically? (Mock Codex binary via PATH override, similar to TF.7 hardening?)

2. **Consolidator algorithm**
   - Claude self-audit and Codex audit each produce a list of challenges. How do we merge?
   - Dedup by text similarity? Severity precedence (premise > gap > divergence)? Reference-merge?
   - Output schema: single array of challenges, or two arrays preserved with `source: claude|codex`?
   - Concession scoring: who computes it (critic plugin or scaffold-onboard)? When does it apply?

3. **Principles file lifecycle**
   - Seed-on-install: ship a default `principles.md` template at `${CLAUDE_PLUGIN_DATA}/architect-critic/principles.md`? Empty? Curated starter set?
   - User-edit contract: critic plugin reads but never modifies, except via auto-promotion (deferred)?
   - Project-specific principles: how are they composed with user-global at audit time? Concatenated? Section-merged?
   - Auto-promotion (deferred but design-locked): what's the prompt shape? When does critic offer to promote? What's the merge gate?

4. **Watcher / dispatch trigger mechanism**
   - scaffold-onboard *writes* a request to inbox. How does the critic plugin learn there's a request waiting?
     - (a) Polling: critic plugin's SessionStart hook polls inbox on every session start?
     - (b) Synchronous: scaffold-onboard's `sf_compose_read_critic_response` is the polling driver; critic plugin runs on-demand via slash command (`/critique`) invoked by scaffold-onboard's hook?
     - (c) Hybrid: SessionStart for ambient mode + on-demand `/critique` for explicit invocation?
   - Implications for cost (Codex calls aren't free), latency (user-facing wait), and reliability (what if Codex CLI is offline?)

5. **Command surface**
   - `/critique` — manual fire (user requests a critique on the current MASTER-SPEC or current phase). Arguments?
   - `/critique-skip` — per-phase override (matches Q3's "always-on with skip"). Should this set a state file or be one-shot?
   - `/critique-list` — show pending requests / recent challenges. Scope?
   - `/promote-principle "X"` — manual promotion (foreshadows the deferred auto-promotion).
   - Other? `/critique-status`, `/critique-budget` (cost-cap UX), `/principles-list`?

6. **Hook integration**
   - SessionStart? PreToolUse (to gate edits while a critique is in flight)? PostToolUse? UserPromptSubmit?
   - Does the critic plugin have its own state file (`${CLAUDE_PLUGIN_DATA}/architect-critic/state.json`) tracking in-flight requests, recent challenges, principle-promotion history?

7. **Composition with scaffold-onboard vs standalone use**
   - When invoked via scaffold-onboard's inbox/outbox dispatch: full envelope contract.
   - When invoked manually via `/critique`: what's the input shape? Just the current MASTER-SPEC.md path? Or richer (principles + phase context)?
   - Should both paths converge on the same internal "run audit" entry point?

8. **Test fixture strategy + test count target**
   - Codex CLI is external. Mock via PATH override (like TF.7's bad-jq pattern) for hermetic tests.
   - Phase breakdown: how many test suites? Target ~100–150 tests total (vs scaffold-onboard's 163).
   - E2E tests: full audit on a fixture MASTER-SPEC with mocked Codex output.

---

## 4. Workflow conventions (mirror of scaffold-onboard's build)

### 4.1 Subagent-driven development pattern

Use the `superpowers:subagent-driven-development` skill. For each task in the PLAN:

1. **Dispatch implementer subagent** (general-purpose, sonnet for TDD logic, haiku for stubs/templates):
   - Prompt includes: verbatim PLAN task text, full context (prior commit hash, branch, file paths), TDD discipline (failing run BEFORE impl, passing run BEFORE commit), portability adaptations to apply.
   - **Implementer reads PLAN directly via Read tool.** Don't summarize PLAN content into the prompt — implementer's verbatim Read is the source of truth.
2. **Implementer reports DONE** with structured status (commit hash, test counts, surprises).
3. **Verify independently** (git log, test sweep, file inspection).
4. **Dispatch combined spec+quality reviewer subagent** (general-purpose, haiku):
   - Prompt includes: verbatim PLAN reference, commit hash, what to check (spec compliance + code quality + smoke tests).
   - Reviewer **does NOT modify files**. Reports only.
5. **Reviewer approves OR requests changes.** If changes requested: dispatch a fix-up implementer with the reviewer's specific feedback. Don't ad-lib fixes from the orchestrator level.
6. **Mark task complete via TaskUpdate.** Move to next.

### 4.2 TDD discipline (non-negotiable)

- Write the failing test FIRST.
- Run it. Confirm it fails with the expected error.
- Write the implementation.
- Run the test. Confirm it passes.
- Run full regression to check for cascading breaks.
- Only then commit.

The implementer subagent should report all four states explicitly: pre-impl failure mode, post-impl pass count, regression count, commit hash.

### 4.3 Commit hygiene

- Commit message format: `architect-critic: <description> (Phase X)` (mirror of `scaffold-onboard: <desc> (Phase X)`).
- **No `Co-Authored-By:` trailer.** Use `git commit -m "..."` with a single-line message. Do NOT use HEREDOC for routine commits.
- One task = one commit (small commits per TDD increment within a task are OK but the final task-close commit is the one PLAN names).
- Phase-close commits should have a `architect-critic: Phase X complete — <summary>` format and update CHANGELOG.
- Never amend commits without explicit user request. Never use `--no-verify`. Never force-push.

### 4.4 Test discipline

- Bash test suites following the scaffold-onboard pattern: `tests/test-<lib>.sh` per library, plus `tests/test-e2e.sh` for end-to-end.
- Use the same `tests/_helpers.sh` shape: `assert_eq`, `assert_file_exists`, `assert_file_contains`, `assert_file_missing`, `assert_exit_code`, `setup_tmp_repo`, `report_results`, `PASS`/`FAIL`/`TMP_DIR` globals.
- Full regression after every commit. Never commit with red tests.
- E2E tests are wall-clock-expensive; budget accordingly (scaffold-onboard's e2e is ~10s, compose suite ~3.2s due to polling; total ~16s).

### 4.5 macOS portability adaptations (apply throughout)

These were discovered during scaffold-onboard's build and apply equally to architect-critic:

1. **BSD awk `sub()` chains**, NOT gawk 3-arg `match($0, /…/, arr)`. Reference: `scaffold-onboard/lib/parser.sh`.
2. **bash 3.2 parallel indexed arrays + `_lookup_var` helper**, NOT `declare -A`. Pass awk maps via `ENVIRON[]`, NOT `-v`. Reference: `scaffold-onboard/lib/render.sh`.
3. Avoid `trap '...' RETURN` for cleanup in functions (bash 3.2 RETURN traps are unreliable). Use explicit release calls before each `return` instead. Reference: `scaffold-onboard/lib/compose.sh` `sf_compose_set_override`.

### 4.6 File-based IPC

Like scaffold-onboard, architect-critic uses file-based JSON envelopes for cross-plugin communication. Atomic writes via `mktemp` + `mv` (in same directory so `mv` is atomic). Lock-file protection where concurrent writes are possible (`sf_compose_lock_*` pattern from scaffold-onboard's compose.sh is the reference).

**Guard `jq && mv` pattern:**
```bash
if jq ... > "$tmp"; then
  mv "$tmp" "$path"
else
  rm -f "$tmp"
  sf_log_error "jq failed during <op>"
  return 1
fi
```
Avoid the raw `jq ... > tmp; mv tmp path` pattern — a jq failure can clobber existing good files.

---

## 5. Key files to read at session start

Order matters. Read these first to ground the context:

1. **This document** (`docs/HANDOFF-architect-critic-build.md`) — full briefing.
2. **`docs/SPEC-scaffold-onboard.md` §8.3 and §9** — integration contract + Q1–Q5 decisions. Use Read with `offset` to target just these sections (each is ~50 lines).
3. **`docs/PLAN-scaffold-onboard.md` Implementation Status section** (lines 13–80) — workflow conventions + portability notes + reference for how PLAN docs are structured.
4. **`scaffold-onboard/lib/compose.sh`** — full file. The scaffold-onboard side of the contract. Especially:
   - `sf_compose_build_critic_request` — the request envelope writer (what critic must read from inbox).
   - `sf_compose_read_critic_response` — the response reader with polling timeout (what critic must write to outbox).
   - `sf_compose_lock_*` — reference for the lock-file pattern.
5. **`scaffold-onboard/tests/test-compose.sh`** — read selectively, focus on `test_critic_request_premise_audit`, `test_critic_request_close`, `test_critic_dispatch_with_mock_outbox`, `test_critic_response_timeout`. These show the envelope shapes the critic plugin must honor.
6. **Auto-memory** (`MEMORY.md` is always loaded; relevant individual files):
   - `project_skill_factory_direction.md` — marketplace direction, Q1–Q5 settlement details, scaffold-onboard ship status.
   - `user_role_and_pulse_ecosystem.md` — user identity, polyglot stack.
   - `feedback_two_axis_skill_eval.md` — always evaluate on (A) dev cycle + (B) product integration.
   - `feedback_custom_over_adapted.md` — prefer custom builds over community adaptations for thin orchestration.

---

## 6. First-session game plan

When the new session opens, execute this sequence:

### Step 1 — Orient (5–10 min)

- Read this document end-to-end.
- Spot-read SPEC-scaffold-onboard.md §8.3 and §9 (the integration contract and Q1–Q5).
- Skim PLAN-scaffold-onboard.md's Implementation Status section to confirm understanding of the workflow.
- Run `bash scaffold-onboard/tests/test-compose.sh` to confirm the marketplace baseline is still green (expect 31 passed).

### Step 2 — Brainstorm Phase 0 (1–2 hours)

- Invoke `Skill` tool with `superpowers:brainstorming`.
- Drive each of the 6–8 design points in §3 above to a settled answer.
- Visual companion artifacts (`.superpowers/*.html`) where they help — especially for the watcher/dispatch trigger decision (state diagram showing scaffold-onboard ↔ critic message flow) and the consolidator algorithm (challenges merge tree).
- Output: brainstorm transcript captured in the conversation; visual artifacts in `.superpowers/`.

### Step 3 — Author SPEC (1–2 hours)

- Create `docs/SPEC-architect-critic.md`.
- Mirror the section structure of `docs/SPEC-scaffold-onboard.md` (TL;DR, Motivation, Goals/Non-goals, Architecture, Commands, Schema, Integration, Decisions, Error handling, Edge cases, Testing strategy, Build sequence, Risks, Open questions, Iteration log).
- Include §X "Open questions" for anything still uncrystallized after brainstorm.
- Commit: `architect-critic: v0.1 design spec` (no Phase suffix; SPEC predates phases).

### Step 4 — Author PLAN (1–2 hours)

- Create `docs/PLAN-architect-critic.md` with an "Implementation Status" section at top (initially "Phase A pending; brainstorm + SPEC committed").
- Mirror the structure of `docs/PLAN-scaffold-onboard.md`: phase-by-phase task breakdown with verbatim impl + test code per task.
- Include "Portability notes" section restating the three macOS adaptations.
- Phase breakdown estimate: A (scaffold) → B (lib + tests) → C (commands) → D (Codex dispatch + consolidator) → E (principles management) → F (composition with scaffold-onboard) → G (E2E + polish + hardening) → H (publish). Roughly 50–70 tasks total.
- Commit: `architect-critic: v0.1 implementation plan`.

### Step 5 — Begin implementation (multi-session)

- Create a fresh branch: `git checkout -b implementation-architect-critic`.
- Begin Phase A. Use the subagent-driven workflow.
- Update Implementation Status section at each phase close.
- Treat compaction recovery the same way — PLAN's "Implementation Status" is the canonical resume point.

---

## 7. Definition of done (architect-critic v0.1.0)

- All phases A–H complete per PLAN.
- ~100–150 tests passing across multiple bash suites.
- `architect-critic-v0.1.0` tag pushed to origin.
- Entry added to `.claude-plugin/marketplace.json` (between scaffold-onboard and scaffold, or at end).
- Root `README.md` plugin table updated to 4 rows.
- `scaffold-onboard` test-compose.sh's `test_critic_dispatch_with_mock_outbox` and `test_critic_response_timeout` tests **still pass** (regression check: the contract this plugin honors must remain compatible).
- Installable via `/plugin install architect-critic@claude-agent-scaffolding`.

---

## 8. Open meta-questions for the new session

These aren't blockers but worth surfacing early:

1. **Pivot risk on Q5 auto-promotion:** SPEC §9 says auto-promotion design intent is locked but implementation deferred. Does v0.1.0 include the design hook (data-model fields, prompt text, principle-promotion command) without the trigger mechanism? Or defer all of it to v0.2?
2. **scaffold-onboard's hook chain:** does scaffold-onboard's SessionStart hook need updates to dispatch critic requests at the right moments (Phase 5/7 recap, MASTER-SPEC close)? Probably yes — this would add a TF.10 style task to scaffold-onboard's repo as a follow-up. Worth flagging early so the architect-critic build doesn't ship without scaffold-onboard's matching dispatch logic.
3. **Cost-cap UX:** Q2 says Codex-only adversary at ~$0.05–0.20 per run. How does v0.1.0 surface cost? Pre-flight estimate? Post-run actual? Cumulative session/project counter? `/critique-budget` command? Or defer entirely to v0.2?

These should be answered during Phase 0 brainstorming.

---

## 9. New-session opening message

To resume in a fresh Claude Code session, paste this single message:

> Read `docs/HANDOFF-architect-critic-build.md` end-to-end. Then read SPEC-scaffold-onboard.md §8.3 and §9 for the integration contract. Confirm the marketplace baseline is still green (`bash scaffold-onboard/tests/test-compose.sh`). Then invoke the `superpowers:brainstorming` skill and let's drive the 6–8 open engineering design points in §3 to settled answers, producing visual companion artifacts where helpful. After brainstorm, we'll author `docs/SPEC-architect-critic.md`, then `docs/PLAN-architect-critic.md`, then begin subagent-driven implementation on a new `implementation-architect-critic` branch.

That's all the context needed. The new session inherits the workflow, conventions, and design-intent settlements via the files. No copy-paste of state required.
