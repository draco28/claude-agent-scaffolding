# Agent-Driven Scaffold Ecosystem — program home

Self-contained home for the **agent-driven refactor program** (settled 2026-06-01, Option C): make agent-driven the first-class workflow across `workspace-init` + `scaffold-onboard` + `scaffold-dev`, reserve bash for non-reasoning facts, and drive the GitHub backlog to **zero**. Kept separate from the older one-off specs in `docs/` so the program docs don't get jumbled with stale material.

## Layout

| Path | What |
|---|---|
| [`SPEC-agent-driven-program.md`](SPEC-agent-driven-program.md) | **The program spec** — north star, the 3 root anti-patterns, the 6 sub-specs (SS-1..SS-6), the issue ledger → zero backlog, open questions. **Start here.** |
| [`specs/`](specs/) | One file per sub-spec. |
| [`handoffs/`](handoffs/) | Session handoffs for this program. |

## Sub-specs

| Sub-spec | File | Status | Closes |
|---|---|---|---|
| **SS-1** memory-bank ownership + single-point cadence | [`specs/SS-1-memory-bank-cadence.md`](specs/SS-1-memory-bank-cadence.md) | design-locked | #45 |
| SS-2 turn synthesis on + verify + post-derivation review | _(not yet written)_ | planned | #42, #50, #49 |
| SS-3 agent-synthesized resumable onboarding | _(not yet written)_ | planned | #51, #49 |
| SS-4 agent-review of verification seams | _(not yet written)_ | planned | #7, #5, #48F, #52 |
| SS-5 Codex implementer/synthesizer backend | _(not yet written)_ | planned | #47 |
| SS-6 standalone cleanup to zero | _(not yet written)_ | planned | #8,#9,#6,#10,#37,#38,#39,#48*,#53 |

## Handoffs

| File | Picks up |
|---|---|
| [`handoffs/2026-06-02-ss1-ready-to-build.md`](handoffs/2026-06-02-ss1-ready-to-build.md) | SS-1 implementation (writing-plans → build) |

## Convention

- New sub-spec → `specs/SS-N-<topic>.md`, registered in the program spec §5/§6 and in the table above.
- New handoff → `handoffs/YYYY-MM-DD-<topic>.md`.
- Older/stale one-off specs stay in `docs/` (not moved here).
