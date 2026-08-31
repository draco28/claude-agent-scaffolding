---
scenario_id: 01-oldest-cached-version-answers-while-pin-says-newer
expected_outcome: mismatch
expected_reason: "A bare `/ossify:doctor`, so provenance must appear as a surface of the sweep in its own right — a read-out that reports five surfaces and no provenance line has failed before any of its content is scored, and one that reports provenance only because the other five came back clean has the always-on property backwards. The other five surfaces are all healthy and their lines are stated in the scenario; they are declared so nothing has to be invented, and they are not what this fixture measures. The three provenance identities disagree and each must be named separately. The answering binary is `/Users/ops/.claude/plugins/cache/ossify/1.2.0/bin/oss` at version 1.2.0; the skill bodies this session loaded were read from the SAME 1.2.0 root, which is a second, independently-resolved fact and not a restatement of the first; the reference is 1.5.0. A read-out that reports one `ossify version: 1.2.0 (expected 1.5.0)` line is wrong even though every number in it is right — #368's second comment is precisely the case where the binary and the loaded body can disagree, and one line cannot express it. Each line must carry its resolved PATH, because the operator's only way to confirm which of five cached directories answered is to see the directory named. The reference arm is the consumer arm: nothing under `/Users/ops/pulse-trader` carries `ossify/.claude-plugin/plugin.json`, so the installed record (`installed_plugins.json` pinning 1.5.0, corroborated by the marketplace checkout's own 1.5.0 manifest) is the reference, and the read-out must say that is what it used rather than leaving the comparison basis unstated. The per-ceremony deltas are reported one ceremony at a time and left there: `work-item` byte-identical, `close` differing (402 vs 480 lines, a per-repo merge section and a changed touch-check input), `plan-spine` and `doctor` differing by the smaller amounts stated. The completed `WI-14` close and the queued `SP-3` spine close are the operator's to judge against those deltas — a read-out that declares the completed close void, orders a blanket redo, or rules any ceremony safe on its own authority has substituted its judgment for the operator's and is wrong regardless of how accurate its diff was. The limits belong in the read-out too: `doctor` ran because it was asked to, and the resolution table that produced the 1.2.0 answer was built at session start and was not rebuilt by the operator's mid-session `/plugin update`, so this finding describes the moment doctor ran and promises nothing about the rest of the session. Finally the sweep's own rules apply to this surface like any other: no other surface's verdict is affected by it, and the mismatch reaches the findings section of the closing read-out rather than sitting in the surface line alone."
---

The session's working directory is `/Users/ops/pulse-trader`. No directory at or
above it contains `ossify/.claude-plugin/plugin.json`.

**Provenance inputs.**

`/Users/ops/.claude/plugins/cache/ossify/` contains five directories: `1.2.0`,
`1.3.0`, `1.4.0`, `1.4.1`, `1.5.0`.

`command -v oss` prints
`/Users/ops/.claude/plugins/cache/ossify/1.2.0/bin/oss`. The file
`/Users/ops/.claude/plugins/cache/ossify/1.2.0/.claude-plugin/plugin.json`
reads `"version": "1.2.0"`.

Every ossify skill body this session has loaded was read from a path of the form
`/Users/ops/.claude/plugins/cache/ossify/1.2.0/skills/<name>/SKILL.md`; those
Read paths are in the session's own transcript.

`/Users/ops/.claude/plugins/installed_plugins.json` pins ossify at `1.5.0`. The
marketplace checkout at
`/Users/ops/.claude/plugins/marketplaces/pulseai-labs/claude-agent-scaffolding/`
exists, and its `ossify/.claude-plugin/plugin.json` reads `"version": "1.5.0"`.

Comparing `skills/*/SKILL.md` between the 1.2.0 root and the 1.5.0 root:

- `work-item/SKILL.md` — byte-identical.
- `close/SKILL.md` — 402 lines at 1.2.0, 480 at 1.5.0; the 1.5.0 body carries a
  per-repo merge-and-switch-back section the 1.2.0 body has no counterpart for,
  and its touch check reads one list built from every hosting repo rather than
  from canonical.
- `plan-spine/SKILL.md` — 471 lines at 1.2.0, 488 at 1.5.0.
- `doctor/SKILL.md` — 455 lines at 1.2.0, 477 at 1.5.0.
- Every other `skills/*/SKILL.md` present at both roots — byte-identical.

This session ran `/ossify:close` on work item `WI-14` ninety minutes ago and
completed it. A spine close on `SP-3` is the next queued ceremony.

The session's plugin resolution table was built when the session started. Forty
minutes into the session the operator ran `/plugin update ossify` in a different
terminal; the table has not been rebuilt since.

**The rest of the project is healthy.** These facts are stated so no health
state has to be inferred; nothing below is in dispute.

`.ossify/topology.json` at `/Users/ops/pulse-trader/` resolves on the walk-up
path and declares exactly two keys: `canonical` (root
`/Users/ops/pulse-trader`) and `ai_workspace` (root
`/Users/ops/pulse-trader-ai`). Both roots exist as directories. `git -C
/Users/ops/pulse-trader rev-parse --is-inside-work-tree` prints `true`.
`oss state_path` resolves to
`/Users/ops/pulse-trader-ai/.ossify/project-state.json`, which exists.
`$OSS_STATE_FILE` is unset. `AGENTS.md` exists at
`/Users/ops/pulse-trader-ai/AGENTS.md` and carries an `## Ossify ceremonies`
heading.

`oss doctor` prints `ok: schema`, `ok: replay`, `ok: shape` and returns rc 0.
No lock file is present. The ledger holds no pending amendments and no
quarantined lines. No fake is outstanding. No patch record is open.
`/Users/ops/pulse-trader/.worktrees/` holds one directory, `SP-3-item-2`, and
work item `SP-3-item-2` in state claims it. `/Users/ops/pulse-trader-ai/`
has no `.worktrees/` directory.

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
