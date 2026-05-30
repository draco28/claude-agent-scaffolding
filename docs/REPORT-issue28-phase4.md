# Issue 28 Phase 4 Report

Date: 2026-05-31

## Scope

Phase 4 completed the post-merge eval/documentation migration for the issue 28 slice-ID contract:

- Active scaffold-dev eval specs now use three-part slice IDs (`VS-N.M.K`) and explicit dotted `sprint_id` paths.
- Planning evals now assert the structured roadmap contract: resolve `well_known_paths.roadmap_state`, field-read `project-roadmap.json` by exact `id`, and read `sprint_id` as data.
- Handoff evals now allow dotted purpose segments for carry-forward filenames such as `sprint-3.2-to-3.3-handoff-<id>.md`.
- Sprint-retro evals now model a single dotted sprint (`sprint-3.1`) with three same-sprint slices (`VS-3.1.1`, `VS-3.1.2`, `VS-3.1.3`).

## Release Baseline

PR #32 was merged before this phase and the affected plugins were tagged:

- `workspace-init-v0.1.2`
- `scaffold-onboard-v0.3.6`
- `scaffold-dev-v0.1.6`

Phase 4 is intentionally docs/eval-contract work on top of that release baseline; it does not change plugin runtime code or manifest versions.

## Migrated Eval Contracts

- `scaffold-dev/evals/planning-vertical-slice.md`
  - Uses `.workspace/project-roadmap.json` as the lookup surface.
  - Asserts `sd_roadmap_state_path`, `sd_roadmap_slice_json`, and `sd_roadmap_slice_sprint_id` behavior.
  - Keeps `ROADMAP.md` as rendered human context only.
- `scaffold-dev/evals/closing-vertical-slice.md`
  - Uses `VS-3.2.1` under `sprint-3.2`.
  - Uses `work-1.01` through `work-1.04`.
  - Includes roadmap state fixture data so close-flow path resolution is field-read based.
- `scaffold-dev/evals/executing-work-item.md`
  - Migrates the old `VS-2.1` / `sprint-2` / `work-2.04` fixture to `VS-2.1.1` / `sprint-2.1` / `work-1.04`.
- `scaffold-dev/evals/implementation-checking.md`
  - Uses `VS-3.2.1`, `sprint-3.2`, `work-1.01`, and active cursor state.
- `scaffold-dev/evals/handing-off-session.md`
  - Uses slice handoffs like `vs-3.2.1-bugfix-auth-<id>.md`.
  - Uses carry-forward handoffs like `sprint-3.2-to-3.3-handoff-<id>.md`.
  - Updates filename invariants so dotted purpose segments are accepted.
- `scaffold-dev/evals/writing-sprint-retrospective.md`
  - Uses `sprint-3.1` with `VS-3.1.1`, `VS-3.1.2`, and `VS-3.1.3`.
- `scaffold-dev/evals/results/SUMMARY.md`
  - Marked as historical pre-Phase-4 evidence so preserved legacy examples are not mistaken for active contracts.

## Static Evidence

Active eval docs were scanned for stale two-part slice IDs, old work-item IDs, and old carry-forward forms. A broad initial scan only hit an intentionally escaped regex example for the new dotted carry-forward filename; the final PCRE scan below reported no stale matches.

The runtime smoke surface remains covered by existing shell suites:

- workspace-init manifest contract: `test_A9_well_known_paths_roadmap_state`
- scaffold-onboard publish contract: `test_publish_state_writes_to_workspace_when_manifest_present`
- scaffold-dev consume contract: `test_state_path_resolves_routed_key`, `test_slice_sprint_id_field_read`, `test_e2e_minimal_sprint`

## Verification

- `cd workspace-init && bash run-tests.sh`
  - 10 test files run, 0 failed.
- `cd scaffold-onboard && for t in tests/test-*.sh; do bash "$t" || exit 1; done`
  - Command exited 0. Notable summaries included `test-e2e` 162 passed / 0 failed, `test-roadmap` 68 passed / 0 failed, `test-synthesis` 60 passed / 0 failed, and `test-state` 36 passed / 0 failed.
- `cd scaffold-dev && bash run-tests.sh`
  - 16 test files run, 0 failed.
- `bash tests/test-codex-dual-publish.sh`
  - 119 passed, 0 failed.
- `jq -e . workspace-init/.claude-plugin/plugin.json workspace-init/.codex-plugin/plugin.json scaffold-onboard/.claude-plugin/plugin.json scaffold-onboard/.codex-plugin/plugin.json scaffold-dev/.claude-plugin/plugin.json scaffold-dev/.codex-plugin/plugin.json .agents/plugins/marketplace.json`
  - Exited 0.
- Active eval stale-pattern scan:
  - `rg -n -P "(?<![\\\\.])VS-[0-9]+\\.[0-9]+(?![0-9.])|(?<![\\\\.])vs-[0-9]+\\.[0-9]+(?![0-9.])|docs/specs/sprint-[0-9]+/|\\.worktrees/work-|work-[23]\\.[0-9][0-9]|sprint-[0-9]+-to-[0-9]+|to-[0-9]+-handoff" scaffold-dev/evals --glob '!**/results/SUMMARY.md'`
  - Exited 1 with no matches, as expected for `rg` when no stale patterns are found.
- `git diff --check`
  - Exited 0.

Review cleanup on PR #34 also re-ran:

- `cd scaffold-dev && bash run-tests.sh`
- active eval stale-pattern scan with the broadened `.worktrees/work-` guard above
- `git diff --check`

## Limitation

The full natural-language Agent eval harness described in `scaffold-dev/evals/*.md` is not a repo-local CLI test runner. This phase migrates those eval specifications and validates the underlying published/consumed contract through the repo-local bash suites. A future Claude Code Agent eval run can consume these updated specs directly.
