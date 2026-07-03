# SPEC: scaffold-dev plugin

**Status:** v0.1 — brainstorm complete 2026-05-21; **adversarial-review revisions applied 2026-05-22**. Awaiting build of dependencies (scaffold-onboard v0.2 + architect-critic v0.2) before scaffold-dev PLAN authoring.
**Owner:** Praveen Kumar Singh
**Repo home:** `claude-agent-scaffolding` marketplace
**Position:** Third plugin in marketplace chain — `workspace-init` → `scaffold-onboard` → **`scaffold-dev`** → `architect-critic` + `ai-mentor`
**Platforms:** Linux, macOS
**Predecessor:** Replaces (deprecates) scaffold v1.0.0.
**Build gate:** scaffold-dev v0.1 build is GATED on scaffold-onboard v0.2 + architect-critic v0.2 shipping first (so the R1/R2/R3 contract + skill-based critic invocation exist when scaffold-dev builds).

---

## Brainstorm progress

| Sub-pass | Status |
|---|---|
| **B1** | ✅ COMPLETE — identity, scope, transition, workspace-init composition |
| **B2** | ✅ COMPLETE — vertical-slice lifecycle (orchestrator side) |
| **B3** | ✅ COMPLETE — implementer flow + verification + slice-close ceremony |
| **B4** | ✅ COMPLETE — memory bank + peer composition |
| **B5** | ✅ COMPLETE — state, hooks, build, retrospectives, risks, edge cases |
| **Spec review pass** | ✅ COMPLETE (2026-05-22) — adversarial + grill-me; revisions applied |

---

## 1. TL;DR

A run-continuous Claude Code plugin implementing **orchestrator-implementer workflow** for sprint-driven dev on dual-repo workspaces. Replaces deprecated scaffold v1.0.0.

**Orchestrator session** plans a vertical slice (≈ user epic) into 4-5 feature-sized work items (~200-500 LOC each), identifies parallel-vs-sequential rounds (strict-layer DAG), authors all specs upfront, offers grill-me + invokes architect-critic on specs (in-conversation skill invocation), then per-round: spawns canonical worktrees, authors implementation handoffs, **invokes purpose-built implementer-agent subagent via Task tool**, processes returns (gaps-mode → user clarification + re-invoke; complete-mode → verify + commit + merge), cleans up. At slice close: 3-layer ceremony (auto demo + manual demo + architect-critic adversarial), then retrospective with memory bank harvest.

**Implementer-agent subagent** (NEW from spec review): scaffold-dev-defined custom subagent type invoked by orchestrator via Task tool. Runs in isolated context with handoff doc path as argument. Returns structured response (`mode: gaps-surfaced` with gaps list, OR `mode: complete` with report path). Implementer's "session" is no longer a separate Claude session the user spawns — it's an orchestrator-spawned subagent. Eliminates manual copy/paste workflow.

---

## 2. Motivation

**P1** — scaffold v1.0.0 was CLI-tool-shaped, bash-orchestrated, single-repo.

**P2** — Wabash project proved orchestrator-implementer pattern works.

**P3** — "Sprint without demo" recurring failure mode. 3-layer slice-close ceremony enforces demoable-end-to-end.

**P4 (new from spec review)** — Manual session-handoff workflow was heavy. Subagent automation eliminates copy/paste/switch-terminal overhead while preserving context isolation between orchestrator and implementer.

---

## 3. Goals, non-goals, transition

### 3.1 Inventory of scaffold v1.0.0

(Per earlier SPEC iterations — 4 capabilities, 18 slash commands, 10 MCP tools, SessionStart source-aware hook.)

### 3.2 Port / drop / redesign

Headline: drop all of v1.0.0's `/scaffold-*` and CLAUDE.md commands; port slice 5-phase concept + worktree primitive + test framework detection + state partitioning + SessionStart hook; redesign slice spec → adapted Wabash Format B + slash commands → skills + governance commands → skills + manifest-routed; drop MCP memory bank entirely.

### 3.3 Goals

G1. Codify orchestrator-implementer workflow with subagent automation.
G2. Skill-first.
G3. Strict workspace-init dependency.
G4. Replace v1.0.0 cleanly.
G5. Demoable end-to-end at slice close.
G6. Feature-sized work items.
G7. Compose with architect-critic + ai-mentor.

### 3.4 Non-goals

NG1. Single-repo support. NG2. v1.0.0 migration. NG3. MCP memory bank. NG4. Pipelined rounds. NG5. Auto-decomposition. NG6. Project plan authoring. NG7. Cross-machine state sync. NG8. Cognitive-mode enforcement.

---

## 4. Architecture overview

### 4.1 Marketplace chain

`workspace-init` → `scaffold-onboard` v0.2 → **`scaffold-dev`** → `architect-critic` v0.2 + `ai-mentor` v2.0 (shipped 2026-05-24 as scope-cut release; the originally-planned v1.4 expanded retrofit was descoped — grill-me retained as the surviving cognitive-partner skill that scaffold-dev composes with).

### 4.2 Coupling tier

Tight read on manifest (read-only). Refuses to start without manifest. workspace-init sole writer.

### 4.3 Two execution contexts (orchestrator + implementer subagent)

```
┌──────────────────────────────────────────────────────────────────────────┐
│            ORCHESTRATOR SESSION (in AI workspace, high-effort model)     │
│                                                                          │
│   reads: project plan, MASTER-SPEC, memory bank, ADRs, backlog, SRS      │
│   does:  decompose VS → work items                                       │
│          identify rounds (strict-layer DAG)                              │
│          author all specs upfront                                        │
│          OFFER grill-me + INVOKE architect-critic on specs               │
│          per round: spawn worktree, author handoff                       │
│          INVOKE implementer-agent subagent via Task tool ─────┐          │
│          process subagent return (gaps-mode | complete-mode)  │          │
│          verify + commit + merge + cleanup                    │          │
│          slice close: demo + critic + retrospective + harvest │          │
│                                                               │          │
└───────────────────────────────────────────────────────────────┼──────────┘
                                                                ▼
┌──────────────────────────────────────────────────────────────────────────┐
│      IMPLEMENTER-AGENT SUBAGENT (isolated context, parent-spawned)       │
│                                                                          │
│   inputs:  handoff doc path (passed in prompt)                           │
│   tools:   Bash + Read + Write + Edit + Glob + Grep                      │
│            (NO Task, NO commit ops — implementer never commits)          │
│   skills:  executing-work-item (as system prompt baked into subagent)    │
│            superpowers:test-driven-development                           │
│            superpowers:verification-before-completion                    │
│   does:    pre-flight check → if gaps detected, return                   │
│              { mode: "gaps-surfaced", gaps: [...] }                      │
│            if clean: TDD loop per AC → verification commands             │
│            → author report.md → stage changes (no commit)                │
│            return { mode: "complete", report_path, summary,              │
│                     stage_status }                                       │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

The split is **subagent-bounded**, not session-bounded (CHANGED from prior version). One Claude session (orchestrator) drives the whole VS lifecycle; subagents handle implementation work in isolated contexts via Task tool.

### 4.4 Hierarchy + numbering

Phase (~4, no prefix) → Sprint (`sprint_id` = `<phase>.<sprint>`, e.g. `1.1`) → Vertical slice (3-part `VS-<phase>.<sprint>.<slice>`, e.g. `VS-1.1.1`) → Work item (`<slice-index>.<nn>`, e.g. `1.01`) → Round (strict-layer DAG within slice).

**Slice-ID arity + field-read contract (#28).** scaffold-onboard authors the canonical 3-part slice id and publishes a structured `project-roadmap.json` (manifest `well_known_paths.roadmap_state`) whose slice records carry explicit `id` + `sprint_id` fields. scaffold-dev **field-reads** `id` (exact match) and `sprint_id` from that JSON — it never greps a `#### VS-…:` heading and never string-splits the id to recover the sprint (the old approach mis-derived `sprint-1` from `VS-1.1.1`). The sprint segment of every path/branch (`sprint-<sprint_id>`) keys off the field-read `sprint_id`, not the id's first field.

