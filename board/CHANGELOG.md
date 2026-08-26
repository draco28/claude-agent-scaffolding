# Changelog

## 0.1.0 — VS1, the mirror
- New plugin. Projects `.ossify/project-state.json` onto a Huly project: releases → milestones,
  spines → issues (task type Spine), work items → sub-issues (Work item), spine_dag → is-blocked-by.
- Digest-gated async Stop hook; `/board:sync` forces a reconcile and binds on first run;
  `/board:doctor` reports env, reachability, last sync and drift.
- Idempotent workspace setup on the hand-made `Ossify project` space type: task types,
  statuses named after ossify's, an `agent` role without delete.
- Never deletes on Huly. Bare binding for repos not on ossify.
