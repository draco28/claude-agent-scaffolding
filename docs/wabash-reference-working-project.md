# Wabash — reference working project

> A reference description of how the wabash project (`/home/pras/Documents/wabash/` AI workspace + `/home/pras/wabash-poc/ai-insights/` canonical codebase) is structured. Read this when designing scaffold v1.x to understand which patterns to port wholesale, which to port partially, and which are wabash-bespoke.

This document does not endorse the wabash format as the "right" target for scaffold. It describes what wabash actually does, with notes on which conventions generalize.

---

## 1. Repo topology

Wabash uses a **dual-repo split**:

| Repo | Path | What lives here | Git? |
|---|---|---|---|
| AI workspace | `/home/pras/Documents/wabash` | `.claude/` (memory bank, discussion logs), `CLAUDE.md`, `AGENTS.md`, `docs/specs/`, `docs/superpowers/`, `README.md`, `.archive/` | Not git-tracked |
| Canonical codebase | `/home/pras/wabash-poc/ai-insights` | All code, production docs, project config | Git-tracked on Azure DevOps |

The split exists because the AI workspace evolves at conversation pace (specs/plans/memory-bank get edited dozens of times per session) and forcing it through a commit-driven workflow would create thousands of trivial commits. The canonical codebase keeps a clean Azure DevOps history.

**Generalization note:** dual-repo is wabash-specific. Most projects use a single repo. Scaffold should *not* assume this topology, but a v1.x "scratchpad" workspace (untracked) for spec/memory-bank churn could be a useful opt-in.

The agent never runs `git commit` / `git push` / `git pull` / `git fetch` / `git merge` / `git rebase` / `git reset --hard` / `git stash` in either repo. User owns all git workflow manually. Agent stages (`git add`, `git mv`, `git rm`) and provides commit-message handoffs.

---

## 2. Memory bank — `.claude/memory-bank/`

Wabash has 9 markdown files plus an `index.md` and `WORKFLOW.md`. The shape is lifted from the "Cline memory bank" pattern.

| # | File | Purpose | Status |
|---|---|---|---|
| 00 | `00-dual-repo-topology.md` | Repo split rules | wabash-specific |
| 00 | `00-project-brief.md` | Vision, problem, users, MVP, project class | generic-friendly |
| 01 | `01-product-context.md` | Domain entities, user flows / DX, ubiquitous language | generic-friendly |
| 02 | `02-system-patterns.md` | Architecture invariants, security posture, async/sync rules, ADR index | generic-friendly |
| 03 | `03-code-patterns.md` | Code style invariants — typed/dynamic, function/class rules, comment policy, banned patterns | generic-friendly (content varies) |
| 04 | `04-tech-context.md` | Languages, frameworks, data stores, external services, hosting, tooling | generic-friendly |
| 05 | `05-active-context.md` | What's happening *right now* — active sprint, active slice, recent decisions, blockers | LIVE — appended by per-sprint commands |
| 06 | `06-progress.md` | Append-only log: dated entries by sprint/slice/decision/gotcha | LIVE — appended by `/commit` and `/implementation-check` |
| 07 | `07-constraints.md` | Hard constraints — budget, timeline, compliance, perf targets | generic-friendly |
| 08 | `08-governance.md` | Pointers to governance docs (PRD, SRS, Backlog, etc.) + workflow rules | generic-friendly |
| – | `index.md` | TOC over the bank | generated |
| – | `WORKFLOW.md` | Per-sprint workflow — pointers to `/spec` → `/implement` → `/implementation-check` → `/commit` loop | mostly generic |

### Tier strategy (always-preloaded vs branch)

- **Tier 0 — always preloaded** (~250–400 lines total): `CLAUDE.md`, `index.md`, `00-project-brief.md`, `05-active-context.md`, plus the executive summary + Phase 1 of `MASTER-SPEC.md`.
- **Tier 1 — branch by query type**:
  - *Architecture / system-design* → `02-system-patterns.md`, `04-tech-context.md`
  - *Implementation / coding* → `03-code-patterns.md`, `04-tech-context.md`, `02-system-patterns.md`
  - *Product / UX* → `01-product-context.md`
  - *Planning / scoping* → `07-constraints.md`, `08-governance.md`
  - *Workflow / process* → `WORKFLOW.md`, `06-progress.md`

The branch rules are encoded in `CLAUDE.md` itself, so a fresh session knows what to load when the user's first message lands.

### Live vs derived

- **Live files (05, 06)**: authored by commands during work, never auto-regenerated.
- **Derived files (00, 01, 02, 03, 04, 07, 08)**: in the original `/onboard` design, these would be re-derived from `MASTER-SPEC.md`. Each derived file carries a `Last derived from MASTER-SPEC.md @ <date>` line so users can detect drift.

