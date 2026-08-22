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
suite has passed; the two real-project pilots are operator-owned and post-v1.

Design of record and the release roadmap are tracked in this repository's
issues and git history rather than as shipped files.

Dispatcher: `bin/oss`. Tests: `bash tests/run-all.sh`.
