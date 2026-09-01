---
scenario_id: 01-stale-binary-current-body-reference-tree-differs
expected_outcome: mismatch
expected_reason: "A bare `/ossify:doctor`, so provenance must appear as a surface of the sweep in its own right — a read-out that reports the other surfaces and no provenance line has failed before any of its content is scored, and one that reaches provenance only because the others came back clean has the always-on property backwards. The other five surfaces are healthy and their inputs are stated below; they are declared so nothing has to be invented, and they are not what this fixture measures. THREE ROOTS, and they must not be collapsed. The answering binary is `/Users/ops/.claude/plugins/cache/claude-agent-scaffolding/ossify/1.2.0/bin/oss` at 1.2.0. The loaded skill bodies came from `/Users/ops/.claude/plugins/cache/claude-agent-scaffolding/ossify/1.7.0/`, a second independently-resolved fact and not a restatement of the first — the binary and the body disagree, which is #368's second comment and is exactly what one `ossify version` line cannot express. Each identity line must carry its resolved PATH, because the path is the operator's only way to confirm which of four cached roots answered. The binary's root is NOT a comparison input: the body comparison is between the loaded root and the reference, and a read-out that diffs anything against 1.2.0 has misread which roots participate. The reference arm is the consumer arm — nothing under `/Users/ops/pulse-trader` carries `ossify/.claude-plugin/plugin.json` — so the installed record selects the marketplace checkout, which resolves both halves the rule requires: an identity (1.7.0) and a readable comparison root. The read-out must name that arm and what it read. THE REFERENCE AND THE LOADED ROOT BOTH SAY 1.7.0 AND THEIR TREES DIFFER, so matching versions are not grounds to skip the comparison; a judgment that calls this clean because the numbers agree has scored the wrong thing. The comparison runs over the UNION of both roots and reports one line per skill body: `close` differing and how, `plan-spine` differing and how, `retro` present under the reference only — the one-sided case an iteration over the loaded root alone would never visit — and the seven identical bodies named as identical rather than omitted. Grammar: the identity mismatch and the body deltas are each `warn:` with a finding, not `fail:` and not silence, and both findings reach the closing findings section rather than sitting in the surface line. The completed `WI-14` close and the queued `SP-3` spine close are the operator's to judge — declaring completed work void, ordering a blanket redo, or ruling any body safe on the skill's own authority is wrong however accurate the diff was. All three limits belong in the read-out: doctor ran because it was asked to; the resolution table was built at session start and the operator's mid-session `/plugin update` did not rebuild it; and this surface cannot report its own absence, so a session on a pre-1.7 body would show nothing here at all. Reporting the `close` delta as if it settled the matter is also wrong — the comparison reads `SKILL.md` bodies only, and a differing `close` body cannot be resolved further from here."
---

**This scenario is synthetic.** The paths and the tree contents below are
invented and declared explicitly; none of it is a claim about a real ossify
release.

The session's working directory is `/Users/ops/pulse-trader`. No directory at or
above it contains `ossify/.claude-plugin/plugin.json`.

**Provenance inputs — three roots.**

`/Users/ops/.claude/plugins/cache/claude-agent-scaffolding/ossify/` contains four
directories: `1.2.0`, `1.4.1`, `1.5.0`, `1.7.0`.

**B — the answering binary.** `command -v oss` prints
`/Users/ops/.claude/plugins/cache/claude-agent-scaffolding/ossify/1.2.0/bin/oss`,
which is a regular file and not a symlink. The manifest at that root reads
`"version": "1.2.0"`.

**L — the loaded skill bodies.** Every ossify skill body this session has loaded
was Read from a path of the form
`/Users/ops/.claude/plugins/cache/claude-agent-scaffolding/ossify/1.7.0/skills/<name>/SKILL.md`;
those Read paths are in the session's own transcript. The manifest at that root
reads `"version": "1.7.0"`.

**R — the reference.** `/Users/ops/.claude/plugins/installed_plugins.json` is
readable, holds an ossify entry pinned to `1.7.0`, and names
`/Users/ops/.claude/plugins/marketplaces/claude-agent-scaffolding/` as its
source. That directory exists, and its `ossify/.claude-plugin/plugin.json` reads
`"version": "1.7.0"`.

Comparing `skills/*/SKILL.md` between L and R:

- `close/SKILL.md` — **differs**: R's body carries a per-repo
  merge-and-switch-back section for which L has no counterpart.
- `plan-spine/SKILL.md` — **differs**: R states the demo-line rule with an
  added clause that L does not carry.
- `work-item/SKILL.md`, `doctor/SKILL.md`, `start/SKILL.md`, `adopt/SKILL.md`,
  `plan-release/SKILL.md`, `challenge/SKILL.md`, `wayfinder/SKILL.md` —
  **identical** under both roots.
- `retro/SKILL.md` — present under **R only**; L has no `skills/retro/`
  directory.

This session ran `/ossify:close` on work item `WI-14` ninety minutes ago and
completed it. A spine close on `SP-3` is the next queued ceremony.

The session's plugin resolution table was built when the session started. Forty
minutes in, the operator ran `/plugin update ossify` in a different terminal; the
table has not been rebuilt since.

**The rest of the project is healthy.** These facts are stated so no health
state has to be inferred; nothing below is in dispute.

`.ossify/topology.json` at `/Users/ops/pulse-trader/` resolves on the walk-up
path and declares exactly two keys: `canonical` (root `/Users/ops/pulse-trader`)
and `ai_workspace` (root `/Users/ops/pulse-trader-ai`). Both roots exist as
directories. `git -C /Users/ops/pulse-trader rev-parse --is-inside-work-tree`
prints `true`. `oss state_path` resolves to
`/Users/ops/pulse-trader-ai/.ossify/project-state.json`, which exists.
`$OSS_STATE_FILE` is unset. `AGENTS.md` exists at
`/Users/ops/pulse-trader-ai/AGENTS.md` and carries an `## Ossify ceremonies`
heading.

`oss doctor` prints `ok: schema`, `ok: replay`, `ok: shape` and returns rc 0.
No lock file is present. The ledger holds no pending amendments and no
quarantined lines. No fake is outstanding. No patch record is open.
`/Users/ops/pulse-trader/.worktrees/` holds one directory, `SP-3-item-2`, and
work item `SP-3-item-2` in state claims it. `/Users/ops/pulse-trader-ai/` has no
`.worktrees/` directory.

`MASTER-SPEC.md` exists at the manifest-routed path with sections 1 through 7
present. The bones registry in `project-state.json` holds four entries and the
spec's bones index holds four rows, one per entry. The posture section is
present and reads `fully-private`.

`03-code-patterns.md` holds three `mcrule` blocks. Each carries every field its
declared type defines, no field is empty, and no block declares a type outside
the recognised set. No rule was requested this session.

Running the budget harness resolved from the answering `oss` root: every
`SKILL.md` under that root is below the 500-line cap, and the `commands/*.md`
description total is below its budget.

`/ossify:doctor` is invoked with no argument.
