# Decomposition worked example — VS-3.2

A concrete walkthrough of the sketch-first-then-refine decomposition flow (SPEC §5.3) for a fictional slice. Use this as a teaching reference when the planning-vertical-slice skill body proposes a 4-5 work-item draft.

## Slice under decomposition

From `ROADMAP.md` (excerpt):

```
#### VS-3.2: insights-action-needed-card

Surface an "action needed" insight card on the dashboard, sourced from
the action_needed table, refreshed via the daily insight pipeline, and
reachable from the chatbot panel.

##### Demo criteria
- [ ] auto: `pytest tests/integration/test_insight_pipeline.py` -> expected: exit 0
- [ ] user: Navigate to localhost:3000/insights -> expected: action-needed card visible with real data
- [ ] user: Click chatbot icon and type "what's overdue?" -> expected: response within 5s
```

Sprint context: sprint-3, Phase 3 (post-MVP polish). Prior slice VS-3.1 shipped the insights table schema and pipeline scaffolding. VS-3.2 builds the demoable end-user surface on top.

## Step 1 — Sketch (first pass, 60-90 seconds)

The skill body reads MASTER-SPEC §3.2 + the slice's demo criteria + memory-bank `02-system-patterns.md` and proposes a draft. The draft is intentionally rough — coverage and shape matter more than precision.

**Draft proposal surfaced to user:**

1. work-3.2.01 — Backend query layer: add `select_action_needed_for_user(user_id)` to `db/insights.py`; wire to FastAPI endpoint `GET /api/insights/action-needed`.
2. work-3.2.02 — Frontend card component: `<ActionNeededCard />` React component; fetches the endpoint; renders empty / loading / populated states.
3. work-3.2.03 — Dashboard integration: mount the card on `/insights` route; wire to layout grid; add e2e test for visibility.
4. work-3.2.04 — Chatbot intent wiring: add "what's overdue" intent handler in `chatbot/intents/`; reuses the same query layer from 3.2.01.
5. work-3.2.05 — Integration tests + demo verification: `pytest tests/integration/test_insight_pipeline.py` end-to-end (the auto: criterion).

## Step 2 — Refine (interactive with user)

Skill surfaces the draft and asks: "Does this decomposition cover the slice's demo criteria? Anything missing or over-scoped?"

User response (typical): "3.2.04 feels like it should depend on 3.2.01 being merged. And does 3.2.05 actually need its own work item or does the test go in 3.2.03?"

Skill responds:
- Confirms dependency: 3.2.04 reads from the same query layer 3.2.01 introduces -> hard dep.
- Considers merge: the auto: demo step is an integration test that spans backend + frontend + chatbot. Keeping it as its own work item (3.2.05) means a single owner runs the end-to-end gate; folding into 3.2.03 conflates dashboard-integration concerns with cross-slice verification. Recommend keep separate.

User: "OK, keep 3.2.05 separate. Promote 3.2.01 to the first round and 3.2.04 to a later round so it doesn't race."

## Step 3 — Final decomposition (5 items)

| ID | Title | Dependencies | Round |
|---|---|---|---|
| work-3.2.01 | Backend query + endpoint | none | R1 |
| work-3.2.02 | Frontend card component | none (uses contract-only of 3.2.01) | R1 |
| work-3.2.03 | Dashboard integration | 3.2.01 merged, 3.2.02 merged | R2 |
| work-3.2.04 | Chatbot intent handler | 3.2.01 merged | R2 |
| work-3.2.05 | End-to-end integration test | 3.2.03 + 3.2.04 merged | R3 |

Round identification follows the worked DAG example in `round-identification-DAG-example.md`. The skill body does not run round-id yet — that's the next phase of the lifecycle.

## Step 4 — Grill-me offer (SPEC §16.4 offer 1)

After the decomposition settles, the skill body offers (lazy probe, see SKILL.md):

> "Decomposition settled at 5 work items. Want to grill-me this before authoring specs? (ai-mentor:grill-me will interrogate the decomposition one question at a time.) Reply 'yes' to invoke, 'no' to skip."

If user accepts: invoke `ai-mentor:grill-me` skill in-conversation with the decomposition as context. Common challenges surfaced:
- "Why is 3.2.02 in R1 if 3.2.01 hasn't merged?" -> because 3.2.02 builds against a contract (TypeScript types), not a running endpoint.
- "Is 3.2.05 actually a work item or a closing-slice ceremony step?" -> it's a work item because the test ITSELF is new code (the integration test file didn't exist before).

User may revise decomposition based on grill-me. Skill re-surfaces the table.

## Step 5 — Confirmation gate

Before proceeding to round identification, skill surfaces:

> "Confirm decomposition (5 work items, IDs 3.2.01-3.2.05)? Reply 'yes' to advance to round identification, or name changes inline."

On 'yes' -> proceed. On edits -> revise table -> re-surface.

## Anti-patterns surfaced during decomposition

- **Single mega-work-item.** "Build the action-needed card." Too coarse — no AC granularity for the implementer-agent subagent to verify. Refused at sketch.
- **Tech-debt-only work item.** "Refactor db/insights.py for clarity." Belongs in a separate slice, not gating demo criteria. Refused — promoted to backlog.
- **Pure-test work item with no implementation hook.** "Add tests for the insight pipeline." If the tests verify ALREADY-shipped behavior, they're a quality-gate task, not a slice work item. work-3.2.05 escapes this only because the integration test is genuinely new (covers the new cross-component flow).

## Output

After this step, the skill writes the work-item identifiers + titles to a transient state buffer (in conversation; not yet on disk). Round identification consumes this buffer (see `round-identification-DAG-example.md`). Spec authoring (see `architect-critic-invocation-example.md`) consumes the round + work-item assignments.
