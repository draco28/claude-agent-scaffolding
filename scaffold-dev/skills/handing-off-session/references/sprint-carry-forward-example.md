# Sprint carry-forward handoff (worked example)

The sprint -> sprint(N+1) carry-forward is a special handoff (SPEC §6b.1 + §6b.6): it survives sprint-close cleanup. This walks through the sprint-3 -> sprint-4 transition.

## When this fires

End-of-sprint-3. `writing-sprint-retrospective` skill has run; the user is about to close sprint-3. Multiple sprint-3 handoffs exist in `.workspace/handoffs/` (bug-fix detours, mid-slice context recoveries, etc.). All except one will be cleaned up.

The user invokes:

```
/handoff --scope sprint --purpose 3-to-4
```

The skill body detects the `sprint` scope and the explicit `N-to-N+1` purpose pattern, and emits the carry-forward variant (which is structurally identical to a normal handoff but named so cleanup rules treat it specially).

## Naming

Per SPEC §6b.1: `sprint-N-to-N+1-handoff-XXXX.md`

For this example: `sprint-3-to-4-handoff-g7h8.md`

The naming pattern is what triggers preservation at sprint-close cleanup (SPEC §6b.6). All other handoffs matching `sprint-3-*.md` get wiped; this one survives.

## Resulting file

Path: `<ai-workspace>/.workspace/handoffs/sprint-3-to-4-handoff-g7h8.md`

```markdown
# Handoff — sprint-3 to sprint-4 carry-forward

## 1. Header

- Type: forward (carry-forward variant)
- Scope: sprint (sprint-3 closing, sprint-4 starting)
- Purpose: bootstrap sprint-4 with retained sprint-3 context that didn't make it to memory bank
- Source session metadata:
  - Author: orchestrator session that ran sprint-3 retrospective
  - Authored at: 2026-05-28T16:30Z
  - Sprint-3 retrospective: `docs/specs/sprint-3/sprint-retrospective.md` (closed at this time)
  - Short-id: g7h8

## 2. Purpose

Sprint-3 closed with 4 slices delivered (VS-3.1 through VS-3.4). Three patterns observed
across slices didn't reach codification — they're either too thin to promote yet, or they
need a sprint-4 instance to triangulate. This carry-forward preserves them so sprint-4's
first slice can pick them up.

## 3. State pointers

- AI workspace: `/Users/draco/projects/insight-platform-ai`
- Canonical: `/Users/draco/projects/insight-platform`
- Sprint just closed: sprint-3 (4 slices: VS-3.1, VS-3.2, VS-3.3, VS-3.4)
- Sprint about to open: sprint-4 (planned: VS-4.1, VS-4.2 per ROADMAP.md)
- Canonical main HEAD at sprint-3 close: `d8e9f12`
- Active context cursor (post-retrospective): "sprint-3 closed; ready to start sprint-4"

## 4. What's NOT in memory bank yet

Three observations from sprint-3 retrospective that the harvest queue surfaced but did
NOT codify (user chose 'defer'):

- **Pattern: auth dependencies should raise, never return None.** Surfaced in VS-3.2 (bug-fix
  detour) and again in VS-3.4 (the new `verify_session_cookie` dep also had a return-None path
  initially, caught in review). Two instances is suggestive but I want a third before promoting
  to `02-system-patterns.md`. sprint-4 will likely add a third auth integration; that's when
  this pattern earns its keep.

- **Pattern: dashboard cards take an `empty_state` prop with default rendering.** Used in VS-3.2
  (action-needed card) and VS-3.3 (recent-activity card). Tempted to promote, but the two
  implementations diverge on a key detail (3.2 takes a node, 3.3 takes a string + icon).
  Resolve the API divergence before codifying. sprint-4 VS-4.1 (notifications card) will need
  the same prop — that's the natural moment to standardize.

- **Process: architect-critic moment-1 audit has surfaced an avg of 3 spec gaps per slice.**
  Worth tracking — if this stays high, the spec-authoring step needs revision (maybe a
  pre-audit checklist). One sprint is not enough data; carry-forward to track sprint-4.

## 5. Workflow deviations

None during sprint-3 itself. The only minor deviation: I started sprint-3 without a previous
carry-forward (sprint-3 was a clean start) — so this is the FIRST carry-forward this project
generates. Useful as a reference instance for future sprint transitions.

## 6. In-flight state

None. Sprint-3 closed cleanly:
- All sprint-3 slices retrospectives written.
- All sprint-3 slice worktrees removed.
- All sprint-3 slice branches deleted (post-merge).
- Sprint-3 retrospective doc written + committed.
- No open work items, no open subagents, no merge conflicts.

## 7. Must read before doing anything

- This carry-forward handoff (start here)
- `docs/specs/sprint-3/sprint-retrospective.md` — the sprint-3 retro doc (full context)
- `ROADMAP.md` — sprint-4 plan (VS-4.1, VS-4.2 entries)
- `.claude/memory-bank/06-progress.md` — should now reflect sprint-3 done

## 8. Next intended action(s)

Primary: start sprint-4 planning.

Recommended sequence:
1. Confirm sprint-4 slices match ROADMAP.md (VS-4.1 notifications, VS-4.2 admin-tools-export).
2. Choose first slice to plan (default VS-4.1 unless user prefers different order).
3. Invoke `planning-vertical-slice` with "plan VS-4.1" or `/orchestrate VS-4.1`.
4. As VS-4.1 progresses, watch for the carry-forward §4 patterns:
   - If VS-4.1's notifications work surfaces a third auth-dependency instance, surface the
     "auth raises, never returns None" pattern for promotion at VS-4.1 slice-close harvest.
   - If VS-4.1's notifications card is built, standardize `empty_state` prop API with VS-3.2
     and VS-3.3 implementations; the harmonization itself may be its own work item.
   - If VS-4.1's spec audit surfaces 3+ gaps again, log to this carry-forward's "process" entry.

## 9. Anti-actions

- Do NOT delete sprint-3 retrospective doc — that's a permanent artifact.
- Do NOT delete this carry-forward handoff at sprint-4 close UNLESS its §4 items have all
  been promoted or rejected (per SPEC §6b.6, the carry-forward becomes a sprint-4 artifact
  eligible for cleanup at sprint-4 close).
- Do NOT start sprint-4 slices before reading this handoff. The §4 patterns are the reason
  the carry-forward exists.
- Do NOT carry sprint-3 unfinished work into sprint-4 silently — if any slice slipped, it
  should be visible in ROADMAP.md as a sprint-4 entry, not hidden in this handoff.

## 10. Return-handoff template stub

(Not applicable. Carry-forwards don't expect a return — they're a one-way bootstrap from
sprint N close to sprint N+1 start.)
```

