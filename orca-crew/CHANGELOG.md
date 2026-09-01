# Changelog

All notable changes to the `orca-crew` plugin.

## 0.1.0

Initial release. One prose skill, no runtime library.

- `orchestrate` — the orchestrator/worker session model over Orca orchestration: the
  delegation floor, the role table with alias and effort per role, the twelve-step run,
  four self-contained brief templates, the ossify seam, and the refusals.
- `/orca-crew:orchestrate [objective]` loads the skill and binds the Run.

Design boundaries, stated once here:

1. The skill states one Orca mechanic itself (launch by alias with `terminal create`
   then `dispatch --inject`, because `worker-start --agent` cannot take a custom alias)
   and defers every other command to `orca skills get orchestration`.
2. A review runs once per PR and returns findings only through `worker_done`. GitHub
   review threads are a second stream the retained implementer works to zero.
3. ossify keeps every contract; this plugin sorts its commands between the orchestrator
   session and dispatched sessions and edits no ossify prose.
4. No per-project role map. The aliases are the roles.

Not in the OpenCode bundle in this release.
