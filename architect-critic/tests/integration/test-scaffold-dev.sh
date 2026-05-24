#!/usr/bin/env bash
# test-scaffold-dev.sh — verify scaffold-dev v0.1 invokes critiquing-spec at
# its two architect-critic moments per slice: spec-author audit (before round 1)
# and slice-close adversarial review.
#
# CURRENTLY SKIPPED — scaffold-dev is not yet a plugin in this repo. Only its
# SPEC exists (docs/SPEC-scaffold-dev.md). When scaffold-dev v0.1 lands,
# replace this skip with actual fixture-based integration checks for both
# invocation moments.
#
# Expected v0.1 contract (per architect-critic SPEC §8.2 + scaffold-dev §16.3):
#   - Moment 1 (pre-round-1 spec-author audit): scaffold-dev's orchestrator
#     invokes critiquing-spec on the slice spec before round 1 begins
#   - Moment 2 (slice-close adversarial review): scaffold-dev invokes
#     critiquing-spec again after the slice is materially complete, on the
#     same spec, with --close depth
#   - Both invocations happen in-conversation; no file IPC
#   - state.json should accumulate two recent_runs[] entries per slice

set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/.." && pwd)"

if [[ -f "$REPO_ROOT/scaffold-dev/.claude-plugin/plugin.json" ]]; then
  consumer_version="$(jq -r '.version' "$REPO_ROOT/scaffold-dev/.claude-plugin/plugin.json")"
else
  consumer_version="(not installed)"
fi

case "$consumer_version" in
  0.1.*|0.2.*|0.3.*|1.*)
    echo "SKIP: scaffold-dev v${consumer_version} is installed but this test's"
    echo "      real fixture/wiring is still TODO. Replace this skip with the"
    echo "      actual integration check when ready."
    exit 0
    ;;
  *)
    echo "SKIP: scaffold-dev not yet built (consumer_version=${consumer_version})."
    echo "      Per docs/SPEC-scaffold-dev.md this plugin is still on the queue."
    echo "      Re-enable this test after scaffold-dev v0.1 ships."
    exit 0
    ;;
esac
