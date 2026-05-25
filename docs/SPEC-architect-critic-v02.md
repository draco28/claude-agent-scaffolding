# SPEC: architect-critic v0.2 plugin

**Status:** Draft (2026-05-24)
**Predecessor:** [`SPEC-architect-critic.md`](./SPEC-architect-critic.md) (v0.1 — shipped as v0.1.3 with 8 documented bugs in [GitHub issue #1](https://github.com/draco28/claude-agent-scaffolding/issues/1))
**Inputs:** [`HANDOFF-architect-critic-v02-spec.md`](./HANDOFF-architect-critic-v02-spec.md), grill-me settlements ([memory](../../.claude/projects/-Volumes-master-ssd-projects-claude-agent-scaffolding/memory/project_architect_critic_v02_grill_settlements.md))
**Type:** Hard breaking change. No backwards compatibility with v0.1.x.

---

## 1. TL;DR

architect-critic v0.2 is a ground-up retrofit of the v0.1.3 plugin around the **skill-first principle**. It fixes all 8 bugs documented in issue #1, drops the file-IPC inbox/outbox protocol in favor of in-conversation skill invocation, ships the auto-promotion machinery v0.1 deferred, and integrates the **ghost-notes** + **CORE** thinking-discipline patterns as default principles. Consumers (scaffold-onboard v0.2, scaffold-dev v0.1) invoke the critic by triggering its `critiquing-spec` skill in conversation — no shared registry, no async file passing. The plugin ships 4 skills + 4 slash-command wrappers + 1 SessionStart hook + slimmed `lib/` for state and principles bookkeeping.

---

## 2. Motivation

v0.1.3 is architecturally wrong in a way that produces 8 user-visible bugs. The root cause: v0.1 was built CLI-tool-shaped (bash scripts attempt to orchestrate Claude with instructions embedded in `bash -c` comments). Claude cannot intervene mid-bash to produce judgment work; the "claude-self-audit" step is therefore a silent no-op in real use (bug #2 — the architectural sin from which #1, #3, #4 cascade). Two other consumer plugins (scaffold-onboard v0.2, scaffold-dev v0.1) need adversarial-review capability and would inherit this brokenness if integrated against v0.1.3.

The fix is not patching individual bugs. It is restructuring the plugin to be **skill-first** per the Pass D principle: logic lives in markdown skill bodies that Claude reads and acts on; bash is reserved for bookkeeping (state.json, principles file, codex subprocess invocation). When the design is right, most v0.1 bugs evaporate by construction.

---

## 3. Goals & non-goals

### Goals

- **G1** Fix all 8 bugs in issue #1 (3 critical, 1 high, 2 medium, 2 low). Each gets a regression test.
- **G2** Restructure to skill-first: 4 skills (gerund-named) replace v0.1's bash-orchestrating slash commands. Slash commands stay as thin `$ARGUMENTS` wrappers for explicit invocation with flags.
- **G3** Drop inbox/outbox file IPC entirely. Consumer plugins (scaffold-onboard v0.2, scaffold-dev v0.1) invoke `critiquing-spec` skill in-conversation; critic produces challenges; user resolves in conversation; control returns naturally.
- **G4** Ship the full auto-promotion machinery v0.1.3 deferred (per [[feedback_v01_full_over_minimal]]). Pattern-detection across runs + user-vote recurrence + suppression windows (30-day for score-4 / 90-day for score-5 rejections).
- **G5** Integrate ghost-notes + CORE as default principles in `principles.md` (with `source: "shipped-default"` tag), referenced by `critiquing-spec` skill body. Critic operates by principles → critic's posture is itself a principle.
- **G6** Adopt Codex CLI 0.125+ native JSON output (`--json --output-schema --output-last-message`) for adversarial fresh-frame audit. Drop prose-parsing fallback.
- **G7** Ship LLM-as-judge eval harness for skill bodies (~5 fixtures × 4 skills × 2 LLM calls per full run). Run on PR + release gate.

### Non-goals

- **NG1** Backwards compatibility with v0.1.3 callers. Hard breaking change. v0.2 detects old state, renames to `.bak`, starts fresh.
- **NG2** `composition.json` shared cross-plugin registry. Skill auto-discovery already solves invocation; filesystem-probe handles presence-detection. YAGNI.
- **NG3** `cost_usd` tracking. Field removed from schema. User on subscription accounts; not actionable.
- **NG4** Async / background codex invocation. Codex runs synchronously in conversation. User waits with progress message.
- **NG5** Codex `review` subcommand integration. v0.2 sticks to `codex exec`. `codex review` (git-diff-aware) deferred to v0.3+.
- **NG6** Hard-coded codex model. v0.2 respects user's `~/.codex/config.toml` default. Optional override via slash flag only.

---

## 4. Architecture overview

### 4.1 Three-layer pattern (Pass D skill-first)

```
┌──────────────────────────────────────────────────────────────────┐
│ Layer 1 — Hooks (ambient)                                        │
│   SessionStart: "architect-critic v0.2 installed; principles at  │
│                  <path>"  (~50 tokens, fail-open)                │
└──────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────┐
│ Layer 2 — Skills (auto-invocable capabilities, gerund-named)     │
│   • critiquing-spec                                              │
│   • reviewing-critique-history                                   │
│   • listing-principles                                           │
│   • promoting-principle                                          │
└──────────────────────────────────────────────────────────────────┘
┌──────────────────────────────────────────────────────────────────┐
│ Layer 3 — Slash commands (explicit handles, $ARGUMENTS wrappers) │
│   • /critique [path] [--close] [--model NAME] [--principles PATH]│
│   • /critique-list [--limit N]                                   │
│   • /principles-list                                             │
│   • /promote-principle "<text>" [--scope user|project]           │
└──────────────────────────────────────────────────────────────────┘
```

**Slash commands are thin wrappers.** Each slash-command body normalizes args (using `$ARGUMENTS` env-var bridge per [[feedback_slash_command_dollar_n_bug]]) then invokes the corresponding skill. The skill body does the work.

**Bash is reserved for bookkeeping.** Reading/writing state.json, principles.md; invoking codex subprocess; computing filename heuristics. Bash is NOT used to drive Claude's judgment work.

### 4.2 Directory layout

```
architect-critic/
├── .claude-plugin/
│   ├── plugin.json                    # version: 0.2.0
│   └── marketplace.json
├── skills/                            # NEW: 4 skill bodies (gerund-named)
│   ├── critiquing-spec/SKILL.md
│   ├── reviewing-critique-history/SKILL.md
│   ├── listing-principles/SKILL.md
│   └── promoting-principle/SKILL.md
├── commands/                          # slimmed: thin wrappers over skills
│   ├── critique.md                    # invokes critiquing-spec skill
│   ├── critique-list.md               # invokes reviewing-critique-history
│   ├── principles-list.md             # invokes listing-principles
│   └── promote-principle.md           # invokes promoting-principle
├── hooks-handlers/
│   └── session-start.sh               # fail-open ambient status
├── lib/                               # slimmed: bookkeeping only
│   ├── state.sh                       # state.json read/write (schema v2)
│   ├── principles.sh                  # principles.md parsing + merge
│   ├── promotion.sh                   # NEW: auto-promotion machinery
│   ├── codex.sh                       # codex subprocess invocation + JSON parse
│   ├── scorer.sh                      # 1-5 rubric scoring (called by skill body)
│   ├── consolidator.sh                # challenge dedup across adversaries
│   ├── migration.sh                   # NEW: v0.1.x → v0.2 first-run migration
│   └── log.sh                         # logger
├── templates/
│   ├── principles.md                  # ships with ghost-notes + CORE defaults
│   └── output-schema.json             # codex --output-schema constraint
├── tests/
│   ├── unit/                          # bash unit tests
│   │   ├── test-state.sh
│   │   ├── test-principles.sh
│   │   ├── test-scorer.sh
│   │   ├── test-consolidator.sh
│   │   ├── test-promotion.sh
│   │   ├── test-codex.sh
│   │   └── test-migration.sh
│   ├── eval/                          # NEW: LLM-as-judge eval harness
│   │   ├── fixtures/
│   │   │   ├── critiquing-spec/      # 5 scenarios
│   │   │   ├── reviewing-critique-history/
│   │   │   ├── listing-principles/
│   │   │   └── promoting-principle/
│   │   ├── rubrics/
│   │   │   └── *.md                  # per-skill judging rubric
│   │   ├── run-evals.sh              # orchestrator: subagent + judge
│   │   └── README.md
│   └── integration/
│       ├── test-bug-repros.sh        # 8 regression tests, one per issue #1 bug
│       ├── test-end-to-end.sh
│       └── test-scaffold-onboard.sh  # fixture invocation
├── CHANGELOG.md
└── README.md
```

**Deleted from v0.1.3:** `lib/inbox.sh`, `lib/outbox.sh`, `inbox/`, `outbox/`, the bash-orchestration sections of `commands/critique.md` (lines ~230-266 "CLAUDE SELF-AUDIT INSTRUCTIONS").

### 4.3 Skill invocation flow (the v0.2 happy path)

When a consumer (or user) needs an adversarial audit:

```
1. User says "/critique docs/SPEC-foo.md" OR "critique this spec adversarially"
2. Claude triggers critiquing-spec skill (auto-discovery by description
   OR via slash-command wrapper)
3. Skill body runs IN CONVERSATION:
   a. Read artifact (path resolution per §5.1 discovery order)
   b. Read principles (user-global merged with project context + ghost-notes
      + CORE defaults)
   c. Detect codex availability + close-depth trigger
   d. Run claude-self-audit (Claude's own judgment, in conversation):
      identify challenges by severity (premise/gap/alternative)
   e. IF close-depth + codex installed: invoke codex subprocess via Bash
      (synchronous, ~30-90s, progress message displayed)
   f. Consolidate claude+codex challenges (dedup by similarity)
   g. Present challenges sequentially with 1-5 rubric prompt (per §5.1)
      • premise + gap severities: one-by-one round-trip
      • alternative severity: auto-batched at end
   h. Score each rebuttal (≥4 = concede, ≤3 = challenge stands)
   i. Bash bookkeeping: append run to state.json (schema v2);
      run auto-promotion check (per §7.2)
4. Skill emits structured summary; control returns to caller (user or
   consumer-plugin orchestrator)
```

No inbox file. No outbox file. No polling. No timeout. Everything happens in the same Claude conversation turn.

---

## 5. Skills

### 5.1 `critiquing-spec` (primary skill)

**Trigger phrases:** *"audit this spec"*, *"critique X"*, *"adversarial review of Y"*, *"challenge the spec"*, *"deep audit"*, *"fresh-frame review"*

**Slash-command wrapper:** `/critique [path] [--close] [--model NAME] [--principles PATH] [--scope project|user]`

**Skill body responsibilities** (markdown prose Claude reads and executes):

1. **Resolve artifact path.** Order: (a) explicit `--spec PATH` / first positional arg from slash command; (b) workspace-init manifest's `well_known_paths.master_spec`; (c) filename heuristic restricted to `SPEC*` / `MASTER-SPEC*` / `PLAN*` patterns; (d) AskUserQuestion with candidate files. Never glob `*.md` (that was bug #3's root cause).

2. **Resolve principles.** Merge sources: shipped defaults (ghost-notes + CORE per §6.4) → user-global `principles.md` → project-scoped (if exists) → memory-bank patterns (if scaffold-onboard installed). Per [[project_skill_first_retrofit_queue]].

3. **Detect codex + close-depth.** `command -v codex` → check availability. Close-depth triggered by: `--close` slash flag, `--deep` slash flag, OR natural-language match against trigger list (*"deep audit"*, *"close review"*, *"deeper look"*, *"adversarial fresh-frame"*). Default = claude-only audit.

4. **Surface codex status to user before audit.** Examples: *"Codex 0.125 detected; will run fresh-frame audit (~60s)"*, *"Codex not installed; running claude-self-audit only. Install codex CLI for adversarial fresh-frame."*, *"Codex available but depth=shallow; running claude-self-audit only. Use --close for fresh-frame."*. Fixes bug #5.

5. **Run claude-self-audit IN CONVERSATION.** This is the bug #2 fix. The skill body says *"now identify challenges, gaps, alternatives in this artifact, applying the ghost-notes principle (look for absent data) and the CORE protocol tone. Produce output as a JSON-shaped structure: `{ challenges: [{ text, severity, rationale }], gaps: [...], alternatives: [...] }`. Do this work as Claude in this conversation; do NOT delegate to bash."* No bash `-c` wrapper around the audit step.

6. **IF close-depth + codex installed: invoke codex.** Via Bash tool:
   ```bash
   codex exec \
     --json \
     --output-schema "${PLUGIN_DIR}/templates/output-schema.json" \
     --output-last-message "${TMP}/codex-audit-${REQ_ID}.json" \
     --ignore-user-config --ignore-rules \
     --skip-git-repo-check \
     ${MODEL_OVERRIDE:+-c model=\"$MODEL_OVERRIDE\"} \
     "${ADVERSARIAL_PROMPT}"
   ```
   Synchronous. Default timeout 5 min (configurable via `ARCHITECT_CRITIC_CODEX_TIMEOUT_S`). Progress message displayed before invocation. If timeout hit, surface to user with partial result.

7. **Consolidate challenges.** Algorithm: similarity dedup (text overlap >70% = same challenge), preserve adversary attribution (`source: ["claude"]`, `source: ["codex"]`, or `source: ["claude", "codex"]` for cross-confirmed), preserve highest severity if mismatched. Lives in `lib/consolidator.sh`.

8. **Present rebuttal cycle.** Sequential by default:
   ```
   Challenge 1 of N (severity: <premise|gap>)
   <CORE-toned text>
   Rationale: <why this might matter>

   Your response (accept | rebut | dismiss):
   ```
   Wait for user reply (Claude's native turn handling — NOT bash `read`; this fixes bug #4). Score rebuttal 1-5 via `scorer.sh`. If ≥4 (concede) → mark concession. If ≤3 → challenge stands, surface to candidates pile. Advance to next.

   **Escape hatches:**
   - User says *"linear from here"* / *"batch the rest"* → switch to bulk-list for remaining challenges.
   - `alternative` severity challenges auto-batched at end (one final group, not one-by-one).

9. **Bash bookkeeping.** Append `recent_runs[]` entry to state.json (schema v2 per §6.3). Run auto-promotion check (§7.2). Update `auto_promote_suppressions[]` for rejected candidates.

10. **Emit structured summary.** Returns to caller: challenge count, concessions, candidates surfaced, principles applied, codex used yes/no, elapsed time. Consumer plugins parse this from conversation context (no file IPC).

### 5.2 `reviewing-critique-history`

**Trigger phrases:** *"show recent critiques"*, *"critique history"*, *"list pending audits"*

**Slash-command wrapper:** `/critique-list [--limit N]` (default N=10)

**Skill body responsibilities:** Read state.json, render `recent_runs[]` (default N=10) with: completed-at timestamp, depth (shallow/close), adversaries used (claude / claude+codex), challenge count, concessions count, skill invoked. Note: `in_flight` field is gone in schema v2 (no async). Output format: human-readable table.

### 5.3 `listing-principles`

**Trigger phrases:** *"show principles"*, *"list principles"*, *"what principles apply here"*

**Slash-command wrapper:** `/principles-list [--source all|shipped|user|project]`

**Skill body responsibilities:** Read shipped + user-global + project principles, merge, render grouped by source. Each principle annotated with: source tag (`shipped-default` / `user-promoted` / `project`), promotion timestamp (for user-promoted), suppression status (if applicable). The shipped defaults (ghost-notes + CORE per §6.4) are always shown unless explicitly excluded by `--source` flag.

### 5.4 `promoting-principle`

**Trigger phrases:** *"promote this principle"*, *"record this as a principle"*, *"add to principles.md"*

**Slash-command wrapper:** `/promote-principle "<text>" [--scope user|project]`

**Skill body responsibilities:** Append principle to target principles.md (user-global or project-scoped). Validate uniqueness (no exact duplicates). Tag with `source: "user-promoted"` and timestamp. If invoked during a `critiquing-spec` run with a specific challenge selected, auto-link the principle to the challenge's `fingerprint` for future auto-promotion deduplication.

---

## 6. Schemas

### 6.1 state.json (schema v2)

```json
{
  "schema_version": 2,
  "recent_runs": [
    {
      "request_id": "crit-<ISO8601>-<depth>-<short>",
      "completed_at": "2026-05-24T15:00:00Z",
      "depth": "shallow" | "close",
      "adversaries_used": ["claude"] | ["claude", "codex"],
      "challenge_count": 8,
      "concessions": 2,
      "skill_invoked": "critiquing-spec",
      "elapsed_ms": 65000
    }
  ],
  "principle_promotions": [
    {
      "principle_id": "pp-<hash>",
      "text": "Prefer explicit over implicit configuration",
      "source": "user-promoted" | "auto-promoted" | "shipped-default",
      "promoted_at": "2026-05-24T15:01:00Z",
      "scope": "user" | "project",
      "promotion_basis": "user-vote" | "pattern-recurrence" | "shipped"
    }
  ],
  "candidate_promotions": [
    {
      "candidate_id": "cc-<hash>",
      "fingerprint": "<sha256 of normalized challenge text>",
      "challenge_text": "...",
      "appeared_in_runs": ["crit-...", "crit-..."],
      "vote_count": 2,
      "first_seen_at": "...",
      "last_seen_at": "..."
    }
  ],
  "declined_candidates": [
    {
      "candidate_id": "cc-<hash>",
      "declined_at": "...",
      "decline_score": 4 | 5
    }
  ],
  "auto_promote_suppressions": [
    {
      "fingerprint": "<sha256>",
      "suppressed_at": "2026-05-24T15:00:00Z",
      "expires_at": "2026-06-23T15:00:00Z",
      "reason_score": 4 | 5
    }
  ]
}
```

**Changes from v0.1.3:** Drop `in_flight` array (no async). Drop `cost_usd` from `recent_runs[]`. Add `concessions`, `skill_invoked`. Add `auto_promote_suppressions[]` (replaces v0.1.3's incomplete `declined_candidates`-as-suppression hack). Suppression window: 30 days if `reason_score=4`, 90 days if `reason_score=5` (per v0.1 Q4 deferred refinement).

### 6.2 principles.md grammar (with shipped defaults)

```markdown
# Architect-critic principles

## Shipped defaults (do not edit; updates ship with the plugin)

<!-- source: shipped-default -->
- **Ghost notes:** Look for what is *absent* from the artifact, not just what is present. (Per Abraham Wald's survivor-bias insight — armor the engines where there are no bullet holes, because planes hit *there* did not return.) Apply by asking: what assumption does this spec depend on that it never surfaces? What dependency is implied but not acknowledged? What failure mode is unenumerated?

<!-- source: shipped-default -->
- **CORE protocol (rebuttal tone):** Frame every challenge with Curiosity → Objectivity → Reassurance → Empathy.
  - **Curiosity:** *"I might be missing something, but is there a reason X is not addressed?"* (lower defensiveness)
  - **Objectivity:** Shift to facts/processes, not people/stories. *"Where should we adjust the spec?"* not *"why did you skip this?"*
  - **Reassurance:** Signal mutual purpose. *"I'm raising this because I want the spec to be robust before implementation."* not *"this is wrong."*
  - **Empathy:** Acknowledge user's work + intent. *"I see you've thought through X carefully; here's a related angle that might also need consideration."*

## Your principles (user-promoted)

<!-- Add via /promote-principle "<text>" or by direct edit. Each principle on its own line. -->

## Project principles (scope=project)

<!-- Only present in project-scoped principles.md files. Inherited from user-global if not overridden. -->
```

**Why shipped defaults:** per grill-me decision #9 (ghost-notes + CORE as principles, not skill-body prose). The `critiquing-spec` skill body references them by name during audit — *"apply the Ghost Notes principle and the CORE protocol from principles.md"* — rather than re-stating them inline. They participate in `/principles-list` output, can be inspected by user, and serve as exemplars for the format of user-promoted principles.

### 6.3 Codex output schema (`templates/output-schema.json`)

JSON Schema constrains codex's response shape so we don't prose-parse:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "challenges": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "text": { "type": "string" },
          "severity": { "enum": ["premise", "gap", "alternative"] },
          "rationale": { "type": "string" },
          "principle_applied": { "type": "string" }
        },
        "required": ["text", "severity", "rationale"]
      }
    },
    "divergences": {
      "type": "array",
      "items": { "type": "string" }
    }
  },
  "required": ["challenges"]
}
```

Codex enforces this shape via `--output-schema`. v0.1.3's prose-parsing fallback is removed.

---

## 7. Derivations

### 7.1 Consolidator algorithm (claude + codex challenge dedup)

Inherited from v0.1 §7.1, lives in `lib/consolidator.sh`, unchanged in semantics:

1. Normalize text (lowercase, strip punctuation, collapse whitespace).
2. Pairwise similarity (token-set Jaccard); threshold 0.7.
3. If pair exceeds threshold → merge: pick longer `text`, union `source` array, take max severity (`premise` > `gap` > `alternative`).
4. Output list with `source: ["claude"|"codex"|"claude","codex"]` annotation.

Cross-confirmed challenges (source = both) get elevated display priority in the rebuttal cycle.

### 7.2 Auto-promotion (FULL implementation, no deferrals)

Per [[feedback_v01_full_over_minimal]] — v0.1 design-locked, implementation deferred; v0.2 ships full.

After each critiquing-spec run, run `lib/promotion.sh check-candidates`:

1. **Collect challenges that user did NOT concede** (score ≤3 or no rebuttal at all). Each gets a fingerprint (sha256 of normalized text).
2. **Look up fingerprint in `auto_promote_suppressions[]`.** If present and not expired → skip (this candidate was rejected within suppression window).
3. **Look up fingerprint in `candidate_promotions[]`.** If present → increment `vote_count`, append run-id to `appeared_in_runs[]`, update `last_seen_at`. If absent → insert new candidate.
4. **Apply promotion threshold (T=4 votes).** If `vote_count ≥ 4` across distinct runs → surface as auto-promote candidate to user (next critiquing-spec invocation prompts: *"This pattern has appeared in 4 audits across 3 weeks: '<text>'. Promote to principles.md? [yes / no / never]"*).
5. **User response handling.**
   - `yes` → move to `principle_promotions[]` with `promotion_basis: "pattern-recurrence"`. Append to principles.md.
   - `no` → record in `auto_promote_suppressions[]` with 30-day expiry (`reason_score: 4` — user rejected but might reconsider).
   - `never` → record in `auto_promote_suppressions[]` with 90-day expiry (`reason_score: 5` — premise invalidated, strong rejection).

**Supplementary instinct-style signal (per [[project_post_spec_exploration_queue]]):** alongside vote-recurrence, also surface candidates whose fingerprint appeared in N consecutive runs (default N=3) even if user never explicitly scored them. Frame as: *"this challenge keeps coming up; want to elevate?"*. Lower-priority signal than vote-recurrence.

### 7.3 Concession scoring (kept from v0.1; relocated)

The 1-5 rubric (1=bare-contradiction, 2=cite-self, 3=partial, 4=material-new-info, 5=premise-invalidated) lives in `lib/scorer.sh` and is called BY THE SKILL BODY, not by bash orchestration. The skill body presents the challenge, captures the user's free-text rebuttal in conversation, then calls scorer.sh with `(challenge_text, rebuttal_text)` → gets 1-5 back → decides concede/stands. Bug #4 (bash `read` non-TTY) is gone because no bash read is used.

---

## 8. Integration

### 8.1 With scaffold-onboard v0.2 (in-conversation skill invocation)

scaffold-onboard v0.2 (gated on architect-critic v0.2 ship) drops its inbox/outbox protocol entirely (per `SPEC-scaffold-onboard.md` §8.3 redesign). When scaffold-onboard reaches an architect-critic moment (e.g., MASTER-SPEC review after Round 1), it does NOT write a request envelope to a file. Instead:

1. scaffold-onboard's skill body says *"now invoke architect-critic's critiquing-spec skill on the MASTER-SPEC."*
2. Claude triggers `critiquing-spec` via description match (no registry lookup, no `composition.json`).
3. `critiquing-spec` runs in the same conversation, produces challenges, runs rebuttal cycle, returns summary.
4. scaffold-onboard reads the summary from conversation context (Claude's native turn handling), continues to next phase.

If architect-critic is not installed, scaffold-onboard's skill body detects this (filesystem probe of `~/.claude/plugins/.../architect-critic/skills/critiquing-spec/SKILL.md`) and skips the adversarial step with a one-line note: *"architect-critic not installed; skipping adversarial review. Install via /plugin install architect-critic for fresh-frame audits."*

### 8.2 With scaffold-dev v0.1 (in-conversation skill invocation)

Identical pattern to §8.1. scaffold-dev v0.1's orchestrator (per `SPEC-scaffold-dev.md` §16.3) reaches two architect-critic moments per slice: spec-author audit (before round 1) and slice-close adversarial review. Both invoke `critiquing-spec` in conversation. No file IPC.

### 8.3 With ai-mentor (no direct integration)

architect-critic and ai-mentor are orthogonal. ai-mentor's `grill-me` is for user-facing Socratic dialogue on plans/designs; architect-critic's `critiquing-spec` is for adversarial audit of written artifacts. Both can be invoked in the same session without coordination. The grill-me ↔ critiquing-spec sequence ("first interrogate the design verbally, then audit the written spec") is a natural user workflow but not a coded integration.

### 8.4 With superpowers (skill-naming convention shared)

architect-critic v0.2 skills follow the gerund pattern (`-ing`) per `superpowers` convention. No deeper integration — no skill from architect-critic depends on a superpowers skill. (Future possibility: `critiquing-spec` could chain into `writing-plans` for SPEC→PLAN handoff, but that's deferred.)

### 8.5 Standalone use (no consumer plugin)

User directly invokes via slash command (`/critique docs/SPEC-foo.md`) or natural language (*"adversarially audit this spec"*). Skill resolves spec path via §5.1 step 1 (slash arg → manifest → heuristic → AskUserQuestion). Works without scaffold-onboard or scaffold-dev installed. Fixes bug #3 (no MASTER-SPEC = unusable).

---

## 9. Decisions

### 9.1 Settled by grill-me 2026-05-22→24

Reference: [[project_architect_critic_v02_grill_settlements]]. All 13 decisions enumerated there are binding on this SPEC. Summary:

| # | Decision | Section |
|---|---|---|
| 1 | Drop `composition.json` — use skill auto-discovery | §3 NG2, §8.1 |
| 2 | Keep 1-5 rubric + T=4 threshold from v0.1 unchanged | §7.3 |
| 3 | Sequential rebuttal + linear-on-demand + auto-batch alternative severity | §5.1 step 8 |
| 4 | Codex JSON output via `--output-schema` + `--output-last-message` | §5.1 step 6, §6.3 |
| 5 | No hard-coded codex model; respect user's config default | §5.1 step 6, §3 NG6 |
| 6 | Codex invocation = user opt-in per audit (`--close` flag or NL trigger) | §5.1 step 3-4 |
| 7 | Hard breaking change; rename old state.json to `.bak`; nuke inbox/outbox | §10, §3 NG1 |
| 8 | LLM-as-judge eval harness; ~40 LLM calls per full run | §12 |
| 9 | Ghost-notes + CORE ship as default principles in principles.md | §6.2, §3 G5 |
| 10 | Drop `cost_usd` entirely | §6.1, §3 NG3 |
| 11 | SessionStart fail-open hook only | §4.1 Layer 1 |
| 12 | state.json schema v2 | §6.1 |
| 13 | Gerund skill-naming convention | §4.1, §5.x |

### 9.2 Inherited from v0.1 (still binding)

From v0.1 §9.1-§9.3, the following remain in v0.2:

- **D2** Consolidator dedup threshold 0.7 (§7.1).
- **Q4** T=4 concession threshold; score-5 distinction for 90-day suppression (§7.2 step 5, §7.3).
- **OQ-1** Auto-promotion via pattern-recurrence + supplementary instinct-style signal (§7.2).
- **Q1-Q3** Multi-source principles merge order (shipped → user → project → memory-bank).
- **D1** principles.md is a Markdown checkbox-free grammar (§6.2).

Reference: `SPEC-architect-critic.md` §9 for full v0.1 settled rationale.

---

## 10. Migration from v0.1.x (hard breaking change)

On first run of v0.2 (any skill or slash command), `lib/migration.sh check-v01-state`:

1. Look for `~/.claude/architect-critic/state.json`. If found:
   - Read `schema_version`. If `< 2` → backup: `mv state.json state.json.v0.1.3.bak`.
   - Initialize fresh state.json with schema v2.
2. Look for `~/.claude/architect-critic/inbox/` and `outbox/`. If found:
   - Move both to `~/.claude/architect-critic/legacy-v0.1.x/` (preserved for forensics; will be removed in v0.3).
3. Look for `~/.claude/architect-critic/principles.md`. If found:
   - Preserve user content (user's own principles stay).
   - Prepend shipped-defaults block from `templates/principles.md` (ghost-notes + CORE) above user content.
   - Tag pre-existing user content with `<!-- migrated from v0.1.x -->` comment.
4. Print one-line user-facing notice: *"architect-critic upgraded from v0.1.x to v0.2.0. Legacy state preserved at <path>. See CHANGELOG for breaking changes."*

**CHANGELOG.md** explicitly labels v0.1.x → v0.2 as BREAKING with:
- Inbox/outbox protocol removed
- state.json schema v1 → v2 (migrated automatically; backup preserved)
- `cost_usd` field removed
- 0 skills → 4 skills (gerund-named)
- `--depth` flag renamed → `--close` (semantic clarity)
- Codex CLI 0.125+ required for adversarial fresh-frame

---

## 11. Error handling

| Failure | Behavior |
|---|---|
| Spec path resolution exhausts all options | AskUserQuestion with up to 5 candidate paths; if user declines all, abort with clear message |
| Codex CLI not installed | Surface "Codex not detected; running claude-only" in user output (bug #5 fix); proceed with claude-self-audit only |
| Codex subprocess timeout | Default 5min; surface partial result with timeout warning; record `codex_timeout: true` in state.json run entry |
| Codex returns non-schema-conforming output | Validation fails; log error; skip codex challenges; proceed with claude-only result |
| principles.md missing | Auto-create from `templates/principles.md` (ships with shipped-defaults) |
| state.json missing | Auto-create empty schema-v2 structure |
| state.json corrupt (unparseable) | Backup to `state.json.corrupt-<ts>`; create fresh; log warning |
| User aborts rebuttal cycle mid-way | Save partial state; mark run as `incomplete: true`; allow resume on next invocation via `/critique --resume <request_id>` |

All errors fail-open (don't block the user; surface the problem; degrade gracefully). The plugin is an advisor, not a gate.

---

## 12. Testing strategy

### 12.1 Unit tests (bash, `tests/unit/`)

Inherited from v0.1.3 style. Each `lib/*.sh` script has a `test-<name>.sh` covering:

- `test-state.sh` — schema v2 read/write, migration v1→v2
- `test-principles.sh` — merge order (shipped → user → project), shipped-defaults preservation
- `test-scorer.sh` — 1-5 rubric edge cases (kept from v0.1.3 with extensions for `--scope` flag)
- `test-consolidator.sh` — dedup threshold 0.7, source array merging
- `test-promotion.sh` — vote-count threshold T=4, suppression windows 30d/90d, instinct-style signal
- `test-codex.sh` — codex subprocess invocation, JSON parsing, schema validation, timeout handling
- `test-migration.sh` — v0.1.x state detection, .bak rename, principles preservation

Run: `bash architect-critic/tests/unit/test-*.sh`. Total target: ~200 assertions (up from ~154 in v0.1.3).

### 12.2 Integration tests (`tests/integration/`)

- `test-bug-repros.sh` — one regression test per issue #1 bug:
  | Bug | Regression test |
  |---|---|
  | #1 `$N` substitution | Run `/critique --spec custom-path.md` → assert path used, no $1/$2 corruption |
  | #2 silent no-op | Run `/critique` → assert challenges produced (not empty) |
  | #3 no MASTER-SPEC hard fail | Run `/critique` in dir with no MASTER-SPEC → assert discovery flow runs |
  | #4 rebuttal cycle skipped | Run `/critique` non-TTY → assert rebuttal challenges presented |
  | #5 codex availability surfaced | Run `/critique` with codex absent → assert status message |
  | #6 cost_usd | Assert field absent from state.json |
  | #7 README standalone | Assert README has standalone-use section |
  | #8 project_class consequence | Assert message documents what fallback means |

- `test-end-to-end.sh` — full critiquing-spec flow on a fixture spec, claude-only and close-depth paths
- `test-scaffold-onboard.sh` — scaffold-onboard v0.2 fixture invokes critiquing-spec, verifies in-conversation handoff

### 12.3 Eval harness (`tests/eval/`, LLM-as-judge)

Per grill-me decision #8 — Option B locked. Per [[claude-code-sessions-only]]: the harness runs **entirely inside a Claude Code session** using the `Agent` tool for both skill invocation and judge scoring. No API-based runner. No `claude-judge` / `claude-subagent` CLI wrappers. No third-party LLM providers.

**Structure:** for each of 4 skills, 5 fixture scenarios with expected judgment characteristics encoded in a rubric.

**Run flow:**
1. User opens Claude Code in the repo and pastes the prompt from `tests/eval/RUNBOOK.md` (or types *"run architect-critic evals"*).
2. Claude reads `RUNBOOK.md` and follows the procedure: for each fixture, dispatch `Agent` (subagent_type: general-purpose) with a prompt that reads the skill body and applies it to the fixture; capture output.
3. Claude dispatches a second `Agent` (judge, fresh context) with the rubric + fixture + skill output; judge returns JSON `{"scores": {...}, "pass": bool, "notes": "..."}`.
4. Per-fixture JSON results are written to `tests/eval/results/<skill>/<fixture_id>.json`.
5. `bash tests/eval/lib/aggregate-scores.sh` aggregates results into a pass/fail summary report.

**Why session-driven (not API-driven):** the project runs on Claude Code subscription accounts. API-based eval scripts incur metered cost and require key provisioning. Subscription Agent dispatches cover the harness for free, and writing the orchestration as a markdown RUNBOOK that Claude reads + executes is consistent with the rest of v0.2's skill-first design.

**Example rubric for `critiquing-spec`:**
```markdown
# Rubric: critiquing-spec

For the given fixture (a spec with a deliberately hidden assumption), score 1-5:
1. **Found the hidden assumption** — did the critic surface it as a challenge?
2. **Used CORE tone** — does at least one challenge open with curiosity-framing (e.g., "I might be missing something...")?
3. **Applied ghost-notes** — does the critic reference looking-for-absent-data anywhere?
4. **Severity labels valid** — every challenge has severity ∈ {premise, gap, alternative}?
5. **5-point rubric correctly used in rebuttal scoring** — when a stub rebuttal is provided, is the score in 1-5 range with consistent reasoning?

Pass threshold: ≥4/5 on each criterion. Run = pass if all 5 scenarios pass.
```

**Cost:** ~40 LLM calls per full eval run (4 skills × 5 scenarios × 2 calls). ~5-10min wall time. ~$1-2 in API equivalent (subscription accounts absorb).

**Gate:** runs on PR + release. NOT per-commit (too slow / expensive).

---

## 13. Build sequence

Per grill-me + handoff §3 Q7. TDD-driven; each phase produces a green test suite before advancing.

- **Phase 0 — Eval harness scaffolding + bug-repro fixtures.** Establish the eval orchestrator + 8 regression-test fixtures. These fail until corresponding skill bodies / fixes land.
- **Phase 1 — 4 SKILL.md bodies.** Author `critiquing-spec`, `reviewing-critique-history`, `listing-principles`, `promoting-principle` markdown bodies. Each makes its eval pass minimally.
- **Phase 2 — Reference sub-docs.** principles.md template with ghost-notes + CORE; output-schema.json for codex; CORE-tone phrasing examples; ghost-notes worked example. Lives under `templates/` + `skills/*/references/`.
- **Phase 3 — Slimmed `lib/`.** Keep state.sh (refactor for schema v2), principles.sh, scorer.sh, consolidator.sh; add promotion.sh, codex.sh, migration.sh; delete inbox.sh + outbox.sh.
- **Phase 4 — SessionStart hook.** `hooks-handlers/session-start.sh` — fail-open ambient status.
- **Phase 5 — Slash command wrappers.** Thin shells over skills using `$ARGUMENTS` env-var bridge. Fixes bug #1.
- **Phase 6 — Subagent pressure tests.** Invoke each skill from subagent; verify no orchestration deadlocks; verify codex subprocess invocation works under subagent context.
- **Phase 7 — Integration tests.** scaffold-onboard v0.2 fixture; scaffold-dev v0.1 fixture; verify in-conversation skill invocation works end-to-end.
- **Phase 8 — Migration smoke.** Drop fake v0.1.3 state into a temp HOME; run v0.2; verify .bak created, fresh state, principles preserved.
- **Phase 9 — Release.** plugin.json → 0.2.0; CHANGELOG; tag v0.2.0; marketplace.json updated; root README plugin table updated; close issue #1 with link to v0.2.0 commit.

Per [[feedback_subagent_vs_inline_threshold]]: if subagent dispatches fail in implementation, pivot to inline for that phase. Don't burn rounds.

---

## 14. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Codex 0.125+ `--output-schema` produces unconstrained output despite schema | Low | Test in Phase 3 `test-codex.sh`; if schema not enforced, add post-validation + retry-with-stricter-prompt fallback |
| LLM-judge evals flaky (nondeterministic) | Medium | Use temperature=0 for judge; multi-judge consensus for borderline cases; allow re-run on flake |
| Migration .bak rename overwrites previous .bak | Low | If `.v0.1.3.bak` exists, append timestamp (`.v0.1.3.bak.<unix-ts>`) |
| scaffold-onboard v0.2 + scaffold-dev v0.1 timelines slip → architect-critic v0.2 ships alone, consumers unhappy | Medium | Paired release: do NOT publish architect-critic v0.2 to marketplace until consumer SPECs are ready to consume. Coordinate ship order. |
| Codex subprocess deadlocks under subagent context (per [[feedback_subagent_vs_inline_threshold]]) | Low-Medium | Phase 6 explicitly pressure-tests this; if deadlock observed, pivot inline for codex-invoking skills |
| 5min codex timeout too short for large specs | Low | Configurable via `ARCHITECT_CRITIC_CODEX_TIMEOUT_S`; default surfaced in user-facing docs |

---

## 15. Open questions

All Q1-Q7 from the handoff settled by grill-me 2026-05-22→24 (see §9.1). All A.3 #1-#8 gaps from the planning pass also settled. No open questions remaining at SPEC time.

**Worth re-checking during PLAN authoring:**
- Eval harness LLM-judge nondeterminism — does 5 scenarios per skill × 1 run give stable enough signal, or do we need N=3 judge runs averaged?
- Migration: should principles.md `<!-- migrated from v0.1.x -->` tag also include the user's old v0.1.x version number?
- Codex output schema strictness: should `divergences` be required or optional? (Leaning optional — codex sometimes finds nothing-to-diverge-on.)

---

## 16. Iteration log

- **2026-05-22** Handoff `HANDOFF-architect-critic-v02-spec.md` authored from prior session.
- **2026-05-22** Verification pass identified 2 factual errors in handoff (test count 249→154; lib/compose.sh path) + 8 design gaps beyond Q1-Q7.
- **2026-05-22→24** grill-me settled 13 design decisions across Q1-Q7 + A.3 #1-#8. See [[project_architect_critic_v02_grill_settlements]].
- **2026-05-24** SPEC v0.2 draft authored (this document). PLAN authoring next.
