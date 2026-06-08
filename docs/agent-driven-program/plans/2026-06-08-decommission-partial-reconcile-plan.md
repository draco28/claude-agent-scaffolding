# Decommission Partial Reconcile (N7/#58) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the dormant partial-reconcile machinery from scaffold-onboard so the codebase reflects the live behavior (full re-walk + first-author re-synthesis); close #58 wontfix; release v0.7.0.

**Architecture:** Pure decommission — delete never-wired reconcile code paths, helpers, agent/brief instructions, prose, and their dead tests; simplify `sf_synth_master_spec_prompt` to a 3-arg first-author-only signature; one tiny UX touch to the §8 backup message. No new behavior. Success = the full suite (18 files) + repo-root dual-publish (148) stay green with the dead surface gone.

**Tech Stack:** Bash (`sf` dispatcher libs), Markdown skills/briefs/agents, bash test harness (`run-tests.sh`), jq.

**Design doc:** `docs/agent-driven-program/specs/2026-06-08-decommission-partial-reconcile.md`

**Working branch:** `chore/decommission-reconcile-58` (already created; design doc already committed).

**Verification commands (used throughout):**
- Single file: `cd scaffold-onboard && bash tests/<file>` (each test file is self-contained).
- Full suite: `cd scaffold-onboard && bash run-tests.sh` (18 files; slow ~60s+/file — run in background with a generous timeout).
- Dual-publish: `bash tests/test-codex-dual-publish.sh` (from repo root; 148 checks; version parity).

---

### Task 1: Remove `touched_this_run` + reconcile helpers from `lib/state.sh` and their dead tests

**Files:**
- Modify: `scaffold-onboard/lib/state.sh`
- Modify: `scaffold-onboard/tests/test-phase-records.sh`

- [ ] **Step 1: Delete the three dormant helpers from `lib/state.sh`**

Remove these whole functions (currently ~lines 182–226):
- `sf_state_mark_touched()` (and its preceding comment block starting "# Mark a single phase as touched…")
- `sf_state_run_reset()` (and its preceding comment "# Reset the per-run tracker…")
- `sf_state_phases_touched_this_run()` (and its preceding comment "# Print phase IDs (re)authored…")

- [ ] **Step 2: Drop `touched_this_run` from `sf_state_init`**

In `sf_state_init`, the `jq -n` object literal currently ends with:
```bash
      answers: {},
      phase_records: {},
      touched_this_run: []
    }' > "$path"
```
Change to:
```bash
      answers: {},
      phase_records: {}
    }' > "$path"
```

- [ ] **Step 3: Stop appending `touched_this_run` in `sf_state_write_phase_record`**

The jq filter currently reads:
```bash
    .schema_version = 2
    | .phase_records = (.phase_records // {})
    | .phase_records[$p] = ($rec[0] + {authored_at: $now})
    | .touched_this_run = (((.touched_this_run // []) + [$p]) | unique)
    | .updated_at = $now
```
Remove the `touched_this_run` line:
```bash
    .schema_version = 2
    | .phase_records = (.phase_records // {})
    | .phase_records[$p] = ($rec[0] + {authored_at: $now})
    | .updated_at = $now
```

- [ ] **Step 4: Delete the dead tests in `tests/test-phase-records.sh`**

Delete these test functions AND their invocation lines (currently ~lines 65–137):
- `test_touched_this_run_tracks_writes` (def + call)
- `test_run_reset_clears_touched` (def + call)
- `test_mark_touched_adds_phase_to_tracker` (def + call)
- `test_mark_touched_is_idempotent` (def + call)
- `test_mark_touched_coexists_with_write_phase_record` (def + call)

- [ ] **Step 5: Remove the `touched_this_run` assertion from the state-init test in `tests/test-phase-records.sh`**

Delete the line (currently ~line 16):
```bash
  assert_file_contains "$(sf_state_path)" '"touched_this_run": \[\]'
```

