# Changelog

All notable changes to the scaffold plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — Phase A: plugin scaffold (2026-04-26)
- File tree at `scaffold/` with valid manifests, command stubs, library stubs, MCP skeleton, templates, and install script skeleton. Plugin loads in Claude Code without errors. No functional behavior yet — subsequent phases (B–J) implement capabilities.

### Added — Phase B: state, repo, claude-md libraries + tests (2026-04-26)
- `lib/repo.sh`: `sf_repo_root`, `sf_repo_remote_url`, `sf_repo_hash` (12-hex SHA-256 of remote-URL or path fallback), `sf_branch` with `_detached_<sha>` / `_unborn` / `_no_git` fallbacks, `sf_branch_safe` (sanitizes `/` for dir use), `sf_stack_detect` (python/node/rust/go), `sf_stack_detect_json`, `sf_llm_detect` (10+ signal sources), `sf_test_command`.
- `lib/state.sh`: `sf_data_dir`, `sf_project_dir`, `sf_state_dir`, `sf_state_path` path resolution; `sf_default_state` schema; fail-safe `sf_read_state`; atomic `sf_write_state_stdin`; `sf_state_get` / `sf_state_get_path` field reads; `sf_state_apply` (jq expression) and `sf_state_apply_typed` (with `$val` JSON injection) writers; `sf_init_state` (detects stack + LLM at init, idempotent); `sf_is_managed` predicate.
- `lib/claude-md.sh`: two-layer CLAUDE.md generator. `sf_seed_personal_defaults` and `sf_seed_project_layer` (idempotent template seeding with `{{var}}` substitution); `sf_generate_claude_md` (concatenation + footer timestamp); `sf_claude_md_footer_timestamp` parser; `sf_claude_md_manually_edited` (mtime vs footer comparison with 60s buffer); honors `claude_md_managed=false` opt-out.
- `tests/test-state.sh`: 30 tests covering 17 repo helpers + 13 state helpers (including detached HEAD, unborn repos, multi-stack detection, malformed state recovery, multi-branch state isolation).
- `tests/test-claude-md.sh`: 16 tests covering path resolution, template seeding, generation order, footer timestamp, manual-edit detection, and opt-out behavior.
- One bug found and fixed during testing: `sf_state_get_path` uses jq `// empty` which incorrectly treats boolean `false` as "no value", defeating the `claude_md_managed=false` opt-out check. Fixed by reading the boolean directly in `sf_generate_claude_md` without the lossy default.

All 46 tests pass on `bash tests/test-state.sh && bash tests/test-claude-md.sh`.

## [0.1.0] — planned

Initial release target. Phases A–J build sequence:

- **A:** plugin scaffold *(this release)*
- **B:** state, repo-detection, CLAUDE.md generator libraries + tests
- **C:** init / audit / status / claude-md-edit / claude-md-rebuild commands (Capabilities 1, 4)
- **D:** slice workflow with phase gates (Capability 2)
- **E:** governance commands — adr-new / changelog / runbook-new (Capability 3)
- **F:** Python MCP server with semantic memory (sqlite + sqlite-vec + Ollama)
- **G:** worktree fork / list commands
- **H:** SessionStart hook (source-aware project context)
- **I:** E2E smoke test on real repos
- **J:** v1.0.0 ship — bump version, register in marketplace, push
