# scaffold-dev

Sprint-driven orchestrator-implementer workflow plugin for dual-repo workspaces. Consumes the R1/R2/R3 contract emitted by `scaffold-onboard` (Phase → Sprint → Vertical Slice roadmap, machine-checkable rules, `auto:`/`user:` demo criteria) and drives slice-by-slice implementation via Claude Code's custom `implementer-agent` subagent or Codex worker-style handoff prompts.

Replaces `scaffold` v1.0.0 (deprecated). Third in the chain: `workspace-init` → `scaffold-onboard` → **`scaffold-dev`**.

## Install

```
/plugin marketplace add github:draco28/claude-agent-scaffolding
/plugin install scaffold-dev@claude-agent-scaffolding
```

## Quick start

```
cd <your-paired-ai-workspace>
> /orchestrate                          # sprint-level driver — plans slices, dispatches implementers, closes slices + sprint
> /work-item VS-1.1                     # explicit single-work-item dispatch (orchestrator → implementer-agent → report)
> /impl-check                           # run mcrule + verify gates against current slice
> /handoff "stuck on X — next session resume here"   # escape valve to .workspace/handoffs/
```

## Commands

| Command | What it does |
|---|---|
| `/orchestrate` | Sprint-level driver: plans next slice, dispatches implementer subagent per work item, runs verify gates, harvests reports, writes slice + sprint retrospectives. |
| `/work-item <VS-id>` | Single-work-item dispatch — orchestrator invokes `implementer-agent` subagent with a handoff doc; subagent returns structured JSON + `report.md`. |
| `/impl-check` | Runs R2 mcrule enforcement (banned_imports, coverage_floor, style_invariants, required_pattern) + verify gates (tests, demo criteria). |
| `/handoff` | Writes a session-boundary handoff markdown to `.workspace/handoffs/` for resume across compaction or clear. |

## Skills (auto-invoke)

The 9 skills auto-invoke on natural-language triggers — slash commands are thin `Skill(...)` dispatchers:

- `planning-vertical-slice` — author slice spec + work-item breakdown from R1/R3
- `executing-work-item` — TDD-loop implementer body (subagent system prompt)
- `implementation-checking` — mcrule + gate enforcement
- `closing-vertical-slice` — demo verify + report harvest + slice retrospective
- `handing-off-session` — `.workspace/handoffs/` escape-valve writer
- `recording-architecture-decision` — ADR authoring
- `appending-changelog-entry` — Keep-a-Changelog append
- `authoring-runbook` — operational runbook authoring
- `writing-sprint-retrospective` — sprint-close retrospective + slice harvest

## How it works

The **orchestrator** (you, in the main session) drives slice planning and dispatches one **implementer** per work item. In Claude Code, the implementer is the custom subagent type `scaffold-dev:implementer-agent`. In Codex, v0 uses a worker-style prompt that embeds the same `executing-work-item` contract and the absolute `handoff.md` path. If automated worker dispatch is unavailable, the handoff is self-contained and can be pasted into a fresh Claude or Codex session. The implementer pre-flight-checks the handoff for gaps, runs the TDD loop per acceptance criterion, verifies, authors `report.md`, stages changes (never commits), and returns structured JSON.

If a session boundary hits mid-slice, `/handoff` writes a resumable markdown to `.workspace/handoffs/` — the next session reads it via `handing-off-session` and picks up cleanly. Volatile scaffold state uses lock/provenance helpers under `.workspace/locks` so Claude and Codex can switch without silently trampling active cursors.

The **R2 machine-checkable rules** (from `.claude/memory-bank/03-code-patterns.md`) are enforced by `implementation-checking` at slice close. The **R3 demo criteria** (literal U+2192 arrow grammar from `ROADMAP.md`) gate slice acceptance via `closing-vertical-slice`.

## Composition

- **workspace-init** v0.1+ — pairing manifest consumed for artifact routing (slice specs, ADRs, handoffs per `routing.*` table); single-repo fallback preserved
- **scaffold-onboard** v0.2+ — R1 hierarchy, R2 mcrules, R3 demo criteria consumed
- **architect-critic** v0.2+ — `Skill(architect-critic:critiquing-spec)` at slice-spec close, sprint retrospective, ADR draft (filesystem probe, no file IPC)
- **ai-mentor** v2.0+ — `Skill(ai-mentor:grill-me)` at slice-plan close, mid-slice stuck-state, sprint retrospective

## Pointers

- Spec: [`docs/SPEC-scaffold-dev.md`](../docs/SPEC-scaffold-dev.md)
- Plan: [`docs/PLAN-scaffold-dev.md`](../docs/PLAN-scaffold-dev.md)
- Changelog: [`CHANGELOG.md`](./CHANGELOG.md)
- Sibling plugins: [`workspace-init`](../workspace-init/), [`scaffold-onboard`](../scaffold-onboard/)

## Platforms

Linux and macOS. Windows deferred (matches sibling plugins).

## Status

v0.1.0 — initial release, 2026-05-25. v0.x polish pass anticipated to deepen skill-first structure once usage data accumulates.

## License

MIT — see [`../LICENSE`](../LICENSE).
