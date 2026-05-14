#!/usr/bin/env bash
# test-inbox.sh — tests for architect-critic/lib/inbox.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/_helpers.sh"
source "$PLUGIN_ROOT/lib/_helpers.sh"
source "$PLUGIN_ROOT/lib/inbox.sh"

setup_tmp_repo

TINY_SPEC="$SCRIPT_DIR/fixtures/master-specs/tiny-spec.md"

# ---------------------------------------------------------------------------
# Helper: build a valid envelope JSON
# ---------------------------------------------------------------------------
valid_envelope() {
  local spec_path="${1:-$TINY_SPEC}"
  jq -n \
    --arg rid "crit-2026-01-01T00:00:00-phase-abc" \
    --arg spec "$spec_path" \
    '{
      request_id: $rid,
      depth: "premise-audit",
      adversaries: ["claude"],
      target: {
        type: "master-spec-phase",
        path: $spec,
        phase_id: 3
      },
      sources: {
        principles: "/tmp/nonexistent-principles.md",
        accumulated_phases: [1, 2, 3]
      },
      concession_threshold: 4,
      project_class: "web-app"
    }'
}

# ---------------------------------------------------------------------------
# Test 1: ac_inbox_dir returns data-dir/inbox
# ---------------------------------------------------------------------------
echo "=== ac_inbox_dir ==="
expected_dir="$(ac_data_dir)/inbox"
actual_dir="$(ac_inbox_dir)"
assert_eq "ac_inbox_dir returns data-dir/inbox" "$expected_dir" "$actual_dir"

# ---------------------------------------------------------------------------
# Test 2: ac_inbox_path returns inbox/<id>.json
# ---------------------------------------------------------------------------
echo "=== ac_inbox_path ==="
rid="crit-test-123"
expected_path="$(ac_inbox_dir)/${rid}.json"
actual_path="$(ac_inbox_path "$rid")"
assert_eq "ac_inbox_path <id> returns inbox/<id>.json" "$expected_path" "$actual_path"

# ---------------------------------------------------------------------------
# Test 3: ac_inbox_read returns non-zero when file missing
# ---------------------------------------------------------------------------
echo "=== ac_inbox_read missing ==="
set +e
ac_inbox_read "no-such-request-id-xyz" >/dev/null 2>&1
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  echo "  ✓ ac_inbox_read returns non-zero for missing file"; PASS=$((PASS+1))
else
  echo "  ✗ ac_inbox_read should return non-zero for missing file (got $ec)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 4: ac_inbox_read returns contents when file exists
# ---------------------------------------------------------------------------
echo "=== ac_inbox_read existing ==="
mkdir -p "$(ac_inbox_dir)"
test_rid="crit-test-read-456"
test_path="$(ac_inbox_path "$test_rid")"
printf '{"request_id":"%s"}' "$test_rid" > "$test_path"
read_output="$(ac_inbox_read "$test_rid" 2>/dev/null)"
if echo "$read_output" | jq -e --arg rid "$test_rid" '.request_id == $rid' >/dev/null 2>&1; then
  echo "  ✓ ac_inbox_read returns file contents"; PASS=$((PASS+1))
else
  echo "  ✗ ac_inbox_read returned unexpected output: $read_output"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 5: valid envelope passes validation
# ---------------------------------------------------------------------------
echo "=== ac_inbox_validate valid envelope ==="
env_json="$(valid_envelope)"
set +e
ac_inbox_validate "$env_json" 2>/dev/null
ec=$?
set -e
assert_eq "valid envelope passes validation (exit 0)" "0" "$ec"

# ---------------------------------------------------------------------------
# Test 6: missing / empty request_id fails (rule 1)
# ---------------------------------------------------------------------------
echo "=== rule 1: request_id ==="
bad_env="$(valid_envelope | jq '.request_id = ""')"
set +e
ac_inbox_validate "$bad_env" 2>/dev/null
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  echo "  ✓ empty request_id fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ empty request_id should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 7: invalid depth fails (rule 2)
# ---------------------------------------------------------------------------
echo "=== rule 2: depth ==="
bad_env="$(valid_envelope | jq '.depth = "bad-depth"')"
set +e
ac_inbox_validate "$bad_env" 2>/dev/null
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  echo "  ✓ invalid depth fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ invalid depth should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 8: invalid adversary entry fails (rule 3)
# ---------------------------------------------------------------------------
echo "=== rule 3: adversaries ==="
bad_env="$(valid_envelope | jq '.adversaries = ["gpt4"]')"
set +e
ac_inbox_validate "$bad_env" 2>/dev/null
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  echo "  ✓ invalid adversary entry fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ invalid adversary entry should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

