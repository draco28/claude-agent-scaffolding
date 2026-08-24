# ossify (v1.2.0)

Skeleton-first lifecycle plugin: Release 0 → MVP → v1, driven by bone and flesh
spines against a cumulative demo ledger. Eight entry skills (`start`, `adopt`,
`plan-release`, `plan-spine`, `work-item`, `close`, `doctor`, `challenge`) plus
`/ossify:run-spine`, which drives a planned spine's rounds end to end, and the
standalone utilities — session handoff (`/ossify:handoff`,
`/ossify:handoff-resume`), the PR review-fix-merge loop
(`/ossify:work-pr`), and decision-ticket maps that chart a question into
tickets or work an existing map's frontier one ticket per session
(`/ossify:wayfinder`) — which work in any repository, ossify-initialised or
not. The utilities are a Claude Code command surface: the OpenCode bundle
exposes the entry skills only (#131 tracks the command-registration gap
there).

`challenge` is the grill and the adversarial critic, absorbed in-tree at 1.1.0:
the bone grill gate, the spec-core close audit, the release class veto, and the
spine plan/close audits all run on ossify alone — no ai-mentor or
architect-critic install required. Both plugins remain useful standalone;
ossify no longer depends on either. A close-depth audit recruits an external
fresh-frame adversary when one is configured via `OSSIFY_ADVERSARY`
(`skills/challenge/references/adversaries.md`); unconfigured means host-only,
by declaration.

Ossify is in the Claude and Codex marketplaces as of v1.0.0. In the OpenCode
bundle it stays an explicit opt-in: bundle installability begins only after an
immutable bundle tag is published, and it requires the root bundle's explicit
four-plugin allowlist documented in
[`../.opencode/INSTALL.md`](../.opencode/INSTALL.md). Plan D's consolidated eval
covers all 10 acceptance scenarios; scenario 10 is a run rather than a standing
fixture, and its second run agreed **5 of 5 with no divergence** after the prose
fixes its first run prompted (#250, #251). That is two runs on one scenario, not
a measured property of the prose — #254 stands over both. The two real-project
pilots are operator-owned and post-v1.

Ossify requires `workspace-init`: `start` refuses fail-fast until a
workspace-init pairing manifest exists. Round execution dispatches the
`ossify:implementer-agent` subagent. Claude Code registers it natively, and the
OpenCode adapter registers `ossify-implementer-agent` as well, so rounds run on
both. **Codex** has no worker path: its planning, diagnosis and close skills
work, and rounds are driven from Claude Code or OpenCode. The critic is
internal, so the release-planning veto and the spine-close audit run on every
install, Codex-only included.

Design of record and the release roadmap are tracked in this repository's
issues and git history rather than as shipped files.

Dispatcher: `bin/oss`. Tests: `bash tests/run-all.sh`.
