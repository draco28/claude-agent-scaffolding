# SS-2 — Synthesis Live & Verified + EXEC-SUMMARY + post-derivation review

**Status:** Design-locked (sub-spec of `docs/agent-driven-program/SPEC-agent-driven-program.md` → SS-2) · **Date:** 2026-06-04
**Closes:** `#50`/N2 (dark-synthesis — OQ-1), `#42` (agent-driven post-derivation doc review), `#49`/N1 (EXECUTIVE-SUMMARY hole).
**Plugins touched:** `scaffold-onboard` only (memory-bank + governance synthesis dispatch, onboarding EXEC-SUMMARY, briefs, a new review agent, tests). scaffold-dev untouched.
**Depends on:** SS-1 (shipped) — uses the `03` preserve-zone + migration helpers already in `lib/memory-bank.sh`.

> **Design settled with user 2026-06-04** (SS-2 brainstorm). Scope chosen: broadest — make-it-real + verify + #42 review + #49 EXEC-SUMMARY. This sub-spec is design-locked except the explicit settle-points in §7 (all resolved).

---

## 1. The core realization (OQ-1 resolved)

OQ-1 asked: *does `/scaffold-project` + `/scaffold-docs` actually dispatch synthesis by default, or fall through to deterministic stubs?* Investigation verdict (2026-06-04, evidence below): **LIVE-BUT-BUGGY and entirely unverified** — not purely "dark."

