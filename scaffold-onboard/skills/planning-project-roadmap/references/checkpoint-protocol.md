# Checkpoint Protocol — Save-And-Resume, Time Budgets, Re-Run Modes

> Companion reference for `planning-project-roadmap` §5 (state), §6 (time budget), and §9 (re-run modes). Read this when you need the full picture of *every place this skill can pause, save, resume, or replay* — and what `project-roadmap.json` looks like through each transition.

---

## 1. Checkpoint taxonomy

The skill surfaces four distinct kinds of checkpoint, plus one warning, plus five re-run modes. Each is independent of the others; they coexist.

| Kind | Trigger | User choice | State write |
|---|---|---|---|
| Sub-phase boundary (R1.A → R1.B) | R1.A complete | continue / pause | `checkpoint = "R1.A-complete"` |
| Sub-phase boundary (per-phase, R1.B mid) | All sprints captured for a phase | continue / pause | `checkpoint = "R1.B"` (still mid-sub-phase) |
| Sub-phase boundary (R1.B → R1.C) | All sprints captured | continue / pause | `checkpoint = "R1.B-complete"` |
| Sub-phase boundary (per-sprint, R1.C mid) | All slices+criteria captured for a sprint | continue / pause | `checkpoint = "R1.C"` (still mid-sub-phase) |
| 60-min advisory | `elapsed_min` first crosses 60 | continue / pause (default no) | none (transient) |
| 90-min warn-only | `elapsed_min` first crosses 90 | continue / pause (default no) | none (transient) |

Plus the terminal write at the very end: `checkpoint = "R1.C-complete"` once architect-critic returns and ROADMAP.md is emitted.

---

## 2. The three sub-phase boundary checkpoints

These are the natural seams in the flow. Each is **proactive** — the skill prompts before advancing.

### 2.1 Checkpoint 1: R1.A → R1.B

After all 3-6 phases are named and persisted, the skill writes `checkpoint="R1.A-complete"` and prompts:

> Phases captured (N total). Continue to sprints, or pause here and resume with `/plan-roadmap --resume`?

- **User accepts** ("yes" / "continue") → surface size-class adaptation (§7 of SKILL.md) if `nodes_estimate > 50`, then open R1.B with its verbatim framing prompt.
- **User declines** ("no" / "pause") → stop, leaving `checkpoint="R1.A-complete"`. Next `/plan-roadmap --resume` re-enters at R1.B.

### 2.2 Checkpoint 2: per-phase within R1.B

After all sprints for a single phase are captured, the skill prompts:

> Sprints captured for Phase N (M total). Continue to the next phase's sprints, or pause and resume with `/plan-roadmap --resume`?

- `checkpoint` stays at `"R1.B"` (still mid-sub-phase); the `sprints[]` array records progress.
- The skill knows which phase to re-enter at by scanning `sprints[]` against `phases[]` — see §4 (mid-sub-phase resume).
- After the LAST phase's sprints are captured, the skill writes `checkpoint="R1.B-complete"` and surfaces an R1.B → R1.C boundary prompt (analogous to Checkpoint 1).

### 2.3 Checkpoint 3: per-sprint within R1.C

After all slices + demo criteria for a single sprint are captured, the skill prompts:

> Slices captured for Sprint N.M (K total, each with demo criteria). Continue to next sprint's slices, or pause and resume?

- `checkpoint` stays at `"R1.C"` during R1.C; `vertical_slices[]` tracks progress.
- After ALL sprints' slices are captured, the skill moves to §10 (architect-critic close moment) → ROADMAP.md emission → terminal `checkpoint="R1.C-complete"` write.

### 2.4 Why three boundary checkpoints (not one)

Each is a natural cognitive break: the user just finished one kind of work (phase-naming, or sprint-naming-for-this-phase, or slice-authoring-for-this-sprint) and is about to start another. Offering pause there means *the user doesn't have to choose between "finish the whole thing today" or "stop in an awkward mid-question state"*. They can stop cleanly at any of three seams and resume with no lost context.

---

## 3. The 60-min advisory + 90-min warn-only checkpoints

These are **time-based**, fire mid-sub-phase, and are orthogonal to the boundary checkpoints. Per SPEC §5.4 + §7.3, both are **warn-only** — the skill never unilaterally pauses. Agency belongs to the user.

