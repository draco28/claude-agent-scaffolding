# Discussion handoff — 2026-05-03

> Session-context dump so we can pick this up on Mac without re-deriving everything. Not committed to a particular plan; this is a snapshot of where the conversation stopped, what we found, and what's open.

## What this session covered

Started as a status check on the personal marketplace repo (`/home/pras/personal/claude-agent-scaffolding`) and turned into a deeper question about whether `scaffold` is fit for daily use, particularly for the kind of project the user runs on wabash.

The conversation moved in this order:

1. **Status of shipped plugins** — both pushed to remote, both at production versions.
2. **Status of scaffold for daily use** — technically v1.0.0, but battle-tested only in tests, not in real daily flow.
3. **Spec template comparison** — the user pointed at `/home/pras/Documents/wabash/docs/specs/` and asked whether the wabash format would generalize.
4. **Comparison finding** — wabash itself has two coexisting formats (the documented README v1.0 template vs. the actual sprint-5/6 D-decision format).
5. **Visual walkthrough started** — superpowers brainstorming + visual companion launched at `http://localhost:52781`. First screen showed the current scaffold greenfield user journey (`current-journey.html`). The screen surfaced a key gap.
6. **Key gap surfaced** — scaffold today has NO project-vision / architecture / SRS phase. `/scaffold-init` is silent automation; you go straight to slices. The user's expectation of "10-phase questions baked in" was off — that vision exists in a *different repo*, and was never shipped.
7. **Found the original vision** — `/home/pras/Documents/claude-agent-scaffolding/SPEC.md` (1021 lines) contains the original `/onboard` design with 10 phases, ~54 questions, MASTER-SPEC.md as source of truth, and 11-file memory-bank derivation. Different repo from the shipped marketplace — the shipped plugin is a much-smaller subset that skipped the onboarding work.
8. **Pause and document** — switching to Mac to continue with full repo context. This file captures the snapshot; `wabash-reference-working-project.md` captures the wabash conventions.

## Current state of `claude-agent-scaffolding` (this repo)

Latest commits on `main` (matches `origin/main` — clean, pushed):

```
5e289b4  ai-mentor v1.3.0: add /improve slash command
b0a9bc9  ai-mentor v1.2.0: add grill-me sibling skill
771c3ef  scaffold v1.0.0 — production release
6002fae  scaffold Phase I: E2E integration suite + 3 bug fixes
```

### ai-mentor (v1.3.0) — what shipped

User-level cognitive partner. Mechanically enforces "spotter mode" via a PreToolUse hook that blocks `Edit`/`Write`/`NotebookEdit` when in Curve 2.

Slash commands: `/z1`, `/z2-decide`, `/z2-build`, `/locked` (alias `/implement`), `/quiz l1..l4`, `/eli10`, `/fool`, `/improve`. Plus the `grill-me` sibling skill (Socratic plan/design interrogation, one question per turn, seven categories).

State: `${CLAUDE_PLUGIN_DATA}/state.json` (fallback `~/.claude/ai-mentor/state.json`). Survives plugin updates. Resets on `startup`/`clear` SessionStart sources; preserved through `resume`/`compact`.

Tests: 28 hook regression tests in `ai-mentor/tests/test-hooks.sh`. All green.

### scaffold (v1.0.0) — what shipped

Project-level workflow plugin with 18 slash commands across:

- **Bootstrap / status / audit** — `/scaffold-init`, `/scaffold-status`, `/scaffold-audit`, `/scaffold-claude-md-edit`, `/scaffold-claude-md-rebuild`.
- **Slice workflow (5-phase strict gates)** — `/slice-new`, `/slice-spec`, `/slice-contract`, `/slice-scaffold`, `/slice-implement`, `/slice-verify`, `/slice-list`, `/slice-status`.
- **Governance** — `/adr-new`, `/changelog`, `/runbook-new`.
- **Worktree** — `/scaffold-worktree-fork`, `/scaffold-worktree-list`.

Plus a Python MCP server with 10 tools for a per-repo memory bank (record_decision / record_pattern / record_note / record_retrospective / recall / list_recent / get_by_id / update / delete / reindex). SQLite + sqlite-vec + FTS5 hybrid search. Ollama embeddings via stdlib HTTP. Fail-soft when sqlite-vec is missing.

State: `${CLAUDE_PLUGIN_DATA}/<repo-hash>/<branch>/state.json`. Worktree-shared via `git rev-parse --git-common-dir`.

Tests: 236 across 9 suites. All green.

### What scaffold v1.0.0 does NOT do (the gap)

- **No `/onboard` command.** No phased questionnaire. No project-vision capture.
- **No MASTER-SPEC.md generation.** No SRS / PRD / ARCH document scaffolding.
- **No memory-bank markdown files.** The MCP memory is searchable but not human-readable as a session-start preload. There's no equivalent of wabash's `00-project-brief.md`, `02-system-patterns.md`, etc.
- **No D-decision IDs.** The slice template has a "Design notes / Trade-offs considered" placeholder — much weaker than wabash's `D-{sprint}-{slice}-{n}` with explicit "Rejected: X. Reason: Y." entries.
- **No sprint grouping.** Slices are flat-numbered.
- **No implementation-handoff companion file.** Wabash creates `slice-NN-implementation-handoff.md` alongside the spec; scaffold doesn't.

