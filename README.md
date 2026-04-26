# claude-agent-scaffolding

Personal Claude Code plugin marketplace.

## Plugins

| Plugin | Status | Scope | Purpose |
|---|---|---|---|
| [`ai-mentor`](./ai-mentor/) | v1 (in development) | User-level | Cognitive partner — Pillar 3 (Gym/spotter) + Pillar 4 (Fool/beginner's mind). Replaces the fragile pair-program plugin. Mechanically enforces Curve 2 mode via PreToolUse hook + state file. |
| `scaffolding` (working title) | Planned | Per-project | "Ultimate" project scaffolding plugin — applies on every new project. Spec drift, governance docs, methodology helpers. Spec at [`docs/archive/SPEC-v1.md`](./docs/archive/SPEC-v1.md) is a stale 5-plugin design; will be rewritten before this plugin is built. |

## Install

Add this repo as a Claude Code plugin marketplace:

```
/plugin marketplace add github:<user>/claude-agent-scaffolding
/plugin install ai-mentor@claude-agent-scaffolding
```

For local development:

```
/plugin marketplace add /home/pras/personal/claude-agent-scaffolding
/plugin install ai-mentor@claude-agent-scaffolding
```

## Layout

```
.
├── .claude-plugin/marketplace.json    # marketplace manifest
├── ai-mentor/                         # AI Mentor plugin
├── docs/
│   ├── SPEC-ai-mentor.md              # active spec (v0.2)
│   └── archive/SPEC-v1.md             # historical 5-plugin design
├── README.md
└── LICENSE
```

## License

MIT — see [`LICENSE`](./LICENSE).
