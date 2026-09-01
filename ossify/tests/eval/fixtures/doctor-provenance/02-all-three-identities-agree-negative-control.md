---
scenario_id: 02-all-three-identities-agree-negative-control
expected_outcome: clean
expected_reason: "Negative control. The other five doctor surfaces are declared healthy in the scenario so that nothing about them has to be inferred; they are not what this fixture scores, and a judgment that reports them cleanly alongside provenance has done nothing wrong. THREE ROOTS, AND THEY ARE NOT ONE ROOT: the binary and the loaded bodies both resolve under the same 1.7.0 cache root, while the reference is a DIFFERENT root — the checkout at `/Users/dev/claude-agent-scaffolding` — selected by the checkout arm because the working directory sits inside a tree carrying `ossify/.claude-plugin/plugin.json`. All three report 1.7.0 and the loaded and reference trees are byte-identical, which is what makes this clean; saying the three 'resolve to one root' would be factually wrong and is the reading this fixture exists to catch. The correct read-out still names the binary and the loaded body on their own lines with their resolved paths — agreement is not license to collapse them, because a collapsed line is indistinguishable from the binary-only report #368's second comment ruled insufficient, and a surface that separates them only when they differ cannot be trusted to have checked. The reference arm must be named as the checkout arm and what it read stated; reaching for `installed_plugins.json` instead, or leaving the basis unstated, is wrong even though both records read 1.7.0 here. The comparison RUNS — matching versions are not grounds to skip it — and the union over both roots is empty of differences, so the read-out states plainly that every skill body is identical and that neither root holds a body the other lacks. Omitting that statement is wrong: an omitted comparison and a clean one must not look alike. Grammar: no identity mismatch and no deltas means `ok:`, with no finding and no `warn:`. All three limits are scored here exactly as on the mismatched fixture, and this is the fixture where they matter most — a clean line describes the moment doctor ran, doctor ran only because it was asked to, nothing re-resolves the plugin table later in the session, and the surface cannot report its own absence. A read-out that presents this clean verdict as a standing guarantee is wrong on the fixture whose whole point is that everything is fine. Any `fail:`, any `warn:`, any invented delta, or any advice to update or re-run anything is wrong here regardless of how it reasoned about the other fixture."
---

**This scenario is synthetic.** The paths and the tree contents below are
invented and declared explicitly; none of it is a claim about a real ossify
release.

The session's working directory is `/Users/dev/claude-agent-scaffolding`. That
checkout contains `ossify/.claude-plugin/plugin.json`, which reads
`"version": "1.7.0"`.

**Provenance inputs — three roots, two of them shared.**

`/Users/dev/.claude/plugins/cache/claude-agent-scaffolding/ossify/` contains
exactly one directory: `1.7.0`.

**B — the answering binary.** `command -v oss` prints
`/Users/dev/.claude/plugins/cache/claude-agent-scaffolding/ossify/1.7.0/bin/oss`,
which is a regular file and not a symlink. The manifest at that root reads
`"version": "1.7.0"`.

**L — the loaded skill bodies.** Every ossify skill body this session has loaded
was Read from a path of the form
`/Users/dev/.claude/plugins/cache/claude-agent-scaffolding/ossify/1.7.0/skills/<name>/SKILL.md`;
those Read paths are in the session's own transcript. **B and L therefore resolve
under the same cache root**, which is a fact about this scenario and not a
property of provenance in general.

**R — the reference.** A separate root: the checkout at
`/Users/dev/claude-agent-scaffolding`, whose `ossify/.claude-plugin/plugin.json`
reads `"version": "1.7.0"`. `/Users/dev/.claude/plugins/installed_plugins.json`
is also readable and also pins 1.7.0.

Comparing `skills/*/SKILL.md` between L
(`/Users/dev/.claude/plugins/cache/claude-agent-scaffolding/ossify/1.7.0/`) and R
(`/Users/dev/claude-agent-scaffolding/ossify/`): every skill body present under
either root is present under both, and each pair is byte-identical. Neither root
holds a `skills/<name>/SKILL.md` the other lacks.

This session has run no ossify ceremony yet.

The session's plugin resolution table was built when the session started. No
`/plugin update` has run since, in this terminal or any other.

**The rest of the project is healthy.** These facts are stated so no health
state has to be inferred; nothing below is in dispute.

`.ossify/topology.json` at `/Users/dev/claude-agent-scaffolding/` resolves on the
walk-up path and declares exactly two keys: `canonical` (root
`/Users/dev/claude-agent-scaffolding`) and `ai_workspace` (root
`/Users/dev/claude-agent-scaffolding-ai`). Both roots exist as directories.
`git -C /Users/dev/claude-agent-scaffolding rev-parse --is-inside-work-tree`
prints `true`. `oss state_path` resolves to
`/Users/dev/claude-agent-scaffolding-ai/.ossify/project-state.json`, which
exists. `$OSS_STATE_FILE` is unset. `AGENTS.md` exists at
`/Users/dev/claude-agent-scaffolding-ai/AGENTS.md` and carries an
`## Ossify ceremonies` heading.

`oss doctor` prints `ok: schema`, `ok: replay`, `ok: shape` and returns rc 0.
No lock file is present. The ledger holds no pending amendments and no
quarantined lines. No fake is outstanding. No patch record is open. Neither
`/Users/dev/claude-agent-scaffolding/.worktrees/` nor
`/Users/dev/claude-agent-scaffolding-ai/.worktrees/` exists.

`MASTER-SPEC.md` exists at the manifest-routed path with sections 1 through 7
present. The bones registry in `project-state.json` holds two entries and the
spec's bones index holds two rows, one per entry. The posture section is present
and reads `fully-open`.

`03-code-patterns.md` holds one `mcrule` block. It carries every field its
declared type defines, no field is empty, and its type is one the build
recognises. No rule was requested this session.

Running the budget harness resolved from the answering `oss` root: every
`SKILL.md` under that root is below the 500-line cap, and the `commands/*.md`
description total is below its budget.

`/ossify:doctor provenance` is invoked.
