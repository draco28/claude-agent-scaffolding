# ossify (experimental v0.x)

Skeleton-first lifecycle plugin. Specs of record:
- docs/superpowers/specs/2026-07-11-poc-first-lifecycle-design.md
- docs/superpowers/specs/2026-07-12-public-private-boundary-design.md

Ossify's experimental installability begins only after an immutable bundle tag
is published. At that point it requires the root OpenCode bundle's explicit
four-plugin allowlist documented in
[`../.opencode/INSTALL.md`](../.opencode/INSTALL.md). It is not in the stable
Claude or Codex marketplaces and is not stable or ready for v1 until Plan D's
consolidated eval suite and two real-project pilots pass.

The current v0.x build still has no invoking entry point for its completed
round-orchestration execution lane. Track that and the Plan D gate in
[`../docs/superpowers/plans/2026-08-06-ossify-release-roadmap.md`](../docs/superpowers/plans/2026-08-06-ossify-release-roadmap.md).

Dispatcher: `bin/oss`. Tests: `bash tests/run-all.sh`.