### 3.1 60-min proactive advisory

When `sf_roadmap_read_elapsed` first crosses 60 minutes AND the current `checkpoint` is NOT at a natural boundary (R1.A-complete / R1.B-complete / R1.C-complete), surface this **before** asking the next authoring question:

> ~60 min elapsed. Checkpoint and continue tomorrow with `/plan-roadmap --resume`? (yes/no, default no)

- Fires **once per session crossing the threshold**. Do not re-prompt.
- No state-file write — this is a courtesy nudge, not a contract.
- If user declines: continue to the next authoring question.
- If user accepts: stop. State is already persisted at the last node write (R1.B per-sprint, R1.C per-slice). Next `/plan-roadmap --resume` re-enters at the next unanswered question.

### 3.2 90-min warn-only

When `elapsed_min` first crosses 90 minutes:

> ~90 min elapsed — past the advisory budget. Strongly suggest checkpoint via `/plan-roadmap --resume` later. Continue anyway? (yes/no, default no)

- Still warn-only. **This is not a unilateral pause.** Per SPEC §7.3 + §5.4 (the warn-only enforcement clause): the skill does NOT force-stop at 90 min. The user retains agency.
- Fires once per session.
- If user accepts the offer: stop cleanly (same as 60-min accept).
- If user declines: continue. No further prompts about time elapsed — at this point the user has explicitly chosen to push past the advisory budget.

### 3.3 Why warn-only (not hard-stop)

A unilateral hard-stop at 90 min would mean the skill takes choice away from the user mid-authoring. That's a bigger failure mode than slightly over-running the budget: the user has all the context loaded in their head, they may be 5 questions away from R1.C close, forcing them to stop and resume tomorrow throws away that context.

The warning is real (the budget exists for a reason — fatigue degrades roadmap quality), but the *choice to stop* belongs to the user. The skill's job is to surface the signal clearly, not to override the user's judgment.

---

## 4. Resume via `--resume`

`/plan-roadmap --resume` re-enters the flow at the next unanswered question, regardless of which sub-phase you were in.

### 4.1 Top-level routing

On entry:

1. Call `sf_roadmap_state_mode`. If `new` (no state file): error — `--resume` requires existing state. Stop.
2. If `rerun` (state shows `checkpoint="R1.C-complete"`): `--resume` is invalid in re-run mode. Route to the re-run mode prompt (§5 below). Stop.
3. Otherwise (`resume`): read `checkpoint` and re-enter.

### 4.2 Sub-phase routing

The `checkpoint` field reflects the **highest-completed boundary**, not the actual cursor:

| `checkpoint` value | Re-entry point |
|---|---|
| `"R1.A"` | Mid-R1.A. Scan `phases[]`; re-ask phase N+1 where N = `phases.length`. |
| `"R1.A-complete"` | R1.B boundary. Surface R1.B intro + first sprint question for phase 1. |
| `"R1.B"` | Mid-R1.B. Scan `sprints[]` grouped by `phase_id`; find first phase whose sprint count is below the per-phase target (or the next phase entirely); re-ask its next sprint. |
| `"R1.B-complete"` | R1.C boundary. Surface R1.C intro + first slice question for sprint 1.1. |
| `"R1.C"` | Mid-R1.C. Scan `vertical_slices[]` grouped by `sprint_id`; find first sprint whose slice count is below the per-sprint target; re-ask its next slice. |
| `"R1.C-complete"` | Terminal. ROADMAP.md exists. Route to re-run mode (§5). |

### 4.3 Mid-sub-phase re-entry: worked example

Say `checkpoint="R1.B"` with state:

```json
{
  "phases": [{"id": 1, ...}, {"id": 2, ...}, {"id": 3, ...}],
  "sprints": [
    {"phase_id": 1, "id": "1.1", ...},
    {"phase_id": 1, "id": "1.2", ...},
    {"phase_id": 1, "id": "1.3", ...},
    {"phase_id": 2, "id": "2.1", ...},
    {"phase_id": 2, "id": "2.2", ...}
  ]
}
```

