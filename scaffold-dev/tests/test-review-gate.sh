#!/usr/bin/env bash
# tests/test-review-gate.sh — tests for lib/review_gate.sh (#39 Phase B
# review-gate selector) + the §7 gate seams in the slice-close / spec-gate
# skills. Dispatcher-path (bin/sd) for the set -e-sensitive manifest-read
# default, mirroring tests/test-backend.sh.

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
SD_BIN="$HERE/../bin/sd"

# --- B-W1: sd_review_gate_resolve --------------------------------------------

test_resolve_default_when_field_absent() {
  echo "test_resolve_default_when_field_absent:"
  setup_tmp_workspace
  # Manifest exists (no review_gate field) → default off.
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "defaults to off" "off" "$OUT"
}

test_resolve_field_both() {
  echo "test_resolve_field_both:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.review_gate = "both"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "reads both from manifest" "both" "$OUT"
}

test_resolve_field_slice_close() {
  echo "test_resolve_field_slice_close:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.review_gate = "slice_close"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "reads slice_close" "slice_close" "$OUT"
}

test_resolve_field_spec_close() {
  echo "test_resolve_field_spec_close:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.review_gate = "spec_close"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "reads spec_close" "spec_close" "$OUT"
}

test_override_beats_manifest() {
  echo "test_override_beats_manifest:"
  setup_tmp_workspace
  # Manifest absent (default off); override forces slice_close.
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve --gate slice_close)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "override wins" "slice_close" "$OUT"
}

# Override must beat a SET manifest field (a different value), not just an absent one.
test_override_beats_set_manifest() {
  echo "test_override_beats_set_manifest:"
  setup_tmp_workspace
  local tmp="$TMP_MANIFEST.new"
  jq '.review_gate = "both"' "$TMP_MANIFEST" > "$tmp" && mv "$tmp" "$TMP_MANIFEST"
  # Manifest SET to both; override to a DIFFERENT value must win.
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve --gate off)" && RC=0 || RC=$?
  assert_eq "rc=0" "0" "$RC"
  assert_eq "override beats a SET manifest field" "off" "$OUT"
}

test_override_missing_value() {
  echo "test_override_missing_value:"
  setup_tmp_workspace
  OUT="$(cd "$TMP_AI_WORKSPACE" && bash "$SD_BIN" review_gate_resolve --gate 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=2 when --gate lacks a value" "2" "$RC"
  assert_contains "reports missing --gate value" "missing value for --gate" "$OUT"
}

test_resolve_no_manifest_defaults() {
  echo "test_resolve_no_manifest_defaults:"
  setup_tmp_repo
  # Plain git repo, no .workspace/pairing.json on the walk-up path. The
  # manifest-read returns rc=1 and must NOT abort under the dispatcher set -e.
  OUT="$(cd "$TMP_DIR/repo" && bash "$SD_BIN" review_gate_resolve)" && RC=0 || RC=$?
  assert_eq "rc=0 (manifest-read rc1 does not abort)" "0" "$RC"
  assert_eq "defaults to off" "off" "$OUT"
}

test_resolve_invalid_gate() {
  echo "test_resolve_invalid_gate:"
  setup_tmp_repo
  OUT="$(cd "$TMP_DIR/repo" && bash "$SD_BIN" review_gate_resolve --gate bogus 2>&1)" && RC=0 || RC=$?
  assert_eq "rc=1 on invalid gate" "1" "$RC"
  assert_contains "names the invalid value" "bogus" "$OUT"
}

# --- sd_review_gate_bundle: mechanical bundle assembly (extracted from §7.2a prose
#     after Codex rounds 3-5 kept finding plumbing bugs there; the AGENT still makes
#     every decision and just calls this tested helper). Bakes in: write under a
#     trusted git root (never /tmp), diff only when non-empty, file concat. ---------

