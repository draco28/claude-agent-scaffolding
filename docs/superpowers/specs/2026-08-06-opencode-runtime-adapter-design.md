# OpenCode Runtime Adapter Design

**Status:** Approved on 2026-08-06

## Goal

Package the canonical `workspace-init`, `ai-mentor`, `architect-critic`, and
experimental `ossify` assets as one configurable OpenCode plugin without
creating a second source of truth for their skills, references, templates, or
deterministic shell logic.

## Scope

The stable default bundle contains:

- `workspace-init`
- `ai-mentor`
- `architect-critic`

`ossify` is packaged but opt-in until its Plan D v1 ship gate. The adapter must
never discover top-level plugin directories dynamically. `scaffold`,
`scaffold-onboard`, `scaffold-dev`, and `claude-security-audit` are explicitly
outside the OpenCode bundle.

## Package And Invocation Architecture

One git-installable root package exports an OpenCode plugin. Its optional
`plugins` setting is an exact allowlist; omitting it enables only the three
stable plugins.

The plugin appends selected canonical `skills/` directories to
`config.skills.paths`. OpenCode then discovers the `SKILL.md` files, advertises
them lazily through the native `skill` tool, and exposes each skill as a slash
command. Skill bodies are never eagerly injected into every turn.

Only command names that differ from their target skill need explicit aliases:

| Alias | Skill |
|---|---|
| `init-workspace` | `initializing-dual-repo-workspace` |
| `pair-workspace` | `pairing-canonical-repo` |
| `pair-existing-dual` | `pairing-existing-dual` |
| `critique` | `critiquing-spec` |
| `critique-list` | `reviewing-critique-history` |
| `principles-list` | `listing-principles` |
| `promote-principle` | `promoting-principle` |
| `critique-doctor` | `checking-adversary-readiness` |
| `critique-jobs` | `managing-async-critique` |

Ossify's Claude agent is registered as the OpenCode subagent
`ossify-implementer-agent`. It inherits the invoking model, denies nested
`task`, and preserves the canonical return contract.

A shared translator operates only on package-owned prompt content. It adapts
qualified `Skill(plugin:name)` and `Task(...)` forms, `AskUserQuestion`, tool
vocabulary, plugin-root/data placeholders, and Architect Critic's transient
argument bridge. Project files and ordinary user text are not rewritten.

## Hooks, State, And Deterministic Gates

Adapter-owned `wi`, `arc`, and `oss` wrappers are prepended to OpenCode's shell
`PATH`. Each wrapper resolves the installed package, sets compatibility
variables for exactly one plugin, and `exec`s the canonical dispatcher. The
adapter does not reinterpret gate results: stdout, stderr, locks, atomic
writes, Git operations, and return codes remain owned by the existing shell
libraries.

State remains in its current canonical locations:

- Workspace Init and Ossify remain manifest/project-state routed.
- Architect Critic continues to share `~/.claude/architect-critic` across
  Claude, Codex, and OpenCode.
- The installed package remains read-only; no generated skill tree is written
  into OpenCode configuration directories.

Architect Critic's included `SessionStart` behavior is adapted through
`experimental.chat.messages.transform`. The canonical handler runs once per
OpenCode session, its fail-open status is prepended to the first user message,
and repeated transforms are deduplicated.

Workspace Init's generated `commit-msg` hook remains a project artifact
installed by the canonical workflow. It is not an OpenCode lifecycle hook.

Ossify's deterministic verbs, including RED gates, verification steps, report
cross-checks, touch checks, fake/quarantine expiry, and replay checks, continue
to run through `oss`. For the OpenCode implementer subagent, a
`tool.execute.before` guard additionally rejects `git commit`, `git push`,
`git pull`, and `git fetch`, including `git -C` forms. This supplements the
canonical prompt and audit contract.

When OpenCode hosts Architect Critic:

- `HOST_AGENT=opencode`.
- The active OpenCode model performs the host self-audit.
- Codex is the foreground close-depth fresh-frame adversary.
- Async uses the existing Codex companion/state spine only after a live
  compatibility smoke test; explicit async requests never silently degrade.
- Slash and cross-skill arguments are carried in adapter session state rather
  than relying on a shell export to survive across tool processes.

## Verification And Release

The first supported OpenCode version is `1.18.13`. A dependency-free Node test
suite verifies package selection, exclusions, idempotent config mutation,
skill and alias registration, prompt translation, agent conversion, hook
deduplication, argument propagation, and the worker Git guard.

Wrapper tests execute representative canonical verbs and assert return-code
preservation. Hermetic OpenCode integration tests use temporary config and
data directories to verify real `debug config`, `debug skill`, and `debug
agent` behavior without touching the developer's OpenCode configuration.

Model-free checks run in CI. Credentialed model-backed smoke checks remain a
release runbook gate.

The root package has independent bundle semver and tags named
`bundle-v<semver>`. Distribution begins as a pinned git-backed package rather
than six npm packages. Every config-time change requires restarting OpenCode.

Ossify documentation must state that v0.x is experimentally installable only
through an explicit OpenCode allowlist while remaining outside stable
Claude/Codex marketplaces until Plan D.

The package is trusted startup JavaScript with access to shell hooks. Release
documentation must recommend pinned tags, state the trust boundary, and run
the repository's own security audit over the adapter before tagging.

## Non-Goals

- Rewriting canonical skills into a neutral DSL.
- Committing generated OpenCode skill or command copies.
- Publishing one package per source plugin.
- Porting deprecated scaffolding plugins.
- Windows support.
- Claiming Ossify stable before its existing pilot and ship gates.
