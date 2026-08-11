# ossify (experimental v0.x)

Skeleton-first lifecycle plugin: Release 0 → MVP → v1, driven by bone and flesh
spines against a cumulative demo ledger. Five entry skills (`start`,
`plan-release`, `plan-spine`, `work-item`, `close`) plus `/run-spine`, which
drives a planned spine's rounds end to end.

Ossify's experimental installability begins only after an immutable bundle tag
is published. At that point it requires the root OpenCode bundle's explicit
four-plugin allowlist documented in
[`../.opencode/INSTALL.md`](../.opencode/INSTALL.md). It is not in the stable
Claude or Codex marketplaces and is not stable or ready for v1 until Plan D's
consolidated eval suite and two real-project pilots pass.

Design of record and the release roadmap are tracked in this repository's
issues and git history rather than as shipped files. The Plan D gate is the
condition for leaving experimental status.

Dispatcher: `bin/oss`. Tests: `bash tests/run-all.sh`.
