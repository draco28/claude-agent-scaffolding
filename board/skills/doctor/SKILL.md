---
name: doctor
description: Diagnose the board mirror — env present, Huly reachable, repo bound, when it last synced and whether it failed, and drift between the Huly board and .ossify/project-state.json (status mismatches, unowned issues, orphans). Use when the user says board doctor, is the board in sync, why didn't huly update, /board:doctor. Reports only; never mutates.
---

# doctor

You read and report. Nothing here writes to Huly or to the repo.

Every command below invokes `board` and `huly-run` bare, from `PATH` — the harness puts each
installed plugin's `bin/` there. Never spell paths with `${CLAUDE_PLUGIN_ROOT}`: that
variable is not exported into Bash-tool subprocesses and expands empty. If `command -v
board` finds nothing, say the board plugin is not installed and stop.

## 1. Environment and reachability

Run `board env-check` and report all four lines — the three required variables and the
optional `HULY_EMAIL` status (it says whether membership self-ensure is available). If the
three required ones are set, run `huly-run auth status --json` and report the workspace it
resolves and whether it is authenticated. A failure here is the finding; stop after
reporting it.

## 2. Binding and last sync

First resolve the workspace root: the nearest ancestor of `$PWD` (including itself) carrying
`.ossify/project-state.json` — the same walk `board digest "$PWD"` does. Every read below is
against that root, never bare `$PWD`: run from a subdirectory, a relative read misses the
root-level `.board/` and misreports a bound repo as unbound.

Read `<root>/.board/config.json` (the project identifier) and `<root>/.board/sync.json`
(`synced_at`, `digest`). Compare the digest with `board digest "$PWD"`: equal means the
source file is unchanged since the last successful sync — it does not prove the board
matches, because a hand edit on Huly leaves the digest equal; §3 is what detects that.
Different means a sync is pending or failed. Show the last five lines of
`<root>/.board/sync.log` if it exists — each line is one failed sync with the CLI's error
code.

No `.board/config.json` at the root but a `.ossify/project-state.json`: the repo is not
bound; point at `/board:sync`. No `.ossify/` anywhere up the walk: say the repo is not on
ossify and only a bare binding applies.

## 3. Drift

Compute the desired board yourself, from the root's state file:
`jq -f "$(dirname "$(command -v board)")/../lib/map.jq" <root>/.ossify/project-state.json`.
Fetch the actual one: `huly-run issues list --project <IDENT> --limit 200 --json` and
`huly-run milestones list --project <IDENT> --limit 200 --json` (without `--limit`,
milestones default to 50). If either list's length equals its limit it may be truncated —
the CLI has no pagination — so report the drift comparison as inconclusive and stop rather
than reporting phantom missing entities or orphans. Field shapes differ between the two
lists: a milestone's title lives in `.label`, an issue's in `.title`, and an issue's status
may be `.status` or `.status.name` — inspect the JSON you actually received before
comparing. An issue's labels arrive as objects keyed `title` (`[{"title": "spine:bone", ...}]`),
not bare strings. Either list may arrive wrapped in a top-level `result` field
(`{"result": [...]}`) instead of a bare array — this happens when the result set includes an
issue created by an account with no person record; unwrap before comparing.

One shape of report is untrustworthy: **both lists empty while the desired board is not**.
Huly gates read visibility by space membership — a token that is authenticated but not a
member of the project's space gets empty lists, not errors, and "everything is missing"
would send the user to a sync that creates blind duplicates. Report that case as
inconclusive and point at membership (#350 tracks a first-class check). Then report, as
short lists:

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
