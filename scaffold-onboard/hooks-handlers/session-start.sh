#!/usr/bin/env bash
# SessionStart hook for scaffold-onboard.
# Phase A: stub only. Implementation arrives in Phase F, Task TF.4.
#
# Responsibilities (when implemented):
#   - refresh ${CLAUDE_PLUGIN_DATA}/composition.json detecting ai-mentor /
#     architect-critic / superpowers
#   - emit additionalContext if onboarding is in progress in the current repo
#
# Matcher design note (hooks/hooks.json):
#   The hooks.json matcher is "startup|clear|compact|resume" — explicit list
#   of the SessionStart sources we care about. Sibling plugins (scaffold,
#   ai-mentor) use no matcher and filter the source field inside the handler.
#   The matcher-based approach here is intentional: it lets Claude Code skip
#   invoking the handler entirely when source is irrelevant, saving startup
#   cost. The handler still reads the source from stdin (Phase F) to branch
#   between "refresh composition" and "preserve composition" cases.

set -u
exit 0
