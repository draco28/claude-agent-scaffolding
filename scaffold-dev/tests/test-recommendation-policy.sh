#!/usr/bin/env bash
# test-recommendation-policy.sh — seam guard for the recommend-by-default policy
# (#93). Locks the mechanical facts that planning-vertical-slice adopted the
# convention at the orchestrate gates: the shipped policy copy exists, the SKILL
# references it and carries the accept/rebut/defer affordance, and --neutral is
# parsed in the arg-parser + advertised by the command wrapper. Prose presence
# only (not full-sentence pinning) — robust against wording churn.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
PLUGIN_ROOT="$(cd "$HERE/.." && pwd)"

SKILL="$PLUGIN_ROOT/skills/planning-vertical-slice/SKILL.md"
ARGS="$PLUGIN_ROOT/skills/planning-vertical-slice/references/orchestrate-args.md"
POLICY="$PLUGIN_ROOT/skills/planning-vertical-slice/references/recommendation-policy.md"
CMD="$PLUGIN_ROOT/commands/orchestrate.md"

echo "test_recommendation_policy_wiring:"

# Shipped policy copy ships inside the plugin (repo-root docs/ does not install).
assert_file_exists "$POLICY"
assert_file_contains "$POLICY" "recommend-by-default"

# planning-vertical-slice references the policy + adopts the convention at the gates.
assert_file_contains "$SKILL" "recommendation-policy"
assert_file_contains "$SKILL" "Recommend-by-default"
assert_file_contains "$SKILL" "accept / rebut / defer"
assert_file_contains "$SKILL" "ARCHITECT_CRITIC_ARGS=.*--neutral"
assert_file_contains "$SKILL" "Recommended: run the audit"
assert_file_contains "$SKILL" "Recommended: skip"
assert_file_contains "$SKILL" "Recommended: grill-me"
assert_file_contains "$SKILL" "proceed to round K"

# --neutral opt-out: parsed in the arg-parser reference + advertised by the wrapper.
assert_file_contains "$ARGS" "neutral_mode"
assert_file_contains "$ARGS" "--neutral"
assert_file_contains "$CMD" "--neutral"

sd_test_summary
