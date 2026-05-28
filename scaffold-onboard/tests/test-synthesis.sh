#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/synthesis.sh"
PLUGIN_ROOT="$HERE/.."
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"

test_project_name_prefers_explicit_answer() {
  echo "test_project_name_prefers_explicit_answer:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "Acme — the — multi — dash — pitch"
  sf_state_write_answer "1.1.4" "Acme"
  assert_eq "explicit name wins" "Acme" "$(sf_project_name)"
}

test_project_name_no_emdash_truncation_fallback() {
  echo "test_project_name_no_emdash_truncation_fallback:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "Acme — a — pitch — with — dashes"
  local got; got="$(sf_project_name)"
  assert_eq "fallback is basename, not em-dash prefix" "$(basename "$PWD")" "$got"
}

test_synth_enabled_default_on() {
  echo "test_synth_enabled_default_on:"
  unset SF_SYNTH_FAST 2>/dev/null || true
  assert_eq "default is synthesize" "synthesize" "$(sf_synth_mode)"
}
test_synth_enabled_fast_flag() {
  echo "test_synth_enabled_fast_flag:"
  assert_eq "--fast forces deterministic" "fast" "$(SF_SYNTH_FAST=1 sf_synth_mode)"
}

_write_sample_brief() {
  cat > "$1" <<'EOF'
---
doc: SRS
routes_to: srs
wave: 2
required_sections:
  - "Functional Requirements"
  - "Non-Functional Requirements"
  - "Traceability"
mints: [FR, NFR]
consumes: [UC]
model: opus
---
## Synthesis guidance
Derive FRs from PRD use cases.
EOF
}
test_brief_field_scalar() {
  echo "test_brief_field_scalar:"
  setup_tmp_repo
  _write_sample_brief ./b.brief.md
  assert_eq "routes_to" "srs" "$(sf_synth_brief_field ./b.brief.md routes_to)"
  assert_eq "wave" "2" "$(sf_synth_brief_field ./b.brief.md wave)"
  assert_eq "model" "opus" "$(sf_synth_brief_field ./b.brief.md model)"
}
test_brief_required_sections_list() {
  echo "test_brief_required_sections_list:"
  setup_tmp_repo
  _write_sample_brief ./b.brief.md
  local got; got="$(sf_synth_brief_list ./b.brief.md required_sections | tr '\n' '|')"
  assert_eq "sections" "Functional Requirements|Non-Functional Requirements|Traceability|" "$got"
}
test_brief_validate_ok() {
  echo "test_brief_validate_ok:"
  setup_tmp_repo
  _write_sample_brief ./b.brief.md
  if sf_synth_brief_validate ./b.brief.md; then echo "  ✓ valid"; PASS=$((PASS+1)); else echo "  ✗"; FAIL=$((FAIL+1)); fi
}
test_brief_validate_missing_key() {
  echo "test_brief_validate_missing_key:"
  setup_tmp_repo
  printf -- '---\ndoc: X\n---\nbody\n' > ./bad.brief.md
  if sf_synth_brief_validate ./bad.brief.md 2>/dev/null; then echo "  ✗ should fail"; FAIL=$((FAIL+1)); else echo "  ✓ rejected"; PASS=$((PASS+1)); fi
}

test_ledger_merge_concats_families() {
  echo "test_ledger_merge_concats_families:"
  local base='{"use_cases":[{"id":"UC-1","title":"a"}],"frs":[],"nfrs":[],"backlog":[]}'
  local add='{"frs":[{"id":"FR-1","title":"f","traces_uc":["UC-1"]}]}'
  local out; out="$(sf_synth_ledger_merge "$base" "$add")"
  assert_eq "uc kept"  "UC-1" "$(printf '%s' "$out" | jq -r '.use_cases[0].id')"
  assert_eq "fr added" "FR-1" "$(printf '%s' "$out" | jq -r '.frs[0].id')"
}

