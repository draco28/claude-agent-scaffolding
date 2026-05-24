# Eval: scaffold-onboard:planning-project-roadmap

> Behavior eval for the `planning-project-roadmap` skill. Run via Agent dispatch from a Claude Code session — not via external CLI shells or bash test harness.

## Purpose

Verify that the `scaffold-onboard:planning-project-roadmap` skill (per SPEC §5.4 + §7) drives the three sub-phase R1.A → R1.B → R1.C hierarchy authoring flow, manages the separate `project-roadmap.json` state file correctly, surfaces the verbatim 3-timelines framing prompts, fires the proactive 60-minute checkpoint, and invokes architect-critic at `/plan-roadmap` close per SPEC §12.1 + §12.4.

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

**Reproducibility note:** the orchestrator MUST clear `${CLAUDE_PLUGIN_DATA}/project-roadmap.json` and any `.claude/marker-*` files between scenarios. Scenarios are independent; ordering does not matter.

## Scenarios

### S1 — Fresh `/plan-roadmap` with MASTER-SPEC present (happy path R1.A → R1.B → R1.C)

**Setup:**
- Tmp repo with `git init`.
- Completed v0.1.0-style `MASTER-SPEC.md` already on disk at routing destination (single-repo cwd, no manifest). MASTER-SPEC defines a small project (estimate: 3 phases × 2 sprints × 2 slices = 12 nodes; well under the 50-node size-class threshold).
- `${CLAUDE_PLUGIN_DATA}` points to a fresh empty dir — no `project-roadmap.json` yet.
- No `ROADMAP.md` at routing destination.
- Composition.json absent (architect-critic, ai-mentor, superpowers all read as absent for this scenario — critic invocation is covered by S5).
- Orchestrator pre-loads (per Harness multi-turn protocol) plausible user answers to walk the full R1.A → R1.B → R1.C flow without timing out.

**Trigger:** target subagent user message: `/plan-roadmap`

**Expected behavior:**
- Skill triggers on `/plan-roadmap` (slash command resolves through the wrapper to `scaffold-onboard:planning-project-roadmap`).
- Skill reads `MASTER-SPEC.md` from routing destination (single-repo: cwd).
- Skill creates `${CLAUDE_PLUGIN_DATA}/project-roadmap.json` with `schema_version=1`, valid `started_at` timestamp, and initial `checkpoint` reflecting entry into R1.A.
- Skill opens R1.A with the verbatim 3-timelines framing for Phases (asserted in detail by S4).
- Skill walks R1.A (collects 3-6 phases), updates state `checkpoint="R1.A-complete"`, offers Checkpoint 1 prompt.
- After user accepts continuing, skill walks R1.B (sprints per phase), updates state `checkpoint="R1.B"` then `checkpoint="R1.B-complete"` at each Checkpoint 2 boundary.
- After R1.B complete, skill walks R1.C (slices per sprint), invoking `Skill(scaffold-onboard:authoring-vertical-slice-demo)` per slice to author 1-3 demo criteria lines.
- After R1.C complete, skill writes `ROADMAP.md` at routing destination.

**Assertion (judge subagent verifies):**
- `project-roadmap.json` is present after the run and parses as valid JSON with `schema_version`, `started_at`, `checkpoint`, `phases`, `sprints`, `vertical_slices` keys per SPEC §7.2.
- The state file's final `checkpoint` value is `"R1.C-complete"` (or equivalent terminal marker).
- `ROADMAP.md` is written at routing destination and contains a Phase section, a Sprints section, and a Vertical Slices section with at least one demo criteria line per slice.
- Transcript shows at least one invocation of `Skill(scaffold-onboard:authoring-vertical-slice-demo)` during R1.C.
- Transcript shows the three sub-phase boundaries (R1.A close, R1.B close per phase, R1.C close per sprint) each surface a "save progress and resume later?" style offer.
- No errors or warnings emitted.

---

### S2 — `/plan-roadmap --resume` mid-R1.B

**Setup:**
- Tmp repo with `git init`.
- `MASTER-SPEC.md` present at routing destination.
- Pre-seed `${CLAUDE_PLUGIN_DATA}/project-roadmap.json` with:
  - `schema_version="1"`
  - `started_at` set to 25 minutes earlier
  - `checkpoint="R1.B"` (mid-R1.B — partial sprint authoring in progress)
  - `phases` array fully populated (3 phases, R1.A complete)
  - `sprints` array partially populated: phase 1 sprints done, phase 2 sprints in progress (1 of 3 captured), phase 3 untouched
  - `vertical_slices` empty
- No `ROADMAP.md` at routing destination yet.
- Composition.json absent.
- Orchestrator pre-loads (per Harness multi-turn protocol) follow-up answers for the next 1-2 sprints to verify skill resumes at the correct point.

**Trigger:** target subagent user message: `/plan-roadmap --resume`

