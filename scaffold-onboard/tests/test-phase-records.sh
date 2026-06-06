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

# Fix 2: sf_state_mark_touched — pre-write crash-safety marker
test_mark_touched_adds_phase_to_tracker() {
  echo "test_mark_touched_adds_phase_to_tracker:"
  setup_tmp_repo
  sf_state_init
  # Mark phase 4 touched WITHOUT writing a phase record (simulates start of revision
  # before any answer overwrites — the crash-safety pre-write required by Fix 2).
  sf_state_mark_touched 4
  local touched
  touched="$(sf_state_phases_touched_this_run | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "mark_touched 4 appears in tracker" "4" "$touched"
  # No phase record should exist yet (we only marked touched, didn't write a record).
  assert_eq "no phase record yet after mark_touched" "null" "$(sf_state_read_phase_record 4)"
}

test_mark_touched_adds_phase_to_tracker

test_mark_touched_is_idempotent() {
  echo "test_mark_touched_is_idempotent:"
  setup_tmp_repo
  sf_state_init
  # Calling mark_touched twice for the same phase must not double-list it.
  sf_state_mark_touched 4
  sf_state_mark_touched 4
  local touched
  touched="$(sf_state_phases_touched_this_run | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "mark_touched twice does not double-list phase 4" "4" "$touched"
}

test_mark_touched_is_idempotent

test_mark_touched_coexists_with_write_phase_record() {
  echo "test_mark_touched_coexists_with_write_phase_record:"
  setup_tmp_repo
  sf_state_init
  # mark_touched first (pre-write marker), then write the record — both use unique-append
  # so the phase should appear exactly once in touched_this_run.
  sf_state_mark_touched 3
  local rec="$TMP_DIR/r.json"; printf '{"decisions":"folded forward"}' > "$rec"
  sf_state_write_phase_record 3 "$rec"
  local touched
  touched="$(sf_state_phases_touched_this_run | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "mark_touched + write_phase_record gives exactly one entry" "3" "$touched"
  # Record must be persisted correctly.
  assert_eq "record present after mark+write" "folded forward" "$(sf_state_read_phase_record 3 | jq -r '.decisions')"
}

test_mark_touched_coexists_with_write_phase_record

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

test_state_write_failure_does_not_replace_state() {
  echo "test_state_write_failure_does_not_replace_state:"
  setup_tmp_repo
  sf_state_init
  local path before
  path="$(sf_state_path)"
  before="$(cat "$path")"
  # Corrupt the on-disk state so jq cannot parse the input file. The helper must
  # return non-zero and leave the original bytes in place rather than mv'ing an
  # empty/partial temp file over the state path.
  printf '{not json' > "$path"
  assert_exit_code 1 sf_state_write_answer "1.1.9" "lost?"
  assert_eq "failed write leaves original state bytes" "{not json" "$(cat "$path")"
  printf '%s' "$before" > "$path"
  assert_eq "restored fixture remains valid json" "object" "$(jq -r 'type' "$path")"
}

test_state_write_failure_does_not_replace_state

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
  # project_class = "CLI tool" activates the 6A branch, not the 6B branch.
  sf_state_write_answer "1.3.1" "CLI tool"
  sf_state_write_answer "6A.1.1" "CLI"
  # Stale 6B answer written as if from a prior onboard that used a different class.
  sf_state_write_answer "6B.1.1" "API docs"
  local rec="$TMP_DIR/r1.json"
  printf '{"decisions":"single JSON file","rationale":"no DB requested"}' > "$rec"
  sf_state_write_phase_record 1 "$rec"
  local digest_file="$TMP_DIR/digest.md"
  sf_state_synthesis_digest > "$digest_file"
  assert_file_contains "$digest_file" "1\.1\.1"
  assert_file_contains "$digest_file" "todo-cli — a fast task manager"
  assert_file_contains "$digest_file" "single JSON file"
  assert_file_contains "$digest_file" "no DB requested"
  # 6A.1.1 is in the active branch for "CLI tool" — must appear.
  assert_file_contains "$digest_file" "6A\.1\.1"
  assert_file_contains "$digest_file" "CLI"
  # 6B.1.1 is in the INACTIVE branch for "CLI tool" — must NOT appear in digest.
  assert_file_not_contains "$digest_file" "6B\.1\.1"
  assert_file_not_contains "$digest_file" "API docs"
}

test_synthesis_digest_includes_answers_and_records

