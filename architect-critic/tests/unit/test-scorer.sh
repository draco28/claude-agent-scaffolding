#!/usr/bin/env bash
# test-scorer.sh — tests for lib/scorer.sh
# TDD: write tests first, then implement.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# shellcheck source=tests/_helpers.sh
source "$TESTS_DIR/_helpers.sh"
source "$PLUGIN_ROOT/lib/_helpers.sh"
source "$PLUGIN_ROOT/lib/scorer.sh"

SPEC_PATH="$TESTS_DIR/fixtures/master-specs/tiny-spec.md"

echo "=== test-scorer.sh ==="

# ---------------------------------------------------------------------------
# 1. Bare contradiction — "no" → score 1
# ---------------------------------------------------------------------------
score="$(ac_scorer_score_rebuttal "Phase 5 lacks a fallback strategy." "no")"
assert_eq "bare contradiction 'no' → 1" "1" "$score"

# ---------------------------------------------------------------------------
# 2. Bare contradiction — "wrong" → score 1
# ---------------------------------------------------------------------------
score="$(ac_scorer_score_rebuttal "Phase 5 lacks a fallback strategy." "wrong")"
assert_eq "bare contradiction 'wrong' → 1" "1" "$score"

# ---------------------------------------------------------------------------
# 3. Bare contradiction — "disagree" → score 1
# ---------------------------------------------------------------------------
score="$(ac_scorer_score_rebuttal "Phase 5 lacks a fallback strategy." "disagree")"
assert_eq "bare contradiction 'disagree' → 1" "1" "$score"

# ---------------------------------------------------------------------------
# 4. Bare contradiction — "not true" → score 1
# ---------------------------------------------------------------------------
score="$(ac_scorer_score_rebuttal "Phase 5 lacks a fallback strategy." "not true")"
assert_eq "bare contradiction 'not true' → 1" "1" "$score"

# ---------------------------------------------------------------------------
# 5. Cite-self — rebuttal is substring of spec content → score 2
# ---------------------------------------------------------------------------
# Pick a known phrase from tiny-spec.md
ARCHITECT_CRITIC_SPEC_PATH="$SPEC_PATH" \
score="$(ARCHITECT_CRITIC_SPEC_PATH="$SPEC_PATH" ac_scorer_score_rebuttal \
  "Phase 5 lacks a fallback strategy." \
  "Integration patterns and composition.")"
assert_eq "cite-self: rebuttal substring of spec → 2" "2" "$score"

# ---------------------------------------------------------------------------
# 6. Material new info — rebuttal contains words not in spec → score ≥ 4
#    (mock forces exact value since heuristic only guarantees ≥4)
# ---------------------------------------------------------------------------
score="$(ARCHITECT_CRITIC_SCORER_MOCK=4 ARCHITECT_CRITIC_SPEC_PATH="$SPEC_PATH" \
  ac_scorer_score_rebuttal \
  "Phase 5 lacks a fallback strategy." \
  "Actually, RFC 9999 mandates a circuit-breaker protocol that supersedes this requirement entirely.")"
assert_eq "material new info with mock=4 → 4" "4" "$score"

# ---------------------------------------------------------------------------
# 7. Material new info — mock forces 5
# ---------------------------------------------------------------------------
score="$(ARCHITECT_CRITIC_SCORER_MOCK=5 ARCHITECT_CRITIC_SPEC_PATH="$SPEC_PATH" \
  ac_scorer_score_rebuttal \
  "Phase 5 lacks a fallback strategy." \
  "Actually, RFC 9999 mandates a circuit-breaker protocol that supersedes this requirement entirely.")"
assert_eq "material new info with mock=5 → 5" "5" "$score"

# ---------------------------------------------------------------------------
# 8. ARCHITECT_CRITIC_SCORER_MOCK env override — ambiguous rebuttal falls
#    through to mock → returns mock value
# ---------------------------------------------------------------------------
score="$(ARCHITECT_CRITIC_SCORER_MOCK=3 \
  ac_scorer_score_rebuttal "Some challenge." "This partially covers the concern.")"
assert_eq "SCORER_MOCK=3 overrides fallback → 3" "3" "$score"

# ---------------------------------------------------------------------------
# 9. Multi-paragraph rebuttal truncated to 500 chars
#    Build a rebuttal >500 chars; prepend "no" so heuristic catches it if
#    the *full* text were used but NOT if truncated (after 500 chars the
#    leading "no" pattern still fires, so instead we test that a rebuttal
#    that would score 2 (cite-self) only if the FULL string is a substring
#    actually falls to mock because the 500-char truncation breaks the match)
# ---------------------------------------------------------------------------
# Construct: start with spec phrase (≤500 chars total so phrase is in first 500)
# Then verify that a rebuttal whose ONLY spec match lives AFTER char 500 does NOT score 2.
long_suffix="$(printf 'X%.0s' {1..600})"
rebuttal_spec_after_500="SomethingUnrelated ${long_suffix} Integration patterns and composition."
score_no_mock="$(ARCHITECT_CRITIC_SPEC_PATH="$SPEC_PATH" ARCHITECT_CRITIC_SCORER_MOCK=3 \
  ac_scorer_score_rebuttal "Some challenge." "$rebuttal_spec_after_500")"
# The spec phrase appears after 500 chars, so cite-self should NOT match;
# falls through to mock → 3
assert_eq "spec phrase after 500 chars → not cite-self, mock=3 → 3" "3" "$score_no_mock"

# ---------------------------------------------------------------------------
# 10. decide — score 1 → "restate"
# ---------------------------------------------------------------------------
decision="$(ac_scorer_decide 1)"
assert_eq "decide(1) → restate" "restate" "$decision"

# ---------------------------------------------------------------------------
# 11. decide — score 2 → "restate"
# ---------------------------------------------------------------------------
decision="$(ac_scorer_decide 2)"
assert_eq "decide(2) → restate" "restate" "$decision"

# ---------------------------------------------------------------------------
# 12. decide — score 3 → "restate"
# ---------------------------------------------------------------------------
decision="$(ac_scorer_decide 3)"
assert_eq "decide(3) → restate" "restate" "$decision"

# ---------------------------------------------------------------------------
# 13. decide — score 4 → "concede"
# ---------------------------------------------------------------------------
decision="$(ac_scorer_decide 4)"
assert_eq "decide(4) → concede" "concede" "$decision"

# ---------------------------------------------------------------------------
# 14. decide — score 5 → "concede"
# ---------------------------------------------------------------------------
decision="$(ac_scorer_decide 5)"
assert_eq "decide(5) → concede" "concede" "$decision"

report_results
