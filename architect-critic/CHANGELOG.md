# Changelog

## [Unreleased]

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
