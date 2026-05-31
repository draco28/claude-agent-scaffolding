# Changelog

All notable changes to scaffold-dev documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [0.1.7] — 2026-05-31

### Fixed
- **#35 — invalid YAML frontmatter made Codex skip four skills.** The `description:` frontmatter on `implementation-checking`, `appending-changelog-entry`, `authoring-runbook`, and `executing-work-item` contained unquoted `: ` (colon-space) sequences (`Read-only:`, `changelog: <entry>`, `six sections:`, `Dual-use:`) that Codex's Psych loader parsed as a nested mapping → `Psych::SyntaxError`, so the four skills were silently dropped on load. Each value is now single-quoted (trigger phrases preserved byte-for-byte). The dual-publish suite (`tests/test-codex-dual-publish.sh`) now parses every published `SKILL.md` frontmatter with Ruby Psych and fails on any future unquoted-`: ` regression.
- **#36 — per-work-item gate silently false-greened on normally-authored specs.** `implementation-checking` §4 parses `auto:` acceptance-criteria lines from a work-item spec's section 6, but `work-item-spec.md.tmpl` §6 rendered a markdown table (`{{acs_table}}`) the parser could not read — so a real spec yielded zero ACs and the gate fell through with nothing verified. §6 now renders machine-checkable `auto:`/`user:` lines (`{{acs_block}}`) as the **single AC source of truth** (the parallel table var is removed — it was the drift vector); `planning-vertical-slice` authors that block; and the gate **degrades loudly** (`[AC]` advisory + a ≥3-option menu, never a green) when zero `auto:` ACs are found. The authored line grammar is `- [ ] AC-1 auto: \`<command>\` → expected: <exit 0 | exit N | output contains <text>>` — the command is backtick-wrapped (so `lib/verify.sh::sd_verify_auto_step` can extract and run it), carries a real numbered `AC-1`/`AC-2`/… label (so `sd_verify_report_cross_check` engages instead of silently skipping, and template boilerplate avoids the literal `AC-N` that would grep as a phantom id), and uses the `output contains` substring **unquoted** (it is matched literally via `grep -F`). New render-contract test (`scaffold-dev/tests/test-render.sh`) asserts the concrete rendered command + that `{{acs_block}}`/`{{acs_table}}` placeholders resolved (false-green-proof), and eval scenario S5 covers the zero-AC loud-degrade path (the prior evals hand-authored `auto:` fixtures the real template never produced, which is why the bug escaped the suite).

## [0.1.6] — 2026-05-30

### Fixed
- **#28 Phase 3 — consume the 3-part slice id by field-read instead of heading-grep (cross-plugin contract fix).** scaffold-onboard authors 3-part slice ids (`VS-<phase>.<sprint>.<slice>`, e.g. `VS-1.1.1`) with an explicit `sprint_id` (`1.1`), but scaffold-dev located slices by grepping a `#### VS-…:` heading in `ROADMAP.md` and recovered the sprint by string-splitting the id's **first** field — so `VS-1.1.1` mis-derived `sprint-1` instead of the real `sprint-1.1` (and `closing-vertical-slice` did the same via an `awk -F'[.:]'` over a `#### VS-${sprint_n}\.…:` grep). scaffold-dev now **field-reads** the slice from the structured `project-roadmap.json` that scaffold-onboard publishes (manifest `well_known_paths.roadmap_state`): it matches `id` exactly and reads `sprint_id` as a field — no id parsing — so every path/branch sprint segment (`sprint-<sprint_id>`) is correct. This also resolves the pre-existing bug where `planning-vertical-slice` read `.routing.roadmap` (a repo *selector* like `"canonical"`) as if it were a filesystem path.

### Added
- **`lib/roadmap.sh`** — `sd_roadmap_state_path` (resolve the published `project-roadmap.json` via `well_known_paths.roadmap_state`, with a forward-compat fallback to `${ai_workspace.root}/.workspace/project-roadmap.json` and an unresolved-placeholder guard), `sd_roadmap_slice_json` (exact-`id` lookup, fails listing available ids), `sd_roadmap_slice_field`, and `sd_roadmap_slice_sprint_id`. New `tests/test-roadmap.sh` (10 assertions).

