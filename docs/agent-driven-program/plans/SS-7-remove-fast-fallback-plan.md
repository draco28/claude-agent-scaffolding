# SS-7 — Remove `--fast` Fallback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline) or superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make agent synthesis the only derivation path in scaffold-onboard — delete the `--fast` deterministic fallback and every deterministic content renderer it reaches; ship v0.8.0.

**Architecture:** Uniform model (spec §2): dispatch → main-context-inline → re-dispatch-once → hard-fail; no deterministic content fallback. Mechanical I/O (seed live/static, manifest routing, mcrules-preserve zone, harvest migration, roadmap JSON→md formatter, structural validation, cksum, `_from_synthesized` guarded write-back) survives. Bash tests for derived content convert to mechanical-assertion + canned-fixtures; content-correctness moves to `evals/`.

**Tech stack:** Bash (`sf` libs), Markdown skills/commands/briefs, bash test harness, jq.

**Design doc:** `docs/agent-driven-program/specs/SS-7-remove-fast-fallback.md`
**Branch:** `feat/ss7-remove-fast-fallback` (created; design committed).

**Key facts confirmed during planning:**
- `sf_docs_derive`/`_docs_args`/`_write_or_skip` (`lib/docs.sh`) are **entirely** deterministic render → delete the file's render functions wholesale; the §11 synthesize branch authors docs via agents and knows the doc-set itself.
- `sf_memory_bank_derive` = 8-file render loop + harvest-migration call + `seed_live_static` call. The §13 **synthesize** path already runs the harvest migration (§13.3) and `sf_memory_bank_seed_live_static` independently → after removing the render loop, `sf_memory_bank_derive` is redundant and is **deleted**; the mechanical helpers (`sf_memory_bank_seed_live_static`, `_sf_mb_migrate_harvested`, `_sf_mb_extract/reinject_preserve_zone`, `_memory_bank_args`) survive.
- `lib/render.sh`: remove `sf_render_executive_summary` + `sf_render_executive_summary_from_state`; keep `sf_render_executive_summary_from_synthesized` (+ `_sf_render_executive_summary_body`, `_sf_master_spec_replace_section_body` it relies on).
- roadmap has no content renderer; `--fast` is a dispatch-vs-inline toggle in `planning-project-roadmap` §16 only.

**Verification commands:**
- Single file: `cd scaffold-onboard && bash tests/<file>`
- Full suite: `cd scaffold-onboard && bash run-tests.sh` (18 files; slow — background, generous timeout)
- Dual-publish: `bash tests/test-codex-dual-publish.sh` (repo root; 148)
- Residue sweep: `grep -rnE 'SF_SYNTH_FAST|sf_synth_mode|--fast' scaffold-onboard/{lib,skills,agents,templates,commands,tests} | grep -vi CHANGELOG`

---

## Phase A — Library removals

### Task 1: Remove `sf_synth_mode` from `lib/synthesis.sh`

**Files:** Modify `scaffold-onboard/lib/synthesis.sh`

- [ ] **Step 1:** Delete the `sf_synth_mode` function (the `# Resolve synthesize-vs-deterministic …` comment + the function body, ≈lines 10–18). Nothing else in `synthesis.sh` references `SF_SYNTH_FAST`.
- [ ] **Step 2:** `grep -n 'sf_synth_mode\|SF_SYNTH_FAST' lib/synthesis.sh` → expect no matches.
- [ ] **Step 3:** Commit: `git commit -m "refactor(scaffold-onboard): remove sf_synth_mode (--fast resolver) (#56)"` (other lib refs are removed in later tasks; the function has no internal callers — skill/lib callers are edited in their own tasks; suite gate is Task 18).

### Task 2: Remove deterministic EXEC-SUMMARY renderers from `lib/render.sh`

**Files:** Modify `scaffold-onboard/lib/render.sh`; Test `scaffold-onboard/tests/test-render.sh`

- [ ] **Step 1:** Delete `sf_render_executive_summary` (≈230–257) and `sf_render_executive_summary_from_state` (≈262–305). KEEP `_sf_render_executive_summary_body`, `_sf_master_spec_replace_section_body`, and `sf_render_executive_summary_from_synthesized` (the mechanical guarded write-back).
- [ ] **Step 2:** Update `tests/test-render.sh`: delete tests that call the two removed functions; keep tests for `sf_render` and `sf_render_executive_summary_from_synthesized`. (Read the file; remove only the dead-fn tests.)
- [ ] **Step 3:** `cd scaffold-onboard && bash tests/test-render.sh` → green.
- [ ] **Step 4:** `grep -n 'sf_render_executive_summary\b\|_from_state' lib/render.sh` → only `_from_synthesized` remains.
- [ ] **Step 5:** Commit: `refactor(scaffold-onboard): drop deterministic EXEC-SUMMARY renderers; keep guarded write-back (#56)`

