#!/usr/bin/env bash
# test-master-spec-synthesis.sh — SS-3: MASTER-SPEC synthesis brief, prompt
# assembler (first-author/reconcile), behavioral close harness, no-determinism guard.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
ROOT="$HERE/.."
export PATH="$ROOT/bin:$PATH"
source "$ROOT/lib/state.sh"
source "$ROOT/lib/synthesis.sh"
source "$ROOT/lib/routing.sh"
BRIEF="$ROOT/templates/synthesis-briefs/MASTER-SPEC.brief.md"

test_brief_exists_and_valid_frontmatter() {
  echo "test_brief_exists_and_valid_frontmatter:"
  assert_file_exists "$BRIEF"
  assert_file_contains "$BRIEF" '^doc: MASTER-SPEC'
  assert_file_contains "$BRIEF" '^routes_to: master_spec'
  # Must instruct emitting a fillable Executive Summary section for the SS-2 step.
  assert_file_contains "$BRIEF" '## Executive Summary'
}

test_brief_is_tool_agnostic() {
  echo "test_brief_is_tool_agnostic:"
  # Zero Claude-isms: no "Claude", no Anthropic-specific tool names in the body.
  assert_file_not_contains "$BRIEF" 'Claude'
  assert_file_not_contains "$BRIEF" 'Anthropic'
}

test_brief_exists_and_valid_frontmatter
test_brief_is_tool_agnostic

test_brief_requires_parser_anchors() {
  echo "test_brief_requires_parser_anchors:"
  assert_file_contains "$BRIEF" '# <Project Name> — Master Specification'
  assert_file_contains "$BRIEF" '\*\*Project class:\*\* <enum>'
  assert_file_contains "$BRIEF" '\*\*Spec version:\*\* 1\.0'
  assert_file_contains "$BRIEF" '<!-- master-spec:phase id=1 name=Foundation -->'
  assert_file_contains "$BRIEF" '<!-- master-spec:phase id=10 name=Operations & Support -->'
  assert_file_contains "$BRIEF" 'sf_spec_validate'
}

test_brief_requires_parser_anchors

_seed_min_state() {
  sf_state_init
  sf_state_write_answer "1.1.1" "todo-cli — a fast task manager"
  sf_state_write_answer "1.3.1" "CLI tool"
}

test_prompt_first_author_contains_digest_and_mode() {
  echo "test_prompt_first_author_contains_digest_and_mode:"
  setup_tmp_repo
  _seed_min_state
  local digest out prompt
  digest="$(sf_state_synthesis_digest)"
  out="$TMP_DIR/repo/MASTER-SPEC.md"
  prompt="$(sf_synth_master_spec_prompt "$BRIEF" "$digest" "$out" first_author "" "")"
  printf '%s' "$prompt" | grep -q "todo-cli — a fast task manager" || { FAIL=$((FAIL+1)); echo "  ✗ digest not embedded"; return 1; }
  printf '%s' "$prompt" | grep -qi "MODE: first-author" || { FAIL=$((FAIL+1)); echo "  ✗ mode missing"; return 1; }
  printf '%s' "$prompt" | grep -q "$out" || { FAIL=$((FAIL+1)); echo "  ✗ out path missing"; return 1; }
  PASS=$((PASS+1)); echo "  ✓ first-author prompt assembled"
}

test_prompt_reconcile_lists_touched_and_existing() {
  echo "test_prompt_reconcile_lists_touched_and_existing:"
  setup_tmp_repo
  _seed_min_state
  local existing="$TMP_DIR/repo/MASTER-SPEC.md"
  printf '# todo-cli\n\n## Phase 1\nold content\n' > "$existing"
  local digest prompt
  digest="$(sf_state_synthesis_digest)"
  prompt="$(sf_synth_master_spec_prompt "$BRIEF" "$digest" "$existing" reconcile "1 5" "$existing")"
  printf '%s' "$prompt" | grep -qi "MODE: reconcile" || { FAIL=$((FAIL+1)); echo "  ✗ reconcile mode missing"; return 1; }
  printf '%s' "$prompt" | grep -q "touched this run: 1 5" || { FAIL=$((FAIL+1)); echo "  ✗ touched list missing"; return 1; }
  printf '%s' "$prompt" | grep -q "$existing" || { FAIL=$((FAIL+1)); echo "  ✗ existing spec path missing"; return 1; }
  PASS=$((PASS+1)); echo "  ✓ reconcile prompt assembled"
}

test_prompt_first_author_contains_digest_and_mode
test_prompt_reconcile_lists_touched_and_existing

