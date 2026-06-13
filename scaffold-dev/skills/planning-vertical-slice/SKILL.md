---
name: planning-vertical-slice
description: Drive the full vertical-slice lifecycle — decompose into 4-5 work items, identify rounds via DAG, author specs upfront, offer grill-me at three gates, invoke architect-critic, then per round spawn worktrees + dispatch `scaffold-dev:implementer-agent` subagents. Use this when the user wants to plan VS-1.1.1, orchestrate VS-1.1.1, start a new vertical slice, or says "let's plan the next slice". Refuses to start without a workspace-init pairing manifest.
---

# planning-vertical-slice

You are the conductor of scaffold-dev v0.1's vertical-slice lifecycle. Once `MASTER-SPEC.md`, the memory bank, and `ROADMAP.md` exist (authored upstream by scaffold-onboard v0.2), this skill walks the user through one full slice: decomposition → round identification → spec authoring → architect-critic audit → per-round subagent dispatch → verification → commit + merge → round-close → slice-close handoff.

Bash helpers in `lib/manifest.sh`, `lib/state.sh`, `lib/worktree.sh`, `lib/merge.sh`, `lib/compose.sh`, and `lib/render.sh` do the bookkeeping (manifest resolution, atomic state writes, worktree mechanics, merge orchestration, filesystem probes, template substitution). The judgment work — how to slice the VS into work items, when to surface the grill-me offer, whether a subagent gap is blocking or nice-to-have, how to interpret a verification fail — happens here, in conversation.

This skill is the orchestrator's entry point. It does NOT author work-item implementations (that's `executing-work-item` running as the `scaffold-dev:implementer-agent` subagent body per SPEC §6), does NOT run the per-work-item verification gate (that's `implementation-checking` per §12), and does NOT close the slice (that's `closing-vertical-slice` per §14). Those are downstream skills this body invokes or hands off to.

---

## 1. Overview

When invoked, you:

1. Discover the workspace-init pairing manifest (refuse fail-fast if absent per SPEC §16.1).
2. Resolve the published structured roadmap (`project-roadmap.json` via `sd_roadmap_state_path`), field-read the target slice by exact `id` (get `sprint_id` + metadata), read MASTER-SPEC + memory bank Tier 0 + the active-context cursor.
3. Propose a 4-5 work-item decomposition (each ~200-500 LOC, stable `N.NN` numbering); iterate with the user.
4. Offer grill-me (gate 1).
5. Identify rounds via strict-layer DAG topological sort over declared dependencies; user may loosen or tighten.
6. Author the full slice scaffold upfront: `README.md`, all `work-N.NN-<kebab>/spec.md` files, empty `handoff.md` + `report.md` placeholders alongside each spec.
7. Offer grill-me on specs (gate 2).
8. Offer spec-citations check (opt-in gate, §6.4).
9. Invoke `Skill(architect-critic:critiquing-spec)` in-conversation (per SPEC §16.3 moment 1) — challenges/concessions cycle.
10. **Per round (sequential):** create worktrees via `sd_worktree_add`, author handoff via `templates/implementation-handoff.md.tmpl`, dispatch `Task(subagent_type="scaffold-dev:implementer-agent", ...)`, process gaps-mode or complete-mode returns (§6.3), run `implementation-checking` (§12.1), commit + merge per `git_policy` (HALT on conflict per §11), offer grill-me at fix-up replan (gate 3).
11. After all items in a round: surface "Round K complete; ready for K+1 or close slice?"
12. At slice-close intent: suggest invoking `closing-vertical-slice`.

Phase 1 RED→GREEN: this body's behavior is contracted by `scaffold-dev/evals/planning-vertical-slice.md` — the four scenarios there are the binding spec.

---

## 2. When to use

**Trigger phrases (description-match):**

- `plan VS-N.M.K`, `orchestrate VS-N.M.K`, `start vertical slice N.M`
- `start a new vertical slice`, `let's plan the next slice`
- `/orchestrate VS-N.M.K` (slash command — see §13 for the `$ARGUMENTS` env-var bridge)

**Do NOT auto-invoke when:**

- `MASTER-SPEC.md` does not exist. The slice is downstream of MASTER-SPEC + ROADMAP; without them there is nothing to plan against. Route to `Skill(scaffold-onboard:onboarding-project)` (or `/onboard`) and stop.
- `ROADMAP.md` does not exist OR does not contain the target VS. Route to `Skill(scaffold-onboard:planning-project-roadmap)` (or `/plan-roadmap --add-slice <id>`) and stop. §3 covers the missing-VS error path.
- The user wants to *execute* a work item from an already-planned slice — that's `executing-work-item` (either as the subagent body via Task dispatch, or as a manual fresh-session skill per §6.4).
- The user wants to *verify* a completed work item — that's `implementation-checking` (SPEC §12.1).
- The user wants to *close* a slice whose rounds have all completed — that's `closing-vertical-slice` (SPEC §14).

If the user types something ambiguous like "let's work on VS-1.1.1", ask: *"Plan VS-1.1.1 from scratch (decomposition → spec authoring → round-1 execution), or resume an in-flight slice (next round / next work item)?"*. A resume case routes to either `executing-work-item` (round in progress) or `implementation-checking` (round-close pending) per the active-context cursor.

---

## 3. Pre-flight

Before any decomposition step, validate prerequisites in this order. Any failure surfaces the verbatim refusal/error string and stops.

### 3.1 Manifest discovery (refuses fail-fast)

Call `sd_manifest_discover` (lib/manifest.sh) to walk up from `pwd` for `.workspace/pairing.json`. If discovery returns absent — i.e. `sd_manifest_require` exits non-zero — surface this verbatim refusal and stop:

> scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first.

