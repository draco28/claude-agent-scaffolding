# OpenCode Runtime Adapter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task by task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package the canonical `workspace-init`, `ai-mentor`,
`architect-critic`, and experimental `ossify` assets as one configurable
OpenCode plugin.

**Architecture:** A zero-dependency runtime adapter registers canonical skills
directly, provides native command aliases and an Ossify subagent, translates
harness-specific prompt conventions, and routes shell execution through
wrappers preserving canonical deterministic gates.

**Tech Stack:** JavaScript ES modules, Node built-in test runner, Bash,
OpenCode plugin API, existing shell libraries.

## Global Constraints

- Minimum supported OpenCode version: `1.18.13`.
- Default plugins: `workspace-init`, `ai-mentor`, `architect-critic`.
- Experimental opt-in: `ossify`.
- Never include `scaffold`, `scaffold-onboard`, `scaffold-dev`, or
  `claude-security-audit`.
- Canonical skills, references, templates, libraries, and hooks remain
  authoritative.
- Do not generate or copy OpenCode-specific skill trees.
- Runtime adapter has no third-party dependencies.
- Preserve all canonical shell exit codes and state paths.
- Linux and macOS only; Windows remains deferred.
- Preserve unrelated worktree changes and stage explicit paths only.
- Restart OpenCode after every plugin/config-time change.

---

### Task 1: Package Contract And Explicit Catalog

**Files:**
- Create: `package.json`
- Create: `.opencode/lib/catalog.js`
- Create: `.opencode/plugins/marketplace.js`
- Create: `tests/test-opencode-runtime-adapter.mjs`

**Interfaces:**
- Produces: `resolveEnabledPlugins(options = {}) -> PluginDefinition[]`
- Produces: `getSkillOwner(skillName) -> PluginDefinition | undefined`
- Produces: `getCommandOwner(commandName) -> PluginDefinition | undefined`
- Produces: `ScaffoldingPlugin(input, options = {}) -> Promise<Hooks>`

- [ ] Write failing tests for root metadata, default selection, the four-plugin
  allowlist, unknown plugin rejection, and exact exclusions.
- [ ] Run `node --test tests/test-opencode-runtime-adapter.mjs`; confirm the
  failure is caused by missing package/adapter code.
- [ ] Create a zero-dependency package with independent version `0.1.0`,
  `type: module`, the OpenCode entrypoint, `engines.opencode >=1.18.13`, and
  a payload allowlist containing only the adapter, selected plugins, and
  `LICENSE`.
- [ ] Implement an immutable four-entry catalog and strict selection logic.
- [ ] Run the focused Node suite and `npm pack --dry-run --json`.
- [ ] Commit with `feat(opencode): add bundle package and explicit plugin catalog`.

### Task 2: Native Skills And Command Aliases

**Files:**
- Create: `.opencode/lib/markdown.js`
- Modify: `.opencode/plugins/marketplace.js`
- Modify: `tests/test-opencode-runtime-adapter.mjs`

**Interfaces:**
- Consumes: Task 1 catalog and plugin entrypoint.
- Produces: selected `config.skills.paths` and exactly nine command aliases.

- [ ] Write failing tests for exact skill paths, idempotence, preservation of
  caller config, OpenCode frontmatter/name rules, uniqueness, and aliases.
- [ ] Run the focused test and confirm expected failures.
- [ ] Implement dependency-free frontmatter/body parsing.
- [ ] Append selected canonical skill directories without replacing user paths.
- [ ] Register the three Workspace Init and six Architect Critic aliases using
  native OpenCode templates with `$ARGUMENTS`.
- [ ] Rely on OpenCode's native skill commands for same-named AI Mentor and
  Ossify commands.
- [ ] Run the focused Node suite.
- [ ] Commit with `feat(opencode): register canonical skills and command aliases`.

### Task 3: Prompt Translation And Invocation Arguments

**Files:**
- Create: `.opencode/lib/translate.js`
- Create: `.opencode/lib/runtime.js`
- Modify: `.opencode/plugins/marketplace.js`
- Modify: `tests/test-opencode-runtime-adapter.mjs`

**Interfaces:**
- Produces: `translatePrompt(text, context) -> string`
- Produces: `translateToolOutput(tool, args, output) -> void`
- Produces: per-session command argument and agent tracking.

- [ ] Write failing tests for qualified Skill/Task forms, question mapping,
  package placeholders, package-owned reference reads, argument lifetime, and
  non-transformation of project files.
- [ ] Run the focused tests and confirm expected failures.
- [ ] Implement targeted translation through `command.execute.before` and
  `tool.execute.after` for skill/package-owned read results.
- [ ] Persist command and cross-skill Architect Critic arguments per session and
  inject them through `shell.env`.
- [ ] Clear stale arguments on the next ordinary user message.
- [ ] Run the focused Node suite.
- [ ] Commit with `feat(opencode): translate cross-harness skill invocations`.

### Task 4: Dispatcher Wrappers And Deterministic Gate Preservation

**Files:**
- Create: `.opencode/bin/wi`
- Create: `.opencode/bin/arc`
- Create: `.opencode/bin/oss`
- Modify: `.opencode/plugins/marketplace.js`
- Modify: `tests/test-opencode-runtime-adapter.mjs`

