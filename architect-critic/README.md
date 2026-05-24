# architect-critic

Anti-sycophancy reviewer plugin for Claude Code (v0.2 — skill-first). Four gerund-named skills auto-invoke on natural-language triggers: `critiquing-spec` runs a claude-self-audit followed by sequential adversarial rebuttal with T=4 concession scoring, `reviewing-critique-history` surfaces recent run summaries, `listing-principles` renders the merged principle set, and `promoting-principle` adds a principle manually. Ships two shipped-default principles — ghost notes (Wald survivor-bias: look for what is *absent*) and CORE protocol (Curiosity / Objectivity / Reassurance / Empathy rebuttal tone) — that are prepended to your `principles.md` on first run. Full auto-promotion machinery: vote-recurrence threshold T=4, supplementary instinct-style N=3 consecutive signal, 30/90-day suppression windows. Codex CLI 0.125+ dispatched as an adversarial fresh-frame second auditor at `--close` depth. Standalone-invocable; consumer plugins (`scaffold-onboard v0.2+`, `scaffold-dev v0.1+`) invoke `critiquing-spec` in-conversation with no file IPC.

## Install

```
/plugin install architect-critic@claude-agent-scaffolding
```

## Quick start

Shallow audit (claude-self-audit only):

```
/critique
```

Close audit (claude-self-audit + Codex 0.125+ fresh-frame adversary):

```
/critique --close
```

Audit a specific spec file:

```
/critique --spec docs/SPEC-payments.md
```

All four skills also auto-invoke on natural-language triggers — no slash command required:

```
"critique my spec"                   # → critiquing-spec
"show my recent critiques"           # → reviewing-critique-history
"what principles are in use?"        # → listing-principles
"add a principle about rollbacks"    # → promoting-principle
```

## Skills (4)

| Skill | Trigger phrases (examples) | What it does |
|---|---|---|
| `critiquing-spec` | "critique my spec", "audit this plan", "review this design", "run a critique" | Discovers spec file, runs claude-self-audit, optional Codex fresh-frame, sequential rebuttal per challenge, auto-promotion offer |
| `reviewing-critique-history` | "show recent critiques", "critique list", "what did the last audit find", "history of critiques" | Renders recent runs from state.json with challenge counts, concession tallies, skills invoked |
| `listing-principles` | "what principles are in use", "show my principles", "list my principles", "principles-list" | Composes and renders user-global + project-scoped + pattern-derived + governance principles |
| `promoting-principle` | "add a principle", "promote this principle", "record a principle about X", "add to principles.md" | Validates text, routes to user-global or project scope, appends with `[promoted YYYY-MM-DD source:manual]` annotation |

## Slash commands (4)

| Command | Args | Delegates to |
|---|---|---|
| `/critique` | `[--close] [--spec PATH]` | `critiquing-spec` skill |
| `/critique-list` | `[--limit N]` | `reviewing-critique-history` skill |
| `/promote-principle` | `"<text>" [--scope user\|project]` | `promoting-principle` skill |
| `/principles-list` | _(none)_ | `listing-principles` skill |

All commands use `$ARGUMENTS` env-var bridge exclusively — no `$1`/`$2` bare positionals.

## Shipped principles

Two principles ship as defaults in `templates/principles.md` and are auto-prepended to your `~/.claude/architect-critic/principles.md` on first run (preserving any existing content below them):

**Ghost notes** — drawn from Abraham Wald's WWII survivor-bias insight: when auditing a spec, look not just at what is present but for what is *absent*. The missing cases, the unspecified failure modes, the undocumented assumptions — these are the ghost notes. A design that only addresses the visible is incomplete.

**CORE protocol** — sets the rebuttal-cycle tone: Curiosity (ask before assuming), Objectivity (score the argument, not the author), Reassurance (challenge the design, not the person), Empathy (acknowledge when the concern was legitimate even if conceded). Applied by Claude during the sequential rebuttal phase.

## Auto-promotion

When a pattern recurs across critique runs, the skill offers to promote it to your `principles.md`. Two signals combine:

- **Vote-recurrence (T=4):** a topic cluster that appears in ≥4 distinct runs triggers a promotion offer.
- **Instinct signal (N=3):** a topic cluster appearing in 3 consecutive runs (regardless of total count) also triggers — catches fast-forming patterns before T=4 is reached.

**Suppression windows** prevent re-prompting after a decline:

- Score-4 decline (user said no to a promotion): suppressed for **30 days**.
- Score-5 decline (user rejected a premise-invalidated challenge): suppressed for **90 days**.

