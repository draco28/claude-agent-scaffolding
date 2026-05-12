# scaffold-onboard

Run-once project onboarding plugin for Claude Code. Walks you through 10 expert-role phases (~54 questions) to author `MASTER-SPEC.md`, then deterministically derives a `.claude/memory-bank/` (11 files), a tiered `CLAUDE.md` session-start router, and 5 (or 14 with `--full`) governance docs.

Composes with `ai-mentor` (cognitive mode), `architect-critic` (anti-sycophancy review), and `superpowers` (visual brainstorming) if installed — but works fully standalone.

## Commands

- `/onboard` — guided 10-phase conversation; produces `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md`
- `/scaffold-project` — derives `.claude/memory-bank/` (11 files) + `CLAUDE.md` from `MASTER-SPEC.md`
- `/scaffold-docs [--full]` — derives `docs/PRD.md`, `SRS.md`, `BACKLOG.md`, `PROJECT_PLAN.md`, `adr/0001-*.md` (`--full` adds 9 more)

## Status

v0.1.0 — design spec at `docs/SPEC-scaffold-onboard.md`; implementation plan at `docs/PLAN-scaffold-onboard.md`.

## Platforms

Linux and macOS. Windows deferred (same as sibling plugins).

## License

MIT — see `LICENSE`.