The literal slash-command tokens `/init-workspace` and `/pair-workspace` are load-bearing — eval S2's judge rejects paraphrased substitutes that omit either token. Do NOT proceed to read ROADMAP.md, do NOT author any files, do NOT invoke architect-critic. The refusal is grounded in the helper's absent-result, not in a heuristic guess.

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash shebang forces a bash runtime under it regardless of the calling shell — required because Claude Code's Bash tool runs zsh by default on macOS):

```bash
# Manifest probe (S2 contract)
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

Never read manifest fields via raw inline `jq -r '...' .workspace/pairing.json` — eval S1's green-light criterion is binding: **all manifest field reads MUST go through `sd_manifest_get` / `sd_manifest_resolve`**. The helpers handle walk-up discovery, `${var}` expansion, and `${PLUGIN_DATA:<plugin-name>}` resolution per workspace-init's contract.

### 3.2 Read manifest fields

Resolve the fields this skill needs:

```bash
ai_workspace="$(sd manifest_get '.ai_workspace.root')"
canonical="$(sd manifest_get '.canonical.root')"
worktrees_dir="$(sd manifest_resolve "$ai_workspace" "$(sd manifest_get '.during_dev.worktrees_dir')")"
branch_naming="$(sd manifest_get '.during_dev.branch_naming')"
sprint_dir_template="$(sd manifest_get '.during_dev.sprint_dir_template')"
```

The slice's identity and structure come from the **structured roadmap state** (`project-roadmap.json`) that scaffold-onboard publishes — NOT from grepping `ROADMAP.md`. Resolve its path via the helper, which honors the manifest's `well_known_paths.roadmap_state` and falls back to the canonical workspace location (`${ai_workspace.root}/.workspace/project-roadmap.json`) for older manifests predating workspace-init 0.1.2:

```bash
roadmap_state="$(sd roadmap_state_path)"
```

Do **NOT** read `.routing.roadmap` as a path — it is a repo *selector* string (`"canonical"` / `"ai_workspace"`), never a filesystem path. The published JSON, carrying explicit `id` + `sprint_id` fields per slice, is the structured contract surface scaffold-onboard and scaffold-dev share (#28).

### 3.3 Field-read the target VS from the structured roadmap

Look up the slice by its **exact `id`** in `project-roadmap.json`. Never grep a `#### VS-…:` heading, and never string-split the id to recover the sprint — that was the #28 slice-ID arity bug (a 3-part `VS-1.1.1` collapsed to the wrong `sprint-1` instead of `sprint-1.1`).

```bash
vs_record="$(sd roadmap_slice_json "$vs_id")"        # fails if id not found
sprint_id="$(sd roadmap_slice_sprint_id "$vs_id")"   # e.g. "1.1" for VS-1.1.1
vs_name="$(printf '%s' "$vs_record" | jq -r '.name // empty')"
vs_summary="$(printf '%s' "$vs_record" | jq -r '.summary // empty')"
vs_kebab="$(printf '%s' "$vs_name" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[[:space:]_]+/-/g; s/[^a-z0-9-]//g; s/-+/-/g; s/^-+|-+$//g')"
if [[ -z "$vs_kebab" ]]; then
  echo "VS ${vs_id} has no usable roadmap name for a directory slug; update project-roadmap.json and re-publish via /plan-roadmap." >&2
  exit 1
fi
```

If no slice matches the id, `sd roadmap_slice_json` fails and its error lists the available ids; surface this to the user (S3 contract):

> VS-<id> not found in the published roadmap (`<roadmap_state path>`). Available: <ids>. Run `/plan-roadmap --add-slice <id>` to author the slice first, then `/plan-roadmap` to re-publish the structured state.

The error MUST name the missing id explicitly, cite the resolved `project-roadmap.json` path, and include the literal `/plan-roadmap --add-slice` token. Then stop — do NOT auto-fix the roadmap, do NOT create `docs/specs/sprint-<sprint_id>/` directories, do NOT invoke architect-critic.

When the record is found, read every field directly from `vs_record` (all carried in the structured state — no prose parsing): VS `name`, one-paragraph `summary`, declared `demo_criteria` (the `auto:` / `user:` lines, per SPEC §14.1 grammar; rendered into the slice README at §6), and the traceability arrays `traces_fr` / `traces_nfr` / `traces_backlog`. Derive `vs_kebab` from the roadmap `name` field before §6.1 uses it in `slice_root`; if the name sanitizes to empty, stop and surface a roadmap data error rather than inventing a directory slug. Carry the trace IDs into every work-item spec and implementation handoff as `traceability_block`; if an array is empty, render `- FR: None`, `- NFR: None`, and `- Backlog: None` explicitly rather than inventing IDs.

### 3.3a Merge-mode pre-flight (pr_hierarchical)

Read the mode early (it gates §8.1 + §8.6 + slice-close). See
`references/git-workflow.md` for the full topology and primitive contracts.

```bash
merge_mode="$(sd merge_mode)"   # "direct" (default) | "pr_hierarchical"
```

If `merge_mode == "direct"`: skip the rest of this subsection — behavior is
unchanged from v0.1.

If `merge_mode == "pr_hierarchical"`:

1. **Refuse fast if the remote/gh prerequisites are missing:**
   ```bash
   sd remote_check || exit 1   # surfaces the actionable error verbatim
   ```
   Do NOT silently fall back to `direct`.
