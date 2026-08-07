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
- Codex CLI >=0.125 for Architect Critic's adversary paths. It must be installed
  and authenticated for fresh-frame close-depth and async use; the default
  shallow path does not require it.

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

## Native Skills And Commands

OpenCode discovers the package's canonical skills lazily and exposes every
selected skill as a same-name native slash command. The complete inventory is:

| Plugin | Availability | Native commands |
|---|---|---|
| `workspace-init` | Default | `/initializing-dual-repo-workspace`, `/pairing-canonical-repo`, `/pairing-existing-dual` |
| `ai-mentor` | Default | `/grill-me`, `/council`, `/eli10`, `/fool` |
| `architect-critic` | Default | `/critiquing-spec`, `/reviewing-critique-history`, `/listing-principles`, `/promoting-principle`, `/checking-adversary-readiness`, `/managing-async-critique` |
| `ossify` | Experimental opt-in | `/start`, `/plan-spine`, `/work-item`, `/close`, `/plan-release` |

## Differing Aliases

Same-name native commands do not receive extra aliases. The package adds only
these nine aliases, where the existing command name differs from its skill:

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

Task 7 validates the native package export and options shapes with a direct
`file://` package spec. It does not validate GitHub transport; that transport
waits for the first gated immutable bundle tag to be published.

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
resolved state and startup logs without destructive cache cleanup:

```sh
opencode debug paths
opencode --print-logs --log-level WARN debug skill
opencode --print-logs --log-level ERROR debug config
opencode --print-logs --log-level DEBUG debug config
opencode debug agent ossify-implementer-agent
```

- Start with `opencode debug paths`; its `config` and `cache` values are the
  source of truth rather than assumed `~/.config/opencode` and
  `~/.cache/opencode` locations. Architect Critic state remains under
  `~/.claude/architect-critic`.
- OpenCode stores installed packages under
  `<cache>/packages/<sanitized-spec>/node_modules/<package>`. Do not guess
  `<sanitized-spec>` or search unrelated cache entries. Use the DEBUG log's
  resolved target to inspect only the identified package subtree and the config
  reported by `debug paths`.
- OpenCode 1.18.13 warns and overwrites duplicate skills; it does not fail
  loading for that collision. `debug skill` shows only the winning definition,
  while the WARN log names the duplicate. Use that path evidence to decide
  which config or skill source should change.
- OpenCode catches adapter config-hook errors, so `opencode debug config` can
  still exit 0. With a reserved `ossify-implementer-agent` collision, the
  selected package skill paths, aliases, and Ossify agent can all be absent
  from resolved config. The ERROR log exposes the reserved-name collision;
  rename the caller agent, restart, and inspect resolved config again.
- Caller-defined command collisions remain caller-preserved rather than being
  replaced by package aliases. Compare the command entry in resolved config
  with the differing-alias table before changing it.
- Confirm resolved `plugin` contains one pinned package entry. The default is a
  string; the Ossify opt-in is one tuple with the exact allowlist above. Never
  clear OpenCode's entire cache as a first response; change a targeted config or
  resolved package subtree only after the diagnostics identify it, then
  restart.