test_prompt_does_not_expand_user_content() {
  echo "test_prompt_does_not_expand_user_content:"
  setup_tmp_repo
  sf_state_init
  # A hostile answer containing a command substitution + a backtick command.
  sf_state_write_answer "1.1.2" 'danger $(echo PWNED) and `echo ALSO`'
  local digest out prompt
  digest="$(sf_state_synthesis_digest)"
  out="$TMP_DIR/repo/MASTER-SPEC.md"
  prompt="$(sf_synth_master_spec_prompt "$BRIEF" "$digest" "$out" first_author "" "")"
  # The literal text must survive verbatim (NOT executed/expanded).
  if printf '%s' "$prompt" | grep -qF 'danger $(echo PWNED) and `echo ALSO`'; then
    PASS=$((PASS+1)); echo "  ✓ user content passed through literally (no expansion)"
  else
    FAIL=$((FAIL+1)); echo "  ✗ user content was expanded/altered — injection risk"
  fi
  # And the executed output must NOT appear as a standalone token.
  if printf '%s' "$prompt" | grep -qE '(^|[^A-Z])PWNED([^A-Z]|$)' && ! printf '%s' "$prompt" | grep -qF 'echo PWNED'; then
    FAIL=$((FAIL+1)); echo "  ✗ command substitution appears to have executed"
  else
    PASS=$((PASS+1)); echo "  ✓ no evidence of command execution"
  fi
}

test_prompt_does_not_expand_user_content

test_no_deterministic_master_spec_renderer() {
  echo "test_no_deterministic_master_spec_renderer:"
  source "$ROOT/lib/render.sh"
  if declare -F sf_master_spec_update_phase >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); echo "  ✗ sf_master_spec_update_phase still defined"
  else
    PASS=$((PASS+1)); echo "  ✓ sf_master_spec_update_phase removed"
  fi
  if declare -F sf_master_spec_init >/dev/null 2>&1; then
    FAIL=$((FAIL+1)); echo "  ✗ sf_master_spec_init still defined"
  else
    PASS=$((PASS+1)); echo "  ✓ sf_master_spec_init removed"
  fi
  assert_file_missing "$ROOT/templates/master-spec/MASTER-SPEC.md.tmpl"
  if declare -F sf_render_executive_summary >/dev/null 2>&1; then
    PASS=$((PASS+1)); echo "  ✓ SS-2 sf_render_executive_summary intact"
  else
    FAIL=$((FAIL+1)); echo "  ✗ SS-2 sf_render_executive_summary removed by mistake"
  fi
}

test_no_deterministic_master_spec_renderer

SKILL="$ROOT/skills/onboarding-project/SKILL.md"

# Extract the first ```bash block that follows a heading/line containing <marker>.
_extract_bash_after() {
  local file="$1" marker="$2"
  awk -v m="$marker" '
    index($0, m) { armed=1 }
    armed && /^```bash/ { inb=1; next }
    inb && /^```/ { exit }
    inb { print }
  ' "$file"
}

test_close_master_spec_block_executes_clean() {
  echo "test_close_master_spec_block_executes_clean:"
  setup_tmp_repo
  _seed_min_state
  export CLAUDE_PLUGIN_ROOT="$ROOT"
  local block; block="$(_extract_bash_after "$SKILL" "Produce MASTER-SPEC.md")"
  [[ -n "$block" ]] || { FAIL=$((FAIL+1)); echo "  ✗ no MASTER-SPEC bash block found"; return; }
  # Execute the extracted setup block under strict mode; it must assemble the
  # prompt without abort. (The Task() dispatch line is prose, not bash.)
  if bash -c "set -euo pipefail; $block; [[ -n \"\$prompt\" ]] && [[ -n \"\$master\" ]]"; then
    PASS=$((PASS+1)); echo "  ✓ first-author close block runs clean + assembles prompt"
  else
    FAIL=$((FAIL+1)); echo "  ✗ close block aborted under set -euo pipefail"
  fi
}

test_close_block_reconcile_backs_up_existing() {
  echo "test_close_block_reconcile_backs_up_existing:"
  setup_tmp_repo
  _seed_min_state
  export CLAUDE_PLUGIN_ROOT="$ROOT"
  # Pre-existing MASTER-SPEC at the resolved (single-repo → cwd) path.
  printf '# todo-cli\n\n## Phase 1\nold\n' > "$TMP_DIR/repo/MASTER-SPEC.md"
  local block; block="$(_extract_bash_after "$SKILL" "Produce MASTER-SPEC.md")"
  bash -c "set -euo pipefail; $block; echo \"\$mode\" > $TMP_DIR/mode.out"
  assert_eq "reconcile mode detected" "reconcile" "$(cat "$TMP_DIR/mode.out")"
  # A .bak-* copy must now exist next to MASTER-SPEC.md.
  if ls "$TMP_DIR/repo/MASTER-SPEC.md.bak-"* >/dev/null 2>&1; then
    PASS=$((PASS+1)); echo "  ✓ existing spec backed up before reconcile"
  else
    FAIL=$((FAIL+1)); echo "  ✗ no backup created"
  fi
}

