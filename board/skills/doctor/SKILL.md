---
name: doctor
description: Diagnose the board mirror — env present, Huly reachable, repo bound, when it last synced and whether it failed, and drift between the Huly board and .ossify/project-state.json (status mismatches, unowned issues, orphans). Use when the user says board doctor, is the board in sync, why didn't huly update, /board:doctor. Reports only; never mutates.
---

# doctor

You read and report. Nothing here writes to Huly or to the repo.

## 1. Environment and reachability

Run `bash ${CLAUDE_PLUGIN_ROOT}/bin/board env-check` and report the three lines. If all are
set, run `bash ${CLAUDE_PLUGIN_ROOT}/bin/huly-run auth status --json` and report the
workspace it resolves and whether it is authenticated. A failure here is the finding; stop
after reporting it.

## 2. Binding and last sync

Read `.board/config.json` (the project identifier) and `.board/sync.json` (`synced_at`,
`digest`). Compare the digest with `bash ${CLAUDE_PLUGIN_ROOT}/bin/board digest "$PWD"`:
equal means the board reflects the current file; different means a sync is pending or
failed. Show the last five lines of `.board/sync.log` if it exists — each line is one
failed sync with the CLI's error code.

No `.board/config.json` but a `.ossify/project-state.json`: the repo is not bound; point at
`/board:sync`. No `.ossify/` at all: say the repo is not on ossify and only a bare binding
applies.

## 3. Drift

Compute the desired board yourself: `jq -f ${CLAUDE_PLUGIN_ROOT}/lib/map.jq .ossify/project-state.json`.
Fetch the actual one: `bash ${CLAUDE_PLUGIN_ROOT}/bin/huly-run issues list --project <IDENT> --limit 200 --json`
and `... milestones list --project <IDENT> --json`. Field shapes differ between the two
lists: a milestone's title lives in `.label`, an issue's in `.title`, and an issue's status
may be `.status` or `.status.name` — inspect the JSON you actually received before
comparing. Then report, as short lists:

- **Status, label, or milestone mismatches** — same title key but a different status; a
  spine whose `spine:<class>` label disagrees with the file; an issue attached to a
  milestone whose title does not start with its release key (compare labels and milestone
  only when those fields are present in the JSON you received). These are hand edits on
  Huly the next sync will overwrite, or a failed sync. Say which, using §2.
- **Unowned issues** — titles that do not start with an ossify id (`r1`, `r1.s1`,
  `r1.s1.w3`) and carry no `wayfinder:` label. Usually a title someone edited; the next
  sync will create a duplicate beside it.
- **Orphans** — ossify-keyed issues with no matching id in the file.
- **Missing** — desired entities with no issue or milestone yet.

Zero in all four is the healthy report; say so in one line. Descriptions are not compared
in VS1 — do not report description drift.
