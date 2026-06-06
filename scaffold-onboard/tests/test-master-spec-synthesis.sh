#!/usr/bin/env bash
# test-master-spec-synthesis.sh — SS-3: MASTER-SPEC synthesis brief, prompt
# assembler (first-author/reconcile), behavioral close harness, no-determinism guard.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
ROOT="$HERE/.."
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
  printf '%s' "$prompt" | grep -q "todo-cli — a fast task manager" || { echo "  ✗ digest not embedded"; exit 1; }
  printf '%s' "$prompt" | grep -qi "MODE: first-author" || { echo "  ✗ mode missing"; exit 1; }
  printf '%s' "$prompt" | grep -q "$out" || { echo "  ✗ out path missing"; exit 1; }
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
  printf '%s' "$prompt" | grep -qi "MODE: reconcile" || { echo "  ✗ reconcile mode missing"; exit 1; }
  printf '%s' "$prompt" | grep -q "touched this run: 1 5" || { echo "  ✗ touched list missing"; exit 1; }
  printf '%s' "$prompt" | grep -q "$existing" || { echo "  ✗ existing spec path missing"; exit 1; }
  PASS=$((PASS+1)); echo "  ✓ reconcile prompt assembled"
}

test_prompt_first_author_contains_digest_and_mode
test_prompt_reconcile_lists_touched_and_existing

report_results
