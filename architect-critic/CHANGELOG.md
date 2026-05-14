# Changelog

## [Unreleased]

### Added
- **Phase A — plugin scaffold:** plugin.json manifest, LICENSE (MIT), README skeleton, CHANGELOG, 4 command stubs (`/critique`, `/critique-list`, `/promote-principle`, `/principles-list`), SessionStart hook stub, `lib/_helpers.sh` (logging + jq-then-mv guard + lock-file pattern), 9 empty lib stubs ready for Phase B–E, `templates/principles.md` seed (D3 stub-with-examples per SPEC §6.4), test infrastructure (`tests/_helpers.sh` with assert_*, setup_tmp_repo, setup_mock_codex), mock-codex PATH-override fixture + 3 canned codex payloads + tiny MASTER-SPEC fixture.
