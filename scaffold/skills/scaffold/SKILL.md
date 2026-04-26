---
name: scaffold
description: Project-level workflow plugin. Bootstraps and audits repos; runs slice-driven 5-phase workflow with strict gates; manages living governance docs (ADRs, CHANGELOG, runbooks); maintains a per-repo memory bank with semantic search.
when_to_use: Load when the user invokes any /scaffold-*, /slice-*, /adr-new, /changelog, or /runbook-new command, or asks about project state, slice progress, audit gaps, ADRs, runbooks, decisions, patterns, slice retrospectives, memory bank, worktree forking, or how scaffold composes with ai-mentor.
version: 0.1.0
---

# scaffold — Project-Level Workflow Plugin

> **Build status:** v0.1.0 (Phase A scaffold). The plugin's file tree is in place but most slash commands are stubs that report "not yet implemented." Capability rollout follows the build sequence in `docs/SPEC-scaffold.md §14`.

## What this plugin does

Four capabilities + a memory bank. See full spec at `docs/SPEC-scaffold.md`.

| # | Capability | Status |
|---|---|---|
| 1 | Project init / audit | Phase C (pending) |
| 2 | Slice workflow with strict 5-phase gates | Phase D (pending) |
| 3 | Living governance (ADR / CHANGELOG / runbook) | Phase E (pending) |
| 4 | Personal-defaults + 2-layer CLAUDE.md, materializes in worktrees | Phase C (pending) |
| — | Memory bank MCP server (semantic search via Ollama + sqlite-vec) | Phase F (pending) |

## Composition with ai-mentor

The two plugins are designed to compose without overlap. **Spec authoring and scaffold operations are Curve 1** (mechanical, template-driven) — run them in `/z1` or `ambient`. **AC capture from Socratic discussion is Curve 2/decide** — `/z2-decide`, `/locked`, then `/slice-contract`. **Implementation work** depends on user's mode: side project / learning → `/z2-build`; daily work where decisions are already locked → `/z1`.

If a scaffold operation is blocked by ai-mentor's hook (you're in zone=2 and the command wants to write files), run `/z1` or `/locked` first — scaffold's spec-authoring commands are mechanical; they're meant to run in Curve 1.

## State partitioning (worktree-safe)

All mutable state lives in `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/`, outside the working tree. Worktrees of the same repo share the memory bank; per-branch state is isolated under `branches/<branch>/state.json`. The plugin **never** commits agent state to the repo. Only artifact files (slice specs, ADRs, runbooks, CHANGELOG) are committed.

## Detailed reference (loaded on demand)

For each capability's detailed behavior — phase gate logic, audit checklist, slash command contracts, MCP tool semantics — see `docs/SPEC-scaffold.md` §5.1 through §5.6.