# empty adversaries array also fails
bad_env2="$(valid_envelope | jq '.adversaries = []')"
set +e
ac_inbox_validate "$bad_env2" 2>/dev/null
ec2=$?
set -e
if [[ "$ec2" -ne 0 ]]; then
  echo "  ✓ empty adversaries array fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ empty adversaries array should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 9: invalid target.type fails (rule 4)
# ---------------------------------------------------------------------------
echo "=== rule 4: target.type ==="
bad_env="$(valid_envelope | jq '.target.type = "other-type"')"
set +e
ac_inbox_validate "$bad_env" 2>/dev/null
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  echo "  ✓ invalid target.type fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ invalid target.type should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 10: unreadable target.path fails (rule 5)
# ---------------------------------------------------------------------------
echo "=== rule 5: target.path readable ==="
bad_env="$(valid_envelope | jq '.target.path = "/no/such/file/ever.md"')"
set +e
ac_inbox_validate "$bad_env" 2>/dev/null
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  echo "  ✓ unreadable target.path fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ unreadable target.path should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 11: phase_id out of range fails (rule 6)
# ---------------------------------------------------------------------------
echo "=== rule 6: phase_id range ==="
bad_env="$(valid_envelope | jq '.target.phase_id = 11')"
set +e
ac_inbox_validate "$bad_env" 2>/dev/null
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  echo "  ✓ phase_id=11 fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ phase_id=11 should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

bad_env2="$(valid_envelope | jq '.target.phase_id = 0')"
set +e
ac_inbox_validate "$bad_env2" 2>/dev/null
ec2=$?
set -e
if [[ "$ec2" -ne 0 ]]; then
  echo "  ✓ phase_id=0 fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ phase_id=0 should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

# master-spec-full does NOT require phase_id — should pass without it
full_env="$(valid_envelope | jq '.target.type = "master-spec-full" | del(.target.phase_id)')"
set +e
ac_inbox_validate "$full_env" 2>/dev/null
ec3=$?
set -e
assert_eq "master-spec-full passes without phase_id" "0" "$ec3"

# ---------------------------------------------------------------------------
# Test 12: non-array accumulated_phases fails (rule 7)
# ---------------------------------------------------------------------------
echo "=== rule 7: accumulated_phases array ==="
bad_env="$(valid_envelope | jq '.sources.accumulated_phases = "1,2,3"')"
set +e
ac_inbox_validate "$bad_env" 2>/dev/null
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  echo "  ✓ non-array accumulated_phases fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ non-array accumulated_phases should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 13: concession_threshold out of range fails (rule 8)
# ---------------------------------------------------------------------------
echo "=== rule 8: concession_threshold range ==="
bad_env="$(valid_envelope | jq '.concession_threshold = 6')"
set +e
ac_inbox_validate "$bad_env" 2>/dev/null
ec=$?
set -e
if [[ "$ec" -ne 0 ]]; then
  echo "  ✓ concession_threshold=6 fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ concession_threshold=6 should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

bad_env2="$(valid_envelope | jq '.concession_threshold = 0')"
set +e
ac_inbox_validate "$bad_env2" 2>/dev/null
ec2=$?
set -e
if [[ "$ec2" -ne 0 ]]; then
  echo "  ✓ concession_threshold=0 fails validation"; PASS=$((PASS+1))
else
  echo "  ✗ concession_threshold=0 should fail validation (got exit 0)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 14: missing principles file warns but accepts (warning, not error)
# ---------------------------------------------------------------------------
echo "=== warning: missing principles file ==="
# The valid_envelope already uses /tmp/nonexistent-principles.md
env_json="$(valid_envelope)"
set +e
warn_output="$(ac_inbox_validate "$env_json" 2>&1)"
ec=$?
set -e
assert_eq "missing principles file accepts (exit 0)" "0" "$ec"
if echo "$warn_output" | grep -qi "warn"; then
  echo "  ✓ missing principles file emits a warning"; PASS=$((PASS+1))
else
  echo "  ✗ missing principles file should emit a warning (got: $warn_output)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
# Test 15: null project_class warns but accepts
# ---------------------------------------------------------------------------
echo "=== warning: null project_class ==="
env_json="$(valid_envelope | jq '.project_class = null')"
set +e
warn_output="$(ac_inbox_validate "$env_json" 2>&1)"
ec=$?
set -e
assert_eq "null project_class accepts (exit 0)" "0" "$ec"
if echo "$warn_output" | grep -qi "warn"; then
  echo "  ✓ null project_class emits a warning"; PASS=$((PASS+1))
else
  echo "  ✗ null project_class should emit a warning (got: $warn_output)"; FAIL=$((FAIL+1))
fi

# ---------------------------------------------------------------------------
report_results
