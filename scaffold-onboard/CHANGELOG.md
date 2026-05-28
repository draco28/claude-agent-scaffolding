# Changelog

All notable changes to scaffold-onboard documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [0.2.2] — 2026-05-28

### Added
- **Issue #14 — traceability-first docs:** default SRS and BACKLOG templates now mint stable `FR-N`, `NFR-N`, and `BACKLOG-N` IDs for downstream planning.
- **Issue #14 — roadmap trace links:** roadmap slice records now include `traces_fr`, `traces_nfr`, and `traces_backlog` arrays; ROADMAP rendering shows trace links under each vertical slice.
- **Issue #14 — coverage report:** added `sf roadmap_traceability_report` to print covered and unassigned FR/NFR/BACKLOG IDs from generated docs and `project-roadmap.json`.

### Changed
- Roadmap planning guidance now recommends `/scaffold-docs` before `/plan-roadmap` for traceability-first projects while preserving lightweight MASTER-SPEC-only planning with warnings.

### Fixed
- **Issue #13 — manifest routing regression coverage:** added a real workspace-init resolver integration test proving `sf resolve_output_path master_spec MASTER-SPEC.md` does not double-append `.workspace/pairing.json`.

## [0.2.1] — 2026-05-26

Shell-portability + cross-project-contamination patch (v0.x.1 bundle). See `docs/HANDOFF-shell-portability-v0x1.md` and `docs/HANDOFF-shell-portability-v0x1-RETURN.md` in the marketplace repo.

### Fixed
- **Shell portability (zsh compatibility):** Claude Code's Bash tool runs zsh by default on macOS; skill bodies that `source lib/*.sh` then inherited zsh, where `${BASH_SOURCE[0]}` is unset (libs crash with `parameter not set`) and `${BASH_REMATCH[…]}` returns empty silently (parser appears to work, downstream gets garbage — scaffold-onboard had the worst silent-corruption surface with 11 BASH_REMATCH sites in spec parsers / rule validators). Added `bin/sf` dispatcher with `#!/usr/bin/env bash` shebang — kernel forces bash on direct execution regardless of caller shell. `validating-master-spec/SKILL.md` and its example walkthroughs refactored to invoke `sf <fn-suffix>` instead of `source && fn`. `sf --list` enumerates dispatchable functions. The dispatcher is auto-discoverable via `$PATH` (Claude Code adds each plugin's `bin/` to PATH automatically).
- **Issue #3 — `sf_data_dir` no longer falls back to `~/.scaffold-onboard-test-data/`:** that path was originally a "test fallback" but became the production-active path because Claude Code does not export `CLAUDE_PLUGIN_DATA` to Bash tool subprocesses (anthropics/claude-code#48230). v0.2.1 derives the canonical `~/.claude/plugins/data/<plugin>-<marketplace>/` path from `$PLUGIN_ROOT` when the install matches the cache layout, and falls back to `~/.claude/plugins/data/scaffold-onboard-local/` (intentionally NOT colliding with the host-runtime path) when derivation fails. The old `~/.scaffold-onboard-test-data/` path is gone.
- **Issue #4 — cross-project state contamination:** added `project_root` field to `onboarding-state.json` schema. `sf_state_init` captures `pwd` (or `$SF_PROJECT_ROOT` if pre-exported); `sf_state_mode` now returns a new `project_mismatch` value when the stored `project_root` differs from current `pwd`, prompting the user before resuming a stranger's state. New `sf_state_stored_project_root` helper returns the stored path (or `unknown` for legacy state files lacking the field). The `onboarding-project` skill's resume protocol updated to handle `project_mismatch`. Legacy state files (pre-v0.2.1) lacking `project_root` surface as `project_mismatch` with stored=`unknown`, forcing user confirmation.

### Migration notes
- Existing `~/.scaffold-onboard-test-data/onboarding-state.json` files are NOT auto-migrated to the new canonical path. To preserve in-flight onboarding state from v0.2.0, manually `mv ~/.scaffold-onboard-test-data ~/.claude/plugins/data/scaffold-onboard-claude-agent-scaffolding` (substitute your marketplace name) or delete the stale file and restart `/onboard`.
- Legacy state files lacking `project_root` will trigger the project-mismatch prompt on next `/onboard` invocation — pick "start fresh here" to overwrite with a new init.