### Task 3: Reduce `lib/memory-bank.sh` to mechanical-only (delete `sf_memory_bank_derive`)

**Files:** Modify `scaffold-onboard/lib/memory-bank.sh`

- [ ] **Step 1:** Delete `sf_memory_bank_derive` entirely (≈218–273: header comment + function). Its render loop is the deterministic path; its migration + `seed_live_static` calls are already performed independently by the §13 synthesize flow.
- [ ] **Step 2:** In `sf_memory_bank_seed_live_static`, remove the `--fast)  export SF_SYNTH_FAST=1 ;;` arm from its arg loop (≈284). Keep `--force`.
- [ ] **Step 3:** Confirm the surviving mechanical helpers are intact: `sf_memory_bank_seed_live_static`, `_memory_bank_args`, `_sf_mb_migrate_harvested`, `_sf_mb_extract_preserve_zone`, `_sf_mb_reinject_preserve_zone`, `_composition_args`, `sf_claude_md_generate`, `sf_agents_md_generate`, `sf_claude_settings_generate`. `grep -n 'SF_SYNTH_FAST\|sf_memory_bank_derive' lib/memory-bank.sh` → no matches.
- [ ] **Step 4:** (No standalone test run yet — `test-memory-bank.sh` converts in Task 12. Do `bash -n lib/memory-bank.sh` to confirm it parses.)
- [ ] **Step 5:** Commit: `refactor(scaffold-onboard): delete deterministic sf_memory_bank_derive; keep mechanical seed/migrate/zone helpers (#56)`

### Task 4: Delete deterministic governance renderer from `lib/docs.sh`

**Files:** Modify `scaffold-onboard/lib/docs.sh`

- [ ] **Step 1:** The entire file is the deterministic renderer (`_docs_args`, `sf_docs_derive`, `_write_or_skip`). Confirm no non-render mechanical caller needs them (the §11 synthesize branch authors docs via agents). Delete `sf_docs_derive`, `_docs_args`, `_write_or_skip`. If that empties the file, leave a stub header comment noting governance derivation is agent-only (SS-7) so `bin/sf`'s `for _f in lib/*.sh` source loop has a valid file, OR remove the file and drop nothing else (the dispatcher tolerates fewer libs). Prefer: reduce to a header-only file documenting the removal.
- [ ] **Step 2:** `grep -rn 'sf_docs_derive\|_docs_args\|_write_or_skip' lib/ skills/` → matches only in `test-docs.sh` (Task 13) and any §11 prose to be edited (Task 6).
- [ ] **Step 3:** `bash -n lib/docs.sh` parses.
- [ ] **Step 4:** Commit: `refactor(scaffold-onboard): remove deterministic sf_docs_derive renderer (#56)`

---

## Phase B — Skill, command, template edits

### Task 5: `scaffolding-memory-bank` SKILL — remove fast path

**Files:** Modify `scaffold-onboard/skills/scaffolding-memory-bank/SKILL.md`

- [ ] **Step 1:** §13.2 — delete the `case " $ARGUMENTS " in *" --fast "*) export SF_SYNTH_FAST=1 ;; esac` line, the `if [[ "$(sf_synth_mode)" == "fast" ]]; then … sf_memory_bank_derive … return 0; fi` block, and the explanatory paragraphs about fast-mode/`return 0`/`${var:+}`.
- [ ] **Step 2:** §9 — remove the `--fast` flag bullet ("use the deterministic derivation path"). Keep `--regenerate`/no-flag.
- [ ] **Step 3:** §1/§3/§4/§10 — scrub references to `sf_memory_bank_derive` as the derivation helper and "deterministic `--fast` fallback" in the description frontmatter + prose; reframe derivation as synthesis-only (the synthesize waves are the path; `seed_live_static` does mechanical seeding). Update §10's helper list to drop `sf_memory_bank_derive`.
- [ ] **Step 4:** **EXEC-SUMMARY produce-once (decided 2026-06-09):** replace the `sf_render_executive_summary` produce-once-if-missing call (≈§13:271) with an **agent dispatch** — when `EXECUTIVE-SUMMARY.md` is missing, dispatch the `EXECUTIVE-SUMMARY.brief.md` synthesis agent from MASTER-SPEC → `sf_render_executive_summary_from_synthesized` write-back (inline fallback if headless). Keep the `sf_exec_summary_staleness` warn path unchanged.
- [ ] **Step 5:** Add (or confirm) a sentence documenting the agent-unavailable model: dispatch → main-context-inline → re-dispatch-once → hard-fail (spec §2). This is the R3 doc-grep target.
- [ ] **Step 6:** `grep -nE 'SF_SYNTH_FAST|sf_synth_mode|--fast|sf_memory_bank_derive|sf_render_executive_summary\b' skills/scaffolding-memory-bank/SKILL.md` → no matches (only `_from_synthesized` may remain).
- [ ] **Step 6:** Commit: `docs(scaffold-onboard): scaffolding-memory-bank synthesis-only, drop --fast (#56)`