2. **Ensure the sprint integration branch exists — on origin and current**
   (create off `default_branch` at the first slice; reuse otherwise):
   ```bash
   sprint_branch="$(sd sprint_branch_name "$sprint_id")"
   default_branch="$(sd manifest_get '.canonical.default_branch')" || default_branch="main"
   sd branch_sync "$default_branch"   # fast-forward local main/default after prior sprint→main PRs
   sd branch_create_from "$default_branch" "$sprint_branch"   # reuses origin/$sprint_branch when it exists (fresh clone / deleted local); else cuts from $default_branch (first slice)
   sd branch_sync "$sprint_branch"   # FIRST: fast-forward a reused base if a prior slice PR already merged
   sd branch_push "$sprint_branch"   # THEN: ensure the base exists on origin for the slice→sprint PR
   ```
   **Halt on any non-zero return above.** `branch_sync` HARD-FAILS when a local
   base has *diverged* from `origin` (or cannot be fast-forwarded). On any failure,
   surface the helper's error verbatim and have the user reconcile the branch
   manually — do NOT branch the slice off a stale or diverged base.
   **Order matters.** Sync the local `$default_branch` before cutting a new
   sprint branch; a prior sprint→main PR (or any remote update) advances
   `origin/$default_branch`, and a stale local default branch would omit landed
   commits from the next sprint. Then `branch_sync "$sprint_branch"` runs
   **before** `branch_push`: a merged slice PR advances `sprint-N` on the remote,
   so the local base is stale; pushing first would be rejected non-fast-forward
   (and the next slice could never reach the sync). Sync fast-forwards the reused
   local `$sprint_branch` to `origin/$sprint_branch` (no-op on the first slice,
   when origin has no `$sprint_branch` yet); then `branch_push` creates it on
   origin (first slice) or is a no-op fast-forward (later slices). The slice then
   branches off the fresh base.
3. **Slice-ordering check:** if a prior slice's PR into `$sprint_branch` is still
   open, surface it per `references/git-workflow.md` (slice-ordering rule) and wait
   for the user before continuing.
4. **Create the slice branch off the sprint branch:**
   ```bash
   slice_branch="$(sd slice_branch_name "$vs_id")"
   sd branch_create_from "$sprint_branch" "$slice_branch"
   ```
   Carry `$slice_branch` forward — §8.1 bases work-item worktrees on it and §8.6
   merges into it.

### 3.4 Read MASTER-SPEC + memory bank + cursor

- **MASTER-SPEC.md** — read via the manifest-resolved master-spec path. Surfaces project class, constraints, tech stack — feeds decomposition rationale.
- **Memory bank Tier 0** — auto-loaded by scaffold-dev's SessionStart hook (per SPEC §15.1, §18). If the hook hasn't fired in this session (e.g., started outside the AI workspace), surface a soft warning and continue.
- **Active-context cursor** — read `<ai-workspace>/.claude/memory-bank/05-active-context.md` for the current active sprint / slice / round position (per SPEC §17). If the cursor names a different active slice and the user is invoking this skill for a NEW slice, surface: *"Cursor shows VS-<X.Y.Z> active. Plan VS-<N.M.K> as a new slice (cursor will update on first commit), or resume VS-<X.Y.Z> instead?"* and wait for choice.

---

## 4. Decomposition (4-5 work items + grill-me gate 1)

Propose a draft decomposition into 4-5 work items, surfaced to the user as a numbered list with one-line summaries. Each work item:

- Targets ~200-500 LOC of canonical changes (the feature-size band per SPEC §4.4).
- Carries a stable `<slice-index>.<nn>` identifier — e.g., `1.01`, `1.02` for `VS-1.1.1` (slice index 1), `2.01` for `VS-1.1.2` — that survives reordering. The `<slice-index>` is the slice's position within its sprint (the 3rd field of the id); the two-digit `<nn>` suffix is deliberate (per SPEC §4.4). Keep work ids compact (`1.01`, **not** the 4-dotted `1.1.1.01`): the work id is unique across sibling slices in a sprint because the branch and path also carry `sprint-<sprint_id>`.
- Has a kebab-case slug for its directory name (`work-1.01-pulse-db-migration`).
- Declares dependencies on prior work items as a list of `<slice-index>.<nn>` ids (used for §5 DAG sort).
- Carries an explicit rationale: why this slice and why this size.

**Iteration loop:**

1. Surface the draft (numbered list, one-line summaries).
2. Ask: *"This decomposition: accept as-is, refine (which items?), or restart?"*
3. On refine: re-draft per user feedback. Loop until the user accepts.

Anti-patterns:

- **Mega-items.** A "build the whole API surface" item that hides 1500 LOC behind one bullet is a decomposition failure — break it.
- **Microscope items.** A "rename one constant" item is too fine — fold it into a sibling.
- **Hidden dependencies.** If items 1.02 and 1.03 both require a schema migration that's not its own item, surface the migration as 1.01.
- **Demoability drift.** Each work item should advance at least one demo criterion from the VS block; if an item advances zero, justify or merge.

### 4.1 grill-me offer (gate 1, post-decomposition)

After the user accepts the decomposition, probe for ai-mentor v2.0 via `sd_compose_detect_ai_mentor` (lib/compose.sh — filesystem probe at `~/.claude/plugins/cache/*/ai-mentor/*/skills/grill-me/SKILL.md`). If present, surface this explicit offer:

> Decomposition settled (N items). Want to grill-me on it before locking the spec authoring? (yes/no, default no)

This is an **offer**, not auto-invocation (eval S1 rejects silent skip; S1 also rejects silent invocation). The user can:

- **yes** → invoke `Skill(ai-mentor:grill-me)` with `target=decomposition, context=<decomp-summary>`. When grill-me returns, the user may revise the decomposition; loop back to §4 if so.
- **no / skip** → record the skip and proceed to §5.

If ai-mentor is absent: skip the offer silently (no warning needed — grill-me is enrichment, not a contract).

---

## 5. Round identification (strict-layer DAG)

Run a strict-layer topological sort over the declared dependency edges from §4. Output: a sequence of rounds, where round K contains all work items whose dependencies are fully covered by rounds 1..K-1.

Surface the proposed round structure to the user:

> Round 1: 1.01, 1.02 (parallel)
> Round 2: 1.03 (depends on 1.01)
> Round 3: 1.04, 1.05 (parallel; both depend on 1.03)

Then ask:

> Use the proposed rounds, loosen (move items earlier — must not violate declared deps), or tighten (move items later — always allowed as soft ordering)?

