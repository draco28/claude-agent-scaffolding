# Changelog

All notable changes to the scaffold plugin are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added — Phase A: plugin scaffold (2026-04-26)
- File tree at `scaffold/` with valid manifests, command stubs, library stubs, MCP skeleton, templates, and install script skeleton. Plugin loads in Claude Code without errors. No functional behavior yet — subsequent phases (B–J) implement capabilities.

### Added — Phase H: SessionStart hook (project context injection) (2026-04-27)
- `hooks-handlers/session-start.sh`: source-aware project-context emitter. Detects scaffold-managed repos via plugin-data presence (`sf_is_managed`); silently exits 0 on non-git dirs and unmanaged git repos. When managed, emits ~280 tokens via `additionalContext`: project name, branch, stack (with LLM tag if detected), current slice + phase + AC pass/total, last 3 memory entries newest-first, and a slash-command quick reference.
- **Source-awareness**: emits identically on `startup` / `clear` / `resume` / `compact` / missing source. Unlike ai-mentor's hook, scaffold has no per-session mutable state to reset — the source-aware behavior is purely "always emit, including on compact, so context survives compression."
- **Memory bank surfacing**: dual-path read for portability — tries `sqlite3` CLI first, falls back to `python3` with stdlib `sqlite3` module. Hook works without the MCP venv installed and without `sqlite3` CLI present (user's machine here didn't have the latter; Python fallback caught it).
- **Fail-open** at every layer: missing lib → exit 0; missing jq → exit 0; missing both DB readers → memory section shows "(memory bank empty — record via the scaffold-memory MCP tools)" without breaking context emission.
- `tests/test-session-start.sh`: 20 tests covering silent-exit cases (non-git, unmanaged), JSON validity, project-context fields (name / branch / stack / slice / phase / AC count), memory bank surfacing (with seeded test DB via Python), source-awareness across all four source values + missing-source defensive default.
- E2E verified on a real LLM-shaped repo with active slice + 2 memory entries: 283-token context output cleanly summarizes project state, with newest-first ordering preserved.
- Total scaffold test count: **195 tests** across 8 suites (30 state + 16 claude-md + 21 audit + 36 slice-gates + 23 governance + 28 mcp + 21 worktree + 20 session-start), all passing.

### Added — Phase G: worktree commands (2026-04-27)
- `lib/worktree.sh`: `sf_worktree_fork` wraps `git worktree add -b`, copies parent branch's `state.json` with `current_slice`, `slices`, and audit history reset (per-branch slice context starts fresh) but inherits `stack`, `llm_project`, `adr_counter`, `claude_md_managed` (these are per-repo concepts). Materializes `CLAUDE.md` inside the new worktree by running the generator from inside the new tree's cwd. `sf_worktree_list` parses `git worktree list --porcelain` and joins each block to its branch's `state.json` for current-slice + phase context.
- `/scaffold-worktree-fork <branch> [--path <p>]`: creates worktree at `../<repo>-<branch-slug>` by default (configurable via `--path`). Pre-flight refuses if branch already exists or target path is occupied. Slash-named branches (`feat/payments`) get the slug applied to the dir name (`-feat-payments`) and `__` substitution for the plugin-data branch dir.
- `/scaffold-worktree-list`: prints a markdown table of all worktrees with branch, current slice, phase, and last-updated timestamp. Worktrees that exist on disk but have no scaffold state show `(unmanaged)` so the user can spot which ones haven't been initialized.
- `tests/test-worktree.sh`: 21 tests across success path (10), refusal cases (3), `--path` support including slash-name slugging (3), and list rendering (5).
- E2E walkthrough: created parent repo with stack signal → `/scaffold-init` → `/slice-new` → `/scaffold-worktree-fork auth-flow-alt` → verified new worktree has `CLAUDE.md`, fresh state with parent's stack/adr_counter inherited but slice context cleared. `/scaffold-worktree-list` correctly showed both worktrees with their respective slice progress.
- Total scaffold test count: **175 tests** across 7 suites (30 state + 16 claude-md + 21 audit + 36 slice-gates + 23 governance + 28 mcp + 21 worktree), all passing.

