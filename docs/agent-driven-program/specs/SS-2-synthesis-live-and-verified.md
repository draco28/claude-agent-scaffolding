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
3. **EXEC-SUMMARY synthesized from MASTER-SPEC (#49) — single authoritative producer (SP-1 revised per critique).** New `templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md`. To avoid re-introducing the #45 two-writers-one-artifact class (critique premise #2), there is **exactly one authoritative producer/refresher: `onboarding-project` at onboarding-close** (replacing the phantom `sf_render_executive_summary`). The `/scaffold-*` commands **only consume** `EXECUTIVE-SUMMARY.md`; if it is *missing* (legacy project) they **produce-once** as a Wave-0 dependency, but they **never refresh it** — not even under `--regenerate` (which scopes to the bundle, not the summary). Refreshing EXEC-SUMMARY is done by re-running the onboarding synthesis.
   - **Ownership class:** EXEC-SUMMARY is **spec-derived** (from MASTER-SPEC); hand-edits are overwritten on the authoritative refresh. Stated in its header + the SSoT notes, analogous to SS-1's classification.
   - **Staleness detection (not silent):** before the consuming waves run, compare EXEC-SUMMARY vs MASTER-SPEC (mtime, with a content-hash trailer as the robust signal). If MASTER-SPEC is newer, **warn** ("EXECUTIVE-SUMMARY.md is older than MASTER-SPEC.md — re-run onboarding synthesis to refresh") and proceed; never silently consume a stale summary as if intentional.
   - **`--fast` parser contract (critique #2/#9):** the deterministic fallback extracts MASTER-SPEC's named "Executive Summary" section. Define behavior for absent / renamed / empty / duplicated: a missing-or-empty section is an **explicit error with a fix hint**, never a silent thin summary; a duplicated heading takes the first and warns. The section name is a pinned contract.
   - All phantom `sf_render_executive_summary` references removed (`onboarding-project/SKILL.md`, `references/example-walkthrough.md`).
4. **#42 = advisory, whole-bundle review — with a disposition lifecycle (critique premise #4).** A new read-only sub-agent `scaffold-onboard:derivation-reviewer` (Read/Grep/Glob; no Write, no Task — parallel to `synthesis-agent`), dispatched once after the synthesis waves on each surface. It reads the synthesized bundle + MASTER-SPEC + EXEC-SUMMARY and emits findings (faithfulness, hallucinations, unmet FR/NFR, weak/thin sections). **Non-blocking**, but findings have a defined lifecycle so the review isn't documentation theater:
   - **Recorded, artifact-linked:** the report is written to a known path (`<bundle>/derivation-review.md`) with each finding tagged by the **target filename** and the MASTER-SPEC revision (content-hash) it was reviewed against, so a finding is actionable and detectably stale on the next run.
   - **Defined apply path:** each finding carries one of `accept` / `regenerate <file>` / `edit`. **`regenerate <file>` maps to a concrete action: a targeted re-synth of that single artifact** (`/scaffold-project --regenerate=<file>` / the governance equivalent) — not a full-bundle clobber. The skill surfaces the report and the per-file regenerate commands; the user runs them.
   - Distinct from the mechanical `sf_synth_assert_*` validators (which stay, in-line, per artifact).
5. **Behavioral dispatch harness — the real OQ-1 closer (critique premise #1, #5).** The root risk is *executability of the orchestration shell*, not just helper sourcing — a stubbed-return test + static source-guard can go green while the real path aborts. So the primary regression guard **extracts the actual dispatch / fallback / finalize shell blocks** from the synthesis SKILL sections and **executes them under `set -euo pipefail`** in an isolated fixture, with **faked `Task` outputs** (stub sub-agent return files written to the resolved artifact paths). This *behaviorally* proves: the shell runs without unbound-variable/undefined-function abort (catches the OQ-1 class for real), the per-artifact fallback path executes, and the finalize steps (settings.json, AGENTS.md, live-seed) write. The stubbed-return contract test (ledger merge / `assert_*` consumption) and a static source-guard remain as **secondary** lints, not the main protection.
   - **Honest boundary:** the harness cannot prove the *LLM orchestrator* will choose to dispatch / honor ordering — that part is irreducibly prose (bash can't dispatch sub-agents). The harness proves the *shell it runs* is correct; the prose is mitigated by explicit control-flow (W1) + clear instructions + the W6 in-session smoke. This residual is stated as a known limit, not hidden.
6. **Fallback failure-domain — explicit (critique #3, #6).** Fallback is **per-artifact**: only the artifact whose synthesis failed/validated-bad falls back to deterministic render; successfully synthesized siblings are kept. **Ledger consistency:** a fallback-rendered artifact mints no agent IDs; the coverage report (`sf_synth_coverage_report`) flags any FR/NFR a fallback artifact left uncovered so downstream citations can't silently reference IDs from a discarded agent output. **Concurrency:** waves write **distinct files** and the orchestrator merges the ledger **serially after each `Task` returns** — there is no concurrent write-race or ledger race (documented rebuttal to the locking concern); the genuine risk is an **interrupted run**, recovered by skip-if-exists on re-run (resume) or `--regenerate` (full re-derive). Synthesis writes are atomic (agent `Write`).
7. **Verification is reproducible (critique #5/#10).** The behavioral harness in §2.5 **is** the repeatable acceptance signal that survives the PR. The one real in-session synthesize-mode smoke (W6) is **supplementary evidence** captured in the build report — not the definition of "fixed."

---

## 3. What "fixed" looks like (target behavior)

| Surface | Default run today (OQ-1) | After SS-2 |
|---|---|---|
| `/scaffold-project` (memory bank + CLAUDE.md) | attempts dispatch → aborts under `set -u` at the `03`/fallback/finalize steps (unsourced helpers); settings.json/AGENTS.md may never write | sources all needed libs; EXEC-SUMMARY present (Wave 0); waves author 8 derived files + CLAUDE.md; SS-1 preserve/migration intact; advisory review; `--fast` clean fallback |
| `/scaffold-docs` (governance) | attempts dispatch; fallback target `sf_docs_derive` self-contained but setup may miss its source; comment-only STOP | sources `docs.sh`; PRD→SRS→BACKLOG→fan-out waves author docs; advisory review; `--fast` clean fallback |
| EXEC-SUMMARY | phantom render fn; `{{executive_summary}}` hole | synthesized from MASTER-SPEC at onboarding-close (single producer); `/scaffold-*` consume it (produce-if-missing only, staleness-warned vs MASTER-SPEC); deterministic `--fast` fallback with pinned parser contract |
| CI | a broken dispatch stays green | behavioral harness executes the dispatch/fallback/finalize shell under `set -euo pipefail` with faked Task outputs → a real abort fails CI (+ contract test + source-guard secondary) |

---

## 4. Work breakdown

- **W1 (dispatch executability):** fix `scaffolding-memory-bank/SKILL.md` §13 + `scaffolding-governance-docs/SKILL.md` synthesis section — `source` every lib the dispatch/fallback/finalize body calls; replace comment-only `# STOP` short-circuits with explicit control-flow. No behavior change to the deterministic path.
- **W2 (EXEC-SUMMARY synthesis, #49):** add `EXECUTIVE-SUMMARY.brief.md`; synthesize at **onboarding-close** in `onboarding-project` as the single authoritative producer (remove phantom `sf_render_executive_summary` there + in `references/example-walkthrough.md`); add a Wave-0 **produce-if-missing-only** (no refresh) EXEC-SUMMARY step + the **staleness warning** (EXEC-SUMMARY vs MASTER-SPEC) to both `/scaffold-*` synthesis sections; classify EXEC-SUMMARY as spec-derived in its header + SSoT notes; deterministic `--fast` fallback derives from MASTER-SPEC's pinned "Executive Summary" section with the explicit absent/empty/duplicated **parser contract** (§2.3).
- **W3 (#42 review):** register `agents/derivation-reviewer.md` (Read/Grep/Glob); document its dispatch (once, post-waves, both surfaces) in the two synthesis SKILL sections; define the findings-report **lifecycle** — written to `<bundle>/derivation-review.md`, each finding tagged by target filename + MASTER-SPEC content-hash, with `accept`/`regenerate <file>`/`edit` dispositions where **`regenerate <file>` = a targeted single-artifact re-synth command** the skill surfaces (§2.4). Non-blocking.
- **W4 (behavioral dispatch harness + secondary lints):** the **primary** test extracts the dispatch/fallback/finalize shell blocks from the synthesis SKILL sections and **executes them under `set -euo pipefail`** with faked `Task` output files, asserting no abort + fallback executes + finalize writes (the real OQ-1 closer). **Secondary:** the stubbed-return contract test (ledger merge / `assert_*` consumption / forced-failure fallback) + a static source-guard + `EXECUTIVE-SUMMARY.brief.md` validation + Wave-0-wiring + parser-contract (absent/empty section → error) + staleness-warning assertions. New `tests/test-synthesis-dispatch.sh`.
- **W5 (verify):** one real in-session synthesize-mode `/scaffold-project` + `/scaffold-docs` against a fixture MASTER-SPEC — **supplementary evidence** (the W4 harness is the repeatable acceptance), recorded in the build report (dispatch fired, bundle written, review ran).
- **W6 (release):** scaffold-onboard `0.4.0 → 0.5.0` (Claude + Codex `plugin.json` parity), CHANGELOG `[0.5.0]`, README version table + memory-bank/synthesis description; PR → bot-review → tag `scaffold-onboard-v0.5.0`.

---

## 5. Tests / acceptance

- **Behavioral harness (primary):** the extracted dispatch/fallback/finalize shell blocks run under `set -euo pipefail` with faked `Task` outputs and complete without abort; the per-artifact fallback path executes; finalize writes settings.json/AGENTS.md/live-seed. A regression of the OQ-1 unsourced-helper class fails this test for real.
- **Contract test (secondary):** a stubbed agent return is consumed; ledger merges; `assert_sections`/`assert_no_markers`/`validate_cited` run; a forced validation failure triggers per-artifact deterministic fallback (successful siblings preserved) and the coverage report flags the uncovered FR/NFR.
- **EXEC-SUMMARY:** brief passes `sf_synth_brief_validate`; produced at onboarding-close; consumed (not refreshed) by `/scaffold-*`; staleness warning fires when MASTER-SPEC is newer; `--fast` parser contract errors loudly on an absent/empty "Executive Summary" section; no `sf_render_executive_summary` reference remains anywhere.
- **#42 review:** `derivation-review.md` is written with per-finding target-file + MASTER-SPEC-hash tags and a `regenerate <file>` command per regenerate-finding.
- Existing deterministic / `--fast` / brief-validation suites stay green.
- W5 supplementary smoke: a real synthesize run completes end-to-end on both surfaces with the advisory review surfaced.

---

## 6. Non-goals (explicit)

- **No reconciliation / agent-merge engine.** SS-1 dissolved it for memory-bank (file separation + `03` preserve zone); governance docs stay skip-if-exists / `--regenerate`-clobber, with the #42 advisory review covering quality.
- **No MASTER-SPEC authoring rework or onboarding resumability** — that is **SS-3** (#51). SS-2 only synthesizes the *summary* from an already-authored MASTER-SPEC.
- **No new deterministic content gates.** The #42 review is advisory (agent-review-over-gates principle); the mechanical `sf_synth_assert_*` validators are unchanged.
- **`scaffold-dev` untouched — and the boundary is real, not just asserted (critique #7).** SS-2 changes how artifacts are *authored* (synthesis dispatch), **not their output format/contract**: memory-bank file shapes, the R1/R2/R3 roadmap+rules+demo contracts, and governance doc structure are unchanged. scaffold-dev consumes those *shapes*, which SS-2 does not alter — so there is no cross-plugin version skew (only scaffold-onboard bumps; the dual-publish parity test still guards the Claude/Codex manifests).

**Cost posture (critique #8):** default-on synthesis dispatches many sub-agents per run (EXEC-SUMMARY + memory-bank waves / governance waves + the review). This is the intentional quality-first default from v0.3; `--fast` is the deterministic, no-dispatch escape for cost/latency-sensitive runs. SS-2 does not change the default; it makes both paths correct.

---

## 7. Settle-points — ALL RESOLVED (2026-06-04, SP-1/SP-4 revised post-critique)

- **SP-1 — EXEC-SUMMARY → single authoritative producer (REVISED per critique premise #2).** Produced/refreshed **only** at onboarding-close; `/scaffold-*` consume it and produce-once-if-missing but never refresh (no second writer); spec-derived ownership; staleness-warned vs MASTER-SPEC; pinned `--fast` parser contract. (§2.3.)
- **SP-2 — #42 review shape → advisory, whole-bundle, one sub-agent per surface, post-waves, non-blocking, with a recorded artifact-linked disposition lifecycle + targeted-regenerate apply path.** New `derivation-reviewer` agent. (§2.4.)
- **SP-3 — reconciliation-into-re-derive → NON-GOAL.** Dissolved by SS-1 for memory-bank; governance unchanged. (§6.)
- **SP-4 — dispatch test → behavioral harness (REVISED per critique premise #1).** Execute the actual dispatch/fallback/finalize shell blocks under `set -euo pipefail` with faked Task outputs (primary); stubbed-return contract test + static source-guard secondary. Per-artifact fallback domain + serial ledger merge specified. (§2.5, §2.6, §5.)
- **SP-5 — scope → broadest (make-it-real + verify + #42 + #49).** scaffold-onboard-only; scaffold-dev boundary documented (§6). (§1, §2.)

---

## 8. Critique record (2026-06-04, architect-critic close-depth: claude + codex fresh-frame)

8 consolidated challenges (3 premise, 4 gap, 1 alt); 6 conceded + 2 documented-rebuttals. Cross-confirmed premise findings drove the revisions above: **#1** prose-dispatch testability → behavioral harness (SP-4); **#2** EXEC-SUMMARY two-writer/staleness/parser-contract → single authoritative producer (SP-1); **#3/#6** fallback failure-domain → per-artifact + serial-ledger (§2.6); **#4** #42 review = "documentation theater" without a lifecycle → recorded artifact-linked disposition + apply path (SP-2); **#5/#10** one-time smoke ≠ acceptance → behavioral harness is the repeatable signal (§2.7). Documented rebuttals: **#6** no concurrent write-race (distinct files + serial ledger merge); **#7** scaffold-dev boundary is real (authoring mechanism changes, output contracts don't).