### Task 6: `scaffolding-governance-docs` SKILL — remove fast path

**Files:** Modify `scaffold-onboard/skills/scaffolding-governance-docs/SKILL.md`

- [ ] **Step 1:** §11 — delete the `case … --fast … export SF_SYNTH_FAST=1` line, the `if sf_synth_mode == fast` block (the `sf_docs_derive [--full] [--regenerate]` ladder + `return 0`), and the explanatory paragraphs.
- [ ] **Step 2:** Ensure the synthesize branch independently encodes the doc-set (5 default / +6 full / +3 LLM-gated on 9.3.1). If it currently relied on `sf_docs_derive` for the doc list, inline the doc-set + LLM-gate logic into the synthesize dispatch prose. (Read §11 fully; the dispatch must name each doc artifact + the gate.)
- [ ] **Step 2b:** **EXEC-SUMMARY produce-once (decided 2026-06-09):** replace the `sf_render_executive_summary` produce-once-if-missing call (≈§11:234-238) with an agent dispatch (EXECUTIVE-SUMMARY brief from MASTER-SPEC → `_from_synthesized`), inline fallback if headless; keep the `sf_exec_summary_staleness` warn branch.
- [ ] **Step 3:** Scrub frontmatter/§ prose "deterministic `--fast` fallback"; drop `--fast` from the flag docs.
- [ ] **Step 4:** Add/confirm the agent-unavailable model sentence (R3).
- [ ] **Step 5:** `grep -nE 'SF_SYNTH_FAST|sf_synth_mode|--fast|sf_docs_derive' skills/scaffolding-governance-docs/SKILL.md` → no matches.
- [ ] **Step 6:** Commit: `docs(scaffold-onboard): scaffolding-governance-docs synthesis-only, drop --fast (#56)`

### Task 7: `planning-project-roadmap` SKILL — remove dispatch-vs-inline `--fast` toggle

**Files:** Modify `scaffold-onboard/skills/planning-project-roadmap/SKILL.md`

- [ ] **Step 1:** §16 — delete the `if [[ "$(sf_synth_mode)" == "fast" ]]; then … fi` block and the paragraph telling the skill to parse `--fast` into `SF_SYNTH_FAST`. The JSON→markdown formatter (`lib/roadmap.sh`) stays.
- [ ] **Step 2:** §16.3 — make per-slice synthesis the only path: dispatch sub-agents; **inline fallback** (conducting agent authors slices in main context) when no Task tool; re-dispatch-once → hard-fail on bad output. Replace the old "deterministic interactive authoring" wording (it WAS main-context authoring → now the inline fallback, not a user mode).
- [ ] **Step 3:** §12 flag docs — drop `--fast`.
- [ ] **Step 4:** `grep -nE 'SF_SYNTH_FAST|sf_synth_mode|--fast' skills/planning-project-roadmap/SKILL.md` → no matches.
- [ ] **Step 5:** Commit: `docs(scaffold-onboard): planning-project-roadmap synthesis-only, drop --fast (#56)`

### Task 8: `onboarding-project` SKILL — `--fast` vestige + EXEC-SUMMARY rejection path

**Files:** Modify `scaffold-onboard/skills/onboarding-project/SKILL.md`; `scaffold-onboard/skills/onboarding-project/references/example-walkthrough.md`

