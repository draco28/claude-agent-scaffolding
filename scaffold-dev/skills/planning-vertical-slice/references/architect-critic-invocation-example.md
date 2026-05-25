# Architect-critic invocation worked example — moment 1 (spec audit)

Full request/response shape for the planning-vertical-slice skill body's first architect-critic invocation: the spec-authoring audit BEFORE round 1 (SPEC §16.3 moment 1).

## Where this happens in the lifecycle

After:
1. Decomposition settles (`decomposition-worked-example.md`)
2. Rounds identified (`round-identification-DAG-example.md`)
3. Skill authors all per-work-item specs upfront under `docs/specs/sprint-3/VS-3.2-insights-action-needed-card/` (per SPEC §5.5)
4. Skill offers grill-me on specs (SPEC §16.4 offer 2) — user may accept or skip

Before:
5. Round-1 worktree creation + handoff authoring + implementer-agent subagent dispatch

## Step 1 — Probe for architect-critic

Lazy filesystem probe (SPEC §16.3):

```bash
ls ~/.claude/plugins/cache/*/architect-critic/*/skills/critiquing-spec/SKILL.md 2>/dev/null | head -1
```

If exit 0 with non-empty output -> architect-critic present, proceed. If empty -> warn user "architect-critic not detected; spec audit skipped" and skip to step 6.

## Step 2 — Prepare invocation context

Context the skill body assembles for critic:

- **Slice README path:** `docs/specs/sprint-3/VS-3.2-insights-action-needed-card/README.md`
- **All work-item specs:** `docs/specs/sprint-3/VS-3.2-insights-action-needed-card/work-3.2.0{1,2,3,4,5}-*/spec.md` (5 files)
- **Round plan:** R1=3.2.01; R2=3.2.02; R3=3.2.03,3.2.04; R4=3.2.05
- **Demo criteria:** 3 criteria (1 auto, 2 user) — from ROADMAP.md
- **Memory-bank pointers:** `.claude/memory-bank/02-system-patterns.md` + `04-tech-context.md` (Tier 1 branch-load)

## Step 3 — In-conversation skill invocation

The skill body triggers architect-critic's `critiquing-spec` skill the same way Claude triggers any skill — by description-match or explicit invocation. NOT via inbox/outbox file IPC. The trigger phrase:

> "Run an architect-critic audit on the just-authored specs for VS-3.2. Context: 5 work-item specs + slice README + round plan. Depth: claude-self-audit (close depth deferred to slice-close adversarial review per SPEC §14.3). Schema: standard challenges/gaps/alternatives output. Persist run to architect-critic state.json."

Critic responds in conversation; orchestrator's skill body is paused until critic returns control.

## Step 4 — Critic output (example)

Critic produces a structured challenge list. Sample output (excerpted):

```
### Challenges (T=3 minimum concession threshold)

C1. work-3.2.01 spec §3 "Decisions baked in" omits the auth policy
    for `GET /api/insights/action-needed`. Is the endpoint authenticated?
    If so, what auth mechanism (session cookie / bearer token / both)?
    Severity: high — auth is a fundamental contract; underspec leaves
    the implementer-agent guessing.

C2. work-3.2.02 spec AC-2 reads: "Card renders correctly in loading
    state." No measurable verification — "correctly" is unspecified.
    Recommend: AC-2 becomes "Card renders a skeleton-loader element
    matching `[data-test-id='action-needed-skeleton']` while fetch is
    pending." Severity: medium — implementer-agent's AC verification
    step (§6.2 pre-flight) will flag this as a gap.

C3. work-3.2.05 spec §6 "Verification" specifies one pytest command.
    But demo criterion 1 is the SAME pytest command — so this work
    item exists ONLY to make the demo pass, which means the work item
    is a tautology relative to the demo. Severity: low — defensible
    but worth surfacing.

### Gaps (potentially missing decisions)

G1. No work item addresses the empty-state design for the card
    (when action_needed table has 0 rows for the user). Should be a
    spec'd AC on work-3.2.02 OR a separate work item.

G2. work-3.2.04 doesn't specify chatbot framework. Reuses existing
    intent infrastructure? Implementer-agent will probe — but spec
    should pre-decide.

### Alternative framings

A1. Could collapse 3.2.03 + 3.2.05 — the dashboard-integration work
    item could OWN the end-to-end test instead of carving it out.
    Trade-off: tighter ownership but conflates concerns.
```

## Step 5 — User rebuttal cycle

Critic runs the T=3 concession-scoring rubric. For each challenge:

```
C1: Concede / Counter / Defer?
> User: "Concede. Add to 3.2.01 spec §3: session cookie auth, return
  401 on unauth. Will edit before round-1 dispatch."
```

```
C2: Concede / Counter / Defer?
> User: "Concede. Revise 3.2.02 AC-2 to the data-test-id form."
```

```
C3: Concede / Counter / Defer?
> User: "Counter. The work item exists because the integration test
  file is new code — the test ITSELF is the deliverable. The demo
  criterion runs the SAME pytest because that's how we verify the
  test passes against the merged stack. Not a tautology — it's the
  intentional shape of an end-to-end gate."
```

Critic scores: C1 = 5 (full concession), C2 = 5, C3 = 2 (defer; counter accepted but logged). Run summary persisted to architect-critic state.json. Auto-promotion check: if any principle has hit threshold per architect-critic v0.2 settlements, surface promotion candidate.

## Step 6 — Control returns to orchestrator

Critic exits. planning-vertical-slice skill body resumes:

1. Apply spec edits per accepted challenges (C1 to 3.2.01 spec; C2 to 3.2.02 spec; G1 and G2 surfaced for user decision).
2. Surface to user: "Audit complete. 2 specs edited; 2 gaps require your decision: (G1) empty-state on 3.2.02, (G2) chatbot framework for 3.2.04. Reply with decisions to proceed."
3. After user resolves gaps -> spec authoring done. Surface: "VS-3.2 specs authored and audited; ready for round-1 execution."
4. Skill EXITS. User must explicitly start round-1 (`continue VS-3.2` or equivalent) in a follow-up turn. Round-1 execution is NOT autopiloted off the back of the audit.

## What the skill body does NOT do at this gate

- Does NOT spawn implementer-agent subagents.
- Does NOT create worktrees in canonical.
- Does NOT make commits.
- Does NOT advance to slice-close (that's a separate skill, `closing-vertical-slice`).

## Graceful degradation

If architect-critic is NOT installed:
- Skill body skips Step 1-5.
- Surfaces to user: "architect-critic not installed; spec audit skipped. Specs are authored but unreviewed. Proceed with round-1 at your own discretion, or install architect-critic and re-run."
- Skill EXITS (same as success path).

## Cost note (SPEC §16.3)

This invocation runs claude-self-audit only (in-conversation, no Codex subprocess). Cost: ~$0.05-0.15 per slice. The close-depth invocation with Codex subprocess happens at slice close (moment 2, §14.3) — that's the higher-cost band (~$0.10-0.40 total per VS across both moments).
