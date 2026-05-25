# workspace-init changelog

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
