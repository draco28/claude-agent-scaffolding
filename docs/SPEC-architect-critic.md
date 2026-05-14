# SPEC: architect-critic plugin

**Status:** v0.1 design (brainstormed 2026-05-14) · not yet implemented
**Owner:** Praveen Kumar Singh
**Repo home:** `claude-agent-scaffolding` marketplace (this repo)
**Companion plugins:** `scaffold-onboard` (run-once onboarding, v0.1.0, already shipped) · `ai-mentor` (cognitive partner, v1.3.0, already shipped) · `scaffold` (continuous slice workflow, v1.0.0, already shipped) · `superpowers` (third-party skills library)
**Platforms:** Linux, macOS (Windows deferred — matches sibling plugins)
**Provenance:** Counterparty plugin to the file-based dispatch contract that `scaffold-onboard v0.1.0` ships at `lib/compose.sh` (`sf_compose_build_critic_request`, `sf_compose_read_critic_response`). Q1–Q5 (product decisions) inherited from `docs/SPEC-scaffold-onboard.md` §9 (settled 2026-05-11). D1–D8 (engineering decisions) + OQ-1/2/3 (meta) settled in this spec via Phase 0 brainstorm 2026-05-14, captured in `/Users/draco/.claude/plans/read-docs-handoff-architect-critic-buil-elegant-minsky.md`.

---

## 1. TL;DR

An anti-sycophancy reviewer plugin. The `/critique` command runs a **claude-self-audit** in the current Claude session and (at close depth) spawns a **codex fresh-frame audit** as a bash subprocess; a **consolidator** merges both adversaries' findings into the response envelope (`challenges` / `gaps` / `divergences`); an **interactive rebuttal cycle** then presents challenges with the `T=4` concession scoring rubric (1–5 against the bar; concedes only at ≥4); and an **auto-promotion** mechanism offers to add recurring patterns to the user-global `principles.md`.

The plugin is the file-IPC counterparty to `scaffold-onboard`: at Phase 5/7 recap and at MASTER-SPEC close, scaffold-onboard's `/onboard` body writes a request envelope to inbox, invokes `/critique` synchronously via the `SlashCommand` tool, and reads the response from outbox. The same `/critique` is also a standalone manual command — invoking it in any session synthesizes an envelope from defaults and runs the same audit pipeline.

Bash-orchestrated, no Python, no MCP server. Four slash commands · one SessionStart housekeeping hook · file-based IPC with atomic writes and lock-file protection.

---

## 2. Motivation

This plugin exists for one reason: **architectural mistakes made when the AI is too agreeable propagate silently through every slice that follows.** This is **P3** from `docs/SPEC-scaffold-onboard.md` §2 — pre-`/onboard`, the user has no mechanical gate that challenges premises before they're cemented; catching them mid-onboarding is cheap, catching them three slices later is expensive.

`scaffold-onboard` v0.1.0 shipped the *contract* for this gate (file-based JSON inbox/outbox per §8.3) and the *insertion points* (Phase 5 / Phase 7 recap, MASTER-SPEC close). What it did not ship is the counterparty that actually *runs* the audit. This plugin is that counterparty. Without it, scaffold-onboard's critic-dispatch hooks degrade to no-ops; with it, the gate is mechanical and structural.

Beyond the scaffold-onboard integration, the plugin stands alone: any Claude Code session in any project can `/critique` a spec, plan, or design document. The auto-promotion mechanism turns one-time challenges into accumulating user-global principles, building the file organically from real decisions rather than forcing cold authorship.

---

## 3. Goals & non-goals

### Goals

- **G1.** Honor the file-IPC contract defined in `docs/SPEC-scaffold-onboard.md` §8.3 — request envelope shape, response envelope shape, atomic outbox write, jq-then-mv guard pattern.
- **G2.** Standalone `/critique` invocable in any Claude Code session (with or without scaffold-onboard installed); synthesizes an envelope from defaults when invoked manually.
- **G3.** Codex CLI dispatch is **graceful** — `command -v codex` detects presence; absent, timeout, malformed JSON, or non-zero exit all degrade to claude-only with a warning, never crash the audit.
- **G4.** Anti-sycophancy via the **T=4 concession threshold** (firm, single, non-adaptive). Critic scores user rebuttals 1–5 against the specific challenge; concedes only at ≥4.
- **G5.** Principles file is **user-owned**: the plugin appends only via `/promote-principle` (manual) or auto-promotion (with explicit consent); never overwrites user edits. Comment-prefixed lines are inert.
- **G6.** **Full auto-promotion** ships in v0.1.0: pattern detection (within-run + cross-run), candidate generation, offer UX with accept/decline/edit flow, 30-day decline suppression.
- **G7.** Bash-orchestrated, no Python runtime, no MCP server. macOS-portable subset (BSD awk, bash 3.2 — no `declare -A`, no `trap RETURN`).
- **G8.** Convergent entry: programmatic (scaffold-onboard via SlashCommand) and manual (`/critique` user-typed) paths share the same audit pipeline. One contract, one test surface.

### Non-goals

- **NG1.** No daemon, no persistent watcher, no SessionStart inbox-scan UX (orphaned requests are rare; synchronous dispatch self-cleans on success/failure).
- **NG2.** No `PreToolUse` gating of edits while a critique is in flight. The synchronous SlashCommand dispatch makes "in-flight" degenerate.
- **NG3.** No cost-cap UX in v0.1.0 beyond a per-run cost line. No `/critique-budget`, no pre-flight estimate, no soft cap, no daily/project budget. Deferred to v0.2.
- **NG4.** No semantic / fuzzy similarity in the consolidator. Exact-match dedup only. Semantic clustering is a v0.2 refinement.
- **NG5.** Cross-platform Windows support — Linux and macOS only, matching sibling plugins.
- **NG6.** No `/critique-skip` slash command — Q3 settled the inline "skip" path lives in scaffold-onboard's prompt body, not a separate command. Anti-sycophancy is structural.
- **NG7.** No `/critique-status` command — largely redundant with `/critique-list`. Defer unless explicit need.

---

## 4. Architecture overview

