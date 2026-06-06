#!/usr/bin/env bash
# test-phase-records.sh — SS-3: enriched state schema, phase records,
# touched-this-run tracking, synthesis digest, legacy migration.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/state.sh"
source "$HERE/../lib/routing.sh"

test_init_has_schema_v2_and_phase_records() {
  echo "test_init_has_schema_v2_and_phase_records:"
  setup_tmp_repo
  sf_state_init
  assert_file_contains "$(sf_state_path)" '"schema_version": 2'
  assert_file_contains "$(sf_state_path)" '"phase_records": \{\}'
  assert_file_contains "$(sf_state_path)" '"touched_this_run": \[\]'
}

test_init_has_schema_v2_and_phase_records

report_results
