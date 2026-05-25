# Changelog

All notable changes to scaffold-dev documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [0.1.0] — 2026-05-25

Initial release. Sprint-driven orchestrator-implementer workflow for dual-repo workspaces. Replaces `scaffold` v1.0.0 (deprecated).

### Added
- **9 skills under `skills/<name>/SKILL.md`** (structural skill-first per SPEC §4): `planning-vertical-slice` (slice plan + spec from R1/R3), `executing-work-item` (TDD-loop implementer body invoked as subagent), `implementation-checking` (R2 mcrule enforcement + verify gates), `closing-vertical-slice` (R3 demo verification + report harvest + slice retrospective), `handing-off-session` (handoff escape valve writer at `.workspace/handoffs/`), `recording-architecture-decision` (ADR authoring), `appending-changelog-entry` (Keep-a-Changelog append), `authoring-runbook` (operational runbook authoring), `writing-sprint-retrospective` (sprint-close retrospective + slice harvest).
- **4 slash commands** wrapping the skills via `$ARGUMENTS` env-var bridge: `/orchestrate` (sprint-level driver), `/work-item` (single work-item dispatch), `/impl-check` (rule + gate verification), `/handoff` (session handoff writer).
- **1 subagent type** `scaffold-dev:implementer-agent` declared in `.claude-plugin/agents.json` — executes a single work item per a handoff doc; pre-flight gap check; TDD loop per AC; verify; author `report.md`; stage changes (no commit); returns structured JSON. Tools allowlist excludes `Task` (no nested dispatch). **Provisional schema** pending Claude Code subagent-type stabilization — shape may evolve in v0.2.
- **SessionStart hook with Tier 0 marker coordination** — first-write-wins marker at `${TMPDIR}/claude-code-tier0-${CLAUDE_SESSION_ID}` coordinates with scaffold-onboard's SessionStart so only one plugin emits the Tier 0 boot banner per session. ~2.5ms typical (50ms budget per SPEC §11).
- **Handoff escape valve** at `.workspace/handoffs/*.md` for session-boundary context preservation. Markdown handoff template (`templates/handoff.md.tmpl`) captures current state + next steps + unresolved questions; resumable across compaction/clear.
- **11 lib helpers** under `lib/`: `manifest.sh` (workspace-init manifest consumer), `state.sh` (sprint + slice state CRUD with atomic writes), `worktree.sh` (git worktree lifecycle for parallel slices), `merge.sh` (slice merge-back orchestration), `harvest.sh` (report.md collation into slice + sprint retrospectives), `verify.sh` (test + mcrule + demo-criteria gate runner), `rules.sh` (R2 mcrule evaluator — banned_imports, coverage_floor, style_invariants, required_pattern), `render.sh` (template substitution `{{key}}` + conditionals), `handoff.sh` (escape-valve writer + resume reader), `compose.sh` (filesystem-probe detection for architect-critic / ai-mentor / superpowers — no file IPC), `_helpers.sh` (shared utilities).
- **8 templates** under `templates/`: `adr.md.tmpl`, `handoff.md.tmpl`, `implementation-handoff.md.tmpl` (orchestrator → implementer subagent contract), `implementation-report.md.tmpl` (implementer → orchestrator return doc), `slice-retrospective.md.tmpl`, `sprint-retrospective.md.tmpl`, `vertical-slice-readme.md.tmpl`, `work-item-spec.md.tmpl`.
- **14 test files / ~216 assertions passing** across `tests/`: `test-state.sh`, `test-manifest.sh`, `test-worktree.sh`, `test-merge.sh`, `test-harvest.sh`, `test-verify.sh`, `test-rules.sh`, `test-render.sh`, `test-handoff.sh`, `test-compose.sh`, `test-helpers.sh`, `test-hook.sh`, `test-subagent.sh`, `test-e2e.sh` (3 e2e scenarios: minimal sprint, bug-fix handoff chain, composition with architect-critic + ai-mentor).

### Composition
- **workspace-init v0.1+** — manifest at `<ai-workspace>/.workspace/pairing.json` consumed for routing every artifact (slice specs to ai_workspace, ADRs per `routing.adr`, etc.). Single-repo fallback preserved.
- **scaffold-onboard v0.2+** — consumes R1 (Phase → Sprint → Vertical Slice hierarchy from `ROADMAP.md`), R2 (machine-checkable rules from `.claude/memory-bank/03-code-patterns.md`), R3 (`auto:`/`user:` demo criteria with literal U+2192 arrow).
- **architect-critic v0.2+** — invoked via `Skill(architect-critic:critiquing-spec)` at slice spec close, sprint-close retrospective, and ADR draft. Filesystem-probe detection (no file IPC).
- **ai-mentor v2.0+** — `Skill(ai-mentor:grill-me)` invoked at 3 gates: slice-plan close, mid-slice stuck-state, sprint retrospective.

### Replaces
- **`scaffold` v1.0.0** (DEPRECATED) — superseded by scaffold-dev's skill-first orchestrator-implementer split, dual-repo native design, R1/R2/R3 contract consumption, and subagent-via-Task-tool model. Migration: install scaffold-dev alongside scaffold v1.0.0 for the transition window; new sprints should use `/orchestrate`. scaffold v1.0.0 will remain in the marketplace as deprecated through one release cycle.
