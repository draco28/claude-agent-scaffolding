#!/usr/bin/env bash
# test-scaffold-onboard.sh — verify scaffold-onboard v0.2 invokes critiquing-spec
# in-conversation (no inbox/outbox file-IPC) at its MASTER-SPEC review moment.
#
# CURRENTLY SKIPPED — scaffold-onboard is still at v0.1.0 in this repo. v0.2 (the
# skill-first retrofit that drops file-IPC) is on the queue per
# [[project_skill_first_retrofit_queue]] but not yet built. When scaffold-onboard
# v0.2 lands, replace this skip with the actual fixture-based integration check.
#
# Expected v0.2 contract (per architect-critic SPEC §8.1):
#   1. scaffold-onboard reaches its "now adversarially audit MASTER-SPEC" moment
#   2. Its skill body says "now invoke architect-critic's critiquing-spec skill"
#   3. Claude triggers critiquing-spec via description match (no composition.json,
#      no registry lookup)
#   4. critiquing-spec runs in the same conversation, produces challenges, runs
#      rebuttal cycle, returns summary
#   5. scaffold-onboard reads the summary from conversation context and continues
#
# When scaffold-onboard v0.2 is available, this test should:
#   - Set up a fixture MASTER-SPEC.md
#   - Set up a fixture workspace-init manifest
#   - Run a scripted invocation that exercises the boundary
#   - Assert state.json gets a recent_runs[] entry with skill_invoked: "critiquing-spec"

set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/.." && pwd)"

if [[ -f "$REPO_ROOT/scaffold-onboard/.claude-plugin/plugin.json" ]]; then
  consumer_version="$(jq -r '.version' "$REPO_ROOT/scaffold-onboard/.claude-plugin/plugin.json")"
else
  consumer_version="(not installed)"
fi

# Major-version gate: only run the real test once scaffold-onboard hits 0.2.x
case "$consumer_version" in
  0.2.*|0.3.*|0.4.*|1.*)
    echo "SKIP: scaffold-onboard v${consumer_version} is installed but this test's"
    echo "      real fixture/wiring is still TODO. Replace this skip with the"
    echo "      actual integration check when ready."
    exit 0
    ;;
  *)
    echo "SKIP: scaffold-onboard at ${consumer_version} (v0.2 required for in-conversation"
    echo "      handoff per architect-critic SPEC §8.1). Per [[project_skill_first_retrofit_queue]]"
    echo "      scaffold-onboard v0.2 is on the queue but not yet built. Re-enable this test"
    echo "      after scaffold-onboard v0.2 ships."
    exit 0
    ;;
esac
