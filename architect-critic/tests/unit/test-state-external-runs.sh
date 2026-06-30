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

assert_quick_exit_code() {
  local expected="$1"; shift
  local out="$CLAUDE_PLUGIN_DATA/quick-exit.out"
  set +e
  "$@" >"$out" 2>&1 &
  local pid=$!
  sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    echo "  ✗ command did not exit promptly: $*"; FAIL=$((FAIL+1))
    return
  fi
  wait "$pid"
  local ec=$?
  if [[ "$ec" == "$expected" ]]; then
    echo "  ✓ exit code $expected for: $*"; PASS=$((PASS+1))
  else
    echo "  ✗ exit code $expected for: $* (got $ec)"; FAIL=$((FAIL+1))
  fi
}

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
assert_eq "neutral_mode defaults false" "false" "$(bash "$ARC" state_external_run_get r1 | jq -r '.neutral_mode')"
assert_exit_code 1 bash "$ARC" state_external_run_get nope

echo "-- add supports persisted neutral mode --"
bash "$ARC" state_external_run_add --run-id r-neutral --host claude --adversary codex \
  --artifact /tmp/spec-neutral.md --depth close --result-path "$CLAUDE_PLUGIN_DATA/async/r-neutral/result.json" \
  --neutral-mode true
assert_eq "neutral_mode persisted true" "true" "$(bash "$ARC" state_external_run_get r-neutral | jq -r '.neutral_mode')"
bash "$ARC" state_external_run_set_status r-neutral completed >/dev/null

echo "-- set_status terminal stamps completed_at --"
bash "$ARC" state_external_run_set_status r1 completed
assert_eq "status updated" "completed" "$(bash "$ARC" state_external_run_get r1 | jq -r '.status')"
ca="$(bash "$ARC" state_external_run_get r1 | jq -r '.completed_at')"
[[ -n "$ca" && "$ca" != "null" ]] && { echo "  ✓ completed_at stamped"; PASS=$((PASS+1)); } || { echo "  ✗ completed_at not stamped"; FAIL=$((FAIL+1)); }
assert_exit_code 1 bash "$ARC" state_external_run_set_status nope completed
assert_exit_code 2 bash "$ARC" state_external_run_set_status r1 typo-status

echo "-- list + status filter --"
assert_eq "two completed in list" "2" "$(bash "$ARC" state_external_run_list --status completed | jq 'length')"
assert_eq "zero running in list" "0" "$(bash "$ARC" state_external_run_list --status running | jq 'length')"

echo "-- missing flag values fail promptly --"
assert_quick_exit_code 2 bash "$ARC" state_external_run_add --run-id
assert_quick_exit_code 2 bash "$ARC" state_external_run_set_status r1 completed --completed-at
assert_quick_exit_code 2 bash "$ARC" state_external_run_list --status

echo "-- resolve once; second resolve fails (idempotency guard) --"
assert_exit_code 0 bash "$ARC" state_external_run_resolve r1 req-1
assert_exit_code 1 bash "$ARC" state_external_run_resolve r1 req-2
assert_eq "resolved id pinned" "req-1" "$(bash "$ARC" state_external_run_get r1 | jq -r '.resolved_run_request_id')"

echo "-- finalize_resume appends recent run and resolves atomically once --"
bash "$ARC" state_external_run_add --run-id r2 --host claude --adversary codex \
  --artifact /tmp/spec2.md --depth close --result-path "$CLAUDE_PLUGIN_DATA/async/r2/result.json"
assert_exit_code 0 bash "$ARC" state_external_run_finalize_resume \
  --run-id r2 \
  --request-id req-final \
  --depth close \
  --adversaries claude,codex \
  --challenge-count 4 \
  --concessions 2 \
  --deferred-count 1 \
  --deferred-challenges '[{"index":3,"text":"Track deferred async concern"}]' \
  --skill-invoked critiquing-spec \
  --elapsed-ms 1200
assert_exit_code 1 bash "$ARC" state_external_run_finalize_resume \
  --run-id r2 \
  --request-id req-final-dup \
  --depth close \
  --adversaries claude,codex \
  --challenge-count 4 \
  --concessions 2 \
  --skill-invoked critiquing-spec \
  --elapsed-ms 1200
assert_eq "finalize appended once" "1" "$(jq '[.recent_runs[] | select(.request_id | startswith("req-final"))] | length' "$state_file")"
assert_eq "finalize pinned request id" "req-final" "$(bash "$ARC" state_external_run_get r2 | jq -r '.resolved_run_request_id')"
assert_eq "finalize stores deferred_count" "1" "$(jq -r '.recent_runs[-1].deferred_count' "$state_file")"
assert_eq "finalize stores deferred challenge" "Track deferred async concern" "$(jq -r '.recent_runs[-1].deferred_challenges[0].text' "$state_file")"