### 4.5 Demoable definition

Every vertical slice demoable end-to-end. Demo criteria in slice README with concrete `auto:` / `user:` grammar (§14.1). Verified at slice close.

---

## 5. Vertical-slice lifecycle (orchestrator side)

### 5.1 Entry point

**Skill:** `planning-vertical-slice`. Triggers: "plan VS-N.M.K", "start vertical slice N.M.K", "orchestrate VS-N.M.K".
**Slash wrapper:** `/orchestrate VS-N.M.K`.

### 5.2 File/folder conventions

```
docs/specs/sprint-<sprint_id>/VS-<phase>.<sprint>.<slice>-<kebab-name>/   # e.g. sprint-1.1/VS-1.1.1-init-models/
├── README.md
├── work-<slice-index>.<nn>-<kebab>/
│   ├── spec.md
│   ├── handoff.md
│   └── report.md
└── retrospective.md
```

### 5.3 Decomposition (sketch-first then refine + grill-me offer)

Orchestrator proposes 4-5 work item draft; user iterates. After decomposition: **offers grill-me** (composition.json probe; user opt-in).

### 5.4 Round identification (DAG-default + user adjustment)

Topological sort proposes default rounds. User loosens (no dep violation) or tightens (always allowed as soft ordering).

### 5.5 Authoring lifecycle (specs upfront + handoffs/worktrees per round)

At slice-init: README + ALL specs + empty handoff.md + report.md placeholders.
**Offers grill-me on specs** (B4 Q4).
**Invokes architect-critic on specs** via in-conversation skill invocation (composition.json probe; per §16.3).
At each round start: create worktrees + author handoffs + **invoke implementer-agent subagent per work item** (§6) + process returns.

### 5.6 Slice close → §14

---

## 6. Implementer-agent subagent (REVISED from spec review)

### 6.1 Subagent type definition

scaffold-dev ships a custom subagent type registered as `scaffold-dev:implementer-agent`. Configuration:

- **System prompt:** scaffold-dev's `executing-work-item` skill body baked in
- **Tool access:**
  - Bash (with restrictions in skill body: no `git commit`, no `git push/pull/fetch`)
  - Read, Write, Edit
  - Glob, Grep
  - NO Task (prevents nesting)
- **Skill access:** can invoke `superpowers:test-driven-development` + `superpowers:verification-before-completion`
- **Model:** inherits or configurable (default: same as parent)

### 6.2 Invocation by orchestrator

Orchestrator (via `planning-vertical-slice` skill body) calls Task tool:

```
Task(
  subagent_type="scaffold-dev:implementer-agent",
  description="Execute work item N.NN",
  prompt="""
    Read handoff at <abs path to handoff.md> and execute the work item per its instructions.

    Your worktree: <abs path>
    Use this path for all git operations and file edits in canonical.

    First turn must be PRE-FLIGHT CHECK:
    - Read handoff + spec end-to-end
    - Verify worktree branch + clean state
    - Identify any ambiguity in the spec

    If pre-flight detects gaps/ambiguity that block execution:
      Return structured response:
        { "mode": "gaps-surfaced",
          "gaps": [
            { "section": "spec §<N>",
              "question": "<concrete question>",
              "severity": "blocking | nice-to-have" },
            ...
          ]
        }
      EXIT without doing work.

    If pre-flight passes:
      Execute work item per spec (TDD loop per AC).
      Author report.md per template in handoff.
      Stage changes (`git add .`) — DO NOT commit.
      Return structured response:
        { "mode": "complete",
          "report_path": "<abs path to report.md>",
          "summary": "<one-line summary>",
          "stage_status": "all_staged | partial | none" }
  """
)
```

### 6.3 Multi-call protocol

The subagent's response mode dictates orchestrator's next action:

- **`mode: gaps-surfaced`**: orchestrator surfaces gaps to user in conversation. User clarifies. Orchestrator amends `handoff.md` (appends `## Clarifications` section). Orchestrator re-invokes the subagent with same handoff path. Loop until pre-flight passes.

- **`mode: complete`**: orchestrator reads `report.md` from disk. Proceeds to verification (`implementation-checking` skill — §12) → commit (per `git_policy`) → merge → cleanup. Or if verification fails: invoke failure-response menu (§12.2).

### 6.4 Subagent-vs-manual fallback

**Default path:** subagent automation (above).

**Documented manual fallback:** orchestrator skill body documents that for cases where subagent isn't viable (e.g., user wants direct control, debugging implementer behavior, subagent timing out), user can spawn a fresh Claude session manually with the handoff doc as the prompt. The handoff doc's "How to use this handoff" section is written to work in both contexts — as a Task-tool prompt OR as a fresh-session starter.

### 6.5 Worktree access from subagent

Subagent's `cwd` is inherited from orchestrator (AI workspace). Subagent operates on canonical worktree via:
- Git ops: `git -C <abs worktree path> <subcommand>` (always `-C` flag)
- General commands (pytest, codegen): `cd <abs worktree path> && <command>` (cd in Bash invocation)
- File edits: Read/Write/Edit tools take absolute paths to worktree files directly

This is baked into the `executing-work-item` skill body and reinforced in handoff doc Header (`Worktree: <abs path>`) + the Task tool prompt.

