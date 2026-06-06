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

report_results
