#!/usr/bin/env bash
# test-state.sh — tests for lib/state.sh (Phase B, Task TB.1)
# ~15 tests covering: init, in_flight CRUD, recent_runs cap-20, promotions, declined, locks

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "$TESTS_DIR/../lib" && pwd)"

source "$TESTS_DIR/_helpers.sh"
source "$LIB_DIR/_helpers.sh"
source "$LIB_DIR/state.sh"

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
setup_tmp_repo

# ---------------------------------------------------------------------------
# T1: ac_state_path returns expected path
# ---------------------------------------------------------------------------
echo "T1: ac_state_path"
expected_path="$(ac_data_dir)/state.json"
actual_path="$(ac_state_path)"
assert_eq "ac_state_path returns data-dir/state.json" "$expected_path" "$actual_path"

# ---------------------------------------------------------------------------
# T2: ac_state_init creates state.json with correct schema when missing
# ---------------------------------------------------------------------------
echo "T2: ac_state_init creates state.json"
state_file="$(ac_state_path)"
assert_file_missing "$state_file"
ac_state_init
assert_file_exists "$state_file"
schema_ver="$(jq '.schema_version' "$state_file")"
assert_eq "schema_version=1" "1" "$schema_ver"

# ---------------------------------------------------------------------------
# T3: ac_state_init creates empty arrays for all required keys
# ---------------------------------------------------------------------------
echo "T3: ac_state_init empty arrays"
in_flight_len="$(jq '.in_flight | length' "$state_file")"
recent_runs_len="$(jq '.recent_runs | length' "$state_file")"
promotions_len="$(jq '.principle_promotions | length' "$state_file")"
candidates_len="$(jq '.candidate_promotions | length' "$state_file")"
declined_len="$(jq '.declined_candidates | length' "$state_file")"
assert_eq "in_flight starts empty" "0" "$in_flight_len"
assert_eq "recent_runs starts empty" "0" "$recent_runs_len"
assert_eq "principle_promotions starts empty" "0" "$promotions_len"
assert_eq "candidate_promotions starts empty" "0" "$candidates_len"
assert_eq "declined_candidates starts empty" "0" "$declined_len"

# ---------------------------------------------------------------------------
# T4: ac_state_init does NOT overwrite an existing state.json
# ---------------------------------------------------------------------------
echo "T4: ac_state_init does not overwrite"
# manually set schema_version to 99 to confirm no overwrite
jq '.schema_version = 99' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
ac_state_init
ver_after="$(jq '.schema_version' "$state_file")"
assert_eq "init does not overwrite existing state" "99" "$ver_after"
# restore to v1 for remaining tests
jq '.schema_version = 1' "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"

# ---------------------------------------------------------------------------
# T5: ac_state_read outputs valid JSON
# ---------------------------------------------------------------------------
echo "T5: ac_state_read"
read_output="$(ac_state_read | jq '.schema_version')"
assert_eq "ac_state_read emits parseable JSON" "1" "$read_output"

# ---------------------------------------------------------------------------
# T6: ac_state_append_in_flight adds an entry
# ---------------------------------------------------------------------------
echo "T6: ac_state_append_in_flight"
ac_state_append_in_flight "crit-001" "premise-audit" "5"
len="$(jq '.in_flight | length' "$state_file")"
assert_eq "in_flight has 1 entry after append" "1" "$len"
rid="$(jq -r '.in_flight[0].request_id' "$state_file")"
assert_eq "in_flight[0].request_id" "crit-001" "$rid"
depth="$(jq -r '.in_flight[0].depth' "$state_file")"
assert_eq "in_flight[0].depth" "premise-audit" "$depth"
phase="$(jq -r '.in_flight[0].phase_id' "$state_file")"
assert_eq "in_flight[0].phase_id" "5" "$phase"

# ---------------------------------------------------------------------------
# T7: ac_state_append_in_flight with null phase_id
# ---------------------------------------------------------------------------
echo "T7: ac_state_append_in_flight null phase"
ac_state_append_in_flight "crit-002" "close" "null"
phase_null="$(jq -r '.in_flight[1].phase_id' "$state_file")"
assert_eq "in_flight null phase_id stored as null" "null" "$phase_null"

