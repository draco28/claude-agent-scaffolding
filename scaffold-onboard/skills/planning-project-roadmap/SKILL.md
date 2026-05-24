---
name: planning-project-roadmap
description: Drive the three-sub-phase (R1.A Phases → R1.B Sprints → R1.C Vertical Slices) interactive authoring of ROADMAP.md after MASTER-SPEC closes. Use this when the user wants to run /plan-roadmap, decompose into sprints, author project roadmap, build out the phase plan, plan the phase-sprint-slice hierarchy, or asks "what comes after onboarding?". Manages a separate project-roadmap.json state file with sub-phase checkpoints, surfaces the verbatim 3-timelines framing prompts, watches the 60-min advisory / 90-min warn-only time budget, invokes authoring-vertical-slice-demo per slice for demo criteria, and calls architect-critic at R1.C close. Re-runs via --add-phase / --add-sprint / --add-slice / --refine-slice / --reorganize modes; never writes to PROJECT_PLAN.md (that's /scaffold-docs's v0.1.0 timeline doc, owned by a different skill).
---

# planning-project-roadmap

You are the conductor of scaffold-onboard's R1 hierarchy authoring flow. After `MASTER-SPEC.md` has been authored and closed by `/onboard`, this skill walks the user through three sub-phases — R1.A (Phases), R1.B (Sprints per phase), R1.C (Vertical Slices per sprint) — and emits `ROADMAP.md`: the Phase → Sprint → Vertical Slice hierarchy that scaffold-dev v0.1's orchestrator-implementer cycle consumes as its R1 input contract (per scaffold-dev SPEC §16.2).

Bash helpers in `lib/roadmap.sh`, `lib/state.sh`, `lib/render.sh`, `lib/routing.sh`, and `lib/compose.sh` do the bookkeeping (state CRUD, atomic writes, template substitution, manifest path resolution, filesystem probes). The judgment work — how to frame each sub-phase intro, when to surface a size-class warning, whether the 60-min checkpoint offer is the right next thing to say, how to interpret a `TBD` slice answer — happens here, in conversation.

This skill is **interactive, not LLM-extractive**. It does NOT try to auto-decompose MASTER-SPEC.md into a hierarchy. The user authors the hierarchy with the skill's guidance; the skill prompts, persists answers, and routes the output (per SPEC §3.7 non-goal).

---

## 1. Overview

When invoked, you read MASTER-SPEC.md from the routing destination, open (or resume) `project-roadmap.json` state, and walk three sub-phases:

- **R1.A (~10-20 min)** — define 3-6 high-level **Phases** (visionary horizon)
- **R1.B (~30-50 min)** — define 2-4 **Sprints per phase** (value-building windows)
- **R1.C (~40-60 min)** — define 2-5 **Vertical Slices per sprint** + 1-3 demo criteria per slice (visibility cycles)

At each sub-phase boundary you persist a checkpoint and offer the user a save-and-resume escape hatch. At ~60 min elapsed you proactively offer a checkpoint (advisory). At 90 min you warn (still advisory — never unilaterally pause). At R1.C close you invoke `architect-critic:critiquing-spec` with `target=roadmap, depth=close`, then emit `ROADMAP.md` via `sf_resolve_output_path "roadmap" "ROADMAP.md"`.

If ROADMAP.md + project-roadmap.json both already exist with `checkpoint == "R1.C-complete"`: enter re-run mode (§9) and prompt the user to pick one of five surgical modes rather than restarting.

---

## 2. When to use

**Trigger phrases (description-match):**

- `/plan-roadmap` (slash command — see §12 for the `$ARGUMENTS` env-var bridge)
- "decompose into sprints", "author project roadmap", "build out the phase plan", "plan the phase-sprint-slice hierarchy"
- "what comes after onboarding?", "next step after MASTER-SPEC", "set up the project roadmap"
- "add a phase to the roadmap", "add a sprint", "add a vertical slice", "refine a slice's demo criteria"

**Do NOT auto-invoke when:**