Iterate until accepted. Persist the round assignment in each work item's spec (§6).

**Discipline:**

- **No dep-violating loosening.** If the user requests "move 1.03 into round 1 alongside 1.01", check the dependency graph — refuse with: *"1.03 depends on 1.01; can't run in the same round. Loosen by dropping the dependency, or keep the proposed round."*.
- **Tightening is always allowed.** The DAG produces the *minimum* round count; the user may always serialize further (e.g., turn a parallel-2 round into two serial rounds) — that's soft ordering, not a dep violation.
- **No empty rounds.** If user edits produce a round with zero items, collapse and renumber.

---

## 6. Spec authoring upfront (§5.5 contract)

At this point, author the FULL slice scaffold to disk — README + every work-item spec + empty placeholder files. This MUST happen BEFORE the architect-critic invocation (§7); the eval S1 contract requires all spec files to exist on disk when the critic skill is invoked.

### 6.1 Slice directory layout

Resolve the slice root. The sprint segment is the **field-read `sprint_id`** (§3.3), NOT a split of the slice id:

```bash
# vs_id is the full 3-part id, e.g. "VS-1.1.1"; sprint_id e.g. "1.1"
slice_root="${ai_workspace}/docs/specs/sprint-${sprint_id}/${vs_id}-${vs_kebab}"
mkdir -p "$slice_root"
# → …/docs/specs/sprint-1.1/VS-1.1.1-<kebab>
```