test_close_master_spec_block_executes_clean
test_close_block_reconcile_backs_up_existing

# Fake "synthesis": write a MASTER-SPEC that includes a marker per phase that has
# either an answer or a record in the digest, plus the required Executive Summary
# section. Stands in for the sub-agent so the integration path is deterministic.
_fake_synthesize_master_spec() {
  local out="$1" digest="$2"
  {
    echo "# $(sf_project_name) — Master Specification"
    echo ""
    echo "**Project class:** CLI tool"
    echo "**Spec version:** 1.0"
    echo ""
    echo "## Executive Summary"
    echo "Placeholder summary line."
    echo ""
    # Echo each phase heading the digest carried content for.
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
      echo "<!-- master-spec:phase id=$i name=Phase $i -->"
      echo ""
      echo "## Phase $i"
      echo "Synthesized placeholder for phase $i."
      echo ""
    done
  } > "$out"
}

test_resumability_uses_persisted_records_across_sessions() {
  echo "test_resumability_uses_persisted_records_across_sessions:"
  setup_tmp_repo
  sf_state_init
  sf_state_run_reset
  # "Session A": phases 1-3 answered + records authored.
  sf_state_write_answer "1.1.1" "todo-cli — fast tasks"
  local r="$TMP_DIR/r.json"
  printf '{"decisions":"single JSON file"}' > "$r"; sf_state_write_phase_record 1 "$r"
  printf '{"decisions":"flat task schema"}' > "$r"; sf_state_write_phase_record 3 "$r"
  # "Session B": fresh process re-reads state from disk (no in-memory carryover).
  local digest; digest="$(sf_state_synthesis_digest)"
  printf '%s' "$digest" | grep -q "single JSON file" || { FAIL=$((FAIL+1)); echo "  ✗ phase-1 record lost across session"; return; }
  printf '%s' "$digest" | grep -q "flat task schema" || { FAIL=$((FAIL+1)); echo "  ✗ phase-3 record lost across session"; return; }
  PASS=$((PASS+1)); echo "  ✓ persisted phase records survive a session boundary"
}

test_reconcile_preserves_untouched_human_edit() {
  echo "test_reconcile_preserves_untouched_human_edit:"
  setup_tmp_repo
  sf_state_init
  # First author at close: touches phases 1 AND 8.
  sf_state_run_reset
  sf_state_write_answer "1.1.1" "todo-cli"
  local r="$TMP_DIR/r.json"; printf '{"decisions":"v1"}' > "$r"; sf_state_write_phase_record 1 "$r"
  printf '{"decisions":"ops v1"}' > "$r"; sf_state_write_phase_record 8 "$r"
  local master="$TMP_DIR/repo/MASTER-SPEC.md"
  _fake_synthesize_master_spec "$master" "$(sf_state_synthesis_digest)"
  # Human edits the phase-8 section directly in the file (not re-touched in re-run).
  printf '\n## Phase 8\nHAND-EDITED OPS NOTES — do not lose me.\n' >> "$master"
  # Enhancement re-run: ONLY phase 1 re-authored this run (phase 8 untouched).
  # Without sf_state_run_reset here, touched would be "1 8" and the assertion below
  # would fail — enforcing that run_reset correctly scopes the tracker.
  sf_state_run_reset
  printf '{"decisions":"v2"}' > "$r"; sf_state_write_phase_record 1 "$r"
  local touched; touched="$(sf_state_phases_touched_this_run | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "only phase 1 touched" "1" "$touched"
  # The reconcile prompt must carry the touched list AND point the agent at the
  # existing spec (which still holds the human edit). Assert the contract inputs.
  local prompt; prompt="$(sf_synth_master_spec_prompt "$BRIEF" "$(sf_state_synthesis_digest)" "$master" reconcile "$touched" "$master")"
  printf '%s' "$prompt" | grep -q "touched this run: 1" || { FAIL=$((FAIL+1)); echo "  ✗ touched list not in prompt"; return; }
  grep -q "HAND-EDITED OPS NOTES" "$master" || { FAIL=$((FAIL+1)); echo "  ✗ human edit already lost before synthesis"; return; }
  PASS=$((PASS+1)); echo "  ✓ reconcile feeds touched=1 + existing spec (human edit intact pre-synthesis)"
}

test_resumability_uses_persisted_records_across_sessions
test_reconcile_preserves_untouched_human_edit

report_results
