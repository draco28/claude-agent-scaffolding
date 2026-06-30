# Changelog

All notable changes to scaffold-dev documented here. Follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) 1.1.0.

## [0.14.0] — 2026-06-27

SS-9 — #92: expose the pre-merge gate as a standalone, slice-decoupled `/work-pr` command. **Closes #92.**

### Added
- **#92 — `/work-pr <PR>` + `working-pull-request` skill.** A standalone command that drives an arbitrary PR through the full review-fix-merge loop — fetch findings (`sd pr_state` + `sd pr_review_comments`), disposition each (P1 must-fix / non-blocking fix-or-defer), drive the fixes, re-review on the new head, defer the leftovers, and merge only on explicit ack. The invoking agent (Claude Code **or** Codex) runs the whole loop itself — no cross-agent hand-off; provider-agnostic. **Skill-driven, no determinism in the loop.** It reuses the single source of truth for the disposition contract (`planning-vertical-slice/references/git-workflow.md` §"Agent-driven pre-merge gate") rather than forking a second copy — the same gate `closing-vertical-slice` §10a and `writing-sprint-retrospective` §8a run at slice/sprint close. Design-of-record: `docs/agent-driven-program/specs/SS-9-work-pr.md`.
- **#92 — `--repo-root DIR` on the PR helpers.** `sd_pr_state` / `sd_pr_review_comments` / `sd_pr_merge` / `sd_remote_check` now accept an optional `--repo-root DIR` target (extracted to the shared `_sd_repo_target` parser, which `sd_issue_create` / `sd_issue_list` are retrofitted onto). This is what lets `/work-pr` run **manifest-free** on the current git repo — no workspace-init pairing required. 9 new tests (`tests/test-pr.sh`).

