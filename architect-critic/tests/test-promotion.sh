#!/usr/bin/env bash
# tests/test-promotion.sh — TE.1: within-run pattern detection (~5 tests)
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/_helpers.sh"
source "$SCRIPT_DIR/../lib/promotion.sh"

echo "=== test-promotion.sh ==="

# ---------------------------------------------------------------------------
# Test 1: ac_promotion_topic normalizes similar phrasing to the same topic
# "Phase 5.2 lacks fallback" vs "phase 5.2 has no fallback"
# Both share: "phase 5.2" in refs and similar first words.
# We check that exact-same refs produce same topic even with minor word diffs.
# ---------------------------------------------------------------------------
echo ""
echo "--- topic normalization ---"

CHALLENGE_A='{"severity":"premise","text":"Phase 5.2 lacks a fallback strategy","references":["Phase 5.2"]}'
CHALLENGE_B='{"severity":"gap","text":"phase 5.2 has no fallback mechanism","references":["Phase 5.2"]}'

TOPIC_A="$(ac_promotion_topic "$CHALLENGE_A")"
TOPIC_B="$(ac_promotion_topic "$CHALLENGE_B")"

# Both should produce the same topic because references are identical ("Phase 5.2")
# and stem("phase 5.2 lacks a fallback") and stem("phase 5.2 has no fallback")
# share "phase 5.2" prefix with trivial stem diffs — but crucially, the ref sort
# dominates: both have refs=["Phase 5.2"] → same ref component → same topic.
assert_eq "topic: same refs → same topic key" "$TOPIC_A" "$TOPIC_B"

# ---------------------------------------------------------------------------
# Test 2: empty challenges array → empty candidates
# ---------------------------------------------------------------------------
echo ""
echo "--- empty input ---"

EMPTY_CHALLENGES='[]'
RESULT="$(ac_promotion_within_run_candidates "$EMPTY_CHALLENGES")"
assert_eq "empty challenges → empty array" "[]" "$RESULT"

# ---------------------------------------------------------------------------
# Test 3: all different topics → no candidates (no clusters ≥2)
# ---------------------------------------------------------------------------
echo ""
echo "--- all different topics ---"

DIFF_CHALLENGES='[
  {"severity":"premise","text":"Alpha system missing auth layer","references":["Phase 1.1"]},
  {"severity":"gap","text":"Beta pipeline lacks logging","references":["Phase 2.3"]},
  {"severity":"alternative","text":"Consider caching for gamma service","references":["Phase 3.5"]}
]'
RESULT="$(ac_promotion_within_run_candidates "$DIFF_CHALLENGES")"
assert_eq "all different topics → no candidates" "[]" "$RESULT"

# ---------------------------------------------------------------------------
# Test 4: 2 challenges same topic → 1 candidate with both in addresses[], signal=within-run
# ---------------------------------------------------------------------------
echo ""
echo "--- 2 same-topic challenges ---"

SAME_TOPIC_CHALLENGES='[
  {"severity":"premise","text":"Phase 5.2 lacks a fallback strategy","references":["Phase 5.2"]},
  {"severity":"gap","text":"phase 5.2 has no fallback mechanism","references":["Phase 5.2"]}
]'
RESULT="$(ac_promotion_within_run_candidates "$SAME_TOPIC_CHALLENGES")"

# Should emit exactly 1 candidate
COUNT="$(printf '%s' "$RESULT" | jq 'length')"
assert_eq "2 same-topic → 1 candidate" "1" "$COUNT"

# signal must be "within-run"
SIGNAL="$(printf '%s' "$RESULT" | jq -r '.[0].signal')"
assert_eq "candidate signal = within-run" "within-run" "$SIGNAL"

# addresses[] must contain both challenges
ADDR_COUNT="$(printf '%s' "$RESULT" | jq '.[0].addresses | length')"
assert_eq "addresses contains 2 challenges" "2" "$ADDR_COUNT"

# ---------------------------------------------------------------------------
# Test 5: 3 challenges, 2 share topic + 1 alone → 1 candidate (the 2-cluster)
# ---------------------------------------------------------------------------
echo ""
echo "--- 3 challenges, 2-cluster + 1 solo ---"

MIXED_CHALLENGES='[
  {"severity":"premise","text":"Phase 5.2 lacks a fallback strategy","references":["Phase 5.2"]},
  {"severity":"gap","text":"phase 5.2 has no fallback mechanism","references":["Phase 5.2"]},
  {"severity":"alternative","text":"Consider semantic versioning for state schema","references":["Phase 9.0"]}
]'
RESULT="$(ac_promotion_within_run_candidates "$MIXED_CHALLENGES")"

COUNT="$(printf '%s' "$RESULT" | jq 'length')"
assert_eq "2-cluster + 1 solo → 1 candidate" "1" "$COUNT"

SIGNAL="$(printf '%s' "$RESULT" | jq -r '.[0].signal')"
assert_eq "cluster signal = within-run" "within-run" "$SIGNAL"

ADDR_COUNT="$(printf '%s' "$RESULT" | jq '.[0].addresses | length')"
assert_eq "cluster addresses 2 items" "2" "$ADDR_COUNT"

# ---------------------------------------------------------------------------
report_results