```
┌────────────────────────────────────────────────────────────────────────────┐
│                       architect-critic plugin                              │
│              user-level install · per-user state in plugin-data            │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  /critique [--phase N] [--depth D] [--spec PATH]                   │    │
│  │   ┌─ inbox read + schema validate                                  │    │
│  │   ├─ principles load + merge (4 sources, concat-with-headers)      │    │
│  │   ├─ claude-self-audit (in-context reasoning)                      │    │
│  │   ├─ if depth=close: codex subprocess (180s timeout, JSON-strict)  │    │
│  │   ├─ consolidator (concat + source-tag + exact-dedup + divergence) │    │
│  │   ├─ outbox write (atomic mktemp+mv, jq-then-mv guard)             │    │
│  │   ├─ rebuttal cycle (1–5 rubric scoring, concede ≥4 else restate)  │    │
│  │   ├─ auto-promotion offer (within-run + cross-run pattern detect)  │    │
│  │   └─ post-run cost line (codex tokens × rate-card)                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  /critique-list [--limit N]    /promote-principle "<text>"         │    │
│  │  /principles-list                                                  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                            │
│  Side state (plugin-update-safe):                                          │
│    ${CLAUDE_PLUGIN_DATA}/architect-critic/                                 │
│    ├── principles.md                  (user-owned, plugin-append-only)     │
│    ├── state.json                     (in-flight, recent_runs, promotions) │
│    ├── inbox/<request_id>.json        (written by scaffold-onboard or self)│
│    └── outbox/<request_id>.json       (written by /critique)               │
│                                                                            │
│  Hooks: one SessionStart hook (housekeeping — clear stale in-flight >24h)  │
└────────────────────────────────────────────────────────────────────────────┘

Active dispatch flow (Phase 5/7 recap, MASTER-SPEC close):

┌─── scaffold-onboard ───┐                                  ┌─── architect-critic ──┐
│ /onboard reaches       │                                  │                       │
│   Phase 5 recap        │                                  │                       │
│     │                  │                                  │                       │
│     ├─▶ inline-skip    │  (Q3: "Type 'skip' to bypass")   │                       │
│     │   announce       │                                  │                       │
│     │                  │                                  │                       │
│     ├─▶ Bash:          │                                  │                       │
│     │   sf_compose_    │  ──▶  inbox/<rid>.json           │                       │
│     │   build_critic_  │                                  │                       │
│     │   request 5      │                                  │                       │
│     │                  │                                  │                       │
│     ├─▶ SlashCommand:  │  ──▶                             │  /critique <rid>      │
│     │   /critique <rid>│                                  │      │                │
│     │                  │                                  │      └─▶ (audit       │
│     │                  │                                  │           pipeline    │
│     │                  │                                  │           — see       │
│     │                  │                                  │           upper box)  │
│     │                  │                                  │                       │
│     │                  │  ◀──  outbox/<rid>.json written  │                       │
│     │                  │                                  │                       │
│     ├─▶ Bash:          │                                  │                       │
│     │   sf_compose_    │                                  │                       │
│     │   read_critic_   │                                  │                       │
│     │   response       │                                  │                       │
│     │                  │                                  │                       │
│     └─▶ user reviews   │                                  │                       │
│                        │                                  │                       │
└────────────────────────┘                                  └───────────────────────┘
```

### 4.1 Plugin manifest (`.claude-plugin/plugin.json`)

```json
{
  "name": "architect-critic",
  "version": "0.1.0",
  "description": "Anti-sycophancy reviewer. /critique runs claude-self-audit + (optionally) codex fresh-frame audit, consolidates into challenges/gaps/divergences, presents interactively with T=4 concession scoring, auto-promotes recurring patterns to user-global principles.md. File-based IPC counterparty to scaffold-onboard at Phase 5/7/close.",
  "author": { "name": "Pras" },
  "category": "workflow"
}
```