test_phase_artifact_includes_answers_and_record() {
  echo "test_phase_artifact_includes_answers_and_record:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "5.1.1" "sqlite with FTS5"
  local rec="$TMP_DIR/r5.json"
  printf '{"decisions":"sqlite","critic_outcomes":["confirmed FTS5"]}' > "$rec"
  sf_state_write_phase_record 5 "$rec"
  local artifact="$TMP_DIR/phase-5.md"
  sf_state_write_phase_artifact 5 "$artifact"
  assert_file_contains "$artifact" "Phase 5 recap artifact"
  assert_file_contains "$artifact" "5\.1\.1"
  assert_file_contains "$artifact" "sqlite with FTS5"
  assert_file_contains "$artifact" "confirmed FTS5"
}

test_phase_artifact_includes_answers_and_record

test_phase_artifact_includes_phase6_gated_answers() {
  echo "test_phase_artifact_includes_phase6_gated_answers:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "6A.1.1" "CLI"
  sf_state_write_answer "6B.1.2" "OpenAPI"
  local artifact="$TMP_DIR/phase-6.md"
  sf_state_write_phase_artifact 6 "$artifact"
  assert_file_contains "$artifact" "6A\.1\.1"
  assert_file_contains "$artifact" "CLI"
  assert_file_contains "$artifact" "6B\.1\.2"
  assert_file_contains "$artifact" "OpenAPI"
}

test_phase_artifact_includes_phase6_gated_answers

test_synthesis_digest_errors_without_state() {
  echo "test_synthesis_digest_errors_without_state:"
  setup_tmp_repo
  # no sf_state_init — no state file exists
  assert_exit_code 1 sf_state_synthesis_digest
}

test_synthesis_digest_errors_without_state

# Fix 5: sf_state_synthesis_digest gate-filter test.
# Seeds a project_class that activates the 6A branch (CLI tool), writes both an
# active-branch answer (6A.1.1) and a stale inactive-branch answer (6B.1.1).
# Asserts the digest INCLUDES the active answer and EXCLUDES the inactive one.
# Phase 6 in phases.yaml: 6A gate = "project_class in {Web app, Mobile app, CLI tool, ML or AI system, Agent or plugin, Other}";
#                          6B gate = "project_class in {Library or SDK, Data pipeline, Web service (API only)}".
test_synthesis_digest_filters_inactive_branch_answers() {
  echo "test_synthesis_digest_filters_inactive_branch_answers:"
  setup_tmp_repo
  sf_state_init
  # "CLI tool" activates 6A (gate passes), not 6B (gate fails).
  sf_state_write_answer "1.3.1" "CLI tool"
  # Active 6A branch answer — should appear in digest.
  sf_state_write_answer "6A.1.1" "CLI surfaces only"
  sf_state_write_answer "6A.1.2" "user types todo add, sees list"
  # Stale 6B branch answer (from e.g. a prior onboard where class was Library) — must NOT appear.
  sf_state_write_answer "6B.1.1" "stale-api-docs-answer"
  sf_state_write_answer "6B.1.2" "stale-error-style-answer"
  local digest_file="$TMP_DIR/digest-gate-filter.md"
  sf_state_synthesis_digest > "$digest_file"
  # Active branch answers must be present.
  assert_file_contains "$digest_file" "6A\.1\.1"
  assert_file_contains "$digest_file" "CLI surfaces only"
  assert_file_contains "$digest_file" "6A\.1\.2"
  # Inactive branch answers must be excluded.
  assert_file_not_contains "$digest_file" "6B\.1\.1"
  assert_file_not_contains "$digest_file" "stale-api-docs-answer"
  assert_file_not_contains "$digest_file" "6B\.1\.2"
  assert_file_not_contains "$digest_file" "stale-error-style-answer"
}

test_synthesis_digest_filters_inactive_branch_answers

test_synthesis_digest_collapses_multiline_answer() {
  echo "test_synthesis_digest_collapses_multiline_answer:"
  setup_tmp_repo
  sf_state_init
  sf_state_write_answer "1.1.2" "$(printf 'line one\nline two')"
  local digest_file="$TMP_DIR/d.md"
  sf_state_synthesis_digest > "$digest_file"
  # The answer must appear on ONE line: "- 1.1.2: line one line two"
  assert_file_contains "$digest_file" "1\.1\.2: line one line two"
  # And there must be no bare "line two" at start-of-line (would mean a broken bullet)
  if grep -qE '^line two' "$digest_file"; then
    FAIL=$((FAIL+1)); echo "  ✗ multiline answer broke the bullet (continuation at line start)"
  else
    PASS=$((PASS+1)); echo "  ✓ multiline answer collapsed to one line"
  fi
}

test_synthesis_digest_collapses_multiline_answer

report_results