### Changed
- **`lib/worktree.sh`** — `_sd_worktree_branch_name` / `sd_worktree_add` take an explicit `sprint_id` (the branch template's `{N}` sprint segment); when omitted it is derived from the 3-part id by dropping the slice segment (`VS-1.1.1` → `1.1`), never the bare first field. Worktree paths are also namespaced by sprint (`.worktrees/sprint-1.1/work-1.01-...`) so compact work ids can repeat across sprints without filesystem collisions.
- **`planning-vertical-slice` / `closing-vertical-slice` SKILLs** — rewritten to field-read `id` + `sprint_id` from `project-roadmap.json`; `slice_root` and the sprint-final detection key off `sprint_id`; work-item ids stay compact `<slice-index>.<nn>` (e.g. `1.01`, not the 4-dotted `1.1.1.01`).
- **Fixtures, test helpers, and `docs/SPEC-scaffold-dev.md`** migrated to the 3-part id / dotted `sprint_id` convention (complete migration per the architect-critic C4 finding): `sprint-fixture-minimal` gains a published `project-roadmap.json`; the shared test manifest declares `well_known_paths.roadmap_state`; `test-e2e`/`test-worktree`/`test-state`/`test-harvest`/`test-merge` updated; SPEC §4.4 + §5.2 specify the 3-part id + field-read contract.
- **PR #32 review — Codex/CodeRabbit (6 findings).** Codex caught that the field-read migration was incomplete — other consumers still string-split the id or assumed integer sprints. Now consistent: `implementation-checking` and `closing-vertical-slice` locate the (existing) slice/work-item dir by **glob** off the field-read `sprint_id` instead of reconstructing it from an undocumented `vs_kebab`/`sprint_n`; `handing-off-session` accepts dotted `sprint-1.1` scopes and 3-field `vs-1.1.1` slice scopes; `writing-sprint-retrospective` accepts the dotted `sprint_id` (the `sprint-${N}` dir + `VS-${N}.*` glob already cover both); `closing-vertical-slice` §11 sprint-close cleanup keys off `sprint_id` (no more integer `sprint_n`/`+1`); `commands/orchestrate.md` advertises the 3-part `VS-N.M.K` argument. CodeRabbit nits: unified `VS-N.M` → `VS-N.M.K` arity across the SPEC + trigger lists; corrected a sprint example mismatch and the stale §14 anti-pattern glob (`vs-${vs_id}-*` → `${vs_slug}-*`).

## [0.1.5] — 2026-05-29

### Fixed
- **Issue #24 — skill-description bloat.** The `description:` frontmatter on nine skills (handing-off-session, recording-architecture-decision, appending-changelog-entry, executing-work-item, authoring-runbook, writing-sprint-retrospective, closing-vertical-slice, implementation-checking, planning-vertical-slice) crammed the full behavioral contract into the description (handing-off-session at 1543 chars exceeded Claude Code's per-entry cap; others were dropped from the listing, disabling reliable auto-invocation, and inflated session token cost). Rewrote each to ~450–500 chars preserving all trigger phrases, slash-command tokens, and disambiguations (the detailed contract already lives in each SKILL body). No behavioral change.

## [0.1.4] — 2026-05-29

### Fixed
- **Issue #19 — `/handoff` flag parsing broken by slash-command `$N` substitution:** `commands/handoff.md` and the `handing-off-session` §10 example parsed flags with `case "$1"`, but Claude Code freezes bare `$1`/`$2`/`$N` at template-render time, so `--scope`/`--purpose`/`--return-of` came out empty — silently mis-authoring a **return** handoff as a forward and breaking the A→B→C chain. Flag parsing now lives in a shared, unit-tested helper `sd_handoff_parse_flags` (regex/`BASH_REMATCH`, immune to `$N`; accepts space- and `=`-delimited values; `--return` vs `--return-of` disambiguated by the separator). The command invokes it via the `sd` dispatcher; the §10 doc example shows the equivalent inline regex.

### Added
- `sd_handoff_parse_flags` in `lib/handoff.sh` + 5 regression tests in `tests/test-handoff.sh` (space form, `=` form, `--return-of`/`--return` disambiguation, empty args).

## [0.1.3] — 2026-05-28

### Added
- **Issue #14 — trace propagation:** scaffold-dev work-item specs and implementation handoffs now include ROADMAP traceability links for `FR-N`, `NFR-N`, and `BACKLOG-N` IDs.

### Changed
- The vertical-slice planning skill now extracts ROADMAP traceability blocks and carries the NFR success-bar context into downstream specs and handoffs.

## [0.1.2] — 2026-05-26

Shell-portability patch (v0.x.1 bundle). See `docs/HANDOFF-shell-portability-v0x1.md` in the marketplace repo.

### Fixed
- **Shell portability (zsh compatibility):** Claude Code's Bash tool runs zsh by default on macOS; skill bodies that `source lib/*.sh` then inherited zsh, where `${BASH_SOURCE[0]}` is unset and lib self-location crashed (`BASH_SOURCE[0]: parameter not set`). Added `bin/sd` dispatcher with `#!/usr/bin/env bash` shebang — kernel forces bash on direct execution regardless of caller shell. All 12 source-call sites across 9 skill bodies refactored to invoke `sd <fn-suffix>` instead of `source && fn` (`handing-off-session`, `writing-sprint-retrospective`, `recording-architecture-decision`, `appending-changelog-entry`, `authoring-runbook`, `implementation-checking`, `closing-vertical-slice`, `planning-vertical-slice`). Cross-plugin call into scaffold-onboard's `sf_rules_*` API (per SPEC §16.2) routes through the `sf` dispatcher. Skill bodies discover the plugin root via `SD_PLUGIN_ROOT="$(dirname "$(dirname "$(command -v sd)")")"` when they need to resolve a template path — works under zsh, does NOT depend on `$CLAUDE_PLUGIN_ROOT` which the host runtime doesn't export (anthropics/claude-code#48230). `sd --list` enumerates dispatchable functions. The dispatcher is auto-discoverable via `$PATH` (Claude Code adds each plugin's `bin/` to PATH automatically).

