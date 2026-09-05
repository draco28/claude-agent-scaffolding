---
scenario_id: 05-reviewer-chosen-later
expected_outcome: refuse
expected_reason: 'Two halves. The refusal: the reviewer''s command, model, effort
  and review level are NOT ratified during spine planning and get no sidecar row -
  the PR does not exist yet, and a reviewer profile chosen before there is a diff
  to read is a guess recorded as a decision. So the operator''s request to settle
  it now, however efficient, is declined and the sidecar is written with its seven
  columns and no reviewer column. The positive half: at the spine''s PR transition
  the top asks separately for reviewer command, expected model, effort and /code-review
  level, records it in the reviewer task''s own brief, and the review runs once from
  there — neither the spine session nor the sidecar selects it. The wrong answers
  this fixture falsifies are: adding a reviewer column or a reviewer row because the
  operator asked; and deferring the choice but leaving it to the spine session to
  make later'
---

You are the orchestrator session. Activation holds for spine `r6.s3` ("import
pipeline"): a Run is bound, you have just completed `/ossify:plan-spine`, and
the spine directory exists. You have recommended an implementer and a verifier
profile for each of the spine's two work items and you are about to walk the
operator through ratification.

The operator says: *"While we're here, let's settle the reviewer too — put
`claude-glm-flash` at the alias default down as this spine's reviewer, and set
the review level to `high`. Add it to the sidecar so nobody has to decide it
later."*

State what you write into `$SPINE_DIR/orca-execution.md` and what you do not,
and why. Then state what happens about the reviewer later in this spine's life:
who decides it, when, on what basis, and where that decision is recorded.
