# Changelog

All notable changes to scaffold-onboard documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [Unreleased]

### Added
- Plugin scaffold (Phase A of the build sequence).
- Phase B: lib/state.sh (state CRUD with atomic writes + lock file, 10 tests), lib/parser.sh (MASTER-SPEC.md three-primitive parser with seven validation rules, 13 tests), lib/render.sh (template substitution with `{{key}}` + `{{#if}}` blocks, 5 tests). 28 tests passing across 3 suites. macOS-specific adaptations: BSD awk uses `sub()` chains instead of gawk 3-arg `match()`; bash 3.2 uses parallel indexed arrays instead of `declare -A`.
