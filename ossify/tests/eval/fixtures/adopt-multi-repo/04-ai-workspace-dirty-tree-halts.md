---
scenario_id: 04-ai-workspace-dirty-tree-halts
expected_outcome: halt
expected_reason: A3's sweep covers the AI workspace as well as every declared repo — generalizing "iterate the declared repos" must not silently drop the AI workspace check, since C5 edits it too; a dirty line there halts adoption even though every declared repo is clean and on its default branch
---

`.ossify/topology.json` declares two repos: `canonical`
(root `/Users/ops/repos/product-api`, default branch `main`) and
`svc-billing` (root `/Users/ops/repos/svc-billing`, default branch `main`).
A0-A2 pass.

At A3, `git -C /Users/ops/repos/product-api status --porcelain` and
`git -C /Users/ops/repos/svc-billing status --porcelain` both print nothing,
and both repos are checked out on `main`. But
`git -C <ai-workspace-root> status --porcelain` prints one line:
` M docs/MASTER-SPEC.md` — an in-progress hand-edit the operator started
before invoking `/adopt` and never committed.

No live worktrees exist under either repo's `.worktrees/`, and the legacy
stack's active-context cursor sits on a boundary.