## [0.2.0] — 2026-05-24

### Added
- **7 skills under `skills/<name>/SKILL.md`** (structural skill-first per SPEC §4.3): `onboarding-project`, `scaffolding-memory-bank`, `scaffolding-governance-docs`, `planning-project-roadmap`, `authoring-machine-checkable-rules`, `authoring-vertical-slice-demo`, `validating-master-spec`. Each ≤500 lines. Slash commands become thin Skill-tool dispatchers via `$ARGUMENTS` env-var bridge.
- **16 reference sub-docs** under `skills/<name>/references/` providing worked examples + edge cases + extensibility notes.
- **7 behavior eval docs** under `evals/` covering the 7 skills (Phase 0 — Agent-dispatch harness per [feedback_claude_code_sessions_only]).
- **R1 — Phase → Sprint → Vertical Slice hierarchy** via new `/plan-roadmap` slash command + `planning-project-roadmap` skill. Outputs `ROADMAP.md` (NEW; does NOT collide with v0.1.0's `PROJECT_PLAN.md` which is preserved unchanged). State at `${CLAUDE_PLUGIN_DATA}/project-roadmap.json` with schema versioning + mutations array. 5 re-run modes. Size-class adaptation: >50 nodes triggers continue/split/reduce prompt; >100 biases toward split. Time-budget: 60-min advisory + 90-min warn-only.
- **R2 — machine-checkable rules DSL** via `authoring-machine-checkable-rules` skill + `lib/rules.sh`. HTML-sentinel format. 4 v0.2 types: `banned_imports`, `coverage_floor`, `style_invariants`, `required_pattern`. Extensibility: unknown types warn-and-skip per SPEC §8.5. Rules live in `.claude/memory-bank/03-code-patterns.md` `## Machine-checkable rules` section.
- **R3 — `auto:`/`user:` demo criteria grammar** per scaffold-dev SPEC §14.1 via `authoring-vertical-slice-demo` skill + `lib/demo-criteria.sh`. Literal U+2192 (→) arrow. Dual storage target (state-file during R1.C; markdown post-R1.C). Idempotent append.
- **Manifest-aware output routing** per SPEC §10 via new `lib/routing.sh`. `sf_resolve_output_path` resolves to ai_workspace or canonical per workspace-init's pairing.json `routing.*` table. Cross-plugin sourcing of `mi_manifest_resolve` with local fallback. Single-repo fallback preserved.
- **Tier 0 marker protocol** for hook coordination with scaffold-dev (SPEC §11). Marker at `${TMPDIR}/claude-code-tier0-${CLAUDE_SESSION_ID}` — first-write-wins. Measured ~2.5ms typical (50ms budget).
- **`/plan-roadmap` slash command** + updated `/onboard`, `/scaffold-project`, `/scaffold-docs` wired to Skills via `$ARGUMENTS` bridge.
- **Karpathy behavioral discipline section** opt-in for CLAUDE.md (SPEC §14): 4 principles, verbatim attribution `Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)`. Gated by `state.answers["phase_10.4.include_karpathy"]`.
- **lib/roadmap.sh, lib/rules.sh, lib/demo-criteria.sh, lib/routing.sh** — 4 new lib modules supporting R1/R2/R3 + routing.
- **5 new test suites** — `test-roadmap.sh` (34), `test-rules.sh` (30), `test-demo-criteria.sh` (27), `test-manifest-routing.sh` (14), `test-hook-marker.sh` (12).
- **229 net new tests across 12 suites** (392 total).

### Changed
- **`lib/compose.sh` refactor** — architect-critic detection moves from composition.json to filesystem probe per SPEC §12.2. composition.json no longer carries `plugins.architect-critic` entry; ai-mentor + superpowers probe behavior preserved. Detection is BINARY (v0.2-present-or-absent) — no v0.1.3 fallback.
- **`hooks-handlers/session-start.sh`** — extended with marker-aware Tier 0 protocol (preserves all v0.1.0 source-aware refresh logic).
- **`templates/memory-bank/03-code-patterns.md.tmpl`** — adds `## Machine-checkable rules` section heading seeded empty (R2 contract).
- **Slash commands** wrapped to invoke skills via `Skill(scaffold-onboard:<name>)` instead of inlining bash. Args via `$ARGUMENTS` env-var bridge.

### Removed (BREAKING — IPC contract)
- **`sf_compose_build_critic_request`** function from `lib/compose.sh` (was lines 257-339 in v0.1.0).
- **`sf_compose_read_critic_response`** function from `lib/compose.sh` (was lines 344-363 in v0.1.0).
- **inbox/outbox** file-IPC paths under `${CLAUDE_PLUGIN_DATA}/architect-critic/` no longer created or used.
- **15 IPC tests** from `test-compose.sh` (v0.1.0: 31 → v0.2: 24; -7 net in this suite, +8 new for filesystem-probe critic detection + skill-marker assertions).
- Migration: architect-critic v0.1.x users see "absent" warning at critic moments after upgrading scaffold-onboard. Install architect-critic v0.2+ to restore adversarial review (paired-release contract per SPEC §12.4).

### Composition
- **architect-critic v0.2+** — invoked via `Skill(architect-critic:critiquing-spec)` at Phase 5, Phase 7, MASTER-SPEC close, and `/plan-roadmap` close. Filesystem-probe detection (no shared registry per ac v0.2 settlement #1).
- **ai-mentor v2.0+** — invocation surface updated.
- **workspace-init** — manifest consumed for routing; forward-compatible with v0.1 manifests missing `roadmap` routing key (defaults to canonical).

### Contract (scaffold-dev v0.1 consumer)
- **R1** — ROADMAP.md hierarchy parseable per SPEC §7.1 + scaffold-dev §16.2
- **R2** — rules consumable by `implementation-checking` skill per SPEC §8.4
- **R3** — criteria parseable by `closing-vertical-slice` skill per SPEC §9.3

## [0.1.0] — 2026-05-14

### Added
- Plugin scaffold (Phase A) — manifest, LICENSE, README, CHANGELOG, command stubs, hook + lib skeletons, test helpers.
- lib/state.sh, lib/parser.sh, lib/render.sh (Phase B) — state CRUD with atomic writes + lock file, MASTER-SPEC.md parser with three primitives + 7 validation rules, template substitution with `{{key}}` + `{{#if}}` blocks.
- phases.yaml (10 phases, ~54 questions, branching gates), MASTER-SPEC + EXECUTIVE-SUMMARY templates, /onboard command with conversational protocol body, state advance + gate evaluation + mode detection + phases.yaml reader (Phase C).
- 11 memory-bank templates (00–08, index, WORKFLOW), CLAUDE.md template (Tier 0 + branch routing + plugin awareness), .claude/settings.json template, lib/memory-bank.sh with derive + CLAUDE.md generation + live-file preservation + --force, /scaffold-project command (Phase D).
- 14 governance doc templates (5 default + 9 --full, 3 LLM-project-gated), lib/docs.sh with default + --full derivation + --regenerate override, /scaffold-docs command (Phase E).
- lib/compose.sh with probe-path detection for ai-mentor / architect-critic / superpowers, composition.json caching with user-override toggles preserved across refresh, sf_compose_set_override input-validated setter, SessionStart hook (source-aware: refresh on startup/clear, preserve on resume/compact), mentor + brainstorming hint emitters keyed to Phase 5/7, architect-critic file-based handshake per SPEC §8.3 (request envelope build + response reader with polling timeout) (Phase F).
- End-to-end coverage on fresh + existing repos, resume after interruption, and cross-cutting composition mocked (Phase G TG.1–TG.4); README polish with Install + Quick start + Commands table (TG.5); hardening (TG.6): jq-then-mv writes guarded against partial failure, critic request_id seeded with PID+RANDOM entropy to prevent same-second collisions, file-lock protection on composition.json writes via sf_compose_lock_acquire/release with polling timeout.
- 163 tests across 7 bash test suites (state 23, parser 13, render 10, memory-bank 22, docs 23, compose 31, e2e 41).

### Composition
- Composes with `ai-mentor`, `architect-critic`, `superpowers`. Works standalone if any are absent.
