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

test_phase_record_round_trip() {
  echo "test_phase_record_round_trip:"
  setup_tmp_repo
  sf_state_init
  local rec="$TMP_DIR/rec3.json"
  cat > "$rec" <<'JSON'
{
  "decisions": "Store data in a single JSON file under ~/.app.",
  "rationale": "Zero-dependency persistence; user requested no DB.",
  "alternatives_rejected": "SQLite (overkill for <1k rows).",
  "constraints": "Must survive a kill -9 mid-write (atomic rename).",
  "open_questions": "Encryption at rest?",
  "critic_outcomes": "premise-audit: single-file lock contention flagged; accepted advisory note."
}
JSON
  sf_state_write_phase_record 3 "$rec"
  local got
  got="$(sf_state_read_phase_record 3 | jq -r '.decisions')"
  assert_eq "decisions round-trip" "Store data in a single JSON file under ~/.app." "$got"
}

test_phase_record_round_trip

test_phase_record_rejects_invalid_json() {
  echo "test_phase_record_rejects_invalid_json:"
  setup_tmp_repo
  sf_state_init
  local bad="$TMP_DIR/bad.json"
  printf 'not json {{' > "$bad"
  assert_exit_code 1 sf_state_write_phase_record 3 "$bad"
}

test_phase_record_rejects_invalid_json

test_read_missing_phase_record_is_null() {
  echo "test_read_missing_phase_record_is_null:"
  setup_tmp_repo
  sf_state_init
  assert_eq "missing record reads null" "null" "$(sf_state_read_phase_record 7)"
}

test_read_missing_phase_record_is_null

test_touched_this_run_tracks_writes() {
  echo "test_touched_this_run_tracks_writes:"
  setup_tmp_repo
  sf_state_init
  local rec="$TMP_DIR/r.json"; printf '{"decisions":"x"}' > "$rec"
  sf_state_write_phase_record 1 "$rec"
  sf_state_write_phase_record 3 "$rec"
  sf_state_write_phase_record 1 "$rec"   # duplicate phase — must not double-list
  assert_eq "touched is unique+sorted" "1 3" "$(sf_state_phases_touched_this_run | tr '\n' ' ' | sed 's/ $//')"
}

test_touched_this_run_tracks_writes

test_run_reset_clears_touched() {
  echo "test_run_reset_clears_touched:"
  setup_tmp_repo
  sf_state_init
  local rec="$TMP_DIR/r.json"; printf '{"decisions":"x"}' > "$rec"
  sf_state_write_phase_record 4 "$rec"
  sf_state_run_reset
  assert_eq "touched empty after reset" "" "$(sf_state_phases_touched_this_run | tr -d '\n')"
}

test_run_reset_clears_touched

report_results