- [ ] **Step 6: Run the affected test files to verify green**

Run: `cd scaffold-onboard && bash tests/test-phase-records.sh && bash tests/test-state.sh`
Expected: both report `Results: N passed, 0 failed` (no `sf_state_mark_touched: command not found` / no failed assertions).

- [ ] **Step 7: Confirm no remaining references to the removed symbols in code**

Run: `cd scaffold-onboard && grep -rnE 'mark_touched|touched_this_run|run_reset|phases_touched' lib/ tests/`
Expected: no matches (prose in skills/refs handled in Task 4).

- [ ] **Step 8: Commit**

```bash
git add scaffold-onboard/lib/state.sh scaffold-onboard/tests/test-phase-records.sh
git commit -m "refactor(scaffold-onboard): remove dormant touched_this_run + reconcile state helpers (#58)"
```

---

### Task 2: Simplify `sf_synth_master_spec_prompt` to first-author-only, update §8 caller + tests

**Files:**
- Modify: `scaffold-onboard/lib/synthesis.sh`
- Modify: `scaffold-onboard/skills/onboarding-project/SKILL.md` (§8 caller block)
- Modify: `scaffold-onboard/tests/test-master-spec-synthesis.sh`

- [ ] **Step 1: Simplify the function signature + body in `lib/synthesis.sh`**

Current header + guards + mode block (≈lines 206–256). Replace the signature line:
```bash
# Args: <brief> <digest_file> <out_path> <mode> <touched> <existing_spec_path>
…
sf_synth_master_spec_prompt() {
  local brief="$1" digest_file="$2" out_path="$3" mode="$4" touched="$5" existing="$6"
```
with:
```bash
# Args: <brief> <digest_file> <out_path>
…
sf_synth_master_spec_prompt() {
  local brief="$1" digest_file="$2" out_path="$3"
```
(Update the multi-line arg comment block above the function: drop the `mode`/`touched`/`existing_spec_path` descriptions; keep the `digest_file` ARG_MAX note.)

- [ ] **Step 2: Remove the mode-validation guard in `lib/synthesis.sh`**

