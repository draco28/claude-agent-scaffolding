# Sprint aggregation worked example — sprint-3 retrospective

The `writing-sprint-retrospective` skill aggregates VS retrospectives + cross-slice patterns into a sprint-level retro (SPEC §16b). This walks through aggregating sprint-3 which contained 4 slices.

## Inputs

Skill body reads:

- All slice retrospectives in sprint-3:
  - `docs/specs/sprint-3/VS-3.1-pipeline-scaffolding/retrospective.md`
  - `docs/specs/sprint-3/VS-3.2-insights-action-needed-card/retrospective.md`
  - `docs/specs/sprint-3/VS-3.3-recent-activity-card/retrospective.md`
  - `docs/specs/sprint-3/VS-3.4-admin-tools-export/retrospective.md`
- Sprint plan from `ROADMAP.md` (the sprint-3 block: goal, planned slices, demo at sprint level)
- The current carry-forward from sprint-2 (`sprint-2-to-3-handoff-*.md`) for any items that were carried forward and should now resolve

## Output

Path: `docs/specs/sprint-3/sprint-retrospective.md`

Per SPEC §16b sprint retrospective format — 6 sections.

## Worked output

```markdown
# Sprint-3 retrospective

## 1. Sprint metadata

- Sprint: 3
- Phase: 3 (post-MVP polish)
- Duration: 2026-05-12 -> 2026-05-28 (16 days; planned 14)
- Slices delivered: 4 (VS-3.1, VS-3.2, VS-3.3, VS-3.4)
- Slices planned: 4
- Carry-forward consumed: sprint-2-to-3-handoff-z9y8.md (2 items resolved, 0 deferred again)
- Carry-forward authored: sprint-3-to-4-handoff-g7h8.md (3 items pending sprint-4 triangulation)

## 2. Sprint goal vs delivered

**Planned goal (from ROADMAP.md):** "Ship the insights surface — backend pipeline, two
dashboard cards (action-needed, recent-activity), chatbot intent integration, and admin
tools export."

**Delivered:** All 4 slices closed. Demo verification: 4/4 slices passed automated demos;
3/4 passed all manual demos; VS-3.2 had 1 partial manual demo (chatbot wording bug)
resolved via fix-up round.

**Variances:**
- Sprint ran 2 days over plan. Root cause: VS-3.2 fix-up round (chatbot wording) added
  ~6 hours unplanned. Not a process miss — fix-up handling worked as designed.
- VS-3.1 (pipeline scaffolding) was easier than estimated (4 days actual vs. 6 planned).
- Net effect: 14 + 6h fix-up - 2 days early on VS-3.1 = roughly +2 days. Acceptable.

## 3. Per-slice rollup

| Slice | Work items | Rounds | Auto demo | Manual demo | Critic findings | Fix-up rounds |
|---|---|---|---|---|---|---|
| VS-3.1 | 3 | 2 | 1/1 pass | 1/1 pass | 2 surfaced, 2 conceded | 0 |
| VS-3.2 | 5 | 4 | 1/1 pass | 1/2 pass, 1 partial | 3 surfaced, 2 conceded, 1 deferred | 1 (chatbot wording) |
| VS-3.3 | 4 | 2 | 1/1 pass | 1/1 pass | 1 surfaced, 1 conceded | 0 |
| VS-3.4 | 3 | 1 | 1/1 pass | 2/2 pass | 0 | 0 |

Total work items: 15. Total rounds: 9. Total critic challenges: 6 (avg 1.5/slice); 5 conceded (83%).

## 4. Cross-slice patterns

Two patterns observed across multiple sprint-3 slices:

### Pattern A — Frontend cards take an `empty_state` prop

- VS-3.2 (`<ActionNeededCard />`) and VS-3.3 (`<RecentActivityCard />`) both implemented
  empty-state rendering via a prop.
- API divergence: VS-3.2 takes a React node; VS-3.3 takes a string + icon name.
- Decision in VS-3.2 harvest: defer to sprint-4 when a third card (notifications, VS-4.1)
  triangulates the API.
- Status at sprint-3 close: 2 instances, divergent API. Pending VS-4.1 triangulation.

### Pattern B — Auth dependencies must raise

- VS-3.2 (bug-fix detour) and VS-3.4 (new `verify_session_cookie` dep) both surfaced the
  silent-failure-on-None anti-pattern.
- VS-3.2 fixed it on the existing `verify_bearer_token`. VS-3.4 designed the new dep
  correctly (raises by default).
- Status at sprint-3 close: 2 instances aligned. ADR 0008 captured the product decision.
  Pending: a third instance (VS-4.1) to motivate promoting to memory-bank/02-system-patterns.md.

## 5. Memory bank impact totals

Aggregated across all 4 slice harvests:

- Accepted (promoted to memory bank): 6 entries
  - 02-system-patterns.md: 4 entries (API auth, chatbot intent registration, dashboard
    grid layout, frontend empty_state pattern outline)
  - 03-code-patterns.md: 1 mcrule (banned_imports for raw sqlalchemy.orm.Session)
  - 04-tech-context.md: 1 entry (mypy not yet configured; backlog item BL-127)
- Backlog (deferred to backlog, not memory bank): 4 items (BL-127 through BL-130)
- Rejected: 2 items (too implementation-detail)
- Deferred to sprint-3-to-4 carry-forward: 3 items (the patterns above + 1 process item)

Total candidate items considered: 15 (across all 4 slice retrospectives' harvest tables).

## 6. Lessons for next sprint

### Lesson 1 — Spec audit catches the same gap class repeatedly

Architect-critic moment-1 audits surfaced "missing auth mechanism" gaps in 2 of 4 slices.
This is a recurring spec authoring miss. Action for sprint-4: add a pre-audit checklist
to planning-vertical-slice that explicitly prompts for auth mechanism on every endpoint-touching
work item. Carry to sprint-3-to-4-handoff process notes.

### Lesson 2 — Fix-up rounds work, but eat schedule

VS-3.2's chatbot-wording fix-up round (1 round, ~6h) was handled cleanly by the slice-close
ceremony halt-and-fix-up path. But it ate schedule. Action: if a slice fails 1+ manual demo
criteria, that's a signal to budget an extra 0.5-1 day in the slice estimate. Update
planning-vertical-slice's effort-estimation prompt.

### Lesson 3 — Pattern triangulation cadence

Two patterns this sprint hit 2 instances but need a 3rd before promoting to memory bank.
Carry-forward is the right mechanism for these. Caution: if a pattern lingers 2+ sprints
without a 3rd instance, that's a signal it's an over-fit — re-evaluate at sprint-5 close.

## 7. Reference index

- Slice retrospectives:
  - `docs/specs/sprint-3/VS-3.1-pipeline-scaffolding/retrospective.md`
  - `docs/specs/sprint-3/VS-3.2-insights-action-needed-card/retrospective.md`
  - `docs/specs/sprint-3/VS-3.3-recent-activity-card/retrospective.md`
  - `docs/specs/sprint-3/VS-3.4-admin-tools-export/retrospective.md`
- ADRs authored this sprint:
  - `docs/adr/0008-auth-dependencies-must-raise.md` (product, canonical)
  - `<ai-workspace>/docs/adr/0008-strict-layer-dag-rationale.md` (process, ai workspace)
- Carry-forward handoff: `<ai-workspace>/.workspace/handoffs/sprint-3-to-4-handoff-g7h8.md`
- Sprint plan reference: `ROADMAP.md` (sprint-3 block)
```