- [ ] **Step 1:** §8 EXEC-SUMMARY block — the current flow calls `sf_render_executive_summary_from_synthesized`, then on failure falls back to `sf_render_executive_summary` → `_from_state`. Replace the fallback with: **re-dispatch the EXEC-SUMMARY synthesis agent once** with the corrective instruction ("prose/bullets only — no `##`/`---`/phase markers"); if `_from_synthesized` still rejects → hard-fail with remediation (state preserved). Remove the two deleted function names.
- [ ] **Step 2:** §8 MASTER-SPEC / §9 flags — remove any `--fast`/deterministic mention ("Default = synthesis; `--fast` = deterministic" lines). MASTER-SPEC already has no deterministic renderer.
- [ ] **Step 3:** `example-walkthrough.md` — scrub the `--fast` mention.
- [ ] **Step 4:** `grep -nE 'SF_SYNTH_FAST|sf_synth_mode|--fast|render_executive_summary_from_state|sf_render_executive_summary\b' skills/onboarding-project/` → only `_from_synthesized` may remain.
- [ ] **Step 5:** Commit: `docs(scaffold-onboard): onboarding EXEC-SUMMARY re-dispatch-on-reject; drop --fast (#56)`

### Task 9: Commands — drop `--fast`

**Files:** Modify `scaffold-onboard/commands/scaffold-project.md`, `scaffold-onboard/commands/scaffold-docs.md`

- [ ] **Step 1:** Remove `--fast` from each command's documented flags + any `--fast` arg-parse/passthrough in the wrapper body.
- [ ] **Step 2:** `grep -n '\-\-fast' commands/scaffold-project.md commands/scaffold-docs.md` → no matches.
- [ ] **Step 3:** Commit: `docs(scaffold-onboard): drop --fast from /scaffold-project + /scaffold-docs (#56)`

### Task 10: Templates + remaining skills — scrub `--fast`

**Files:** Modify `templates/synthesis-briefs/CLAUDE.brief.md`, `templates/synthesis-briefs/index.brief.md`, `templates/docs-full/DEFINITION_OF_DONE.md.tmpl`, `skills/authoring-vertical-slice-demo/SKILL.md` (+ `references/auto-grammar.md`), `skills/authoring-machine-checkable-rules/SKILL.md`

- [ ] **Step 1:** For each, read the `--fast` mention in context. If it documents the removed flag/mode, remove/reword. If it's an unrelated word ("fast" in prose), leave. (DEFINITION_OF_DONE template `--fast` is likely an example doc-content line — judge in context.)
- [ ] **Step 2:** `grep -rnE '\-\-fast|SF_SYNTH_FAST|sf_synth_mode' templates/ skills/authoring-vertical-slice-demo/ skills/authoring-machine-checkable-rules/` → only intentional non-flag prose remains.
- [ ] **Step 3:** Commit: `docs(scaffold-onboard): scrub --fast from templates + demo/mcrule skills (#56)`

---

## Phase C — Test conversion (the bulk)

### Task 11: Add a shared canned-synthesis fixture helper

**Files:** Modify `scaffold-onboard/tests/_helpers.sh`

- [ ] **Step 1:** Add a helper that writes canned "synthesized" memory-bank derived files (and/or governance docs) into the resolved output dir, mirroring `seed_master_spec_fixture`'s style — e.g. `seed_memory_bank_derived_fixture <dir>` writing the 8 derived files with recognizable content + the mcrules preserve-zone sentinels in `03`. This lets mechanical-layer tests assert seeding/routing/zone/preservation without a live agent. (Model on the existing `_seed_state_for_dispatch` in `test-synthesis-dispatch.sh`.)
- [ ] **Step 2:** `bash -n tests/_helpers.sh` parses.
- [ ] **Step 3:** Commit: `test(scaffold-onboard): add canned-synthesis fixture helper for mechanical assertions (#56)`

### Task 12: Convert `tests/test-memory-bank.sh` to mechanical + fixtures

**Files:** Modify `scaffold-onboard/tests/test-memory-bank.sh`