Delete:
```bash
  # Guard: mode must be one of the two defined values.
  if [[ "$mode" != "first_author" && "$mode" != "reconcile" ]]; then
    sf_log_error "sf_synth_master_spec_prompt: invalid mode '$mode' (expected first_author|reconcile)"
    return 1
  fi
```
(Keep the brief / digest-not-found / empty-digest guards above it — those are #59 hardening.)

- [ ] **Step 3: Replace the `mode_block` conditional with the inline first-author block**

Delete:
```bash
  local mode_block
  if [[ "$mode" == "reconcile" ]]; then
    mode_block="MODE: reconcile
An existing MASTER-SPEC is at: $existing — read it in full.
Refresh ONLY these phases, touched this run: ${touched:-(none)}
Reproduce every other section verbatim, preserving human edits."
  else
    mode_block="MODE: first-author
No existing MASTER-SPEC. Author the whole document fresh."
  fi
```
Replace with:
```bash
  local mode_block="MODE: first-author
No existing MASTER-SPEC. Author the whole document fresh."
```
(The `printf '%s\n' … "$mode_block" …` call below is unchanged.)

- [ ] **Step 4: Update the §8 caller in `SKILL.md`**

In the `**Produce MASTER-SPEC.md**` bash block, replace:
```bash
mode="first_author"; existing=""; touched=""
prompt="$(sf synth_master_spec_prompt "$brief" "$digest_file" "$master" "$mode" "$touched" "$existing")"
asm_rc=$?
rm -f "$digest_file"
```
with:
```bash
prompt="$(sf synth_master_spec_prompt "$brief" "$digest_file" "$master")"
asm_rc=$?
rm -f "$digest_file"
```

- [ ] **Step 5: Delete reconcile-specific tests in `tests/test-master-spec-synthesis.sh`**

Delete these test functions + their invocation lines:
- `test_prompt_reconcile_lists_touched_and_existing`
- `test_reconcile_preserves_untouched_human_edit`
- `test_prompt_rejects_bogus_mode`

- [ ] **Step 6: Update surviving first-author call sites to the 3-arg signature**

In every remaining `sf_synth_master_spec_prompt …` / `sf synth_master_spec_prompt …` call in this test file, drop trailing `first_author "" ""` (and any `reconcile`/touched/existing args). Affected tests include `test_prompt_first_author_contains_digest_and_mode`, `test_prompt_reads_digest_from_file`, `test_prompt_does_not_expand_user_content`, `test_prompt_rejects_empty_digest`, `test_prompt_rejects_missing_brief`. Each call becomes:
```bash
sf_synth_master_spec_prompt "$BRIEF" "$digest_file" "$out"
```
For the missing-brief guard: `sf_synth_master_spec_prompt "/nonexistent/brief" "$digest_file" "$out"`.

- [ ] **Step 7: Rename the backup test to drop the reconcile name**

Rename `test_close_block_reconcile_backs_up_existing` → `test_close_block_backs_up_existing_spec` (def + call). Its body is unchanged — it already asserts `first_author mode always` + that a `.bak-*` is created; only the name was reconcile-flavored. Update the inner assertion label string if it says "reconcile".

- [ ] **Step 8: Run the synthesis test file to verify green**

Run: `cd scaffold-onboard && bash tests/test-master-spec-synthesis.sh`
Expected: `Results: N passed, 0 failed`. The `test_close_master_spec_block_executes_clean` + `test_close_block_aborts_on_corrupt_digest` extract-block tests must still pass (they read the updated §8 block).

- [ ] **Step 9: Confirm no remaining reconcile/mode references in lib + this test**

Run: `cd scaffold-onboard && grep -nE 'reconcile|"\$mode"|first_author' lib/synthesis.sh tests/test-master-spec-synthesis.sh`
Expected: no `reconcile`; no `$mode`/`first_author` arg threading (the brief's MODE string literal is fine in lib).

- [ ] **Step 10: Commit**

```bash
git add scaffold-onboard/lib/synthesis.sh scaffold-onboard/skills/onboarding-project/SKILL.md scaffold-onboard/tests/test-master-spec-synthesis.sh
git commit -m "refactor(scaffold-onboard): sf_synth_master_spec_prompt first-author-only 3-arg signature (#58)"
```

---

### Task 3: Strip reconcile from the synthesis-agent + MASTER-SPEC brief

**Files:**
- Modify: `scaffold-onboard/agents/synthesis-agent.md`
- Modify: `scaffold-onboard/templates/synthesis-briefs/MASTER-SPEC.brief.md`

- [ ] **Step 1: Update the agent description (line 3)**

Change `Supports first-author/reconcile MASTER-SPEC synthesis from the onboarding digest, plus …` to `Supports first-author MASTER-SPEC synthesis from the onboarding digest, plus …`.

- [ ] **Step 2: Delete the reconcile binding rule (line 12)**

Remove the bullet:
```
- If the prompt is for `MASTER-SPEC.md` in reconcile mode, read the existing MASTER-SPEC path named in the prompt before writing; refresh only the touched phases and preserve untouched sections/human edits per the brief.
```
Keep the first-author bullet (line 11).

- [ ] **Step 3: Collapse the brief `### Mode` section to first-author only**

In `templates/synthesis-briefs/MASTER-SPEC.brief.md`, replace:
```markdown
### Mode

The prompt states the mode:

- **first-author** — no existing MASTER-SPEC. Author the whole document fresh.
- **reconcile** — an existing MASTER-SPEC is provided (read it in full). Refresh
  ONLY the phases listed as "touched this run"; reproduce every other section
  verbatim, preserving any human edits. Do not reorder or restyle untouched
  sections. The Executive Summary section is owned by the separate summary step —
  carry it through unchanged in reconcile mode.
```
with:
```markdown
### Mode

The prompt states the mode:

- **first-author** — no existing MASTER-SPEC. Author the whole document fresh.
  The Executive Summary section is owned by the separate summary step — emit the
  fillable section as instructed above.
```

- [ ] **Step 4: Verify frontmatter still parses + no reconcile left**

Run: `cd scaffold-onboard && grep -niE 'reconcile' agents/synthesis-agent.md templates/synthesis-briefs/MASTER-SPEC.brief.md`
Expected: no matches.
Run: `bash tests/test-master-spec-synthesis.sh`
Expected: green — incl. `test_brief_is_tool_agnostic` and `test_synthesis_agent_supports_master_spec_first_author` (verify the latter doesn't assert the now-removed reconcile line; if it does, update it to assert first-author only).

- [ ] **Step 5: Commit**

```bash
git add scaffold-onboard/agents/synthesis-agent.md scaffold-onboard/templates/synthesis-briefs/MASTER-SPEC.brief.md
git commit -m "refactor(scaffold-onboard): drop reconcile from synthesis-agent + MASTER-SPEC brief (#58)"
```

---

### Task 4: Scrub reconcile prose from SKILL.md + reference docs

**Files:**
- Modify: `scaffold-onboard/skills/onboarding-project/SKILL.md`
- Modify: `scaffold-onboard/skills/onboarding-project/references/resume-handling.md`
- Modify: `scaffold-onboard/skills/onboarding-project/references/example-walkthrough.md`

- [ ] **Step 1: Remove the "Reset the per-run tracker" bullet (SKILL §4, ~line 161)**

Delete:
```markdown
- **Reset the per-run tracker only when starting a new revision session.** Do NOT call `sf state_run_reset` on ordinary `resume`: `touched_this_run` carries no synthesis role in the descoped re-onboard flow, but is preserved for future use. Fresh `new` mode gets an empty tracker from `sf state_init`.
```

- [ ] **Step 2: Remove the deferred-reconcile note (SKILL §4, ~line 172)**

Delete:
```markdown
> **Note (deferred):** Partial-reconcile mode — revisiting only chosen phases and preserving untouched sections — is reserved for a follow-up. The `sf state_mark_touched` helper and the `reconcile` mode in `sf_synth_master_spec_prompt` are kept in the lib for that follow-up but are NOT driven from the current re-onboard flow.
```

- [ ] **Step 3: Drop `touched_this_run` from the schema example (SKILL §4, ~line 132)**

In the schema JSON block, remove the line `"touched_this_run": ["3"]` (and ensure the preceding `phase_records` block's JSON stays valid — remove the trailing comma after the `phase_records` closing brace if needed).

- [ ] **Step 4: Update the `--regenerate` flag note (SKILL §9, ~line 445)**

Change the trailing sentence `Partial-reconcile (choose only some phases) is deferred to a follow-up.` to `Partial-reconcile was evaluated and decided wontfix (#58); full re-walk is the model.`

- [ ] **Step 5: Remove the 3 helpers from the helper-list (SKILL §10, ~line 457)**

In the `**State (lib/state.sh …):**` inventory line, delete `sf_state_run_reset`, `sf_state_mark_touched`, `sf_state_phases_touched_this_run` (and their separating commas) so the list matches the surviving functions.

- [ ] **Step 6: Scrub `resume-handling.md`**

- Line ~17 (reonboard table row): change `Use `--fresh` for a full wipe-and-restart (requires double confirmation). Partial-reconcile (choosing only some phases) is deferred to a follow-up.` → `Use `--fresh` for a full wipe-and-restart (requires double confirmation). Partial-reconcile was decided wontfix (#58).`
- Line ~99 (worked-example JSON): remove the `"touched_this_run": ["1"]` line (fix trailing comma on the prior line for valid JSON).
- Leave line ~30 ("user must reconcile first") — that's the English verb "reconcile", not the feature. Confirm by reading it in context.

- [ ] **Step 7: Scrub `example-walkthrough.md`**

Line ~182: remove the `"touched_this_run": ["5"]` line from the JSON example (fix trailing comma for valid JSON).

- [ ] **Step 8: Verify the skill-presence + e2e tests still pass and prose is clean**

Run: `cd scaffold-onboard && bash tests/test-e2e.sh`
Expected: green (skill-presence assertions intact; no removed-symbol references).
Run: `cd scaffold-onboard && grep -rniE 'mark_touched|touched_this_run|run_reset|phases_touched' skills/`
Expected: no matches.
Run: `cd scaffold-onboard && grep -rniE 'reconcile' skills/ | grep -viE 'must reconcile first|wontfix'`
Expected: no matches (only the intentional "reconcile first" verb + the wontfix pointer remain).

- [ ] **Step 9: Commit**

```bash
git add scaffold-onboard/skills/onboarding-project/SKILL.md scaffold-onboard/skills/onboarding-project/references/resume-handling.md scaffold-onboard/skills/onboarding-project/references/example-walkthrough.md
git commit -m "docs(scaffold-onboard): scrub reconcile prose from onboarding skill + refs (#58)"
```

---

### Task 5: Tiny UX touch — backup message names manual edits (§8)

**Files:**
- Modify: `scaffold-onboard/skills/onboarding-project/SKILL.md` (§8 close summary)

- [ ] **Step 1: Extend the backup line in the close summary**

Find (SKILL §8, ~line 410):
```markdown
If a prior MASTER-SPEC was present (i.e. `master_bak` is set), append a second line after the MASTER-SPEC path line:
`Re-synthesized (full first-author); prior spec backed up to <master_bak>.`
```
Change the quoted line to:
```markdown
`Re-synthesized (full first-author); prior spec — including any manual edits — backed up to <master_bak>. Copy anything you want to keep before continuing.`
```

- [ ] **Step 2: Verify the §8 extract-block tests still pass**

Run: `cd scaffold-onboard && bash tests/test-master-spec-synthesis.sh`
Expected: green (this is prose after the bash block; extract-block tests unaffected).

- [ ] **Step 3: Commit**

```bash
git add scaffold-onboard/skills/onboarding-project/SKILL.md
git commit -m "docs(scaffold-onboard): close-summary backup message names manual edits (#58)"
```

---

### Task 6: Docs, ledger, changelog, version bump to 0.7.0

**Files:**
- Modify: `scaffold-onboard/.claude-plugin/plugin.json`
- Modify: `scaffold-onboard/.codex-plugin/plugin.json`
- Modify: `scaffold-onboard/CHANGELOG.md`
- Modify: `docs/agent-driven-program/specs/SS-3-agent-synthesized-resumable-onboarding.md`
- Modify: `docs/agent-driven-program/SPEC-agent-driven-program.md`

- [ ] **Step 1: Bump both plugin manifests to `0.7.0`**

In `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`, change `"version": "0.6.1"` → `"version": "0.7.0"`.

- [ ] **Step 2: Add the CHANGELOG entry**

Insert above `## [0.6.1] — 2026-06-08`:
```markdown
## [0.7.0] — 2026-06-08

Decommission partial reconcile-on-re-onboard (#58, wontfix). The full re-walk + first-author re-synthesis shipped in SS-3 is the permanent re-onboard model; the dormant reconcile machinery SS-3 retained "for #58" is removed. **No user-facing behavior changes** — the reconcile path was never wired into the live `/onboard` flow. scaffold-onboard only.

### Removed
- **Dormant partial-reconcile machinery.** `sf_state_mark_touched`, `sf_state_run_reset`, `sf_state_phases_touched_this_run`, and the `touched_this_run` state field (`lib/state.sh`); the `reconcile` mode of `sf_synth_master_spec_prompt` (`lib/synthesis.sh`); the reconcile binding rule in `agents/synthesis-agent.md` and the reconcile-mode instructions in `templates/synthesis-briefs/MASTER-SPEC.brief.md`; the associated dormant tests. (#58)

### Changed
- **`sf_synth_master_spec_prompt` simplified to a 3-arg first-author-only signature** (`<brief> <digest_file> <out_path>`); the dead `mode`/`touched`/`existing` parameters and mode-validation guard are gone. The §8 close caller and tests updated to match. (#58)
- **Close-summary backup message** now states the `.bak-<ts>` includes any manual edits, so hand-edits are clearly recoverable after a re-onboard re-synthesis. (#58)
```

- [ ] **Step 3: Update the SS-3 spec descope banner**

In `SS-3-…md`, change the §2.4 / decision-4 banner wording from "descoped to follow-up issue #58" / "deferred → #58" to note the resolution, e.g. append: `**Update 2026-06-08:** #58 closed **wontfix** — partial reconcile evaluated as not worth the complexity; the dormant foundations were removed in scaffold-onboard v0.7.0. Full re-walk + first-author re-synthesis is the permanent model.` (Edit both the top banner blockquote and the decision-4 line; leave the historical design text for the record.)

- [ ] **Step 4: Update the SPEC ledger row N7/#58**

In `SPEC-agent-driven-program.md`, change the N7 row status from `future (lib foundations retained dormant in SS-3)` to `✅ CLOSED (wontfix) 2026-06-08 — partial reconcile not worth the complexity; dormant foundations removed in scaffold-onboard v0.7.0`.

- [ ] **Step 5: Verify version parity**

Run: `bash tests/test-codex-dual-publish.sh` (from repo root)
Expected: `Passed: 148  Failed: 0` (both manifests at 0.7.0).

- [ ] **Step 6: Commit**

```bash
git add scaffold-onboard/.claude-plugin/plugin.json scaffold-onboard/.codex-plugin/plugin.json scaffold-onboard/CHANGELOG.md docs/agent-driven-program/specs/SS-3-agent-synthesized-resumable-onboarding.md docs/agent-driven-program/SPEC-agent-driven-program.md
git commit -m "release(scaffold-onboard): v0.7.0 — decommission partial reconcile; ledger #58 wontfix"
```

---

### Task 7: Full-suite gate + final reconcile-residue sweep

**Files:** none (verification only)

- [ ] **Step 1: Run the full scaffold-onboard suite**

Run: `cd scaffold-onboard && bash run-tests.sh` (background / generous timeout — suites are slow)
Expected: `Test files run: 18` / `Failed files:   0`.

- [ ] **Step 2: Run the repo-root dual-publish test**

Run: `bash tests/test-codex-dual-publish.sh`
Expected: `Passed: 148  Failed: 0`.

- [ ] **Step 3: Final residue sweep**

Run: `cd scaffold-onboard && grep -rniE 'reconcile|mark_touched|touched_this_run|run_reset|phases_touched' lib/ skills/ agents/ templates/ tests/ commands/ | grep -viE 'must reconcile first|wontfix|CHANGELOG'`
Expected: no matches. (CHANGELOG history + the wontfix pointers + the "reconcile first" verb are the only allowed survivors.)

- [ ] **Step 4: No commit (gate only).** If anything failed, fix in the owning task and re-run.

---

## Post-plan (orchestrator, outside task loop)

- Push branch; open PR (`Closes #58`); babysit Codex/CodeRabbit per the convergence rule (merge on Codex-clean + green suite, defer residual CR nits).
- On merge: squash to main, tag `scaffold-onboard-v0.7.0`, confirm #58 auto-closed (or close with the wontfix rationale).
- Update memory only if a non-obvious lesson emerges (the convergence pattern is already captured).
