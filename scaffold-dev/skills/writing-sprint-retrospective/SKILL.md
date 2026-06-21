---
name: writing-sprint-retrospective
description: Aggregate per-slice retrospectives for a closed sprint and author `sprint-N/sprint-retrospective.md` (goal vs. delivered, per-slice rollup, cross-slice patterns, memory-bank totals, lessons). Refuses if ANY slice lacks `retrospective.md` — names the un-closed slice, points at `closing-vertical-slice`. Read-only against slice retros. Use this when the user says `close sprint N`, `write sprint retro`, `aggregate sprint retros`, `sprint retrospective for sprint N`, or invokes `/close-sprint N`.
---

# writing-sprint-retrospective

You are scaffold-dev v0.1's sprint-retro aggregator. N slice retros in (one per closed VS-N.M.K), one sprint retro out at `sprint-N/sprint-retrospective.md`. The hard part is the precondition gate — every slice in the sprint must have closed (i.e., have a `retrospective.md` on disk) before aggregation makes sense. If even one slice is still in flight, you bail with a remediation hint and the un-closed slice's ID.

This skill is the sprint-retro composer. It does NOT close slices (that's `closing-vertical-slice` per §14 — the upstream contract that produces each `retrospective.md` this skill consumes), does NOT sweep sprint-scoped handoffs at sprint close (that's `closing-vertical-slice`'s §11 conditional final-slice branch per the v0.1 cleanup ownership), does NOT compose the carry-forward handoff (`sprint-N-to-N+1-handoff-XXXX.md` — that's `handing-off-session`'s S1 scenario), and does NOT re-promote sprint-aggregate observations into memory bank. Sprint close writes **nothing** to the memory bank — the per-slice harvest is the single promotion event (see `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**). The sprint retro AGGREGATES counts; it does NOT re-promote items.

Phase 1 RED→GREEN: this body's behavior is contracted by `scaffold-dev/evals/writing-sprint-retrospective.md` — the two scenarios there (S1 happy-path aggregation of 3 closed slices, S2 mid-sprint refusal naming the un-closed slice) are the binding spec.

---

## 1. Overview

When invoked, you:

1. **Discover the workspace-init pairing manifest** via `lib/manifest.sh` walk-up helpers. Refuse fail-fast if absent (mirrors `planning-vertical-slice` §3.1).
2. **Resolve `routing.specs_dir`** to `<ai-workspace>/docs/specs/`.
3. **Resolve the sprint-N target** from the trigger phrase (`close sprint 3` → N=3) or the active-context cursor.
4. **Enumerate slice directories** under `${specs_dir}/sprint-${N}/` matching the `VS-${N}.*` pattern.
5. **Check each slice for closed-state** — presence of `retrospective.md` (the file `closing-vertical-slice` writes at §14.4 / §16b).
6. **Branch on closure state:**
   - If any slice is un-closed → **§6 fail-fast** naming the un-closed slice ID + remediation hint. Stop.
   - All slices closed → proceed.
7. **Read each slice's `retrospective.md`** (all of them — eval S1 verifies all 3 reads appear in tool-call log).
8. **Read `<ai-workspace>/ROADMAP.md`** to extract the sprint-N goal block.
9. **Aggregate** — extract cross-slice patterns, memory-bank impact totals (count items added per memory-bank file across all slices), and lessons-learned across the slice retros.
10. **Confirm cross-slice patterns with the user** (one accept/edit/reject round).
11. **Render `templates/sprint-retrospective.md.tmpl`** with the 6 §16b sections populated.
12. **Write the file** at `${specs_dir}/sprint-${N}/sprint-retrospective.md`.
13. **Emit the final assistant message** naming the absolute path.

---

## 2. When to use

**Trigger phrases (description-match):**

- `close sprint N` (e.g., `close sprint 3`) — S1 triggers via this phrase
- `write sprint retro` — S2 triggers via this phrase
- `aggregate sprint retros`
- `sprint retrospective for sprint N`
- `/close-sprint N` (future slash command — `$ARGUMENTS` env-var bridge)

The first two phrase forms are load-bearing. Do not paraphrase these in your acknowledgement.

**Do NOT auto-invoke when:**

- The user wants to *close a slice* (that's `closing-vertical-slice` per §14). The sprint retro is downstream of all slice closes.
- The user wants to compose a *carry-forward handoff* (that's `handing-off-session` per §6b — orthogonal).
- No workspace-init pairing manifest exists. Refuse with the same verbatim string `planning-vertical-slice` uses (§3.1).

If the user types something ambiguous like "we're done with sprint 3", confirm: *"Author the sprint-3 retrospective by aggregating the 3 VS retros (assumes all slices have closed via `closing-vertical-slice`)?"*. Don't infer-and-aggregate silently — sprint retro is a deliberate ceremony.

---

## 3. Pre-flight + manifest discovery

### 3.1 Manifest discovery (refuses fail-fast)

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash shebang forces a bash runtime under it regardless of the calling shell — required because Claude Code's Bash tool runs zsh by default on macOS):

```bash
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

Never read manifest fields via raw `jq`. All reads route through `sd_manifest_get` / `sd_manifest_resolve`. Eval S1 + S2 both check for at least one `lib/manifest.sh` helper invocation.

### 3.2 Resolve the specs dir + sprint number

```bash
ai_workspace="$(sd manifest_get '.ai_workspace.root')"
specs_dir="$(sd manifest_resolve "$(sd manifest_get '.routing.specs_dir')")"
roadmap_path="$(sd manifest_resolve "$(sd manifest_get '.routing.roadmap')")"
```

If `routing.specs_dir` is absent, fall back to `${ai_workspace}/docs/specs/`. If `routing.roadmap` is absent, fall back to `${ai_workspace}/ROADMAP.md`.

### 3.3 Resolve sprint N

Resolution priority:

1. **Explicit N** in the trigger phrase (e.g., `close sprint 1.1`, `/close-sprint 1.1`) — extract the sprint id. `N` is the **dotted `sprint_id`** (`<phase>.<sprint>`, e.g. `1.1`) in the 3-part era; a bare integer is tolerated for back-compat. Both flow through unchanged: the dir is `sprint-${N}` and the slice glob `VS-${N}.*` matches `VS-1.1.*` (3-part) or `VS-3.*` (legacy).
2. **Active-context cursor** at `${ai_workspace}/.claude/memory-bank/05-active-context.md` — read the current sprint (the cursor stores the dotted `sprint_id`).
3. If neither produces a value, ask: *"Which sprint? (e.g., `1.1`)"* and wait.

### 3.4 Locate the sprint dir

```bash
sprint_dir="${specs_dir%/}/sprint-${N}"
```

If `${sprint_dir}` does not exist, surface:

> Sprint directory `<sprint-dir>` not found. Has sprint-${N} been planned? Run `/plan-roadmap` (scaffold-onboard) or `planning-vertical-slice` to author its slices first.

Then stop. v0.1 does not auto-create sprint directories.

---

## 4. Slice enumeration + closure check

### 4.1 Enumerate slice directories

Glob for slice subdirs matching `VS-${N}.*`:

```bash
slice_dirs=()
while IFS= read -r d; do
  slice_dirs+=("$d")
done < <(find "$sprint_dir" -maxdepth 1 -mindepth 1 -type d -name "VS-${N}.*" | sort)
```

The directory listing MUST appear in the tool-call log (eval S2 verifies a directory listing of `sprint-${N}/`). If `${#slice_dirs[@]} -eq 0`, surface:

> Sprint-${N} directory `<sprint-dir>` contains no slice subdirectories (expected `VS-${N}.*` pattern). Has planning landed?

Then stop.

### 4.2 Check each slice for `retrospective.md`

For each slice, check whether `<slice-dir>/retrospective.md` exists:

```bash
unclosed=()
for sd in "${slice_dirs[@]}"; do
  if [[ ! -f "${sd}/retrospective.md" ]]; then
    unclosed+=("$(basename "$sd")")
  fi
done
```

Each existence check appears in the tool-call log (eval S2 verifies existence checks against `retrospective.md` in each slice subdir).

### 4.3 Branch on closure state

- If `${#unclosed[@]} -gt 0` → §5 fail-fast.
- Else → proceed to §6.

---

## 5. Mid-sprint refusal (S2 contract)

When at least one slice has no `retrospective.md`, surface a refusal naming the un-closed slice(s) AND a remediation hint. For a single un-closed slice (the typical S2 case):

> Sprint-${N} retrospective requires all slices closed first. **`VS-${N}.M`** (`<kebab>`) has no `retrospective.md` — the slice is still in flight or has not yet run the `closing-vertical-slice` ceremony. Close the slice first via `/close-slice VS-${N}.M` (or the `closing-vertical-slice` skill), then re-invoke this skill.

For multiple un-closed slices, name each one in the same shape.

**Binding constraints (eval S2 assertions):**

- The message names `VS-${N}.M` explicitly — quoted or otherwise identifiable. Vague phrasings like "a slice is still open" are a FAIL.
- The message includes EITHER a slash-command token (`/close-slice VS-${N}.M`) OR an explicit naming of the `closing-vertical-slice` skill. The judge accepts either phrasing.
- The message does NOT suggest aggregating the closed slices and skipping the un-closed ones — partial aggregation is a FAIL.
- No `Write` of `sprint-retrospective.md` appears in the tool-call log.
- The skill MAY have Read the closed slices' retros for status confirmation (e.g., to verify they're well-formed) but MUST NOT have begun composing the sprint retro — eval S2 looks for absence of compose-mode activity past the existence-check step.

Then stop. The user closes the un-closed slice(s) via `closing-vertical-slice`, then re-invokes this skill.

---

## 6. Read all slice retros + the sprint goal

### 6.1 Read each slice's `retrospective.md`

Iterate `${slice_dirs[@]}` and Read each `<slice-dir>/retrospective.md` via the Read tool (absolute path; not `cat`). Eval S1 explicitly counts the slice-retro Reads — exactly 3 distinct Reads for the 3-slice fixture (`VS-3.1-user-auth`, `VS-3.2-redis-cache`, `VS-3.3-feature-flags`). Missing any is a FAIL.

The slice retro structure (per `closing-vertical-slice` §8 — 7 sections per §16b):

1. Slice metadata
2. Demo verification results
3. Architect-critic findings
4. Memory bank harvest — names which memory-bank files were modified + count per file
5. Deviations + deferrals
6. Lessons learned — 2-3 bullets
7. Reference index

Extract for aggregation:

- **Slice ID + name** (section 1) — for the per-slice rollup.
- **Memory-bank harvest counts** (section 4) — by target file (e.g., `03-code-patterns.md: 2 items`, `09-known-issues.md: 1 item`).
- **Lessons** (section 6) — to aggregate into sprint-level lessons.
- **Deviations** (section 5) — for cross-slice pattern detection.

### 6.2 Read the ROADMAP sprint goal

```bash
# Extract the sprint-N goal block from ROADMAP.md
```

Read `${roadmap_path}` via the Read tool. Locate the sprint-${N} block (typically `### Sprint ${N}: <name>` or `## Sprint ${N}` per scaffold-onboard's R1.A authoring). Extract the sprint goal sentence/paragraph for the "Sprint goal vs delivered" section.

Eval S1 explicitly checks a Read of `<ai-workspace>/ROADMAP.md` appears BEFORE the Write of `sprint-retrospective.md`. The relative position is binding.

---

## 7. Aggregate cross-slice patterns + totals

### 7.1 Memory bank impact totals

Aggregate the per-slice harvest counts into a per-file total:

```
03-code-patterns.md: 3 items (VS-3.1: 2, VS-3.2: 1)
09-known-issues.md: 1 item (VS-3.2: 1)
04-data-models.md: 1 item (VS-3.3: 1)
Total: 5 items across 3 memory-bank files
```

**Numeric-counts invariant (binding per eval S1):** the "Memory bank impact totals" section MUST name at least 2 memory-bank files (the eval fixture seeds counts across multiple files) AND the counts MUST be NUMERIC (literal integers — "3", "1") not qualitative ("several", "many", "a few"). The judge rejects qualitative phrasings.

### 7.2 Cross-slice patterns

Surface auto-derived patterns to the user as a draft. Candidates include:

- **Shared memory-bank targets** — e.g., "all 3 slices touched `03-code-patterns.md` → opportunity to consolidate".
- **Common deviations** — e.g., "VS-3.1 and VS-3.2 both deferred error-path test coverage".
- **Repeated lessons** — e.g., "subagent dispatches needed absolute paths in 2 of 3 slices".

Prompt: *"Cross-slice patterns I drew from the 3 slice retros — accept / edit / add anything?"*. Wait for the user's response. The user may keep / edit / add patterns; eval S1's pre-injected response accepts the auto-derived pattern.

### 7.3 Sprint-level lessons

Aggregate the slice-level lessons (slice retro section 6) into sprint-level lessons. Prefer lessons that appear in multiple slices (signal: actually patterns, not one-offs) over slice-specific lessons. Surface to user: *"Lessons for sprint-${N+1} — keep / edit / drop / add?"*.

---

## 8. Render + write the sprint retrospective

### 8.1 Template variables

Render `templates/sprint-retrospective.md.tmpl` (Phase 2 T2.6) via `lib/render.sh`'s `{{var}}` substitution.

```
{{sprint_n}}                  3
{{sprint_name}}               (from ROADMAP block, optional)
{{sprint_start_date}}         YYYY-MM-DD (from earliest slice metadata)
{{sprint_close_date}}         YYYY-MM-DD (today)
{{slice_ids}}                 VS-3.1, VS-3.2, VS-3.3
{{sprint_goal_quote}}         "Ship user auth + caching + feature-flags MVP" (from ROADMAP)
{{delivered_summary}}         USER-CONFIRMED
{{per_slice_rollup}}          one row/block per slice with status + key outcome
{{cross_slice_patterns}}      USER-CONFIRMED (§7.2)
{{memory_bank_totals}}        per-file numeric counts (§7.1)
{{sprint_lessons}}            USER-EDITED (§7.3)
```

### 8.2 6-section invariant (binding per eval cross-scenario)

The written file MUST contain these six §16b section headings, in order, as `##` or `###` level markdown headings:

1. **Sprint metadata** — sprint ID, dates, slice IDs included.
2. **Sprint goal vs delivered** — pulls the goal from ROADMAP.md, contrasts against delivered slice outcomes.
3. **Per-slice rollup** — one row/block per slice. Eval S1 verifies all 3 slice IDs (`VS-3.1`, `VS-3.2`, `VS-3.3`) appear here explicitly.
4. **Cross-slice patterns** — user-confirmed patterns from §7.2.
5. **Memory bank impact totals** — per-file numeric counts from §7.1.
6. **Lessons for next sprint** — aggregated + user-edited lessons from §7.3.

A 7th "Reference index" appended section is acceptable but not required. Eval S1 accepts case-insensitive variants and minor pluralization ("Lesson for next sprint"); rejects substitutes that drop or merge sections.

### 8.3 Write

```bash
SD_PLUGIN_ROOT="$(dirname "$(dirname "$(command -v sd)")")"
target_path="${sprint_dir}/sprint-retrospective.md"
tmp_path="${target_path}.tmp.$$"
sd render_template "${SD_PLUGIN_ROOT}/templates/sprint-retrospective.md.tmpl" > "$tmp_path"
mv "$tmp_path" "$target_path"
```

**Read-only against slice retros (binding):** the skill READS each slice's `retrospective.md` but NEVER mutates them. Eval S1 explicitly checks: no `Edit` or `Write` against any slice's `retrospective.md` appears in the tool-call log.

The Write of `sprint-retrospective.md` is under `${sprint_dir}` directly (NOT under any slice subdirectory; NOT in `<canonical>/`). Eval S1 explicitly checks the Write path.

---

## 8a. Open the sprint→main PR (pr_hierarchical only)

Runs only when `sd merge_mode` == `pr_hierarchical`, AFTER the sprint
retrospective is authored and all slice PRs into `sprint-${N}` have merged, and
**BEFORE §9's final message** (so the turn never ends before the PR is opened).
See `references/git-workflow.md` (cited by `planning-vertical-slice`) for the
topology and the binding pre-merge gate.

1. **Confirm slice PRs merged:** if any slice PR into `sprint-${N}` is
   still open, surface it and stop — the sprint isn't ready to integrate to `main`.
2. **Resolve, sync, then push the sprint branch:**
   ```bash
   sprint_branch="$(sd sprint_branch_name "$N")"
   sd branch_sync "$sprint_branch"   # FIRST: fast-forward the local base to origin (slice PRs advanced it remotely)
   sd branch_push "$sprint_branch"   # THEN: push (a stale local base would be rejected non-fast-forward)
   ```
   **Halt on a non-zero return.** `branch_sync` HARD-FAILS if the local
   `$sprint_branch` has diverged from `origin` (or can't be fast-forwarded);
   surface the error and have the user reconcile it before opening the sprint→main
   PR — do not push/PR a diverged base.
3. **Compose the PR body:** the sprint retrospective summary + the slice list +
   linked issues.
4. **Open the PR:**
   ```bash
   sd pr_open "$sprint_branch" "$(sd manifest_get '.canonical.default_branch' || echo main)" \
     "Sprint ${N}: <summary>" "<body-file>"
   ```
5. **Run the agent-driven pre-merge gate** per `references/git-workflow.md`
   (`sd pr_state` + `sd pr_review_comments` → reason over CI **and** inline review
   comments → per-finding disposition + reviewer-completeness → surface → ask). This
   is the protected boundary — be especially explicit about unresolved review findings
   and any absent/skipped reviewer. A **P1/blocking finding must be fixed first (never
   ack-to-merge)**; `sd pr_merge` only on explicit user acknowledgement of the remaining
   non-blocking findings / absent reviewers.

`direct` mode skips this section — there is no sprint branch and no PR.

---

## 9. Final assistant message

In `pr_hierarchical` mode, complete §8a (open the sprint→main PR + run the gate)
**before** emitting this message, and include the opened PR (number/URL) + the
gate outcome in it.

After the write, emit a paragraph naming:

1. **The absolute path of the written file.** Code-formatted block. Eval S1 explicitly checks for the absolute path.
2. **The aggregation summary.** E.g., *"Aggregated 3 slice retros (`VS-3.1`, `VS-3.2`, `VS-3.3`) into the sprint-3 retrospective; 6 sections populated, 5 memory-bank items totaled across 3 files."*.
3. **Next step.** Typically the sprint-close handoff: *"If sprint-${N+1} is up next, compose the carry-forward handoff via `handing-off-session` (`/handoff --scope sprint --purpose to-${N+1}-handoff`)."*.

Do NOT close with self-congratulatory boilerplate.

---

## 10. Anti-patterns (do not do these)

- **Aggregating with un-closed slices.** Eval S2 explicitly rejects partial aggregation. The skill bails with a refusal naming the un-closed slice and `/close-slice` / `closing-vertical-slice`.
- **Vague "a slice is still open" refusal.** Eval S2 requires the un-closed slice ID (`VS-${N}.M`) explicitly. Omitting it is a FAIL.
- **Mutating any slice's `retrospective.md`.** Eval S1 explicitly checks no Edit/Write against slice retros appears. The skill is READ-ONLY against slice retros.
- **Skipping any slice retro on Read.** Eval S1 counts exactly 3 distinct slice-retro Reads for the 3-slice fixture. Missing any is a FAIL.
- **Skipping the ROADMAP read.** Eval S1 verifies a Read of `<ai-workspace>/ROADMAP.md` appears BEFORE the Write of `sprint-retrospective.md`.
- **Writing under a slice subdirectory.** The sprint retro lives at `${sprint_dir}/sprint-retrospective.md` directly. Writing it at `${sprint_dir}/VS-${N}.M/sprint-retrospective.md` (or similar) is a FAIL.
- **Writing under `<canonical>/`.** The sprint retro is an AI-workspace artifact; routing it to canonical is a FAIL.
- **Qualitative memory-bank counts.** Eval S1 rejects "several items added" / "many slices touched memory bank" — counts must be numeric.
- **Dropping a slice from the per-slice rollup.** Eval S1 verifies all 3 slice IDs appear in section 3 of the written file.
- **Reading manifest fields via raw `jq`.** All manifest reads route through `sd_manifest_get` / `sd_manifest_resolve`.
- **Re-promoting sprint-aggregate items into memory bank with `source: sprint-retro` trailers.** Sprint close writes **nothing** to the memory bank — the per-slice harvest is the single promotion event (see `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**). The sprint retro AGGREGATES counts; it does NOT re-promote items.
- **Letting this body exceed 350 lines.** Hard cap per PLAN T1.9 line budget.

---

## 11. Notes on tool boundaries

- **You** make every judgment call: how to phrase the cross-slice pattern draft, how to aggregate lessons across slices when they overlap, how to phrase the un-closed-slice refusal so the user immediately knows which slice to close.
- **Bash helpers** (`lib/manifest.sh`, `lib/render.sh`) handle manifest reads and template substitution.
- **`templates/sprint-retrospective.md.tmpl`** owns the 6-section structure; you populate the variables.
- **`closing-vertical-slice`** is the upstream contract — every slice retro this skill consumes was authored by that skill at slice close. If a slice retro is missing, the upstream contract was not fulfilled, and this skill's refusal routes the user back there.
- **`handing-off-session`** is the downstream sibling — the carry-forward handoff is a separate authoring step, not this skill's lane.
- **The user** confirms cross-slice patterns and edits sprint-level lessons. You never auto-confirm patterns or auto-trim lessons.

When in doubt, prefer prompting over inferring. Cross-slice patterns are user-confirmed every time; the closure precondition is the gate that makes aggregation meaningful.
