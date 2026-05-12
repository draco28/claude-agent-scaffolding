# Changelog

All notable changes to scaffold-onboard documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [Unreleased]

### Added
- Plugin scaffold (Phase A of the build sequence).
- Phase B: lib/state.sh (state CRUD with atomic writes + lock file, 10 tests), lib/parser.sh (MASTER-SPEC.md three-primitive parser with seven validation rules, 13 tests), lib/render.sh (template substitution with `{{key}}` + `{{#if}}` blocks, 5 tests). 28 tests passing across 3 suites. macOS-specific adaptations: BSD awk uses `sub()` chains instead of gawk 3-arg `match()`; bash 3.2 uses parallel indexed arrays instead of `declare -A`.
- Phase C: phases.yaml (10 phases, 56 questions, branching gates), MASTER-SPEC.md.tmpl + EXECUTIVE-SUMMARY.md.tmpl, /onboard command with conversational protocol body, state-machine helpers (sf_state_advance_phase, sf_state_gate_passes, sf_state_mode), phases.yaml reader helpers (sf_phases_questions_for, sf_phases_question_text, sf_phases_question_required, sf_phases_question_gate), sf_master_spec_init, sf_master_spec_update_phase. End-to-end scripted test produces a validated MASTER-SPEC.md from synthetic answers. ~46 tests across 3 suites.
- Phase D: 11 memory-bank templates (00-08 derived/live + index + WORKFLOW static), CLAUDE.md template (Tier 0 + branch routing + plugin awareness via composition.json), .claude/settings.json template, lib/memory-bank.sh with sf_memory_bank_derive + sf_claude_md_generate + sf_claude_settings_generate (live-file preservation + --force override + composition-aware {{#if}} sections), /scaffold-project command. Consistency fix backported to sf_master_spec_update_phase. ~22 tests in test-memory-bank.sh. Cumulative ~68 tests across 4 suites.
