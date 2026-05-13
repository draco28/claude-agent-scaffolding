# Changelog

All notable changes to scaffold-onboard documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [0.1.0] — 2026-05-14

### Added
- Plugin scaffold (Phase A) — manifest, LICENSE, README, CHANGELOG, command stubs, hook + lib skeletons, test helpers.
- lib/state.sh, lib/parser.sh, lib/render.sh (Phase B) — state CRUD with atomic writes + lock file, MASTER-SPEC.md parser with three primitives + 7 validation rules, template substitution with `{{key}}` + `{{#if}}` blocks.
- phases.yaml (10 phases, ~54 questions, branching gates), MASTER-SPEC + EXECUTIVE-SUMMARY templates, /onboard command with conversational protocol body, state advance + gate evaluation + mode detection + phases.yaml reader (Phase C).
- 11 memory-bank templates (00–08, index, WORKFLOW), CLAUDE.md template (Tier 0 + branch routing + plugin awareness), .claude/settings.json template, lib/memory-bank.sh with derive + CLAUDE.md generation + live-file preservation + --force, /scaffold-project command (Phase D).
- 14 governance doc templates (5 default + 9 --full, 3 LLM-project-gated), lib/docs.sh with default + --full derivation + --regenerate override, /scaffold-docs command (Phase E).
- lib/compose.sh with probe-path detection for ai-mentor / architect-critic / superpowers, composition.json caching with user-override toggles preserved across refresh, sf_compose_set_override input-validated setter, SessionStart hook (source-aware: refresh on startup/clear, preserve on resume/compact), mentor + brainstorming hint emitters keyed to Phase 5/7, architect-critic file-based handshake per SPEC §8.3 (request envelope build + response reader with polling timeout) (Phase F).
- End-to-end coverage on fresh + existing repos, resume after interruption, and cross-cutting composition mocked (Phase G TG.1–TG.4); README polish with Install + Quick start + Commands table (TG.5); hardening (TG.6): jq-then-mv writes guarded against partial failure, critic request_id seeded with PID+RANDOM entropy to prevent same-second collisions, file-lock protection on composition.json writes via sf_compose_lock_acquire/release with polling timeout.
- 163 tests across 7 bash test suites (state 23, parser 13, render 10, memory-bank 22, docs 23, compose 31, e2e 41).

### Composition
- Composes with `ai-mentor`, `architect-critic`, `superpowers`. Works standalone if any are absent.
