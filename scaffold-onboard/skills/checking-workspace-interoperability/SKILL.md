---
name: checking-workspace-interoperability
description: Check or repair a workspace-init AI workspace so Claude Code and Codex can switch safely mid-project. Use this when the user asks "can I switch between Claude and Codex here?", "check Codex compatibility", "repair AGENTS.md", "make this workspace Codex-ready", "workspace doctor", or "Claude/Codex interoperability check". Validates `.workspace/pairing.json`, additive routing keys, `AGENTS.md` managed Codex section, and `.workspace/locks`; with explicit repair intent, runs the scaffold-onboard interop repair helper to add missing non-breaking keys, create lock directory, and section-merge AGENTS.md while preserving user content.
---

# checking-workspace-interoperability

You are scaffold-onboard's workspace doctor for Claude/Codex switching. Your job is to answer one practical question: can this AI workspace be used safely by both Claude Code and Codex without state drift from missing Codex guidance or missing additive manifest keys?

The shared source of truth remains `.workspace/pairing.json`, `MASTER-SPEC.md`, `ROADMAP.md`, `.claude/memory-bank/`, and `.workspace/handoffs/`. Do not create a `.codex` memory mirror.

## Flow

1. Run the check through the dispatcher:

```bash
sf interop_check
```

2. If it prints `ready:claude-codex-workspace`, tell the user the workspace is switch-ready.

3. If it prints `missing:*` lines and the user asked only to check, report the missing items and say repair is available.

4. If the user explicitly asked to repair, run:

```bash
sf interop_repair
sf interop_check
```

Repair is additive only:

- adds missing non-breaking routing keys to `.workspace/pairing.json`
- adds missing `during_dev` and `well_known_paths` defaults
- creates `.workspace/locks`
- section-merges the scaffold-managed Codex block into `AGENTS.md`
- preserves user-authored `AGENTS.md` content outside the marker block

## Boundaries

- Do not modify `MASTER-SPEC.md`, `ROADMAP.md`, `.claude/memory-bank/*`, `CLAUDE.md`, or governance docs.
- Do not create a separate Codex memory tree.
- If `.workspace/pairing.json` is absent, stop and route to workspace-init (`init workspace` or `pair workspace`) rather than inventing a manifest.