### Added — Phase F: Python MCP server with semantic memory bank (2026-04-27)
- `mcp/memory.py`: per-repo SQLite store with three indexes — primary `memory` table, `memory_fts` (FTS5, always available via stdlib), `memory_vec` (sqlite-vec, optional). CRUD operations, `list_recent` with type/since filters, `search` with hybrid retrieval (FTS5 BM25 + vector cosine, weighted blend), idempotent migration via `IF NOT EXISTS`, fail-safe row parsing.
- `mcp/embed.py`: Ollama HTTP client using stdlib `urllib` only (no `requests` dependency). Returns `None` on any error so memory operations gracefully degrade to FTS5-only when Ollama is unavailable.
- `mcp/server.py`: FastMCP server exposing **10 MCP tools** — `record_decision`, `record_pattern`, `record_note`, `record_retrospective`, `recall`, `list_recent`, `get_by_id`, `update`, `delete`, `reindex`. Server initialization auto-creates DB schema and probes Ollama availability with a one-time stderr message.
- `mcp/run-server.sh`: launcher with **lazy venv install on first run** (resolves SPEC OQ-11). Detects current repo via `lib/repo.sh`, exports `SCAFFOLD_REPO_HASH` and `SCAFFOLD_REPO_BRANCH`, execs the server with the venv's Python.
- `scripts/install.sh`: bootstrap the Python venv. Prefers `uv` when available (fast, robust on Debian/Ubuntu where `python -m venv` may need `python3-venv` apt package), falls back to vanilla `python -m venv` otherwise. Defaults to `UV_NATIVE_TLS=true` to use the OS trust store — handles corporate-TLS-interception environments out of the box.
- `mcp/requirements.txt`: pinned to `fastmcp>=2.10` and `sqlite-vec>=0.1.6`.
- `tests/test-mcp.sh`: 28 Python unit tests via `unittest` covering CRUD, list_recent filters, FTS5 search behavior, hybrid search degradation paths, FTS5 query sanitization, embed module non-destructiveness, and vector path (skipped when sqlite-vec is missing). Pure stdlib so it runs without the venv installed.
- E2E verified: real MCP server launch over stdio successfully responded to `initialize` + `tools/list` (10 tools registered). Real Ollama-backed semantic recall round-trip on three decisions correctly ranked auth-related decision top for "how do we handle login sessions" and caching-related decision top for "database performance".
- One bug caught and fixed during E2E: single-FTS-only result returned `score=0` because BM25 normalization divides by an empty range. Fixed by special-casing single results to `score=1.0`.
- Removed stale empty subdir `mcp/memory/` from Phase A — the v1 spec called for a more granular module layout but the actual scope is small enough that the flat `mcp/{server,memory,embed}.py` is clearer.
- Total scaffold test count: **154 tests** across 6 suites (30 state + 16 claude-md + 21 audit + 36 slice-gates + 23 governance + 28 mcp), all passing.

### Added — Phase E: governance commands (ADR / changelog / runbook) (2026-04-27)
- `/adr-new <title>`: auto-numbers (4-digit zero-padded), slugs the title, writes `docs/adr/NNNN-<slug>.md` from the Nygard template. Increments `state.adr_counter` (counter unchanged on usage error). Per-repo numbering survives across worktrees.
- `/changelog <Type> <summary>` and `/changelog bump <version>`: in-place mutation of `CHANGELOG.md`. Append form locates `## [Unreleased]` → `### <Type>` and inserts a `- summary` bullet, creating the subsection if missing. Bump form rotates `[Unreleased]` to a new versioned heading while preserving the empty `[Unreleased]` heading for next time. Auto-creates `CHANGELOG.md` from template if missing.
- `/runbook-new <name>`: slugs the name, writes `docs/runbooks/<slug>.md` from SRE-style template with `{{failure_mode}}` and `{{date}}` substituted. Refuses to overwrite an existing runbook.
- `lib/changelog.sh`: `sf_changelog_ensure`, `sf_changelog_append`, `sf_changelog_bump`. Lives in its own file because the awk programs use single quotes for body delimiters, conflicting with the slash-command `bash -c '...'` pattern. Sourcing avoids the conflict.
- `sf_slug` promoted to `lib/repo.sh` (was inline in `lib/slice.sh`). Three callers (slice, ADR, runbook) now share it. `sf_slice_slug` becomes a thin alias for backward compatibility.
- `tests/test-governance.sh`: 23 tests across the three commands (file creation, slug correctness, counter increment, idempotent error paths, in-place CHANGELOG mutations including bump rotation, runbook overwrite refusal). Covers a discovered awk-quoting bug fixed by extracting to `lib/changelog.sh`.
- E2E walkthrough on a fresh git repo: 2 ADRs auto-number to 0001/0002, CHANGELOG accepts Added/Fixed entries then bumps to 0.1.0 with content correctly rotated under the new heading, runbook generates with template substitution.
- Total scaffold test count: **126 tests** across 5 suites (30 state + 16 claude-md + 21 audit + 36 slice-gates + 23 governance), all passing.

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