- `MASTER-SPEC.md` does not exist at the routing destination. The roadmap is downstream of MASTER-SPEC; without a valid spec there is nothing to decompose against. Route the user to `Skill(scaffold-onboard:onboarding-project)` (or `/onboard`) and stop.
- The user wants governance documents (PRD, SRS, BACKLOG, the v0.1.0 timeline `PROJECT_PLAN.md`, ADR-0001) — that's `scaffold-onboard:scaffolding-governance-docs` (SPEC §5.3), reached via `/scaffold-docs`. Those are a different file family with a different owner.
- The user wants memory-bank / CLAUDE.md derivation — that's `scaffold-onboard:scaffolding-memory-bank` (SPEC §5.2).
- The user wants to author or refine demo criteria for a slice that already exists in ROADMAP.md and they know the slice ID — they may directly invoke `Skill(scaffold-onboard:authoring-vertical-slice-demo)` without going through this skill.

If the user types something ambiguous like "let's plan the project" and MASTER-SPEC exists, ask: *"Do you mean the Phase → Sprint → Vertical-Slice hierarchy (`ROADMAP.md`, authored interactively here via `/plan-roadmap`), or the v0.1.0 Phase-2-Strategy-derived timeline doc (`PROJECT_PLAN.md`, emitted deterministically by `/scaffold-docs`)?"* — they're two different files with two different owners.

---

## 3. Prerequisites

Before R1.A opens:

1. **MASTER-SPEC.md must exist** at the routing destination. Resolve via `sf_resolve_output_path master_spec MASTER-SPEC.md` and confirm the file is present. If absent, surface the routing prompt from §2 and stop.
2. **MASTER-SPEC.md should validate** via `sf_spec_validate`. A malformed spec doesn't block roadmap authoring (the user may have hand-edited it), but surface a one-line warning so they're aware: *"MASTER-SPEC has validation errors — proceeding, but expect rough edges. Run `/scaffold-onboard:validating-master-spec` to surface them."*
3. **`${CLAUDE_PLUGIN_DATA}` writable.** State persistence requires it. If unwritable, surface a hard error and stop (mid-flow data loss is the failure mode we avoid).

---

## 4. The three sub-phases (R1.A / R1.B / R1.C)

Each sub-phase opens with a verbatim 3-timelines framing prompt (sourced from SPEC §5.4). **The framing text is canonical onboarding vocabulary — do NOT paraphrase, do NOT improvise, do NOT translate.** Eval scenario S4 explicitly fails on substantive deviation (e.g., "long-term vision" instead of "visionary horizon" is a FAIL).

### 4.1 R1.A — Phases (~10-20 min, 3-6 phases)

Open R1.A with this exact line (em-dash preserved):

> Your Phases are your visionary horizon — what's the project's 5-year shape?

Then walk the user through naming 3-6 phases. For each phase, capture:

- `id` — integer (1-indexed, monotonically increasing)
- `name` — short kebab/Title-Case name (e.g., "Foundation", "Beta-Launch", "Scale")
- `horizon` — rough timeframe estimate ("Q3 2026", "12 months out", "year 2")
- `summary` — 1-2 paragraph phase summary; what the user "sees" at the end of this phase

Persist after each phase via `sf_roadmap_write_phase <id> <name> <horizon> <summary>`. After all phases are named, write `checkpoint="R1.A-complete"` via `sf_state_write_atomic`, then surface Checkpoint 1:

> Phases captured (N total). Continue to sprints, or pause here and resume with `/plan-roadmap --resume`?

If the user declines to continue: stop, leave checkpoint at `R1.A-complete`. If they accept: surface size-class adaptation (§6) before advancing into R1.B.

### 4.2 R1.B — Sprints per phase (~30-50 min, 2-4 sprints per phase)

Open R1.B with this exact line:

> Sprints are your value-building windows — what gets built over 12-18 months that compounds?

For each phase in order, walk the user through naming 2-4 sprints. For each sprint capture:

- `phase_id` — the phase this sprint belongs to
- `id` — `<phase_id>.<sprint_index>` (e.g., "1.1", "1.2", "2.1")
- `name` — short name describing the sprint's value-shipping goal
- `goal` — 2-3 sentence sprint goal: what's demoable at sprint close
- `vs_count_estimate` — integer 2-5 (used by size-class adaptation; can refine in R1.C)

Persist via `sf_roadmap_write_sprint <phase_id> <id> <name> <goal> <vs_count_estimate>` after each sprint. After all sprints for a phase are captured, surface Checkpoint 2 (per-phase boundary):

> Sprints captured for Phase N (M total). Continue to the next phase's sprints, or pause and resume with `/plan-roadmap --resume`?

