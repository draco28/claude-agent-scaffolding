# ai-mentor

Cognitive-partner Claude Code plugin. Replaces the fragile `pair-program` plugin with **mechanical enforcement** of spotter mode.

## What it does

The plugin treats two kinds of work differently:

- **Curve 1** (capped payoff — boilerplate, glue, mechanical tasks): AI does it for you. No friction.
- **Curve 2** (uncapped payoff — decisions, architecture, learning): AI is a *spotter* — it adds friction so you do the rep yourself.

A `PreToolUse` hook physically blocks `Edit` / `Write` / `NotebookEdit` when you're in Curve 2 mode, unless you signal an override. State lives in `~/.claude/ai-mentor/state.json`.

## Two sub-modes for Curve 2

| Mode | Use case | Hook unblocks when |
|---|---|---|
| `/z2-decide` | Daily/work coding — you make the decisions, AI implements | You run `/locked` to signal decisions are finalized |
| `/z2-build` | Personal/learning — you type the code yourself, AI hints | Inline override phrases ("show me", "skip to solution") in your message |

## Slash commands

| Command | Effect |
|---|---|
| `/z1` | Pure delegation — hook is no-op. AI works freely. |
| `/z2-decide` | Curve 2 / decide mode — block edits until `/locked`. |
| `/z2-build` | Curve 2 / build mode — block edits unless inline override. |
| `/locked` (alias `/implement`) | Decisions locked; flip to Z1 and let AI implement. |
| `/quiz l1`..`l4` | Socratic quiz mode at depth (high-school → college → exec → adversarial). |
| `/quiz off` | Exit quiz mode. |
| `/eli10` | Explain Like I'm 10 — repeatable for further simplification. |
| `/fool` | Beginner's-mind mode — no-jargon ground-truth explanations. |

## Override grammar (in `/z2-build`)

Phrases in your most recent message that unblock the hook for the next edit:

- `z1`, `just write it`, `just do it`
- `skip to solution`, `show me`, `just show me the code`
- `/locked` (treat as one-shot transactional unblock)

## Install

```
/plugin marketplace add github:<user>/claude-agent-scaffolding
/plugin install ai-mentor@claude-agent-scaffolding
```

## Subagent scope

The PreToolUse hook fires on the main session's edits, not on subagent tool calls. Treat zone enforcement as a discipline on the main agent. In `/z2-decide` or `/z2-build`, the main agent's protocol already discourages spawning implementation subagents that would bypass the spotter; if you genuinely need one, run `/z1` or `/locked` first. See SKILL.md for the full rationale.

## Platforms

**Linux and macOS only.** Hook scripts are bash + `jq`; no PowerShell / `.bat` flavor ships. Windows support is deferred (would require porting `lib/state.sh` and the two hook handlers). Track at SPEC `B3`.

## Dependencies

- bash (POSIX)
- `jq` (for parsing the transcript file and state JSON)

If `jq` is missing, the hook fails open — edits are allowed but enforcement is disabled. The plugin never bricks your Claude Code session.

## Tests

`bash ai-mentor/tests/test-hooks.sh` runs 28 hook regression tests in isolation (tempfile state, never touches your real plugin data). See `tests/README.md` for details.

## State location

`${CLAUDE_PLUGIN_DATA}/state.json` (resolves to `~/.claude/plugins/data/ai-mentor-claude-agent-scaffolding/state.json` on most installs). Survives plugin updates. If `${CLAUDE_PLUGIN_DATA}` is unavailable in the hook context, falls back to `~/.claude/ai-mentor/state.json`. State resets to `ambient` on `startup` and `clear` SessionStart sources; preserved through `resume` and `compact`.

## License

MIT — see [`LICENSE`](./LICENSE).
