# scaffold-onboard

Run-once project onboarding plugin for Claude Code and Codex. Walks you through 10 expert-role phases (~54 questions) to author `MASTER-SPEC.md`, then deterministically derives a `.claude/memory-bank/` (11 files), a tiered `CLAUDE.md` session-start router, a managed Codex section in `AGENTS.md`, and 5 (or 14 with `--full`) governance docs.

Composes with `ai-mentor` (cognitive mode), `architect-critic` (anti-sycophancy review), and `superpowers` (visual brainstorming + skills library) if installed — but works fully standalone.

## Install

```
/plugin marketplace add github:draco28/claude-agent-scaffolding
/plugin install scaffold-onboard@claude-agent-scaffolding
```

## Quick start

```
cd <your-new-project>
git init
> /onboard                              # ~30–45 min · authors MASTER-SPEC.md
> /scaffold-project                     # ~10s · derives memory-bank + CLAUDE.md
> check Claude/Codex workspace compatibility
> /scaffold-docs                        # ~10s · derives 5 governance docs
> /scaffold-docs --full                 # +9 governance docs (3 LLM-gated)
```

After that, install and use the companion `scaffold` plugin for slice-driven implementation work.

## Commands

| Command | What it does | Time |
|---|---|---|
| `/onboard` | Guided 10-phase conversation; produces `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md` | ~30–45 min |
| `/scaffold-project [--force]` | Derives `.claude/memory-bank/` (11 files) + `CLAUDE.md` + managed `AGENTS.md` section + `.claude/settings.json` | ~10s |
| `/scaffold-docs [--full] [--regenerate]` | Derives `docs/PRD.md`, `SRS.md`, `BACKLOG.md`, `PROJECT_PLAN.md`, `adr/0001-*.md` (`--full` adds 9 more) | ~10s |

## How it works

`MASTER-SPEC.md` is the **single source of truth**. Memory-bank and governance docs derive from it deterministically. Re-running a derive command after editing `MASTER-SPEC.md` regenerates derived files; live files (`05-active-context.md`, `06-progress.md`, `WORKFLOW.md`) are preserved. `AGENTS.md` is section-merged so user-written Codex instructions outside the scaffold markers are preserved.

The `checking-workspace-interoperability` skill acts as a workspace doctor for switching between Claude Code and Codex. It checks `.workspace/pairing.json`, additive routing keys, `.workspace/locks`, and the managed `AGENTS.md` section, and can repair missing non-breaking pieces.

The 10 phases mirror the ProjectPulse expert-role taxonomy: Foundation → Strategy → Domain & Data → Security → Architecture → UX → Implementation → DevOps → Quality → Operations. Each phase has 3–7 questions. Phase 1's project-class enum drives branching gates in later phases (UI vs DX, BE vs FE vs lib, LLM-eval vs not).

Soft composition with cross-cutting plugins is opportunistic — scaffold-onboard probes installed plugins at session start, caches results in `composition.json`, and emits hints / dispatches critic requests when relevant. See `docs/SPEC-scaffold-onboard.md` for the full design and `docs/PLAN-scaffold-onboard.md` for the implementation plan.

## Platforms

Linux and macOS. Windows is deferred (matches sibling plugins).

## Status

v0.1.0 — design spec at `docs/SPEC-scaffold-onboard.md`; implementation plan at `docs/PLAN-scaffold-onboard.md`.

## License

MIT — see `LICENSE`.