## Aggregation logic — how the skill body fills each section

### Section 1 (metadata)
Pure extraction from ROADMAP.md + slice retrospectives' headers + filesystem inspection (handoffs dir).

### Section 2 (goal vs delivered)
The goal text comes from ROADMAP.md. The delivered summary is computed from per-slice retros — for each slice, was demo verification fully clean? Variances: compare planned vs. actual sprint duration.

### Section 3 (per-slice rollup)
Table extraction from slice retros. Skill body reads each slice retro's §2 (demo verification) and §3 (architect-critic findings) to populate the columns. Heavy lifting is per-slice retro authoring (which the closing-vertical-slice skill did). Here the work is aggregation.

### Section 4 (cross-slice patterns)
The hardest section to author automatically. Skill body looks for patterns surfaced in MULTIPLE slice retros' §3 (architect-critic findings) or §6 (lessons learned). When the same theme appears 2+ times, surface as a candidate cross-slice pattern. User confirms / edits / adds patterns the skill missed.

### Section 5 (memory bank impact totals)
Read each slice retro's §4 (memory bank harvest); count accepted/backlog/rejected/deferred. Aggregate. Lookup memory bank file commits in that sprint window for cross-check.

### Section 6 (lessons for next sprint)
User-authored primarily. Skill body offers prompts based on patterns + variances:
- "Did anything happen in this sprint that's worth changing in the process?"
- "Are any cross-slice patterns mature enough to codify?"
- "Did effort estimates correlate with actuals?"
Captures user responses. Optionally invokes ai-mentor:grill-me if user wants to stress-test their lessons.

### Section 7 (reference index)
Filesystem-derived. List slice retro paths, ADRs in the sprint window, carry-forward handoff path.

## Anti-patterns

- **Slice-retro copy-paste.** The sprint retro is NOT a concatenation of slice retros. It's aggregation + cross-slice synthesis. If the sprint retro reads like 4 slice retros stapled together, the synthesis step was skipped.
- **Empty cross-slice patterns.** A sprint with no observed cross-slice pattern is rare. If §4 comes out empty, the skill body likely missed something — re-prompt user to look for patterns.
- **Process changes without justification.** Lessons (§6) should cite the slice + observation that motivates the change. "Add a checklist" without "because VS-3.2 and VS-3.4 hit the same gap" is weak.
- **Carry-forward conflation.** The §6 lessons feed into the carry-forward, but they're not the same thing. Lessons are sprint-retrospective content (permanent). Carry-forward is ephemeral bootstrap context for sprint(N+1). Keep separate.
