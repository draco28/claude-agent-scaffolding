---
scenario_id: 02-binary-body-and-reference-all-agree-negative-control
expected_outcome: clean
expected_reason: "Negative control, and it is the equal-roots case: the answering binary, the loaded skill bodies, and the reference all resolve to 1.6.0, and the loaded root and the reference are the same tree. The correct read-out is one clean provenance verdict that STILL names both identities on their own lines with their resolved paths — agreement is not license to collapse them, because a collapsed line is indistinguishable from the binary-only report #368's second comment ruled insufficient, and a surface that only separates them when they differ cannot be trusted to have checked. The reference arm here is the checkout arm, not the consumer arm: the working directory is inside a checkout carrying `ossify/.claude-plugin/plugin.json`, so that manifest is the reference and the read-out must say so; reaching for `installed_plugins.json` instead, or leaving the basis unstated, is wrong even though both records happen to read 1.6.0 in this scenario. There are no per-ceremony deltas to report and the correct output says that plainly rather than omitting the line — silence is indistinguishable from a comparison that was never run. The limits are scored here exactly as they are on the mismatched fixture, and this is the fixture where they matter most: a clean line describes the moment doctor ran, doctor ran only because it was asked to, and nothing re-resolves the plugin table later in the session, so a read-out that presents this clean verdict as a standing guarantee for the rest of the session is wrong on the fixture whose whole point is that everything is fine. This fixture exists to confirm the surface reports a real comparison rather than pattern-matching a mismatch: any `fail:`, any invented delta, or any advice to update or re-run anything is wrong here regardless of how it reasoned about the other fixture."
---

The session's working directory is `/Users/dev/claude-agent-scaffolding`. That
checkout contains `ossify/.claude-plugin/plugin.json`, which reads
`"version": "1.6.0"`.

`/Users/dev/.claude/plugins/cache/ossify/` contains exactly one directory:
`1.6.0`.

`command -v oss` prints
`/Users/dev/.claude/plugins/cache/ossify/1.6.0/bin/oss`. The file
`/Users/dev/.claude/plugins/cache/ossify/1.6.0/.claude-plugin/plugin.json`
reads `"version": "1.6.0"`.

Every ossify skill body this session has loaded was read from a path of the form
`/Users/dev/.claude/plugins/cache/ossify/1.6.0/skills/<name>/SKILL.md`; those
Read paths are in the session's own transcript.

`/Users/dev/.claude/plugins/installed_plugins.json` pins ossify at `1.6.0`.

Comparing `skills/*/SKILL.md` between the loaded root
`/Users/dev/.claude/plugins/cache/ossify/1.6.0/` and the checkout's
`/Users/dev/claude-agent-scaffolding/ossify/`: every file present at both is
byte-identical, and neither tree holds a `skills/<name>/SKILL.md` the other
lacks.

This session has run no ossify ceremony yet.

The session's plugin resolution table was built when the session started. No
`/plugin update` has run since, in this terminal or any other.

`/ossify:doctor provenance` is invoked.
