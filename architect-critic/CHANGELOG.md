# Changelog

## [Unreleased]

### Added
- **Phase A — plugin scaffold:** plugin.json manifest, LICENSE (MIT), README skeleton, CHANGELOG, 4 command stubs (`/critique`, `/critique-list`, `/promote-principle`, `/principles-list`), SessionStart hook stub, `lib/_helpers.sh` (logging + jq-then-mv guard + lock-file pattern), 9 empty lib stubs ready for Phase B–E, `templates/principles.md` seed (D3 stub-with-examples per SPEC §6.4), test infrastructure (`tests/_helpers.sh` with assert_*, setup_tmp_repo, setup_mock_codex), mock-codex PATH-override fixture + 3 canned codex payloads + tiny MASTER-SPEC fixture.
- **Phase B — state + principles + inbox (78 tests):**
  - `lib/state.sh` (35 tests): all 9 `ac_state_*` functions; lock-protected writes via `ac_guarded_jq_write`; recent_runs cap-20 trimming; full state.json schema per SPEC §6.3.
  - `lib/principles.sh` (22 tests): comment-strip handles both headers AND example comments per SPEC §6.4; trailing `[promoted ...]` annotation strip; 4-source compose with absent-source graceful degradation; BSD awk `sub()` chains for portability.
  - `lib/inbox.sh` (21 tests): all 8 ordered ERROR validation rules per SPEC §6.1; warning paths for missing principles file + null project_class; rule 6 correctly bypassed for `master-spec-full` target type.
- **Phase C — slash command bodies (103 tests cumulative):**
  - `/critique` (commands/critique.md): envelope synthesis from defaults (manual mode) + inbox-read (programmatic mode) + arg overrides (`--phase`, `--depth`, `--spec`) + validation via `ac_inbox_validate`. Audit pipeline stubbed pending Phase D.
  - `/critique-list`: jq-sliced LIMIT enforcement (no `tac`, no subshell trap); renders 7 columns including cost_usd; separate in_flight section.
  - `/promote-principle`: validates ≤200-char single-line text; `--scope user|project` routing; uses `ac_guarded_jq_write` for state.json writes; ERROR exit when scope=project and no memory-bank.
  - `/principles-list`: delegates to `ac_principles_compose`; renders 4-section composition; "(empty)" surface when principles.md absent.
  - `test-commands.sh` (25 assertions across 12 PLAN scenarios): extract-bash-from-markdown approach exercises actual command bodies, not lib internals.
