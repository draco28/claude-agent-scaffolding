# claude-agent-scaffolding

Personal Claude Code plugin marketplace.

## Plugins

| Plugin | Version | Scope | Purpose |
|---|---|---|---|
| [`ai-mentor`](./ai-mentor/) | v1.3.0 | User-level | Cognitive partner. Pillar 3 (Gym/spotter) with two Curve-2 sub-modes (`/z2-decide` and `/z2-build`) + Pillar 4 (Fool/beginner's mind). Mechanically enforces spotter mode via PreToolUse hook + state file. |
| [`scaffold-onboard`](./scaffold-onboard/) | v0.1.0 | Project-level (run-once) | Onboarding plugin. 10-phase guided conversation authors `MASTER-SPEC.md`; deterministic derivation produces an 11-file memory-bank, a tiered `CLAUDE.md` router, and 5/14 governance docs. Soft-composes with ai-mentor + architect-critic. |
| [`scaffold`](./scaffold/) | v1.0.0 | Project-level (continuous) | Implementation plugin. Slice-driven 5-phase workflow, living governance (ADRs, CHANGELOG, runbooks), per-repo memory bank with semantic search. 18 slash commands + 10 MCP tools. |

The three plugins are designed to **compose without overlap**: `ai-mentor` enforces *cognitive mode* (when AI types vs when you do); `scaffold-onboard` runs once per project to author the source-of-truth spec and derive its scaffolding; `scaffold` owns the continuous slice-by-slice implementation phase. Disjoint slash command namespaces, distinct state paths.

## Install

```
/plugin marketplace add github:draco28/claude-agent-scaffolding
/plugin install ai-mentor@claude-agent-scaffolding
/plugin install scaffold-onboard@claude-agent-scaffolding
/plugin install scaffold@claude-agent-scaffolding
```

For local development:

```
/plugin marketplace add /home/pras/personal/claude-agent-scaffolding
/plugin install ai-mentor@claude-agent-scaffolding
/plugin install scaffold-onboard@claude-agent-scaffolding
/plugin install scaffold@claude-agent-scaffolding
```

## Quick start with `scaffold`

```
cd <your-project>
/scaffold-init                 # bootstrap LICENSE, .gitignore, README, CLAUDE.md, docs/
/slice-new my-first-slice      # start a slice
# ... edit the spec file's acceptance criteria ...
/slice-contract                # gate-checks ACs, advance to contract phase
/slice-scaffold                # advance to scaffold phase (write skeletons)
/slice-implement               # advance to implement phase
/slice-verify                  # run tests; mark complete on green
/adr-new "decide caching strategy"
/changelog Added "user authentication"
/changelog bump 0.1.0
/scaffold-worktree-fork alt-approach    # parallel branch with forked state
```

The MCP memory bank exposes `record_decision`, `record_pattern`, `record_note`, `record_retrospective`, `recall`, `list_recent`, `get_by_id`, `update`, `delete`, `reindex` as MCP tools — usable via natural language ("record a decision about caching strategy"), or directly in tool-calling contexts.

## Quick start with `ai-mentor`

```
/z1                            # pure delegation; AI does everything (default ambient)
/z2-decide                     # Curve 2: AI is spotter on architectural thinking;
                               #          PreToolUse hook blocks edits until /locked
/locked                        # signal decisions are final; AI implements
/z2-build                      # Curve 2: AI gives progressive hints; YOU type the code
                               #          override per-edit with "show me" / "skip to solution"
/eli10                         # Explain Like I'm 10 (re-invocable to simplify further)
/quiz l3                       # Socratic quiz at executive-interview depth
/fool                          # beginner's-mind mode for the conversation
```

## Layout

```
.
├── .claude-plugin/marketplace.json    # marketplace manifest
├── ai-mentor/                         # ai-mentor plugin (v1.3.0)
├── scaffold-onboard/                  # scaffold-onboard plugin (v0.1.0)
├── scaffold/                          # scaffold plugin (v1.0.0)
├── docs/
│   ├── SPEC-ai-mentor.md              # ai-mentor spec (v1.1 amendments)
│   ├── SPEC-scaffold.md               # scaffold spec (v1.0 amendments)
│   ├── SPEC-scaffold-onboard.md       # scaffold-onboard spec (v0.1)
│   ├── PLAN-scaffold-onboard.md       # scaffold-onboard implementation plan (v0.1)
│   └── archive/SPEC-v1.md             # historical 5-plugin design (pre-pivot)
├── README.md
└── LICENSE
```

## Platforms

Linux and macOS. Windows is deferred for all plugins (would require porting bash to PowerShell and the MCP launcher script).

`scaffold`'s MCP memory bank requires Python 3.11+ at install time and (optionally) Ollama running for semantic search. Falls back to FTS5 keyword search when Ollama is unavailable.

## License

MIT — see [`LICENSE`](./LICENSE).