Interpretation:
- Phase 1 has 3 sprints captured (assume that matches user's stated count → phase 1 done).
- Phase 2 has 2 sprints captured (user said "3 sprints for phase 2" earlier → 1 sprint remaining).
- Phase 3 has 0 sprints captured (untouched).

Re-entry point: ask sprint 2.3 (the next unauthored sprint in phase 2). The skill should announce:

> Resuming at R1.B — sprints for Phase 2 (2 captured, 1 to go before Phase 3). Next: tell me about Sprint 2.3.

After 2.3 lands, surface Checkpoint 2 for phase 2 (per-phase boundary), then open phase 3.

### 4.4 The first announcement on resume

Always announce position before asking the next question. The user has context-switched out of this flow (potentially days ago) and needs orientation. The pattern:

> Resuming at \<sub-phase\> — \<concrete progress summary\>. Next: \<the specific next question\>.

Eval S2 explicitly checks for this acknowledgement. Skipping it is a fail.

---

## 5. Re-run protocol's five modes

When `checkpoint="R1.C-complete"` AND ROADMAP.md exists at the routing destination: the skill is in **re-run mode**, not resume mode. Re-run never restarts the full R1.A/B/C walk (that would destroy the user's prior work).

The five modes are **surgical**: each touches a small slice of the hierarchy and preserves everything else.

### 5.1 Mode 1: `--add-phase`

**Purpose:** project scope grew; one new phase needs decomposition.

**What it preserves:** all existing phases, sprints, slices, criteria.

**What it walks:**
1. R1.A for one new phase (surface verbatim framing + capture name/horizon/summary).
2. R1.B for that one phase's sprints (verbatim framing + capture).
3. R1.C for each new sprint's slices + demo criteria (verbatim framing + `authoring-vertical-slice-demo` invocations).
4. architect-critic close audit on the appended subtree only (not the full roadmap).
5. Re-emit ROADMAP.md.

**State mutation:** append to `mutations[]`:

```json
{"at": "<ISO8601>", "mode": "add-phase", "added_id": <new_phase_id>}
```

### 5.2 Mode 2: `--add-sprint <phase_id>`

**Purpose:** an existing phase needs another sprint inserted (e.g., between 2.2 and 2.3, or after 2.3).

**Error if** `phase_id` is not in `phases[]`. Surface: *"Phase {id} not found. Existing phases: {list}."*

**What it preserves:** all existing phases, all existing sprints (including the target phase's existing sprints), all existing slices.

**What it walks:**
1. R1.B for ONE new sprint under the named phase (verbatim framing + capture).
2. R1.C for the new sprint's slices + criteria.
3. architect-critic close audit on the new sprint subtree only.
4. Re-emit ROADMAP.md.

**State mutation:**

```json
{"at": "<ISO8601>", "mode": "add-sprint", "target": "phase_<phase_id>", "added_id": "<sprint_id>"}
```

**ID assignment:** new sprint's `id` is `<phase_id>.<next_index>` where `next_index = max(sprints.where(phase_id == p).id.suffix) + 1`. Mid-insertion (between 2.2 and 2.3) is NOT supported in v0.2 — new sprint always appends. If user wants an inserted sprint, they hand-edit ROADMAP.md afterward and the next `--reorganize` accepts it.

### 5.3 Mode 3: `--add-slice <sprint_id>`

**Purpose:** an existing sprint needs another slice (e.g., VS-1.1.3 emerged from VS-1.1.2 closing).

**Error if** `sprint_id` is not in `sprints[]`. Surface: *"Sprint {id} not found. Existing sprints: {list}."*

**What it preserves:** everything except this sprint's slice list (which grows by one).

**What it walks:**
1. R1.C for ONE new slice under the named sprint (verbatim framing + capture name/summary).
2. Invoke `Skill(scaffold-onboard:authoring-vertical-slice-demo)` for 1-3 demo criteria.
3. architect-critic close audit on the slice (depth=close, target=single slice).
4. Re-emit ROADMAP.md.

**State mutation:**

```json
{"at": "<ISO8601>", "mode": "add-slice", "target": "sprint_<sprint_id>", "added_id": "<slice_id>"}
```

### 5.4 Mode 4: `--refine-slice <slice_id>`

**Purpose:** an existing slice's name, summary, or demo criteria need rework.

**Error if** `slice_id` is not in `vertical_slices[]`. Surface: *"Slice {id} not found. Existing slices: {list}."*

**What it preserves:** all OTHER slices; the target slice's siblings; phase + sprint structure entirely.

**What it walks:**
1. Re-prompt for the slice's name (current value shown as default; accept-as-is or edit).
2. Re-prompt for the summary (same pattern).
3. Re-invoke `authoring-vertical-slice-demo` against the slice — demo criteria authoring is idempotent (matches by text equality, tops up without duplicating).
4. architect-critic close audit on the slice.
5. Re-emit ROADMAP.md.

**State mutation:**

```json
{"at": "<ISO8601>", "mode": "refine-slice", "target": "<slice_id>"}
```

(No `added_id` — refine doesn't add a node.)

### 5.5 Mode 5: `--reorganize`

**Purpose:** major project pivot; structure needs full rework, but existing items should be preserved as starting points.

**What it preserves:** every existing phase / sprint / slice as an *editable default*. User accepts-as-is, edits, or deletes each.

**What it walks:**
- Full R1.A → R1.B → R1.C re-walk with each existing entry pre-loaded.
- For each phase: skill restates the existing name/horizon/summary, asks "accept / edit / delete?".
- Same pattern for sprints under each phase.
- Same pattern for slices under each sprint (demo criteria re-walked via `authoring-vertical-slice-demo`).
- architect-critic close audit on the full roadmap (depth=close — same as initial authoring's close moment).
- Re-emit ROADMAP.md.

**State mutation:** one summary entry:

```json
{"at": "<ISO8601>", "mode": "reorganize"}
```

(Per SPEC §7.5 + SKILL.md §9, fine-grained mutations within reorganize defer to OQ4 v0.3+. The minimum honest v0.2 implementation appends one mutation entry per `--reorganize` invocation.)

### 5.6 Default re-run prompt (no flag)

If user runs bare `/plan-roadmap` against a closed roadmap, surface the mode picker:

> ROADMAP.md is already authored. Five surgical modes available:
>
> 1. `--add-phase` — Walk R1.A for one new phase only; offer R1.B + R1.C for that phase.
> 2. `--add-sprint <phase_id>` — Walk R1.B for one new sprint in named phase; offer R1.C for it.
> 3. `--add-slice <sprint_id>` — Walk R1.C for one new slice in named sprint.
> 4. `--refine-slice <slice_id>` — Walk R1.C for one existing slice.
> 5. `--reorganize` — Full re-walk; preserves existing items; user accepts/edits each.
>
> Which mode? (1/2/3/4/5)

Hard-fails on ambiguous re-author intent (per SPEC §7.5) — never silently restart R1.A.

---

## 6. `mutations[]` array — audit trail

Every non-initial change to the hierarchy appends an entry to `project-roadmap.json`'s `mutations[]` array. This produces a per-roadmap audit trail showing how the structure evolved after initial authoring.

Schema:

```json
"mutations": [
  {"at": "2026-07-12T14:30:00Z", "mode": "add-sprint", "target": "phase_2", "added_id": "2.4"},
  {"at": "2026-07-19T09:15:00Z", "mode": "add-slice", "target": "sprint_2.4", "added_id": "VS-2.4.3"},
  {"at": "2026-08-02T16:00:00Z", "mode": "refine-slice", "target": "VS-1.1.2"},
  {"at": "2026-09-01T11:00:00Z", "mode": "reorganize"}
]
```

The initial R1.A → R1.B → R1.C authoring does NOT produce mutations entries. Only re-run modes do.

Mutations are append-only. The skill never rewrites or deletes mutation entries — that would corrupt the audit trail. If a user wants to "undo" a mutation, they re-run a compensating mutation (e.g., `--refine-slice` to walk back a slice that was added by an earlier `--add-slice`).

---

## 7. Edge case: ROADMAP.md exists but `project-roadmap.json` is missing

Scenario: user hand-edited ROADMAP.md without going through `/plan-roadmap` (e.g., they wrote it from scratch in their editor, or they copied it from another project as a starting template). Now they run `/plan-roadmap` and the skill sees:

- ROADMAP.md present at routing destination.
- `project-roadmap.json` absent in the current project's `sf project_data_dir`.

This is a **reconciliation moment**. The skill cannot pretend it's a fresh authoring (would conflict with the existing file) and cannot pretend it's a re-run (no state to walk back from). Surface a two-path prompt:

> Found ROADMAP.md at <path>, but no `project-roadmap.json` state — looks like ROADMAP.md was hand-authored or copied in. Two options:
>
> 1. **Import** — I'll parse ROADMAP.md into `project-roadmap.json` (best-effort; you can correct any mismatches), then enter re-run mode with all five surgical modes available.
> 2. **Hand-edit only** — keep editing ROADMAP.md directly; the skill stays out of the way. (No `--add-phase` / `--refine-slice` etc. without state.)
>
> Which? (1/2, default 1)

**If user picks 1 (Import):**
- Parse the ROADMAP.md markdown shape per SPEC §7.1 into a draft `project-roadmap.json`.
- Surface the parsed state for user confirmation: *"Detected N phases, M sprints, K slices. Anything wrong before I save state?"*.
- Accept user corrections (in-conversation edits to the draft), then write `project-roadmap.json` with `checkpoint="R1.C-complete"` + an initial mutation entry: `{"mode": "import", "at": "<ISO8601>", "source": "ROADMAP.md"}`.
- Now treat as normal re-run mode: prompt for one of the five modes per §5.6.

**If user picks 2 (Hand-edit only):**
- Stop. Leave ROADMAP.md untouched. Don't write `project-roadmap.json`.
- Surface: *"Got it — I'll stay out of the way. Re-run `/plan-roadmap` later and pick option 1 if you want surgical re-run modes."*.

The import path is best-effort, not guaranteed lossless. If ROADMAP.md deviates from the SPEC §7.1 shape (missing demo-criteria sub-sections, non-standard slice IDs, etc.), the skill surfaces what it could and could not parse, and lets the user decide whether to fix ROADMAP.md or override the state file directly.

---

## 8. State transitions diagram (text form)

```
                             [no state file]
                                  │
                                  ▼
                          sf_roadmap_state_init
                                  │
                                  ▼
                          checkpoint="R1.A"
                                  │
                  (R1.A authoring, persist per-phase)
                                  │
                                  ▼
                       checkpoint="R1.A-complete"
                                  │ (Checkpoint 1 offered)
                                  ▼
                  (R1.B opens; size-class adapt fires if needed)
                                  │
                          checkpoint="R1.B"
                                  │
              (per-phase sprint authoring, Checkpoint 2 per phase)
                                  │
                                  ▼
                       checkpoint="R1.B-complete"
                                  │
                                  ▼
                          checkpoint="R1.C"
                                  │
            (per-sprint slice authoring, Checkpoint 3 per sprint;
             authoring-vertical-slice-demo invoked per slice)
                                  │
                                  ▼
                  architect-critic close audit fires
                                  │
                                  ▼
                         ROADMAP.md emitted
                                  │
                                  ▼
                       checkpoint="R1.C-complete"
                                  │
                       (terminal state reached)
                                  │
                                  ▼
              `/plan-roadmap` re-entry → re-run mode (§5)
              `/plan-roadmap --resume` → error (no resume from terminal)
```

Mid-flow, the 60-min and 90-min time-based advisories may fire once each, regardless of which sub-phase the skill is in. Both are warn-only and never mutate `checkpoint`.

---

## 9. Practical reminders

- **State persists per-node**, not per-sub-phase. A mid-R1.B interruption never loses R1.A's phases. (SKILL.md §5, discipline bullet 1.)
- **The 60-min and 90-min checkpoints are advisory only.** No unilateral pause. (SPEC §5.4 + §7.3.)
- **`--resume` and the five re-run modes are mutually exclusive.** Resume re-enters mid-flow; re-run modes operate on a closed roadmap. The skill detects which applies via `sf_roadmap_state_mode` at entry.
- **architect-critic fires at every meaningful close moment**: initial R1.C close (full roadmap), and re-run mode closes (scoped to the affected subtree, except `--reorganize` which is full-roadmap).
- **mutations[] is append-only.** Treat it as an audit trail, not a mutable working set.
