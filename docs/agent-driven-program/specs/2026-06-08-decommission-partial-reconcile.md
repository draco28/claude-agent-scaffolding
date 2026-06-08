# Decommission partial reconcile-on-re-onboard (N7 / #58) — wontfix

**Date:** 2026-06-08 · **Type:** decommission / cleanup (not a feature build)
**Ledger row:** N7 = #58 (the SS-3-deferred "true reconcile" follow-up)
**Plugins touched:** `scaffold-onboard` only. **Release:** scaffold-onboard `v0.7.0`.

---

## 1. Decision

Close #58 **wontfix**. The **full re-walk + first-author re-synthesis** shipped in SS-3 is the
permanent re-onboard model. Remove the dormant partial-reconcile machinery that SS-3 retained
"for #58" so the codebase reflects reality.

## 2. Why (the reconsideration)

When asked what value partial reconcile delivers over the working full re-walk, the answer was
"neither worth it." Holding that up:

- The full re-walk already shows prior answers as **editable defaults** — revising one phase is
  mostly accept-presses, not re-typing.
- Direct hand-edits to `MASTER-SPEC.md` are already **backed up to `.bak-<ts>`** on re-onboard —
  recoverable, just not auto-merged. Hand-editing the SSoT *then* re-onboarding is an unusual
  combination (the intended edit path is re-onboard → re-synthesize).
- Partial reconcile is a **proven defect magnet** — it is why SS-3 descoped it (the
  self-referential `9.3` gate regression across review rounds).
- Its hardest sub-problems were **already solved incidentally by #59**: subsection-gate exposure
  (`sf_phases_subsection_gates`) and gate-value unescaping.
- The retained dormant code is now **untested-in-flow dead code** — the exact surface that
  confused SS-3's 10-round bot review.

This rhymes with SS-7 (#56, remove the deterministic `--fast` dead path): the program's current
ethos is *remove dormant paths*, not finish speculative ones.

## 3. What is NOT lost

**Removal changes zero current user-facing behavior** — the reconcile machinery was never wired
into the live `/onboard` flow. What we permanently decline to build:

| Capability | Stays (full re-walk) | Abandoned (reconcile) |
|---|---|---|
| Refresh only some phases | Re-walk all 10, prior answers pre-filled as defaults | "Just re-do phase 5" |
| Auto-preserve manual `MASTER-SPEC.md` edits | Whole spec re-synthesized; prior saved to `.bak-<ts>` | Splice untouched/edited sections forward automatically |

Both abandoned capabilities were **dormant** — neither works today, so nothing regresses.

## 4. Scope — removal inventory

**Library**
- `lib/synthesis.sh` — `sf_synth_master_spec_prompt`: remove the reconcile `mode_block` branch and
  the mode-validation guard; **simplify the signature to `sf_synth_master_spec_prompt <brief>
  <digest_file> <out_path>`** (drop the now-dead `mode` / `touched` / `existing` params). The
  prompt always emits first-author instructions. (Keep the existing brief-readable / digest
  not-found / **empty-digest** guards added in #59.)
- `lib/state.sh` — remove `sf_state_mark_touched`, `sf_state_run_reset`,
  `sf_state_phases_touched_this_run`; drop `touched_this_run` from `sf_state_init` and stop
  appending it in `sf_state_write_phase_record`.

**Agent / brief**
- `agents/synthesis-agent.md` — remove the reconcile binding rule; description → first-author
  MASTER-SPEC synthesis only.
- `templates/synthesis-briefs/MASTER-SPEC.brief.md` — remove the reconcile-mode instructions.

**Skill + references**
- `skills/onboarding-project/SKILL.md` — §8: update the close-ceremony caller to the simplified
  signature, drop the `mode`/`existing`/`touched` vars; §4: remove the "Reset the per-run tracker"
  bullet and the "Note (deferred): Partial-reconcile mode…" note.
- `skills/onboarding-project/references/resume-handling.md` — scrub reconcile/deferred mentions
  (mode table reonboard row, the partial-reconcile-deferred line).
- `skills/onboarding-project/references/example-walkthrough.md` — scrub the one reconcile mention.

**Tests**
- `tests/test-master-spec-synthesis.sh` — delete `test_prompt_reconcile_lists_touched_and_existing`,
  `test_reconcile_preserves_untouched_human_edit`, `test_prompt_rejects_bogus_mode`; update
  first-author call sites + `test_close_block_*` to the 3-arg signature; rename
  `test_close_block_reconcile_backs_up_existing` → reflect first-author backup (the `.bak` still
  happens). Keep `test_close_block_aborts_on_corrupt_digest` and the empty-digest guard test.
- `tests/test-phase-records.sh` — delete `test_touched_this_run_tracks_writes`,
  `test_run_reset_clears_touched`, `test_mark_touched_adds_phase_to_tracker`,
  `test_mark_touched_is_idempotent`, `test_mark_touched_coexists_with_write_phase_record`; remove
  the `"touched_this_run": []` assertion from the state-init test.

## 5. Preserved behavior (explicitly keep)

- `phase_records` schema-v2 + all SS-3 first-author synthesis.
- Full re-walk on re-onboard with prior answers as defaults.
- `.bak-<ts>` backup of any pre-existing `MASTER-SPEC.md` before re-synthesis.
- #59 hardening: digest fail-fast, empty-digest rejection, `digest_rc` §8 guard, subsection-gate
  helper + unescape.

## 6. Tiny UX touch

§8 close-summary backup line — when a prior spec existed, extend
`Re-synthesized (full first-author); prior spec backed up to <master_bak>.` to note the backup
**includes any manual edits**, so users know where to recover them.

## 7. Docs / ledger / issue

- `docs/agent-driven-program/specs/SS-3-…md` — change the §2.4 / decision-4 descope banner from
  "deferred → #58" to "**decided wontfix → #58 closed**; dormant foundations removed in v0.7.0."
- `SPEC-agent-driven-program.md` ledger row N7/#58 → **closed (wontfix)** with provenance.
- `scaffold-onboard/CHANGELOG.md` — `## [0.7.0]` entry (Removed/Changed).
- Bump `.claude-plugin/plugin.json` + `.codex-plugin/plugin.json` to `0.7.0`.
- Close GitHub issue #58 with the §2 rationale.

## 8. Test / release plan

- After removals: full suite `bash scaffold-onboard/run-tests.sh` (18 files) green, and repo-root
  `bash tests/test-codex-dual-publish.sh` (148; version-parity at 0.7.0) green.
- No new feature tests — this is a removal; success = the suite stays green with the dead tests
  gone and the simplified signature exercised by the surviving first-author tests.
- Ship via PR → Codex/CodeRabbit review → merge on Codex-clean + green (convergence rule) → tag
  `scaffold-onboard-v0.7.0`.

## 9. Risks

- **Signature change breaks a caller/test I missed.** Mitigation: grep `synth_master_spec_prompt`
  across the repo before/after; the full suite + dual-publish guard catches arity drift.
- **Removing `touched_this_run` from new state.** Legacy v2 state files that still carry the field
  are harmless (the field is simply ignored on read); `sf_state_init` no longer emits it. No
  migration needed.
- **A doc still references reconcile after the sweep.** Mitigation: final
  `grep -riE 'reconcile|mark_touched|touched_this_run' scaffold-onboard/` must return only
  intentional historical mentions (CHANGELOG history, the SS-3 banner pointer).