echo "-- external_runs cap preserves all unresolved jobs --"
printf '%s' '{"schema_version":3,"recent_runs":[],"principle_promotions":[],"candidate_promotions":[],"declined_candidates":[],"auto_promote_suppressions":[],"external_runs":[]}' > "$state_file"
for i in $(seq 1 21); do
  bash "$ARC" state_external_run_add --run-id "run-$i" --host claude --adversary codex \
    --artifact "/tmp/spec-$i.md" --depth close --result-path "/tmp/result-$i.json"
done
assert_eq "all 21 unresolved jobs retained" "21" "$(jq '.external_runs | length' "$state_file")"
assert_eq "oldest unresolved job retained" "run-1" "$(bash "$ARC" state_external_run_get run-1 | jq -r '.run_id')"

echo "-- migration v2 → v3 (idempotent, preserves recent_runs, no in_flight) --"
printf '%s' '{"schema_version":2,"recent_runs":[{"request_id":"old"}],"principle_promotions":[],"candidate_promotions":[],"declined_candidates":[],"auto_promote_suppressions":[]}' > "$state_file"
bash "$ARC" state_migrate
assert_eq "schema bumped to 3" "3" "$(jq -r '.schema_version' "$state_file")"
assert_eq "external_runs seeded by migration" "0" "$(jq -r '.external_runs | length' "$state_file")"
assert_eq "recent_runs preserved" "old" "$(jq -r '.recent_runs[0].request_id' "$state_file")"
assert_eq "no in_flight after migrate" "null" "$(jq -r '.in_flight // "null"' "$state_file")"
bash "$ARC" state_migrate   # idempotent re-run
assert_eq "still v3 after re-migrate" "3" "$(jq -r '.schema_version' "$state_file")"

echo "-- session-start hook surfaces in-flight count --"
bash "$ARC" state_external_run_add --run-id r9 --host claude --adversary codex \
  --artifact /tmp/s.md --depth close --result-path /tmp/r.json
out="$(bash "$PLUGIN_ROOT/hooks-handlers/session-start.sh" 2>&1)"
echo "$out" | grep -qiE "in.?flight|background audit" && { echo "  ✓ hook surfaces in-flight"; PASS=$((PASS+1)); } || { echo "  ✗ hook silent on in-flight"; FAIL=$((FAIL+1)); }
# Hook must never fail the session (fail-open).
assert_exit_code 0 bash "$PLUGIN_ROOT/hooks-handlers/session-start.sh"

echo "-- skill/command surfaces exist --"
JOBSK="$PLUGIN_ROOT/skills/managing-async-critique/SKILL.md"
assert_file_exists "$JOBSK"
for verb in status result cancel resume; do
  grep -qi "$verb" "$JOBSK" && { echo "  ✓ job-manager documents '$verb'"; PASS=$((PASS+1)); } || { echo "  ✗ job-manager missing '$verb'"; FAIL=$((FAIL+1)); }
done
grep -qi "resolved_run_request_id\|inspect-only\|idempoten" "$JOBSK" && { echo "  ✓ resume idempotency documented"; PASS=$((PASS+1)); } || { echo "  ✗ resume idempotency missing"; FAIL=$((FAIL+1)); }
grep -qi "Consolidate + Rebuttal + Append\|critiquing-spec" "$JOBSK" && { echo "  ✓ resume reuses shared procedure"; PASS=$((PASS+1)); } || { echo "  ✗ resume shared-procedure link missing"; FAIL=$((FAIL+1)); }

echo "-- history lists external runs --"
HIST="$PLUGIN_ROOT/skills/reviewing-critique-history/SKILL.md"
grep -qi "external_run\|in-flight\|background" "$HIST" && { echo "  ✓ history mentions external runs"; PASS=$((PASS+1)); } || { echo "  ✗ history missing external runs"; FAIL=$((FAIL+1)); }
grep -qi "recent_runs.*empty.*external_runs.*entries\|continue to Step 4b" "$HIST" && { echo "  ✓ history keeps background runs visible when completed history is empty"; PASS=$((PASS+1)); } || { echo "  ✗ history may hide background runs when recent_runs is empty"; FAIL=$((FAIL+1)); }
grep -q '"schema_version": 3' "$HIST" && { echo "  ✓ history worked example uses schema v3"; PASS=$((PASS+1)); } || { echo "  ✗ history worked example is not schema v3"; FAIL=$((FAIL+1)); }

report_results
