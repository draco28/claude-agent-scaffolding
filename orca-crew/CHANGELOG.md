# Changelog

All notable changes to the `orca-crew` plugin.

## 0.2.0

Session budget and plan-time routing, triggered by measured session spray: 66 GLM
sessions in one day (Sep 2), 33 and 49 tasks per run, many one-question verifiers
and "correction" sessions that spent their budget orienting.

- **D7** — the default worker is `claude-glm` at high, retained; flash is for
  read-only probes, mechanical verification, and bounded fast items.
- **D8** — plan-time routing: each work item carries a complexity class
  (`contract` → `claude-glm`, `bounded` → `claude-glm-flash`); unclassified
  defaults to `claude-glm`.
- **D9** — session budget, hard cap: one implementer and at most one verifier per
  work item; one reviewer per PR and at most one verifier per fix round; further
  read-only questions go to the existing session by `send`.
- **D10** — retention to half the window: past ~50% (500k on `glm-5.3`) or an
  auto-compact, checked by `/context` at each task boundary, the implementer
  writes a handoff and the next item starts fresh.
- **D11** — corrections travel by message: one bounded `send`/`reply` to the live
  session; a correction session is never created.
- **D12** — new findings route through the orchestrator (#410): an implementer
  resolves a thread only after the disposition.
- **D13** — verification is one all-claims brief and one report per work item;
  `claude-glm` at high unless every claim is mechanical.

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
