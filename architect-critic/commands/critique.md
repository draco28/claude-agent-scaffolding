---
description: Run an architect-critic audit on a spec or plan
argument-hint: [path] [--close] [--model NAME] [--principles PATH] [--scope project|user]
---

# /critique

Invoke the **critiquing-spec** skill on the provided artifact. The skill body handles all logic:
path discovery, principles merging, codex detection, claude-self-audit, optional codex
fresh-frame, consolidation, sequential rebuttal, bookkeeping, summary emission. This slash
command is a thin wrapper — the work happens in the skill.

## Arguments

- `path` (optional) — artifact path; if omitted, the skill resolves via manifest fast-path,
  filename heuristics, or `AskUserQuestion` fallback. Never globs `*.md`.
- `--close` — request close-depth audit (claude-self-audit + codex fresh-frame). Default is
  shallow (claude-only).
- `--model NAME` — override codex model (respects user's `~/.codex/config.toml` by default).
- `--principles PATH` — override principles.md path.
- `--scope project|user` — for principle promotion during the audit run.

## Bridge

```bash
# Bridge $ARGUMENTS into env var so the skill can read it.
# See [[feedback_slash_command_dollar_n_bug]] — never use $1/$2 in command bodies.
export ARCHITECT_CRITIC_ARGS="$ARGUMENTS"
```

## Invoke

Now invoke the `critiquing-spec` skill, passing the arguments above via `$ARCHITECT_CRITIC_ARGS`.
