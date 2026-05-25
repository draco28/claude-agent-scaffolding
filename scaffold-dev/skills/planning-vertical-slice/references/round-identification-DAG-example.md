# Round identification DAG worked example — VS-3.2

How the planning-vertical-slice skill body computes the strict-layer DAG and surfaces rounds to the user (SPEC §5.4). Builds on the 5-item decomposition from `decomposition-worked-example.md`.

## Input — decomposed work items

```
work-3.2.01  Backend query + endpoint            deps: none
work-3.2.02  Frontend card component             deps: none
work-3.2.03  Dashboard integration               deps: 3.2.01, 3.2.02
work-3.2.04  Chatbot intent handler              deps: 3.2.01
work-3.2.05  End-to-end integration test         deps: 3.2.03, 3.2.04
```

## Step 1 — Build dependency graph

Nodes = work items; directed edges = "depends on". Edges (child -> parent):

```
3.2.03 -> 3.2.01
3.2.03 -> 3.2.02
3.2.04 -> 3.2.01
3.2.05 -> 3.2.03
3.2.05 -> 3.2.04
```

## Step 2 — Strict-layer topological sort

Strict-layer DAG: each round is a "layer" of items with all dependencies in earlier rounds. An item with parents in round K is placed in round K+1 (never K, even if it has spare capacity in K).

Pass 1 — items with no deps in remaining set:
- 3.2.01 (deps: none) -> R1
- 3.2.02 (deps: none) -> R1

Pass 2 — remove R1 items; items with deps satisfied by R1:
- 3.2.03 (deps 3.2.01, 3.2.02 -> both in R1) -> R2
- 3.2.04 (dep 3.2.01 -> in R1) -> R2

Pass 3 — remove R2 items; items with deps satisfied by R1+R2:
- 3.2.05 (deps 3.2.03, 3.2.04 -> both in R2) -> R3

## Step 3 — Default proposal to user

Skill surfaces:

```
Proposed rounds (strict-layer DAG, runnable in parallel within round):

Round 1 (parallel):
  - work-3.2.01: Backend query + endpoint
  - work-3.2.02: Frontend card component

Round 2 (parallel, after R1 merges):
  - work-3.2.03: Dashboard integration
  - work-3.2.04: Chatbot intent handler

Round 3 (serial; only item):
  - work-3.2.05: End-to-end integration test
```

## Step 4 — User adjustment (loosen OR tighten)

Two adjustment moves are allowed (SPEC §5.4):

**Loosen — move item earlier.** Only valid if no dependency would be violated. Example: user proposes "move 3.2.04 to R1." Skill checks: 3.2.04 deps on 3.2.01 which is in R1 -> dep WOULD be violated -> refuse with reason.

**Tighten — split a round.** Always allowed; soft-ordering only. Example: user proposes "split R1 — do 3.2.01 first, then 3.2.02 alone after 3.2.01 commits." Skill accepts:

```
Round 1 (serial):
  - work-3.2.01: Backend query + endpoint

Round 2 (serial; was R1.b):
  - work-3.2.02: Frontend card component

Round 3 (parallel; was R2):
  - work-3.2.03
  - work-3.2.04

Round 4 (serial; was R3):
  - work-3.2.05
```

Skill notes: "Tightening reduces parallelism but is always safe. User reason logged in slice README." User confirms reason: "I want to validate the API contract from 3.2.01 before kicking off 3.2.02."

## Step 5 — Final round table

| Round | Items | Mode |
|---|---|---|
| R1 | 3.2.01 | serial |
| R2 | 3.2.02 | serial |
| R3 | 3.2.03, 3.2.04 | parallel |
| R4 | 3.2.05 | serial |

This is what gets written to the slice's `README.md` at scaffold-time (per §5.5).

## Edge cases the skill body handles

- **Cycle detected.** If the decomposition produces a cycle (e.g., A -> B -> A), skill HALTS with an error naming the cycle and asks user to fix decomposition. Cycles are a decomposition bug, not a round-id bug.
- **All items independent.** Single round, all parallel. Valid.
- **All items serial.** One item per round. Valid but flag for user: "All items serial — is this slice over-decomposed?"
- **Round with > 4 parallel items.** Soft warning surfaced: "Round K has 5+ parallel items; orchestrator session token cost will spike. Consider tightening." User can accept or split.

## What "parallel" means at execution

Within a round, the orchestrator dispatches one implementer-agent subagent per work item via the Task tool. Returns are processed in decomposition order (SPEC §13), not return order, so "parallel" here means parallel SUBAGENTS, not parallel orchestrator processing. The orchestrator still verifies + merges work items in declared order.

## Output

After this step, the skill writes the round assignments to the same transient state buffer. The next step (spec authoring, see `architect-critic-invocation-example.md`) consumes both decomposition + round assignments to author all per-work-item specs upfront.