- [ ] **Step 1:** Read the file. Every test calling `sf_memory_bank_derive` (now deleted) must change. For tests asserting **derived-file content** (e.g. `00-project-brief contains "<pitch>"`): replace the `sf_memory_bank_derive` call with the canned fixture + `sf_memory_bank_seed_live_static`, and re-target the assertion to the **mechanical** property the test actually guards (live-seed preservation, `--force` overwrite, mcrules-zone preserve via `_sf_mb_extract/reinject`, static WORKFLOW copy, tech-debt seed). Delete pure content-render assertions (content-correctness → evals, Task 17).
- [ ] **Step 2:** Keep/adapt the live-file-preserve, force-overwrite, mcrules-zone-preserve, and migration tests — these are mechanical and now the core coverage. Point them at `sf_memory_bank_seed_live_static` / the zone helpers / `_sf_mb_migrate_harvested` directly.
- [ ] **Step 3:** `cd scaffold-onboard && bash tests/test-memory-bank.sh` → green.
- [ ] **Step 4:** Commit: `test(scaffold-onboard): memory-bank tests assert mechanical layer + fixtures (#56)`

### Task 13: Convert `tests/test-docs.sh` to mechanical + fixtures

**Files:** Modify `scaffold-onboard/tests/test-docs.sh`

- [ ] **Step 1:** All tests call `sf_docs_derive` (deleted). The governance docs are now agent-authored, so the mechanical layer left to test is: manifest routing (product vs process ADR destinations), doc-set selection (which files exist for default vs `--full` vs LLM-gate), and preserve-on-exist. Re-author the tests to seed canned doc fixtures + assert routing/selection/preservation, OR (if a test only asserted rendered content) delete it and note the coverage moved to evals. Keep `test_default_does_not_create_full_docs`, `test_full_mode_llm_project` (LLM-gate selection) reframed against the synthesize doc-set logic if it now lives in skill prose — if the selection logic is purely prose, convert these to a doc-grep on §11 instead.
- [ ] **Step 2:** `cd scaffold-onboard && bash tests/test-docs.sh` → green.
- [ ] **Step 3:** Commit: `test(scaffold-onboard): governance tests assert routing/selection, not render (#56)`

### Task 14: Convert `tests/test-e2e.sh`

**Files:** Modify `scaffold-onboard/tests/test-e2e.sh`

- [ ] **Step 1:** Lines ≈79/82/126/160 call `sf_memory_bank_derive` / `sf_docs_derive`. Replace with canned fixtures + the surviving mechanical helpers so the e2e file-existence + routing + settings.json + CLAUDE.md assertions still hold. The "fresh repo" e2e becomes: seed MASTER-SPEC fixture → seed canned derived fixtures → run `seed_live_static` + `sf_claude_md_generate` + `sf_claude_settings_generate` → assert the 14-file set, settings allowlist, CLAUDE.md tiers, routing. Delete assertions that checked render-specific content only.
- [ ] **Step 2:** `cd scaffold-onboard && bash tests/test-e2e.sh` → green.
- [ ] **Step 3:** Commit: `test(scaffold-onboard): e2e uses fixtures + mechanical helpers, not deterministic derive (#56)`

### Task 15: Update synthesis/dispatch tests (invert the `--fast` guards)

**Files:** Modify `scaffold-onboard/tests/test-synthesis-dispatch.sh`, `tests/test-synthesis.sh`, `tests/test-master-spec-synthesis.sh`

