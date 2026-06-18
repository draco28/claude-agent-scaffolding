#!/usr/bin/env bash
# test-state-external-runs.sh — state.json v3 external_runs[] CRUD + v2→v3 migration (#39).
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$(cd "$TESTS_DIR/../lib" && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/_helpers.sh"
source "$LIB_DIR/_helpers.sh"
source "$LIB_DIR/state.sh"

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
ARC="$PLUGIN_ROOT/bin/arc"

echo "=== test-state-external-runs.sh ==="
setup_tmp_repo > /dev/null

echo "-- fresh init is schema v3 with external_runs[] --"
ac_state_init
state_file="$(ac_state_path)"
assert_eq "fresh schema_version=3" "3" "$(jq -r '.schema_version' "$state_file")"
assert_eq "external_runs seeded empty" "0" "$(jq -r '.external_runs | length' "$state_file")"

echo "-- add + get --"
bash "$ARC" state_external_run_add --run-id r1 --host claude --adversary codex \
  --artifact /tmp/spec.md --depth close --result-path "$CLAUDE_PLUGIN_DATA/async/r1/result.json"
assert_eq "added run status running" "running" "$(bash "$ARC" state_external_run_get r1 | jq -r '.status')"
assert_eq "artifact stored" "/tmp/spec.md" "$(bash "$ARC" state_external_run_get r1 | jq -r '.artifact_path')"
assert_exit_code 1 bash "$ARC" state_external_run_get nope

echo "-- set_status terminal stamps completed_at --"
bash "$ARC" state_external_run_set_status r1 completed
assert_eq "status updated" "completed" "$(bash "$ARC" state_external_run_get r1 | jq -r '.status')"
ca="$(bash "$ARC" state_external_run_get r1 | jq -r '.completed_at')"
[[ -n "$ca" && "$ca" != "null" ]] && { echo "  ✓ completed_at stamped"; PASS=$((PASS+1)); } || { echo "  ✗ completed_at not stamped"; FAIL=$((FAIL+1)); }
assert_exit_code 1 bash "$ARC" state_external_run_set_status nope completed

echo "-- list + status filter --"
assert_eq "one completed in list" "1" "$(bash "$ARC" state_external_run_list --status completed | jq 'length')"
assert_eq "zero running in list" "0" "$(bash "$ARC" state_external_run_list --status running | jq 'length')"

echo "-- resolve once; second resolve fails (idempotency guard) --"
assert_exit_code 0 bash "$ARC" state_external_run_resolve r1 req-1
assert_exit_code 1 bash "$ARC" state_external_run_resolve r1 req-2
assert_eq "resolved id pinned" "req-1" "$(bash "$ARC" state_external_run_get r1 | jq -r '.resolved_run_request_id')"

echo "-- migration v2 → v3 (idempotent, preserves recent_runs, no in_flight) --"
printf '%s' '{"schema_version":2,"recent_runs":[{"request_id":"old"}],"principle_promotions":[],"candidate_promotions":[],"declined_candidates":[],"auto_promote_suppressions":[]}' > "$state_file"
bash "$ARC" state_migrate
assert_eq "schema bumped to 3" "3" "$(jq -r '.schema_version' "$state_file")"
assert_eq "external_runs seeded by migration" "0" "$(jq -r '.external_runs | length' "$state_file")"
assert_eq "recent_runs preserved" "old" "$(jq -r '.recent_runs[0].request_id' "$state_file")"
assert_eq "no in_flight after migrate" "null" "$(jq -r '.in_flight // "null"' "$state_file")"
bash "$ARC" state_migrate   # idempotent re-run
assert_eq "still v3 after re-migrate" "3" "$(jq -r '.schema_version' "$state_file")"

report_results
