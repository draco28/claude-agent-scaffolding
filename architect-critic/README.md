# architect-critic

Anti-sycophancy reviewer plugin for Claude Code. `/critique` runs a claude-self-audit + (optionally) a codex fresh-frame audit, consolidates findings, and presents challenges with the T=4 concession scoring rubric (1–5 against the bar; concedes only at ≥4). Recurring patterns are surfaced as candidates to promote into your user-global `principles.md`.

Composes with `scaffold-onboard` via file-based JSON IPC: at Phase 5/7 recap and at MASTER-SPEC close, scaffold-onboard's `/onboard` writes a request envelope to inbox, invokes `/critique` synchronously, and reads the response from outbox. Also usable standalone — `/critique` in any session synthesizes an envelope from defaults.

## Commands

- `/critique [--phase N] [--depth premise-audit|close] [--spec PATH]` — primary audit entry
- `/critique-list [--limit N]` — show recent runs + pending requests
- `/promote-principle "<text>" [--scope user|project]` — manually promote a principle
- `/principles-list` — render the merged principle set the next /critique would see

## Status

v0.1.0 — initial release.

## Platforms

macOS and Linux. Windows deferred (matches sibling plugins).

## License

MIT