**Do NOT use Task tool's `isolation: "worktree"` parameter** — that's for auto-creating a worktree of the CURRENT repo for the agent. Our pattern is different: orchestrator pre-creates worktree in canonical (a DIFFERENT repo from AI workspace where orchestrator runs); subagent uses absolute paths to reach it.

### 6.6 Failure modes

| Subagent failure | Orchestrator response |
|---|---|
| Subagent timeout | Halt; surface to user; offer: extend timeout / fall back to manual session / abandon work item |
| Subagent returns malformed response (not gaps-mode or complete-mode) | Halt; surface raw return to user; treat as gap-mode equivalent |
| Subagent crashes mid-execution (Task tool returns error) | Halt; check worktree state via `git -C status`; partial work may exist; invoke failure-response menu (§12.2) |
| Subagent exits with `stage_status: partial`/`none` | Surface to user; user decides whether to accept partial stage or re-invoke |
| Subagent loops in gaps-mode (3+ iterations) | Halt; surface to user; suggest replan or manual implementer session |

---

## 6b. Handoff escape valve (out-of-slice transitions)

Companion to §6's implementer-agent subagent. Where the subagent handles **planned work-item execution inside a slice**, the handoff escape valve handles **anything that takes you OUT of the planned slice work** — sprint boundary, slice boundary carry-forward, mid-slice context bloat, or mid-slice bug-fix/tech-debt detour. Settled 2026-05-25 via grill-me design pass.

### 6b.1 Skill + storage