For each work item, create (work id is the compact `<slice-index>.<nn>` from §4 — e.g. `1.01` for the first slice's work items — never the full 3-part slice id re-embedded):

```text
${slice_root}/
├── README.md
└── work-${work_id}-${work_kebab}/
    ├── spec.md
    ├── handoff.md       (empty placeholder; populated per-round in §8)
    └── report.md        (empty placeholder; populated by implementer subagent in §8)
```

The `handoff.md` and `report.md` placeholders are created as empty files (`: > "$path"` or equivalent zero-byte writes). They're authored later in the lifecycle — handoff at round start, report by the subagent — but creating the placeholders here keeps the directory shape uniform and lets `git status` / IDE file trees show the full slice surface at planning time.

### 6.2 Template substitution

Use `sd_render` (lib/render.sh, ported from scaffold-onboard) to fill templates:

- `templates/vertical-slice-readme.md.tmpl` → `${slice_root}/README.md`
  - Vars: `vs_id`, `vs_name`, `vs_description`, `demo_criteria` (the `auto:` / `user:` lines from ROADMAP), `work_items_table`, `round_plan`, `sprint_context`.
- `templates/work-item-spec.md.tmpl` → each `work-N.NN-<kebab>/spec.md` (8 sections per SPEC §9). Author §6 `acs_block` as machine-checkable `auto:` / `user:` lines per the SPEC §14.1 grammar — one `auto:` line per programmatically-verifiable AC, in exactly this shape:

  ```
  - [ ] AC-1 auto: `pytest tests/test_foo.py` → expected: exit 0
  - [ ] AC-2 auto: `grep -q "TARGET" src/foo.py` → expected: exit 0
  - [ ] user: click "Export" and confirm a CSV downloads
  ```

  Two hard requirements the `lib/verify.sh` helpers enforce — get either wrong and the gate misfires: **(a)** the command MUST be wrapped in backticks — `sd_verify_auto_step` extracts the command from the backticks, and an un-backticked command is rejected as malformed so the AC never runs; **(b)** every **`auto:`** AC line MUST carry an `AC-N` label — `sd_verify_report_cross_check` keys off `AC-N` IDs, and a spec with none *silently skips* the report cross-check. Use ONLY the supported `expected:` forms: `exit 0`, `exit N`, `output contains <substring>` — the substring is **unquoted** (`sd_verify_auto_step` passes everything after `output contains ` straight to `grep -F`, so wrapping quotes would become part of the required output). No `count > 0` / arithmetic — unsupported. `user:` lines are manual demo steps and carry **no** `AC-N` — they're verified at slice-close, not cross-checked against `report.md` (a labeled `user:` row would be wrongly required in the report). These lines are the single AC source of truth the `implementation-checking` gate parses (§4). Do NOT author a parallel prose AC table — the table/`auto:` split is what caused the gate to find zero ACs (#36).

The worktree path and branch are computed at spec-authoring time (so the spec is self-contained as a fresh-session starter per §6.4) but the actual `git worktree add` does NOT happen until the round starts (§8.1).

### 6.3 grill-me offer (gate 2, post-spec)

After all specs are written, surface gate-2 grill-me (per SPEC §16.4 offer 2 — **before** architect-critic so undecided items surface first):

> Specs authored (N work items). Want to grill-me on the specs before adversarial review? (yes/no, default no)

- **yes** → `Skill(ai-mentor:grill-me)` with `target=specs, context=<spec-paths>`. Returns may produce edits; re-write affected spec.md files via `sd_render`, then proceed to §6.4.
- **no / skip** → proceed to §6.4.

Probe for ai-mentor presence first (silent skip if absent, per §4.1).

### 6.4 Spec-citations check (opt-in gate)

After specs are written and gate-2 grill-me has settled, offer the citation check **before** architect-critic so drift surfaces first:

> Specs authored (N work items). Want to verify spec citations (file paths, function signatures, REQ-IDs, ARCH §-refs) before adversarial review? (yes/no, default no)

- **yes** → invoke `Skill(scaffold-dev:verifying-spec-citations)` over each `work-N.NN-*/spec.md`. Drift reports may produce edits; re-write affected `spec.md` files via `sd_render` (or `sd render`), then continue to §7.
- **no / absent** → skip silently and continue to §7.

The check is enrichment, not a contract — never block slice planning on its absence or on a project without a REQ-ID scheme.

---

## 7. Architect-critic invocation (in-conversation, §16.3 moment 1)

After specs are written, gate-2 grill-me has settled, and the §6.4 citation-check offer has settled, invoke architect-critic for adversarial review.

### 7.1 Detection (filesystem probe; binary)

Call `sd_compose_detect_architect_critic` (lib/compose.sh). It walks `~/.claude/plugins/cache/*/architect-critic/*/skills/critiquing-spec/SKILL.md` and prints either `v0.2` or `absent`. This is **NOT a composition.json read** — scaffold-dev does not maintain a composition.json cache (per SPEC §16.3).

### 7.2 Invocation (when present)

When the probe returns `v0.2`:

1. Announce: *"Specs authored — invoking architect-critic for a spec-audit on the combined work-item specs. Type `skip` to bypass."*
2. End the turn and wait. If the user types `skip` (case-insensitive): log the skip in the slice README and proceed to §8.
3. Otherwise, invoke `Skill(architect-critic:critiquing-spec)` with:
   - `target=spec`
   - `depth=author` (per ac v0.2 §5.1 — author-depth is the lighter Claude-self-audit; close-depth at slice-close is a separate moment per §14.3)
   - `spec_paths=<list of all work-N.NN-<kebab>/spec.md absolute paths>`
   - Context note: this is the slice-spec-author moment per scaffold-dev SPEC §16.3 moment 1.
4. architect-critic runs its own challenge-resolution loop (sequential rebuttal, scoring, optional auto-promotion) and returns the structured summary.
5. When control returns: surface any challenges that stood as edit candidates. The user may accept-and-revise; for each accepted revision, re-write the affected spec.md via `sd_render`. If revisions are substantial, offer gate-3 grill-me on the fix-up (§9).

**Eval contract:** S1's tool-call log assertion requires exactly ONE `Skill(architect-critic:critiquing-spec)` invocation AFTER all spec files are written. Do NOT invoke before spec writes complete; do NOT invoke via Task tool; do NOT write to `inbox/` or `outbox/` paths (file-IPC was removed in architect-critic v0.2 per SPEC §16.3).

### 7.3 Absent / warn-and-skip (S4 contract)

If `sd_compose_detect_architect_critic` returns `absent`, emit ONE warning and continue (do NOT block, do NOT prompt to install, do NOT retry the probe):

> architect-critic not detected — adversarial review skipped. Install architect-critic v0.2+ via `/plugin install architect-critic` for spec audit at this moment.

The warning MUST reference either `architect-critic` (plugin name) OR `adversarial review` (capability name) so the user can identify what was skipped. Then proceed to §8. S4's assertion explicitly rejects silent skip AND rejects blocking error — warn-and-proceed is the only correct path.

### 7.4 Slice-plan handoff

After §7.2 or §7.3 settles, surface:

> VS-<N.M.K> specs authored and audited. Ready for round-1 execution — invoke "execute round 1" when ready.

Do NOT auto-spawn implementer-agent subagents on this same turn. Round execution (§8) is a separate user-initiated step. Eval S1 explicitly asserts that no `Task(subagent_type="scaffold-dev:implementer-agent", ...)` invocation and no `${canonical}/.worktrees/sprint-*/work-*` directories are created on the slice-planning turn.

---

## 8. Per-round execution loop

When the user invokes round execution (e.g., "execute round 1", "run round K"), enter the per-round loop. Rounds are processed in declared order (round 1, then 2, …); work items within a round are dispatched in parallel where the user opted to keep them in the same round.

### 8.1 Create worktrees

For each work item in the round:

```bash
sd worktree_add "${work_id}" "${vs_id}" "${kebab}" "${sprint_id}"
# Creates ${worktrees_dir}/sprint-${sprint_id}/work-${work_id}-${kebab}
# Branches per ${branch_naming} template — {N} = sprint_id (e.g. sprint-1.1),
# field-read in §3.3, NOT split from the slice id
# Base: canonical default branch HEAD at creation
```

Under `merge_mode=pr_hierarchical`, pass the slice branch as the base so the
worktree branches off the slice (not the canonical default branch):

```bash
sd worktree_add "${work_id}" "${vs_id}" "${kebab}" "${sprint_id}" "${slice_branch}"
```

Halt if `sd_worktree_add` fails (dirty canonical tree, existing branch, etc.). Surface the failure-response menu (SPEC §12.2 "Merge conflict" row adapted for setup conflicts).

### 8.2 Author handoff per work item

Render `templates/implementation-handoff.md.tmpl` into each `work-N.NN-<kebab>/handoff.md` via `sd_render`. The handoff is heavy + self-contained (~200-400 lines per SPEC §10): pre-flight calibration, worktree absolute path, what's already merged, memory-bank pointers, ACs embedded, verification commands embedded, constraints (git_policy + STAGE-not-commit + subagent return format), report template, notes-for-orchestrator footer.

The handoff works in BOTH contexts (per SPEC §6.4) — as a Task tool prompt AND as a manual fresh-session starter.

### 8.3 Dispatch implementer

**Resolve the backend first.** Each work item runs on either the Claude implementer subagent (default) or the optional Codex backend (SS-5), chosen by:

```bash
backend="$(sd backend_resolve [--backend <override>])"
```

Precedence: a **per-invocation override** (the user asked to run this slice/round on Codex, e.g. `/orchestrate VS-N --backend codex`) > the manifest's optional `.implementer_backend` > the default `claude_subagent`. An invalid value fails loud. Projects without the field run on Claude, unchanged.

The **manual fresh-session handoff** remains a first-class path for either backend whenever the user wants a fresh boundary: stop after writing the handoff and hand over the absolute `handoff.md` path — the handoff is self-contained by design.

#### 8.3a — `claude_subagent` (default)

For Claude Code, dispatch each work item in the round with:

```text
Task(
  subagent_type="scaffold-dev:implementer-agent",
  description="Execute work item ${work_id}",
  prompt="""
    Read handoff at <abs path to work-${work_id}-${kebab}/handoff.md>
    and execute the work item per its instructions.

    Your worktree: <abs path to ${worktrees_dir}/sprint-${sprint_id}/work-${work_id}-${kebab}>
    Use this path for all git operations and file edits in canonical.

    First turn: PRE-FLIGHT CHECK (per SPEC §6.2).
    Return structured response (gaps-surfaced | complete) per the multi-call protocol.
  """
)
```

The `scaffold-dev:` prefix on `subagent_type` is load-bearing — that's the registered custom subagent type per SPEC §6.1. Do NOT use the bare `implementer-agent` or any other prefix.

#### 8.3b — `codex` (optional backend, SS-5)

The Codex backend dispatches the **same** work item to the externally-installed `codex-plugin-cc` companion through `lib/codex.sh`, under the **same** `{mode,…}` contract, gaps-mode escalation, and no-commit boundary as the Claude path. The only new surface is async liveness — Codex is an external process, so the orchestrator polls for the surface. **Dispatch Codex work items sequentially within a round** (the companion's `--resume-last` resolves the latest session thread; concurrent same-session tasks race).

Per work item (let `WT` = the absolute worktree path):

1. **Pre-flight — hard gate, no silent fallback.**
   ```bash
   sd codex_preflight "$WT"
   ```
   rc≠0 → **STOP** and surface the remediation (§12.2). Do NOT fall back to Claude — the user explicitly chose Codex; quietly running Claude would violate intent.

2. **Assemble the prompt-file.** Codex does not auto-load the skill, so the contract is prompt-carried. Write a temp prompt file outside the worktree (for example under `${TMPDIR:-/tmp}`), not `$WT/.codex-prompt.md`, containing, in order: the full `executing-work-item` contract (read it from the installed scaffold-dev skill as the single source of truth, else treat the handoff's embedded constraints as binding); `Read the handoff at <abs handoff.md> and execute the work item per its instructions.`; `Your worktree: $WT — use it for all git operations and file edits.`; the no-commit prohibition `NEVER run git commit / push / pull / fetch; never launch nested subagents.`; and the return-contract instruction: *end your turn with a single fenced ```json block holding `{mode, report_path, summary, stage_status, gaps}` exactly as the Claude implementer returns; if pre-flight surfaces blocking gaps, emit `{"mode":"gaps-surfaced","gaps":[…]}` and stop.* Remove the temp prompt file after `sd codex_dispatch` returns a job id.

3. **Record baseline + dispatch + watch:**
   ```bash
   baseline="$(git -C "$WT" rev-parse HEAD)"
   prompt_file="$(mktemp "${TMPDIR:-/tmp}/sd-codex-prompt.XXXXXX.md")"
   # write the Codex prompt contract to "$prompt_file"
   job="$(sd codex_dispatch "$WT" "$prompt_file" [--model M] [--effort E])"
   rm -f "$prompt_file"
   term="$(sd codex_wait "$WT" "$job")"   # background+poll+stall+cap; one of: completed|failed|cancelled|stalled|capped|error
   ```
   Any `term` other than `completed` (`stalled`/`capped`/`failed`/`cancelled`/`error`) → surface the failure-response menu (§12.2 "Subagent crash/timeout" row); `sd codex_wait` already cancelled a stalled/capped job. A stall/cap is recoverable — re-dispatch (Codex `--resume-last`) or fall back to a manual session.

4. **Read the return** (only on `completed`):
   ```bash
   out="$(sd codex_result "$WT" "$job")"   # the {mode,…} JSON; rc≠0 → Codex emitted no parseable block → §8.4 malformed-return menu
   ```

5. **No-commit verify** before trusting the result:
   ```bash
   verdict="$(sd codex_verify_nocommit "$WT" "$baseline")"
   ```
   rc≠0 / `commit-violation` → surface loudly; the orchestrator decides remediation. A `complete` return with `ok-clean` (no staged/working-tree changes) is suspect → treat as a malformed/empty return; a `gaps-surfaced` return with `ok-clean` is expected.

6. **Join the Claude downstream unchanged.** The `{mode,…}` object feeds §8.4 exactly as a Claude subagent return would: `gaps-surfaced` → clarify + re-dispatch (Codex via `--resume-last`); `complete` → read `report.md`, proceed to §8.5 verification. Everything from here is backend-agnostic.

### 8.4 Process returns (§6.3 multi-call protocol)

Per SPEC §13, returns are processed **strictly in decomposition order** — work item N+1 is NOT verified until N is fully committed + merged. This prevents the H3 "1.03 verified while 1.02 failed" interleaving the adversarial review surfaced.

For each work item in decomposition order:

**`mode: gaps-surfaced`** — surface the gaps to the user in conversation, gather clarifications, append a `## Clarifications` section to the work item's `handoff.md`, then re-dispatch using the same backend that produced the gaps. For `claude_subagent`, re-invoke the same `Task(...)` dispatch with the same handoff path. For `codex`, re-run §8.3b with `sd codex_dispatch ... --resume-last` so the companion continues the prior Codex thread/session. Loop until pre-flight passes. If gaps loop 3+ iterations: halt and surface the failure-response menu (§12.2 "Subagent loops in gaps-mode" row) — suggest replan or manual implementer session.

**Blocker-recall (issues, #33).** On a `gaps-surfaced` return, before re-dispatching or escalating to the §12.2 menu, run `sd issue_list` and JUDGE whether an open issue already covers the surfaced gap. If one does, surface "known — see #N" and fold that into the clarification appended to the handoff (so the re-dispatched implementer proceeds informed) rather than treating the gap as novel. Judgment, not string-matching; skip silently if `sd remote_check` fails.

**`mode: complete`** — read `report.md` from disk (path returned by subagent), proceed to §8.5 verification.

**Malformed / crash / timeout** — halt and surface the failure-response menu (§12.2 "Subagent crash" row). Options: re-invoke, extend timeout + re-invoke, fall back to manual session per §6.4, abandon.

### 8.5 Verification (§12.1 gate)

After complete-mode return, invoke `implementation-checking` on the work item:

```text
Skill(scaffold-dev:implementation-checking) with: work_item_id=<N.NN>
```

That skill (per SPEC §12.1) runs each `auto:` AC step in the worktree, cross-checks the report against actuals, and consults `sd_rules_check` for R2 mcrule violations. On fail: surface the failure-response menu (§12.2 — AC fail, report cross-check, or rule check row as applicable).

**Fix-up grill-me (gate 3):** if the menu choice is "replan" or "re-spawn with fix-up", offer grill-me before re-authoring:

> Fix-up replan triggered. Want to grill-me on the failure before re-authoring the handoff? (yes/no, default no)

Per §4.1, probe ai-mentor first; offer only when detected.

### 8.6 Commit + merge

On verification pass:

1. Commit in the work-item worktree per `git_policy` (e.g., `git -C <worktree> commit -m "${commit_message}"`). The subagent staged but did NOT commit (per SPEC §6.2 constraint); the orchestrator owns the commit boundary.
2. Merge the work-item branch into the integration target via `sd_merge_work_item`.
   - `direct` mode: `sd merge_work_item "<worktree>" "<branch>"` (merges into
     `default_branch` — today's behavior).
   - `pr_hierarchical` mode: `sd merge_work_item "<worktree>" "<branch>" "${slice_branch}"`
     (merges locally into the slice branch; **no push, no PR at this level**).

   **HALT on conflict** per SPEC §11 — surface the failure-response menu ("Merge
   conflict" row): user resolves via `git merge --continue`, OR aborts via
   `git merge --abort` and replans integration.
3. Update VS README: mark work-item status complete.

Do **NOT** remove the worktree at round close — per SPEC §11, worktrees + branches survive until slice close for demo verification and retrospective harvest inspection.

### 8.7 Round-complete handoff

After all work items in the round are processed (committed + merged):

1. Update VS README: round status → complete.
2. **Deferral auto-file (agent-driven, #33).** Before surfacing round-complete, review each work item's `report.md` **"Deferrals"** section (you already read these reports during §8.4–8.5 — re-read the Deferrals section). This is judgment, not parsing:

   1. For each deferral, DECIDE whether it warrants a tracked GitHub issue (skip trivia and anything already tracked — use `sd issue_list` and judge for de-dup).
   2. Surface the proposed issues to the user as a single batch for a quick confirm (title + one-line why each). Never file silently.
   3. For each confirmed item, file + index via the same logic as `/defer`: `Skill(scaffold-dev:deferring-work-item)` (or inline `sd issue_create` + append the `[TD] …→#N` line).

   If `sd remote_check` fails (no gh/remote), SKIP filing — note that the deferrals remain in the reports' Deferrals sections for later — and proceed to round-complete WITHOUT blocking. There is **no deterministic parser** of the Deferrals section; you read and judge.

3. Surface:

> Round K complete (M items committed + merged). Ready for round K+1, or close VS-<N.M.K>?

If the user says "next round": loop §8.1 for round K+1.
If the user says "close slice" (or equivalent): proceed to §10.

---

## 9. State management (cursor + slice README)

State IS the artifacts (per SPEC §17 — no separate state file). The two cursors:

- **`<ai-workspace>/.claude/memory-bank/05-active-context.md`** — top-level cursor: active sprint, active slice, active round, active work item. Updated via `sd_state_write_cursor` after each round transition.
- **`${slice_root}/README.md`** — slice-level cursor: per-work-item status (planned / in-progress / complete), per-round status, demo verification results (filled by `closing-vertical-slice`).

**Discipline:**

- Update the active-context cursor on round transitions, not on every commit (commits update the work-item status in the slice README; the top-level cursor moves on round boundaries).
- Never write to the same file the implementer-agent subagent writes (per SPEC §17 write-conflict separation: orchestrator → AI workspace; subagent → canonical worktree + its own `report.md`).

---

## 10. Slice-close handoff

When the user signals slice close (after all rounds complete), suggest the slice-close ceremony skill:

> All rounds complete. Invoke `Skill(scaffold-dev:closing-vertical-slice)` (or `/close-slice VS-<N.M.K>`) to run the 3-layer close ceremony: auto-demo execution → manual-demo prompting → architect-critic adversarial review at close depth → retrospective + memory-bank harvest → worktree + branch cleanup.

Do NOT auto-invoke `closing-vertical-slice` — slice close is a deliberate gate the user opts into (often after manual demoing). This skill's lane ends at the round-complete handoff; the close ceremony is downstream.

---

## 11. Failure-response menu (per §12.2)

Whenever a per-round step fails — verification fail, report cross-check mismatch, project rule violation, merge conflict, subagent crash/timeout/malformed — surface the matching row from SPEC §12.2 as an explicit menu and wait for user choice. Never silently retry, never auto-escalate.

The five failure types and their menus are codified in SPEC §12.2 (a table the user can reference). This body does not re-inline the table — it routes failures to the matching row and presents options 1..N as a numbered list with one-line descriptions.

**Hard discipline:** on any halt, leave the workspace in a deterministic state — items 1..N merged, item N+1 halted with menu surfaced, items N+2.. not started. Worktrees + branches preserved for user inspection. Never auto-cleanup on halt.

---

## 12. Bash bookkeeping helpers

This skill never bash-orchestrates the judgment work (which work items to propose, when to fire the grill-me offer, how to interpret a subagent gap, whether a verification fail warrants replan or re-spawn). It calls helpers for I/O and templating only.

**Manifest (lib/manifest.sh — T3.2):** `sd_manifest_discover`, `sd_manifest_require`, `sd_manifest_get`, `sd_manifest_resolve`.

**State (lib/state.sh — T3.3):** `sd_state_read_cursor`, `sd_state_write_cursor`.

**Worktree (lib/worktree.sh — T3.4):** `sd_worktree_add`, `sd_worktree_list`, `sd_worktree_remove` (used only at slice-close per §11).

**Merge (lib/merge.sh — T3.5):** `sd_merge_work_item`.

**Composition (lib/compose.sh):** `sd_compose_detect_architect_critic`, `sd_compose_detect_ai_mentor`.

**Render (lib/render.sh):** `sd_render <template> <output> <var=val ...>` — Wabash-style `{{var}}` substitution ported from scaffold-onboard.

Implementations live in their respective lib files (Phase 3 tasks). macOS-portable patterns (BSD awk, bash 3.2) required for any inline snippets; prefer calling the helpers over re-inlining shell.

---

## 13. Slash-command interaction (`/orchestrate VS-N.M.K`)

The `/orchestrate VS-N.M.K` slash command (`commands/orchestrate.md`) exports the raw arg string as `$ARGUMENTS` (env-var bridge per `feedback_slash_command_dollar_n_bug` — Claude Code substitutes `$1`/`$2`/etc. at template-render time and silently corrupts bash positionals).

Parse `$ARGUMENTS` in bash; never reference `$1` / `$2`. Extract the VS-id (e.g., `VS-1.1.1` — the full 3-part id `VS-<phase>.<sprint>.<slice>`) and proceed to §3 pre-flight.

Unknown or missing VS-id → one-line error + stop:

> /orchestrate requires a VS-id argument. Example: /orchestrate VS-1.1.1

---

## 14. Anti-patterns (do not do these)

- **Reading manifest fields via raw `jq -r '.routing.roadmap' .workspace/pairing.json`.** Eval S1's green-light criterion is binding — all manifest reads MUST route through `sd_manifest_get` / `sd_manifest_resolve`. The helpers handle walk-up discovery + variable expansion; inline jq breaks both.
- **Paraphrasing the manifest-absent refusal.** The literal sentence in §3.1 — including `/init-workspace` and `/pair-workspace` slash-command tokens — is load-bearing. Eval S2 rejects substitutes that omit either token.
- **Authoring specs AFTER architect-critic invocation.** Eval S1 requires all spec files on disk BEFORE the `Skill(architect-critic:critiquing-spec)` call. Spec writes are the upstream contract; the critic audits what's written.
- **Invoking architect-critic via Task tool or via `inbox/` / `outbox/` file IPC.** Eval S1 rejects both. The only correct invocation is the in-conversation `Skill(architect-critic:critiquing-spec)` pattern per SPEC §16.3.
- **Spawning implementer-agent subagents on the slice-planning turn.** Eval S1 explicitly asserts that no `Task(subagent_type="scaffold-dev:implementer-agent", ...)` calls and no worktrees appear on the planning turn. Round execution is a separate user-initiated step.
- **Auto-fixing ROADMAP.md when the target VS is missing.** Eval S3 asserts no writes to ROADMAP.md on the missing-VS path. Surface the error + the `/plan-roadmap --add-slice` hint and stop.
- **Silent skip when architect-critic is absent.** Eval S4 rejects silent skip — emit the warning per §7.3, then proceed. Also rejects blocking error — never prompt the user to install architect-critic.
- **Auto-invoking grill-me.** All three grill-me gates (§4.1 decomposition / §6.3 spec / §8.5 fix-up replan) are explicit offers. Eval S1 asserts the offer surfaces as a user-decidable question; auto-invoke fails the assertion.
- **Skipping verification before commit + merge.** SPEC §13 requires `implementation-checking` between subagent return and commit. Never commit unverified work item output.
- **Removing worktrees at round close.** SPEC §11 defers worktree removal to slice close. The branches + worktrees need to survive for slice-close demo verification.
- **Letting this body exceed 500 lines.** Hard cap per superpowers:writing-skills Pass D guidance.
- **Calling `Skill(architect-critic:critique)`** (the legacy v0.1.x slash-command-shaped name). The v0.2 skill is `critiquing-spec` per SPEC §16.3 last paragraph.

---

## 15. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: how to decompose the VS, how to interpret a subagent gap (blocking vs nice-to-have), whether a verification fail warrants replan or re-spawn, when the round-complete handoff is the right next thing to say.
- **Bash helpers** (`lib/*.sh`) handle pure I/O: manifest reads, atomic state writes, worktree mechanics, merge orchestration, filesystem probes, template substitution.
- **`scaffold-dev:implementer-agent`** (the subagent dispatched via Task) owns work-item execution inside its worktree — it has its own skill body (`executing-work-item`) baked in as system prompt and runs TDD + verification-before-completion per SPEC §6.5.
- **`implementation-checking`** owns the per-work-item verification gate; you invoke it after each subagent complete-mode return.
- **`architect-critic:critiquing-spec`** owns the adversarial review; you invoke it once after specs are written, and it runs its own internal challenge/rebuttal loop before returning control.
- **`ai-mentor:grill-me`** owns the stress-test interrogation; you offer it at three gates and the user opts in or out.
- **`closing-vertical-slice`** owns the slice-close ceremony; you hand off to it at §10 when the user signals close.
- **The user** is the final authority. They accept or refine the decomposition, accept or adjust the round structure, opt in or out of every grill-me offer, choose the failure-response option, and gate the slice close. You never auto-advance past a decision boundary.

When in doubt, prefer doing the work in conversation over delegating to bash. The bookkeeping-vs-judgment line is: if the next action involves a user-facing decision (which work items to propose, how to recap a round, whether to escalate a failure), it belongs here in the skill body; if it's pure I/O (manifest read, worktree create, template render, atomic state write), it belongs in a lib helper.
