# Install The OpenCode Bundle

The OpenCode adapter is distributed as one pinned, git-backed package. Its
bundle version is independent of the versions of the source plugins it
contains.

The `bundle-v0.1.0` value below is an example release tag, not a claim that the
tag is already published. Installation starts only after that immutable tag is
published. At that point, replace the example with the published tag you have
reviewed.

## Requirements

- OpenCode >=1.18.13 on macOS or Linux. Windows is unsupported.
- Bash 3.2 or newer, Git, `jq`, Node.js, and the standard `awk`, `sed`,
  `mktemp`, and `shasum` command-line tools used by the canonical plugins.
- An installed and authenticated Codex CLI for Architect Critic's fresh-frame
  close-depth and async adversary paths. The default shallow path does not
  require it.

## Default Installation

Add the plain pinned GitHub package spec to the native `plugin` array in the
user config at `~/.config/opencode/opencode.json` or a project's
`opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    "github:draco28/claude-agent-scaffolding#bundle-v0.1.0"
  ]
}
```

Restart OpenCode after saving the config. The default enables only
`workspace-init`, `ai-mentor`, and `architect-critic`.

## Experimental Ossify Opt-In

Ossify v0.x is experimental. To opt in, use OpenCode's native
`[specifier, options]` tuple and the exact four-name allowlist:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": [
    [
      "github:draco28/claude-agent-scaffolding#bundle-v0.1.0",
      {
        "plugins": [
          "workspace-init",
          "ai-mentor",
          "architect-critic",
          "ossify"
        ]
      }
    ]
  ]
}
```

Restart OpenCode after changing the options. Ossify remains absent from the
stable Claude and Codex marketplaces and is not ready for v1 until Plan D's
consolidated eval and two-pilot gate passes.

## Commands And Dispatch

OpenCode discovers the package's canonical skills lazily. Same-name skills are
native slash commands, not extra aliases. Examples include `/grill-me`,
`/council`, `/critiquing-spec`, and, when Ossify is enabled, `/plan-release`,
`/plan-spine`, `/work-item`, and `/close`.

The package adds aliases only where an existing command name differs from its
skill:

| Alias | Native skill |
|---|---|
| `/init-workspace` | `initializing-dual-repo-workspace` |
| `/pair-workspace` | `pairing-canonical-repo` |
| `/pair-existing-dual` | `pairing-existing-dual` |
| `/critique` | `critiquing-spec` |
| `/critique-list` | `reviewing-critique-history` |
| `/principles-list` | `listing-principles` |
| `/promote-principle` | `promoting-principle` |
| `/critique-doctor` | `checking-adversary-readiness` |
| `/critique-jobs` | `managing-async-critique` |

Ossify's native skills drive its lifecycle. Work-item execution can dispatch
the registered `ossify-implementer-agent` subagent through OpenCode's `task`
tool or an explicit `@ossify-implementer-agent` mention. The subagent inherits
the invoking model, cannot nest another task, and cannot run Git commit, push,
pull, or fetch through Bash.

## Updating And Restarting

Every config, plugin tag, or options change requires an OpenCode restart. To
update, review a new immutable `bundle-v<semver>` tag and its diff, change the
pinned spec, then restart OpenCode. Do not use floating branches, `HEAD`, or a
moving latest ref.

Root bundle semver and `bundle-v<semver>` tags are independent of each bundled
source plugin's version. After the PR lands, bundle releases run the repository
security audit and model-free gates before tagging, including adapter tests,
live loader checks, and package checks. Credentialed model-backed smoke checks
remain a separate release gate; documentation never treats an unpublished tag
as an available release.

## Trust Boundary

This package is trusted startup JavaScript. Before pinning a tag, review the
package entrypoint and its shipped plugin assets. At startup it registers
hooks, mutates the resolved config to add selected skill paths, aliases, and
the optional Ossify agent, and injects a shell environment with package-owned
`wi`, `arc`, and `oss` wrappers. Other hooks translate package-owned prompts,
carry transient invocation state, run Architect Critic's canonical session
handler once per session, and guard Ossify implementer Bash calls.

Those hooks do not independently read credentials or invoke a model at
startup. Invoked skills can run the canonical shell workflows, and Architect
Critic uses the active OpenCode model and, for configured adversary paths, the
user's Codex CLI. Pinning and reviewing an immutable release is therefore the
security boundary.

## Diagnostics

Restart first if the config, plugin tag, or options changed. Then inspect the
resolved state without deleting caches:

```sh
opencode debug config
opencode debug skill
opencode debug agent ossify-implementer-agent
opencode debug paths
```

- Confirm `debug config` shows one pinned package entry. The default is a
  string; the Ossify opt-in is one tuple with the exact allowlist above.
- Confirm `debug skill` reports one location per skill. Duplicate skill errors
  mean another configured skill path defines the same name; identify that path
  before changing either config.
- The name `ossify-implementer-agent` is reserved when Ossify is selected. A
  caller-defined agent with that name produces a collision error and must be
  renamed; caller commands that collide with aliases are preserved rather than
  overwritten.
- `opencode debug paths` is the source of truth for this installation. Typical
  user config is under `~/.config/opencode`, package cache data is under
  `~/.cache/opencode`, and Architect Critic state remains under
  `~/.claude/architect-critic`.
- For a package-load failure, inspect only the pinned package's entry beneath
  `~/.cache/opencode/node_modules` and the relevant config file. Do not delete
  the whole OpenCode cache. Change or repair a targeted path only after the
  diagnostics identify it, then restart.
