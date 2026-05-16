# architect-critic

Anti-sycophancy reviewer plugin for Claude Code. `/critique` runs a claude-self-audit + (optionally) a codex fresh-frame audit, consolidates findings, and presents challenges with the T=4 concession scoring rubric (1–5 against the bar; concedes only at ≥4). Recurring patterns are surfaced as candidates to promote into your user-global `principles.md`.

Composes with `scaffold-onboard` via file-based JSON IPC: at Phase 5/7 recap and at MASTER-SPEC close, scaffold-onboard's `/onboard` writes a request envelope to inbox, invokes `/critique` synchronously, and reads the response from outbox. Also usable standalone — `/critique` in any session synthesizes an envelope from defaults.

## Commands

- `/critique [--phase N] [--depth premise-audit|close] [--spec PATH]` — primary audit entry
- `/critique-list [--limit N]` — show recent runs + pending requests
- `/promote-principle "<text>" [--scope user|project]` — manually promote a principle
- `/principles-list` — render the merged principle set the next /critique would see

## Worked example — manual critique

From any project directory with a `MASTER-SPEC.md` (or pass `--spec PATH`):

```
> /critique
```

The audit runs in-session: claude-self-audit composes principles from your user-global
`${CLAUDE_PLUGIN_DATA}/architect-critic/principles.md` + (if onboarded) your in-flight
MASTER-SPEC + memory-bank patterns, then audits your spec against them. At `close` depth
(default), codex is also dispatched as a fresh-frame second adversary; their findings are
merged into one envelope of `{challenges, gaps, divergences}`.

Then for each challenge, you rebut interactively:

```
[premise] Phase 5.2 lacks a fallback strategy for codex unavailability
  refs: Phase 5.2
  Your response (accept | edit | note | <rebuttal>): graceful degradation is documented in §10
  → That doesn't address it (score=2). The challenge stands.
  Your response (accept | edit | note | <rebuttal>): accept
  → recorded as: accept
```

The 1–5 rubric scores your rebuttals (1=bare contradiction, 2=cite-self, 3=partial address,
4=material new info, 5=premise invalidated). Concession at ≥4 (T=4 firm).

If a pattern emerges across recent runs, the critic offers to promote it:

```
I noticed a pattern across recent runs:
  "Every state-change operation needs a documented rollback"
Add to principles.md? [y]es / [n]o / [e]dit:
```

## Cost

Each `close`-depth audit dispatches codex (~$0.05–0.20 per run depending on spec size).
Per-run cost prints after the rebuttal cycle:

```
~$0.012 spent on this audit (codex: $0.012, claude-self: $0)
```

Cumulative tracking lives in `state.json.recent_runs[].cost_usd`; surfaced as a column in
`/critique-list`. No soft cap or budget UX in v0.1.0 (deferred per SPEC OQ-3).

## Composition

- **Standalone**: `/critique` works in any session with no other plugins installed. codex
  is optional — if the `codex` CLI isn't on PATH, the audit gracefully degrades to
  claude-only.
- **With `scaffold-onboard`**: at Phase 5/7 recap and at MASTER-SPEC close, `/onboard`
  writes a request envelope to `${CLAUDE_PLUGIN_DATA}/architect-critic/inbox/` and invokes
  `/critique` synchronously via the `SlashCommand` tool. The response is read from outbox.
  Both plugins ship together in the `claude-agent-scaffolding` marketplace.

## Configuration

### Codex CLI timeout

`lib/codex.sh` dispatches codex as a background subprocess using a portable bash-only
timeout (background subshell + kill — no dependency on GNU `timeout(1)` or `gtimeout`).

Default timeout: **180 seconds**.

Override via environment variable:

```bash
export ARCHITECT_CRITIC_CODEX_TIMEOUT=60   # shorter timeout for slow networks
```

On any codex failure (absent binary, timeout, non-zero exit, malformed JSON output),
`/critique` falls back to claude-only with a warning and sets `adversaries_used=["claude"]`.

## Status

v0.1.0 — initial release.

## Platforms

macOS and Linux. Windows deferred (matches sibling plugins).

## See also

- Design spec: [`docs/SPEC-architect-critic.md`](../docs/SPEC-architect-critic.md)
- Implementation plan: [`docs/PLAN-architect-critic.md`](../docs/PLAN-architect-critic.md)
- Counterparty IPC contract: [`docs/SPEC-scaffold-onboard.md`](../docs/SPEC-scaffold-onboard.md) §8.3

## License

MIT
