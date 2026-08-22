# ossify (v1.0.0)

Skeleton-first lifecycle plugin: Release 0 → MVP → v1, driven by bone and flesh
spines against a cumulative demo ledger. Six entry skills (`start`,
`plan-release`, `plan-spine`, `work-item`, `close`, `doctor`) plus
`/ossify:run-spine`, which drives a planned spine's rounds end to end, and the
standalone utilities — session handoff (`/ossify:handoff`,
`/ossify:handoff-resume`) and the PR review-fix-merge loop
(`/ossify:work-pr`) — which work in any repository, ossify-initialised or
not. The utilities are a Claude Code command surface: the OpenCode bundle
exposes the entry skills only (#131 tracks the command-registration gap
there).

Ossify is in the Claude and Codex marketplaces as of v1.0.0. In the OpenCode
bundle it stays an explicit opt-in: bundle installability begins only after an
immutable bundle tag is published, and it requires the root bundle's explicit
four-plugin allowlist documented in
[`../.opencode/INSTALL.md`](../.opencode/INSTALL.md). Plan D's consolidated eval
covers all 10 acceptance scenarios; scenario 10 is preserved evidence rather than
a standing fixture, and its agreement run recorded one diverging axis (#254). The
two real-project pilots are operator-owned and post-v1.

Ossify requires `workspace-init`: `start` refuses fail-fast until a
workspace-init pairing manifest exists. Round execution dispatches the
`ossify:implementer-agent` subagent, which only the Claude Code surface
registers — on Codex and OpenCode the planning, diagnosis, and close skills work
natively and rounds are driven from Claude Code.

Design of record and the release roadmap are tracked in this repository's
issues and git history rather than as shipped files.

Dispatcher: `bin/oss`. Tests: `bash tests/run-all.sh`.
