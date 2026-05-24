#!/usr/bin/env bash
# session-start.sh — fail-open ambient status for architect-critic v0.2.
# Output: ~50 tokens, single line. NEVER fails (always exit 0).
#
# v0.1.3 cleared stale in_flight markers; in v0.2 the schema has no in_flight
# field (no async), so this hook just announces the plugin and points at the
# user-global principles.md if one exists.

set +e

PRINCIPLES_PATH="${HOME}/.claude/architect-critic/principles.md"
if [[ -f "$PRINCIPLES_PATH" ]]; then
  echo "architect-critic v0.2 installed; principles loaded from ${PRINCIPLES_PATH}"
else
  echo "architect-critic v0.2 installed; principles loaded from (shipped defaults only)"
fi

exit 0
