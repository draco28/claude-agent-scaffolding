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
| `/defer` | Files a non-blocking gap as a project-repo GitHub issue + records a lean `[TD]` index pointer. |
| `/flip-adr` | Flips an ADR `Status: Proposed` → `Accepted` and appends an empirical-validation section. |

## Skills (auto-invoke)

The 12 skills auto-invoke on natural-language triggers — slash commands are thin `Skill(...)` dispatchers:

- `planning-vertical-slice` — author slice spec + work-item breakdown from R1/R3 (+ opt-in `review_gate` at the spec moment)
- `executing-work-item` — TDD-loop implementer body (subagent system prompt)
- `implementation-checking` — mcrule + gate enforcement
- `closing-vertical-slice` — demo verify + report harvest + slice retrospective (+ opt-in `review_gate` at slice close)
- `verifying-spec-citations` — resolve file/REQ-ID/signature citations in a draft slice spec
- `handing-off-session` — `.workspace/handoffs/` escape-valve writer
- `recording-architecture-decision` — ADR authoring
- `flipping-adr-status` — flip an ADR `Proposed` → `Accepted` + empirical validation
- `deferring-work-item` — file a non-blocking gap as a GitHub issue + `[TD]` pointer
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
- **architect-critic** v0.2+ — `Skill(architect-critic:critiquing-spec)` at slice-spec close, sprint retrospective, ADR draft (filesystem probe, no file IPC). v0.3+ additionally unlocks the opt-in async `review_gate` (see Configuration).
- **ai-mentor** v2.0+ — `Skill(ai-mentor:grill-me)` at slice-plan close, mid-slice stuck-state, sprint retrospective

## Configuration

- **`review_gate`** (manifest `.workspace/pairing.json` field; default `off`) — opt-in architect-critic review gate at slice/spec close. Values:
  - `off` — today's behavior exactly (synchronous review at the §7 gates).
  - `slice_close` — at slice close, dispatch the close-depth audit as an **async background job** (dispatch-and-defer) instead of blocking the ceremony.
  - `spec_close` — same at the spec-author moment; **upgrades** the default author-depth audit to a close-depth Codex adversary audit (async exists only at close depth).
  - `both` — both attach points.

  When on, the gate dispatches via `Skill(architect-critic:critiquing-spec)` (`async=true`), records the job handle, surfaces a usage-consumption warning + the `/critique-jobs resume <id>` hint, and proceeds without blocking — the operator resumes on their own schedule. Requires architect-critic **v0.3+**; with v0.2 it falls back to the synchronous review with a warning. Resolved by `lib/review_gate.sh` (`sd review_gate_resolve`).

## Pointers

- Spec: [`docs/SPEC-scaffold-dev.md`](../docs/SPEC-scaffold-dev.md)
- Plan: [`docs/PLAN-scaffold-dev.md`](../docs/PLAN-scaffold-dev.md)
- Changelog: [`CHANGELOG.md`](./CHANGELOG.md)
- Sibling plugins: [`workspace-init`](../workspace-init/), [`scaffold-onboard`](../scaffold-onboard/)

## Platforms

Linux and macOS. Windows deferred (matches sibling plugins).

## Status

v0.8.0 — 2026-06-18. Latest: #39 Phase B opt-in async `review_gate` at slice/spec close (see Configuration). Initial release was v0.1.0 (2026-05-25); the v0.x line has deepened the skill-first structure and cross-plugin composition as usage data accumulated.

## License

MIT — see [`../LICENSE`](../LICENSE).
