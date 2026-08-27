# Changelog

## 0.1.0 — VS1, the mirror
- New plugin. Projects `.ossify/project-state.json` onto a Huly project: releases → milestones,
  spines → issues (task type Spine), work items → sub-issues (Work item), spine_dag → is-blocked-by.
- Digest-gated async Stop hook; `/board:sync` forces a reconcile and binds on first run;
  `/board:doctor` reports env, reachability, last sync and drift.
- Idempotent workspace setup on the hand-made `Ossify project` space type (seeded with its
  first task type `Spine` by hand — the CLI can only copy an existing task type): the second
  task type, statuses named after ossify's, an `agent` role without delete.
- Never deletes on Huly. Bare binding for repos not on ossify.
- Typed project creation is UI-only — the CLI cannot do it. `/board:sync` reports rc 6 with
  instructions to create the project in Tracker by hand, then rerun with `--bind`.
- Optional `HULY_EMAIL`: sync self-ensures the harness account is a member of the project's
  space before mirroring — Huly gates read visibility by space membership, so a non-member's
  writes persist but its own reads come back empty, silently producing blind duplicates.
