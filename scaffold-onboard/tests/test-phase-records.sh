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
  assert_eq "invalid-json write leaves record absent" "null" "$(sf_state_read_phase_record 3)"
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
  sf_state_write_phase_record 3 "$rec"
  sf_state_write_phase_record 1 "$rec"
  sf_state_write_phase_record 3 "$rec"   # duplicate phase — must not double-list
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

test_phase_record_rejects_non_object_json() {
  echo "test_phase_record_rejects_non_object_json:"
  setup_tmp_repo
  sf_state_init
  local arr="$TMP_DIR/arr.json"
  printf '[1,2,3]' > "$arr"
  assert_exit_code 1 sf_state_write_phase_record 3 "$arr"
  # state file must be intact (valid JSON, still has answers key) after the rejected write
  assert_eq "state still valid json after rejected array write" "object" "$(jq -r 'type' "$(sf_state_path)")"
}

test_phase_record_rejects_non_object_json

test_legacy_state_migrates_on_write() {
  echo "test_legacy_state_migrates_on_write:"
  setup_tmp_repo
  # A pre-SS-3 (v0.2.x) state file: no schema_version, no phase_records,
  # no touched_this_run — only flat answers. This is the upgrade input class.
  local path; path="$(sf_state_path)"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<JSON
{
  "status": "in_progress",
  "current_phase": 4,
  "project_root": "$(sf_project_identity_root)",
  "created_at": "2026-06-01T00:00:00Z",
  "updated_at": "2026-06-01T00:00:00Z",
  "answers": { "1.1.1": "legacy-app — a thing", "1.3.1": "CLI tool" }
}
JSON
  # Reads must not crash on the missing keys.
  assert_eq "legacy read_phase_record null" "null" "$(sf_state_read_phase_record 1)"
  assert_eq "legacy touched empty" "" "$(sf_state_phases_touched_this_run | tr -d '\n')"
  # First write upgrades the file without dropping the legacy answers.
  local rec="$TMP_DIR/r.json"; printf '{"decisions":"keep going"}' > "$rec"
  sf_state_write_phase_record 4 "$rec"
  assert_file_contains "$path" '"schema_version": 2'
  assert_eq "legacy answer preserved" "legacy-app — a thing" "$(sf_state_read_answer 1.1.1)"
  assert_eq "new record present" "keep going" "$(sf_state_read_phase_record 4 | jq -r '.decisions')"
}

test_legacy_state_migrates_on_write

test_synthesis_digest_includes_answers_and_records() {
  echo "test_synthesis_digest_includes_answers_and_records:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.1" "todo-cli — a fast task manager"
  sf_state_write_answer "1.3.1" "CLI tool"
  local rec="$TMP_DIR/r1.json"
  printf '{"decisions":"single JSON file","rationale":"no DB requested"}' > "$rec"
  sf_state_write_phase_record 1 "$rec"
  local digest; digest="$(sf_state_synthesis_digest)"
  printf '%s' "$digest" | grep -q "1.1.1" || { echo "  ✗ missing qid"; exit 1; }
  printf '%s' "$digest" | grep -q "todo-cli — a fast task manager" || { echo "  ✗ missing raw answer"; exit 1; }
  printf '%s' "$digest" | grep -q "single JSON file" || { echo "  ✗ missing record decision"; exit 1; }
  printf '%s' "$digest" | grep -q "no DB requested" || { echo "  ✗ missing record rationale"; exit 1; }
  PASS=$((PASS+1)); echo "  ✓ digest carries answers + phase records"
}

test_synthesis_digest_includes_answers_and_records

report_results