Promotion records live in `~/.claude/architect-critic/state.json` under `auto_promote_suppressions[]`.

## Standalone use

`architect-critic` works in any Claude Code session without `scaffold-onboard` or any other plugin installed.

**Spec file discovery order:**

1. Explicit `--spec PATH` argument.
2. Workspace-init manifest `well_known_paths.master_spec` (if workspace-init is installed).
3. Restricted glob: `SPEC*.md` or `PLAN*.md` in the project root (never a bare `*.md` sweep).
4. `AskUserQuestion` fallback — Claude asks you to identify the spec file.

**Storage locations:**

- `~/.claude/architect-critic/state.json` — run history, concession records, suppression windows.
- `~/.claude/architect-critic/principles.md` — user-global principles (shipped defaults + your additions).
- `.claude/architect-critic/principles.md` — project-scoped principles (optional; created by `/promote-principle --scope project`).

**Invoking with an explicit path:**

```
/critique --spec /abs/path/to/SPEC-foo.md
```

or pass a relative path from the project root:

```
/critique --spec docs/SPEC-payments.md --close
```

## What `project_class=unknown` means

If a workspace-init manifest is present and reports `project_class: unknown`, the critic falls back to **generic principles only** — project-class-specific heuristics (e.g., API-design rules for `project_class: api-service`, or migration-safety rules for `project_class: data-pipeline`) are not applied.

This is expected when workspace-init could not determine the project type during bootstrapping. Two options to resolve:

1. **Add detection rules to workspace-init** — update its classifier so future bootstraps detect the class.
2. **Author project-scoped principles** — run `/promote-principle "<text>" --scope project` to add heuristics manually; these are always applied regardless of `project_class`.

The `project_class=unknown` state is logged in the skill output ("Project class: unknown — using generic principles only") so it is visible without inspecting the manifest.

## Configuration

| Env var | Default | Effect |
|---|---|---|
| `ARCHITECT_CRITIC_CODEX_TIMEOUT_S` | `180` | Seconds before codex fresh-frame is killed and claude-only fallback is used |

Principles file resolution order (highest priority first):

1. `$CLAUDE_PLUGIN_DATA/architect-critic/principles.md` (user-global)
2. `.claude/architect-critic/principles.md` (project-scoped)
3. Memory-bank pattern files (if scaffold-onboard v0.2+ is installed)
4. Governance docs (if workspace-init manifest is present)

## Migrating from v0.1.x

See [CHANGELOG.md](./CHANGELOG.md) for the full breaking-changes list.

On first run after upgrading, `lib/migration.sh` runs automatically:

- Backs up `state.json` → `state.json.v0.1.3.bak` (timestamped on collision).
- Moves `inbox/` and `outbox/` directories to `legacy-v0.1.x/` (no data is deleted).
- Prepends ghost-notes + CORE shipped defaults to `principles.md`, preserving all existing user content below the defaults block.

No manual steps required. If anything looks wrong after migration, restore from the `.bak` file and open an issue.

## Composition

`scaffold-onboard v0.2+` and `scaffold-dev v0.1+` invoke `critiquing-spec` in-conversation — Claude calls the skill directly, no file IPC. This is the v0.2 contract: consumer plugins pass context through the conversation turn, not through inbox/outbox JSON files.

**v0.1.x `scaffold-onboard` is incompatible with `architect-critic v0.2`.** The v0.1.x onboard plugin writes to an inbox directory that no longer exists. Upgrade scaffold-onboard to v0.2+ before using architect-critic v0.2.

## Development

Run unit tests (~197 assertions):

```bash
bash tests/unit/test-state.sh
bash tests/unit/test-principles.sh
bash tests/unit/test-promotion.sh
bash tests/unit/test-migration.sh
```

Run integration tests (bug repros, migration smoke, subagent pressure):

```bash
bash tests/integration/test-bug-repros.sh
bash tests/integration/test-migration-smoke.sh
```

Run LLM-as-judge evals (requires an active Claude Code session):

```
See tests/eval/RUNBOOK.md
```

## See also

- Design spec: [`docs/SPEC-architect-critic.md`](../docs/SPEC-architect-critic.md)
- Implementation plan: [`docs/PLAN-architect-critic.md`](../docs/PLAN-architect-critic.md)
- Composition contract: [`docs/SPEC-scaffold-onboard.md`](../docs/SPEC-scaffold-onboard.md) §8.3

## Platforms

macOS and Linux. Windows deferred (matches sibling plugins).

## License

MIT
