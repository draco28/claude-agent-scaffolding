#!/usr/bin/env bash
# architect-critic tests/test-outbox.sh
# Tests for lib/outbox.sh — response envelope write
# TDD: run BEFORE implementing outbox.sh to confirm red, then again after to confirm green.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
source "$SCRIPT_DIR/../lib/_helpers.sh"
source "$SCRIPT_DIR/../lib/outbox.sh"

# ---------------------------------------------------------------------------
# Minimal consolidated JSON for use in tests (from consolidator output shape)
# ---------------------------------------------------------------------------
MINIMAL_CONSOLIDATED='{
  "challenges": [
    {"severity": "premise", "text": "Missing fallback", "references": ["Phase 5"], "source": "claude"}
  ],
  "gaps": [
    {"text": "Auth not documented", "severity": "info", "source": "claude"}
  ],
  "divergences": [],
  "adversaries_used": ["claude"]
}'

CONSOLIDATED_BOTH_ADVERSARIES='{
  "challenges": [
    {"severity": "gap", "text": "No migration plan", "references": ["Phase 3"], "source": "codex"}
  ],
  "gaps": [],
  "divergences": [
    {"between": ["claude","codex"], "text": "They disagreed on Phase 3", "references": ["Phase 3"]}
  ],
  "adversaries_used": ["claude","codex"]
}'

# ---------------------------------------------------------------------------
# Test 1: write with valid input → outbox file exists and is jq-parseable
# ---------------------------------------------------------------------------
echo "Test: write valid input → file exists and parseable"
setup_tmp_repo >/dev/null
req_id="crit-test-001"
ac_outbox_write "$req_id" "$MINIMAL_CONSOLIDATED" 1234 0.05
outbox_file="$(ac_outbox_dir)/${req_id}.json"
assert_file_exists "$outbox_file"
parsed=$(jq -e . "$outbox_file" 2>/dev/null)
assert_eq "file is jq-parseable" "0" "$?"

# ---------------------------------------------------------------------------
# Test 2: schema fields present — request_id, elapsed_ms, cost_usd
# ---------------------------------------------------------------------------
echo "Test: schema fields — request_id, elapsed_ms, cost_usd"
assert_eq "request_id field" "$req_id" "$(jq -r .request_id "$outbox_file")"
assert_eq "elapsed_ms field" "1234" "$(jq -r .elapsed_ms "$outbox_file")"
assert_eq "cost_usd field" "0.05" "$(jq -r .cost_usd "$outbox_file")"

# ---------------------------------------------------------------------------
# Test 3: adversaries_used pass-through from consolidated input
# ---------------------------------------------------------------------------
echo "Test: adversaries_used pass-through"
adversaries=$(jq -c .adversaries_used "$outbox_file")
assert_eq "adversaries_used" '["claude"]' "$adversaries"

# ---------------------------------------------------------------------------
# Test 4: challenges and gaps present in envelope
# ---------------------------------------------------------------------------
echo "Test: challenges and gaps present"
ch_count=$(jq '.challenges | length' "$outbox_file")
assert_eq "challenges count" "1" "$ch_count"
gap_count=$(jq '.gaps | length' "$outbox_file")
assert_eq "gaps count" "1" "$gap_count"

# ---------------------------------------------------------------------------
# Test 5: write to non-existent outbox dir → mkdir -p, then write succeeds
# ---------------------------------------------------------------------------
echo "Test: write to non-existent outbox dir → mkdir-p then succeed"
setup_tmp_repo >/dev/null
# Confirm outbox dir doesn't exist yet
outbox_dir="$(ac_outbox_dir)"
[[ ! -d "$outbox_dir" ]] && echo "  (outbox dir absent before write — expected)"
req_id2="crit-test-002"
ac_outbox_write "$req_id2" "$MINIMAL_CONSOLIDATED" 500 0.01
assert_file_exists "$(ac_outbox_dir)/${req_id2}.json"

# ---------------------------------------------------------------------------
# Test 6: jq-then-mv guard — corrupt consolidated_json → tmp cleaned, no target written
# ---------------------------------------------------------------------------
echo "Test: corrupt consolidated_json → no target written, tmp cleaned"
setup_tmp_repo >/dev/null
mkdir -p "$(ac_outbox_dir)"
req_id3="crit-test-003"
CORRUPT='{not valid json at all'
set +e
ac_outbox_write "$req_id3" "$CORRUPT" 100 0.00 2>/dev/null
ec=$?
set -e
assert_eq "returns non-zero on corrupt input" "1" "$ec"
assert_file_missing "$(ac_outbox_dir)/${req_id3}.json"
# Confirm no tmp files lingering in outbox dir
tmp_count=$(ls "$(ac_outbox_dir)"/*.XXXXXX 2>/dev/null | wc -l | tr -d ' ')
assert_eq "no tmp files left" "0" "$tmp_count"

# ---------------------------------------------------------------------------
# Test 7: idempotent re-write (same request_id) → overwrites cleanly
# ---------------------------------------------------------------------------
echo "Test: idempotent re-write same request_id"
setup_tmp_repo >/dev/null
req_id4="crit-test-004"
ac_outbox_write "$req_id4" "$MINIMAL_CONSOLIDATED" 100 0.01
ac_outbox_write "$req_id4" "$MINIMAL_CONSOLIDATED" 200 0.02
# File should exist and reflect the SECOND write's elapsed_ms
assert_file_exists "$(ac_outbox_dir)/${req_id4}.json"
assert_eq "elapsed_ms updated on re-write" "200" "$(jq -r .elapsed_ms "$(ac_outbox_dir)/${req_id4}.json")"
assert_eq "cost_usd updated on re-write" "0.02" "$(jq -r .cost_usd "$(ac_outbox_dir)/${req_id4}.json")"

# ---------------------------------------------------------------------------
# Test 8: cost_usd preserved as number (not string)
# ---------------------------------------------------------------------------
echo "Test: cost_usd is number type, not string"
setup_tmp_repo >/dev/null
req_id5="crit-test-005"
ac_outbox_write "$req_id5" "$MINIMAL_CONSOLIDATED" 999 1.23456
cost_type=$(jq -r 'if (.cost_usd | type) == "number" then "number" else "other" end' "$(ac_outbox_dir)/${req_id5}.json")
assert_eq "cost_usd type is number" "number" "$cost_type"

# ---------------------------------------------------------------------------
# Test 9: adversaries_used with both adversaries pass-through
# ---------------------------------------------------------------------------
echo "Test: adversaries_used both claude and codex"
setup_tmp_repo >/dev/null
req_id6="crit-test-006"
ac_outbox_write "$req_id6" "$CONSOLIDATED_BOTH_ADVERSARIES" 2000 0.10
adv_count=$(jq '.adversaries_used | length' "$(ac_outbox_dir)/${req_id6}.json")
assert_eq "adversaries_used length 2" "2" "$adv_count"
adv_0=$(jq -r '.adversaries_used[0]' "$(ac_outbox_dir)/${req_id6}.json")
assert_eq "adversaries_used[0] is claude" "claude" "$adv_0"
adv_1=$(jq -r '.adversaries_used[1]' "$(ac_outbox_dir)/${req_id6}.json")
assert_eq "adversaries_used[1] is codex" "codex" "$adv_1"

# ---------------------------------------------------------------------------
report_results