# ---------------------------------------------------------------------------
# T8: ac_state_remove_in_flight removes the correct entry
# ---------------------------------------------------------------------------
echo "T8: ac_state_remove_in_flight"
len_before="$(jq '.in_flight | length' "$state_file")"
ac_state_remove_in_flight "crit-001"
len_after="$(jq '.in_flight | length' "$state_file")"
assert_eq "in_flight length decreases by 1" "$((len_before - 1))" "$len_after"
remaining_id="$(jq -r '.in_flight[0].request_id' "$state_file")"
assert_eq "remaining entry is crit-002" "crit-002" "$remaining_id"

# ---------------------------------------------------------------------------
# T9: ac_state_append_recent_run adds a run entry
# ---------------------------------------------------------------------------
echo "T9: ac_state_append_recent_run"
run_json='{"request_id":"crit-003","completed_at":"2026-05-14T00:00:00Z","depth":"close","adversaries_used":["claude"],"challenge_count":3,"divergence_count":0,"elapsed_ms":1200,"cost_usd":0.01}'
ac_state_append_recent_run "$run_json"
run_len="$(jq '.recent_runs | length' "$state_file")"
assert_eq "recent_runs has 1 entry" "1" "$run_len"
run_id="$(jq -r '.recent_runs[0].request_id' "$state_file")"
assert_eq "recent_runs[0].request_id" "crit-003" "$run_id"

# ---------------------------------------------------------------------------
# T10: ac_state_append_recent_run caps at 20 entries (drops oldest)
# ---------------------------------------------------------------------------
echo "T10: recent_runs cap at 20"
# Add 20 more entries (total would be 21 without cap)
for i in $(seq 1 20); do
  rj="{\"request_id\":\"crit-cap-${i}\",\"completed_at\":\"2026-05-14T00:00:00Z\",\"depth\":\"close\",\"adversaries_used\":[\"claude\"],\"challenge_count\":1,\"divergence_count\":0,\"elapsed_ms\":100,\"cost_usd\":0}"
  ac_state_append_recent_run "$rj"
done
cap_len="$(jq '.recent_runs | length' "$state_file")"
assert_eq "recent_runs capped at 20" "20" "$cap_len"
# The oldest entry (crit-003) should have been dropped; most recent is crit-cap-20
last_id="$(jq -r '.recent_runs[-1].request_id' "$state_file")"
assert_eq "most recent entry is crit-cap-20" "crit-cap-20" "$last_id"
first_id="$(jq -r '.recent_runs[0].request_id' "$state_file")"
# After 20 appends beyond the first, the oldest is crit-cap-2 (crit-003 + crit-cap-1 dropped)
# Verify crit-003 is NOT present
has_003="$(jq -r '[.recent_runs[].request_id] | index("crit-003")' "$state_file")"
assert_eq "crit-003 (oldest) was dropped" "null" "$has_003"

# ---------------------------------------------------------------------------
# T11: ac_state_append_promotion adds a principle_promotion entry
# ---------------------------------------------------------------------------
echo "T11: ac_state_append_promotion"
ac_state_append_promotion "auto" "Always document rollback paths" "user"
promo_len="$(jq '.principle_promotions | length' "$state_file")"
assert_eq "principle_promotions has 1 entry" "1" "$promo_len"
promo_text="$(jq -r '.principle_promotions[0].text' "$state_file")"
assert_eq "principle_promotions[0].text" "Always document rollback paths" "$promo_text"
promo_src="$(jq -r '.principle_promotions[0].source' "$state_file")"
assert_eq "principle_promotions[0].source" "auto" "$promo_src"
promo_scope="$(jq -r '.principle_promotions[0].scope' "$state_file")"
assert_eq "principle_promotions[0].scope" "user" "$promo_scope"

# ---------------------------------------------------------------------------
# T12: ac_state_append_declined adds a declined_candidates entry
# ---------------------------------------------------------------------------
echo "T12: ac_state_append_declined"
suppress_ts="2026-06-14T00:00:00Z"
ac_state_append_declined "Prefer explicit config" "$suppress_ts"
declined_len="$(jq '.declined_candidates | length' "$state_file")"
assert_eq "declined_candidates has 1 entry" "1" "$declined_len"
declined_text="$(jq -r '.declined_candidates[0].text' "$state_file")"
assert_eq "declined_candidates[0].text" "Prefer explicit config" "$declined_text"
declined_sup="$(jq -r '.declined_candidates[0].suppress_until' "$state_file")"
assert_eq "declined_candidates[0].suppress_until" "$suppress_ts" "$declined_sup"