test_validate_cited_ids_present() {
  echo "test_validate_cited_ids_present:"
  local led='{"use_cases":[{"id":"UC-1"}],"frs":[{"id":"FR-1"}],"nfrs":[],"backlog":[]}'
  if sf_synth_validate_cited "$led" "UC-1 FR-1"; then echo "  ✓"; PASS=$((PASS+1)); else echo "  ✗"; FAIL=$((FAIL+1)); fi
}
test_validate_cited_ids_missing() {
  echo "test_validate_cited_ids_missing:"
  local led='{"use_cases":[{"id":"UC-1"}],"frs":[],"nfrs":[],"backlog":[]}'
  if sf_synth_validate_cited "$led" "FR-9" 2>/dev/null; then echo "  ✗ should fail"; FAIL=$((FAIL+1)); else echo "  ✓ rejected"; PASS=$((PASS+1)); fi
}
test_no_fillin_markers_pass_and_fail() {
  echo "test_no_fillin_markers_pass_and_fail:"
  setup_tmp_repo
  printf '# Doc\nReal content.\n' > ./good.md
  printf '# Doc\n1. *(steps in order)*\n' > ./bad.md
  if sf_synth_assert_no_markers ./good.md; then echo "  ✓ clean ok"; PASS=$((PASS+1)); else echo "  ✗"; FAIL=$((FAIL+1)); fi
  if sf_synth_assert_no_markers ./bad.md 2>/dev/null; then echo "  ✗ should fail"; FAIL=$((FAIL+1)); else echo "  ✓ marker caught"; PASS=$((PASS+1)); fi
}

test_brief_assemble_includes_paths_and_ledger_slice() {
  echo "test_brief_assemble_includes_paths_and_ledger_slice:"
  setup_tmp_repo
  _write_sample_brief ./b.brief.md
  local led='{"use_cases":[{"id":"UC-1","title":"login"}],"frs":[{"id":"FR-9"}],"nfrs":[],"backlog":[]}'
  local out; out="$(sf_synth_brief_assemble ./b.brief.md "$led" /tmp/SRS.md /tmp/MASTER-SPEC.md /tmp/EXECUTIVE-SUMMARY.md)"
  printf '%s' "$out" | grep -q "/tmp/SRS.md" && { echo "  ✓ output path"; PASS=$((PASS+1)); } || { echo "  ✗"; FAIL=$((FAIL+1)); }
  printf '%s' "$out" | grep -q "UC-1" && { echo "  ✓ consumed UC"; PASS=$((PASS+1)); } || { echo "  ✗"; FAIL=$((FAIL+1)); }
  printf '%s' "$out" | grep -q "FR-9" && { echo "  ✗ leaked non-consumed family"; FAIL=$((FAIL+1)); } || { echo "  ✓ FR slice excluded"; PASS=$((PASS+1)); }
}

test_coverage_report_flags_unassigned() {
  echo "test_coverage_report_flags_unassigned:"
  local led='{"use_cases":[],"frs":[{"id":"FR-1"},{"id":"FR-2"}],"nfrs":[{"id":"NFR-1"}],"backlog":[]}'
  local covered=$'FR-1\nNFR-1'
  local out; out="$(sf_synth_coverage_report "$led" "$covered")"
  printf '%s' "$out" | grep -q "FR-2: UNASSIGNED" && { echo "  ✓ unassigned flagged"; PASS=$((PASS+1)); } || { echo "  ✗"; FAIL=$((FAIL+1)); }
  printf '%s' "$out" | grep -q "FR-1: covered" && { echo "  ✓ covered shown"; PASS=$((PASS+1)); } || { echo "  ✗"; FAIL=$((FAIL+1)); }
}

# CI gate: every shipped synthesis brief must validate.
test_all_shipped_briefs_validate() {
  echo "test_all_shipped_briefs_validate:"
  local b
  for b in "$PLUGIN_ROOT"/templates/synthesis-briefs/*.brief.md; do
    if sf_synth_brief_validate "$b" 2>/dev/null; then
      PASS=$((PASS+1)); echo "  ✓ valid: $(basename "$b")"
    else
      FAIL=$((FAIL+1)); echo "  ✗ INVALID: $(basename "$b")"
    fi
  done
}

test_project_name_prefers_explicit_answer
test_project_name_no_emdash_truncation_fallback
test_synth_enabled_default_on
test_synth_enabled_fast_flag
test_brief_field_scalar
test_brief_required_sections_list
test_brief_validate_ok
test_brief_validate_missing_key
test_ledger_merge_concats_families
test_validate_cited_ids_present
test_validate_cited_ids_missing
test_no_fillin_markers_pass_and_fail
test_brief_assemble_includes_paths_and_ledger_slice
test_coverage_report_flags_unassigned
test_all_shipped_briefs_validate
report_results
