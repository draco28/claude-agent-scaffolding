---
name: closing-vertical-slice
description: Run the three-layer slice-close ceremony — auto-demo (halt-on-first-fail), manual-demo, architect-critic review at close depth, `retrospective.md` authoring, memory-bank harvest sweeping `report.md` + handoffs with `[report]`/`[handoff]` source tags, then worktree + branch cleanup (only after harvest). Also owns sprint-close handoff cleanup on the final slice. Use this when the user says `close VS-N.M.K`, `slice close`, `wrap up the slice`, or `run slice-close ceremony`.
---

# closing-vertical-slice

You are the slice-close ceremony for scaffold-dev v0.1's vertical-slice lifecycle. After `planning-vertical-slice` has shepherded all rounds to completion (all work items committed + merged, worktrees + branches still present per §11 M2), this skill runs the three-layer close: auto-demo → manual-demo → architect-critic adversarial review at close depth → retrospective authoring → memory-bank harvest (with handoff sweep) → worktree + branch cleanup.

The ceremony order is binding. The §11 M2 marker — worktrees + branches removed ONLY after harvest completes — is the load-bearing discipline this body enforces. Halt-on-first-auto-demo-failure preserves worktrees for inspection (eval S2). Warn-and-proceed on architect-critic absence keeps the ceremony moving without blocking (eval S3). Source-tagged harvest with literal `[report]` / `[handoff]` brackets and the provenance trailer carries SPEC §15.2's 8-step contract through eval S4.

Bash helpers in `lib/manifest.sh`, `lib/render.sh`, `lib/worktree.sh`, and `lib/compose.sh` do the bookkeeping (manifest resolution, demo-line parsing, template substitution, filesystem probes, worktree teardown). The judgment work — which §12.2 menu row matches the failing auto-demo, how to phrase the source-tagged harvest candidates, when to count the rejected handoff item as "left in handoff" — happens here, in conversation.