**Interfaces:**
- Consumes: selected plugin roots and runtime shell hook.
- Produces: PATH-visible wrappers preserving canonical stdout, stderr, and rc.

- [ ] Write failing spawn tests for wrapper self-location and representative
  Ossify `0/1/2` gate dispositions.
- [ ] Run the focused tests and confirm expected failures.
- [ ] Implement Bash wrappers that set plugin-specific compatibility variables
  and `exec` the canonical dispatcher.
- [ ] Prepend the wrapper directory idempotently through `shell.env`.
- [ ] Run selected canonical suites and the adapter suite.
- [ ] Commit with `feat(opencode): preserve canonical dispatcher gates`.

### Task 5: Ossify Subagent And Mechanical Git Boundary

**Files:**
- Modify: `.opencode/lib/runtime.js`
- Modify: `.opencode/plugins/marketplace.js`
- Modify: `tests/test-opencode-runtime-adapter.mjs`

**Interfaces:**
- Produces: `ossify-implementer-agent` and pre-execution Git guard.

- [ ] Write failing tests for agent conversion, permissions, prompt resolution,
  allowed Git operations, and all forbidden Git forms.
- [ ] Run the focused tests and confirm expected failures.
- [ ] Register the translated subagent only when Ossify is selected.
- [ ] Track session agent identity through `chat.message`.
- [ ] Reject commit/push/pull/fetch for Ossify implementer bash calls, including
  `git -C`, comments, heredocs, and pipelines.
- [ ] Run the focused Node suite.
- [ ] Commit with `feat(opencode): register and constrain ossify worker`.

### Task 6: Architect Critic Lifecycle And OpenCode Host Overlay

**Files:**
- Modify: `.opencode/lib/translate.js`
- Modify: `.opencode/lib/runtime.js`
- Modify: `.opencode/plugins/marketplace.js`
- Modify: `tests/test-opencode-runtime-adapter.mjs`

**Interfaces:**
- Produces: one-time fail-open session status and OpenCode host policy.

- [ ] Write failing tests for one-time injection, deduplication, handler
  failure, missing state, independent sessions, and host overlay content.
- [ ] Run the focused tests and confirm expected failures.
- [ ] Execute the canonical Architect Critic session-start handler once per
  session through `experimental.chat.messages.transform`.
- [ ] Define OpenCode host self-audit, Codex close-depth adversary, and explicit
  async behavior in the package-owned overlay.
- [ ] Verify Workspace Init's generated Git hook is not treated as a lifecycle
  hook.
- [ ] Run the adapter and Architect Critic suites.
- [ ] Commit with `feat(opencode): adapt architect critic lifecycle`.

### Task 7: Real OpenCode Integration And CI

**Files:**
- Create: `tests/test-opencode-live.sh`
- Modify: `.github/workflows/tests.yml`

**Interfaces:**
- Consumes: complete model-free adapter.
- Produces: hermetic real-loader coverage on OpenCode 1.18.13.

- [ ] Write a failing hermetic script using temporary HOME/XDG/config state.
- [ ] Verify real default and all-four `debug config`, `debug skill`, and
  `debug agent` behavior without touching developer config.
- [ ] Install pinned OpenCode in CI and add AI Mentor, Ossify, adapter unit, and
  live-loader steps.
- [ ] Rename CI wording so it no longer claims shell-only coverage.
- [ ] Run the live script and focused adapter suite.
- [ ] Commit with `test(opencode): add real loader integration coverage`.

### Task 8: Installation, Trust, And Release Documentation

**Files:**
- Create: `.opencode/INSTALL.md`
- Modify: `.gitignore`
- Modify: `README.md`
- Modify: `ossify/README.md`
- Modify: `ossify/.claude-plugin/plugin.json`
- Modify: `docs/superpowers/plans/2026-08-06-ossify-release-roadmap.md`

**Interfaces:**
- Produces: pinned default install, explicit Ossify allowlist, trust/update
  contract, and bundle release policy.

- [ ] Write documentation/package assertions before editing prose.
- [ ] Document default and Ossify-opt-in installation, restart/update behavior,
  requirements, invocation, troubleshooting, and trust boundary.
- [ ] Reconcile Ossify's experimental OpenCode availability with its stable
  Plan D gate.
- [ ] Add only precise OpenCode/Bun runtime ignores.
- [ ] Preserve unrelated README changes and stage explicit paths.
- [ ] Run documentation/package tests.
- [ ] Commit with `docs(opencode): document install and experimental ossify support`.

### Task 9: Final Verification And Release Gate

**Files:**
- Modify only files required by confirmed review findings.

- [ ] Run every selected plugin suite, existing root parity gates, adapter unit
  tests, live OpenCode integration, and `npm pack --dry-run --json`.
- [ ] Run the unchanged root CI suites that protect excluded plugins.
- [ ] Run credentialed smoke checks for one native skill command, one alias,
  Architect Critic shallow/close modes, Ossify skill/subagent dispatch, and
  forbidden Git rejection.
- [ ] Run the repository security audit against `package.json` and `.opencode/`.
- [ ] Request whole-branch review and fix all Critical/Important findings.
- [ ] Record any credential-dependent smoke check not run as a release blocker,
  not as a passing check.
- [ ] Prepare the branch for a PR to `main`; do not tag before the PR lands and
  release gates are recorded.