In practice on wabash the derived files are hand-edited too — the `/onboard` derivation didn't get built; the files were authored manually after enough sessions revealed what each needed.

---

## 3. Spec evolution — sprint by sprint

The wabash slice spec format **drifted** over time. The `docs/specs/README.md` documents the v1.0 template (dated 2026-04-18), but actual sprint-5 and sprint-6 specs do not match it. This is a real signal: the documented template was a starting point, not the steady state.

### Volume per sprint (line totals across all slice files)

| Sprint | Total lines | Slice count | Avg lines/slice |
|---|---|---|---|
| 1 | 1,083 | (varies) | ~150 |
| 2 | 2,045 | | |
| 3 | 3,320 | | |
| 4 | 2,171 | 23 | ~95 (mostly small frontend slices) |
| 4r (refactor) | 4,904 | 14 | ~350 |
| 5 | 1,721 | 6 (3 specs + 3 handoffs) | ~290 |
| 6 | 2,328 | 8 (4 specs + 4 handoffs) | ~290 |

### Format A — sprints 1 through 4 (and the documented README template)

Seven sections in this order:

```markdown
# Spec: <Slice Title>

## Traces
- SRS: REQ-...
- Backlog: Epic N Feature N.M Story N.M.K
- ARCH: §N.M.K
- Depends on: slice-NN-other.md (if any)

## Inputs (precise)
<table name + filters; API params; file format; Pydantic model names>

## Outputs (precise)
<DB tables (REPLACE vs APPEND), API endpoints, UI components, schemas>

## Behavior
<Bullet list of specific behaviors. Pseudocode allowed. Edge cases called out.>

## Acceptance (Given/When/Then)
- [ ] AC-1: Given <state>, when <action>, then <observable outcome>
- [ ] AC-2: ...

## Verification
<bash block: test commands, manual smoke, expected outputs>

## Not in this slice
<explicit scope fencing>
```

Example: `docs/specs/sprint-4/slice-12-otp-kpi-cards.md` (89 lines) follows this format exactly — clean, readable, reviewable on one screen.

### Format B — sprints 5 and 6 (current evolved format)

Eight sections, numbered top-level. Decisions become first-class.

```markdown
# Slice <sprint>-<NN> — <name>

Status: <phase> (<date>) — <readiness marker>
Sprint: N (<theme>)
Branch (canonical codebase): <branch-name>
Depends on: slice <prev>-<nn> (commit <hash>) <one-line reason>
Owner: solo
Implementation effort: low | medium | high | xhigh
Estimated size: ~<LOC delta> across <N> files. <one-paragraph framing>.

## 1. Traces
- Source: <ticket / ISSUE-N / memory-bank entry>
- Format analog: <predecessor slice this mirrors>
- Phase 1 explore: <conversation reference>
- Cumulative-lessons stack carries forward (1-N). Lessons X, Y, Z directly applicable.
- No new top-level deps (or list them).

## 2. Decisions baked in

### D-<sprint>-<NN>-1 — <decision title>
<paragraph or two explaining the decision and approach>

Rejected: <alternative 1>. Reason: <why>.
Rejected: <alternative 2>. Reason: <why>.
Rejected: <alternative 3>. Reason: <why>.

### D-<sprint>-<NN>-2 — <next decision>
... <same shape>

(typically 4-9 decisions)

## 3. Files to modify
<intro paragraph; sometimes grouped by "Thrust A/B/C/D">

| File | Action | LOC delta | Notes |
|---|---|---|---|
| <path> | UPDATE | +N / -M | <one-line description with rationale> |
| ... |

## 4. Acceptance criteria

- [ ] AC-1 (<short tag>): <criterion with grep / shell verification embedded>
- [ ] AC-2 (...): <ditto>
- ... (typically 8-12 ACs)

## 5. Verification

\`\`\`bash
cd <canonical codebase root>

# Branch + status
git branch --show-current
git status

# AC-1 — <description>
<verification command>

# AC-2 — <description>
<verification command>

# ... per AC
\`\`\`

## 6. Not in this slice
- <out-of-scope item 1> (<forward-ref to slice that handles it>)
- <out-of-scope item 2>
- ...

## 7. Reference index
- <slice predecessor 1> — <commit hash> — <one-line>
- <slice predecessor 2> — <commit hash> — <one-line>
- <memory-bank entry referenced>
- <helper location in canonical codebase>
- ...
```

Example: `docs/specs/sprint-5/slice-01-dockerfile-authoring.md` (240 lines), `docs/specs/sprint-6/slice-04-otp-codegen-sync-and-apierror-migration.md` (200 lines).

### What changed between Format A and Format B (and why)