- [ ] **Step 1:** `test-synthesis-dispatch.sh` (~30 `SF_SYNTH_FAST` refs): delete the tests asserting "skill exports `SF_SYNTH_FAST` for `--fast`" / "fast-path returns 0 before waves". Replace the key one with an **inverse** guard test: each dispatch skill (`scaffolding-memory-bank` §13, `scaffolding-governance-docs` §11) contains **no** `SF_SYNTH_FAST` / `sf_synth_mode` / `--fast`, and documents the inline fallback (R3 doc-grep). Keep the dispatch/finalize/seed-preservation behavioral tests (those are the agent-driven core).
- [ ] **Step 1b:** The ~14 `sf_render_executive_summary` calls (EXEC produce-once + staleness) + `_from_state` test (≈251-254) + the "phantom"/"intact" guards (`test-master-spec-synthesis.sh:110`, `test-synthesis-dispatch.sh:507`) reference removed fns → rework: invert the "intact"/"phantom" guards to assert **removal**; convert the produce-once tests to assert the skill **dispatches a synthesis agent when EXEC-SUMMARY is missing** (doc-grep on §11/§13) + keep the `sf_exec_summary_staleness` mechanical cksum tests; replace `_from_state` coverage by asserting it is gone.
- [ ] **Step 2:** `test-synthesis.sh` (3 refs) + `test-master-spec-synthesis.sh` (the `MODE: first-author` etc. — already first-author-only post-#58; just remove any lingering `--fast`/`sf_synth_mode` ref): clean.
- [ ] **Step 3:** `cd scaffold-onboard && bash tests/test-synthesis-dispatch.sh && bash tests/test-synthesis.sh && bash tests/test-master-spec-synthesis.sh` → green.
- [ ] **Step 4:** Commit: `test(scaffold-onboard): invert SF_SYNTH_FAST guards → assert no --fast path + inline fallback (#56)`

### Task 16: R3 — inline-fallback documentation guard test

**Files:** Modify `scaffold-onboard/tests/test-synthesis-dispatch.sh` (or `test-e2e.sh` skill-presence block)

- [ ] **Step 1:** Add a test asserting each content-authoring skill body documents the agent-unavailable model (dispatch → inline → re-dispatch-once → hard-fail). Concretely: grep each of `scaffolding-memory-bank`, `scaffolding-governance-docs`, `planning-project-roadmap`, `onboarding-project` SKILL.md for an inline-fallback phrase (e.g. "main-context-inline" / "inline synthesis") AND a "no deterministic" / hard-fail-remediation phrase. This is the only feasible bash coverage of the unrunnable inline path.
- [ ] **Step 2:** Run the file → green.
- [ ] **Step 3:** Commit: `test(scaffold-onboard): guard inline-fallback documentation across dispatch skills (#56)`

---

## Phase D — Evals, release, gate

### Task 17: Audit + extend `evals/` for derived-content correctness

**Files:** Modify `scaffold-onboard/evals/onboarding-project.md` and/or add `evals/scaffolding-memory-bank.md`, `evals/scaffolding-governance-docs.md` if absent

- [ ] **Step 1:** `ls evals/` — determine which surfaces already have an LLM-judge eval. Memory-bank + governance derived-content correctness was bash-asserted; with that gone, ensure an eval scenario exists that judges: a synthesized memory-bank file is faithful to MASTER-SPEC + preserves the mcrules zone; synthesized governance docs cover the doc-set + LLM-gate. Add scenarios where missing (follow the existing eval scenario format: Trigger / Expected behavior / Assertion).
- [ ] **Step 2:** No bash run (evals are LLM-judge specs). Sanity: `grep -c '## ' evals/*.md` to confirm scenarios added.
- [ ] **Step 3:** Commit: `test(scaffold-onboard): add eval coverage for agent-authored derived content (#56)`

### Task 18: Version bump, docs/ledger, full-suite gate, residue sweep

**Files:** Modify `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `CHANGELOG.md`, `docs/agent-driven-program/SPEC-agent-driven-program.md`

- [ ] **Step 1:** Bump both manifests `0.7.0` → `0.8.0`.
- [ ] **Step 2:** `CHANGELOG.md` add `## [0.8.0]` — Removed (the `--fast` mode, `sf_synth_mode`, deterministic memory-bank/governance renderers, 2 EXEC-SUMMARY renderers); Changed (agent-unavailable model: dispatch→inline→re-dispatch-once→hard-fail; EXEC-SUMMARY re-dispatch-on-reject; tests assert mechanical layer + evals own content-correctness). Note **behavior change**: no deterministic fallback on agent/host failure.
- [ ] **Step 3:** SPEC §5 SS-7 header → `✅ SHIPPED 2026-06-09`; ledger N6/#56 row → closed with provenance.
- [ ] **Step 4:** Full suite: `cd scaffold-onboard && bash run-tests.sh` (background) → `Test files run: 18 / Failed files: 0`.
- [ ] **Step 5:** Dual-publish (repo root): `bash tests/test-codex-dual-publish.sh` → `Passed: 148  Failed: 0`.
- [ ] **Step 6:** Residue sweep: `grep -rnE 'SF_SYNTH_FAST|sf_synth_mode|--fast' scaffold-onboard/{lib,skills,agents,templates,commands,tests} | grep -vi CHANGELOG` → empty (or only intentional non-flag prose).
- [ ] **Step 7:** Commit: `release(scaffold-onboard): v0.8.0 — remove deterministic --fast fallback; ledger #56 closed`

---

## Post-plan (orchestrator, outside task loop)
- Push branch; open PR (`Closes #56`); babysit Codex/CodeRabbit per the convergence rule (merge on Codex-clean + green suite, defer residual nits).
- On merge: squash, tag `scaffold-onboard-v0.8.0`, confirm #56 auto-closed; update SPEC ledger if not already.
- Memory: note only if a non-obvious lesson emerges.
