# Changelog

All notable changes to the scaffold plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — Phase A: plugin scaffold (2026-04-26)
- File tree at `scaffold/` with valid manifests, command stubs, library stubs, MCP skeleton, templates, and install script skeleton. Plugin loads in Claude Code without errors. No functional behavior yet — subsequent phases (B–J) implement capabilities.

### Added — Phase D: slice workflow + 5-phase state machine (2026-04-27)
- `lib/slice.sh`: full slice state machine. Slug + numbering (`sf_slice_slug`, `sf_slice_format_number` with 2-digit-up-to-99 / 3-digit beyond, `sf_slice_format_id`, `sf_slice_next_number`); creation (`sf_slice_create` with `--force` for concurrent-slice override); AC parsing from spec files (`sf_slice_parse_acs` extracts `- [ ] AC-N: text` lines into JSON with `pending`/`passing` status); phase transitions (`sf_slice_phase_spec` / `_contract` / `_scaffold` / `_implement` / `_verify`) with strict gates and helpful error messages on refusal; verify actually runs the detected test command, captures `last_test_result`, and flips to `complete` on exit 0 or stays at `verify` otherwise.
- 8 slash commands wired:
  - `/slice-new <name> [--force]` — allocate next number on this branch, generate spec from template, set current.
  - `/slice-status` — pretty-print current slice phase + AC checklist + last verify + next-step suggestion per phase.
  - `/slice-list` — markdown table of all slices on branch.
  - `/slice-spec` — re-parse ACs from spec file, refresh state.
  - `/slice-contract` — gate-check ≥1 AC, advance phase. Prose body directs the agent to scaffold failing tests for each AC.
  - `/slice-scaffold` — gate-check prior phase, advance. Prose body directs Zone-1 boilerplate writing.
  - `/slice-implement` — gate-check prior=scaffold, advance. Prose body documents composition with ai-mentor (z2-build vs z2-decide vs z1).
  - `/slice-verify` — run tests, capture results, flip to complete or stay at verify with the failing-tests output snippet.
- `tests/test-slice-gates.sh`: 36 tests across slug/numbering, slice creation, AC parsing, phase gate transitions (including refusal cases), verify with mocked passing/failing test commands, and per-branch numbering isolation.
- E2E smoke test on a real fresh repo: `/scaffold-init` → `/slice-new auth-flow` → spec edit → `/slice-contract` → `/slice-implement` (correctly refused, asked for scaffold) → `/slice-scaffold` → `/slice-implement` → `/slice-verify` (mocked passing) → `/slice-status` showing `complete`. Full pipeline works.
- Total test count across the scaffold plugin now: **103 tests** (30 state + 16 claude-md + 21 audit + 36 slice-gates), all passing.

### Added — Phase C: project init, status, audit, CLAUDE.md commands (2026-04-27)
- `/scaffold-init`: bootstrap or onboard the current repo. Conservative + idempotent — only adds missing files (LICENSE/MIT, language-aware `.gitignore`, README skeleton, `docs/{adr,runbooks,slices}/`, generated `CLAUDE.md`). Detects existing `CLAUDE.md` and reports without overwriting; offers manual import / keep / replace via prose. Refuses outside a git repo.
- `/scaffold-status`: pretty-prints state file fields (project, hash, branch, stack, LLM flag, current slice + phase, slice count, ADR counter, last audit timestamp). Reports "not initialized" cleanly if no state exists.
- `/scaffold-audit`: 10 checks across README/License/Gitignore/ADRs/Runbooks/Slices/Changelog/Tests/LLM (evals + model card, only when `llm_project=true`). Markdown table output with ✓ / ⚠ / ⓘ / ✗ icons; summary line; exit 1 when any `fail` rows. `--save` flag writes `docs/AUDIT.md` and updates `state.audit_results_path`.
- `/scaffold-claude-md-edit personal|project`: seeds the requested source layer from template if missing, prints path and scope, advises rebuild step. Doesn't open `$EDITOR` (avoids TTY hand-off issues across Claude Code clients) — the prose offers an inline Read+Edit workflow instead.
- `/scaffold-claude-md-rebuild [--force]`: regenerates `<repo>/CLAUDE.md`. Detects manual edits via mtime-vs-footer-timestamp + 60s buffer; refuses to overwrite without `--force`. Backs up to `CLAUDE.md.bak` when forcing.
- `lib/audit.sh`: ten check functions emitting tab-separated rows (`category\tname\tstatus\tdetail`); `sf_audit_run` orchestrator; `sf_audit_render_md` produces markdown table; `sf_audit_summary` returns 1 on any fail.
- `templates/LICENSE.MIT.tmpl`: MIT license seed with `{{year}}` / `{{holder}}` substitution; holder pulled from `git config user.name`.
- `tests/test-audit.sh`: 21 tests across three fixture repos (empty / well-formed / LLM-shaped). All 67 tests across the suite (state 30 + claude-md 16 + audit 21) pass.
- E2E smoke test: simulated all 5 commands on a fresh git repo. Init → 7 files added across 3 dirs, CLAUDE.md generated with both layers; status → clean printout; audit → 7 pass/2 warn/1 info/0 fail; init re-run → idempotent no-op; claude-md-edit personal → seeded path + scope.

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
