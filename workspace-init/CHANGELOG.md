# workspace-init changelog

## 0.2.0 (2026-06-15)

### Added
- **`pairing-existing-dual` skill + `/pair-existing-dual` command (Scenario C, #9).** Pairs an already-populated AI workspace with an already-populated canonical — the case where a project grew its memory-bank/specs organically (in a sibling AI-workspace directory) before the plugins were discovered, and just needs a manifest to wire it up. Writes ONLY `.workspace/pairing.json` into the existing AI workspace and installs the trace-filter `commit-msg` hook (always in canonical; also in the AI workspace when it is itself a git repo). **Never creates, seeds, stubs, or overwrites** existing AI-workspace content — distinct from Scenario A (`pairing-canonical-repo`), which creates a *fresh* AI workspace and aborts on canonical AI-scaffolding markers. New lib preflight `wi_skeleton_preflight_existing_dual` (AI exists + non-empty; canonical exists + is a git repo; paths differ); conservative failure handling (no destructive rollback against populated content). 13 integration tests (`tests/test-pairing-existing-dual.sh`). SPEC §9.5. `pairing-canonical-repo` now cross-references this skill for the already-populated case.

## 0.1.2 (2026-05-30)

### Added
- **`well_known_paths.roadmap_state` (#28 Phase 2).** The pairing manifest now routes the structured roadmap state — `${ai_workspace.root}/.workspace/project-roadmap.json` — alongside the existing `master_spec` / `memory_bank` paths. scaffold-onboard publishes the structured roadmap there; scaffold-dev's orchestrator will field-read `id` + `sprint_id` from it (the #28 cross-plugin slice-ID contract fix) instead of grepping rendered `#### VS-…:` headings. Older manifests without the key are handled by consumer-side fallback (forward-compat, per the `routing.roadmap` §10.4 precedent).

## 0.1.1 (2026-05-26)

### Fixed
- **Shell portability (zsh compatibility):** Claude Code's Bash tool runs zsh by default on macOS; skill bodies that `source lib/*.sh` then inherited zsh, where `${BASH_SOURCE[0]}` is unset and lib self-location crashed. Added `bin/wi` dispatcher with `#!/usr/bin/env bash` shebang — the kernel forces bash on direct execution regardless of caller shell. Skill bodies (`initializing-dual-repo-workspace`, `pairing-canonical-repo`) and `/init-workspace` command now invoke `wi <fn-suffix> [args...]` instead of `source && fn`. `wi --list` enumerates dispatchable functions. The dispatcher is auto-discoverable via `$PATH` (Claude Code adds each plugin's `bin/` to PATH automatically), so callers don't need to know the plugin root.

## 0.1.0 (2026-05-25)

Initial release. Bootstrap a dual-repo workspace (AI workspace + canonical) with pairing manifest and AI-trace commit-msg filter. Run-once plugin; first in the scaffolding chain (workspace-init → scaffold-onboard → scaffold-dev). 145 tests across 10 suites.

### Added
- Skills: `initializing-dual-repo-workspace`, `pairing-canonical-repo` (skill-first per Pass D).
- Slash commands: `/init-workspace`, `/pair-workspace` (thin `$ARGUMENTS` wrappers per feedback_slash_command_dollar_n_bug).
- `lib/` bookkeeping: manifest read/write/resolve (`mi_manifest_resolve` alias per SPEC §6.3), skeleton, stubs, git-init with default-branch fallback chain, trace-filter hook install, transactional rollback.
- `commit-msg` git hook template with baked AI workspace path per SPEC §7.3.
- Pairing manifest schema v1.0 at `<ai-workspace>/.workspace/pairing.json`.
- Scenario A migration (`--pair-with <existing-canonical>`).
- 145 tests across 10 suites; `run-tests.sh` runner.

### Deferred to v0.2
- Git remotes auto-setup (per project_workspace_init_v02_deferrals).
- User-global workspace registry (per project_workspace_init_v02_deferrals).
- Scenario B migration (split existing scaffold-onboard'd single-repo).
- `/repair-workspace` command.
- `core.hooksPath`-based tracked hook (survives clones).

### Schema versions
- Pairing manifest: 1.0
