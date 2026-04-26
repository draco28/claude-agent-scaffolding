# scaffold

Project-level Claude Code plugin. Bootstrap any repo, run slice-driven development with strict phase gates, manage living governance docs, and query a per-repo memory bank with semantic search.

**Status:** v0.1.0 (Phase A scaffold — file tree exists, functionality lands in subsequent phases).

**Companion plugin:** [`ai-mentor`](../ai-mentor/) — user-level cognitive partner. The two are designed to compose without overlap. See SPEC `§10` for composition rules.

## What it does (target v1.0.0)

Four capabilities, plus a bundled MCP memory bank.

| Capability | Slash commands | Purpose |
|---|---|---|
| **Project init / audit** | `/scaffold-init`, `/scaffold-audit`, `/scaffold-status` | Bootstrap a new repo or audit an existing one. Stack + LLM-project detection drives lang-aware defaults. |
| **Slice workflow** | `/slice-new`, `/slice-spec`, `/slice-contract`, `/slice-scaffold`, `/slice-implement`, `/slice-verify`, `/slice-status`, `/slice-list` | Strict 5-phase gates: spec → contract (failing tests) → scaffold → implement → verify. Each gate refuses to advance until prerequisites hold. |
| **Living governance** | `/adr-new`, `/changelog`, `/runbook-new` | ADR auto-numbering, Keep-a-Changelog entries, SRE-style runbook templates. |
| **Two-layer CLAUDE.md** | `/scaffold-claude-md-edit`, `/scaffold-claude-md-rebuild` | Personal-defaults layer + project-specific layer. Generated, regeneratable, materializes into git worktrees. |
| **Worktree forking** | `/scaffold-worktree-fork`, `/scaffold-worktree-list` | `git worktree add` + state fork + CLAUDE.md materialize, in one command. |
| **Memory bank (MCP)** | (via natural language; 9 MCP tools) | Per-repo decisions, patterns, notes, slice retrospectives. Semantic search via Ollama embeddings; FTS5 fallback. |

## State layout

All mutable state lives **outside the working tree** at `${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/`. Worktrees of the same repo share the memory bank; per-branch state is isolated under `branches/<branch>/state.json`.

The plugin **never commits state files to the repo**. Spec authoring artifacts (slice specs, ADRs, runbooks, CHANGELOG) ARE committed because they're part of the project's documentation.

## Composition with ai-mentor

| Surface | ai-mentor | scaffold |
|---|---|---|
| Slash commands | 7 (`/z1`, `/z2-decide`, `/z2-build`, `/locked`, `/quiz`, `/eli10`, `/fool`) | 18 (above) |
| Hooks | SessionStart (always-on protocol) + PreToolUse (Edit/Write enforcement) | SessionStart (project context, source-aware) |
| MCP server | none | `scaffold-memory` |

Spec authoring and scaffold operations are Curve 1 (mechanical) → run in `/z1` or `ambient`. AC capture from a Socratic discussion is Curve 2/decide → `/z2-decide`, then `/locked`, then `/slice-contract`.

## Install

```
/plugin marketplace add draco28/claude-agent-scaffolding   # (already added if you have ai-mentor)
/plugin install scaffold@claude-agent-scaffolding
```

Will be live once Phase J ships.

## Dependencies

- bash (POSIX), `jq`, `git`
- Python 3.11+ (for the MCP memory bank server)
- Optional: Ollama with `nomic-embed-text:latest` pulled (for semantic search). Falls back to FTS5 keyword search if Ollama is unavailable.

The plugin's MCP server self-installs its Python venv on first use; no manual install step required (see SPEC `OQ-11`).

## Platforms

Linux, macOS. Windows deferred (same as ai-mentor).

## Spec

Full design at [`docs/SPEC-scaffold.md`](../docs/SPEC-scaffold.md).

## License

MIT — see [`LICENSE`](./LICENSE).