- **Skill name:** `handing-off-session` (gerund convention per [[feedback_skill_naming_gerund_convention]])
- **Slash wrapper:** `/handoff [--scope sprint|slice|mid-slice|bugfix|techdebt] [--purpose "<short slug>"]`
- **Storage:** `<ai-workspace>/.workspace/handoffs/` — **gitignored** (durable per-machine; not synced; doesn't pollute repo). workspace-init owns the parent `.workspace/` namespace per its SPEC §4.3 and seeds the AI-workspace `.gitignore` with `.workspace/handoffs/` per its §8.3; scaffold-dev's `handing-off-session` skill lazily creates the `handoffs/` subdir on first invocation via `mkdir -p`.
- **Naming:** `<scope>-<purpose>-<short-id>.md` (no timestamp; short-id is 4-char hex for uniqueness). Examples:
  - `vs-1.1.1-bugfix-auth-a1b2.md` (mid-slice bug-fix detour from VS-1.1.1)
  - `sprint-3-context-bloat-c3d4.md` (sprint-3 mid-sprint context recovery)
  - `vs-1.1.1-techdebt-logging-e5f6.md` (mid-slice tech-debt detour)
  - `sprint-3-to-4-handoff-g7h8.md` (carry-forward sprint→sprint transition; see §6b.6)

### 6b.2 Use cases (4)

| Trigger | Why handoff (not subagent) | Carry-forward? |
|---|---|---|
| Sprint boundary (sprint N closed → N+1 starting) | Orchestrator carried sprint-N context for hours; useless ballast for N+1 | Yes — survives sprint-N cleanup |
| Slice boundary (within same sprint) | Optional breath between slices; lighter than full sprint reset | No — cleared at sprint-close |
| Mid-slice context bloat (orchestrator hitting the "dumb zone") | Subagent doesn't help — orchestrator itself is the bloated one | No |
| Mid-slice bug-fix / tech-debt detour | Subagent has tool/auth boundaries (no `git commit`, no full toolset); detour may need hours of context that would bloat orchestrator further; principle of separation of concerns | No (detour completes via return handoff per §6b.4) |

### 6b.3 Trigger discipline

**Judgment call primary.** User decides when to invoke based on session state, scope of pending work, or "context feels bloated."

**Optional 35%-context-threshold recommendation hook** (implementation-investigation needed — see §6b.8): if Claude Code exposes session-token-count to skill bodies, the skill MAY surface a passive hint when context usage crosses 35% (*"orchestrator context at 35%; consider `/handoff` if hitting the dumb zone"*). Hint never auto-invokes; user retains final call.

### 6b.4 Chain model (not rejoin)

When a source session writes a handoff, the source session **terminates** (or just stops being authoritative — user opens a new terminal/session). The new session reads the handoff and continues. **There is no literal "rejoin"** — what looks like rejoin is actually a third session consuming both the original forward handoff AND any return handoff produced by a fork session.

Example bug-fix detour:

```
Main session A (mid-slice VS-1.1.1)
  └── writes forward handoff:  vs-1.1.1-bugfix-auth-a1b2.md
      Main session A terminates (or pauses indefinitely)

Fork session B (bug-fix work)
  reads forward handoff
  fixes the bug
  └── writes return handoff:   vs-1.1.1-bugfix-auth-a1b2-return.md
      Fork session B terminates

New main session C
  reads BOTH handoffs (forward sets context; return delivers results)
  resumes VS-1.1.1 work
```

The "thread" is the sequence A → B → C, mediated by markdown files. Not a parent-child tree.

### 6b.5 Doc structure (12 standardized sections + focus field)

Every handoff doc — forward or return — uses these sections (parser-friendly + predictable lookup). A plain-language **`Next-session focus:`** lead field (#38 leg 4) sits above section 1. (Sections 8 References and 10 Suggested-skills were added by #38; the original design had 10 sections.)

1. **Header** — type (forward / return), scope, source session metadata
2. **Purpose** — why handing off; one paragraph
3. **State pointers** — workspace paths, active sprint/slice IDs, worktree paths, branch names
4. **What's NOT in memory bank yet** ← *key value-add; the ephemeral pre-codification content*
5. **Workflow deviations** — any deviations from standard scaffold-dev workflow active in this session
6. **In-flight state** — open work items, partial commits, branches needing merge, subagents dispatched but not returned
7. **Must read before doing anything** — specific files beyond Tier 0 auto-load
8. **References** (#38 leg 2) — dispatchable artifact index: specs/ADRs/commits/issues/diffs by path·URL·SHA, not pasted (may be empty)
9. **Next intended action(s)** — single specific action OR ranked list of options
10. **Suggested skills / plugins** (#38 leg 1) — advisory `plugin:skill` capabilities the next session likely needs (may be empty)
11. **Anti-actions** — explicit "do NOT do X" warnings
12. **Return-handoff template stub** — only for forward handoffs expecting a return

**Section 4 is the value-add over memory bank.** Memory bank captures *codified* state. Handoff captures slice-specific decisions, conversation deltas, negative-space ("we tried Y and rejected it"), time-sensitive constraints, and tool-call insights that didn't make it to artifacts. Once items in section 4 get promoted (via slice-close harvest per §15.2), they leave the handoff and become memory-bank entries.

**#38 additions (v0.17.0).** Beyond the two new sections + focus field: a **redaction pass** (leg 3) runs before every write/print — a hybrid mechanical candidate-surfacer (`lib/redact.sh`) + agent warn-and-confirm judgment; and an opt-in **`--ephemeral`** mode (leg 5) renders the full doc to stdout (no manifest, no durable file, no gitignore check) for non-dual-repo projects and ad-hoc compaction.

### 6b.6 Lifecycle + cleanup

- **Handoffs accumulate per sprint.** Mid-sprint a user may have multiple bug-fix, tech-debt, and context-bloat handoffs in `.workspace/handoffs/`.
- **Sprint-close cleanup wipes all sprint-scope handoffs** EXCEPT the carry-forward sprint→sprint(N+1) handoff (named `sprint-N-to-N+1-handoff-XXXX.md`). The carry-forward survives so sprint(N+1) can bootstrap from it.
- **Cleanup ownership:** resolve during PLAN authoring — either extend `closing-vertical-slice` at the final slice of the sprint, OR introduce a separate `closing-sprint` skill.
- **Once consumed, the carry-forward handoff becomes a sprint(N+1) artifact** and is eligible for cleanup at sprint(N+1) close.

### 6b.7 Composition with peer skills

- **§7.1 catalog:** `handing-off-session` is the 8th orchestrator-facing skill.
- **§15.2 harvest:** `closing-vertical-slice` sweeps the slice's handoffs (`vs-N.M.K-*.md`) alongside work-item reports during memory-bank harvest; promote-worthy items in handoff section 4 surface for user accept/edit/reject (source-tagged so user can distinguish report-origin from handoff-origin).
- **Subagent boundary rule (binding):** subagent = planned work-item *inside* slice; handoff = anything taking you *out* of planned slice work. The implementer-agent subagent must never invoke `handing-off-session`. The orchestrator may invoke either, per use case in §6b.2.

### 6b.8 Known limitations (deferred to v0.2+)

- **In-flight subagent quiesce.** If the orchestrator invokes `handing-off-session` while an implementer-agent subagent is mid-execution, the subagent return is orphaned (no orchestrator to receive it). Documented as user discipline: wait for subagent return before handing off. Detection/enforcement deferred.
- **Multiple parallel detours from same source.** Naming with short-id keeps file paths unique; concurrency semantics (e.g., two bug-fix detours from VS-1.1.1 running in parallel) are not designed. Each fork session works independently; new main session at integration time reads all return handoffs.
- **35%-context-threshold detection mechanism.** Whether Claude Code exposes session token count to a skill body needs investigation. May degrade to "user-side hint only" if not exposed; user invokes manually based on subjective sense of orchestrator slowdown.
- **Carry-forward handoff naming convention.** Pattern `sprint-N-to-N+1-handoff-XXXX.md` is provisional; pin during PLAN.

---

## 7. Skills & commands

### 7.1 Orchestrator-facing skills (8 skills)

| Skill | Trigger | Body responsibility |
|---|---|---|
| `planning-vertical-slice` | "plan VS-N.M.K", "orchestrate VS-N.M.K" | Full VS lifecycle (decomposition → rounds → spec authoring → grill-me offer → critic invocation → per-round subagent invocation + return handling → round-close → slice-close) |
| `implementation-checking` | "verify work item", "check round K" | Per-work-item gate: AC verification + report cross-check + project rule checks (§12) |
| `closing-vertical-slice` | "close VS-N.M.K", "slice close" | 3-layer slice-close ceremony (§14); memory bank harvest (§15.2) including handoff sweep per §6b.7 |
| `recording-architecture-decision` | "ADR for X" | Manifest-routed: product ADR → canonical; process ADR → AI workspace |
| `appending-changelog-entry` | "log changelog" | Keep-a-Changelog 1.1.0 |
| `authoring-runbook` | "write runbook" | SRE-style runbook template |
| `writing-sprint-retrospective` | "close sprint N" | Aggregate VS retrospectives; harvest cross-slice patterns |
| `handing-off-session` | "hand this off", "handoff to next session", "fresh session for X", "context bloated", "/handoff", "/handoff --ephemeral" | Compose a handoff doc per §6b at `<ai-workspace>/.workspace/handoffs/<scope>-<purpose>-<short-id>.md`. Captures ephemeral pre-codification state for out-of-slice transitions. 12 standardized sections + focus field per §6b.5; redaction pass before write; opt-in `--ephemeral` stdout mode. |

### 7.2 Implementer-agent (subagent type, not a skill)

`scaffold-dev:implementer-agent` — registered as a custom subagent_type in `scaffold-dev/.claude-plugin/agents.json` (or wherever Claude Code expects subagent_type definitions). System prompt is the body of `executing-work-item` skill (which also exists as a regular skill for fallback manual-session use).

### 7.3 Skill: `executing-work-item`

| Skill | Trigger | Body responsibility |
|---|---|---|
| `executing-work-item` | "execute work item", "handoff at <path>" (also used as system prompt for implementer-agent subagent) | Drive 9-step main loop (§6.2 of prior SPEC — pre-flight → TDD → verify → report → stage → exit-or-return). Composes with TDD + verification-before-completion. |

### 7.4 Slash command wrappers (3)

- `/orchestrate VS-N.M.K` — wraps `planning-vertical-slice`
- `/work-item <handoff-path>` — wraps `executing-work-item` (for manual-session fallback per §6.4)
- `/impl-check <work-item-id-or-round>` — wraps `implementation-checking`

---

## 8. Pairing manifest consumption

§4.2 covers shape. Field-by-field: scaffold-dev reads `ai_workspace.root`, `canonical.root`, `during_dev.*` (worktrees_dir, branch_naming, sprint_dir_template, slice_spec_format), `well_known_paths.*`, `git_policy.*`. Uses workspace-init's `mi_manifest_resolve` helper (handles `${var}` and `${PLUGIN_DATA:<plugin-name>}`). Never writes.

---

## 9. Work-item spec format (adapted Wabash Format B, 8 sections)

Header (with Vertical Slice, Round, Worktree absolute path, Branch) + Context + Decisions baked in + Files to modify + ACs with verification + Verification (executable) + Demo contribution + Not in this work item + Reference index.

---

## 9b. Vertical-slice README format

Description · Demo criteria (`auto:` / `user:` prefixed steps per §14.1 grammar) · Work items table · Round plan · Sprint context · Demo verification · pointer to retrospective.

---

## 10. Implementation handoff format

Heavy self-contained session-starter (~200-400 lines). Works as BOTH:
- A Task tool prompt argument (subagent reads it)
- A manual fresh-session starter (per §6.4 fallback)

Sections: How-to-use (mentions both subagent + manual use cases) → Vertical slice context → Work item identifiers (worktree absolute path emphasized) → Pre-flight calibration → What's already merged → Memory bank pointers → ACs embedded → Verification commands embedded → Constraints (git_policy + STAGE-not-commit + subagent return format) → When done → Report template → Notes for orchestrator footer.

Fix-up iterations APPEND `## Fix-up iteration N` to existing handoff.

---

## 10b. Templating (NEW from spec review)

To address H6 (authoring burden), scaffold-dev ships templates that orchestrator fills in rather than authoring from scratch:

- `scaffold-dev/templates/work-item-spec.md.tmpl` — Wabash Format B with placeholders
- `scaffold-dev/templates/vertical-slice-readme.md.tmpl`
- `scaffold-dev/templates/implementation-handoff.md.tmpl` — heavy self-contained shape
- `scaffold-dev/templates/implementation-report.md.tmpl` — 9-section format
- `scaffold-dev/templates/slice-retrospective.md.tmpl`
- `scaffold-dev/templates/sprint-retrospective.md.tmpl`

Placeholders use Wabash-style `{{var}}` substitution (per scaffold-onboard's render.sh pattern). Orchestrator's `lib/render.sh` (ported from scaffold-onboard) fills templates with values gathered from manifest + user input + analysis.

**Estimated effect:** ~50% reduction in orchestrator-session token cost per VS for artifact authoring (templates carry boilerplate; orchestrator fills content). Validated during Phase 6 testing.

---

## 11. Worktree mechanics

- **Path:** `${canonical.root}/.worktrees/sprint-<sprint_id>/work-N.NN-<kebab>` (manifest)
- **Branch:** per `during_dev.branch_naming`
- **Base:** canonical main HEAD at creation
- **Creation timing:** per-round (per B2 Q8)
- **Removal timing:** **at SLICE close** (CHANGED from round close per M2) — keeps worktrees + branches available for slice-close demo verification and retrospective harvest inspection
- **Conflict at merge:** halt + surface; manual `git merge --continue` resumes
- **Subagent access:** absolute paths per §6.5

---

## 12. Implementation-checking (per-work-item verification gate)

### 12.1 Verification gate

Per Q2 settlement: AC verification + report cross-check + project rule checks (R2 memory-bank machine-checkable rules; v0.1 falls back to AC-only if rules absent).

### 12.2 Failure response menu (table)

| Failure type | Menu options |
|---|---|
| **AC verification fail** | (1) **Re-spawn implementer subagent** with fix-up handoff (append `## Fix-up iteration N` to existing handoff.md; re-invoke Task tool) · (2) **Accept partial-with-deferred** (mark failing AC as deferred-to-follow-up; backlog gets work item) · (3) **Replan work item** (return to spec authoring; reset handoff) |
| **Report cross-check mismatch** | (1) **Re-spawn** (report likely inaccurate) · (2) **Interrogate via subagent** (re-invoke subagent with prompt: "re-verify AC-N and re-author report.md") · (3) **Override** (treat as AC fail; apply that menu) |
| **Project rule check fail** | (1) **Re-spawn with rule context** in fix-up handoff · (2) **Accept-with-deferred TODO** · (3) **Replan if rule is fundamental** |
| **Merge conflict** | (1) **User resolves manually** (`git merge --continue` resumes orchestrator) · (2) **Abort merge** (`git merge --abort`; replan integration) |
| **Subagent crash / timeout / malformed return** | (1) **Re-invoke** (transient failure) · (2) **Extend timeout + re-invoke** · (3) **Fall back to manual implementer session** per §6.4 · (4) **Abandon work item** (mark cancelled) |

---

## 13. Round-close orchestrator flow (strict sequential processing)

Per B3 Q3 settlement, processing is **strictly sequential in decomposition order**. Work item N+1 is NOT verified until N is fully committed + merged. The adversarial review's H3 scenario ("1.03 verified while 1.02 failed") CANNOT happen in this flow — orchestrator processes in declared order regardless of subagent return order.

```
At round close (subagent returns processed in decomposition order):

for each work item in round (decomposition order):
    1. Wait for subagent return for this work item (if not already in)
    2. Process return:
       - mode=gaps-surfaced → multi-call clarification loop (§6.3); blocks
         processing until subagent eventually returns mode=complete
       - mode=complete → proceed
       - error → failure-response menu (§12.2 "Subagent crash" row)
    3. Run implementation-checking skill (§12.1) — HALT on fail
    4. Commit in worktree per git_policy
    5. Merge work-item branch into canonical main; HALT on conflict
    6. Update VS README: work-item status → complete
    # Worktree NOT removed yet; defer to slice close per §11

After all items processed:
    7. Update VS README: round status → complete
    8. Tell user: "Round K complete. Ready for K+1 (or close slice)."
```

State at any halt point is deterministic: items 1..N merged, item N+1 halted with menu surfaced, items N+2.. not started. Worktrees + branches preserved for inspection.

---

## 14. Slice-close ceremony (three layers)

### 14.1 Automated demo criteria (`auto:` prefixed steps)

**Grammar:**
```
- [ ] auto: <bash command> → expected: <exit code 0 | pattern in output>
```

Examples:
```
- [ ] auto: `pytest tests/integration/test_insight_pipeline.py` → expected: exit 0
- [ ] auto: `curl -s localhost:8000/api/insights | jq '.[]'` → expected: output contains "action_needed"
- [ ] auto: `psql -d foo -c "SELECT count(*) FROM action_needed"` → expected: count > 0
```

Orchestrator's `closing-vertical-slice` skill body parses each `auto:` step, runs the command in canonical (now contains all rounds' merges), checks exit code (default success criterion) OR matches output pattern (when `expected:` specifies a pattern). Records pass/fail in VS README "Demo verification".

### 14.2 Manual demo (`user:` prefixed steps)

**Grammar:**
```
- [ ] user: <action description> → expected: <observable outcome>
```

Examples:
```
- [ ] user: Navigate to localhost:3000/insights → expected: action-needed card visible with real data
- [ ] user: Click chatbot icon → expected: chat panel opens; type "what's overdue?" → expected: response within 5s
```

Orchestrator presents each step + expected outcome to user. User executes manually. User reports back: passed / failed / partial. Orchestrator records result + user's note.

### 14.3 Architect-critic adversarial review (in-conversation skill invocation)

Orchestrator probes for architect-critic via composition.json cache. If installed:
- Invoke architect-critic's `critiquing-spec` skill (or equivalent v0.2 entry) **in-conversation** — Claude triggers the skill the same way it triggers grill-me. NOT via inbox/outbox file IPC.
- Provide as context: the slice's combined diff (from VS-start commit to current canonical HEAD) + VS README + all work-item specs.
- architect-critic's skill body runs in conversation: does claude-self-audit; if depth=close + Codex installed, invokes Codex via Bash subprocess; consolidates challenges; presents with T=4 concession-scoring rubric; user does rebuttal cycle in conversation.
- After challenges resolved, control returns to orchestrator.

If architect-critic NOT installed: warn user ("adversarial review skipped — architect-critic not detected"); continue with auto + manual demo only.

### 14.4 Slice-close decision + retrospective + memory bank harvest

All pass + challenges resolved → VS closes → orchestrator authors `retrospective.md` (format §16b) → memory bank harvest (§15.2) → **NOW removes worktrees + deletes branches** (deferred from round close per §11) → surfaces "VS-N.M.K closed".

Any failure → menu: re-open VS with fix-up round / close-with-deferred (must be demoable despite caveats) / abandon VS.

---

## 15. Memory bank

### 15.1 Retrieval (tiered, no MCP)

Reuses scaffold-onboard's tiered pattern. Tier 0 always preloaded by SessionStart hook (~200-300 tokens) + Tier 1 branch-loaded by query type.

**Coordination with scaffold-onboard's hook:** both plugins' SessionStart hooks emit Tier 0. To avoid duplication (~600 tokens of redundant emission per session), scaffold-dev's hook **conditionally skips Tier 0 emission** if it detects scaffold-onboard's hook has already emitted (checked via a session-state marker file `${CLAUDE_PLUGIN_DATA}/scaffold-dev/tier0-emitted-<session-id>`). Falls back to emitting if marker absent. Net effect: ~200-300 tokens of Tier 0 emitted once per session regardless of hook order.

**Graphify + Karpathy CLAUDE.md skill:** deferred to post-spec exploration ([project_post_spec_exploration_queue memory](#)). Not v0.1 deps.

### 15.2 Harvest (per-slice during retrospective)

`closing-vertical-slice` skill at slice close (§14.4):
1. Reads all work-item `report.md` files for the VS
2. Reads all slice handoffs at `<ai-workspace>/.workspace/handoffs/vs-N.M.K-*.md` (per §6b)
3. Extracts: (a) "Suggestions for memory bank" sections from reports, and (b) section 4 ("What's NOT in memory bank yet") promote-worthy items from handoffs
4. Categorizes by target memory-bank file
5. Surfaces to user with proposed target + edit per suggestion (source-tagged: `[report]` or `[handoff]` so user can distinguish origin)
6. User approves/edits/rejects per item
7. Applies with provenance trailer: `<!-- Added from VS-N.M.K retrospective, YYYY-MM-DD; source: report | handoff -->`
8. Records harvest outcomes in retrospective.md (including which handoff items were promoted vs left in handoff)

### 15.3 File structure additions

None. No new memory-bank files beyond scaffold-onboard's 11.

---

## 16. Composition with peer plugins

### 16.1 workspace-init (tight upstream)

Manifest contract per §4.2. Refuses to start without manifest.

### 16.2 scaffold-onboard v0.2 (tight upstream)

Input contract per [project_scaffold_onboard_v02_contract_from_dev memory](#):
- R1 — Phase/Sprint/VS hierarchy in `ROADMAP.md` (renamed from PROJECT_PLAN.md per scaffold-onboard v0.2 §13.5 to avoid collision with v0.1.0's existing PROJECT_PLAN.md output)
- R2 — Machine-checkable rules in memory bank
- R3 — Demo criteria with `auto:`/`user:` grammar per §14.1

**scaffold-dev v0.1 build is GATED on scaffold-onboard v0.2 ship.** No degraded mode in v0.1 (the prior SPEC's "two operating modes" handwave is removed per spec-review C2).

### 16.3 architect-critic v0.2 (lazy via filesystem probe — skill-based invocation)

**Detection:** filesystem probe (lazy; per-skill-call). scaffold-dev does NOT maintain a composition.json cache (scaffold-onboard v0.2 does, but scaffold-dev builds without that infrastructure). Probe walks `~/.claude/plugins/cache/*/architect-critic/*/skills/critiquing-spec/SKILL.md` per ac v0.2 settlement #1; ~5ms typical. Match scaffold-onboard's `sf_compose_detect_architect_critic` pattern (§12.2 of scaffold-onboard v0.2 SPEC).

**Invocation mechanism:** **in-conversation skill invocation**. When orchestrator reaches an architect-critic moment (spec-author audit or slice-close adversarial), Claude triggers architect-critic's `critiquing-spec` skill (or equivalent v0.2 entry skill) the same way Claude triggers any other skill — description matching, or by Claude explicitly invoking the skill name. NOT via inbox/outbox file IPC (the inbox/outbox protocol from architect-critic v0.1.3 was the wrong architecture; v0.2 redesigns to skill-first per Pass D).

**Two invocation moments:**
- **Moment 1 — Slice-spec-authoring audit** (BEFORE round 1)
- **Moment 2 — Slice-close adversarial review** (§14.3)

Critic's skill runs in conversation, produces challenges, user resolves, orchestrator picks up after.

Cost: ~$0.10-0.40 per VS (2 invocations × Codex band when applicable). Graceful degradation if architect-critic not installed.

### 16.4 ai-mentor v2.0 (lazy via filesystem probe — orchestrator OFFERS grill-me at 3 gates)

**Detection:** filesystem probe (lazy; per-call). Probe walks `~/.claude/plugins/cache/*/ai-mentor/*/skills/grill-me/SKILL.md`; ~5ms typical. scaffold-dev uses filesystem probe uniformly for ALL composition detection — no composition.json cache (that's scaffold-onboard's hub-plugin pattern; scaffold-dev is a consumer-side plugin and doesn't need the cache layer).

Shipped v2.0 as scope-cut release 2026-05-24 (per `project_ai_mentor_v2_grill_settlements` memory): 4 skills survived (grill-me, eli10, fool, council); cognitive-discipline content from transcripts folded into grill-me as escape valves; the originally-planned v1.4 expanded retrofit (new skills like minimizing-loss-function, separating-concerns, etc.) was descoped. scaffold-dev composes with v2.0's grill-me skill only.

- Offer 1 — After decomposition settles
- Offer 2 — After spec authoring (BEFORE architect-critic audit — grill-me first surfaces undecided items)
- Offer 3 — After fix-up replan

Never auto-invoked.

### 16.5 superpowers (cross-references)

`superpowers:test-driven-development` (per-AC TDD) + `superpowers:verification-before-completion` (don't-claim-done) — invoked by name from `executing-work-item` body (skill body for manual fallback AND as system prompt for implementer-agent subagent).

---

## 16b. Retrospective formats

### Slice retrospective (`VS-N.M.K-<kebab>/retrospective.md`, 7 sections)

Slice metadata · Demo verification results · Architect-critic findings (both moments with resolutions) · Memory bank harvest · Deviations + deferrals · Lessons learned · Reference index.

### Sprint retrospective (`sprint-N/sprint-retrospective.md`, 6 sections)

Sprint metadata · Sprint goal vs delivered · Per-slice rollup · Cross-slice patterns · Memory bank impact totals · Lessons for next sprint · Reference index.

---

## 17. State management

State IS the AI workspace artifacts. No separate state file. Current-cursor in `<ai-workspace>/.claude/memory-bank/05-active-context.md`.

**Write-conflict separation:** orchestrator-only writes to AI workspace files; implementer-agent subagent only writes to canonical worktree + its own `report.md` (file path passed in handoff). No concurrent writes to same file from different actors. (Adversarial review H5 mitigation.)

---

## 18. Hooks strategy

**SessionStart only.** Walk up for `.workspace/pairing.json`; if not in AI workspace, **emit one-line stderr warning** ("scaffold-dev: not in an AI workspace; manifest discovery skipped") so user sees the silent-mode signal; otherwise emit Tier 0 + scaffold-dev cursor; coordinate with scaffold-onboard's hook (§15.1 marker file). Fail-open on any error.

---

## 19. Build sequence (Pass D 8-phase pattern + Phase 3.5)

```
PHASE 0 — Evals first (RED). ~15-18 baseline scenarios (more than prior estimate to cover subagent + return-mode + worktree-via-abs-path scenarios).
PHASE 1 — Author SKILL.md bodies (8 skills; each ≤500 lines).
PHASE 2 — Reference sub-docs.
PHASE 3 — Utility scripts (bookkeeping):
  · state.sh · worktree.sh · merge.sh · manifest.sh (uses workspace-init's mi_manifest_resolve)
  · harvest.sh · verify.sh · rules.sh · render.sh (template filler) · _helpers.sh
PHASE 3.5 — Subagent definition (NEW from spec review):
  · scaffold-dev/.claude-plugin/agents.json (or equivalent Claude Code subagent registration)
  · Subagent system prompt = executing-work-item SKILL.md body (shared)
  · Subagent tool access configuration
  · Tests: subagent invocation, return-mode parsing, gaps-mode multi-call loop, complete-mode report read
PHASE 4 — Hooks (hooks.json + session-start.sh with coordination marker).
PHASE 5 — Slash command wrappers (3).
PHASE 6 — Subagent pressure tests (re-run Phase 0 scenarios with skills + subagent).
PHASE 7 — Integration tests (fixture project end-to-end with subagent-driven implementer).
PHASE 8 — Publish.
```

**Test count target:** ~140-160 tests (more than prior estimate to cover subagent return modes + templating + write-conflict separation).

**Estimated effort:** 8-12 implementer-session days (1-2 days more than prior estimate due to subagent definition + multi-call protocol tests).

---

## 20. Testing strategy

Eval-driven. Test scenarios per skill + integration. Specific scenarios beyond prior list:

- Subagent return modes: gaps-surfaced (single iteration); gaps-surfaced (multi-iteration loop); complete; malformed return
- Subagent worktree access via absolute paths (no cwd assumption)
- Subagent failure modes (timeout, crash, partial stage)
- Manual fallback path: user spawns fresh session with handoff as prompt; works equivalently
- Template rendering: each template fills correctly with sample data
- `auto:` step grammar parsing (exit code vs pattern match)
- `user:` step presentation + result capture
- Strict sequential processing: work item N+1 not verified until N merged
- Worktree cleanup at slice-close (not round-close); inspectable post-merge
- Write-conflict separation (orchestrator + subagent never race on same file)

---

## 21. Deferred to v0.2+

- Single-repo support
- Pipelined round execution
- Auto-decomposition
- Project-class-aware spec templates
- Sprint-overview.md rollup
- Per-slice opt-out flags
- Abandoned-state recovery
- Re-decomposing-slice skill
- Concurrent implementer detection
- Graphify + Karpathy CLAUDE.md skill integration
- ~~ai-mentor v1.4 retrofit~~ — shipped 2026-05-24 as v2.0 scope-cut release instead (per `project_ai_mentor_v2_grill_settlements` memory); composition with v2.0's grill-me documented in §16.4

---

## 22. Open questions

None blocking. Implementation-level questions resolve during PLAN authoring.

---

## 23. Risks

| # | Risk | Mitigation |
|---|---|---|
| R1 | architect-critic v0.2 not built | Build gate — scaffold-dev v0.1 build blocked until critic v0.2 ships. Composition.json probe for graceful degradation when used post-ship. |
| R2 | scaffold-onboard v0.2 not built | Build gate — same as R1. No degraded mode in v0.1. Build order: workspace-init + onboard v0.2 + critic v0.2 FIRST, then scaffold-dev. |
| R3 | Memory bank scaling | Tier-loading + hook coordination; Graphify is post-spec exploration item if needed |
| R4 | Subagent return mode parsing fragility | Strict JSON schema for return modes; orchestrator validates; malformed return → failure-response menu |
| R5 | Round-close conflict cascade | Halt-and-surface per item; sequential processing prevents intermediate states |
| R6 | Compaction mid-orchestrator session | State IS artifacts; subagent runs in isolated context (compaction in orchestrator doesn't affect in-flight subagent) |
| R7 | Architect-critic cost runaway | Monitor via `/critique-list`; per-slice opt-out flag v0.2 |
| R8 | Worktree pollution from abandoned slices | Manual workaround v0.1; recovery skill v0.2 |
| R9 (NEW) | Subagent automation fails in practice (timeout, malformed returns common) | Manual fallback documented (§6.4); orchestrator skill body includes fallback prompt; user retains control |

---

## 24. Edge case handling

(Per prior SPEC §24 table; E1-E4 covered; E5-E8 deferred; E9-E12 documented.)

---

## 25. Definition of done (v0.1.0)

- All 8 build phases + Phase 3.5 complete
- ~140-160 tests passing
- `scaffold-dev-v0.1.0` tag pushed
- Marketplace entry (between scaffold-onboard and architect-critic)
- Root README updated (6 active plugins + scaffold v1.0.0 deprecated)
- workspace-init's manifest contract honored
- scaffold-onboard v0.2 R1/R2/R3 contract honored
- architect-critic v0.2 skill-based invocation working
- Subagent pressure tests confirm subagent return modes parse correctly
- Manual fallback path tested

---

## 25b. Future workflow tool consideration (v0.2 candidate)

Anthropic released a `.claude/workflows/*.js` deterministic-orchestration feature 2026-05-24 (off by default; pre-announcement at time of this SPEC revision). Workflows let sub-agents stream stage-to-stage with results bypassing the orchestrator's context entirely — eliminating the token tax of Task tool subagent returns. Pause/resume, automatic retry, parallel + pipeline composition, budget enforcement, and a `/workflows` UI ship out-of-box.

### 25b.1 Where workflows would fit scaffold-dev

| scaffold-dev concept | Why workflows fit |
|---|---|
| Round execution (§13: sequential work-item processing) | Pure pipeline: per-work-item → pre-flight → execute → verify → commit → merge. For-each fan-out + conditional fix-up retry |
| Slice-close ceremony (§14: auto-demo → manual demo → architect-critic → retrospective) | 4 phases in chain with conditionals (skip critic if absent) |
| Sprint roll-up (per-VS retrospective harvest → sprint retrospective) | Linear pipeline |

### 25b.2 Where workflows do NOT fit

- Spec authoring — requires user dialogue at every step
- VS decomposition — user proposes/iterates with orchestrator
- Brainstorming — conversational steering
- Architect-critic rebuttal cycle — user concession scoring per challenge
- Handoff escape valve (§6b) — user-invoked transitions, not a deterministic pipeline

### 25b.3 Why v0.1 stays on Task tool

1. **Pre-announcement feature.** Surface may change; building against unstable APIs = wasted work.
2. **Off by default.** Every user must opt in via env var. Cannot be a hard dependency in v0.1.
3. **JS language barrier.** scaffold-dev is markdown + bash. Adding JS adds a runtime + new debugging surface.
4. **§6 is locked around Task tool.** Refactoring to workflows = restart spec section.
5. **Risk parity with [[feedback_subagent_vs_inline_threshold]].** Workflows are MORE infrastructure than Task tool — same risk pattern, amplified.

### 25b.4 v0.2 adoption path (if/when workflows stabilize)

- Adopt workflows for round execution + slice-close ceremony (deterministic pipelines)
- Keep Task tool subagent for adaptive implementer-agent work (returns need orchestrator-side decisions)
- Keep handoff escape valve (§6b) for user-invoked out-of-slice transitions
- **Hybrid model:** workflows for pipelines; Task tool for adaptive work; handoff for transitions

Track Anthropic's official announcement + stability signal before committing to v0.2 adoption.

---

## 26. Iteration log

- **2026-05-20** — Stub created.
- **2026-05-21** — B1-B5 settled (single-day brainstorm marathon).
- **2026-05-22** — **Spec review pass.** Adversarial review via fresh-frame subagents + grill-me Socratic pass. Major revisions:
  - §6 fully rewritten: implementer-agent subagent (custom subagent_type via Task tool) replaces fresh-user-spawned implementer session; multi-call protocol with gaps-mode + complete-mode returns
  - §10b NEW: templating to address authoring burden (H6)
  - §14.1, §14.2 NEW: `auto:` / `user:` demo step grammar defined
  - §16.3 rewritten: architect-critic invocation is skill-based in-conversation, NOT inbox/outbox
  - §16.4: ai-mentor version corrected to v1.3.0
  - §15.1: hook coordination with scaffold-onboard's Tier 0 emission
  - §17: write-conflict separation (orchestrator vs subagent file ownership)
  - §11: worktree cleanup deferred to slice-close (not round-close)
  - §19: Phase 3.5 added (subagent definition)
  - §13: strict sequential processing clarified (H3 non-issue)
  - §6.4: manual fallback documented
  - §23 R9 added: subagent fragility risk
  - C2 fix: removed "two operating modes" handwave; v0.1 build gated on dependencies (no degraded mode)
- **2026-05-24 — Phase 3 drift-resolution pass** (post architect-critic v0.2 + ai-mentor v2.0 ship):
  - §4.1: ai-mentor version reference updated from v1.3.0 to v2.0 (shipped as scope-cut release)
  - §16.2: R1 hierarchy doc renamed `PROJECT_PLAN.md` → `ROADMAP.md` (per scaffold-onboard v0.2 §13.5 settlement; avoids v0.1.0 PROJECT_PLAN.md collision)
  - §16.3: architect-critic detection mechanism — composition.json probe → filesystem probe (matches scaffold-onboard §12.2 + ac v0.2 settlement #1)
  - §16.4: ai-mentor v1.3.0 → v2.0; documented scope-cut (4 surviving skills: grill-me, eli10, fool, council); v1.4 expanded retrofit descoped; detection mechanism unified to filesystem probe (scaffold-dev doesn't maintain composition.json — that's scaffold-onboard's hub-plugin pattern)
  - §21 deferred-list: removed stale "ai-mentor v1.4 retrofit" entry; replaced with note pointing to v2.0 ship
- **2026-05-25 — Handoff escape valve design pass + workflow tool consideration** (post claude-security-audit v0.1.1 ship; scaffold-onboard v0.2.0 SHIPPED; architect-critic v0.2.0 issue #3 closed as resolved):
  - §6b NEW: handoff escape valve (out-of-slice transitions) — companion to implementer-agent subagent; complete 8-subsection design (skill, storage, naming, use cases, trigger discipline, chain model, doc structure, lifecycle, composition, known limitations). Settled via grill-me design pass.
  - §7.1 catalog: added 8th orchestrator-facing skill `handing-off-session`; closing-vertical-slice row updated to reference §6b.7 handoff sweep
  - §15.2: harvest extended to sweep slice handoffs alongside work-item reports; source-tagged surface ([report] vs [handoff]); 7-step flow expanded to 8
  - §25b NEW: future workflow tool consideration; v0.2 candidate; identified fit boundaries (round execution, slice-close ceremony, sprint roll-up) + non-fit areas (interactive flows); v0.1 stays on Task tool for 5 stated reasons; hybrid v0.2 adoption path
- **2026-05-25 — Phase 3 cross-check pass** (verify SPEC clean against all 4 shipped deps):
  - §6b.1: clarified storage path ownership — workspace-init owns parent `.workspace/` namespace + seeds `.gitignore`; scaffold-dev's `handing-off-session` lazily creates `handoffs/` subdir on first invocation
  - Verified clean across §4.1 / §16.3 / §16.4 / §16 / §17 / §6b–§25b internal consistency; no further drift found
  - Workspace-init companion edits: §11.4 ai-mentor version bump; §4.3 topology diagram + `.workspace/handoffs/`; §8.3 gitignore template content (handoff dir explicit)
- **Status:** scaffold-onboard v0.2.0 SHIPPED 2026-05-24; architect-critic v0.2.0 + ai-mentor v2.0.0 shipped; claude-security-audit v0.1.1 shipped; workspace-init `routing.roadmap` baked into v0.1 schema; Phase 3 cross-check pass clean. Ready for **Phase 4** (workspace-init + scaffold-dev v0.1 builds).
