# Changelog

## [0.1.1] — 2026-05-16

### Added
- `argument-hint:` frontmatter on all 4 commands so the slash-command picker shows expected flags (`/critique [--phase N] [--depth ...] [--spec PATH]`, `/critique-list [--limit N]`, `/promote-principle "<text>" [--scope user|project]`). Polish on top of v0.1.0; no behavioral change.

## [0.1.0] — 2026-05-16

Initial release. **244 tests passing across 10 bash suites** (full regression < 30s); scaffold-onboard's 163 contract tests remain green (regression check per HANDOFF §7).

Built on branch `implementation-architect-critic` over Phases A–H per `docs/PLAN-architect-critic.md`. The build was subagent-driven for logic-bearing phases (B → D) and main-session-inline for scaffold/integration phases (A, E → H) after agent runtime instability surfaced in mid-flight. See `docs/SPEC-architect-critic.md` and the brainstorm transcript in `.superpowers/brainstorm/56102-1778732670/` for the design.

### Added (Phases A → G — see [Unreleased] notes below for the per-phase breakdown)

### Added
- **Phase A — plugin scaffold:** plugin.json manifest, LICENSE (MIT), README skeleton, CHANGELOG, 4 command stubs (`/critique`, `/critique-list`, `/promote-principle`, `/principles-list`), SessionStart hook stub, `lib/_helpers.sh` (logging + jq-then-mv guard + lock-file pattern), 9 empty lib stubs ready for Phase B–E, `templates/principles.md` seed (D3 stub-with-examples per SPEC §6.4), test infrastructure (`tests/_helpers.sh` with assert_*, setup_tmp_repo, setup_mock_codex), mock-codex PATH-override fixture + 3 canned codex payloads + tiny MASTER-SPEC fixture.
- **Phase B — state + principles + inbox (78 tests):**
  - `lib/state.sh` (35 tests): all 9 `ac_state_*` functions; lock-protected writes via `ac_guarded_jq_write`; recent_runs cap-20 trimming; full state.json schema per SPEC §6.3.
  - `lib/principles.sh` (22 tests): comment-strip handles both headers AND example comments per SPEC §6.4; trailing `[promoted ...]` annotation strip; 4-source compose with absent-source graceful degradation; BSD awk `sub()` chains for portability.
  - `lib/inbox.sh` (21 tests): all 8 ordered ERROR validation rules per SPEC §6.1; warning paths for missing principles file + null project_class; rule 6 correctly bypassed for `master-spec-full` target type.
- **Phase C — slash command bodies (103 tests cumulative):**
  - `/critique` (commands/critique.md): envelope synthesis from defaults (manual mode) + inbox-read (programmatic mode) + arg overrides (`--phase`, `--depth`, `--spec`) + validation via `ac_inbox_validate`. Audit pipeline stubbed pending Phase D.
  - `/critique-list`: jq-sliced LIMIT enforcement (no `tac`, no subshell trap); renders 7 columns including cost_usd; separate in_flight section.
  - `/promote-principle`: validates ≤200-char single-line text; `--scope user|project` routing; uses `ac_guarded_jq_write` for state.json writes; ERROR exit when scope=project and no memory-bank.
  - `/principles-list`: delegates to `ac_principles_compose`; renders 4-section composition; "(empty)" surface when principles.md absent.
  - `test-commands.sh` (25 assertions across 12 PLAN scenarios): extract-bash-from-markdown approach exercises actual command bodies, not lib internals.
- **Phase D — audit pipeline core (184 tests cumulative):**
  - `lib/codex.sh` (16 tests): `ac_codex_available` + `ac_codex_audit` with portable bash-only timeout (background subshell + kill — no GNU `timeout(1)` dependency), 180s default + `ARCHITECT_CRITIC_CODEX_TIMEOUT` env override, strict JSON parse with jq, all 4 failure paths (absent / timeout / non-zero / malformed JSON) fall back to return 1 + claude-only. Extended mock-codex fixture with `MOCK_CODEX_SLEEP` + `MOCK_CODEX_EXIT_CODE` env vars.
  - `lib/consolidator.sh` (29 tests): `ac_consolidator_merge` implements SPEC §7.1 — concat + source-tag + exact-match dedup with `agreed_by_both` marker + heuristic divergence detection + gap concat; `adversaries_used` derived from inputs. Single jq invocation; jq 1.7 BINDING-syntax workarounds applied.
  - `lib/scorer.sh` (14 tests): T=4 firm rubric per Q4 — heuristic check (bare contradiction → 1, cite-self substring → 2, material new info → ≥4), `ARCHITECT_CRITIC_SCORER_MOCK` env override for the claude-reasoning fallback path, 500-char rebuttal truncation. `ac_scorer_decide` returns concede ≥4 else restate.
  - `lib/outbox.sh` (19 tests): `ac_outbox_write` assembles full SPEC §6.2 envelope (7 fields), uses `ac_guarded_jq_write` for atomic write, `cost_usd` preserved as JSON number via `--argjson`, mkdir-p safety, idempotent overwrite.
  - `lib/cost.sh` (2 tests in test-consolidator): `ac_cost_compute` with static rate-card (`AC_COST_CODEX_IN_PER_1K=0.005`, `AC_COST_CODEX_OUT_PER_1K=0.015`; "as of 2026-05" doc comment), bc-or-bash-only fallback. `ac_cost_print` formats per SPEC OQ-3 line.
  - `commands/critique.md` (no new tests; full pipeline wired): Steps 3–11 of SPEC §5.1 in place — record in_flight → claude-self-audit (with `ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK` test hook) → codex audit if depth=close → consolidator merge → outbox write → cost line → state completion. Phase E rebuttal-cycle + promotion-offer steps stubbed.