When all phases' sprints are captured, write `checkpoint="R1.B-complete"`. The skill state field tracks the current sub-phase explicitly (R1.A / R1.A-complete / R1.B / R1.B-complete / R1.C / R1.C-complete) so `--resume` can re-enter at the exact next unanswered question — never restart from R1.A.

### 4.3 R1.C — Vertical Slices per sprint (~40-60 min, 2-5 slices per sprint + demo criteria)

Open R1.C with this exact line:

> Vertical slices are your visibility cycles — what ships demoably in 90-day-ish windows?

For each sprint in order, walk the user through naming 2-5 vertical slices. For each slice capture:

- `sprint_id` — the sprint this slice belongs to (e.g., "1.1", "2.3")
- `id` — `VS-<phase>.<sprint>.<slice>` (e.g., `VS-1.1.1`, `VS-2.3.2`) — matches scaffold-dev's `docs/specs/sprint-N/VS-N.M-<kebab>/` schema (per scaffold-dev SPEC §5.2)
- `name` — short slice name
- `summary` — 1-2 sentence summary: what's demoed when this slice closes
- `demo_criteria` — 1-3 lines authored via `Skill(scaffold-onboard:authoring-vertical-slice-demo)` (§8)

Persist each slice (without demo criteria yet) via `sf_roadmap_write_slice <sprint_id> <id> <name> <summary>`, then immediately invoke the demo-authoring skill per §8 to top-up criteria. After each sprint's slices are all captured, surface Checkpoint 3 (per-sprint boundary):

> Slices captured for Sprint N.M (K total, each with demo criteria). Continue to next sprint's slices, or pause and resume?

When all sprints' slices are captured, advance to §10 (architect-critic close moment), then write `checkpoint="R1.C-complete"` and emit ROADMAP.md (§11).

---

## 5. State management

State lives at `${CLAUDE_PLUGIN_DATA}/project-roadmap.json` — a **separate file** from `onboarding-state.json`. The two state files have non-overlapping concerns; keeping them split avoids schema collision and lets `/plan-roadmap --resume` work even when onboarding state is `complete`.

**Schema (per SPEC §7.2):**

```
{
  "schema_version": "1",
  "started_at": "<ISO8601>",
  "checkpoint": "R1.A" | "R1.A-complete" | "R1.B" | "R1.B-complete" | "R1.C" | "R1.C-complete",
  "elapsed_min": <integer>,
  "phases": [
    {"id": 1, "name": "Foundation", "horizon": "Q3 2026", "summary": "..."},
    ...
  ],
  "sprints": [
    {"phase_id": 1, "id": "1.1", "name": "...", "goal": "...", "vs_count_estimate": 3},
    ...
  ],
  "vertical_slices": [
    {"sprint_id": "1.1", "id": "VS-1.1.1", "name": "...", "summary": "...", "demo_criteria": ["auto: ...", "user: ..."]},
    ...
  ],
  "mutations": [
    {"at": "<ISO8601>", "mode": "add-sprint", "target": "phase_2", "added_id": "2.4"},
    ...
  ]
}
```

**Helpers you call (lib/state.sh + lib/roadmap.sh — T3.2):**

- `sf_roadmap_state_init` — create a fresh `project-roadmap.json` with `started_at` set to `now`, `checkpoint="R1.A"`, empty arrays.
- `sf_roadmap_state_mode` — returns `new` | `resume` | `rerun` based on existing state + filesystem (parallel to `sf_state_mode` for the onboarding state file).
- `sf_roadmap_state_path` — print the absolute path of the roadmap state file.
- `sf_roadmap_read_checkpoint` — return current `checkpoint` value.
- `sf_roadmap_read_elapsed` — compute and return `elapsed_min` from `started_at`.
- `sf_roadmap_write_phase` / `sf_roadmap_write_sprint` / `sf_roadmap_write_slice` — atomic writes for individual hierarchy nodes.
- `sf_roadmap_count_nodes_estimate` — compute estimated node count for size-class adaptation (§6).
- `sf_roadmap_append_mutation` — log a mutation entry into `mutations[]` during re-runs (§9).
- `sf_state_write_atomic` / `sf_state_read_field` — top-level field reads/writes (re-used from lib/state.sh).

**Discipline:**