test_bundle_under_slice_root_with_diff() {
  echo "test_bundle_under_slice_root_with_diff:"
  setup_tmp_workspace
  ( cd "$TMP_CANONICAL" && git checkout -q -b feature && echo "feat line added" >> README.md && git commit -qam "feat" )
  local bundle
  bundle="$(bash "$SD_BIN" review_gate_bundle --slice-root "$TMP_AI_WORKSPACE" \
    --title "Slice-close review bundle: VS-1.1.1" \
    --diff-root "$TMP_CANONICAL" --diff-base main \
    "VS README" "$TMP_CANONICAL/README.md")"
  assert_contains "bundle path under slice root" "$TMP_AI_WORKSPACE" "$bundle"
  assert_contains "bundle is the dotfile under slice root" "/.sd-review-bundle.md" "$bundle"
  assert_file_contains "$bundle" "Slice-close review bundle: VS-1.1.1"
  assert_file_contains "$bundle" "Combined diff"
  assert_file_contains "$bundle" "feat line added"
  assert_file_contains "$bundle" "VS README"
}

test_bundle_omits_empty_diff() {
  echo "test_bundle_omits_empty_diff:"
  setup_tmp_workspace
  ( cd "$TMP_CANONICAL" && git checkout -q -b feature && echo "x" >> README.md && git commit -qam "feat" )
  # diff-base = current branch → merge-base == HEAD → empty diff (the direct-mode case)
  local bundle
  bundle="$(bash "$SD_BIN" review_gate_bundle --slice-root "$TMP_AI_WORKSPACE" --title "T" \
    --diff-root "$TMP_CANONICAL" --diff-base feature \
    "spec: a" "$TMP_CANONICAL/README.md")"
  assert_file_not_contains "$bundle" "Combined diff"
  assert_file_contains "$bundle" "spec: a"
}

test_bundle_spec_mode_no_diff() {
  echo "test_bundle_spec_mode_no_diff:"
  setup_tmp_workspace
  printf 'spec body here\n' > "$TMP_AI_WORKSPACE/specA.md"
  local bundle
  bundle="$(bash "$SD_BIN" review_gate_bundle --slice-root "$TMP_AI_WORKSPACE" \
    --title "Combined work-item specs: VS-1.1.1" \
    "spec: work-1.01" "$TMP_AI_WORKSPACE/specA.md")"
  assert_file_not_contains "$bundle" "Combined diff"
  assert_file_contains "$bundle" "Combined work-item specs: VS-1.1.1"
  assert_file_contains "$bundle" "spec body here"
}

test_bundle_missing_section_file_graceful() {
  echo "test_bundle_missing_section_file_graceful:"
  setup_tmp_workspace
  assert_exit_code 0 bash "$SD_BIN" review_gate_bundle --slice-root "$TMP_AI_WORKSPACE" --title "T" \
    "ghost" "$TMP_DIR/does-not-exist.md"
}

test_bundle_requires_slice_root() {
  echo "test_bundle_requires_slice_root:"
  setup_tmp_workspace
  assert_exit_code 2 bash "$SD_BIN" review_gate_bundle --title "T"
}

test_bundle_diff_pair_required() {
  echo "test_bundle_diff_pair_required:"
  setup_tmp_workspace
  # lone --diff-root (no --diff-base) must fail loud, not silently skip the diff
  assert_exit_code 2 bash "$SD_BIN" review_gate_bundle --slice-root "$TMP_AI_WORKSPACE" --title "T" --diff-root "$TMP_CANONICAL"
}

test_bundle_odd_section_args() {
  echo "test_bundle_odd_section_args:"
  setup_tmp_workspace
  # a trailing unpaired section arg must fail loud
  assert_exit_code 2 bash "$SD_BIN" review_gate_bundle --slice-root "$TMP_AI_WORKSPACE" --title "T" "ghost-heading"
}

# --- B-W2: §7 review-gate seam prose -----------------------------------------
# The gate's dispatch/defer flow is agent behavior (skill prose), verified here
# by seam lints (the Phase A pattern). Each §7 must carry the gate-resolution,
# async-dispatch, dispatch-and-defer, resume-hint, usage-warning, v0.2-fallback,
# and off=unchanged seams; the spec gate also carries the author→close note.

CLOSING_SKILL="$HERE/../skills/closing-vertical-slice/SKILL.md"
PLANNING_SKILL="$HERE/../skills/planning-vertical-slice/SKILL.md"
ORCHESTRATE_ARGS="$HERE/../skills/planning-vertical-slice/references/orchestrate-args.md"
GIT_WORKFLOW="$HERE/../skills/planning-vertical-slice/references/git-workflow.md"

