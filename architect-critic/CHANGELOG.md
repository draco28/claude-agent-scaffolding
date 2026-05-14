# Changelog

## [Unreleased]

### Added
- **Phase A — plugin scaffold:** plugin.json manifest, LICENSE (MIT), README skeleton, CHANGELOG, 4 command stubs (`/critique`, `/critique-list`, `/promote-principle`, `/principles-list`), SessionStart hook stub, `lib/_helpers.sh` (logging + jq-then-mv guard + lock-file pattern), 9 empty lib stubs ready for Phase B–E, `templates/principles.md` seed (D3 stub-with-examples per SPEC §6.4), test infrastructure (`tests/_helpers.sh` with assert_*, setup_tmp_repo, setup_mock_codex), mock-codex PATH-override fixture + 3 canned codex payloads + tiny MASTER-SPEC fixture.
- **Phase B — state + principles + inbox (78 tests):**
  - `lib/state.sh` (35 tests): all 9 `ac_state_*` functions; lock-protected writes via `ac_guarded_jq_write`; recent_runs cap-20 trimming; full state.json schema per SPEC §6.3.
  - `lib/principles.sh` (22 tests): comment-strip handles both headers AND example comments per SPEC §6.4; trailing `[promoted ...]` annotation strip; 4-source compose with absent-source graceful degradation; BSD awk `sub()` chains for portability.
  - `lib/inbox.sh` (21 tests): all 8 ordered ERROR validation rules per SPEC §6.1; warning paths for missing principles file + null project_class; rule 6 correctly bypassed for `master-spec-full` target type.
