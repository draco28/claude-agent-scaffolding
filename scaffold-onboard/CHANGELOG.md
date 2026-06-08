# Changelog

All notable changes to scaffold-onboard documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [0.7.0] — 2026-06-08

Decommission partial reconcile-on-re-onboard (#58, wontfix). The full re-walk + first-author re-synthesis shipped in SS-3 is the permanent re-onboard model; the dormant reconcile machinery SS-3 retained "for #58" is removed. **No user-facing behavior changes** — the reconcile path was never wired into the live `/onboard` flow. scaffold-onboard only.

### Removed
- **Dormant partial-reconcile machinery.** `sf_state_mark_touched`, `sf_state_run_reset`, `sf_state_phases_touched_this_run`, and the `touched_this_run` state field (`lib/state.sh`); the `reconcile` mode of `sf_synth_master_spec_prompt` (`lib/synthesis.sh`); the reconcile binding rule in `agents/synthesis-agent.md` and the reconcile-mode instructions in `templates/synthesis-briefs/MASTER-SPEC.brief.md`; and the associated dormant tests. None of this was reachable from the live skill flow. (#58)

### Changed
- **`sf_synth_master_spec_prompt` simplified to a 3-arg first-author-only signature** (`<brief> <digest_file> <out_path>`); the dead `mode`/`touched`/`existing` parameters and the mode-validation guard are gone. The §8 close caller and tests updated to match. (#58)
- **Close-summary backup message** now states the `.bak-<ts>` includes any manual edits ("Copy anything you want to keep before continuing"), so hand-edits are clearly recoverable after a re-onboard re-synthesis. (#58)

## [0.6.1] — 2026-06-08

SS-3 residual review polish (closes #59). Non-product-bug edge-case/prose/robustness items deferred at the PR #57 merge so the first-author SS-3 core could ship; this is the focused follow-up pass. No output-contract change. **scaffold-onboard only.** (The broader *true reconcile* follow-up remains #58.)

### Added
- **`sf_phases_subsection_gates <yaml> <phase>` helper** (`lib/state.sh`) lists each gated subsection in a phase as `<subsection_id>\t<gate_expr>`. Subsection-level gates do not surface via `sf_phases_question_gate` (which reads question-level gates only), so the conducting agent had no clean, data-driven way to see which subsections are gated. The emitted gate is **unescaped** (the `7.4` gate `project_class == \"Library or SDK\"` becomes the logical `project_class == "Library or SDK"`) so it round-trips through `sf state_gate_passes` instead of warning-unknown and defaulting to pass. The helper is read-only — it does not evaluate gates or filter questions (gate-aware digest resolution remains deferred to #58). Wired into `onboarding-project` SKILL §3 per-phase loop. Guarded by `test-state.sh`. (#59.4)

### Fixed
- **`sf_state_synthesis_digest` now fails fast on a corrupt/unreadable state file** instead of silently emitting a thin (answer-less) digest that the synthesis agent would turn into a hollow MASTER-SPEC. A `jq -e .` validity gate surfaces a parse failure with a clear error and non-zero exit. Defense-in-depth: `sf_synth_master_spec_prompt` also rejects an **empty** digest file (the residue a failed `> "$digest_file"` redirection leaves on corrupt state), and SKILL §8 checks the digest exit code (`digest_rc`) before backup/assembly/dispatch — so the close ceremony preserves `status=close_pending` rather than synthesizing from nothing. Guarded by `test-state.sh` + `test-master-spec-synthesis.sh`. (#59.7)
- **Record-repair eligibility is now explicitly gate-aware** (`onboarding-project` SKILL §4): a required question inside a *gated-out* subsection no longer blocks missing-record repair (e.g. a Library/SDK project never answers the web-UX `6A.*` questions), and unanswered *optional* questions never block repair nor get re-asked by the pass. The conductor judges active subsections via `sf phases_subsection_gates` + `sf state_gate_passes` — no helper-level gate-filtering (that caused the reverted Phase-9 LLM-opt-in regression). (#59.1, #59.2)
- **Fresh `/onboard --regenerate` (no prior state) now inits state first** before its atomic writes, so a `--regenerate` with no existing onboarding no longer fails on `sf state_write_atomic` reading a non-existent state file. (#59.5)
- **MASTER-SPEC prompt-assembly failures are surfaced before dispatch** (`onboarding-project` SKILL §8): if `sf synth_master_spec_prompt` exits non-zero, the skill surfaces the error and stops (state preserved, `status=close_pending`) rather than dispatching the synthesis agent / entering the inline fallback with an empty prompt. (#59.3)

### Changed
- **Eval reproducibility note** (`evals/onboarding-project.md`) now requires clearing `onboarding.lock` between scenarios — a stale lock made the next scenario fail at lock acquisition with a false contention error. (#59.6)
- **`references/resume-handling.md` synced** so the missing-record repair scan documents covering phases 1 *through and including* `current_phase` (and all 10 on a `close_pending` resume), matching SKILL §4 — plus the gated-out/optional eligibility rule. (#59.8)

## [0.6.0] — 2026-06-06

SS-3 — agent-synthesized, resumable onboarding (closes #51). MASTER-SPEC is now synthesized by a sub-agent (or inline in main context) at Phase-10 close, replacing mechanical `{{placeholder}}` transcription. Onboarding state schema v2 captures per-phase records (decisions/rationale/rejected-alternatives/critic-outcomes) alongside verbatim answers, making sessions resumable across interruptions. Enhancement re-runs (`--regenerate`) do a full re-walk + first-author re-synthesis (all phases re-walked with existing answers as defaults; whole spec re-synthesized; prior spec backed up). **scaffold-onboard only**; scaffold-dev untouched. (True *partial* reconcile — touched-phase-only refresh preserving human edits + gate-aware digest — was descoped to follow-up #58 during review.)

### Changed
- **MASTER-SPEC is now agent-synthesized at onboarding close (no deterministic transcription).** The mechanical `sf_master_spec_init`/`sf_master_spec_update_phase` renderers and the `MASTER-SPEC.md.tmpl` template are removed. At Phase-10 close the conducting agent dispatches `scaffold-onboard:synthesis-agent` with a tool-agnostic synthesis brief (`MASTER-SPEC.brief.md`) carrying a phase-records digest; the fallback is main-context-inline (not a deterministic template). First-author and reconcile prompt paths are both guarded by `test-master-spec-synthesis.sh`. (SS-3, #51)
- **Onboarding state captures per-phase reasoning (phase_records) beside verbatim answers.** State schema bumped to v2: `phase_records` map (phase → decisions/rationale/rejected-alternatives/critic-outcomes, agent-authored during each phase) + `touched_this_run` list. Legacy v1 state is migrated on first write. Guarded by `test-phase-records.sh`. (SS-3, #51)
- **Enhancement re-runs (`--regenerate`) do a full re-walk + first-author re-synthesis.** When `MASTER-SPEC.md` already exists, the close block backs it up (`MASTER-SPEC.md.bak-<ts>`) and re-synthesizes the whole spec from the (re-walked) state in first-author mode. True *partial* reconcile (touched-phase-only refresh preserving direct human edits to the spec file, plus gate-aware digest filtering) is deferred to follow-up #58; the lib retains the dormant `sf_synth_master_spec_prompt` reconcile mode + `sf_state_mark_touched` foundations. (SS-3, #51)

## [0.5.0] — 2026-06-04

SS-2 — synthesis live & verified + EXECUTIVE-SUMMARY + advisory post-derivation review (closes #50, #49, #42). Makes the v0.3 LLM-synthesis dispatch actually execute end-to-end on `/scaffold-project` and `/scaffold-docs`, gives EXECUTIVE-SUMMARY a real spec-derived producer, and adds an advisory content-quality review — guarded by a behavioral dispatch harness so a broken dispatch can no longer merge green. **scaffold-onboard only**; scaffold-dev untouched (no output-contract change → no cross-plugin version skew).

### Added
- **EXECUTIVE-SUMMARY is now synthesized from MASTER-SPEC (#49).** New `templates/synthesis-briefs/EXECUTIVE-SUMMARY.brief.md` plus a real deterministic renderer `sf_render_executive_summary` (previously a phantom reference, defined nowhere). It is produced by **exactly one authoritative producer — `onboarding-project` at onboarding-close** (synthesis by default; deterministic under `--fast`). `/scaffold-project` and `/scaffold-docs` only **consume** it: produce-once-if-missing for legacy projects, **never refresh**, and **warn** when it is stale vs MASTER-SPEC (content-hash trailer). Spec-derived ownership (hand-edits overwritten on the authoritative refresh). The `--fast` parser contract extracts MASTER-SPEC's pinned `## Executive Summary` section and **errors loudly** on an absent/empty section — never a silent thin summary.
- **Advisory post-derivation review (#42).** New read-only `agents/derivation-reviewer.md` (Read/Grep/Glob; no Write, no Task) dispatched once after the synthesis waves on each surface. **Non-blocking**, with a recorded artifact-linked **disposition lifecycle**: findings tagged by target filename + the MASTER-SPEC content-hash they were reviewed against, each carrying `accept` / `regenerate <file>` / `edit`, where `regenerate <file>` surfaces the supported boolean `--regenerate` command plus the internal single-artifact re-dispatch target. The report is written to `<bundle>/derivation-review.md`.
- **Behavioral dispatch harness (`tests/test-synthesis-dispatch.sh`).** Executes the actual dispatch/fallback/finalize shell under `set -euo pipefail` with faked agent outputs, so the OQ-1 unsourced-helper class fails CI for real; plus source-guard, parser-contract, staleness, per-artifact-fallback, fragile-flag-expansion, and live-seed-preservation regression tests.

### Fixed
- **Synthesis dispatch was live-but-buggy (#50 / OQ-1).** Both synthesis-dispatch SKILL sections (`scaffolding-memory-bank` §13, `scaffolding-governance-docs` §11) now `source` every lib their dispatch/fallback/finalize body calls (`memory-bank.sh` + `render.sh`; `docs.sh`) — previously they sourced only `synthesis.sh` + `routing.sh` and aborted under the slash command's `set -u`. The comment-only `# STOP` fast-path short-circuits are now real `return 0`.
- **Fast-path could silently clobber live-seed files.** The fast-path no longer uses the fragile `${regenerate:+--force}` / `${full:+--full}` idiom (which expands on the string `"0"`, not just when the flag is present); it uses explicit `== "1"` tests, so a normal `--fast` run can no longer force-overwrite the user's in-flight live-seed files (`05`/`06`/`09`/`10`) or `WORKFLOW.md` without an explicit `--regenerate`.
- **Doubled `---` separator in the EXEC-SUMMARY render.** The deterministic renderer strips a trailing horizontal-rule from the extracted MASTER-SPEC section, so it no longer doubles the template's own separator.

## [0.4.0] — 2026-06-02

SS-1 — memory-bank ownership + single-point update cadence (closes #45; the agent-driven program's foundational sub-spec). The memory bank grows from 12 to **14 files**.

### Added
- **Two pure-dev-authored live-seed files: `09-known-issues.md` + `10-decisions-log.md`.** `09` holds caveats / gotchas / workarounds + dev-discovered stack notes (Tier 0, always-loaded); `10` holds build-time decisions + advisory patterns (on-demand). Both seeded header-only on first `/scaffold-project` and **preserved** across re-derive (same bucket as `05`/`06`). Registered in `index.md`, the CLAUDE.md Tier-0 preload (09), and the load-tier matrix.
- **Single canonical "Memory-bank update cadence" policy** in `WORKFLOW.md` (marked with the `cadence-policy:canonical` sentinel comment): one event × file × who table, three ownership classes (spec-derived / dev-authored / mixed), and the slice-close harvest routing rule. Every other skill now points here instead of restating cadence — enforced by a new grep-guard test (`tests/test-cadence-single-source.sh`).
- **One-time migration (#45 / SP-5):** `/scaffold-project` now relocates provenance-trailed harvest content (`<!-- Added from VS… -->`) out of spec-derived memory-bank files into `09-known-issues.md` before regenerating them — never silent-drop. Seeds `09` from its template on the legacy-upgrade path so the header/sections/cadence pointer survive. No-op on fresh projects.

### Changed
- **`03-code-patterns.md` now preserves its `## Machine-checkable rules` section across re-derive.** The section is wrapped in `<!-- mcrules:preserve:start/end -->` sentinels; `sf_memory_bank_derive` (and the synthesis path) extract the zone before re-render and re-inject it after, so authored rules are no longer clobbered. `authoring-machine-checkable-rules` inserts new rules inside that zone. The rest of `03` still re-renders from MASTER-SPEC.
- **CLAUDE.md SSoT note + CLAUDE.brief.md synthesis guidance rewritten** to distinguish spec-derived (regenerated) from dev-authored (preserved) files and point to the single cadence policy.
- De-contamination sweep: every cadence restatement across templates + skills now points to the policy; stale "11/12-file" current-count references updated to 14.

## [0.3.6] — 2026-05-30

### Added
- **#28 Phase 2 — publish the structured roadmap state into the workspace.** `sf_roadmap_render` now also calls a new `sf_roadmap_publish_state`, which copies `project-roadmap.json` (the structured roadmap with explicit `id` + `sprint_id` fields) from onboard's data dir to the workspace contract path the manifest routes via `well_known_paths.roadmap_state` (`${ai_workspace.root}/.workspace/project-roadmap.json`, added in workspace-init 0.1.2). This gives scaffold-dev's orchestrator a structured surface to **field-read** the slice `id`/`sprint_id` from — the fix for the #28 cross-plugin slice-ID arity mismatch (so it no longer guesses the sprint by string-splitting a rendered `#### VS-…:` heading). Best-effort: a no-op (info log) in standalone mode with no workspace-init manifest; never blocks the `ROADMAP.md` write. The scaffold-dev consumer side (field-read + complete fixture migration) is Phase 3.

### Fixed
- **PR #31 review hardening (Codex P2 ×3) on `sf_roadmap_publish_state` / `sf_roadmap_render`.** (1) **Resolve all manifest placeholders** — the routed `well_known_paths.roadmap_state` path is now expanded through the shared `mi_manifest_resolve` (every supported placeholder: `${ai_workspace.root}`, `${canonical.root}`, `${HOME}`, …) instead of a naive `${ai_workspace.root}`-only substitution, with a guard that refuses to write a path still carrying an unresolved `${…}`. (2) **Atomic publish** — the structured state is written to a sibling temp then renamed into place, so a concurrent scaffold-dev field-read never observes a half-written `project-roadmap.json` when re-rendering over an existing file. (3) **Render failures propagate** — `sf_roadmap_render` no longer lets the trailing best-effort publish mask a real render/write error (it previously always returned `0`); a render/`mv` failure now returns non-zero while a publish failure stays a warn-only no-op. Adds three regression tests to `test-roadmap.sh`.

## [0.3.5] — 2026-05-30

### Fixed
- **#28 (Phase 1, doc-truth) — removed the false "slice IDs match scaffold-dev's `VS-N.M` schema" claim.** scaffold-onboard authors **3-part** slice IDs (`VS-<phase>.<sprint>.<slice>`, e.g. `VS-1.1.1`) but four shipped docs claimed this "matches"/"chains cleanly into" scaffold-dev's **2-part** `docs/specs/sprint-N/VS-N.M-<kebab>/` schema — a self-contradiction (3-part ≠ 2-part). Corrected `planning-project-roadmap/SKILL.md`, `authoring-vertical-slice-demo/SKILL.md`, `examples/sample-project/ROADMAP.md`, and `planning-project-roadmap/references/example-hierarchy.md` to state the canonical 3-part identifier honestly and point at #28 for the (still-open) cross-plugin consumer-contract alignment. The `/orchestrate VS-N.M` command examples in the generated templates are **deliberately left as-is** — current scaffold-dev parses 2-part IDs (`planning-vertical-slice` derives `docs/specs/sprint-<N>/` from the first field; `closing-vertical-slice` resolves `VS-N.M`), so showing the 3-part form would route users into a failed path-derivation. The command-arity correction lands with the #28 code-side contract fix (structured field-read), gated on a verification spike per the architect-critic audit. Docs-only.
- **Synced the Codex manifest version (Codex review on PR #29).** `.codex-plugin/plugin.json` was stranded at `0.3.3` — it was never bumped for 0.3.4 or 0.3.5, so Codex installs (published via `.agents/plugins/marketplace.json`) would never receive the fixes. Bumped to `0.3.5` and added a version-parity assertion to `tests/test-codex-dual-publish.sh` so a release that bumps only the Claude manifest can no longer drift the Codex manifest silently.

## [0.3.4] — 2026-05-30

### Security
- **Issue #25 — settings.json template auto-approved command-exec & secret-disclosure escapes.** `templates/settings/claude-settings.json.tmpl` — copied verbatim into every scaffolded project by `/scaffold-project` (`sf_claude_settings_generate`) — shipped `Bash(rg:*)` and `Bash(jq:*)` on the `permissions.allow` list. As `allow` entries these ran with **no confirmation prompt**, yet both carry allowlist-escape vectors the `:*` wildcard cannot exclude: `rg --pre <cmd>` / `--search-zip` execute arbitrary external programs, and `jq -n 'env'` dumps all environment variables (`--rawfile`/`--slurpfile` read arbitrary files). The default allowlist is now reduced to the three safe read-only git grants (`git status`/`git diff`/`git log`); `rg`/`jq`/`cat`/`grep`/`ls` are removed (the dedicated Read/Grep/Glob tools cover those uses without a Bash auto-approve). A new `test-e2e.sh` regression asserts the generated settings contains no escape-capable grant.

### Fixed
- **Issue #26 Slip 1 — branch-gated sections were over-required, forcing needless template fallback.** Three memory-bank briefs (`01-product-context`, `03-code-patterns`, `04-tech-context`) listed project-class-conditional headings (Backend/Frontend/Library specifics; UI/DX Surfaces & flows) as flat `required_sections`. `sf_synth_assert_sections` has no gate concept, so when a synthesis agent correctly omitted an inapplicable branch section the validator failed it and swapped good LLM output for a deterministic template. These headings now live in a new additive `gated_sections:` frontmatter block (never hard-required); `sf_synth_brief_assemble` surfaces them to the agent under a "Conditional sections (include only when the branch applies)" block instead of "must all appear". New `test-synthesis.sh` coverage pins the lenient behavior.
- **Issue #26 Slip 2 — synthesis briefs referenced "the template" for verbatim content the sub-agent can't see, so it hallucinated.** `CLAUDE.brief.md` said "include the scaffold/ai-mentor commands exactly as in the template" without embedding them; the deterministic `CLAUDE.md.tmpl` it pointed at was itself stale (`/slice-new`, `/z1`, `/quiz`, `/adr-new` — none exist). Both now carry the **ground-truth** slash-command tables verbatim (`/orchestrate` `/work-item` `/impl-check` `/handoff`; `/council` `/grill-me` `/eli10` `/fool`; `/critique` `/critique-list` `/principles-list` `/promote-principle`; base `/onboard` `/plan-roadmap` `/scaffold-project` `/scaffold-docs`), with the swapped `/scaffold-project`↔`/scaffold-docs` descriptions corrected and known-hallucinated names explicitly banned. Same root cause fixed in `index.brief.md` (the Tier-0 always-preloaded memory-bank index table is now embedded for verbatim copy instead of referenced). Lower-severity prose references (DEFINITION_OF_DONE/RISK_REGISTER/BACKLOG/PROMPT_GOVERNANCE) already inline their essential format and are left as-is.
- **#26 Slip 2 root cause swept beyond the synthesis path.** The same dead command names were baked into other shipped surfaces and were never exercised by the synthesis review: the `templates/memory-bank/WORKFLOW.md` slice loop still described the retired scaffold v1.0 five-command sequence (`/slice-new`→`/slice-verify`) — rewritten to the current scaffold-dev shape (`/orchestrate`→`/work-item`→`/impl-check`→`/handoff`→ slice close); the `lib/compose.sh` Phase-5/7 mentor hint suggested the nonexistent `/z2-decide` — now `/grill-me` (test sentinel updated); and the governance commands `/adr-new`/`/runbook-new` across `ADR-0001`/`DEFINITION_OF_DONE`/`PROMPT_GOVERNANCE`/`TEST_STRATEGY` briefs and the docs-full/docs-minimal templates were corrected (with `/slice-verify` references re-pointed at the slice `auto:` demo + `/impl-check` gate). Stale `/z2-decide` test sentinels in `test-e2e.sh`/`test-memory-bank.sh` updated to the `cognitive modes (ai-mentor)` marker.
- **scaffold-dev composition detection was broken — the slice-workflow command block never rendered.** (Found by Codex review on PR #27.) `_composition_args` read `.plugins["scaffold"].installed`, but the plugin was renamed `scaffold` → `scaffold-dev` and `lib/compose.sh` never probed for it at all, so `has_scaffold_plugin` was always false and the `{{#if has_scaffold_plugin}}` block in `CLAUDE.md.tmpl` was effectively dead code (undercutting the command-table corrections above). Added `sf_compose_detect_scaffold_dev` (probes the full `scaffold-dev` prefix — a bare `scaffold` prefix would false-match scaffold-onboard itself), wrote the `scaffold-dev` plugin entry into `composition.json`, and made `_composition_args` read it (legacy `scaffold` key honored as fallback). New `test-compose.sh` coverage + a `test-e2e.sh` assertion that the `/orchestrate` block renders when scaffold-dev is detected.
- **Skill-only commands no longer advertised as typed slash commands in generated docs.** (Codex review on PR #27.) Only `/orchestrate`, `/work-item`, `/impl-check`, `/handoff` ship as scaffold-dev command files; slice-close, sprint-close, ADR, runbook, and changelog are skill/natural-language actions. Generated `WORKFLOW.md`, the governance briefs, and the docs-full/docs-minimal templates now present those as their natural-language triggers (e.g. `close VS-N.M`, `close sprint N`, `record ADR`, `author runbook`, `add changelog entry`) so users don't hit an unresolved slash command. (The slice-ID arity mismatch Codex also flagged — scaffold-onboard 3-part `VS-1.1.1` vs scaffold-dev 2-part `VS-N.M` — is a cross-plugin contract decision tracked in #28.)
- **CodeRabbit nits (PR #27):** `/work-item` → `/work-item <handoff>` in the PROJECT_PLAN example; `markdown` language tag on the `index.brief.md` fenced block (MD040); and the settings-allowlist e2e guard now asserts all three safe git grants (`status`/`diff`/`log`), not just `status`.
- **Upgrade path for existing projects (Codex round-3 review on PR #27).** The v0.3.4 template fixes only reached *new* projects; three gaps left already-scaffolded repos behind: **(a)** `sf_claude_settings_generate` skipped any existing `settings.json`, so upgraders kept the unsafe `rg`/`jq` grants — it now scans an existing file and **warns loudly** when escape-capable grants are present (listing them + remediation), without auto-editing the user's file; **(b)** the static `WORKFLOW.md` was never refreshed — `sf_memory_bank_derive --force` now overwrites it (it carries no per-project content) so existing projects pick up the corrected slice loop; **(c)** the legacy-`scaffold`-key fallback added earlier in this release was removed — the old `scaffold` v1.0 plugin shipped a different command surface (`/slice-*`), so a stale key must not light up scaffold-dev's `/orchestrate` block. New `test-memory-bank.sh` coverage for the warn path and the `--force` refresh.

## [0.3.3] — 2026-05-29

### Fixed
- **Issue #23 — synthesis validators rejected valid LLM output.** Three `lib/synthesis.sh` bugs that silently downgraded good synthesized docs back to deterministic templates: (1) `sf_synth_assert_no_markers` flagged every `*(...)*` italic — including legitimate annotations like `*(traces_uc: UC-1)*` — now only imperative fill-in stubs (`*(populate …)*`, `TODO:`/`TBD`) trip it; (2) `sf_synth_validate_cited` + `sf_synth_coverage_report` threw `Cannot index string with "id"` on string-array ledgers — both now tolerate object- or string-shaped entries; (3) `sf_synth_assert_sections` was exact/case-sensitive — now normalizes case + a dropped trailing parenthetical (`## Initial stories` matches required `Initial stories (seeded from MASTER-SPEC.md)`). The brief-assembly "hard rules" no longer ban `*(...)*` wholesale.
- **Issue #22 — settings.json `$schema` host.** `claude-settings.json.tmpl` used `www.schemastore.org`, which fails Claude Code's `/doctor`; corrected to `json.schemastore.org`.
- **Issue #24 — skill-description bloat.** Tightened the over-long `description:` frontmatter on seven skills (authoring-vertical-slice-demo, validating-master-spec, authoring-machine-checkable-rules, scaffolding-governance-docs, scaffolding-memory-bank, planning-project-roadmap, checking-workspace-interoperability) to ~440–570 chars, preserving trigger phrases and disambiguations — part of cutting the cross-plugin skill-listing budget (~5.9k→~3.6k description tokens) so descriptions stop being truncated/dropped.

## [0.3.2] — 2026-05-29

### Fixed
- **Issue #20 — ROADMAP renderer shipped a broken artifact:** `_sf_roadmap_render_to_stdout` emitted an empty H1 (`# ROADMAP — ` with no project name) and a literal `<3-paragraph summary…>` stub. The renderer now resolves the project name via `sf_project_name` (onboarding answer 1.1.4 → cwd basename) when roadmap state lacks one — H1 is now `# <ProjectName> — Roadmap` — and seeds the overview from the elevator pitch (answer 1.1.1) plus a soft italic invitation to expand, never an angle-bracket stub.
- **Issue #21 — Karpathy opt-in silently no-op'd:** the `phase_10.4.include_karpathy = yes` opt-in captured during `/onboard` was never emitted. `CLAUDE.md.tmpl` now contains the `{{#if include_karpathy}}` Behavioral Discipline block (verbatim attribution "Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)"), and `sf_claude_md_generate` reads the answer and passes `include_karpathy=true` only when the answer is the literal `yes`. This also makes the skill description's Karpathy claim accurate again.
- **Stale skill metadata:** the `scaffolding-governance-docs` and `scaffolding-memory-bank` frontmatter descriptions still said "Deterministically derive"; updated to reflect LLM-assisted sub-agent synthesis by default (with the deterministic `--fast` path / per-artifact fallback) introduced in v0.3.0.

## [0.3.1] — 2026-05-29

### Fixed
- **Issue #18 — `sf_roadmap_write_sprint` doc/signature mismatch:** the `planning-project-roadmap` skill documented the arguments as `<phase_id> <id> …`, but the lib takes `<sprint_id> <phase_id> …` (sprint_id first; phase_id is a bare-integer `--argjson`). Following the doc made every sprint in a phase collide on one id and silently overwrite (only the last survived). Corrected §4.2 of the skill to the real order with an explicit note on the sprint_id-string / phase_id-integer distinction. Doc-only change; the lib signature (which the test suite already pins) is unchanged.

## [0.3.0] — 2026-05-29

### Added
- **Issue #17 — LLM sub-agent synthesis layer:** post-MASTER-SPEC artifacts (governance docs, roadmap slices, memory-bank, CLAUDE.md) are now synthesized by `scaffold-onboard:synthesis-agent` from `MASTER-SPEC.md` + `EXECUTIVE-SUMMARY.md` instead of deterministic `{{placeholder}}` substitution, raising them from scaffolds to production-grade documents.
- `lib/synthesis.sh` — deterministic orchestration helpers: `sf_synth_mode` (`--fast` gate), brief frontmatter reader/validator, ID-ledger merge, cited-ID / required-section / fill-in-marker validators, brief assembly with consumed-ledger slicing, and requirement coverage rollup.
- `agents/synthesis-agent.md` — registered sub-agent (Read/Write/Grep/Glob; no Task, no git) with a compact ID-ledger return contract.
- `templates/synthesis-briefs/*.brief.md` — 24 per-artifact synthesis briefs (machine-readable section contract + guidance), dispatched in dependency waves (PRD → SRS → BACKLOG → fan-out) so minted `UC`/`FR`/`NFR`/`BACKLOG` IDs stay consistent across artifacts.
- `--fast` flag on `/scaffold-docs`, `/plan-roadmap`, `/scaffold-project` for the deterministic (zero-token, offline) path.

### Fixed
- **Issue #16:** SRS now derives Functional Requirements from PRD use cases (`UC-N`) and Non-Functional Requirements from quality attributes (latency/determinism/security/coverage) instead of from implementation (Phase 7) and devops (Phase 8); PRD emits a full `UC-1..UC-N` use-case set rather than a single use case.
- `project_name` em-dash truncation (`${raw_pitch%% — *}` in three call sites) that produced garbage document titles — replaced with a shared `sf_project_name` helper backed by an explicit onboarding answer (`1.1.4`).

### Changed
- Post-MASTER-SPEC derivation is synthesis-by-default; the prior deterministic substitution remains available via `--fast` and as the per-artifact fallback when synthesis fails validation.

## [0.2.3] — 2026-05-28

### Added
- **Issue #15 — per-project state:** onboarding and roadmap state now live under project-scoped plugin data directories, allowing multiple projects to be mid-onboarding or mid-roadmap-planning under the same plugin install.
- Added `sf project_identity_root` and `sf project_data_dir` helper surfaces for resolving the current project identity and its state directory.
- `project-roadmap.json` now records `project_root` on new initialization.

### Changed
- `sf state_path`, `sf state_lock_path`, and `sf roadmap_state_path` now resolve to project-scoped paths while preserving their public call signatures.
- `project_mismatch` is retained as a same-project moved/malformed-state guard; switching to a different project now opens a different state file instead of asking to overwrite the singleton.

### Migration
- Matching legacy singleton files at the install-level `onboarding-state.json` and `project-roadmap.json` are copied into the project-scoped directory when ownership can be proven from `project_root`.
- Legacy singleton files are never deleted automatically.

## [0.2.2] — 2026-05-28

### Added
- **Issue #14 — traceability-first docs:** default SRS and BACKLOG templates now mint stable `FR-N`, `NFR-N`, and `BACKLOG-N` IDs for downstream planning.
- **Issue #14 — roadmap trace links:** roadmap slice records now include `traces_fr`, `traces_nfr`, and `traces_backlog` arrays; ROADMAP rendering shows trace links under each vertical slice.
- **Issue #14 — coverage report:** added `sf roadmap_traceability_report` to print covered and unassigned FR/NFR/BACKLOG IDs from generated docs and `project-roadmap.json`.

### Changed
- Roadmap planning guidance now recommends `/scaffold-docs` before `/plan-roadmap` for traceability-first projects while preserving lightweight MASTER-SPEC-only planning with warnings.

### Fixed
- **Issue #13 — manifest routing regression coverage:** added a real workspace-init resolver integration test proving `sf resolve_output_path master_spec MASTER-SPEC.md` does not double-append `.workspace/pairing.json`.

## [0.2.1] — 2026-05-26

Shell-portability + cross-project-contamination patch (v0.x.1 bundle). See `docs/HANDOFF-shell-portability-v0x1.md` and `docs/HANDOFF-shell-portability-v0x1-RETURN.md` in the marketplace repo.

### Fixed
- **Shell portability (zsh compatibility):** Claude Code's Bash tool runs zsh by default on macOS; skill bodies that `source lib/*.sh` then inherited zsh, where `${BASH_SOURCE[0]}` is unset (libs crash with `parameter not set`) and `${BASH_REMATCH[…]}` returns empty silently (parser appears to work, downstream gets garbage — scaffold-onboard had the worst silent-corruption surface with 11 BASH_REMATCH sites in spec parsers / rule validators). Added `bin/sf` dispatcher with `#!/usr/bin/env bash` shebang — kernel forces bash on direct execution regardless of caller shell. `validating-master-spec/SKILL.md` and its example walkthroughs refactored to invoke `sf <fn-suffix>` instead of `source && fn`. `sf --list` enumerates dispatchable functions. The dispatcher is auto-discoverable via `$PATH` (Claude Code adds each plugin's `bin/` to PATH automatically).
- **Issue #3 — `sf_data_dir` no longer falls back to `~/.scaffold-onboard-test-data/`:** that path was originally a "test fallback" but became the production-active path because Claude Code does not export `CLAUDE_PLUGIN_DATA` to Bash tool subprocesses (anthropics/claude-code#48230). v0.2.1 derives the canonical `~/.claude/plugins/data/<plugin>-<marketplace>/` path from `$PLUGIN_ROOT` when the install matches the cache layout, and falls back to `~/.claude/plugins/data/scaffold-onboard-local/` (intentionally NOT colliding with the host-runtime path) when derivation fails. The old `~/.scaffold-onboard-test-data/` path is gone.
- **Issue #4 — cross-project state contamination:** added `project_root` field to `onboarding-state.json` schema. `sf_state_init` captures `pwd` (or `$SF_PROJECT_ROOT` if pre-exported); `sf_state_mode` now returns a new `project_mismatch` value when the stored `project_root` differs from current `pwd`, prompting the user before resuming a stranger's state. New `sf_state_stored_project_root` helper returns the stored path (or `unknown` for legacy state files lacking the field). The `onboarding-project` skill's resume protocol updated to handle `project_mismatch`. Legacy state files (pre-v0.2.1) lacking `project_root` surface as `project_mismatch` with stored=`unknown`, forcing user confirmation.

### Migration notes
- Existing `~/.scaffold-onboard-test-data/onboarding-state.json` files are NOT auto-migrated to the new canonical path. To preserve in-flight onboarding state from v0.2.0, manually `mv ~/.scaffold-onboard-test-data ~/.claude/plugins/data/scaffold-onboard-claude-agent-scaffolding` (substitute your marketplace name) or delete the stale file and restart `/onboard`.
- Legacy state files lacking `project_root` will trigger the project-mismatch prompt on next `/onboard` invocation — pick "start fresh here" to overwrite with a new init.

## [0.2.0] — 2026-05-24

### Added
- **7 skills under `skills/<name>/SKILL.md`** (structural skill-first per SPEC §4.3): `onboarding-project`, `scaffolding-memory-bank`, `scaffolding-governance-docs`, `planning-project-roadmap`, `authoring-machine-checkable-rules`, `authoring-vertical-slice-demo`, `validating-master-spec`. Each ≤500 lines. Slash commands become thin Skill-tool dispatchers via `$ARGUMENTS` env-var bridge.
- **16 reference sub-docs** under `skills/<name>/references/` providing worked examples + edge cases + extensibility notes.
- **7 behavior eval docs** under `evals/` covering the 7 skills (Phase 0 — Agent-dispatch harness per [feedback_claude_code_sessions_only]).
- **R1 — Phase → Sprint → Vertical Slice hierarchy** via new `/plan-roadmap` slash command + `planning-project-roadmap` skill. Outputs `ROADMAP.md` (NEW; does NOT collide with v0.1.0's `PROJECT_PLAN.md` which is preserved unchanged). State at `${CLAUDE_PLUGIN_DATA}/project-roadmap.json` with schema versioning + mutations array. 5 re-run modes. Size-class adaptation: >50 nodes triggers continue/split/reduce prompt; >100 biases toward split. Time-budget: 60-min advisory + 90-min warn-only.
- **R2 — machine-checkable rules DSL** via `authoring-machine-checkable-rules` skill + `lib/rules.sh`. HTML-sentinel format. 4 v0.2 types: `banned_imports`, `coverage_floor`, `style_invariants`, `required_pattern`. Extensibility: unknown types warn-and-skip per SPEC §8.5. Rules live in `.claude/memory-bank/03-code-patterns.md` `## Machine-checkable rules` section.
- **R3 — `auto:`/`user:` demo criteria grammar** per scaffold-dev SPEC §14.1 via `authoring-vertical-slice-demo` skill + `lib/demo-criteria.sh`. Literal U+2192 (→) arrow. Dual storage target (state-file during R1.C; markdown post-R1.C). Idempotent append.
- **Manifest-aware output routing** per SPEC §10 via new `lib/routing.sh`. `sf_resolve_output_path` resolves to ai_workspace or canonical per workspace-init's pairing.json `routing.*` table. Cross-plugin sourcing of `mi_manifest_resolve` with local fallback. Single-repo fallback preserved.
- **Tier 0 marker protocol** for hook coordination with scaffold-dev (SPEC §11). Marker at `${TMPDIR}/claude-code-tier0-${CLAUDE_SESSION_ID}` — first-write-wins. Measured ~2.5ms typical (50ms budget).
- **`/plan-roadmap` slash command** + updated `/onboard`, `/scaffold-project`, `/scaffold-docs` wired to Skills via `$ARGUMENTS` bridge.
- **Karpathy behavioral discipline section** opt-in for CLAUDE.md (SPEC §14): 4 principles, verbatim attribution `Behavioral guidelines inspired by Karpathy's observations (Chang, 2026; MIT)`. Gated by `state.answers["phase_10.4.include_karpathy"]`.
- **lib/roadmap.sh, lib/rules.sh, lib/demo-criteria.sh, lib/routing.sh** — 4 new lib modules supporting R1/R2/R3 + routing.
- **5 new test suites** — `test-roadmap.sh` (34), `test-rules.sh` (30), `test-demo-criteria.sh` (27), `test-manifest-routing.sh` (14), `test-hook-marker.sh` (12).
- **229 net new tests across 12 suites** (392 total).

### Changed
- **`lib/compose.sh` refactor** — architect-critic detection moves from composition.json to filesystem probe per SPEC §12.2. composition.json no longer carries `plugins.architect-critic` entry; ai-mentor + superpowers probe behavior preserved. Detection is BINARY (v0.2-present-or-absent) — no v0.1.3 fallback.
- **`hooks-handlers/session-start.sh`** — extended with marker-aware Tier 0 protocol (preserves all v0.1.0 source-aware refresh logic).
- **`templates/memory-bank/03-code-patterns.md.tmpl`** — adds `## Machine-checkable rules` section heading seeded empty (R2 contract).
- **Slash commands** wrapped to invoke skills via `Skill(scaffold-onboard:<name>)` instead of inlining bash. Args via `$ARGUMENTS` env-var bridge.

### Removed (BREAKING — IPC contract)
- **`sf_compose_build_critic_request`** function from `lib/compose.sh` (was lines 257-339 in v0.1.0).
- **`sf_compose_read_critic_response`** function from `lib/compose.sh` (was lines 344-363 in v0.1.0).
- **inbox/outbox** file-IPC paths under `${CLAUDE_PLUGIN_DATA}/architect-critic/` no longer created or used.
- **15 IPC tests** from `test-compose.sh` (v0.1.0: 31 → v0.2: 24; -7 net in this suite, +8 new for filesystem-probe critic detection + skill-marker assertions).
- Migration: architect-critic v0.1.x users see "absent" warning at critic moments after upgrading scaffold-onboard. Install architect-critic v0.2+ to restore adversarial review (paired-release contract per SPEC §12.4).

### Composition
- **architect-critic v0.2+** — invoked via `Skill(architect-critic:critiquing-spec)` at Phase 5, Phase 7, MASTER-SPEC close, and `/plan-roadmap` close. Filesystem-probe detection (no shared registry per ac v0.2 settlement #1).
- **ai-mentor v2.0+** — invocation surface updated.
- **workspace-init** — manifest consumed for routing; forward-compatible with v0.1 manifests missing `roadmap` routing key (defaults to canonical).

### Contract (scaffold-dev v0.1 consumer)
- **R1** — ROADMAP.md hierarchy parseable per SPEC §7.1 + scaffold-dev §16.2
- **R2** — rules consumable by `implementation-checking` skill per SPEC §8.4
- **R3** — criteria parseable by `closing-vertical-slice` skill per SPEC §9.3

## [0.1.0] — 2026-05-14

### Added
- Plugin scaffold (Phase A) — manifest, LICENSE, README, CHANGELOG, command stubs, hook + lib skeletons, test helpers.
- lib/state.sh, lib/parser.sh, lib/render.sh (Phase B) — state CRUD with atomic writes + lock file, MASTER-SPEC.md parser with three primitives + 7 validation rules, template substitution with `{{key}}` + `{{#if}}` blocks.
- phases.yaml (10 phases, ~54 questions, branching gates), MASTER-SPEC + EXECUTIVE-SUMMARY templates, /onboard command with conversational protocol body, state advance + gate evaluation + mode detection + phases.yaml reader (Phase C).
- 11 memory-bank templates (00–08, index, WORKFLOW), CLAUDE.md template (Tier 0 + branch routing + plugin awareness), .claude/settings.json template, lib/memory-bank.sh with derive + CLAUDE.md generation + live-file preservation + --force, /scaffold-project command (Phase D).
- 14 governance doc templates (5 default + 9 --full, 3 LLM-project-gated), lib/docs.sh with default + --full derivation + --regenerate override, /scaffold-docs command (Phase E).
- lib/compose.sh with probe-path detection for ai-mentor / architect-critic / superpowers, composition.json caching with user-override toggles preserved across refresh, sf_compose_set_override input-validated setter, SessionStart hook (source-aware: refresh on startup/clear, preserve on resume/compact), mentor + brainstorming hint emitters keyed to Phase 5/7, architect-critic file-based handshake per SPEC §8.3 (request envelope build + response reader with polling timeout) (Phase F).
- End-to-end coverage on fresh + existing repos, resume after interruption, and cross-cutting composition mocked (Phase G TG.1–TG.4); README polish with Install + Quick start + Commands table (TG.5); hardening (TG.6): jq-then-mv writes guarded against partial failure, critic request_id seeded with PID+RANDOM entropy to prevent same-second collisions, file-lock protection on composition.json writes via sf_compose_lock_acquire/release with polling timeout.
- 163 tests across 7 bash test suites (state 23, parser 13, render 10, memory-bank 22, docs 23, compose 31, e2e 41).

### Composition
- Composes with `ai-mentor`, `architect-critic`, `superpowers`. Works standalone if any are absent.