| Change | Why it appeared |
|---|---|
| Top-level sections renumbered (1–7) | Cross-references between slices became common; `§3` is faster than "Files to modify" |
| Decisions made first-class (`§2`) | Sprint-5 had heavy refactor work; alternatives killed mattered as much as the chosen path |
| `D-<sprint>-<slice>-<n>` IDs | Decisions get cited in commit messages and follow-up slices |
| "Rejected: X. Reason: Y." sub-structure | Forces explicit kill-reasons; prevents revisiting closed alternatives |
| Files-to-modify table | Big slices were touching many files; needed an inventory before editing |
| ACs with embedded grep/shell verification | Spec doubles as verification script; reviewer can copy-paste |
| Reference index | Cross-slice dependencies became common (e.g., "uses helper from slice 6-03") |
| Header metadata (Status / Sprint / Branch / Depends on / Owner / Effort / Size) | Implementer needs to know these before opening any file |
| Implementation handoff companion | See §4 below |

The format change tracks the project's complexity growth, not a deliberate "redesign." The README v1.0 template was good for a 1-day green-field slice; sprint-5+ slices are 2–3 day refactor slices touching multiple layers, and the format adapted to carry more context.

---

## 4. The implementation-handoff companion file

Starting from sprint 5, every slice has TWO files:

- `slice-NN-<name>.md` — the spec itself (formats A or B above)
- `slice-NN-implementation-handoff.md` — a separate doc, typically 300–460 lines, that's a session-starter prompt for a fresh Claude session that will execute the slice

The handoff file contains:

- The full prompt the orchestrator session would paste to start the implementation session
- Every reference link the implementer needs (memory-bank pointers, prior-slice commit hashes, helper locations, related ARCH sections)
- Pre-flight calibration steps (run codegen first / observe diff / verify expectations before editing)
- "Notes for the orchestrator session (NOT part of the prompt — context only)" footer with explanations of *why* the handoff is shaped this way

The file is generated by the orchestrator session (Claude in a planning role) and consumed by an implementer session (Claude in an implementation role). The split exists because once orchestration takes a few thousand tokens of work to figure out *what* to do, that planning context shouldn't burden the implementation session — the implementer should start with a clean focused prompt.

**Generalization note:** the orchestrator/implementer split is a heavy pattern. It pays off when slices are big enough that orchestration alone uses a meaningful portion of the context window. For small slices (one file, few ACs) it's overkill. Scaffold could offer this as a per-slice opt-in, not a default.

---

## 5. Sprint structure

Slices are grouped under `docs/specs/sprint-{N}/`. Sprint numbering is roughly weekly but flexible:

```
docs/specs/
├── README.md
├── sprint-1/   ← ingest + walking skeleton + scorecard
├── sprint-2/   ← Penske scorecards, chassis delays
├── sprint-3/   ← LLM Phase 2 (initial)
├── sprint-4/   ← UI build-out (lots of small slices)
├── sprint-4r/  ← refactor sprint (the "r" suffix)
├── sprint-5/   ← deploy / Dockerfiles / Bicep
└── sprint-6/   ← tech-debt + refinement (running in parallel with sprint 5 deploy)
```

Slice names are `slice-{NN}-<kebab-title>.md`. Within a sprint, slices are numbered contiguously; if a slice gets split mid-sprint, the new slice gets the next number — no renumbering. History stays sacred.

The "r" suffix on sprint-4r marks a major refactor that runs alongside the next sprint's normal feature work. This is wabash convention; not necessarily generalizable.

---

## 6. The `/implementation-check` command

After a slice's implementation finishes (in canonical codebase), the user runs `/implementation-check [SLICE-ID] [--full] [--path <dir>]`. The protocol lives in `.claude/commands/implementation-check.md`. It validates:

- Spec coverage: every AC in the slice spec has a corresponding test or verification step
- Hexagonal rules: no LLM SDK imports outside `packages/insights/client.py`, no `requests`/`urllib`, etc.
- Code style invariants
- Test coverage floors per `TEST_STRATEGY.md`

It's a structured replay of the spec against the implementation, run before declaring the slice done.

**Generalization note:** this is a good pattern. Scaffold has a similar gate built into `/slice-verify`, but it's lighter-weight (just "ACs ticked + tests green"). Adding richer rule-based checks (no banned imports, coverage floors, etc.) is a v1.x candidate.

---

## 7. CLAUDE.md as session-start router

Wabash's `CLAUDE.md` (197 lines) is itself a structured doc with:

1. What this file is (preface)
2. Dual-repo topology
3. Required reading at session start (loaded in order, ≤250 lines)
4. Project in 5 lines (one-line summary)
5. Conventions (git workflow, where edits go, stated-default pattern, hexagonal boundaries, committed-text neutrality)
6. Code style pointer
7. SSoT pointers (table of "need → canonical path")
8. Slash commands
9. Update triggers for memory-bank
10. Session hygiene (when to use plan mode vs edit mode, spec-first gate, model+effort isolation)
11. What NOT to do
12. Relationship to native auto-memory
13. The `.archive/` directory rules

The 197-line shape is the result of evolution. Earlier versions were thinner. Sections were added when a new failure mode (e.g., model+effort leak across sessions; auto-memory vs memory-bank confusion) needed a rule.

**Generalization note:** scaffold's two-layer CLAUDE.md generator (personal + project) is the right shape but emits a much thinner file. Whether to grow toward wabash's depth depends on whether the project actually has the failure modes that motivated each section.

---

## 8. Native auto-memory split

Wabash distinguishes:

- **Native auto-memory** at `~/.claude/projects/-home-pras-Documents-wabash/memory/` — owns: feedback rules, user corrections, preferences, cross-session behavioral instructions. *How to act.*
- **`.claude/memory-bank/`** — owns: project-scoped operational state + SSoT navigation. *What's where.*

The split is enforced in `CLAUDE.md §12` with rules like "if it's a preference or correction → native memory; if it's a fact about the project's structure → memory-bank."

**Generalization note:** scaffold's MCP memory bank conflates both — it stores patterns, decisions, notes, retrospectives without distinguishing "act this way" rules from "this is how the project is structured" facts. The wabash split is a useful refinement.

---

## 9. What to port to scaffold (recommended), what to leave (recommended)

### Port wholesale (generic gold)

- `D-<NN>-<n>` decision IDs in slice spec, with explicit "Rejected: X. Reason: Y." sub-structure
- Files-to-modify table with LOC delta + rationale
- Verification commands embedded per AC
- Reference index section
- Header metadata block (Status / Branch / Depends on / Effort / Size)
- "Not in this slice" with rationale per item (already in scaffold)
- 9-file memory-bank shape (00-project-brief, 01-product-context, 02-system-patterns, 03-code-patterns, 04-tech-context, 05-active-context, 06-progress, 07-constraints, 08-governance) with the live-vs-derived split
- Tier-0 vs branch loading pattern in CLAUDE.md
- Native-auto-memory vs project-memory-bank split (clear rules)

### Port partially (concept generalizes; specific shape doesn't)

- Sprint grouping — opt-in per project; flat fallback for non-sprint workflows
- Implementation effort tier — concept yes; specific alias names (`claude-impl-h` etc.) no
- `/implementation-check`-style structured gate — yes, but project-configurable rule set, not hardcoded hexagonal

### Don't port (wabash-bespoke)

- Dual-repo topology (most projects are single-repo)
- SRS REQ-IDs / ARCH §N references / Backlog Story IDs in Traces (project-bespoke upstream doc hierarchy)
- Hexagonal/Protocol enforcement language (wabash code shape)
- Pre-flight calibration ritual (codegen-shape specific)
- Cumulative-lessons stack 1–N (sprint-aging-specific)
- The `slice-NN-implementation-handoff.md` companion (heavy; offer as opt-in module, not default)
- "claude-plan / claude-orch / claude-impl / claude-impl-h" effort aliases (your machine setup)
- "Committed-text neutrality" rules (wabash team-specific)

---

## 10. Files to read for full context

If you want the full picture without my summary:

| Topic | File |
|---|---|
| Dual-repo rules + git workflow | `/home/pras/Documents/wabash/CLAUDE.md` |
| Memory-bank tier strategy | Same file, §3 + §6 |
| Spec template (documented v1.0) | `/home/pras/Documents/wabash/docs/specs/README.md` |
| Spec format A example | `/home/pras/Documents/wabash/docs/specs/sprint-4/slice-12-otp-kpi-cards.md` (89 lines) |
| Spec format B example | `/home/pras/Documents/wabash/docs/specs/sprint-5/slice-01-dockerfile-authoring.md` (240 lines), `sprint-6/slice-04-otp-codegen-sync-and-apierror-migration.md` (200 lines) |
| Implementation-handoff example | `/home/pras/Documents/wabash/docs/specs/sprint-5/slice-01-implementation-handoff.md` (300+ lines) |
| Memory-bank file shapes | `/home/pras/Documents/wabash/.claude/memory-bank/00-dual-repo-topology.md`, `02-system-patterns.md`, `03-code-patterns.md` (each ≈ 100–300 lines) |
| The `/onboard` design (NOT in wabash; in the scaffolding repo) | `/home/pras/Documents/claude-agent-scaffolding/SPEC.md` lines 109–500 |