**Expected behavior:**
- Skill detects existing `project-roadmap.json` state file.
- Skill reads the `checkpoint` field and re-enters at R1.B mid-progress (does not restart at R1.A).
- Skill does NOT re-ask Phases (R1.A) questions or overwrite the existing `phases` array.
- Skill does NOT re-ask the already-captured phase-1 sprints.
- Skill restates current position (states current sub-phase + which phase's sprints are being authored).
- Skill asks the next unauthored sprint in phase 2.
- State file's `phases` array remains unchanged; `sprints` array grows with new entries but does not lose pre-seeded ones.

**Assertion (judge subagent verifies):**
- Target subagent's first assistant message acknowledges the resume + states current sub-phase position (R1.B, phase 2 mid-progress).
- The state file's `checkpoint` field was read and used to route re-entry — no R1.A questions appear in the transcript.
- Pre-seeded `phases` array entries are unchanged in the final state file.
- Pre-seeded phase-1 sprints in the `sprints` array are unchanged (no overwrite).
- The next prompt asked is a sprint-authoring question for phase 2 (the unfinished sub-phase), not a phase-defining question.
- No architect-critic invocation (R1.C close not reached).

---

### S3 — 60-min checkpoint trigger (proactive)

**Setup:**
- Tmp repo with `git init`.
- `MASTER-SPEC.md` present at routing destination.
- Pre-seed `${CLAUDE_PLUGIN_DATA}/project-roadmap.json` with:
  - `schema_version="1"`
  - `started_at` set to **62 minutes earlier** (past the 60-min proactive checkpoint threshold per SPEC §7.3)
  - `checkpoint="R1.B"` (mid-flow — neither a natural R1.A/R1.B/R1.C boundary nor R1.C-complete)
  - `phases` populated; `sprints` partially populated; `vertical_slices` empty
- No `ROADMAP.md` yet.
- Composition.json absent.
- Orchestrator pre-loads (per Harness multi-turn protocol) a user response declining the checkpoint offer (e.g., `no, let's keep going`) so the judge can also verify the skill continues rather than hard-stopping.

**Trigger:** target subagent user message: `/plan-roadmap --resume`

**Expected behavior:**
- Skill loads state, computes `elapsed_min` from `started_at` (~62 min), detects threshold crossed.
- Before asking the next R1.B question, skill **proactively offers** the 60-min checkpoint prompt per SPEC §7.3 / §5.4: "checkpoint and continue tomorrow?" (or equivalent verbatim language).
- The proactive checkpoint is an **offer** (a prompt for user choice), NOT a hard-stop — the 90-min budget is the hard ceiling per SPEC §5.4, the 60-min mark is advisory.
- After user declines (per pre-injected response), skill resumes the next R1.B question.
- State file is preserved (the checkpoint mechanism writes elapsed_min back but does not reset checkpoint to a different sub-phase).

**Assertion (judge subagent verifies):**
- Target subagent's first assistant message (before asking any new R1.B authoring question) surfaces the 60-min checkpoint offer with language matching SPEC §5.4 ("checkpoint and continue tomorrow?") or a clearly equivalent proactive-pause prompt.
- The prompt is framed as an offer (user-choice), not a unilateral session termination.
- After the user declines (per pre-injected response), the next assistant message is the resumed R1.B sprint-authoring question.
- The proactive checkpoint is NOT one of the natural boundary checkpoints (R1.A-close / R1.B-close-per-phase / R1.C-close-per-sprint) — the judge confirms the trigger fired mid-R1.B, not at a sub-phase boundary.
- `project-roadmap.json` is not reset; `phases` + already-captured `sprints` remain intact.
- No architect-critic invocation.

---

### S4 — 3-timelines prompt framing (R1.A intro language)

**Setup:**
- Same as S1: fresh tmp repo, MASTER-SPEC.md present, no prior state, composition.json absent.
- Orchestrator does NOT need to walk the full flow — only the first 1-2 turns are needed to capture R1.A intro language.

**Trigger:** target subagent user message: `/plan-roadmap`

**Expected behavior:**
- Skill enters R1.A and opens with the verbatim 3-timelines framing for Phases per SPEC §5.4:
  > "Your Phases are your visionary horizon — what's the project's 5-year shape?"
- After R1.A completes (in a fuller walk; for this scenario only the R1.A intro is required), R1.B and R1.C use their own verbatim framings:
  - R1.B: "Sprints are your value-building windows — what gets built over 12-18 months that compounds?"
  - R1.C: "Vertical slices are your visibility cycles — what ships demoably in 90-day-ish windows?"
- The framing text is treated as canonical onboarding vocabulary; the skill MUST NOT paraphrase or improvise.

**Assertion (judge subagent verifies):**
- The target subagent's first assistant message includes the verbatim string: `Your Phases are your visionary horizon — what's the project's 5-year shape?` (exact em-dash, exact wording from SPEC §5.4).
- The judge verifies the string is present without paraphrasing. Substantive deviation (e.g., "long-term vision" instead of "visionary horizon", or "Phases represent" instead of "Your Phases are") is FAIL.
- If the orchestrator extends the trigger into a fuller walk for this scenario, the judge also verifies the R1.B intro contains the verbatim string `Sprints are your value-building windows — what gets built over 12-18 months that compounds?` and the R1.C intro contains the verbatim string `Vertical slices are your visibility cycles — what ships demoably in 90-day-ish windows?`. If the walk does not reach R1.B/R1.C, only the R1.A assertion is evaluated.
- No improvised or paraphrased framing text appears for the R1.A intro.

---

### S5 — architect-critic invocation at `/plan-roadmap` close (filesystem-probe detection)

**Setup:**
- Tmp repo with `git init`.
- `MASTER-SPEC.md` present at routing destination.
- Pre-seed `${CLAUDE_PLUGIN_DATA}/project-roadmap.json` with:
  - `schema_version="1"`
  - `started_at` set to ~75 minutes earlier (within 90-min budget; past 60-min advisory)
  - `checkpoint="R1.C"` (final sub-phase, near completion)
  - `phases`, `sprints` fully populated
  - `vertical_slices` populated except for the last sprint's slices (one slice remaining)
- No `ROADMAP.md` yet.
- **No composition.json file at all** in this scenario (no architect-critic entry per v0.2 ac settlement #1; ai-mentor / superpowers also absent to isolate the filesystem-probe path).
- Mock the plugin cache filesystem: create `${HOME}/.claude/plugins/cache/test-marketplace/architect-critic/0.2.0/skills/critiquing-spec/SKILL.md` (stub content) so the filesystem probe per SPEC §12.2 returns `v0.2`. (`test-marketplace` is an arbitrary fixture name; the real marketplace slug doesn't matter for this probe.)
- Orchestrator pre-loads (per Harness multi-turn protocol) the answers needed to author the final slice + its demo criteria, completing R1.C.

**Trigger:** target subagent user message: `/plan-roadmap --resume`

**Expected behavior:**
- Skill resumes at R1.C, authors the remaining slice via `Skill(scaffold-onboard:authoring-vertical-slice-demo)`.
- Once R1.C completes, skill runs `sf_compose_detect_architect_critic` (filesystem probe per §12.2) — NOT a composition.json lookup (the file is absent in this scenario).
- Probe returns `v0.2`.
- Skill invokes `Skill(architect-critic:critiquing-spec)` with `target=roadmap`, `depth=close` (per SPEC §5.4 + §12.1 row 4 + §12.4), adversaries `[claude, codex]` per §12.1.
- Skill does NOT use the legacy file-IPC pattern (`sf_compose_build_critic_request` / `sf_compose_read_critic_response` — both dropped per §12.3).
- After critic returns control, skill emits `ROADMAP.md` at routing destination and writes terminal `checkpoint="R1.C-complete"` to state.

**Assertion (judge subagent verifies):**
- Target subagent's tool-call log contains exactly one `Skill(architect-critic:critiquing-spec)` invocation at the `/plan-roadmap` close moment.
- Invocation args carry `target=roadmap` and `depth=close` (matching SPEC §5.4 and the §12.4 close-depth contract).
- No file writes to any `inbox/` or `outbox/` paths in the transcript (legacy IPC must not be used).
- Target made zero `composition.json` reads in this scenario (file is absent per setup); all critic detection went via filesystem probe per §12.2.
- After the critic returns, `ROADMAP.md` is written at routing destination.
- `project-roadmap.json` final `checkpoint` is `"R1.C-complete"`.
- No fallback to a `Skill(architect-critic:critique)` (v0.1.3-style) name — that grammar was removed in the 2026-05-24 drift-resolution pass; detection is binary v0.2-present vs absent.

---

## Pass / fail criteria

A scenario is PASS only if every bullet under its `Assertion` block is judged true. If any bullet fails, the judge returns `FAIL: <bullet text> — <specific deviation observed>` so the skill author can target a fix.

The full eval is GREEN when all 5 scenarios PASS.

## Out of scope for this eval

- Re-run protocol modes (`--add-phase`, `--add-sprint`, `--add-slice`, `--refine-slice` per SPEC §7.5) — covered by a separate eval pass after the re-run flow lands
- Size-class adaptation at R1.A close (split into product epics / reduce scope path per SPEC §7.3 size-class branch) — out of scope; S1 uses a small project that stays under the 50-node threshold
- Single-repo vs manifest-mode routing distinction for `ROADMAP.md` output destination — covered by integration tests (PLAN T7.1)
- architect-critic v0.1.3 fallback path — removed from SPEC §12 in the 2026-05-24 drift-resolution pass (v0.1.3 had no skills directory, so the fallback was dead code). Detection is now binary v0.2-present vs absent; only the present case is tested in S5
- ai-mentor + superpowers composition (orthogonal; this eval keeps them absent to isolate the planning-project-roadmap skill behavior)
- 90-min hard-budget enforcement behavior — the 60-min advisory is tested in S3; the 90-min hard ceiling behavior (if/how the skill hard-stops) is left for a follow-up eval once SPEC clarifies enforcement mode
