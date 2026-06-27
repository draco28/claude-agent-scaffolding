# test-amend-spec — `/amend-spec` behavioral fixture checklist

**Behavioral checklist (scaffold-onboard v0.12, #86 / SS-8).** `/amend-spec`
(`amending-spec`) is the **agent-driven** front door for incrementally amending an
existing `MASTER-SPEC.md` — classify a change → impact analysis → **targeted** spec
edit + revision trail → fold the rationale into the durable SSoT → hand off
propagation. The logic is skill prose (no deterministic helper, no ID-minting
engine, no diff-merge engine), so these are **manual** behavioral checks — consistent
with the plugin's skill-first design. Design of record:
`docs/agent-driven-program/specs/SS-8-amend-spec.md`.

## How to use

For each fixture:

1. Start a fresh Claude Code session with scaffold-onboard v0.12 installed.
2. Set up the named precondition, then run the trigger.
3. Inspect the behavior against **Expected**. It passes if the behavior matches
   (language need not match word-for-word; the structural facts must hold).
4. Check the box, or annotate FAIL with what actually happened.

## Status legend

- RED — known to fail in current tree
- GREEN — confirmed passing in a live session

---

## Fixtures (12 total)

### A1 — absent spec routes to /onboard (does not scaffold)

| Field | Value |
|---|---|
| Setup | A directory with **no** `MASTER-SPEC.md` at the resolved path |
| Trigger | `/amend-spec add an audit-logging NFR` |
| Expected | Surfaces a routing message ("no MASTER-SPEC.md … author it via `/onboard` first") and **stops**. Does NOT scaffold or stub a spec. |
| Status | GREEN (target) |

### A2 — pure maintenance routes to /defer (no spec edit)

| Field | Value |
|---|---|
| Setup | A valid `MASTER-SPEC.md` present |
| Trigger | `/amend-spec bump the linter to v9 and fix the flaky CI cache` |
| Expected | Classifies as **pure maintenance / tech-debt**, routes to `/defer`, and makes **no** edit to `MASTER-SPEC.md`. |
| Status | GREEN (target) |

### A3 — impact analysis precedes the edit (confirmation gate)

| Field | Value |
|---|---|
| Setup | A valid `MASTER-SPEC.md` (ideally with derived SRS/BACKLOG present) |
| Trigger | `/amend-spec on-disk format changes must ship a tested, non-destructive migration path` |
| Expected | Before editing, presents an impact analysis — **which phase section** it lands in, which existing requirements/slices it touches, and the **prospective** new NFR — and asks for confirmation. No silent edit. |
| Status | GREEN (target) |

### A4 — targeted edit + revision trail (version field pinned)

| Field | Value |
|---|---|
| Setup | A4 follows A3, user confirms |
| Trigger | (confirm the amendment) |
| Expected | Folds the change into the **right phase section** (a targeted fold, not a section rewrite, marker preserved); appends a dated `## Revision History` entry outside phase-marker content (before the first phase marker, not EOF); adds/bumps `**Spec revision:**`; **leaves `**Spec version:**` at `1.0`**; re-validates with `sf spec_validate`. |
| Anti-pattern (FAIL) | Bumping `**Spec version:**`; rewriting the whole phase section; placing revision history after Phase 10; editing SRS/BACKLOG |
| Status | GREEN (target) |

### A5 — SSoT fold-forward into the phase_record

| Field | Value |
|---|---|
| Setup | A valid spec **with** `onboarding-state.json` present (`sf state_mode` ≠ `new`) |
| Trigger | amend any net-new/NFR change through to the edit |
| Expected | Reads the affected phase's `phase_record`, **preserves all existing fields**, merges a short amendment note, and writes the complete object back via `sf state_write_phase_record`. The note survives a later `/onboard --regenerate` (reconciled forward, not clobbered). |
| Anti-pattern (FAIL) | Dropping existing record fields; leaving the amendment only in `MASTER-SPEC.md` |
| Status | GREEN (target) |

### A6 — no state → fold skipped with a note

| Field | Value |
|---|---|
| Setup | A valid `MASTER-SPEC.md` but **no** `onboarding-state.json` (legacy/external spec; `sf state_mode` = `new`) |
| Trigger | `/amend-spec add a rate-limit NFR` |
| Expected | Still edits the spec + revision trail, but **skips** the `phase_record` fold and says so (nothing to clobber without state). Does not error out or fabricate a state file. |
| Status | GREEN (target) |

### A7 — EXEC-SUMMARY judged, not silently reproduced

| Field | Value |
|---|---|
| Setup | A valid spec + `EXECUTIVE-SUMMARY.md` present |
| Trigger | amend a small hardening NFR (summary arguably unaffected) |
| Expected | Checks staleness; if the summary prose is unaffected, **flags it stale-by-design** ("refreshes at the next onboarding close") rather than silently re-rendering. If summary-worthy, updates the `## Executive Summary` section in MASTER-SPEC and refreshes only on explicit user agreement by writing a fresh H2 summary body and calling `sf render_executive_summary_from_synthesized "$master" "$exec" "$(sf project_name)" "$(sf spec_project_class "$master")"`. |
| Anti-pattern (FAIL) | Silently re-rendering EXECUTIVE-SUMMARY as a second producer; invoking the helper against an already-rendered H1 EXEC-SUMMARY with no fresh H2 body |
| Status | GREEN (target) |

### A8 — propagation handoff is honest about whole-bundle re-derive

| Field | Value |
|---|---|
| Setup | amendment completed |
| Trigger | (end of the flow) |
| Expected | Names `/scaffold-docs` to propagate + assign the requirement's ID, and **plainly flags** that today this re-derives the whole governance bundle (not a targeted low-churn update — deferred). Optionally offers `/plan-roadmap --add-slice` / a roadmap mutation stub using an existing mode such as `add-slice` with an `amend-spec:` note. |
| Status | GREEN (target) |

### A9 — orientation preamble + thin-context asks

| Field | Value |
|---|---|
| Setup | (a) a change request that names context vs (b) a bare directory with thin context |
| Trigger | `/amend-spec <change>` |
| Expected | Opens with a "📍 You are here" block (**Topic / Where-it-sits + weight / Why**) before the first question. In the thin-context case it **asks** for a one-line reminder rather than fabricating a location/rationale. |
| Expected markers | "📍" / "You are here" / "Topic" / "Where it sits" / "weight" / "Why" |
| Status | GREEN (target) |

### A10 — out-of-scope honesty (no doc edits, no ID minted)

| Field | Value |
|---|---|
| Setup | A valid spec with derived SRS/BACKLOG present |
| Trigger | `/amend-spec add a new export-to-CSV capability` then ask "did you update the SRS / what's its FR number?" |
| Expected | Confirms it did **not** edit SRS/BACKLOG/PRD and wrote **no** FR/NFR ID into any file; explains IDs are assigned by `/scaffold-docs` on re-derive, and that diff-aware doc merge + stable ID minting are deferred. |
| Anti-pattern (FAIL) | Claiming to have written `FR-N` into a doc; editing a derived doc |
| Status | GREEN (target) |

### A11 — lock/state safety on early exits

| Field | Value |
|---|---|
| Setup | (a) An active onboarding/amend lock already exists, or (b) `sf state_mode` returns `project_mismatch` after this invocation acquires the lock |
| Trigger | `/amend-spec add a retry-budget NFR` |
| Expected | In (a), surfaces lock contention and stops without calling `sf state_lock_release` (does not delete another session's lock). In (b), surfaces stored/current project roots, releases only the lock it acquired, and stops before reading or writing `phase_records`. Pure-maintenance early exits after a successful lock acquisition must release the acquired lock before routing to `/defer`. |
| Anti-pattern (FAIL) | Releasing a lock after failed acquisition; mutating mismatched onboarding state |
| Status | GREEN (target) |

### A12 — post-edit validation failure stops with state preserved

| Field | Value |
|---|---|
| Setup | A valid spec, then during the confirmed edit introduce a corrupted required marker or metadata line |
| Trigger | Continue the amendment through the §5 re-validation step |
| Expected | `sf spec_validate "$master"` rejects the edited spec; the flow surfaces the validation error, stops, and does not proceed to `phase_record` fold, EXEC-SUMMARY refresh, or roadmap mutation. The acquired lock is released. |
| Anti-pattern (FAIL) | Continuing propagation after validation failure; hiding the failed validation behind a successful summary |
| Status | GREEN (target) |

---

## Aggregate status

Total fixtures: **12.** Target GREEN on this tree: **12 / 12** (the amendment flow is
embedded in `skills/amending-spec/SKILL.md` as of #86 / SS-8). These are **manual**
behavioral checks — not automated — consistent with scaffold-onboard's skill-first,
agent-driven design (classification, impact analysis, and every edit are produced by
the agent, never by a script).