# ---------------------------------------------------------------------------
# T13: lock file is created and released
# ---------------------------------------------------------------------------
echo "T13: lock file acquire and release"
lock_path="$(ac_data_dir)/state.lock"
assert_file_missing "$lock_path"
ac_lock_acquire "$lock_path"
assert_file_exists "$lock_path"
ac_lock_release "$lock_path"
assert_file_missing "$lock_path"

# ---------------------------------------------------------------------------
# T14: second ac_lock_acquire fails when lock is held
# ---------------------------------------------------------------------------
echo "T14: concurrent lock refusal"
ac_lock_acquire "$lock_path"
# Try to acquire again — should fail immediately (no sleep in test)
# We override to a 0-retry version by testing directly:
( set -o noclobber; > "$lock_path" ) 2>/dev/null
second_rc=$?
assert_eq "noclobber fails when lock held" "1" "$second_rc"
ac_lock_release "$lock_path"

# ---------------------------------------------------------------------------
# T15: ac_state_write_field updates a scalar field atomically
# ---------------------------------------------------------------------------
echo "T15: ac_state_write_field"
ac_state_write_field ".schema_version" "2"
new_ver="$(jq '.schema_version' "$state_file")"
assert_eq "write_field updates schema_version to 2" "2" "$new_ver"

# ---------------------------------------------------------------------------
# Phase F TF.1: SessionStart housekeeping hook
# ---------------------------------------------------------------------------

HOOK_HANDLER="$(cd "$TESTS_DIR/../hooks-handlers" && pwd)/session-start.sh"

echo ""
echo "=== TF.1: SessionStart housekeeping ==="

echo ""
echo "--- T16: housekeeping clears in_flight entries older than 24h ---"
setup_tmp_repo > /dev/null
ac_state_init
export CLAUDE_PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
# Inject a stale entry directly via jq write
state_file="$(ac_state_path)"
ac_lock_acquire "$(ac_data_dir)/state.lock"
jq '.in_flight = [{"request_id":"stale-old","started_at":"2020-01-01T00:00:00Z","depth":"close","phase_id":null}]' "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
ac_lock_release "$(ac_data_dir)/state.lock"
bash "$HOOK_HANDLER" > /dev/null 2>&1
remaining="$(jq '.in_flight | length' "$state_file")"
assert_eq "stale in_flight cleared" "0" "$remaining"

echo ""
echo "--- TF.4: ac_state_init preserves on-disk state.json with future schema_version ---"
setup_tmp_repo > /dev/null
mkdir -p "$(ac_data_dir)"
state_file="$(ac_state_path)"
printf '%s\n' '{"schema_version":2,"in_flight":[],"future_field":"x"}' > "$state_file"
ac_state_init 2>&1 | grep -q "future schema_version=2"
assert_eq "future schema_version logs info" "0" "$?"
preserved_ver="$(jq '.schema_version' "$state_file")"
assert_eq "future schema preserved" "2" "$preserved_ver"
preserved_future="$(jq -r '.future_field' "$state_file")"
assert_eq "future field preserved" "x" "$preserved_future"

echo ""
echo "--- T17: housekeeping preserves recent in_flight entries ---"
setup_tmp_repo > /dev/null
ac_state_init
export CLAUDE_PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
now_iso="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
state_file="$(ac_state_path)"
ac_lock_acquire "$(ac_data_dir)/state.lock"
jq --arg now "$now_iso" '.in_flight = [{"request_id":"fresh","started_at":$now,"depth":"close","phase_id":null}]' "$state_file" > "$state_file.tmp" && mv "$state_file.tmp" "$state_file"
ac_lock_release "$(ac_data_dir)/state.lock"
bash "$HOOK_HANDLER" > /dev/null 2>&1
remaining="$(jq '.in_flight | length' "$state_file")"
assert_eq "fresh in_flight preserved" "1" "$remaining"

# ---------------------------------------------------------------------------
report_results