- **Persist after every node.** A mid-R1.B interruption must never lose R1.A's phases.
- **Resume protocol.** On entry, call `sf_roadmap_state_mode`. If `resume`: read `checkpoint`, announce position (*"Resuming at R1.B (sprints for Phase 2). 1 sprint already captured."*), and re-enter at the first unanswered sub-phase question (detected by scanning the relevant array against the current sub-phase loop's expected entries).
- **Mid-sub-phase re-entry.** The `checkpoint` field reflects the highest-completed boundary. To find the actual re-entry point: read `phases` / `sprints` / `vertical_slices` arrays, determine which is partially populated, re-enter at its next missing entry.
- **Re-run protocol** is §9; do not confuse with resume.

---

## 6. Time-budget discipline (advisory, warn-only)

The R1 authoring flow is advisory-bounded at **~90 minutes total** across all three sub-phases (per SPEC §5.4 + §7.3). The discipline is **warn-only** — the skill never unilaterally pauses the user. Agency belongs to the user.

**60-minute advisory checkpoint:**

When `sf_roadmap_read_elapsed` first crosses 60 minutes (and the current `checkpoint` is mid-sub-phase, NOT at a natural R1.A-complete / R1.B-complete / R1.C-complete boundary), surface this **before** asking the next authoring question:

> ~60 min elapsed. Checkpoint and continue tomorrow with `/plan-roadmap --resume`? (yes/no, default no)

This is an **offer** — a prompt for user choice. If the user declines (default no, or explicit "no, let's keep going"): proceed to the next authoring question. The 60-min mark is advisory, not a hard stop.

The offer fires **once per session crossing the threshold**. Do not re-prompt at every subsequent question. Record the surfacing event in transient session memory (no state-file write needed; this is a courtesy, not a contract).

**90-minute warning:**

When elapsed crosses 90 minutes, surface a stronger warning + a stronger checkpoint offer:

> ~90 min elapsed — past the advisory budget. Strongly suggest checkpoint via `/plan-roadmap --resume` later. Continue anyway? (yes/no, default no)

This is **still warn-only**. If the user declines the checkpoint: continue. The skill does not force-stop. The 90-min mark is the upper end of the advisory budget, not a hard ceiling.

The natural sub-phase boundaries (R1.A-complete, per-phase R1.B-complete, per-sprint R1.C-complete) ALSO offer save-and-resume — those are separate from the time-based ones. Both kinds of checkpoint offers coexist.

---

## 7. Size-class adaptation (>50 nodes triggers 3-path prompt)

At **R1.A close** (after all phases are named but before R1.B opens), call `sf_roadmap_count_nodes_estimate`. This returns:

```
nodes_estimate = phases_count × avg_sprints_per_phase × avg_slices_per_sprint
```

Where `avg_sprints_per_phase` and `avg_slices_per_sprint` are SPEC-recommended midpoints (3 sprints/phase, 4 slices/sprint) since R1.B/R1.C haven't run yet. The estimate is a rough up-front sizing signal, not a final count.

**Thresholds (per SPEC §7.3):**

- **`nodes_estimate ≤ 50`** (typical: 4 phases × 3 sprints × 4 slices = 48). Proceed silently. No prompt.
- **`50 < nodes_estimate ≤ 100`** (e.g., 5 × 3 × 5 = 75, or 6 × 4 × 4 = 96). Surface the 3-path prompt:

  > Estimated hierarchy size: ~N nodes (typical projects: ≤50). Three paths forward:
  > 1. **Continue** — accept the >90 min budget; explicit acknowledgment recorded.
  > 2. **Split into product epics** — break the project into 2-3 epics; each runs separate `/plan-roadmap` with its own MASTER-SPEC slice. Recommended for tightly-scoped completion.
  > 3. **Reduce scope** — only the first 2-3 phases get sprint+slice decomposition; later phases stay as sprint-level placeholders for now.
  >
  > Which path? (1/2/3, default 1)

  Record the choice via `sf_state_write_atomic size_class_choice <1|2|3>`. If choice == 2, stop after capturing the choice and surface guidance: *"Re-run `/onboard` with a scoped MASTER-SPEC slice per epic, then `/plan-roadmap` against each."*. If choice == 3, proceed to R1.B but cap decomposition at the first 2-3 phases.

- **`nodes_estimate > 100`** (e.g., 7 × 4 × 5 = 140). Surface the same 3-path prompt, but **bias the default toward path 2 (split into epics)**:

  > Estimated hierarchy size: ~N nodes — this is significantly larger than the typical R1 budget supports. Strongly recommend **path 2 (split into product epics)** for completion success. The three paths are:
  > 1. Continue (NOT recommended at this size)
  > 2. **Split into product epics** (recommended)
  > 3. Reduce scope (only first 2-3 phases decompose)
  >
  > Which path? (1/2/3, default 2)

The default-flip at >100 is a nudge, not a force. User retains agency.

---

## 8. R1.C: invoking `authoring-vertical-slice-demo` per slice

For each vertical slice you capture in R1.C, after `sf_roadmap_write_slice` persists the slice header, invoke the demo-criteria authoring skill to top-up 1-3 demo criteria:

```
Skill(scaffold-onboard:authoring-vertical-slice-demo)
  with: slice_id=<VS-N.M.K>, target_roadmap=<resolved ROADMAP.md path>
```

That skill (per SPEC §5.6) handles the `auto:` / `user:` grammar prompts, validates each line via `sf_demo_parse_line`, and idempotently appends to the slice's `demo_criteria` array. Repeated invocations on the same slice top-up without duplicating (matched by text equality). You do NOT inline the `auto:` / `user:` grammar prompts here — that's the demo-authoring skill's lane.

**1-3 criteria per slice** is the target band:

- **0 criteria** is acceptable on first pass; the slice can be top-upped later by scaffold-dev's orchestrator when more implementation context is known (per SPEC §9.2 hybrid authoring).
- **>3 criteria** is fine if the user has them ready; the skill doesn't cap.
- The eval (S1) checks that at least one demo criteria line lands per slice in the typical walk; lean toward at-least-one over zero.

When the demo-authoring skill returns, persist no extra state (it writes directly to the slice's `demo_criteria` array via `sf_demo_append` against ROADMAP.md, but ROADMAP.md doesn't exist yet during R1.C; the criteria land in `project-roadmap.json`'s `vertical_slices[].demo_criteria` array instead — see SPEC §7.2 schema). At ROADMAP.md emission time (§11), the renderer reads those arrays into the slice blocks.

---

## 9. Re-run protocol (5 modes)

When ROADMAP.md exists at the routing destination AND `project-roadmap.json` has `checkpoint == "R1.C-complete"`: enter **re-run mode**. Do NOT restart R1.A/B/C from scratch — that destroys the user's prior work.

**Detection:** at skill entry, after `sf_roadmap_state_mode` returns `rerun`, surface the mode prompt:

> ROADMAP.md is already authored. Five surgical modes available:
>
> 1. `--add-phase` — Walk R1.A for one new phase only; offer R1.B + R1.C for that phase. ("Project scope grew — added Phase 5.")
> 2. `--add-sprint <phase_id>` — Walk R1.B for one new sprint in named phase; offer R1.C for it. ("Phase 2 needs another sprint between 2.2 and 2.3.")
> 3. `--add-slice <sprint_id>` — Walk R1.C for one new slice in named sprint. ("VS-1.1.3 emerged from VS-1.1.2 closing.")
> 4. `--refine-slice <slice_id>` — Walk R1.C for one existing slice (rewrite name / summary; demo criteria via `authoring-vertical-slice-demo`). ("VS-2.1.1 needs better demo criteria after Phase 1 closed.")
> 5. `--reorganize` — Full re-walk; preserves existing items; user accepts/edits each. ("Major project pivot; restructure.")
>
> Which mode? (1/2/3/4/5)

If `$ARGUMENTS` already contains a mode flag (e.g., user typed `/plan-roadmap --add-sprint 2`): skip the prompt and route directly to the named mode.

**Mode behavior:**

- **`--add-phase`** — append one new entry to `phases[]`; walk R1.B for sprints of that phase; walk R1.C for slices of those sprints. Existing entries untouched. Append to `mutations[]`: `{"mode": "add-phase", "added_id": <id>}`.
- **`--add-sprint <phase_id>`** — error if `phase_id` not in `phases[]`. Append one new entry to `sprints[]` under that phase; walk R1.C for its slices. Append mutation: `{"mode": "add-sprint", "target": "<phase_id>", "added_id": <id>}`.
- **`--add-slice <sprint_id>`** — error if `sprint_id` not in `sprints[]`. Append one new entry to `vertical_slices[]` under that sprint; invoke `authoring-vertical-slice-demo` for criteria. Append mutation: `{"mode": "add-slice", "target": "<sprint_id>", "added_id": <id>}`.
- **`--refine-slice <slice_id>`** — error if `slice_id` not in `vertical_slices[]`. Re-prompt for the slice's name + summary + demo criteria; the user can accept-as-is or edit any field. Append mutation: `{"mode": "refine-slice", "target": "<slice_id>"}`.
- **`--reorganize`** — walk all three sub-phases again with each existing entry pre-loaded as the default; user accepts/edits/deletes each. Most details for v0.2 defer to SPEC OQ4 (v0.3+); a minimal honest implementation re-walks R1.A/B/C presenting current entries as editable defaults, persisting changes as ordinary writes, and appending one summary mutation: `{"mode": "reorganize", "at": "<ISO8601>"}`.

After any re-run mode completes, re-emit ROADMAP.md via §11 (the renderer is idempotent; the file is rewritten from `project-roadmap.json`).

**Note on `--reorganize` ambiguity:** SPEC §7.5 hand-waves "preserves existing items; user accepts/edits each (defers most details to OQ4 v0.3+)". This skill body codifies the minimum honest behavior above. If `--reorganize` runs against a roadmap WITHOUT existing `project-roadmap.json` state (ROADMAP.md present but no state — e.g., hand-authored), surface: *"`--reorganize` requires existing `project-roadmap.json` state. Re-run without `--reorganize` to start fresh, or hand-edit ROADMAP.md directly."* and stop.

---

## 10. architect-critic moment at R1.C close

After R1.C completes (all sprints have their slices, all slices have their demo criteria) and **before** writing ROADMAP.md to its routing destination, invoke architect-critic for adversarial review at `target=roadmap, depth=close` (per SPEC §12.1 row 4).

### 10.1 Detection (filesystem probe; binary v0.2-or-absent)

Call `sf_compose_detect_architect_critic` (lib/compose.sh) — the same helper `onboarding-project` uses. It walks known plugin cache directories looking for `architect-critic/*/skills/critiquing-spec/SKILL.md` and prints either `v0.2` or `absent`. This is **NOT a `composition.json` read** — per ac v0.2 settlement #1, architect-critic detection is filesystem-only. The composition.json this plugin maintains for ai-mentor + superpowers does not carry an architect-critic entry.

**Why binary detection (no older-version fallback):** architect-critic v0.1.x shipped with zero `skills/` directory, so the `Skill(architect-critic:...)` grammar can never resolve against pre-v0.2 installs. Combined with architect-critic v0.2's hard-breaking-change SPEC §3 NG1, the cleanest contract is binary: detect v0.2 → invoke; detect absent → warn-and-skip. There is no transitional fallback path.

### 10.2 Invocation pattern

When the probe returns `v0.2`:

1. Announce: *"R1.C close — invoking architect-critic for a `close` audit on the full roadmap. Type `skip` if you want to bypass."*
2. End the turn and wait. If the user types `skip` (case-insensitive): log the skip and proceed to §11.
3. Otherwise, invoke `Skill(architect-critic:critiquing-spec)` with:
   - `target=roadmap`
   - `depth=close`
   - `spec_path=<resolved ROADMAP.md draft path>` (or, since ROADMAP.md isn't written yet, the in-memory rendered preview; architect-critic v0.2's settlement supports both)
   - Adversaries: `[claude, codex]` per SPEC §12.1 row 4 (close depth = claude + codex when user opts in via the critic skill's own `--close` flag handling)
4. architect-critic runs its own challenge-resolution loop (sequential rebuttal, scoring, auto-promotion) and returns the structured "Audit complete for ..." summary.
5. When control returns: surface any challenges that stood as edit candidates for the affected phase / sprint / slice. The user may accept-and-revise; you re-render the relevant section in the in-memory roadmap before emitting in §11.

### 10.3 Absent / warn-and-skip

If `sf_compose_detect_architect_critic` returns `absent`, emit one warning and continue to §11:

> [scaffold-onboard] architect-critic not installed — skipping `roadmap close` audit. Install via `/plugin install architect-critic` (v0.2+) for adversarial review at this moment.

Do not stall the flow. R1 authoring is robust to architect-critic's absence; the critic is a strength-multiplier, not a gate.

### 10.4 What you do NOT do

- Do **NOT** use the legacy file-IPC pattern (`sf_compose_build_critic_request` / `sf_compose_read_critic_response`) — both functions were removed in v0.2 per SPEC §12.3. No `inbox/` or `outbox/` paths.
- Do **NOT** read `composition.json` to detect architect-critic — filesystem probe only.
- Do **NOT** invoke `Skill(architect-critic:critique)` (the legacy slash-command-shaped v0.1.x name). The v0.2 skill is `critiquing-spec`.

---

## 11. Manifest-aware output routing

Per SPEC §10.1, this skill produces one logical-name destination:

| Logical name | Default destination | Doc emitted by this skill |
|---|---|---|
| `roadmap` | `canonical` | `ROADMAP.md` |

**Helper:** `sf_resolve_output_path <logical_name> <relative_path>` (lib/routing.sh):

```
roadmap_path="$(sf_resolve_output_path roadmap ROADMAP.md)"
```

Behavior:

- **Manifest present** (walked up from `pwd` to find `.workspace/pairing.json`): returns absolute path with `canonical.root` expanded (e.g., `<canonical-repo>/ROADMAP.md`).
- **Manifest absent** (single-repo mode): returns `$(pwd)/ROADMAP.md` — falls back to v0.1.0-style behavior. The R1 hierarchy file lands at the project root in single-repo mode.
- **Manifest present but `routing.roadmap` missing** (older workspace-init manifest that pre-dates the `roadmap` key per SPEC §10.4): helper warns once and falls back to `$(pwd)/ROADMAP.md`. workspace-init v0.1.1 (point release) adds the key with default `"canonical"`.

Always route through `sf_resolve_output_path` — never hardcode `ROADMAP.md` against `$(pwd)` directly. Rendering: call `sf_roadmap_render <state_file> <output_path>` (lib/roadmap.sh — T3.2) which reads `project-roadmap.json` and emits the markdown shape per SPEC §7.1.

After emission, surface the close summary:

```
ROADMAP.md authored at <resolved_roadmap_path>.

R1 hierarchy authored:
  - N phases
  - M sprints
  - K vertical slices (each with demo criteria)

Next step:
  scaffold-dev v0.1's orchestrator-implementer cycle consumes ROADMAP.md as its R1 input contract.
  Run /scaffold-dev:open-sprint <sprint_id> to start a sprint (when scaffold-dev v0.1 ships).
```

---

## 12. Slash-command interaction (`/plan-roadmap` via `$ARGUMENTS` bridge)

The `/plan-roadmap` slash command wrapper (`commands/plan-roadmap.md`) exports the raw arg string as `$ARGUMENTS` (env-var bridge per `feedback_slash_command_dollar_n_bug` — Claude Code substitutes `$1`/`$2`/etc. in command bodies at template-render time, silently corrupting bash positionals).

Supported flags:

- *(no flag)* — default: `new` mode if no state file; `resume` mode if state is mid-flow (`checkpoint != R1.C-complete`); `rerun` mode prompt if state shows `R1.C-complete` (§9).
- `--resume` — explicit resume; errors if no state file is present. Re-enters at the next unauthored question per §5 discipline.
- `--phase-only` — walk R1.A only; stop after `checkpoint="R1.A-complete"`. Useful for early scoping.
- `--sprint-only` — walk R1.A + R1.B; stop after `checkpoint="R1.B-complete"`. Useful when slice-level detail isn't ready yet.
- `--add-phase` — re-run mode 1 (§9).
- `--add-sprint <phase_id>` — re-run mode 2.
- `--add-slice <sprint_id>` — re-run mode 3.
- `--refine-slice <slice_id>` — re-run mode 4.
- `--reorganize` — re-run mode 5.

Parse `$ARGUMENTS` in bash; never reference `$1` / `$2` directly. Unknown flags → one-line error listing supported flags + stop (do not silently ignore).

---

## 13. Bash bookkeeping helpers

This skill never bash-orchestrates the judgment work (which sub-phase to enter, how to phrase a checkpoint offer, whether to trigger the size-class prompt, how to interpret a partial slice answer). It calls helpers for I/O and templating only.

**Roadmap state + rendering (lib/roadmap.sh — T3.2):** `sf_roadmap_state_init`, `sf_roadmap_state_mode`, `sf_roadmap_state_path`, `sf_roadmap_read_checkpoint`, `sf_roadmap_read_elapsed`, `sf_roadmap_write_phase`, `sf_roadmap_write_sprint`, `sf_roadmap_write_slice`, `sf_roadmap_count_nodes_estimate`, `sf_roadmap_append_mutation`, `sf_roadmap_render`.

**State (lib/state.sh — re-used):** `sf_state_write_atomic`, `sf_state_read_field`.

**Composition (lib/compose.sh):** `sf_compose_detect_architect_critic`.

**Routing (lib/routing.sh):** `sf_resolve_output_path`, `sf_discover_manifest`.

**Validation (lib/parser.sh — re-used):** `sf_spec_validate` (for the prerequisite check on MASTER-SPEC).

These are pseudocode references — the implementations live in their respective lib files. macOS-portable patterns (BSD awk, bash 3.2) are required for any inline snippets; prefer calling the helpers over re-inlining shell.

---

## 14. Anti-patterns (do not do these)

- **Writing the R1 hierarchy to `PROJECT_PLAN.md` instead of `ROADMAP.md`.** The R1 hierarchy doc is `ROADMAP.md` — a separate file. `PROJECT_PLAN.md` is `/scaffold-docs`'s v0.1.0 Phase-2-Strategy-derived timeline doc, owned by `scaffolding-governance-docs`, **unchanged from v0.1.0**. Reusing that filename would silently overwrite v0.1.0 users' timeline docs on regenerate. The rename to `ROADMAP.md` is load-bearing (per SPEC §13.5).
- **Auto-extracting the hierarchy from MASTER-SPEC.md.** This skill is **interactive**, not LLM-extractive (per SPEC §3.7 non-goal). The user authors the hierarchy with the skill's guidance; the skill prompts, persists, and routes. Do not try to parse MASTER-SPEC and infer phases/sprints/slices.
- **Paraphrasing the 3-timelines framing prompts.** The exact strings in §4.1 / §4.2 / §4.3 are canonical onboarding vocabulary. Eval S4 explicitly fails on substantive deviation. Paste them verbatim, em-dashes included.
- **Restarting R1.A from scratch when ROADMAP.md already exists.** Use the re-run protocol (§9). Restarting destroys the user's prior work.
- **Unilaterally pausing at 60 or 90 min.** The time-budget discipline is **warn-only**. The user retains agency; pause is always an offer, never a unilateral stop.
- **Reading `composition.json` to detect architect-critic.** Filesystem probe only — `sf_compose_detect_architect_critic`.
- **Writing to `inbox/` or `outbox/` paths.** File-IPC is removed in v0.2. In-conversation `Skill(...)` invocation only.
- **Hardcoding `ROADMAP.md` against `$(pwd)`.** Always route via `sf_resolve_output_path roadmap ROADMAP.md`.
- **Calling `Skill(architect-critic:critique)`** (the legacy v0.1.x slash-command-shaped name). Use `Skill(architect-critic:critiquing-spec)` — the v0.2 skill.
- **Inlining the `auto:` / `user:` demo-criteria grammar in this body.** That grammar belongs to `authoring-vertical-slice-demo` (SPEC §5.6 / §9). This skill invokes that one; it does not author the grammar itself.
- **Letting this body exceed 500 lines.** Hard cap per Pass D skill-first guidance. Target ~400.

---

## 15. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: how to phrase a sub-phase intro recap, when to fire the size-class prompt, whether the user's "TBD" on a slice summary is a checkpoint signal or a placeholder, when to escalate to architect-critic.
- **Bash helpers** (`lib/*.sh`) handle pure I/O: state file reads/writes, atomic mv, template substitution, manifest path resolution, filesystem probes, node counting.
- **`authoring-vertical-slice-demo`** is invoked per slice during R1.C — it owns the `auto:`/`user:` grammar; you only orchestrate the call.
- **`architect-critic:critiquing-spec`** is invoked at R1.C close — it runs its own internal challenge/rebuttal loop and returns a structured summary; you don't mediate its internals.
- **The user** is the final authority. They author every node; you prompt and persist. They accept, edit, or skip every checkpoint offer. You never auto-finalize a sub-phase, auto-advance past a checkpoint, or auto-pause without explicit user choice.

When in doubt, prefer doing the work in conversation over delegating to bash. The bookkeeping-vs-judgment line is: if the next action involves a user-facing decision (which question to ask next, how to recap, whether to escalate), it belongs here in the skill body; if it's pure I/O (state write, template render, path resolve), it belongs in a lib helper.