## [0.1.1] — 2026-05-25

Install-blocking schema fixes surfaced by first `/plugin install scaffold-dev` against live Claude Code. No behavioral changes.

### Fixed
- **`hooks/hooks.json` schema** — wrapped the `SessionStart` declaration in the required top-level `hooks: { ... }` object with the `matcher` + `hooks[]` + `type: "command"` shape that Claude Code's hooks loader actually validates. The v0.1.0 shorthand (`{"SessionStart": "hooks-handlers/session-start.sh"}`) was the PLAN-provided sketch, not the production schema; v0.1.0 install raised `Hook load failed: expected: "record", code: "invalid_type", path: ["hooks"]`. Matches `scaffold-onboard/hooks/hooks.json` shape verbatim.
- **Subagent registration format** — replaced `.claude-plugin/agents.json` (the PLAN-provided provisional shape) with `agents/implementer-agent.md` per Claude Code's actual per-agent markdown-with-frontmatter format. Frontmatter declares `name: implementer-agent` (Claude Code auto-prefixes the plugin name → `scaffold-dev:implementer-agent` at dispatch), `description:`, `tools: Bash, Read, Write, Edit, Glob, Grep` (Task omitted to forbid nesting), `model: inherit`. The body references the single-source-of-truth `skills/executing-work-item/SKILL.md` as the binding system prompt — keeps the dual-use SKILL.md authoritative.
- **`tests/test-subagent.sh`** — rewrote 6 assertions (subagent name, file existence, description field, tools allowlist, Task absence, body reference to skill) for the new `agents/implementer-agent.md` format. Other 8 assertions (return-mode JSON shapes, enums, clarification loop, malformed rejection) unchanged. 14 test functions / all PASS.

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
