# claude-agent-scaffolding

Personal Claude Code plugin marketplace.

## Plugins

| Plugin | Version | Scope | Purpose |
|---|---|---|---|
| [`workspace-init`](./workspace-init/) | v0.1.0 | Project-level (run-once) | Bootstrap a dual-repo workspace (AI workspace + canonical) with pairing manifest and AI-trace commit-msg filter. Run-once plugin; first in the scaffolding chain. 2 skills (`initializing-dual-repo-workspace`, `pairing-canonical-repo`), 2 slash commands (`/init-workspace`, `/pair-workspace` via `$ARGUMENTS` bridge). Pairing manifest schema v1.0 at `<ai-workspace>/.workspace/pairing.json`. `commit-msg` hook filters AI-trace lines with baked AI workspace path. Scenario A migration (`--pair-with`). 145 tests across 10 suites. |
| [`ai-mentor`](./ai-mentor/) | v2.0.0 | User-level | Decision-making mentor. Four auto-invocable skills: `grill-me` (one-question-at-a-time plan interrogation with CORE posture + 4 cognitive-discipline escape valves), `council` (5-persona multi-angle idea validation, Karpathy LLM Council pattern with codebase-aware Historian), `eli10` (repeatable simplification), `fool` (sticky beginner's-mind mode). Skill-first; no hooks, no state machinery. |
| [`scaffold-onboard`](./scaffold-onboard/) | v0.2.0 | Project-level (run-once) | Onboarding plugin (skill-first). 7 skills + 4 slash commands. 10-phase guided conversation authors `MASTER-SPEC.md`; deterministic derivation produces an 11-file memory-bank, a tiered `CLAUDE.md` router, and 5/14 governance docs. v0.2 adds R1 (Phase → Sprint → Vertical Slice roadmap via `/plan-roadmap`), R2 (machine-checkable rules DSL), R3 (`auto:`/`user:` demo criteria grammar). Composes with workspace-init (manifest routing), ai-mentor (cognitive mode), architect-critic v0.2+ (in-conversation review, no file IPC). |
| [`scaffold`](./scaffold/) | v1.0.0 | Project-level (continuous) | Implementation plugin. Slice-driven 5-phase workflow, living governance (ADRs, CHANGELOG, runbooks), per-repo memory bank with semantic search. 18 slash commands + 10 MCP tools. |
| [`architect-critic`](./architect-critic/) | v0.2.0 | User-level | Anti-sycophancy reviewer (skill-first). 4 auto-invocable skills: `critiquing-spec` (audit + sequential rebuttal with T=4 concession scoring), `reviewing-critique-history`, `listing-principles`, `promoting-principle`. Ships ghost-notes (Wald survivor-bias) + CORE protocol as default principles. Full auto-promotion (vote-recurrence T=4, instinct N=3, 30/90-day suppression). Codex 0.125+ adversarial fresh-frame at close-depth. Standalone-invocable; consumer plugins invoke skills in-conversation (no file IPC). |
| [`claude-security-audit`](./claude-security-audit/) | v0.1.0 | Project-level | Static-analysis security audit for Claude Code project configs and enabled plugins. 28 rules across 7 aspects (secrets, permissions incl. PERM-005 schema-typo, hooks, MCP, CLAUDE.md, prompt-injection, marketplace). Two-flag auto-fix + 5-layer defense-in-depth (T2-H). Durable `finding_uid` survives whitespace edits (T2-I). Self-tamper detection on state + suppressions (T1-F). Critical-cannot-suppress; 60s race-window refusal. Zero ambient surface — SessionStart reminder is opt-in (T1-C). 28 rules / 182 tests / 5 clean-fixture release gate. Inspired by ECC's AgentShield (MIT). |

The six plugins are designed to **compose without overlap**, ordered by where they fire in the project lifecycle: `workspace-init` (chain head) bootstraps the dual-repo topology (AI workspace + canonical) and writes the pairing manifest every downstream plugin reads; `scaffold-onboard` runs once per project to author the source-of-truth spec and derive its scaffolding; `scaffold` owns the continuous slice-by-slice implementation phase; `architect-critic` provides anti-sycophancy reviews on demand or when invoked in-conversation by `scaffold-onboard v0.2+` / `scaffold-dev v0.1+` (no file IPC); `ai-mentor` provides decision-making mentor surfaces (interrogation, multi-angle validation, simplification, beginner's mind) at any point; `claude-security-audit` provides on-demand static-analysis review of project configs and enabled plugins. Disjoint slash command namespaces, distinct state paths.

## Install

```
/plugin marketplace add github:draco28/claude-agent-scaffolding
/plugin install workspace-init@claude-agent-scaffolding
/plugin install ai-mentor@claude-agent-scaffolding
/plugin install scaffold-onboard@claude-agent-scaffolding
/plugin install scaffold@claude-agent-scaffolding
/plugin install architect-critic@claude-agent-scaffolding
/plugin install claude-security-audit@claude-agent-scaffolding
```

For local development:

```
/plugin marketplace add /home/pras/personal/claude-agent-scaffolding
/plugin install workspace-init@claude-agent-scaffolding
/plugin install ai-mentor@claude-agent-scaffolding
/plugin install scaffold-onboard@claude-agent-scaffolding
/plugin install scaffold@claude-agent-scaffolding
/plugin install architect-critic@claude-agent-scaffolding
/plugin install claude-security-audit@claude-agent-scaffolding
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

All four skills auto-invoke on natural-language triggers — no slash command required. Examples:

```
"grill me on this plan"            # → grill-me (one question at a time, walks the tree)
"council me on this idea"          # → council (5 personas attack from different angles)
"explain in simpler terms"         # → eli10 (re-explain at 10-year-old level; repeatable)
"consider me a beginner here"      # → fool (sticky beginner's-mind mode for the conversation)
```

Slash commands are also available as explicit handles when you want to be unambiguous:

```
/grill-me <plan or design>
/council <idea or decision>
/eli10 [topic]
/fool
```

Don't run `/grill-me` and `/council` in the same session — different interaction shapes (1-question interactive vs 5-voices one-shot); pick one.

## Layout

```
.
├── .claude-plugin/marketplace.json    # marketplace manifest
├── ai-mentor/                         # ai-mentor plugin (v2.0.0)
├── scaffold-onboard/                  # scaffold-onboard plugin (v0.2.0)
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