# Both §7 sections must drive architect-critic through its REAL async contract
# (ARCHITECT_CRITIC_ARGS="… --close --async" — informal params don't set async),
# react-to-return (so v0.2 / Codex-host degrade to a synchronous review, never a
# phantom job), gate async on Claude-host, and preserve gate-off behavior.
_seam_async_contract() {
  local skill="$1"
  assert_file_contains "$skill" "sd review_gate_resolve"
  # gate resolved from the AI-workspace root (manifest lives there; §5 cd's to
  # canonical) — Codex round-4 R4-A.
  assert_file_contains "$skill" 'ai_workspace" && sd review_gate_resolve'
  assert_file_contains "$skill" "ARCHITECT_CRITIC_ARGS"
  # the single-artifact bundle is assembled by the tested helper sd_review_gate_bundle
  # (its trusted-root / non-empty-diff / concat invariants live in the bundle unit
  # tests above — Codex rounds 2-5); the prose just CALLS it.
  assert_file_contains "$skill" "sd review_gate_bundle"
  # args must be EXPORTED (a plain assignment isn't seen by critiquing-spec) and
  # the bundle passed as an explicit --spec path (Codex round-6 T2/T3).
  assert_file_contains "$skill" "export ARCHITECT_CRITIC_ARGS"
  assert_file_contains "$skill" "[-][-]spec "
  assert_file_contains "$skill" "[-][-]close [-][-]async"
  assert_file_contains "$skill" "dispatch-and-defer"
  assert_file_contains "$skill" "/critique-jobs resume"
  assert_file_contains "$skill" "consumes Codex"
  assert_file_contains "$skill" "synchronous"
  assert_file_contains "$skill" "Claude-host"
  assert_file_contains "$skill" "today's behavior"
  # preflight hard-fail is an explicit third react-to-return outcome (New-2).
  assert_file_contains "$skill" "Pre-flight hard-fail"
  # non-runnable-in-active-host degrades to warn-and-proceed, not a failed call (New-5).
  assert_file_contains "$skill" "runnable in the active host"
  # per-invocation --gate override is wired through §13 to the resolver (Codex round-5 R5-A).
  assert_file_contains "$skill" "gate_override"
  assert_file_contains "$skill" "review_gate_resolve --gate"
  # absent probe (exits 1 by design) is set-e-guarded before routing (Codex round-5 R5-B).
  assert_file_contains "$skill" "exits 1 by design"
  # async=true was the broken informal-parameter form (Codex P1) — must be gone.
  assert_file_not_contains "$skill" "async=true"
}

test_seam_prose_closing_vertical_slice() {
  echo "test_seam_prose_closing_vertical_slice:"
  _seam_async_contract "$CLOSING_SKILL"
  # async job handle is carried to §8 (retrospective is template-rendered there;
  # an early write would be clobbered) — Codex round-3 R3-B.
  assert_file_contains "$CLOSING_SKILL" "carry the job"
  assert_file_contains "$CLOSING_SKILL" "durable home for the job handle"
  # ALL §7.2a outcomes (skip / synchronous / hard-fail) defer to §8, not just the
  # async-dispatched one — Codex round-4 R4-B.
  assert_file_contains "$CLOSING_SKILL" "carry the critic's findings"
  assert_file_contains "$CLOSING_SKILL" "bypassed by user"
  # the undefined <vs-start-commit> placeholder must not reappear (R4-C); the real
  # diff-base / non-empty logic now lives in the tested helper, not the prose.
  assert_file_not_contains "$CLOSING_SKILL" "vs-start-commit"
  # PR #83 review fix: every manifest-dependent diff-base lookup must be anchored
  # to the AI workspace because the close flow may have cd'd into canonical.
  assert_file_contains "$CLOSING_SKILL" 'cd "\$ai_workspace" && sd sprint_branch_name'
  assert_file_contains "$CLOSING_SKILL" 'cd "\$ai_workspace" && sd manifest_get'
  # PR #83 review fix: under pr_hierarchical the slice→sprint PR gate must run
  # before final-slice sprint cleanup.
  assert_file_contains "$CLOSING_SKILL" 'Then the slice→sprint PR under `pr_hierarchical` .*sprint-close sweep on the final slice'
  assert_file_contains "$CLOSING_SKILL" "sd worktree_resolve"
  assert_file_not_contains "$CLOSING_SKILL" "shopt -s nullglob"
}