This skill is the slice-close terminal step. It does NOT plan slices (that's `planning-vertical-slice` per §5), does NOT verify per-work-item ACs (that's `implementation-checking` per §12.1), and does NOT author the work-item bodies (that's the `scaffold-dev:implementer-agent` subagent body via `executing-work-item` per §6). It is invoked at the end of the slice when all rounds complete, either by trigger phrase or by the `/close-slice VS-N.M.K` slash command.

---

## 1. Overview

When invoked, you:

1. Discover the workspace-init pairing manifest; refuse fail-fast if absent (mirrors `planning-vertical-slice` §3.1).
2. Resolve the target VS-id from the user message (or active-context cursor) and locate the slice directory under `<ai-workspace>/docs/specs/sprint-<sprint_id>/VS-<id>-<kebab>/` (e.g. `sprint-1.1/VS-1.1.1-<kebab>/`), with `sprint_id` field-read from the structured roadmap.
3. Read the VS README; parse `auto:` and `user:` demo criteria per SPEC §14.1 grammar via `lib/render.sh::sd_demo_parse_block`.
4. **Layer 1 — auto-demo:** run each `auto:` command in canonical (NOT in any work-item worktree), evaluate the expectation, halt on first failure. Record outcomes in the VS README's "Demo verification" section.
5. **Layer 2 — manual-demo:** surface each `user:` step to the user with the expected outcome; capture pass/fail/partial + notes. Record outcomes in "Demo verification".
6. **Layer 3 — architect-critic at close depth:** probe via `lib/compose.sh::sd_compose_detect_architect_critic`; if v0.2 present, invoke `Skill(architect-critic:critiquing-spec)` in-conversation at `depth=close` with the slice diff + VS README + work-item specs as context; if absent, emit one warning naming `architect-critic` or `adversarial review` and proceed.
7. **Retrospective:** render `templates/slice-retrospective.md.tmpl` (7 sections per SPEC §16b) into `${slice_root}/retrospective.md`.
8. **Memory-bank harvest (§15.2 8-step flow):** read all work-item `report.md` files + all slice-scoped handoffs at `<ai-workspace>/.workspace/handoffs/vs-N.M.K-*.md`; extract "Suggestions for memory bank" + handoff section-4 promote candidates; categorize by target memory-bank file; surface each candidate prefixed `[report]` or `[handoff]`; consume per-item accept/edit/reject decisions; apply approved items with the provenance trailer `<!-- Added from VS-N.M.K retrospective, YYYY-MM-DD; source: report | handoff -->`; record harvest outcomes in `retrospective.md`.
9. **Cleanup (M2):** remove each work-item worktree via `sd_worktree_remove` + delete each work-item branch — ONLY after harvest completes successfully.
10. **Sprint-close cleanup:** if this is the FINAL slice of the sprint, sweep non-carry-forward handoffs from `<ai-workspace>/.workspace/handoffs/` per §6b.6.
11. Emit final `VS-N.M.K closed` handoff message.

Phase 1 RED→GREEN: this body's behavior is contracted by `scaffold-dev/evals/closing-vertical-slice.md` — the four scenarios there are the binding spec.

---

## 2. When to use

**Trigger phrases (description-match):**

- `close VS-N.M.K` (e.g., `close VS-1.1.1`)
- `slice close`
- `wrap up the slice`
- `run slice-close ceremony`
- `/close-slice VS-N.M.K` (slash command — see §11 for the `$ARGUMENTS` env-var bridge)

All four phrase forms are load-bearing in the description block above — the four eval scenarios trigger via description-match on each, so do not paraphrase any of them in your acknowledgement.

**Do NOT auto-invoke when:**

- Any work item in the slice has NOT yet returned `mode: complete` from its implementer-agent — route back to `planning-vertical-slice` §8 to finish the round.
- Any work item has been verified but NOT committed + merged — `implementation-checking` returned green but the orchestrator's commit + merge step (§8.6) has not run; route back.
- The slice directory does not exist or contains no work-item subdirs — surface the missing-slice error (§3.4) and stop.
- The user wants to *plan* a new slice (that's `planning-vertical-slice`) or *execute* a work item (that's the implementer-agent subagent).

If the user types something ambiguous like "we're done with VS-1.1.1", confirm: *"Run the slice-close ceremony for VS-1.1.1 (auto-demo → manual-demo → architect-critic → retrospective + harvest → worktree cleanup)?"*. The ceremony is destructive at the cleanup step — never auto-advance past the user's intent confirmation when the trigger phrase isn't explicit.

---

## 3. Pre-flight

Before any demo step, validate prerequisites in this order. Any failure surfaces the error string and stops.

### 3.1 Manifest discovery (refuses fail-fast)

Call `sd_manifest_require` (lib/manifest.sh). If absent, surface this verbatim refusal and stop:

> scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first.

The literal `/init-workspace` and `/pair-workspace` slash-command tokens are load-bearing (mirrors `planning-vertical-slice` §3.1 + `implementation-checking` §3.1). Do NOT read the VS README, do NOT run any `auto:` command, do NOT invoke architect-critic, do NOT touch any worktree.

All scaffold-dev lib calls go through the `sd` dispatcher (`scaffold-dev/bin/sd`, on `$PATH` because Claude Code adds each plugin's `bin/` automatically; the dispatcher's bash shebang forces a bash runtime under it regardless of the calling shell — required because Claude Code's Bash tool runs zsh by default on macOS):

```bash
if ! sd manifest_require 2>/dev/null; then
  printf '%s\n' "scaffold-dev requires a workspace-init pairing manifest; run /init-workspace or /pair-workspace first."
  exit 0
fi
```

Never read manifest fields via raw inline `jq`. All manifest reads route through `sd_manifest_get` / `sd_manifest_resolve`.

### 3.2 Resolve the VS-id

Resolution priority:

1. **Explicit id** in the user message (e.g., `close VS-1.1.1`, `/close-slice VS-1.1.1`) — match the full 3-part `VS-<phase>.<sprint>.<slice>` token and normalize to the `VS-`-prefixed form (`vs_id="VS-1.1.1"`).
2. **Active-context cursor** — read `<ai-workspace>/.claude/memory-bank/05-active-context.md` for the in-flight slice; use that when the message is ambiguous (e.g., `slice close`, `wrap up the slice`).
3. If neither produces an id, ask: *"Which slice? (e.g., `VS-1.1.1`)"* and wait.

### 3.3 Read manifest fields + field-read the slice

```bash
ai_workspace="$(sd manifest_get '.ai_workspace.root')"
canonical="$(sd manifest_get '.canonical.root')"
worktrees_dir="$(sd manifest_get '.during_dev.worktrees_dir')"
handoffs_dir="$(sd manifest_get '.routing.handoffs_dir')"   # resolves to <ai-workspace>/.workspace/handoffs/ in v0.1
sprint_dir_template="$(sd manifest_get '.during_dev.sprint_dir_template')"
```

Field-read the slice's `sprint_id` from the published structured roadmap — the same contract `planning-vertical-slice` uses. Never split it out of the slice id:

```bash
roadmap_state="$(sd roadmap_state_path)"
sprint_id="$(sd roadmap_slice_sprint_id "$vs_id")"   # e.g. "1.1" for VS-1.1.1
```

### 3.4 Locate the slice directory

The sprint segment is the field-read `sprint_id`; the kebab suffix was chosen at planning time and isn't field-read here, so locate the existing dir by glob (`vs_id` is the full 3-part id, e.g. `VS-1.1.1`):

```bash
slice_root="$(ls -d "${ai_workspace}/docs/specs/sprint-${sprint_id}/${vs_id}-"*/ 2>/dev/null | head -1)"
slice_root="${slice_root%/}"
# → …/docs/specs/sprint-1.1/VS-1.1.1-<kebab>
```

If `slice_root` is empty or contains no `work-*/` subdirectories, surface:

> Slice `<vs_id>` not found at `<resolved-path>`. Has `planning-vertical-slice` authored this slice yet?

Then stop. Do NOT auto-create the directory; spec authoring is the orchestrator's lane.

### 3.5 Confirm round-complete state

Read each work item's `report.md`. If any report has `Status: gaps-surfaced`, `Status: in-progress`, or is empty, surface:

> Work item `<work_id>` not at complete status (`<status_observed>`). Route back to `planning-vertical-slice` to finish the round before closing the slice.

Then stop. The ceremony depends on all work items having committed + merged outputs.

---

## 4. Demo-criteria parse (per §14.1 grammar)

Read `${slice_root}/README.md`. Locate the demo-criteria block (rendered into the README at `planning-vertical-slice` §6 from the ROADMAP's `auto:`/`user:` lines). Parse via `lib/render.sh::sd_demo_parse_block`:

```bash
demo_lines="$(sd demo_parse_block "${slice_root}/README.md")"
```

Each parsed line yields a `(prefix, command-or-action, expectation)` tuple where `prefix` is one of `auto` or `user`, separated by the literal U+2192 arrow character (`→`, NOT the ASCII `->` digraph — same grammar as scaffold-onboard's R3 per SPEC §14.1).

Build two ordered lists: `auto_steps` (the `auto:` tuples in declared order) and `user_steps` (the `user:` tuples in declared order). If both lists are empty, surface:

> VS README at `<resolved-path>` declares no demo criteria. Author at least one `auto:` or `user:` line (per §14.1 grammar) before closing the slice.

Then stop.

---

## 5. Layer 1 — auto-demo execution (halt on first fail)

Iterate `auto_steps` in declared order. For each `(command, expectation)`:

```bash
cd "$canonical"   # auto-demo runs in CANONICAL post-merge state, NOT in any worktree
result_stdout="$(eval "$command" 2>&1)"; result_exit=$?
```

The `cd "$canonical"` is binding — eval S1's judge confirms either the absence of any `cd <worktree>` prefix OR the explicit presence of a canonical-root marker. Auto-demo against a work-item worktree produces false-greens (the worktree's branch may be at a pre-merge HEAD).

Evaluate `expectation` per §14.1:
- `exit 0` → pass iff `result_exit == 0`.
- `output contains "<pat>"` → pass iff `result_stdout` substring-matches the literal pattern.
- `count > 0` / numeric comparisons → arithmetic against the trimmed `result_stdout`.

Record each outcome in the VS README's `## Demo verification` section (append if absent), one line per step:

```
- [x] auto: <cmd> → expected: <exp> → observed: pass (exit 0)
- [x] auto: <cmd> → expected: <exp> → observed: fail (exit 1) — <stderr-excerpt>
```

**Halt-on-first-fail is binding.** On any fail:
- Do NOT run the remaining `auto:` lines.
- Do NOT surface `user_steps`.
- Do NOT invoke architect-critic.
- Do NOT author `retrospective.md`.
- Do NOT run harvest.
- Do NOT remove any worktree or delete any branch.
- Mutate ONLY the "Demo verification" line for the failing step (the rest of the README is untouched).

Surface a failure report naming: (a) the verbatim `auto:` line from the VS README so the user can identify the failing step, (b) the command that was run, (c) the observed exit code, (d) a captured stderr/stdout excerpt (~200 chars). Then present the recovery menu (§12.2 row adapted for slice-close auto-demo fails):

> **Recovery menu (§12.2 — slice-close auto-demo fail):**
> 1. **Re-author the demo step** — the criterion is wrong; return to scaffold-onboard's `Skill(scaffold-onboard:authoring-vertical-slice-demo)` (or `/plan-roadmap --refine-slice VS-<N.M>`) to revise.
> 2. **Accept-with-deferred** — slice closes with the failing step marked deferred; the slice must still be demoable despite the caveat (per §14.4 close-with-deferred). Add a follow-up work item to the backlog.
> 3. **Re-spawn implementer subagent for fix-up** — the implementation is wrong; re-invoke the offending work item's implementer-agent against the failing area, then re-run the slice-close ceremony.

Then stop and wait. Do NOT auto-select an option (option 3 in particular requires a `Task` dispatch which is a user-gated action, not ceremony-driven). The judge in eval S2 explicitly checks for ≥3 distinct menu options matching this shape and rejects collapse to fewer; eval S2 also asserts no `Task` invocation on the halt turn.

On all-pass: proceed to §6.

---

## 6. Layer 2 — manual-demo execution

Iterate `user_steps` in declared order. For each `(action, expectation)`:

1. Surface the step verbatim to the user with the expected outcome quoted:

   > **Manual demo step <K>:** `<action>` → expected: `<expectation>`. Run this and report back: pass / fail / partial + a note.

2. Wait for the user's response. Capture pass/fail/partial + the user's verbatim note.
3. Record in the VS README's "Demo verification" section:

   ```
   - [x] user: <action> → expected: <exp> → observed: pass — <user note>
   ```

Eval S1's judge confirms the manual-demo step appears in the assistant transcript with the expected outcome quoted AND that the target waits for / captures the user response before proceeding to Layer 3. Auto-advancing past a `user:` step (or paraphrasing the expected outcome away) fails the assertion.

**Partial / fail outcomes:** if the user reports `fail` or `partial`, treat it the same way as Layer 1's fail — halt, do NOT invoke architect-critic, do NOT author retrospective, do NOT run harvest, do NOT touch worktrees. Surface the same 3-option recovery menu (§5), adapted for manual-demo:

> 1. Re-author the demo step · 2. Accept-with-deferred (slice closes with caveat) · 3. Re-spawn implementer for fix-up against the manual flow.

On all-pass across all `user_steps`: proceed to §7.

---

## 7. Layer 3 — architect-critic adversarial review (in-conversation, §16.3 moment 2)

After both demo layers pass, invoke architect-critic at close depth.

### 7.1 Detection (filesystem probe)

Call `sd_compose_detect_architect_critic` (lib/compose.sh). It walks `~/.claude/plugins/cache/*/architect-critic/*/skills/critiquing-spec/SKILL.md` and prints either `v0.2` or `absent`. This is NOT a composition.json read — scaffold-dev does not maintain a composition.json cache (per SPEC §16.3). The probe MUST be observable in the tool-call log (eval S3 asserts a Bash invocation listing or globbing the cache path appears, even when the probe returns absent).

### 7.2 Invocation (when present, S1 contract)

When the probe returns `v0.2`:

1. Announce: *"Demos passed — invoking architect-critic for the slice-close adversarial review at close depth. Type `skip` to bypass."*
2. End the turn and wait. If the user types `skip` (case-insensitive): log the skip in `retrospective.md`'s critic section and proceed to §8.
3. Otherwise, invoke `Skill(architect-critic:critiquing-spec)` with:
   - `target=slice`
   - `depth=close` (per ac v0.2 §5.1 — close-depth is the heavier audit, includes optional Codex fresh-frame invocation; distinct from the lighter `author` depth used at `planning-vertical-slice` §7.2 moment 1)
   - **Context:** the slice's combined diff (from the VS-start commit to canonical HEAD) + the VS README (with demo-verification section populated) + all work-item `spec.md` paths.
   - Context note: this is the scaffold-dev SPEC §16.3 moment 2 (slice-close adversarial), distinct from the moment 1 spec-author audit at slice-plan time.
4. architect-critic runs its own sequential rebuttal cycle with T=4 concession scoring; the user resolves challenges in conversation; eventually control returns.
5. When control returns: capture the critic's findings + the user's rebuttal outcomes into a section of `retrospective.md` (§8).

**Eval contract (S1):** the `Skill(architect-critic:critiquing-spec)` invocation MUST appear in the tool-call log exactly once AND MUST appear AFTER both `auto:` Bash invocations AND after the manual-demo user response is captured. The judge verifies the relative position. No `Write` to `inbox/` or `outbox/` paths — legacy file IPC was removed in architect-critic v0.2 (SPEC §16.3) and any such write fails the assertion.

### 7.3 Absent / warn-and-proceed (S3 contract)

If `sd_compose_detect_architect_critic` returns `absent`, emit ONE warning and proceed (do NOT block, do NOT prompt the user to install, do NOT retry the probe):

> architect-critic not detected — adversarial review skipped. Install architect-critic v0.2+ via `/plugin install architect-critic` for slice-close audit at this moment.

The warning MUST reference either `architect-critic` (plugin name) OR `adversarial review` (capability name) so the user can identify what was skipped. Eval S3 explicitly rejects silent skip AND rejects a blocking error. Proceed to §8.

---

## 8. Retrospective authoring (per §16b 7-section format)

Render `templates/slice-retrospective.md.tmpl` into `${slice_root}/retrospective.md` via `sd_render`. The 7 sections (per SPEC §16b):

1. **Slice metadata** — VS-id, name, sprint, start date, close date, work-item count, round count.
2. **Demo verification results** — the populated "Demo verification" block from the VS README (auto-demo outcomes + manual-demo outcomes with user notes).
3. **Architect-critic findings** — both moments: moment-1 spec-author audit (cached from `planning-vertical-slice` §7) + moment-2 slice-close adversarial (captured in §7.2 above), each with their challenges and the user's resolutions. If a moment was skipped (architect-critic absent), note "skipped — architect-critic not detected" in that subsection.
4. **Memory bank harvest** — placeholder; §9 fills it after harvest completes.
5. **Deviations + deferrals** — anything that landed as accept-with-deferred during demo layers, plus any cross-cutting deviations from the original spec discovered during the rounds.
6. **Lessons learned** — free-form observations the orchestrator + user captured.
7. **Reference index** — paths to the VS README, all work-item `spec.md` + `report.md` + `handoff.md`, all `vs-N.M.K-*.md` handoffs swept in §9, the retrospective itself.

Write the file BEFORE harvest runs (so the harvest step can append to section 4 in-place). Eval S1 asserts the `Write` of `retrospective.md` appears AFTER the architect-critic invocation in tool-call order, and BEFORE the harvest Reads of report/handoff files — preserve that ordering.

---

## 9. Memory-bank harvest (§15.2 8-step flow)

The harvest is the heart of the slice's memory-bank promotion contract. Eight steps, executed in this order.

### 9.1 Step 1 — Read all work-item `report.md`

Iterate `${slice_root}/work-*/report.md`. Read each one. Eval S1 + S4 assert that ALL work-item reports appear in the Read tool-call log (4 reports in the standard 4-item slice).

### 9.2 Step 2 — Read all slice-scoped handoffs

Derive the slice slug from the full id and glob `${handoffs_dir}/${vs_slug}-*.md` (`vs_slug="vs-${vs_id#VS-}"`, e.g. `vs-1.1.1`). Read each match. The glob is **slice-scoped**: it matches `vs-1.1.1-bugfix-auth-a1b2.md` and `vs-1.1.1-techdebt-logging-e5f6.md` but does NOT match `sprint-1-context-bloat-c3d4.md` (sprint-scoped, different naming pattern). Eval S1 + S4 explicitly assert the unrelated sprint-scoped handoff MUST NOT appear in any Read — accidentally sweeping it fails the assertion.

```bash
vs_slug="vs-${vs_id#VS-}"
for handoff in "${handoffs_dir}/${vs_slug}"-*.md; do
  [[ -f "$handoff" ]] || continue
  # Read the handoff file (Read tool, not bash cat)
done
```

### 9.3 Step 3 — Extract promote candidates

From each `report.md`: extract the **"Suggestions for memory bank"** section (per SPEC §10 report template). May be empty for some reports — that's fine.

From each `vs-N.M.K-*.md` handoff: extract **section 4 — "What's NOT in memory bank yet"** (per SPEC §6b.5 handoff doc structure). May be empty for some handoffs — that's fine.

### 9.4 Step 4 — Categorize by target memory-bank file

For each candidate, decide which memory-bank file it belongs in (per scaffold-onboard's 11-file taxonomy): typically `03-code-patterns.md` (patterns + R2 rules), `04-tech-context.md` (stack-specific notes), `09-known-issues.md` (caveats + workarounds), `10-decisions-log.md` (ADR-worthy notes), or `06-product-context.md` (product-shape notes). Surface the proposed target alongside the candidate at step 5.

### 9.5 Step 5 — Surface candidates with source-tag prefix

Present each candidate to the user as a numbered list. Each item's first line MUST start with the literal source-tag token in square brackets — either `[report]` or `[handoff]`. The brackets are load-bearing per eval S1 + S4: paraphrased spellings (`(report)`, `<handoff>`, `*report*`, `[Report]`) fail the assertion.

Example surface:

```
Harvest candidates for VS-1.1.1 (4 items):

1. [report] from work-1.01/report.md → target: 03-code-patterns.md
   "subagent must use absolute paths when reading worktree files (relative paths break under Task dispatch)"

2. [report] from work-1.03/report.md → target: 09-known-issues.md
   "merge conflict surface on shared schema.json when two parallel work items both touch it"

3. [handoff] from vs-1.1.1-bugfix-auth-a1b2.md section 4 → target: 03-code-patterns.md
   "auth retry pattern: exponential backoff with 3 attempts, jitter 100-500ms"

4. [handoff] from vs-1.1.1-techdebt-logging-e5f6.md section 4 → target: 09-known-issues.md
   "log-rotation cron caveat — rotation fires at 03:00 UTC and races with the scheduled backup"

Per item: accept (apply as-is) / edit (give me the revised text) / reject (drop).
```

### 9.6 Step 6 — Consume per-item decisions

For each candidate, accept the user's decision: `accept`, `edit: <new text>`, or `reject`. The user may answer per-item or as a batch (`accept all`, `accept 1,2; edit 3; reject 4`).

### 9.7 Step 7 — Apply with provenance trailer

For each `accept` or `edit` decision, append the item to its target memory-bank file at `${ai_workspace}/.claude/memory-bank/<file>.md`. Each applied item carries the literal provenance trailer:

```
<!-- Added from VS-N.M.K retrospective, YYYY-MM-DD; source: report -->
```

or

```
<!-- Added from VS-N.M.K retrospective, YYYY-MM-DD; source: handoff -->
```

The `source:` field MUST exactly match the candidate's origin (`report` for report-sourced, `handoff` for handoff-sourced). Eval S4 explicitly rejects: missing trailer, missing `source:` field, mis-labeled source (e.g., `source: report` on a handoff-origin item). Eval S1 accepts minor date-format variation but rejects missing `VS-N.M.K` reference.

For `reject` decisions: do NOT write to any memory-bank file. The candidate is dropped. Eval S4 asserts filesystem diff confirms only the count of accepted items appears as memory-bank file modifications.

### 9.8 Step 8 — Record harvest outcomes in retrospective.md

Append to section 4 of `${slice_root}/retrospective.md`:

- For each accepted item: source-tag + target file + status `applied` (or `applied-with-edit` if the user edited).
- For each rejected handoff item: source-tag + status `left in handoff` (the item stays in the handoff doc — handoffs are NOT swept-and-deleted at slice close; they persist as historical artifacts per §6b.4 chain model).
- For each rejected report item: status `dropped`.

Eval S4 explicitly checks that the retrospective's harvest section names at least the promoted items with their source AND notes any item "left in handoff" per §15.2 step 8 — distinguishing report-origin from handoff-origin items in the prose is part of the contract.

---

## 10. Cleanup (M2 marker enforcement)

ONLY AFTER §9 step 8 completes successfully, remove worktrees + delete branches.

### 10.1 Worktree removal

For each work item in the slice:

```bash
sd worktree_remove "${work_id}" "${kebab}"
# Runs: git worktree remove "${canonical}/${worktrees_dir}/work-${work_id}-${kebab}"
# Then: git branch -D "${branch_name}"
```

`sd_worktree_remove` halts on failure (worktree has uncommitted changes, branch is checked out elsewhere). If a removal fails, surface the failure verbatim and stop — leave the remaining worktrees intact for inspection. The user may resolve and re-invoke this skill's cleanup phase, or accept partial cleanup.

**Eval M2 enforcement (S1 + S4):** any `git worktree remove` Bash invocation MUST appear in the tool-call log AFTER the `Write` of `retrospective.md` AND after all harvest-step Reads of report.md + handoff files. If any `git worktree remove` or `git branch -D work-N.NN-*` invocation precedes the retrospective Write OR precedes any harvest Read, the scenario FAILS. Eval S2 enforces the inverse: on auto-demo halt, NO `git worktree remove` invocation may appear at all — worktrees stay preserved for user inspection.

### 10.2 Branch deletion

Branch deletion is bundled into `sd_worktree_remove` per `lib/worktree.sh`'s contract. After §10.1 completes, all `work-N.NN-*` branches are gone. Final filesystem state shows `${canonical}/${worktrees_dir}/work-*` directories absent and `git branch` listing in canonical does not contain any `work-*` branch.

---

## 11. Sprint-close branch (final slice of the sprint)

If this slice is the FINAL slice of its sprint (resolved by field-reading the structured roadmap for any later slice with the same `sprint_id`), run the sprint-close cleanup per §6b.6.

### 11.1 Detect final-slice condition

```bash
roadmap_state="$(sd roadmap_state_path)"
# Field-read: is there a LATER slice in this same sprint? Compare the slice index
# (3rd id field) numerically — never grep ROADMAP headings or split on the wrong
# field (the #28 bug). cur_idx is this slice's index, e.g. "1" from VS-1.1.1.
cur_idx="${vs_id##*.}"
next_vs_in_sprint="$(jq -r --arg sid "$sprint_id" --argjson cur "$cur_idx" '
  [ .vertical_slices[]
    | select(.sprint_id == $sid)
    | (.id | sub("^VS-"; "") | split(".") | .[2] | tonumber) as $idx
    | select($idx > $cur) ] | length' "$roadmap_state")"
# next_vs_in_sprint == "0" ⇒ this is the final slice of the sprint.
if [[ -z "$next_vs_in_sprint" || "$next_vs_in_sprint" == "0" ]]; then
  is_final_slice_of_sprint=1
else
  is_final_slice_of_sprint=0
fi
```

### 11.2 Sweep non-carry-forward handoffs

When `is_final_slice_of_sprint=1`:

- Read every handoff in `${handoffs_dir}/`.
- For each handoff, check its frontmatter or section-1 metadata for a `carry_forward: true` marker (per §6b.5).
- Delete handoffs WITHOUT the carry-forward marker. Carry-forward handoffs (e.g., `sprint-${sprint_id}-to-${next_sprint_id}-handoff-XXXX.md`, where `next_sprint_id` is the next sprint in the roadmap — there is no integer `+1` for a dotted `sprint_id` like `1.1`) survive into the next sprint.
- Surface to user: *"Sprint ${sprint_id} closed. Swept N non-carry-forward handoffs; K carry-forward handoffs preserved for sprint ${next_sprint_id}."*.

**Ownership lock for v0.1:** sprint-close cleanup lives in this skill, not a separate `closing-sprint` skill (per SPEC §6b.6 settlement during PLAN). A future v0.2 may split this out, but v0.1's surface is a single slice-close skill with sprint-close as a conditional final step.

### 11.3 Sprint retrospective (out of scope for this skill)

Sprint-level retrospective authoring (`sprint-${sprint_id}/sprint-retrospective.md`, 6 sections per §16b) is handled by `writing-sprint-retrospective` (Phase 1 task T1.7, separate skill). This skill does NOT author the sprint retrospective — only the slice retrospective + the conditional handoff sweep.

---

## 12. Slash-command interaction (`/close-slice VS-N.M.K`)

The `/close-slice VS-N.M.K` slash command (`commands/close-slice.md`) exports the raw arg string as `$ARGUMENTS` (env-var bridge per `feedback_slash_command_dollar_n_bug` — Claude Code substitutes `$1`/`$2`/etc. at template-render time and silently corrupts bash positionals).

Parse `$ARGUMENTS` in bash; never reference `$1` / `$2`. Extract the VS-id (e.g., `VS-1.1.1` — the full 3-part id `VS-<phase>.<sprint>.<slice>`) and proceed to §3 pre-flight.

Unknown or missing VS-id → one-line error + stop:

> /close-slice requires a VS-id argument. Example: /close-slice VS-1.1.1

---

## 13. Final handoff

After §10 cleanup (and §11 sprint-close if applicable), emit the closing message:

> **VS-`<vs_id>` closed.** Demo verification: `<N>` `auto:` + `<M>` `user:` steps all passing. Architect-critic: `<finding-count or "skipped">`. Memory bank harvest: `<X>` items promoted (`<R>` from `[report]`, `<H>` from `[handoff]`), `<L>` left in handoff. Worktrees + branches removed. Retrospective at `${slice_root}/retrospective.md`.

Eval S1 / S3 / S4 assert the target subagent's final assistant message indicates the slice is closed — judge accepts `VS-1.1.1 closed`, `VS-1.1.1 close ceremony complete`, or equivalent. Silent termination fails the assertion.

---

## 14. Anti-patterns (do not do these)

- **Running auto-demo commands inside a worktree.** `cd "$canonical"` is binding — auto-demo runs in canonical (post-merge state). Eval S1's judge rejects any `cd <worktree>` prefix on the auto-demo Bash invocations. The work-item worktree's branch may be at a pre-merge HEAD; running there produces false-greens.
- **Continuing past the first auto-demo failure.** Eval S2's assertion is binding — exactly one Bash invocation in the tool-call log when the first `auto:` line fails. Halt immediately; preserve worktrees; surface the 3-option recovery menu.
- **Removing worktrees before harvest completes.** §11 M2 marker is the entire ceremony's discipline. Eval S1 + S4 scan the tool-call log: any `git worktree remove` or `git branch -D work-*` invocation that precedes the `retrospective.md` Write OR precedes any harvest Read fails the scenario.
- **Removing worktrees on an auto-demo halt.** Eval S2 explicitly asserts no `git worktree remove` invocation appears when ceremony halts in Layer 1. Worktrees + branches stay preserved for user inspection; the user picks the recovery menu option and the ceremony re-runs from §5 on the next pass.
- **Paraphrasing the source-tag tokens.** The literal `[report]` and `[handoff]` square brackets are load-bearing per eval S1 + S4. Spellings like `(report)`, `<handoff>`, `*report*`, `[Report]`, `[report-sourced]` all fail the assertion.
- **Mis-labeling the `source:` field in the provenance trailer.** Eval S4 cross-checks each accepted item against its origin: `source: report` for items extracted from `report.md`; `source: handoff` for items extracted from a `vs-N.M.K-*.md` handoff. Swapping the labels fails the assertion.
- **Sweeping sprint-scoped handoffs at slice close.** The glob is `${handoffs_dir}/${vs_slug}-*.md` (`vs_slug="vs-${vs_id#VS-}"`, e.g. `vs-1.1.1-*.md`) — slice-scoped only; do NOT write `vs-${vs_id}-*.md`, which with the `VS-`-prefixed `vs_id` would resolve to a never-matching `vs-VS-1.1.1-*.md`. Files like `sprint-3-context-bloat-c3d4.md` are sprint-scoped and MUST NOT appear in any Read during harvest. Eval S1 + S4 reject any accidental read of a sprint-scoped handoff.
- **Silent skip when architect-critic is absent.** Eval S3 rejects silent skip — emit the §7.3 warning naming `architect-critic` or `adversarial review`. Also rejects blocking error — never prompt the user to install architect-critic; never retry the probe.
- **Invoking architect-critic via Task tool or via `inbox/` / `outbox/` file IPC.** Eval S1 rejects both. The only correct invocation is the in-conversation `Skill(architect-critic:critiquing-spec)` pattern per SPEC §16.3.
- **Authoring the retrospective BEFORE the architect-critic moment.** Eval S1 asserts the `Write` of `retrospective.md` appears AFTER the architect-critic invocation in tool-call order. The retrospective's section 3 captures the critic's findings; writing it earlier means section 3 is empty.
- **Authoring the retrospective AFTER harvest applies items.** The retrospective's section 4 is the harvest's destination for outcomes (step 8). The Write happens before harvest Reads (§9.1), then harvest results are appended in-place. Inverting that order means section 4 is mute on the actual harvest outcomes.
- **Auto-selecting a recovery menu option.** The menu is a user decision boundary; surfacing-and-waiting is the entire contract. Eval S2 asserts no `Task` tool invocation on the halt turn — option 3 (re-spawn implementer) is user-selected, not ceremony-driven.
- **Reading manifest fields via raw `jq`.** All manifest reads route through `sd_manifest_get` / `sd_manifest_resolve` — mirrors `planning-vertical-slice` §3.1 + `implementation-checking` §3.1 discipline.
- **Calling `Skill(architect-critic:critique)`** (the legacy v0.1.x slash-command-shaped name). The v0.2 skill is `critiquing-spec` per SPEC §16.3 last paragraph.
- **Letting this body exceed 500 lines.** Hard cap per superpowers:writing-skills Pass D guidance.

---

## 15. Notes on tool boundaries

- **You** (Claude reading this skill body) make every judgment call: how to phrase the failing-step recovery menu, how to categorize each harvest candidate by target memory-bank file, how to surface the source-tagged candidates with enough context for the user's per-item decision, how to phrase the closing handoff message.
- **Bash helpers** (`lib/manifest.sh`, `lib/render.sh`, `lib/compose.sh`, `lib/worktree.sh`) handle pure I/O: manifest reads, demo-line parsing, template substitution, filesystem probes, worktree teardown.
- **`architect-critic:critiquing-spec`** owns the adversarial review at close depth; you invoke it once between Layer 2 and §8 retrospective authoring, and it runs its own sequential rebuttal cycle before returning control. This skill never enters that cycle; the user does, in conversation.
- **`writing-sprint-retrospective`** (separate skill, T1.7) owns the sprint-level retrospective. This skill does NOT author it — only the slice retrospective + the conditional handoff sweep at §11.
- **`scaffold-onboard:authoring-vertical-slice-demo`** owns demo-criteria authoring. When the user picks recovery option 1 ("re-author the demo step"), this skill hands off to that flow; it does NOT edit the VS README's demo criteria itself.
- **The user** is the final authority. They pass/fail each manual-demo step, resolve architect-critic challenges, accept/edit/reject each harvest candidate, pick the recovery menu option on any halt. You never auto-advance past a decision boundary; you never auto-cleanup; you never auto-select a menu option.

When in doubt, prefer surfacing-and-waiting over acting. The ceremony's value is the deterministic ordering: demos before critic, critic before retrospective, retrospective before harvest, harvest before cleanup. Every step is a user-observable artifact; every halt preserves the workspace for inspection. The §11 M2 marker — worktrees + branches survive until harvest completes — is the load-bearing discipline that makes the retrospective harvest meaningful.
