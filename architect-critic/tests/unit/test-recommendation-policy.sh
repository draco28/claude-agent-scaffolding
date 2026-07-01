#!/usr/bin/env bash
# test-recommendation-policy.sh — seam guard for the recommend-by-default policy
# (#93). Locks the mechanical facts that critiquing-spec adopted the convention:
# the shipped policy copy exists, the SKILL references it, the disposition triple
# was reframed accept|rebut|dismiss -> accept|rebut|defer, and --neutral opt-out is
# wired. Prose presence only (not full-sentence pinning) — robust against wording
# churn while catching a regression of the rename or a dropped reference.
set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
source "$TESTS_DIR/_helpers.sh"

# _helpers.sh has no not-contains assert; add a local one mirroring its style.
assert_file_not_contains() {
  if grep -q "$2" "$1" 2>/dev/null; then
    echo "  ✗ file unexpectedly contains pattern in $1: $2"; FAIL=$((FAIL+1))
  else
    echo "  ✓ file does not contain pattern in $1: $2"; PASS=$((PASS+1))
  fi
}

echo "=== test-recommendation-policy.sh ==="

SKILL="$PLUGIN_ROOT/skills/critiquing-spec/SKILL.md"
POLICY="$PLUGIN_ROOT/templates/recommendation-policy.md"
CMD="$PLUGIN_ROOT/commands/critique.md"
ASYNC_SKILL="$PLUGIN_ROOT/skills/managing-async-critique/SKILL.md"

# Shipped policy copy ships inside the plugin (repo-root docs/ does not install).
assert_file_exists "$POLICY"
assert_file_contains "$POLICY" "recommend-by-default"

# critiquing-spec references the policy + adopts the convention.
assert_file_contains "$SKILL" "recommendation-policy.md"
assert_file_contains "$SKILL" "Recommend-by-default"

# Disposition triple reframed to accept | rebut | defer (the rebuttal prompt).
assert_file_contains "$SKILL" "accept | rebut | defer"
# ...and the old triple is gone (regression guard for the rename).
assert_file_not_contains "$SKILL" "accept | rebut | dismiss"

# --neutral opt-out is wired (Step 3 detection + the neutral_mode flag).
assert_file_contains "$SKILL" "neutral_mode"
assert_file_contains "$SKILL" "neutral"

# Command wrapper advertises the flag.
assert_file_contains "$CMD" "argument-hint:.*--neutral"
assert_file_contains "$CMD" '`--neutral`'

# Async dispatch/resume preserves the neutral opt-out across turns.
assert_file_contains "$SKILL" "neutral-mode"
assert_file_contains "$ASYNC_SKILL" "neutral_mode"
assert_file_contains "$ASYNC_SKILL" 'force `neutral_mode=true`'

# Deferred challenges are tracked rather than silently dropped.
assert_file_contains "$SKILL" "DEFERRED_CHALLENGES_JSON"
assert_file_contains "$SKILL" "deferred-count"
assert_file_contains "$SKILL" "Deferred"
assert_file_contains "$ASYNC_SKILL" "deferred-count"

report_results