## The `/onboard` vision (NOT shipped — lives in a separate repo)

Location: `/home/pras/Documents/claude-agent-scaffolding/SPEC.md`. 1021 lines. Drafted but never built.

The vision is roughly:

1. `/onboard` walks the user through 10 expert-role phases (Foundation → Strategy → Domain → Security → Architecture → UX → Implementation → DevOps → Quality → Operations). ~54 questions, individually skippable, light branching on project class.
2. Output: `MASTER-SPEC.md` (source of truth) + `EXECUTIVE-SUMMARY.md`.
3. `/scaffold-project` derives 11 memory-bank files from `MASTER-SPEC.md` (project-brief, product-context, system-patterns, code-patterns, tech-context, active-context, progress, constraints, governance, index, WORKFLOW).
4. `/scaffold-docs` derives 5 (or with `--full`, 14) governance docs (PRD, SRS, BACKLOG, PROJECT_PLAN, ADR-0001, plus optional RISK_REGISTER, THREAT_MODEL, TEST_STRATEGY, etc.).
5. `/spec` authors a slice spec using a 9-section template (richer than the 7-section template that actually shipped).

This entire flow is what the user remembered as "10-phase questions" — that memory is correct, but the implementation went into the *spec*, not the *plugin*.

## The wabash spec format question

The user asked whether the wabash spec format generalizes well. Findings (full detail in `wabash-reference-working-project.md`):

- **Wabash itself has two coexisting formats.** Sprint 1–4 used the documented 7-section template (Traces / Inputs / Outputs / Behavior / Acceptance / Verification / Not-in-slice). Sprint 5–6 evolved to an 8-section format with `D-{sprint}-{slice}-{n}` decision IDs + Files-to-modify table + Reference index, and added a `slice-NN-implementation-handoff.md` companion file. The `docs/specs/README.md` was not updated to reflect this.
- **Some parts of the wabash format are project-bespoke and should NOT be ported wholesale**: SRS REQ-IDs, ARCH §N refs, Backlog Story IDs, dual-repo handoff blocks, hexagonal/Protocol enforcement language, pre-flight calibration ritual, cumulative-lessons stack 1–N, the specific `claude-impl-h` effort aliases.
- **Some parts are generic gold and should be in any template**: `D-` decision IDs with explicit "Rejected: X. Reason: Y." sub-structure; Files-to-modify table; verification commands per AC; Reference index; opt-in sprint grouping; effort tier tag; Traces section.

User direction (preliminary, to revisit on Mac): module system. Generic core template + opt-in modules for project-specific patterns (SRS-traces module, hexagonal module, dual-repo module, pre-flight-calibration module, etc.).

## Open threads

These are unresolved as of session end. Re-engage when picking back up:

1. **Is scaffold's correct path forward `/onboard` from the original SPEC.md, or just the slice-template upgrade?** Two questions in one — the user originally thought scaffold was supposed to have onboarding; it doesn't. Pick a direction:
   - (a) Build `/onboard` per the original SPEC.md (big v1.x story; brings scaffold closer to the "complete project initialization" vision).
   - (b) Skip onboarding; just upgrade the slice template (small v1.1 story; scaffold stays a slice/governance plugin).
   - (c) Both — `/onboard` as v1.2 and slice-template upgrade as v1.1.
2. **Module system shape.** If we go with the module idea, what's the unit of opt-in? Per-template-section (e.g., enable "SRS traces" section)? Per-feature (e.g., enable "implementation-handoff companion")? Per-project-shape (e.g., select profile "wabash-style" or "minimal")?
3. **MCP memory bank vs. markdown memory bank.** Wabash has both: searchable structured memory and human-readable markdown files derived from MASTER-SPEC. Scaffold today only has the searchable MCP version. Should scaffold also derive markdown files (the wabash 9-file pattern), and how do they stay in sync with MASTER-SPEC?
4. **Sprint vs. flat slice numbering.** Wabash uses sprints (which gives `D-{sprint}-{slice}-{n}` IDs); some projects don't. Need a story for both.
5. **Two-repo topology vs single-repo.** Wabash has the AI workspace + canonical codebase split. Most projects don't. Scaffold today is single-repo — would adding two-repo support be worth the complexity? (Likely not; it's wabash-bespoke.)

## What to do on Mac

Suggested re-entry sequence:

1. Clone or pull the marketplace repo on the Mac: `git clone github.com/draco28/claude-agent-scaffolding` or `cd ... && git pull`.
2. Read this file (`docs/discussion.md`) and `docs/wabash-reference-working-project.md`.
3. Open the original `/onboard` vision: `/home/pras/Documents/claude-agent-scaffolding/SPEC.md` lines 107–500 for the design (lines 130–298 for the question taxonomy).
4. Decide on the open threads above, then re-enter brainstorming with that context.

## Visual companion artifacts left in this repo

`.superpowers/brainstorm/1288236-1777826620/content/current-journey.html` — the first screen showed in the browser before the conversation pivoted. Captures the gap: scaffold today goes straight from `git init` → `/scaffold-init` → slices, with no architecture/vision phase. Kept for reference; safe to delete.