Four slash commands · one SessionStart hook · no MCP server · no install-time dependencies on other plugins (degrades gracefully when codex CLI is absent or scaffold-onboard isn't installed).

### 4.2 Directory layout

```
architect-critic/
├── .claude-plugin/plugin.json
├── commands/
│   ├── critique.md                       # /critique
│   ├── critique-list.md                  # /critique-list
│   ├── promote-principle.md              # /promote-principle
│   └── principles-list.md                # /principles-list
├── hooks/hooks.json                      # SessionStart (source-aware, housekeeping)
├── hooks-handlers/
│   └── session-start.sh                  # clears stale in_flight markers >24h
├── lib/
│   ├── _helpers.sh                       # shared bash helpers (logs, jq guards)
│   ├── state.sh                          # state.json CRUD; in_flight + recent_runs + promotions
│   ├── principles.sh                     # principles.md load + comment-strip + merge 4 sources
│   ├── inbox.sh                          # request envelope read + schema validation
│   ├── codex.sh                          # codex subprocess + 180s timeout + JSON-strict + mock-via-PATH
│   ├── consolidator.sh                   # concat + source-tag + exact-dedup + divergence detection
│   ├── scorer.sh                         # 1–5 rubric scoring; concede ≥4 else restate
│   ├── promotion.sh                      # within-run + cross-run pattern detection; candidate generation
│   ├── outbox.sh                         # response envelope write (atomic, jq-then-mv guard)
│   └── cost.sh                           # post-run cost line (codex tokens × rate-card)
├── templates/
│   └── principles.md                     # stub-with-examples seed (D3)
├── tests/
│   ├── _helpers.sh                       # assert_*, setup_tmp_repo, report_results (mirror of scaffold-onboard)
│   ├── fixtures/
│   │   ├── mock-codex/codex              # PATH-override mock binary
│   │   ├── codex-payloads/*.json         # canned codex JSON outputs
│   │   └── master-specs/*.md             # fixture MASTER-SPECs for E2E
│   ├── test-state.sh
│   ├── test-principles.sh
│   ├── test-inbox.sh
│   ├── test-codex.sh
│   ├── test-consolidator.sh
│   ├── test-scorer.sh
│   ├── test-promotion.sh
│   ├── test-outbox.sh
│   ├── test-commands.sh
│   └── test-e2e.sh
├── README.md
├── CHANGELOG.md
└── LICENSE
```

---

## 5. Commands

### 5.1 `/critique` — primary audit entry

**Trigger:** programmatic via `SlashCommand` tool from scaffold-onboard's `/onboard` body, OR manual via user-typed `/critique` in any Claude Code session.

**Args:**
- `--phase N` — only audit Phase N of MASTER-SPEC.md (depth defaults to `premise-audit`).
- `--depth premise-audit|close` — explicit depth override.
- `--spec PATH` — explicit spec path override (default: `./MASTER-SPEC.md`).
- `<request_id>` (positional, programmatic only) — when scaffold-onboard pre-wrote an inbox envelope, pass its id.

**Mode detection:**
- If `<request_id>` arg present AND `inbox/<request_id>.json` exists → **programmatic mode**: read envelope from inbox.
- Else → **manual mode**: synthesize envelope from defaults (find MASTER-SPEC.md in cwd; default principles to `${CLAUDE_PLUGIN_DATA}/architect-critic/principles.md`; infer `project_class` from `.onboarding-state.json` if present else `"unknown"`; default `depth=close`; default `adversaries=["claude","codex"]`; `accumulated_phases=[1..10]`); apply arg overrides; write to inbox; proceed.

**Algorithm:**

```
1. inbox read + schema validate (lib/inbox.sh)
   └─ on validation failure: print error, exit non-zero, suggest /critique with no args

2. principles load + merge (lib/principles.sh)
   ├─ user-global: ${CLAUDE_PLUGIN_DATA}/architect-critic/principles.md
   ├─ project context: MASTER-SPEC accumulated_phases content (only if onboarded)
   ├─ project patterns: .claude/memory-bank/03-code-patterns.md (only if exists)
   └─ project governance: .claude/memory-bank/08-governance.md (only if exists)
   → emit composed principles block with section headers

3. record in_flight in state.json (lib/state.sh)

4. claude-self-audit (in-context Claude reasoning)
   ├─ prompt assembled from: composed principles + spec content + 1–5 rubric + JSON output schema
   └─ output: list of challenges + gaps in JSON

5. if depth=close: codex subprocess (lib/codex.sh)
   ├─ command -v codex || (log info, skip, claude-only)
   ├─ pipe wrapper prompt to: timeout 180 codex --output-format json (or equivalent)
   ├─ jq parse stdout; on parse failure or non-zero: warn, claude-only fallback
   └─ output: list of codex challenges + gaps in JSON

6. consolidator (lib/consolidator.sh)
   ├─ concat both adversaries' challenge lists
   ├─ tag each item with source: claude|codex
   ├─ dedup where (severity, text, references) tuple matches exactly
   ├─ scan for cross-claims → divergences[]
   └─ concat gaps without dedup

7. outbox write (lib/outbox.sh)
   ├─ jq-then-mv guarded write to mktemp file
   └─ atomic mv to outbox/<request_id>.json

8. rebuttal cycle (lib/scorer.sh + interactive)
   for each challenge:
     present challenge to user
     user rebuts, accepts, edits, or notes
     if rebut: scorer.sh scores 1–5 against rubric
       ├─ score ≥4: concede ("Acknowledged — your rebuttal addresses this with material new info.")
       └─ score <4: restate ("That doesn't address X. The challenge stands.")
     loop until user accepts/edits/notes

9. auto-promotion offer (lib/promotion.sh)
   ├─ within-run: ≥2 challenges share normalized topic → candidate
   ├─ cross-run: scan recent_runs (last 20); ≥3 challenges share topic → candidate
   ├─ candidate generation: claude-reason "what one-line principle would prevent these?"
   ├─ check declined_candidates suppression (30 days)
   └─ for each candidate not suppressed:
        print offer (text + addressed-challenges + [y/n/e] prompt)
        on y: /promote-principle internally with --scope user, source: auto
        on n: record in declined_candidates with suppress_until = now + 30d
        on e: $EDITOR on candidate; on save promote, on cancel decline

10. post-run cost line (lib/cost.sh)
    ├─ codex tokens (if available) × rate-card → estimated cost
    └─ print "~$0.X spent on this audit (codex: $0.X, claude-self: $0)"

11. record completion in state.json:
    ├─ remove from in_flight
    └─ append to recent_runs (rolling cap 20): {request_id, completed_at, depth, adversaries_used, challenge_count, divergence_count, elapsed_ms, cost_usd}

12. return control to caller (scaffold-onboard via SlashCommand, or terminal directly)
```

**Outputs:**
- `${CLAUDE_PLUGIN_DATA}/architect-critic/outbox/<request_id>.json` — response envelope per §6.
- Updated `state.json`.
- Optionally appended `principles.md` (only if user accepts a promotion offer).
- Inline UI: rebuttal cycle output, promotion offer output, cost line.

### 5.2 `/critique-list [--limit N]`

**Trigger:** user-invoked. No args required. `--limit N` defaults to `10`.

**Algorithm:**

```
1. read state.json
2. read recent_runs[0..N-1] (most recent first)
3. for each run, render:
   - timestamp (relative: "5 min ago", "yesterday", etc.)
   - request_id (truncated)
   - depth
   - adversaries_used
   - challenge_count + divergence_count
   - elapsed_ms (formatted)
   - cost_usd
4. also list in_flight markers (if any) as a separate "Currently running" section
```

**Outputs:** terminal table.

### 5.3 `/promote-principle "<text>" [--scope user|project]`

**Trigger:** user-invoked OR called internally from `/critique`'s auto-promotion accept path.

**Args:**
- `<text>` (required, quoted) — the principle text. Single line.
- `--scope user` (default) — append to `${CLAUDE_PLUGIN_DATA}/architect-critic/principles.md`.
- `--scope project` — append to `.claude/memory-bank/03-code-patterns.md` (creates the file if absent and a memory-bank dir exists; errors if no memory-bank).

**Algorithm:**

```
1. validate <text> non-empty, single-line, ≤200 chars
2. compute target file from --scope
3. atomic append: lock + read + append "<text> [promoted YYYY-MM-DD source:manual|auto]" + write + unlock
4. record in state.json's principle_promotions:
   {timestamp, source, text, scope}
5. echo confirmation
```

### 5.4 `/principles-list`

**Trigger:** user-invoked. No args.

**Algorithm:**

```
1. principles.sh: compose the same merged set /critique would see
2. render to terminal with section headers:
   # User-global principles  (n entries)
   <list, comments stripped>

   # Project context (MASTER-SPEC phases X-Y)  (only if onboarded)
   <summary count>

   # Project patterns  (only if 03-code-patterns.md exists)
   <list>

   # Project governance  (only if 08-governance.md exists)
   <list>
```

---

## 6. Schemas

### 6.1 Request envelope (inbox)

**Verbatim from `docs/SPEC-scaffold-onboard.md` §8.3:**

```json
{
  "request_id": "crit-<iso>-<phase|close>-<entropy>",
  "depth": "premise-audit" | "close",
  "adversaries": ["claude"] | ["claude", "codex"],
  "target": {
    "type": "master-spec-phase" | "master-spec-full",
    "path": "<absolute path to MASTER-SPEC.md>",
    "phase_id": <int>            /* only when type == master-spec-phase */
  },
  "sources": {
    "principles": "<path to principles.md>",
    "accumulated_phases": [<int>, ...]
  },
  "concession_threshold": 4,
  "project_class": "<enum string>"
}
```

**Validation rules** (in order; fails on first ERROR):
- `request_id` non-empty string · ERROR
- `depth` in {`premise-audit`, `close`} · ERROR
- `adversaries` non-empty array; each entry in {`claude`, `codex`} · ERROR
- `target.type` in {`master-spec-phase`, `master-spec-full`} · ERROR
- `target.path` resolves to readable file · ERROR
- if `target.type == master-spec-phase`: `target.phase_id` is int 1–10 · ERROR
- `sources.principles` is a path string (file may not exist; that's a re-seed signal) · WARNING if missing
- `sources.accumulated_phases` is array of ints · ERROR
- `concession_threshold` in {1..5} (we expect 4) · ERROR
- `project_class` is a string (may be `"unknown"`) · WARNING if `null`

### 6.2 Response envelope (outbox)

```json
{
  "request_id": "<matches request>",
  "adversaries_used": ["claude"] | ["claude", "codex"],
  "challenges": [
    {
      "severity": "premise" | "gap" | "alternative",
      "text": "<challenge text>",
      "references": ["<phase or section ref>", ...],
      "source": "claude" | "codex"     /* extra-field — tolerated by scaffold-onboard */
    }
  ],
  "gaps": [
    { "text": "<gap text>", "severity": "info" | "warning", "source": "claude" | "codex" }
  ],
  "divergences": [
    {
      "between": ["claude", "codex"],
      "text": "<where they disagreed>",
      "references": ["<refs>", ...]
    }
  ],
  "elapsed_ms": <int>,
  "cost_usd": <number>            /* extra-field, OQ-3 */
}
```

`adversaries_used` MAY be a strict subset of the request's `adversaries` (graceful degradation when codex falls back).

### 6.3 state.json

```json
{
  "schema_version": 1,
  "in_flight": [
    {
      "request_id": "...",
      "started_at": "<iso>",
      "depth": "premise-audit" | "close",
      "phase_id": <int> | null
    }
  ],
  "recent_runs": [
    {
      "request_id": "...",
      "completed_at": "<iso>",
      "depth": "...",
      "adversaries_used": [...],
      "challenge_count": <int>,
      "divergence_count": <int>,
      "elapsed_ms": <int>,
      "cost_usd": <number>
    }
  ],
  "principle_promotions": [
    {
      "timestamp": "<iso>",
      "source": "manual" | "auto",
      "text": "...",
      "scope": "user" | "project"
    }
  ],
  "candidate_promotions": [
    {
      "discovered_at": "<iso>",
      "text": "<candidate principle>",
      "addresses": ["<challenge text 1>", ...],
      "signal": "within-run" | "cross-run"
    }
  ],
  "declined_candidates": [
    {
      "text": "...",
      "declined_at": "<iso>",
      "suppress_until": "<iso>"
    }
  ]
}
```

`recent_runs` is a rolling window (cap 20; oldest dropped on insert).
`candidate_promotions` is a transient queue (cleared on accept/decline/edit).
Lock-file protected at `${CLAUDE_PLUGIN_DATA}/architect-critic/state.lock` via the `compose.lock` pattern from scaffold-onboard.

### 6.4 principles.md grammar

```
Plain markdown. Three rules:

1. Lines beginning with `# ` (header) are inert — section markers only.
2. Lines beginning with `# ` followed by content (commented examples, like `# Prefer composition over inheritance`) are also inert.
   → distinguished from headers by user convention; both treated as inert.
3. All other non-blank lines are active principles.
   → trimmed of leading/trailing whitespace before use.
   → trailing `[promoted YYYY-MM-DD source:manual|auto]` annotation, if present, is stripped before display.
```

**Seed template** (shipped at `templates/principles.md`):

```markdown
# Architect-critic principles

This file is yours. The architect-critic loads it as the user-global principles set every audit.
Each line that doesn't begin with `#` is treated as an active principle. Edit freely; the critic
never overwrites your edits — it only appends via /promote-principle (manual) or auto-promotion
(with your consent).

## Your principles

(empty — add yours here, one per line)

## Examples (commented out — uncomment to activate)

# Prefer explicit over implicit configuration
# Push validation to system boundaries; trust internal code
# Every state-change operation needs a documented rollback path
# Avoid feature flags that outlive the experiment they gate
# Tests must hit real boundaries (DB, network) — mocks only at the seam
# Don't add fallbacks for scenarios that can't happen
# A bug fix doesn't need surrounding cleanup
```

---

## 7. Derivations

### 7.1 Consolidator algorithm (D2)

```
input:
  claude_audit  = { challenges: [{severity, text, references}, ...],
                    gaps: [{text, severity}, ...] }
  codex_audit   = { challenges: [...], gaps: [...] }   /* may be empty if codex skipped */

step 1 — concat challenges:
  for each c in claude_audit.challenges: tag c with source="claude" → all_ch
  for each c in codex_audit.challenges:  tag c with source="codex"  → all_ch

step 2 — exact-match dedup:
  group all_ch by (severity, text-normalized, references-sorted)
  for each group with >1 member: keep first; mark as agreed-by-both if sources differ
  result → challenges_deduped

step 3 — divergence detection:
  for each (claude-only) challenge with phase reference R:
    if any codex item with reference R exists with disagreeing severity → divergences.append
  for each (codex-only) challenge with phase reference R:
    same check, mirrored

step 4 — gaps:
  concat claude_audit.gaps + codex_audit.gaps; tag source; no dedup
  → gaps_combined

output:
  { challenges: challenges_deduped,
    gaps: gaps_combined,
    divergences: divergences,
    adversaries_used: derived from which audits ran }
```

### 7.2 Pattern detection (auto-promotion · OQ-1)

```
input:
  current_run.challenges  = [{severity, text, references, source}, ...]
  state.recent_runs[0..N-1]  /* last 20 */
  state.declined_candidates  /* with suppress_until timestamps */

step 1 — within-run topic clustering:
  topic(c) = lowercase + stem(text first 5 words) + sort(references)
  group current_run.challenges by topic
  for each group with size ≥2:
    candidate = synthesize_principle(group)
    signal = "within-run"
    candidates.append

step 2 — cross-run topic clustering:
  for each c in current_run.challenges:
    same_topic_count = count(c2 in flatten(recent_runs.challenges) where topic(c2) == topic(c))
    if same_topic_count ≥ 3:
      candidate = synthesize_principle(c + matching c2's)
      signal = "cross-run"
      candidates.append

step 3 — synthesize_principle (claude-reasoning):
  prompt = "You are summarizing a recurring critique theme into one short prescriptive principle.
            Challenges:\n  - <text 1>\n  - <text 2>\n...
            Return a single line, imperative voice, ≤120 chars, no preamble."
  candidate.text = claude_response

step 4 — suppression filter:
  for each candidate:
    if exists d in declined_candidates where d.text == candidate.text and d.suppress_until > now:
      drop candidate

step 5 — write candidates to state.json.candidate_promotions for /critique to surface
```

`synthesize_principle` is a Claude-reasoning step inside `/critique`'s body. It is not unit-tested in `test-promotion.sh` (which uses canned candidate text); E2E tests exercise it.

### 7.3 Concession scoring (D2 follow-up · Q4)

```
rubric (verbatim from SPEC-scaffold-onboard §9 Q4):
  1. Bare contradiction
  2. Cite-self (points to spec without new info)
  3. Partial address
  4. Material new info
  5. Premise invalidated

algorithm (lib/scorer.sh):
  input: challenge text, user rebuttal text
  step 1 — heuristic check:
    if rebuttal length < 20 chars and matches /^(no|wrong|disagree|not true)/i → score = 1
    if rebuttal is substring of MASTER-SPEC content → score = 2 (cite-self)
    if rebuttal references new fact not in MASTER-SPEC → score ≥ 4 (material)
    else → defer to claude-reasoning
  step 2 — claude-reasoning fallback:
    prompt = "Score this rebuttal against the challenge on the 1–5 rubric. Return only the integer.
              Challenge: <text>
              Rubric:
                1 = bare contradiction
                2 = cite-self
                3 = partial address
                4 = material new info
                5 = premise invalidated
              Rebuttal: <text>"
  output: integer 1–5

decision:
  if score ≥ 4 → concede (return "Acknowledged — your rebuttal addresses this.")
  else → restate (return "That doesn't address X. The challenge stands.")
```

The heuristic check covers the most common cases cheaply; the claude-reasoning fallback handles ambiguity. Tests in `test-scorer.sh` cover the heuristic paths; E2E covers the fallback.

---

## 8. Integration

### 8.1 With scaffold-onboard (programmatic, file-IPC)

scaffold-onboard's `lib/compose.sh` ships the writer (`sf_compose_build_critic_request`) and the reader (`sf_compose_read_critic_response`). architect-critic's contract is:

- **Read** from `${CLAUDE_PLUGIN_DATA}/architect-critic/inbox/<request_id>.json` per §6.1 schema.
- **Write** to `${CLAUDE_PLUGIN_DATA}/architect-critic/outbox/<request_id>.json` per §6.2 schema.
- **Honor** the `concession_threshold` field (set to `4` by scaffold-onboard).
- **Honor** the `principles` and `accumulated_phases` source fields (use them in §7's principle composition).

**Dispatch trigger:** D4 settled — scaffold-onboard's `/onboard` body uses the `SlashCommand` tool to invoke `/critique <request_id>` synchronously between writing the inbox file and reading the outbox file. The polling loop (`sf_compose_read_critic_response`) becomes a degenerate "file already there" check + a hard timeout safety net.

**OQ-2 reciprocal delta to scaffold-onboard** (shipped in same branch as architect-critic v0.1.0):
1. Add `allowed-tools: ["SlashCommand"]` to `scaffold-onboard/commands/onboard.md` frontmatter.
2. Update onboard.md body at Phase 5 recap, Phase 7 recap, MASTER-SPEC close: between the existing `sf_compose_build_critic_request` and `sf_compose_read_critic_response` calls, insert a `SlashCommand` invocation of `/critique <request_id>` gated on `architect-critic` installed (per `composition.json`).
3. Implement Q3's inline "skip" path in scaffold-onboard's prompt body: announce "Running architect-critic [audit type]. Type 'skip' to bypass this fire."; if user types `skip`, log "skipped by user" and proceed without dispatch.
4. Add a mock /critique handler to scaffold-onboard's `tests/test-e2e.sh` so E2E tests stay hermetic after the dispatch wiring.

**Regression guarantee:** scaffold-onboard's `tests/test-compose.sh` continues to pass (those 31 tests exercise lib functions, not slash-command bodies).

### 8.2 Standalone use (manual, no scaffold-onboard)

When invoked manually as `/critique` (no `<request_id>` arg, no scaffold-onboard installed):

- /critique synthesizes a request envelope from defaults (see §5.1 Mode detection).
- Writes the envelope to `inbox/` itself.
- Runs the same audit pipeline.
- Writes the response to `outbox/`.
- Presents inline (rebuttal cycle, promotion offer, cost line).

This is the convergent entry path (D7). Manual mode is just programmatic mode with envelope synthesized from defaults.

### 8.3 With ai-mentor

No coupling. ai-mentor's `grill-me` sibling skill is a different tool (surfaces *unmade decisions*, this plugin scores *user rebuttals to challenges*). Both can be active in the same session without interference.

### 8.4 With superpowers

No coupling. The brainstorming skill is a separate workflow surface; architect-critic is a reactive auditor. They compose naturally — brainstorm to settle a design, then `/critique` it.

---

## 9. Decisions

### 9.1 Inherited from `docs/SPEC-scaffold-onboard.md` §9 (settled 2026-05-11 — interface-defining)

**Q1 · Insertion point:** selective per-phase + final pass — auto-fire after Phase 5 + Phase 7 recaps (claude-only premise audit, ~30s each), plus full pass at MASTER-SPEC close (claude gap sweep + Codex fresh-frame, ~2–3 min).

**Q2 · Cross-model adversary:** Codex only. Single fresh-frame lineage at close. Fresh-frame given just MASTER-SPEC + project_class (no Claude reasoning context).

**Q3 · Activation default:** always-on with per-occurrence inline skip. Anti-sycophancy is structural; no session-wide kill switch, no ask-each-time prompt. The skip path lives in scaffold-onboard's prompt body, not as a separate command.

**Q4 · Concession threshold:** T=4 firm. 1–5 rubric (1=bare contradiction · 2=cite-self · 3=partial address · 4=material new info · 5=premise invalidated). Concedes only at ≥4. Single threshold, not adaptive.

**Q5 · Principle ingestion:** user-global + project, accumulating. User-global at `${CLAUDE_PLUGIN_DATA}/architect-critic/principles.md` (plugin-owned, user-editable, seeded on first install). Project-specific from in-flight MASTER-SPEC phases + post-onboarding from `.claude/memory-bank/03-code-patterns.md` + `08-governance.md`. Auto-promotion design intent **yes**, implementation **no longer deferred** (see OQ-1 below).

### 9.2 Engineering decisions (settled 2026-05-14 — implementation-defining)

**D1 · Codex CLI dispatch:** bash subprocess; `command -v codex` for detection; strict-JSON contract (jq parse, fail-loud); `timeout 180 codex …` hard cap; PATH-override mock binary for tests; on any failure (absent / timeout / malformed / non-zero) → log warn, fall back to claude-only, set `adversaries_used=["claude"]`.

**D2 · Consolidator:** concat both adversaries' challenge lists; tag each with extra-field `source:claude|codex`; dedup where `(severity, text, references)` matches exactly; scan for cross-claims → emit to `divergences[]`. Gaps concatenated without dedup. Rebuttal cycle owned by `/critique` (critic plugin, not scaffold-onboard).

**D3 · Principles file lifecycle:** stub-with-examples seed template (preamble + `## Your principles` empty + `## Examples (commented out)`). Critic appends only via `/promote-principle` or auto-promotion; never overwrites user edits. Comment-prefixed lines inert. Composition at audit time = concatenate-with-section-headers across 4 sources.

**D4 · Watcher / dispatch trigger:** synchronous SlashCommand. scaffold-onboard's `/onboard` body invokes `/critique` via the `SlashCommand` tool; same Claude session; outbox written before scaffold-onboard's polling loop runs; polling becomes a degenerate "file already there" + hard timeout safety net.

**D5 · Command surface:** four slash commands — `/critique`, `/critique-list`, `/promote-principle`, `/principles-list`. Skipped: `/critique-skip` (Q3 inline path), `/critique-status` (redundant with `/critique-list`), `/critique-budget` (deferred per OQ-3).

**D6 · Hook integration:** one `SessionStart` hook only (housekeeping — clear stale `in_flight` markers >24h). state.json at `${CLAUDE_PLUGIN_DATA}/architect-critic/state.json`, lock-file protected. No PreToolUse, no UserPromptSubmit, no PostToolUse.

**D7 · Composition entry:** convergent envelope-driven. Both programmatic (scaffold-onboard) and manual (`/critique`) paths use the same audit pipeline. Manual mode synthesizes envelope from defaults.

**D8 · Test fixture strategy:** ~10 bash suites, ~120–160 tests. Mock-codex via PATH override (`tests/fixtures/mock-codex/codex` shell script). Wall-clock budget <30s for full regression.

### 9.3 Meta-decisions (settled 2026-05-14 — scope-defining)

**OQ-1 · Auto-promotion in v0.1.0:** **FULL ships in v0.1.0** (scope-expanding decision; user override of recommendation). Pattern detection (within-run + cross-run) + candidate generation (claude-reasoning) + offer UX (accept/decline/edit) + 30-day decline suppression. New library `lib/promotion.sh`; new test suite `test-promotion.sh` (~15 tests). Phase E expanded from ~6 to ~12 tasks.

**OQ-2 · scaffold-onboard hook chain delta:** **same-branch wiring delta.** The `implementation-architect-critic` branch touches both `architect-critic/` AND `scaffold-onboard/commands/onboard.md` + `scaffold-onboard/tests/test-e2e.sh`. Single PR, single ship, full integration on first install of both plugins. scaffold-onboard's `test-compose.sh` continues to pass.

**OQ-3 · Cost-cap UX in v0.1.0:** **post-run cost line only.** Each `/critique` prints `~$0.X spent on this audit (codex: $0.X tokens, claude-self: $0)` after the rebuttal cycle. Cumulative tracked in `state.json.recent_runs[].cost_usd`; `/critique-list` displays as a column. No `/critique-budget`, no pre-flight estimate, no soft cap. Deferred: cumulative budget UX, soft cap, dedicated command.

---

## 10. Error handling

| Trigger | Severity | Behavior | Recovery |
|---|---|---|---|
| `${CLAUDE_PLUGIN_DATA}` not writable | FATAL | Exit before any file write | "Check perms on plugin data dir" |
| Inbox file malformed JSON | ERROR | Exit non-zero; log validation errors | "Fix or re-write inbox envelope" |
| Inbox file fails schema validation | ERROR | Exit non-zero; print failed rules | "Check request envelope per SPEC §6.1" |
| Codex CLI not installed | WARNING | Skip codex; set `adversaries_used=["claude"]`; log info | "Install codex CLI to enable cross-model audit" |
| Codex subprocess times out (>180s) | WARNING | Kill subprocess; claude-only fallback | "Check network / codex CLI version" |
| Codex returns non-JSON | WARNING | Parse failure; claude-only fallback | "Re-run; codex output may be flaky" |
| Codex returns non-zero exit | WARNING | Claude-only fallback | "Check codex CLI auth / quota" |
| Outbox write `jq` failure | ERROR | Guard pattern: rm tmp; log error; return non-zero | "Check disk space / permissions" |
| state.json corrupt | ERROR | Refuse to read; log; reseed empty schema | "Move state.json to .bak; rerun" |
| principles.md missing | recoverable | Re-seed from template at `templates/principles.md` | Transparent |
| Concurrent `/critique` invocations | WARNING | Lock file at `${CLAUDE_PLUGIN_DATA}/architect-critic/state.lock`; second waits up to 5s, then refuses | "Wait or remove lock" |
| User Ctrl-C mid-rebuttal | expected | State persisted; in_flight marker remains (cleared on next SessionStart housekeeping) | Re-invoke `/critique <request_id>` to resume |
| Promotion `--scope project` outside memory-bank | ERROR | Exit non-zero | "Run /scaffold-project first or use --scope user" |
| Auto-promotion candidate generation fails | recoverable | Skip the offer; log info | Critique completes normally |

---

## 11. Edge cases

| Scenario | Behavior |
|---|---|
| Manual `/critique` outside an onboarded repo (no MASTER-SPEC.md) | Prompt: "No MASTER-SPEC.md found. Pass `--spec PATH` or run `/onboard` first." |
| Manual `/critique` outside any git repo | Same prompt; suggest `git init` or `--spec PATH` |
| principles.md user-deleted between runs | Re-seed from template; log "principles.md re-seeded — your prior content was not recoverable" |
| Codex CLI version mismatch (different output schema) | Treat as malformed JSON path → claude-only fallback |
| state.json schema version skew (v1 vs future v2) | Future versions: `state_migrate.sh` per scaffold-onboard pattern; v0.1.0 only knows v1 |
| Declined candidate re-offered after suppress_until expires | Yes — re-offered if pattern still present |
| User accepts a candidate that's already in principles.md | Idempotent: append-with-dedup; log "principle already present" |
| Concurrent `/critique` in multiple worktrees of same repo | Each session runs independently; state.json keyed by user-global path (no per-repo isolation) |
| User rebuts with a multi-paragraph response | Scorer truncates to first 500 chars; falls through to claude-reasoning fallback |
| codex-only audit (no claude-self-audit possible somehow) | Architecturally impossible — claude-self-audit is in-context and always runs first |
| Empty challenges + empty gaps after audit | Print "No challenges. Spec passes premise audit at this depth."; skip rebuttal cycle and promotion offer |

---

## 12. Testing strategy

Ten bash test suites mirroring scaffold-onboard's pattern. Pure bash, no Python or framework dependencies, CI-friendly exit codes. Target: ~120–160 tests total.

| Suite | Target | Coverage |
|---|---|---|
| `test-state.sh` | ~15 | state.json CRUD, in_flight tracking, recent_runs rolling window (cap 20), lock-file behavior, schema migration tolerance, concurrent-write refusal |
| `test-principles.sh` | ~12 | principles.md load, comment stripping, project-specific composition (4 sources), missing-source graceful degradation, re-seed on missing |
| `test-inbox.sh` | ~10 | request envelope read + schema validation per §6.1, rejection of malformed JSON, rejection on missing required fields |
| `test-codex.sh` | ~15 | mock-via-PATH binary, JSON parse success, JSON parse failure → fallback, 180s timeout via `timeout(1)`, non-zero exit → fallback, codex-absent → fallback, `adversaries_used` downgrade |
| `test-consolidator.sh` | ~15 | concat, source-tagging, exact-match dedup, divergence detection (4 cross-claim permutations), gap concatenation, empty-input cases |
| `test-scorer.sh` | ~10 | rubric 1–5 heuristic paths (bare contradiction, cite-self, material new info), concession at ≥4, restate at <4, multi-paragraph truncation |
| `test-promotion.sh` | ~15 | within-run pattern detection (≥2 same topic), cross-run detection (≥3 across recent_runs), candidate generation (with canned LLM output), offer UX state transitions, 30-day decline suppression, declined-candidate re-offer after expiry |
| `test-outbox.sh` | ~8 | response envelope write (atomic mktemp+mv), schema-correct shape, jq-then-mv guard pattern (clean tmp on failure), idempotent re-write |
| `test-commands.sh` | ~12 | /critique synth-from-defaults, /critique-list rendering with various recent_runs sizes, /promote-principle scope routing (user vs project), /principles-list merge rendering with absent sources |
| `test-e2e.sh` | ~12 | empty repo + manual /critique, onboarded repo + /critique --phase 5, full close-depth audit with mock codex, rebuttal cycle (3 challenges, mixed accept/rebut), promotion offer accept-and-decline paths, post-run cost line |
| **Total** | **~124** | (with headroom to ~160 if edge-case clusters expand) |

**Mock-codex fixture:** `tests/fixtures/mock-codex/codex` — shell script that reads stdin (ignores it), checks env var `MOCK_CODEX_OUTPUT` for the path to a canned JSON payload (e.g., `tests/fixtures/codex-payloads/3-challenges.json`), echoes its contents to stdout, exits 0. Tests prepend `tests/fixtures/mock-codex/` to `PATH` to intercept the `codex` binary lookup.

**Wall-clock budget:** target full regression < 30s (scaffold-onboard's ~16s + this plugin's surface roughly doubles wall-clock).

Run all suites: `for t in architect-critic/tests/test-*.sh; do bash "$t"; done`.

---

## 13. Build sequence

Eight phases A–H, mirror of scaffold-onboard's pattern. Each phase ends with one phase-close commit + CHANGELOG entry + PLAN's "Implementation Status" updated.

| Phase | Deliverable | Suite added | Est. tasks |
|---|---|---|---|
| **A** | Plugin scaffold: `.claude-plugin/plugin.json`, `commands/` stubs (4 cmds per D5), `lib/_helpers.sh`, `templates/principles.md` seed (D3), README, LICENSE, CHANGELOG | (helpers seeded) | ~5 |
| **B** | `lib/state.sh` (D6 schema), `lib/principles.sh` (4-source merge per D3), `lib/inbox.sh` (envelope read + validate per §6.1) | `test-state.sh`, `test-principles.sh`, `test-inbox.sh` | ~12 |
| **C** | All 4 slash command bodies per D5; envelope synthesis per D7; commands wire to libs but audit pipeline still stubbed | `test-commands.sh` | ~8 |
| **D** | `lib/codex.sh` (D1), `lib/consolidator.sh` (D2), `lib/scorer.sh` (Q4 rubric), `lib/outbox.sh` (§6.2 write), `lib/cost.sh` (OQ-3) | `test-codex.sh`, `test-consolidator.sh`, `test-scorer.sh`, `test-outbox.sh` | ~14 |
| **E** | Auto-promotion FULL (OQ-1): `lib/promotion.sh` (within-run + cross-run detection, candidate generation, offer UX, suppression). Principles edge cases: re-seed, user-deletion recovery | `test-promotion.sh` | ~12 |
| **F** | Composition + hook + scaffold-onboard delta: `hooks/hooks.json` + `hooks-handlers/session-start.sh` (D6 housekeeping). **OQ-2 same-branch wiring delta:** edit `scaffold-onboard/commands/onboard.md` for SlashCommand frontmatter + dispatch /critique at Phase 5/7/close + Q3 inline-skip; update `scaffold-onboard/tests/test-e2e.sh` mock handler | `test-state.sh` extension; scaffold-onboard regression check | ~8 |
| **G** | E2E on fixture MASTER-SPEC.md with mock codex; full audit cycle (build → audit → outbox → rebuttal → promotion offer → accept); README polish; CHANGELOG entries; portability sweep | `test-e2e.sh` | ~5 |
| **H** | Bump to v0.1.0; add to `.claude-plugin/marketplace.json`; root README plugin table → 4 rows; tag `architect-critic-v0.1.0`; push tag | (regression) | ~3 |

**Total estimated tasks:** ~67 across A–H.
**Total target test count:** ~124 (cap ~160).

---

## 14. Risks

- **R1 (medium)** · **Auto-promotion noise.** Pattern detection may surface candidates the user finds repetitive or low-value. Mitigation: 30-day decline suppression; conservative thresholds (≥2 within-run, ≥3 cross-run); user can disable per-fire by typing `n` to the offer prompt. Revisit thresholds if real-world friction surfaces.
- **R2 (medium)** · **Codex CLI install / auth friction.** Codex CLI requires its own installation and OpenAI auth; users without it lose the cross-model adversary at close. Mitigation: graceful fallback to claude-only with a one-line warning; codex availability is documented in README as optional-but-recommended.
- **R3 (medium)** · **Rebuttal-cycle UX feels heavy.** Some users will find the 1–5 scoring loop tedious for short audits. Mitigation: heuristic check in scorer.sh handles obvious cases (bare contradiction, cite-self) without LLM round-trip; concession is unambiguous when it happens; user can `accept` to skip rebuttal entirely.
- **R4 (low)** · **state.json corruption from concurrent runs.** Two `/critique` invocations in different sessions could race on state.json writes. Mitigation: lock file at `${CLAUDE_PLUGIN_DATA}/architect-critic/state.lock`; second invocation waits up to 5s, then refuses with a clear error.
- **R5 (low)** · **Pattern detection false positives.** Topic clustering via simple stemming + reference-overlap may surface candidates that don't actually share a principle. Mitigation: candidate generation is claude-reasoning (not pure heuristic), so the synthesized principle is a sanity check; user can decline with `n`.
- **R6 (low)** · **scaffold-onboard regression risk from same-branch delta.** Editing `scaffold-onboard/commands/onboard.md` and `tests/test-e2e.sh` could break scaffold-onboard's existing test suite. Mitigation: `test-compose.sh` (the contract test) does not exercise slash-command bodies, so its 31 tests stay green; the e2e mock-handler addition is additive, not breaking; full scaffold-onboard regression run before phase-close commit.

---

## 15. Open questions

None remaining post-brainstorm. All 8 §3 design points + 3 OQ-meta-questions settled per §9.

If real-world use surfaces friction, the most likely v0.2 candidates are:
- **OQ-3 follow-up:** richer cost-cap UX (`/critique-budget`, soft cap, daily/project budgets).
- **D2 follow-up:** semantic / fuzzy similarity in the consolidator (currently exact-match only).
- **OQ-1 follow-up:** cross-project pattern detection (currently per-user-installation, not per-team).
- Windows support (currently macOS + Linux only).

---

## 16. Iteration log

- **v0.1 (2026-05-14):** Initial design after Phase 0 brainstorm. All 8 §3 engineering design points (D1–D8) + 3 OQ-meta-questions (OQ-1 auto-promotion, OQ-2 scaffold-onboard delta, OQ-3 cost UX) settled. Auto-promotion scope expanded vs. recommendation per user direction (OQ-1 = FULL in v0.1.0, not deferred). Same-branch scaffold-onboard wiring delta locked (OQ-2). Plugin separation from ai-mentor's `grill-me` confirmed (different tool: surfaces unmade decisions vs scores rebuttals to challenges). Q1–Q5 inherited verbatim from `docs/SPEC-scaffold-onboard.md` §9 — interface-defining, the critic plugin must honor them. Total estimated build: ~67 tasks across Phases A–H, ~124 tests across 10 suites, target wall-clock <30s for full regression. Companion brainstorm transcript and visual artifacts in `.superpowers/brainstorm/56102-1778732670/`.