test_seam_prose_planning_vertical_slice() {
  echo "test_seam_prose_planning_vertical_slice:"
  _seam_async_contract "$PLANNING_SKILL"
  # spec gate keeps the depth upgrade even when async is unavailable (Codex P2a)
  assert_file_contains "$PLANNING_SKILL" "upgrades the default author-depth"
  # PR #83 review fix: pr_hierarchical worktrees must actually pass the slice
  # branch as sd_worktree_add's 5th arg, not merely mention it in prose.
  assert_file_contains "$PLANNING_SKILL" 'sd worktree_add "\$\{work_id\}" "\$\{vs_id\}" "\$\{kebab\}" "\$\{sprint_id\}" "\$\{slice_branch\}"'
  # PR #83 hardening: baseline default-branch lookup is manifest-dependent.
  assert_file_contains "$PLANNING_SKILL" 'cd "\$ai_workspace" && sd manifest_get'
}

test_orchestrate_args_validates_vs_id() {
  echo "test_orchestrate_args_validates_vs_id:"
  assert_file_contains "$ORCHESTRATE_ARGS" "orchestrate: invalid VS-id"
  assert_file_contains "$ORCHESTRATE_ARGS" '\^VS-\[\^\.\]\+\(\\\.\[\^\.\]\+\)\{2\}\$'
}

# --- #82: pre-merge gate completeness contract -------------------------------
# git-workflow.md is the SINGLE source of the agent-driven pre-merge gate. The
# gate is binding agent judgment by design, so these seam lints pin only a small
# set of load-bearing phrases that uniquely identify the two clauses and the
# deterministic-check boundary.
test_seam_premerge_gate_contract() {
  echo "test_seam_premerge_gate_contract:"
  # Finding-disposition loop
  assert_file_contains "$GIT_WORKFLOW" "Finding-disposition loop"
  assert_file_contains "$GIT_WORKFLOW" "P1/blocking"
  assert_file_contains "$GIT_WORKFLOW" "deferral, not a silent pass"
  assert_file_contains "$GIT_WORKFLOW" "not waved through"
  # Reviewer-completeness
  assert_file_contains "$GIT_WORKFLOW" "actual review/comment signal"
  assert_file_contains "$GIT_WORKFLOW" "in-progress reviewer must be waited for"
  assert_file_contains "$GIT_WORKFLOW" "stale verdict needs re-review"
  assert_file_contains "$GIT_WORKFLOW" "CodeRabbit's default configuration"
  assert_file_contains "$GIT_WORKFLOW" "sprint→main targets the"
  # Agent-judgment boundary
  assert_file_contains "$GIT_WORKFLOW" "Deterministic checks stay only for"
}

test_seam_prose_implementation_checking_path_resolution() {
  echo "test_seam_prose_implementation_checking_path_resolution:"
  local skill="$HERE/../skills/implementation-checking/SKILL.md"
  assert_file_contains "$skill" "sd work_item_dir_resolve"
  assert_file_contains "$skill" "sd worktree_resolve"
  assert_file_not_contains "$skill" "shopt -s nullglob"
}

test_resolve_default_when_field_absent
test_resolve_field_both
test_resolve_field_slice_close
test_resolve_field_spec_close
test_override_beats_manifest
test_override_beats_set_manifest
test_override_missing_value
test_resolve_no_manifest_defaults
test_resolve_invalid_gate
test_bundle_under_slice_root_with_diff
test_bundle_omits_empty_diff
test_bundle_spec_mode_no_diff
test_bundle_missing_section_file_graceful
test_bundle_requires_slice_root
test_bundle_diff_pair_required
test_bundle_odd_section_args
test_seam_prose_closing_vertical_slice
test_seam_prose_planning_vertical_slice
test_orchestrate_args_validates_vs_id
test_seam_premerge_gate_contract
test_seam_prose_implementation_checking_path_resolution

sd_test_summary