### Notes
- **Manifest-free by design.** Unlike every other scaffold-dev skill, `working-pull-request` does NOT call `manifest_require` — it resolves the target repo from `git rev-parse --show-toplevel` (or `--repo-root`), so it works on any gh repo (e.g. the scaffolding repo itself, where PR #91 lived). Slice/sprint-close PR paths are unchanged: with no `--repo-root` the helpers fall back to `.canonical.root` exactly as before (byte-compatible).
- **Deferred:** remote `--repo owner/repo` (gh `-R`) targeting — current-repo / `--repo-root DIR` covers the motivating cases without touching the test gh-shim.

## [0.13.0] — 2026-06-25

SS-6 — #79: recognize the count-aware `ran ≥N` demo form at slice-close.

### Added
- **`ran ≥N` recognized as a judged content form (#79).** `closing-vertical-slice` §5 now lists `ran ≥N` among the agent-judged content expectations (alongside `count > 0`, `> 5 rows`, free-form prose): the orchestrator reads the captured runner summary plus the exit signal (`result_stdout` + `result_exit`) and judges whether **the run passed AND at least N tests executed**, recording a one-line reason — **no deterministic count parser** (agent-review-over-deterministic-gates). The `AND passed` half is load-bearing: `ran ≥N` never trades the pass/fail check away for the count check (a `3 examples, 1 failure` run fails even though ≥3 ran). It is the opt-in count guard for runners outside the `exit 0` zero-test allowlist (`sd_zero_tests_guard`, #74), which stays the zero-config default. Authored via scaffold-onboard's `authoring-vertical-slice-demo` (v0.10.0). Design-of-record: `docs/SPEC-slice-demo-agent-eval.md`.

### Notes
- **Work-item ACs are unchanged.** The per-work-item `implementation-checking` gate stays the deterministic `exit 0` / `exit N` / `output contains` mechanical check — `ran ≥N` is a **slice-demo-only** form (agent-judged at close), preserving the deliberate v0.1.7 work-item minimalism (`docs/SPEC-slice-demo-agent-eval.md`).

## [0.12.0] — 2026-06-21

SS-6 — #82: complete the multi-reviewer pre-merge gate. **Closes #82.**

### Added
- **#82 — finding-disposition loop.** The agent-driven pre-merge gate in `planning-vertical-slice/references/git-workflow.md` is now the single source for the per-PR resolution rule: every reviewer finding is fixed or recorded before merge; P1/blocking findings must be fixed first; non-blocking findings accepted at merge become tracked deferrals rather than silent passes.
- **#82 — reviewer-completeness.** The gate now says a green check is not proof a reviewer ran: the agent reads `sd pr_state` (`statusCheckRollup`, reviews, comments, commits) plus `sd pr_review_comments`, then judges the actual review/comment signal. Skipped reviewers are not approvals, queued/in-progress reviewers are waited for, stale verdicts after a fix require re-review on the new head, and the CodeRabbit non-default-base skip is kept as a brief default-config example while sprint→main remains the normal default-base reviewed path.
- **#82 — anti-rot seam-lint.** `tests/test-review-gate.sh` gains `test_seam_premerge_gate_contract`, pinning the simplified gate clauses against `git-workflow.md` with a small set of load-bearing assertions.

### Notes
- **Prose-only enhancement — no new `sd` helper.** Baking semantic reviewer detection into bash was rejected per the agent-review-over-deterministic-gates principle: `git-workflow.md` keeps deterministic checks only for mechanical git/`gh` facts. The `closing-vertical-slice` and `writing-sprint-retrospective` call sites now point back to that single source instead of restating the gate.

## [0.11.0] — 2026-06-20

SS-6 — Batch A (#76 + #77): scaffold-dev vertical-slice pass. **Closes #76 and #77.**

### Added
- **#76 — slice-start baseline for direct-mode review bundles.** New `lib/slice_meta.sh` with `sd_slice_baseline_write` / `sd_slice_baseline_read`: an append-once JSON block between `<!-- sd:baseline:start/end -->` sentinels in the VS README (mirrors the `lib/state.sh` cursor). `planning-vertical-slice` §8.1 records the canonical default-branch HEAD at slice start; `closing-vertical-slice` §7.2a reads it as the review-bundle `--diff-base` in `direct` mode so the async architect-critic audit gets a real `<recorded-base>..HEAD` diff (previously empty + omitted, since the slice is already merged into the default branch by close). Falls back to the mode base when no baseline was recorded (pre-#76 slices) or under `pr_hierarchical`. `sd_review_gate_bundle` itself is unchanged. 7 new tests (`tests/test-slice-meta.sh`).
- **#77 — 500-line SKILL.md cap guard.** New `tests/test-skill-line-cap.sh` asserts every `scaffold-dev/skills/*/SKILL.md` body is ≤ 500 lines (the self-declared cap, superpowers:writing-skills Pass D).

### Changed
- **#77 — `closing-vertical-slice` (660 → 490) and `planning-vertical-slice` (729 → 489) brought under the 500-line cap.** Reference-grade prose extracted to `references/*.md` (harvest mechanics, sprint-close cleanup, pr_hierarchical pre-flight + close, backend dispatch, AC-authoring grammar, orchestrate arg-parser); operative steps + seams + load-bearing tokens stay in the body. The §7 review-gate prose is unchanged (seam-pinned by `tests/test-review-gate.sh`). Added the previously-missing 500-line cap anti-pattern to `planning-vertical-slice` §14.

## [0.10.0] — 2026-06-20

SS-6 — #48 Stage 2: lean-index **marketplace routing** (`/defer --tooling`) + `tech-debt` label auto-create. **Closes #48** (Stage 1 = Parts C/D/E in v0.9.0; Part F shipped in v0.4.0).

### Added
- **#48 Stage 2 — `/defer --tooling` marketplace routing.** `deferring-work-item` parses `--tooling` from `$SCAFFOLD_DEV_ARGS`; when set it resolves the tooling repo via `sd manifest_get '.tooling_repo.root'` and routes the deferral there instead of canonical — degrading with an actionable error (*"no tooling_repo configured; re-run without --tooling …"*) when the field is absent, never silently mis-filing. `sd_issue_create` and `sd_issue_list` gain an optional `--repo-root <dir>` flag (parsed out here, **never forwarded to `gh`**); absent → canonical, byte-compatible with every pre-#48 caller. Consumes workspace-init v0.3.0's optional `tooling_repo` manifest field.
- **#48 Stage 2 — `sd_label_ensure <label> [repo-root]` (`lib/pr.sh`).** Idempotent `gh label create` run from the target repo (default canonical): rc 0 when the label exists or was just created (an "already exists" / "already been taken" rejection counts as success), rc 1 + actionable message on a real failure. `deferring-work-item` §4 now **offers** it when a repo lacks `tech-debt` — agent-driven and skippable; label setup never blocks recording the debt (the §4 A+B contract stands). The gh test-shim gains a `label create` case. 8 new tests (`tests/test-pr.sh`).

### Notes
- Design-of-record: `docs/SPEC-lean-index-CDEF.md` §3.5–§3.6. The repo-root parameter shape was chosen as a parsed `--repo-root` flag (not a positional arg) to keep `sd_issue_create`/`sd_issue_list`'s variadic `gh` passthrough byte-compatible (SPEC §7).

## [0.9.0] — 2026-06-20

SS-6 — #48 Stage 1 (Parts C/D/E): lean-index **deep-reference channels** — memory entries cite lean pointers (`DOC §anchor`, `ADR-NNNN`, claude-mem) and a slice-close check confirms they still resolve. (Part F shipped earlier in v0.4.0; this stage covers the deferred pointer channels.)

### Added
- **#48 C/D — doc-anchor + ADR-id citation resolution legs (`lib/citations.sh`).** Two new mechanical legs extend the `verifying-spec-citations` mechanical/agent split to lean-index memory pointers. `sd_citations_check_anchor <doc-file> <anchor>` returns 0 iff a Markdown heading in the doc resolves the anchor — **heading-only**, with boundary-aware structured tokens (`5.2`, `FR-5`, `NFR-10`), literal title-fragment matches, optional matching quote stripping, and empty-anchor rejection. `sd_citations_check_adr <adr-id> <adr-dir>...` returns 0 iff any supplied dir holds `adr-<NNNN>-*.md` or scaffold-onboard's seeded `<NNNN>-*.md` form for the id's number (zero-pad-tolerant: `ADR-3` → `adr-0003` / `0003`); **manifest-free** so the caller passes the product + process ADR dirs (independent series → both). Semantic drift — whether the cited target still *denotes* what the entry claims — stays the agent's leg; the mechanical legs only confirm the heading/ADR exists. 17 new tests (`tests/test-citations.sh`, 22 total, 26 assertions).
- **#48 C/D/E — write-time pointer enforcement in `closing-vertical-slice` §9.4.** The lean-index harvest nudge now names the pointer conventions, **resolution-checks** a surfaced/harvested pointer via the new legs (so the bank never stores a dangling reference), and adds a **presence-gated** claude-mem topic-pointer channel (Part E — skipped when claude-mem is absent, never authoring a dead pointer). `verifying-spec-citations` §6.2/§11 document the new legs (the ARCH §-ref existence probe can now be mechanized). New eval scenario S7.

### Notes
- Design-of-record: `docs/SPEC-lean-index-CDEF.md` (§3.3). Part F (#48-F) shipped in v0.4.0 as the agent-judged harvest check + `sd_harvest_lint_length` — **no deterministic mcrule** (the agent-review-over-deterministic-gates principle). Marketplace routing + `tech-debt` label auto-create are Stage 2.
- README version table corrected from a pre-existing drift (the scaffold-dev / scaffold-onboard rows lagged ~6 minor versions behind `plugin.json`).

## [0.8.1] — 2026-06-20

SS-6 — #74: close the `auto:` AC `exit 0` vacuous-pass hole (TDD false-green).

### Fixed
- **#74 — `auto:` `exit 0` no longer passes vacuously when a recognized test runner collected zero tests.** A test-runner filter that matches nothing exits 0 (e.g. `cargo test mymod::feature` → `0 passed; N filtered out`, or `pytest -k nomatch` → `no tests ran`), so an `exit 0` acceptance-criterion could demo-verify **green having run no test**. New pure helper `lib/verify.sh::sd_zero_tests_guard <cmd> <output>` (no command execution — inspects already-captured output, fully unit-tested) now fails the AC when a recognized runner (pytest / go test / cargo test / cargo nextest / jest / vitest / node --test) exited 0 having collected zero tests. Wired into all three execution sites: `sd_verify_auto_step` (`exit 0` branch), `implementation-checking` §6 gate, and `closing-vertical-slice` §5 auto-demo (exit-code leg). Scoped to `exit 0` (negative-test `exit N` ACs are exempt). **Allowlist-only + fail-soft:** an unrecognized runner or wrapper script is unaffected (no regression), and the guard requires the runner's *passed/ran count to be zero* — `5 passed; 204 filtered out` and mixed multi-binary/multi-package runs do **not** fire. `authoring-vertical-slice-demo`'s `auto-grammar.md` §2.1 documents the guard so the "deterministic mechanical fact" claim stays accurate (doc-only; no scaffold-onboard version change).

### Notes
- The allowlist is heuristic and best-effort against common runner output; markers may drift across runner versions (drift degrades to a miss, never a false fire). An explicit count-aware `auto:` form (`expected: ran ≥N`) for runners outside the allowlist / wrapper scripts is deferred to a follow-up enhancement (#79, issue #74 Option A).

## [0.8.0] — 2026-06-18

SS-6 — #39 Phase B: opt-in **architect-critic review gate** at slice/spec close, consuming the architect-critic v0.3 async API shipped in Phase A. Default `off` preserves today's behavior exactly.

### Added
- **#39 Phase B — `review_gate` config (`off | slice_close | spec_close | both`, default `off`).** New `lib/review_gate.sh` `sd_review_gate_resolve` (mirrors `sd_backend_resolve`): per-invocation `--gate` override > manifest `.review_gate` > `off`; set-e-safe manifest read; rc1 on an invalid value, rc2 on bad usage. Absent field / absent manifest → `off`, so existing projects are unchanged and no workspace-init schema change is required. Unit-tested in `tests/test-review-gate.sh`.
- **#39 Phase B — async dispatch-and-defer at the two §7 gates.** When the gate is on for an attach point and architect-critic v0.3 is present, `closing-vertical-slice` §7 (slice close) and `planning-vertical-slice` §7 (spec author) dispatch the close-depth architect-critic audit as a background job via `Skill(architect-critic:critiquing-spec)` with `async=true`, record the job handle (retrospective/README), surface the `/critique-jobs resume <id>` hint, and **proceed without blocking** the ceremony. No in-ceremony polling; the operator resumes on their own schedule to fold both adversaries into one rebuttal. A usage-consumption warning is surfaced before dispatch.
- **Capability-aware `sd_compose_detect_architect_critic`.** Now reports `v0.3` (async-capable — `managing-async-critique` present), `v0.2` (sync-only), or `absent`, scanning all cache dirs before deciding.

### Changed
- **`spec_close`/`both` upgrades the spec-author audit from author-depth to close-depth.** Async exists only at close depth, so the gate at the spec moment runs a heavier close-depth Codex adversary audit (the extra rigor the gate buys); the lighter author-depth Claude-self-audit remains the default when the gate is off.
- **Graceful degradation.** Gate on but architect-critic is `v0.2` (no async API) → one warning + fall through to the existing **synchronous** close-depth review (the operator still gets a review). Gate on + `absent` → existing warn-and-proceed. Gate `off` / wrong attach point → today's behavior, untouched.
- **Dual-publish constraint (inherited):** async execution is Claude-host → Codex-adversary only (the architect-critic v0.3 constraint); the gate's skill prose ships on both surfaces.

### Fixed
- **Stale README.** `Status` corrected from v0.1.0 → v0.8.0; the skills list (was "9 skills") and commands table now reflect the real 12 skills / 6 commands; added a Configuration section documenting `review_gate`.

## [0.7.0] — 2026-06-15

SS-6 cleanup batch — ADR `proposed-then-flip` lifecycle (#6) + `git stash` ban in operator-facing templates (#8).

### Added
- **#6 — `flipping-adr-status` skill + `/flip-adr` command.** The second half of the ADR `proposed-then-flip` lifecycle: resolves an ADR by number (across the manifest-routed product/process dirs) or absolute path, gates on it currently being `Status: Proposed`, prompts for an empirical signal, then makes a *targeted* edit — flips `- Status: Proposed` → `- Status: Accepted` and appends an `## Empirical validation` section (operator signal + date). Refuses an already-`Accepted` ADR (one-way) and disambiguates a number that matches both series. Agent-driven (Edit tool), eval-tested (`evals/flipping-adr-status.md`, 3 scenarios).

### Changed
- **#6 — `recording-architecture-decision` offers a status protocol at authoring time (§9.1).** `accepted-on-author` (default, current behavior → `Status: Accepted`) or `proposed-then-flip` (→ `Status: Proposed`, for an ADR companioning a build slice that later flips via `/flip-adr` once an empirical signal lands). `evals/recording-architecture-decision.md` gains S4 covering the proposed-then-flip path (now 4 scenarios).
- **#8 — operator-facing templates ban `git stash` for baseline isolation.** `templates/implementation-handoff.md.tmpl` (§10 hard constraints), `templates/handoff.md.tmpl` (§9 anti-actions), and `templates/work-item-spec.md.tmpl` (§9) now carry a banned-commands block: `git stash` / `git stash pop` / `git stash apply` collide with the operator's pre-existing stash stack and can be unrecoverable — use a reversible file move to a temp dir instead. (Cited incident: a slice-14 impl-handoff directed `git stash`, pushing an unrecoverable entry onto unrelated older stash entries.)

## [0.6.0] — 2026-06-15

SS-6 — `closing-vertical-slice` now reconciles `05-active-context.md` at slice close (#66). The close ceremony previously had zero writes to the live active-context file, so after a correct slice close "Current focus" still presented the just-closed slice as in-flight and "Next up" lagged (observed two slices stale in a real project) — a fresh `/orchestrate` or `/handoff` session read wrong state. The new §12 reconcile flips the closed slice's status and advances the cursor as a surfaced, user-confirmed targeted edit.

### Fixed
- **#66 — `closing-vertical-slice` leaves `05-active-context.md` stale at close.** Added a §12 close-time reconcile step (all-pass path, after harvest + cleanup, before the final handoff): it surfaces a *targeted* edit flipping the closed slice's `## Current focus` status from IN FLIGHT to CLOSED + merge ref (round log retained verbatim) and advancing `## Next up` to the **field-read** next roadmap slice — or, on the sprint-final slice, to the sprint-close → next-sprint pointer. Prose-only and user-confirmed: never regenerates the file, never touches the structured cursor block (`<!-- sd:cursor:start -->…<!-- sd:cursor:end -->`, still owned by `planning-vertical-slice`), and never writes a spec-derived file.

### Added
- **`lib/roadmap.sh` — `sd_roadmap_next_slice` + `sd_roadmap_next_sprint`.** `sd_roadmap_next_slice <id>` field-reads the next vertical slice in the same sprint (smallest 3rd-id-index greater than the current slice; `sort_by` keeps it robust to roadmap array order), echoing empty when the slice is the sprint's final one. `sd_roadmap_next_sprint <sprint-id>` is an array-order lookup over `sprints[]` (dotted ids, no integer `+1`). Both fail loud (rc 1) on no manifest / unpublished state. Unit-tested in `tests/test-roadmap.sh`.

### Changed
- **`closing-vertical-slice` §11.1 final-slice detection now reuses `sd roadmap_next_slice` / `sd roadmap_next_sprint`** instead of an inline jq count — single source of truth shared with the new §12 reconcile (the issue's "reuse the same query §11.1 uses" is now literal, not copy-pasted). Behavior of the §11.2 carry-forward sweep is unchanged.
- **`evals/closing-vertical-slice.md`** gains S6 (close-time active-context reconcile: field-read Next-up, prose-only status flip, round-log + cursor-block preservation); the full eval is now GREEN at 6 scenarios.

## [0.5.0] — 2026-06-12

SS-5 — optional Codex implementer backend (#47). A work item can now be dispatched to OpenAI's externally-installed `codex-plugin-cc` companion instead of the Claude `implementer-agent` subagent, under the same `{mode,…}` contract, gaps-mode escalation, and no-commit boundary. Default stays `claude_subagent` — existing projects are unchanged.

### Added
- **`lib/codex.sh` — mechanical adapter for the Codex backend.** `sd_codex_resolve_companion` (locate the installed `codex-companion.mjs`, newest version, with `SCAFFOLD_CODEX_COMPANION` override; fail-loud + remediation), `sd_codex_preflight` (hard gate: `setup --json` availability/auth + worktree-trust path-prefix check; no silent fallback), `sd_codex_dispatch` (`task --background --write --prompt-file`, optional `--resume-last`/`--resume`/`--fresh`, guarded `--model`/`--effort` values), `sd_codex_wait` (background poll + stall heuristic + wall-cap → `completed|failed|cancelled|stalled|capped|error`; normalizes legacy `done` to `completed`; cancels a stalled/capped job; validates wait options), `sd_codex_result` (extract the fenced `{mode,…}` JSON Codex emits), `sd_codex_verify_nocommit` (assert Codex did not commit; ignore only the legacy root `.codex-prompt.md` artifact when judging dirty state). All helpers are `set -e`-safe and tested through `bin/sd`.
- **`lib/backend.sh` — `sd_backend_resolve`.** Resolves the backend with precedence per-invocation override > manifest `.implementer_backend` > `claude_subagent`. Read-with-default (no workspace-init schema change); invalid values and missing `--backend` values fail loud.
- **`tests/test-codex.sh` + `tests/test-backend.sh` + `tests/fixtures/codex-shim/`.** Dispatcher-path coverage of every helper against an env-driven mock companion (no real Codex / no network), including the `set -e` regression guard on the `wait` poll loop.

### Changed
- **`planning-vertical-slice` §8.3 — backend-selector dispatch.** Resolves the backend first; `claude_subagent` (§8.3a) keeps the existing `Task(subagent_type="scaffold-dev:implementer-agent")` path; `codex` (§8.3b) runs preflight → external temp prompt-file assembly (contract prompt-carried, removed after dispatch) → dispatch → background wait → result → no-commit verify, then joins the existing downstream unchanged. Replaces the prior proto-typed "Codex worker subagent" prose. Codex work items dispatch sequentially within a round, and gaps-mode re-dispatches with `--resume-last`.

## [0.4.0] — 2026-06-12

SS-4 — agent-review of verification seams; single-authority harvest; spec-citations gate; RED-tests pre-flight; lean-index length leg (#52, #7, #5, #48 Part F).

### Removed
- **#52 — orphaned semantic harvest parsers `sd_harvest_reports`, `sd_harvest_handoffs`, and `_sd_harvest_extract_section` deleted from `lib/harvest.sh`.** These AWK/grep-based extractors attempted to machine-parse free-form report/handoff prose and silently dropped content that didn't match their patterns — a grammar-collision with the agent's own reading of the same prose. The agent is now the sole reader of free-form `report.md` / handoff "Suggestions for memory bank" prose; `sd_harvest_apply` remains the single mechanical write authority (provenance trailer, idempotency, derived-reroute). The `report.md` "Suggestions for memory bank" section is documented as agent-read, not machine-parsed.

### Changed
- **#52 — `closing-vertical-slice` §9 harvest is now agent-sole-reader of free-form report/handoff prose.** `sd_harvest_apply` is the single mechanical write authority: it enforces the provenance trailer, idempotency guard, and derived-file reroute. The "Suggestions for memory bank" section in `report.md` is documented as agent-read input, not a machine-parseable structured field.

### Added
- **#48 Part F — `sd_harvest_lint_length` lean-index length leg + harvest §9.4 restate-prevention check.** The linter now flags memory-bank entries that exceed the length ceiling. The §9.4 check prevents re-stating content already present in the target file (anti-bloat gate).
- **#7 — `verifying-spec-citations` skill + `lib/citations.sh` (`sd_citations_check_file`, `sd_citations_check_signature`).** Opt-in spec-citations gate added to `planning-vertical-slice` §6.4: the agent verifies that spec section references cite real, reachable anchors in the target spec file before the slice plan is finalised. Dissolved the original "agent-assisted" framing — the agent drives the check end-to-end.
- **#5 — `executing-work-item` §3.6 pre-flight RED-tests gate ("not-already-GREEN" semantics) + `sd_redgate_assert_red` helper + `--allow-skip-thrust-zero` skip-escape.** Tests that are meant to turn green during implementation must be confirmed RED (or missing) before work begins; the gate hard-fails if a target test is already green, preventing phantom "passes". The `--allow-skip-thrust-zero` flag only proceeds after an orchestrator-recorded clarification confirms the already-GREEN AC is legitimate (e.g. a pure code-deletion AC).

## [0.3.0] — 2026-06-02

SS-1 — slice-close harvest aligns with memory-bank ownership (part of #45; cross-plugin with scaffold-onboard 0.4.0).

### Changed
- **Slice-close harvest no longer writes into spec-derived memory-bank files.** `sd_harvest_apply` now refuses any spec-derived target (`00,01,02,03,04,07,08,index`) and **reroutes** it to the dev-authored catch-all `09-known-issues.md` with a warning — harvested prose appended into a derived file would be clobbered on the next `/scaffold-project` (the root of #45). `closing-vertical-slice` §9.4 + the harvest worked-example now route caveats/stack notes → `09-known-issues.md`, decisions/advisory patterns → `10-decisions-log.md`, and enforceable patterns → `authoring-machine-checkable-rules` (03's preserved rules zone); the phantom `06-product-context.md` target is removed.
- Every cadence mention across scaffold-dev skills (`executing-work-item`, `deferring-work-item`, `writing-sprint-retrospective`, `closing-vertical-slice`) now points to the single canonical policy (`memory-bank/WORKFLOW.md` → **Memory-bank update cadence**) instead of restating it; sprint-close is documented as the settled write-nothing policy rather than a deferred open question.

## [0.1.7] — 2026-05-31

### Fixed
- **#35 — invalid YAML frontmatter made Codex skip four skills.** The `description:` frontmatter on `implementation-checking`, `appending-changelog-entry`, `authoring-runbook`, and `executing-work-item` contained unquoted `: ` (colon-space) sequences (`Read-only:`, `changelog: <entry>`, `six sections:`, `Dual-use:`) that Codex's Psych loader parsed as a nested mapping → `Psych::SyntaxError`, so the four skills were silently dropped on load. Each value is now single-quoted (trigger phrases preserved byte-for-byte). The dual-publish suite (`tests/test-codex-dual-publish.sh`) now parses every published `SKILL.md` frontmatter with Ruby Psych and fails on any future unquoted-`: ` regression.
- **#36 — per-work-item gate silently false-greened on normally-authored specs.** `implementation-checking` §4 parses `auto:` acceptance-criteria lines from a work-item spec's section 6, but `work-item-spec.md.tmpl` §6 rendered a markdown table (`{{acs_table}}`) the parser could not read — so a real spec yielded zero ACs and the gate fell through with nothing verified. §6 now renders machine-checkable `auto:`/`user:` lines (`{{acs_block}}`) as the **single AC source of truth** (the parallel table var is removed — it was the drift vector); `planning-vertical-slice` authors that block; and the gate **degrades loudly** (`[AC]` advisory + a ≥3-option menu, never a green) when zero `auto:` ACs are found. The authored line grammar is `- [ ] AC-1 auto: \`<command>\` → expected: <exit 0 | exit N | output contains <text>>` — the command is backtick-wrapped (so `lib/verify.sh::sd_verify_auto_step` can extract and run it), carries a real numbered `AC-1`/`AC-2`/… label (so `sd_verify_report_cross_check` engages instead of silently skipping, and template boilerplate avoids the literal `AC-N` that would grep as a phantom id), and uses the `output contains` substring **unquoted** (it is matched literally via `grep -F`). New render-contract test (`scaffold-dev/tests/test-render.sh`) asserts the concrete rendered command + that `{{acs_block}}`/`{{acs_table}}` placeholders resolved (false-green-proof), and eval scenario S5 covers the zero-AC loud-degrade path (the prior evals hand-authored `auto:` fixtures the real template never produced, which is why the bug escaped the suite). The grammar is now consistent across all consumers: the orchestrator/template author it, the gate **runs each `auto:` command in the worktree** (`cd "$worktree" && eval`), the `executing-work-item` implementer reads/writes the same grammar, and `user:` rows carry **no** `AC-N` — they're slice-close demo steps, and `sd_verify_report_cross_check` excludes them so a manual AC can't wrongly fail the report cross-check.
- **#43 — `implementation-checking` §6 documented an `sd_verify_auto_step` contract that didn't match `lib/verify.sh`.** §6 called the helper with 3 args `(command, expectation, worktree)` and claimed it `cd`s into the worktree and emits a `STATUS=…` line, but the helper takes a single full `auto:` line, extracts the command from the backticks, and runs in the current directory — so following §6 literally rejected every AC as `no command found`. §6 now runs commands directly in the worktree (matching `executing-work-item` §5's discipline) and documents `sd_verify_auto_step` accurately as the line-level utility the tests exercise. The report cross-check collects AC ids only from declared AC rows (not prose/boilerplate) and excludes `user:` rows.

## [0.1.6] — 2026-05-30

### Fixed
- **#28 Phase 3 — consume the 3-part slice id by field-read instead of heading-grep (cross-plugin contract fix).** scaffold-onboard authors 3-part slice ids (`VS-<phase>.<sprint>.<slice>`, e.g. `VS-1.1.1`) with an explicit `sprint_id` (`1.1`), but scaffold-dev located slices by grepping a `#### VS-…:` heading in `ROADMAP.md` and recovered the sprint by string-splitting the id's **first** field — so `VS-1.1.1` mis-derived `sprint-1` instead of the real `sprint-1.1` (and `closing-vertical-slice` did the same via an `awk -F'[.:]'` over a `#### VS-${sprint_n}\.…:` grep). scaffold-dev now **field-reads** the slice from the structured `project-roadmap.json` that scaffold-onboard publishes (manifest `well_known_paths.roadmap_state`): it matches `id` exactly and reads `sprint_id` as a field — no id parsing — so every path/branch sprint segment (`sprint-<sprint_id>`) is correct. This also resolves the pre-existing bug where `planning-vertical-slice` read `.routing.roadmap` (a repo *selector* like `"canonical"`) as if it were a filesystem path.

### Added
- **`lib/roadmap.sh`** — `sd_roadmap_state_path` (resolve the published `project-roadmap.json` via `well_known_paths.roadmap_state`, with a forward-compat fallback to `${ai_workspace.root}/.workspace/project-roadmap.json` and an unresolved-placeholder guard), `sd_roadmap_slice_json` (exact-`id` lookup, fails listing available ids), `sd_roadmap_slice_field`, and `sd_roadmap_slice_sprint_id`. New `tests/test-roadmap.sh` (10 assertions).

### Changed
- **`lib/worktree.sh`** — `_sd_worktree_branch_name` / `sd_worktree_add` take an explicit `sprint_id` (the branch template's `{N}` sprint segment); when omitted it is derived from the 3-part id by dropping the slice segment (`VS-1.1.1` → `1.1`), never the bare first field. Worktree paths are also namespaced by sprint (`.worktrees/sprint-1.1/work-1.01-...`) so compact work ids can repeat across sprints without filesystem collisions.
- **`planning-vertical-slice` / `closing-vertical-slice` SKILLs** — rewritten to field-read `id` + `sprint_id` from `project-roadmap.json`; `slice_root` and the sprint-final detection key off `sprint_id`; work-item ids stay compact `<slice-index>.<nn>` (e.g. `1.01`, not the 4-dotted `1.1.1.01`).
- **Fixtures, test helpers, and `docs/SPEC-scaffold-dev.md`** migrated to the 3-part id / dotted `sprint_id` convention (complete migration per the architect-critic C4 finding): `sprint-fixture-minimal` gains a published `project-roadmap.json`; the shared test manifest declares `well_known_paths.roadmap_state`; `test-e2e`/`test-worktree`/`test-state`/`test-harvest`/`test-merge` updated; SPEC §4.4 + §5.2 specify the 3-part id + field-read contract.
- **PR #32 review — Codex/CodeRabbit (6 findings).** Codex caught that the field-read migration was incomplete — other consumers still string-split the id or assumed integer sprints. Now consistent: `implementation-checking` and `closing-vertical-slice` locate the (existing) slice/work-item dir by **glob** off the field-read `sprint_id` instead of reconstructing it from an undocumented `vs_kebab`/`sprint_n`; `handing-off-session` accepts dotted `sprint-1.1` scopes and 3-field `vs-1.1.1` slice scopes; `writing-sprint-retrospective` accepts the dotted `sprint_id` (the `sprint-${N}` dir + `VS-${N}.*` glob already cover both); `closing-vertical-slice` §11 sprint-close cleanup keys off `sprint_id` (no more integer `sprint_n`/`+1`); `commands/orchestrate.md` advertises the 3-part `VS-N.M.K` argument. CodeRabbit nits: unified `VS-N.M` → `VS-N.M.K` arity across the SPEC + trigger lists; corrected a sprint example mismatch and the stale §14 anti-pattern glob (`vs-${vs_id}-*` → `${vs_slug}-*`).

## [0.1.5] — 2026-05-29

### Fixed
- **Issue #24 — skill-description bloat.** The `description:` frontmatter on nine skills (handing-off-session, recording-architecture-decision, appending-changelog-entry, executing-work-item, authoring-runbook, writing-sprint-retrospective, closing-vertical-slice, implementation-checking, planning-vertical-slice) crammed the full behavioral contract into the description (handing-off-session at 1543 chars exceeded Claude Code's per-entry cap; others were dropped from the listing, disabling reliable auto-invocation, and inflated session token cost). Rewrote each to ~450–500 chars preserving all trigger phrases, slash-command tokens, and disambiguations (the detailed contract already lives in each SKILL body). No behavioral change.

## [0.1.4] — 2026-05-29

### Fixed
- **Issue #19 — `/handoff` flag parsing broken by slash-command `$N` substitution:** `commands/handoff.md` and the `handing-off-session` §10 example parsed flags with `case "$1"`, but Claude Code freezes bare `$1`/`$2`/`$N` at template-render time, so `--scope`/`--purpose`/`--return-of` came out empty — silently mis-authoring a **return** handoff as a forward and breaking the A→B→C chain. Flag parsing now lives in a shared, unit-tested helper `sd_handoff_parse_flags` (regex/`BASH_REMATCH`, immune to `$N`; accepts space- and `=`-delimited values; `--return` vs `--return-of` disambiguated by the separator). The command invokes it via the `sd` dispatcher; the §10 doc example shows the equivalent inline regex.

### Added
- `sd_handoff_parse_flags` in `lib/handoff.sh` + 5 regression tests in `tests/test-handoff.sh` (space form, `=` form, `--return-of`/`--return` disambiguation, empty args).

## [0.1.3] — 2026-05-28

### Added
- **Issue #14 — trace propagation:** scaffold-dev work-item specs and implementation handoffs now include ROADMAP traceability links for `FR-N`, `NFR-N`, and `BACKLOG-N` IDs.

### Changed
- The vertical-slice planning skill now extracts ROADMAP traceability blocks and carries the NFR success-bar context into downstream specs and handoffs.

## [0.1.2] — 2026-05-26

Shell-portability patch (v0.x.1 bundle). See `docs/HANDOFF-shell-portability-v0x1.md` in the marketplace repo.

### Fixed
- **Shell portability (zsh compatibility):** Claude Code's Bash tool runs zsh by default on macOS; skill bodies that `source lib/*.sh` then inherited zsh, where `${BASH_SOURCE[0]}` is unset and lib self-location crashed (`BASH_SOURCE[0]: parameter not set`). Added `bin/sd` dispatcher with `#!/usr/bin/env bash` shebang — kernel forces bash on direct execution regardless of caller shell. All 12 source-call sites across 9 skill bodies refactored to invoke `sd <fn-suffix>` instead of `source && fn` (`handing-off-session`, `writing-sprint-retrospective`, `recording-architecture-decision`, `appending-changelog-entry`, `authoring-runbook`, `implementation-checking`, `closing-vertical-slice`, `planning-vertical-slice`). Cross-plugin call into scaffold-onboard's `sf_rules_*` API (per SPEC §16.2) routes through the `sf` dispatcher. Skill bodies discover the plugin root via `SD_PLUGIN_ROOT="$(dirname "$(dirname "$(command -v sd)")")"` when they need to resolve a template path — works under zsh, does NOT depend on `$CLAUDE_PLUGIN_ROOT` which the host runtime doesn't export (anthropics/claude-code#48230). `sd --list` enumerates dispatchable functions. The dispatcher is auto-discoverable via `$PATH` (Claude Code adds each plugin's `bin/` to PATH automatically).

## [0.1.1] — 2026-05-25

Install-blocking schema fixes surfaced by first `/plugin install scaffold-dev` against live Claude Code. No behavioral changes.

### Fixed
- **`hooks/hooks.json` schema** — wrapped the `SessionStart` declaration in the required top-level `hooks: { ... }` object with the `matcher` + `hooks[]` + `type: "command"` shape that Claude Code's hooks loader actually validates. The v0.1.0 shorthand (`{"SessionStart": "hooks-handlers/session-start.sh"}`) was the PLAN-provided sketch, not the production schema; v0.1.0 install raised `Hook load failed: expected: "record", code: "invalid_type", path: ["hooks"]`. Matches `scaffold-onboard/hooks/hooks.json` shape verbatim.
- **Subagent registration format** — replaced `.claude-plugin/agents.json` (the PLAN-provided provisional shape) with `agents/implementer-agent.md` per Claude Code's actual per-agent markdown-with-frontmatter format. Frontmatter declares `name: implementer-agent` (Claude Code auto-prefixes the plugin name → `scaffold-dev:implementer-agent` at dispatch), `description:`, `tools: Bash, Read, Write, Edit, Glob, Grep` (Task omitted to forbid nesting), `model: inherit`. The body references the single-source-of-truth `skills/executing-work-item/SKILL.md` as the binding system prompt — keeps the dual-use SKILL.md authoritative.
- **`tests/test-subagent.sh`** — rewrote 6 assertions (subagent name, file existence, description field, tools allowlist, Task absence, body reference to skill) for the new `agents/implementer-agent.md` format. Other 8 assertions (return-mode JSON shapes, enums, clarification loop, malformed rejection) unchanged. 14 test functions / all PASS.

## [0.1.0] — 2026-05-25

Initial release. Sprint-driven orchestrator-implementer workflow for dual-repo workspaces. Replaces `scaffold` v1.0.0 (deprecated).

### Added
- **9 skills under `skills/<name>/SKILL.md`** (structural skill-first per SPEC §4): `planning-vertical-slice` (slice plan + spec from R1/R3), `executing-work-item` (TDD-loop implementer body invoked as subagent), `implementation-checking` (R2 mcrule enforcement + verify gates), `closing-vertical-slice` (R3 demo verification + report harvest + slice retrospective), `handing-off-session` (handoff escape valve writer at `.workspace/handoffs/`), `recording-architecture-decision` (ADR authoring), `appending-changelog-entry` (Keep-a-Changelog append), `authoring-runbook` (operational runbook authoring), `writing-sprint-retrospective` (sprint-close retrospective + slice harvest).
- **4 slash commands** wrapping the skills via `$ARGUMENTS` env-var bridge: `/orchestrate` (sprint-level driver), `/work-item` (single work-item dispatch), `/impl-check` (rule + gate verification), `/handoff` (session handoff writer).
- **1 subagent type** `scaffold-dev:implementer-agent` declared in `.claude-plugin/agents.json` — executes a single work item per a handoff doc; pre-flight gap check; TDD loop per AC; verify; author `report.md`; stage changes (no commit); returns structured JSON. Tools allowlist excludes `Task` (no nested dispatch). **Provisional schema** pending Claude Code subagent-type stabilization — shape may evolve in v0.2.
- **SessionStart hook with Tier 0 marker coordination** — first-write-wins marker at `${TMPDIR}/claude-code-tier0-${CLAUDE_SESSION_ID}` coordinates with scaffold-onboard's SessionStart so only one plugin emits the Tier 0 boot banner per session. ~2.5ms typical (50ms budget per SPEC §11).
- **Handoff escape valve** at `.workspace/handoffs/*.md` for session-boundary context preservation. Markdown handoff template (`templates/handoff.md.tmpl`) captures current state + next steps + unresolved questions; resumable across compaction/clear.
- **11 lib helpers** under `lib/`: `manifest.sh` (workspace-init manifest consumer), `state.sh` (sprint + slice state CRUD with atomic writes), `worktree.sh` (git worktree lifecycle for parallel slices), `merge.sh` (slice merge-back orchestration), `harvest.sh` (report.md collation into slice + sprint retrospectives), `verify.sh` (test + mcrule + demo-criteria gate runner), `rules.sh` (R2 mcrule evaluator — banned_imports, coverage_floor, style_invariants, required_pattern), `render.sh` (template substitution `{{key}}` + conditionals), `handoff.sh` (escape-valve writer + resume reader), `compose.sh` (filesystem-probe detection for architect-critic / ai-mentor / superpowers — no file IPC), `_helpers.sh` (shared utilities).
- **8 templates** under `templates/`: `adr.md.tmpl`, `handoff.md.tmpl`, `implementation-handoff.md.tmpl` (orchestrator → implementer subagent contract), `implementation-report.md.tmpl` (implementer → orchestrator return doc), `slice-retrospective.md.tmpl`, `sprint-retrospective.md.tmpl`, `vertical-slice-readme.md.tmpl`, `work-item-spec.md.tmpl`.
- **14 test files / ~216 assertions passing** across `tests/`: `test-state.sh`, `test-manifest.sh`, `test-worktree.sh`, `test-merge.sh`, `test-harvest.sh`, `test-verify.sh`, `test-rules.sh`, `test-render.sh`, `test-handoff.sh`, `test-compose.sh`, `test-helpers.sh`, `test-hook.sh`, `test-subagent.sh`, `test-e2e.sh` (3 e2e scenarios: minimal sprint, bug-fix handoff chain, composition with architect-critic + ai-mentor).

### Composition
- **workspace-init v0.1+** — manifest at `<ai-workspace>/.workspace/pairing.json` consumed for routing every artifact (slice specs to ai_workspace, ADRs per `routing.adr`, etc.). Single-repo fallback preserved.
- **scaffold-onboard v0.2+** — consumes R1 (Phase → Sprint → Vertical Slice hierarchy from `ROADMAP.md`), R2 (machine-checkable rules from `.claude/memory-bank/03-code-patterns.md`), R3 (`auto:`/`user:` demo criteria with literal U+2192 arrow).
- **architect-critic v0.2+** — invoked via `Skill(architect-critic:critiquing-spec)` at slice spec close, sprint-close retrospective, and ADR draft. Filesystem-probe detection (no file IPC).
- **ai-mentor v2.0+** — `Skill(ai-mentor:grill-me)` invoked at 3 gates: slice-plan close, mid-slice stuck-state, sprint retrospective.

### Replaces
- **`scaffold` v1.0.0** (DEPRECATED) — superseded by scaffold-dev's skill-first orchestrator-implementer split, dual-repo native design, R1/R2/R3 contract consumption, and subagent-via-Task-tool model. Migration: install scaffold-dev alongside scaffold v1.0.0 for the transition window; new sprints should use `/orchestrate`. scaffold v1.0.0 will remain in the marketplace as deprecated through one release cycle.