- **The mechanism defaults to synthesize.** `lib/synthesis.sh::sf_synth_mode` returns `"synthesize"` unless `SF_SYNTH_FAST=1`; neither command wrapper sets the fast flag (`commands/scaffold-project.md`, `commands/scaffold-docs.md` grep only `--regenerate`/`--full`). So an orchestrator following the skill *would attempt* dispatch.
- **But the dispatch prose breaks at the edges.** Decisive defect: `scaffolding-memory-bank/SKILL.md` §13.1 sources **only** `synthesis.sh` + `routing.sh` (lines 252-253), yet the dispatch/fallback/finalize bodies call `sf_memory_bank_derive`, `sf_claude_md_generate`, `sf_claude_settings_generate`, `sf_agents_md_generate`, `_memory_bank_args`, `sf_render`, `_sf_mb_extract_preserve_zone`, `_sf_mb_reinject_preserve_zone` — all defined in `lib/memory-bank.sh`/`render.sh`, never sourced → **abort under the command's `set -u`**. The fast-path/fallback finalize steps (settings.json, AGENTS.md, live-seed) error the same way. The `# STOP` short-circuits (mem `:272`, gov analog) are comment-only — no real control-flow exit.
- **EXEC-SUMMARY is a hole (#49).** `sf_render_executive_summary` is referenced (`onboarding-project/SKILL.md`, `references/example-walkthrough.md:213`) but **defined nowhere**; `templates/master-spec/EXECUTIVE-SUMMARY.md.tmpl` is a 4-placeholder stub with a `{{executive_summary}}` value that has no source. Since the memory-bank/governance briefs *consume* `EXECUTIVE-SUMMARY.md` as a source doc, this caps downstream synthesis quality.
- **Zero tests exercise dispatch.** `tests/test-synthesis.sh` tests only the deterministic helpers + `--fast` + brief validation — no `Task()` path, no stub. A broken dispatch (or wholesale silent fallback) is invisible to CI.

**Consequence:** SS-2 is a blend of "turn it on" (it's already on) and "fix the model" — concretely: make the wired dispatch *executable* on both surfaces, give EXEC-SUMMARY a real synthesized source, add an advisory content-quality review, and add the dispatch test that makes a broken dispatch impossible to merge green. Then verify with one real end-to-end run.

---

## 2. Settled decisions

1. **Make-it-real + verify is the spine** (not a rewrite). Synthesis stays default-on; `--fast` stays the explicit deterministic fallback; SS-1's preserve/migration behavior is unchanged. SS-2 fixes the executability defects and proves the path works.
2. **Dispatch executability (both surfaces).** Each synthesis-dispatch section sources every lib its dispatch/fallback/finalize body calls; the fast-path short-circuit uses explicit control-flow (not a comment) so it cannot fall through into the waves. Memory-bank pulls from `memory-bank.sh` + `render.sh` + `synthesis.sh` + `routing.sh`; governance from `docs.sh` + `synthesis.sh` + `routing.sh`.
3. **EXEC-SUMMARY synthesized from MASTER-SPEC (#49).** New `templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md`. Authored in **two places** (settle-point SP-1 resolved): (a) at **onboarding-close** in `onboarding-project` (replacing the phantom `sf_render_executive_summary`), so it exists before any `/scaffold-*`; and (b) re-synthesized as a **Wave-0 dependency** at the start of `/scaffold-project` + `/scaffold-docs` — skip-if-exists, refresh on `--regenerate` — so the consuming waves always have a current one and it can't go stale after a MASTER-SPEC edit. `--fast` fallback = deterministic derive from MASTER-SPEC's "Executive Summary" section. All phantom `sf_render_executive_summary` references removed.
4. **#42 = advisory, whole-bundle review.** A new read-only sub-agent `scaffold-onboard:derivation-reviewer` (Read/Grep/Glob; no Write, no Task — parallel to `synthesis-agent`), dispatched once after the synthesis waves on each surface. It reads the synthesized bundle + MASTER-SPEC + EXEC-SUMMARY and emits a findings report (faithfulness to spec, hallucinations, unmet FR/NFR, weak/thin sections) with per-finding accept / regenerate / edit suggestions. **Non-blocking** — surfaced to the user, who decides. Distinct from the mechanical `sf_synth_assert_*` validators (which stay).
5. **Dispatch integration test.** A test stubs the `synthesis-agent` return JSON (the `mode:complete` + `ids_minted`/`ids_cited` contract) and asserts the orchestration consumes it correctly (ledger merge via `sf_synth_ledger_merge`, `sf_synth_assert_sections`/`assert_no_markers`/`validate_cited`, and the fallback-on-failure path), plus a regression guard for the unsourced-helper class (assert each synthesis-dispatch section sources the libs its body references) and EXEC-SUMMARY Wave-0 wiring.
6. **End-to-end verification.** One real synthesize-mode `/scaffold-project` + `/scaffold-docs` against a fixture MASTER-SPEC, dispatched in-session during the build (agent-driven smoke, not a bash CI test), confirming: dispatch fires, sub-agents author the artifacts, validators pass, the #42 review runs, and the bundle + settings.json + AGENTS.md are written. Recorded in the build report.

---

## 3. What "fixed" looks like (target behavior)

| Surface | Default run today (OQ-1) | After SS-2 |
|---|---|---|
| `/scaffold-project` (memory bank + CLAUDE.md) | attempts dispatch → aborts under `set -u` at the `03`/fallback/finalize steps (unsourced helpers); settings.json/AGENTS.md may never write | sources all needed libs; EXEC-SUMMARY present (Wave 0); waves author 8 derived files + CLAUDE.md; SS-1 preserve/migration intact; advisory review; `--fast` clean fallback |
| `/scaffold-docs` (governance) | attempts dispatch; fallback target `sf_docs_derive` self-contained but setup may miss its source; comment-only STOP | sources `docs.sh`; PRD→SRS→BACKLOG→fan-out waves author docs; advisory review; `--fast` clean fallback |
| EXEC-SUMMARY | phantom render fn; `{{executive_summary}}` hole | synthesized from MASTER-SPEC at onboarding-close + refreshed Wave-0; deterministic `--fast` fallback |
| CI | a broken dispatch stays green | dispatch integration test + source-guard fail on regression |

---

## 4. Work breakdown

- **W1 (dispatch executability):** fix `scaffolding-memory-bank/SKILL.md` §13 + `scaffolding-governance-docs/SKILL.md` synthesis section — `source` every lib the dispatch/fallback/finalize body calls; replace comment-only `# STOP` short-circuits with explicit control-flow. No behavior change to the deterministic path.
- **W2 (EXEC-SUMMARY synthesis, #49):** add `EXECUTIVE-SUMMARY.brief.md`; synthesize at onboarding-close in `onboarding-project` (remove phantom `sf_render_executive_summary` there + in `references/example-walkthrough.md`); add the Wave-0 EXEC-SUMMARY step (skip-if-exists / refresh-on-`--regenerate`) to both `/scaffold-*` synthesis sections as a dependency of the consuming waves; deterministic `--fast` fallback derives from MASTER-SPEC §Executive Summary.
- **W3 (#42 review):** register `agents/derivation-reviewer.md` (Read/Grep/Glob); document its dispatch (once, post-waves, both surfaces) in the two synthesis SKILL sections; define the findings-report shape (per-finding accept/regenerate/edit) and the non-blocking surface.
- **W4 (tests):** add a dispatch integration test (stubbed `synthesis-agent` return JSON → assert orchestration consumes + validates + falls back) + a source-guard test (each synthesis-dispatch section sources the libs it references) + EXEC-SUMMARY brief-validation and Wave-0-wiring assertions, in `tests/test-synthesis.sh` (or a new `tests/test-synthesis-dispatch.sh`).
- **W5 (verify):** one real in-session synthesize-mode `/scaffold-project` + `/scaffold-docs` against a fixture MASTER-SPEC; record outcomes (dispatch fired, bundle written, review ran) in the build report.
- **W6 (release):** scaffold-onboard `0.4.0 → 0.5.0` (Claude + Codex `plugin.json` parity), CHANGELOG `[0.5.0]`, README version table + memory-bank/synthesis description; PR → bot-review → tag `scaffold-onboard-v0.5.0`.

---

## 5. Tests / acceptance

- Dispatch integration test: a stubbed agent return is consumed; ledger merges; `assert_sections`/`assert_no_markers`/`validate_cited` run; a forced validation failure triggers the deterministic fallback (and the fallback does not abort — proves W1).
- Source-guard test: every synthesis-dispatch section's referenced helpers are sourced by that section's setup (regression guard for the OQ-1 unsourced-helper class).
- `EXECUTIVE-SUMMARY.brief.md` passes `sf_synth_brief_validate`; the Wave-0 step is wired before the consuming waves; no `sf_render_executive_summary` reference remains anywhere.
- Existing deterministic / `--fast` / brief-validation suites stay green.
- W5 manual/agent smoke: a real synthesize run completes end-to-end on both surfaces with the advisory review surfaced.

---

## 6. Non-goals (explicit)

- **No reconciliation / agent-merge engine.** SS-1 dissolved it for memory-bank (file separation + `03` preserve zone); governance docs stay skip-if-exists / `--regenerate`-clobber, with the #42 advisory review covering quality.
- **No MASTER-SPEC authoring rework or onboarding resumability** — that is **SS-3** (#51). SS-2 only synthesizes the *summary* from an already-authored MASTER-SPEC.
- **No new deterministic content gates.** The #42 review is advisory (agent-review-over-gates principle); the mechanical `sf_synth_assert_*` validators are unchanged.

---

## 7. Settle-points — ALL RESOLVED (2026-06-04)

- **SP-1 — EXEC-SUMMARY production location → both.** Onboarding-close (fixes #49 where the phantom lives) **and** Wave-0-on-`/scaffold-*` (skip-if-exists / refresh-on-`--regenerate`) so consumers always have a fresh one. (§2.3.)
- **SP-2 — #42 review shape → advisory, whole-bundle, one sub-agent per surface, post-waves, non-blocking.** New `derivation-reviewer` agent. (§2.4.)
- **SP-3 — reconciliation-into-re-derive → NON-GOAL.** Dissolved by SS-1 for memory-bank; governance unchanged. (§6.)
- **SP-4 — dispatch test → stubbed agent-return JSON + source-guard.** (§2.5, §5.)
- **SP-5 — scope → broadest (make-it-real + verify + #42 + #49).** scaffold-onboard-only; scaffold-dev untouched. (§1, §2.)