- **Phase E — auto-promotion FULL + rebuttal cycle (216 tests cumulative):**
  - `lib/promotion.sh` (29 tests via test-promotion.sh): full SPEC §7.2 algorithm — `ac_promotion_topic` (lowercase + stemmed first word + sorted refs), `ac_promotion_within_run_candidates` (cluster by topic, emit groups ≥2), `ac_promotion_cross_run_candidates` (scan state.json recent_runs[0..19], emit when total ≥3), `ac_promotion_synthesize` (claude-reasoning prompt builder + `ARCHITECT_CRITIC_PROMOTION_MOCK` env override), `ac_promotion_filter_suppressed` (30-day decline window), `ac_promotion_record_candidates` + `ac_promotion_record_decline`.
  - `/critique` rebuttal cycle: iterates consolidator's challenges, prompts user for `accept`/`edit`/`note`/`<rebuttal>`, scores rebuttals via `ac_scorer_score_rebuttal`, concedes at ≥4 else restates. TTY-gated (or `ARCHITECT_CRITIC_REBUT_INPUT` env override for tests). Uses process substitution `< <(printf …)` so inner `read -r` doesn't conflict with outer challenge iteration.
  - `/critique` auto-promotion offer: composes within-run + cross-run candidates, filters via 30-day suppression, records to state.json's `candidate_promotions`. Interactive `[y]es/[n]o/[e]dit` per candidate, TTY-gated. y → `ac_state_append_promotion` + appends to principles.md with `[promoted YYYY-MM-DD source:auto]` annotation; n → `ac_promotion_record_decline` (30-day suppression); e → opens `$EDITOR` (or `true` as safe default).
  - `lib/principles.sh` (25 tests via test-principles.sh): `ac_principles_load_user_global` re-seeds from template if file missing (SPEC §11 edge case).
- **Phase F — hooks + scaffold-onboard delta (OQ-2) (219 tests cumulative + scaffold-onboard 163 regression-green):**
  - `hooks-handlers/session-start.sh` (2 tests in test-state.sh): housekeeping clears `state.json.in_flight` entries with `started_at < now − 24h`. Source-aware: only fires on `startup`/`clear` per `hooks/hooks.json` matcher. Lock-protected write.
  - `lib/state.sh` schema-migration tolerance (3 tests): `ac_state_init` logs info + preserves on-disk schema_version > 1 (forward-compatibility).
  - `/critique-list` cost column (1 test in test-commands.sh): renders `cost_usd` from `recent_runs[]` per OQ-3 minimal cost UX.
  - **OQ-2 scaffold-onboard delta:** `scaffold-onboard/commands/onboard.md` frontmatter now includes `SlashCommand` in `allowed-tools`. The per-phase critic dispatch already lives in the protocol prose (Phase 5/7 recap + MASTER-SPEC close steps invoke `/critique`); adding `SlashCommand` to the allowed-tools makes that invocation possible from inside `/onboard`. scaffold-onboard's 163 regression tests stay green. **TF.3 mock /critique handler** marked N/A: scaffold-onboard's `test-e2e.sh` exercises lib functions directly (not the slash command body), so there's no `/critique` invocation to mock.
- **Phase G — E2E + polish (244 tests cumulative):**
  - `tests/test-e2e.sh` (22 tests): three end-to-end scenarios per SPEC §12 — TG.1 manual /critique in empty repo with mock-codex (close depth, 3 challenges merged), TG.2 onboarded repo with /critique --phase 5 premise-audit (claude-only), TG.3 full audit cycle exercising consolidator + within-run candidate detection + promotion accept-path + decline-path + scorer concede/restate transitions + OQ-3 cost line. Uses mock-codex via PATH override + `ARCHITECT_CRITIC_CLAUDE_AUDIT_MOCK` env hook for hermetic execution.
  - `README.md` polish: worked example walking through manual `/critique` (rebuttal cycle + promotion offer), cost section with sample line, composition section (standalone vs scaffold-onboard), see-also pointers to SPEC + PLAN + scaffold-onboard §8.3.
  - Hardening sweep: `ac_guarded_jq_write` confirmed as the write path for every state.json mutation; `ac_lock_acquire`/`ac_lock_release` paired with explicit release before each `return` (Adaptation 3); `bash -n` syntax check passes on all lib + hook handlers + command body extracts.