## Sprint-close cleanup behavior

When `closing-vertical-slice` (or the v0.2 `closing-sprint` skill if that materializes per SPEC §6b.6) runs sprint-close cleanup, it executes:

```bash
# Wipe all sprint-3-scope handoffs EXCEPT the carry-forward
find <ai-workspace>/.workspace/handoffs -name 'sprint-3-*.md' \
  ! -name 'sprint-3-to-*-handoff-*.md' -delete

find <ai-workspace>/.workspace/handoffs -name 'vs-3.*-*.md' -delete
```

After cleanup, `.workspace/handoffs/` contains only `sprint-3-to-4-handoff-g7h8.md` (the carry-forward) and any unmatched orphans (e.g., a sprint-2 carry-forward that was never consumed).

## When the carry-forward itself gets cleaned up

At sprint-4 close, the carry-forward becomes a sprint-4 artifact (the §4 items have either been promoted by sprint-4 slice harvests or are still pending). Sprint-4's cleanup pass treats it like any other sprint-4 handoff: wipe unless it's the sprint-4-to-5-handoff. So `sprint-3-to-4-handoff-g7h8.md` gets deleted at sprint-4 close, replaced by `sprint-4-to-5-handoff-i9j0.md` (if sprint-5 is starting).

The retention is exactly one sprint boundary. Older sprint transitions are preserved only via:
- The sprint retrospective doc (permanent)
- Memory bank entries that got promoted from the handoff's §4
- Git history of the handoffs dir IF the handoffs dir were tracked (it's gitignored per §6b.1)

## Why gitignored

Handoffs are durable per-machine, NOT synced. Per SPEC §6b.1: handoffs are machine-local because they capture ephemeral session-specific context that loses meaning when synced to another developer's session. The artifacts that DO travel are the slice retrospective + memory bank promotions — those are the codified outputs of the handoff lifecycle.
