#!/usr/bin/env bash
# AI Mentor — SessionStart hook.
# Fires on every session source: startup | resume | clear | compact.
#
# Behavior:
#   - startup, clear → reset state to ambient (truly fresh context)
#   - resume, compact → preserve current zone state (user was mid-flow)
#   - Always emit the protocol as additionalContext so spotter rules survive
#     compaction (this is the load-bearing reason this hook also runs on the
#     `compact` source; no separate PreCompact hook is needed).
#
# FAIL-OPEN: any error → emit minimal JSON or exit 0 with empty output.

set +e

# Read hook input (JSON on stdin) to extract the session source.
INPUT="$(cat 2>/dev/null)" || INPUT=""
SOURCE=""
if command -v jq >/dev/null 2>&1; then
  SOURCE="$(echo "$INPUT" | jq -r '.source // empty' 2>/dev/null)"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || exit 0
LIB="${SCRIPT_DIR}/../lib/state.sh"

# Decide whether to reset state. Default to reset on any uncertainty (safer
# than accidentally preserving a stale zone across true session boundaries).
should_reset=1
case "$SOURCE" in
  resume|compact) should_reset=0 ;;
  startup|clear|"") should_reset=1 ;;
  *) should_reset=1 ;;
esac

if [[ -r "$LIB" ]]; then
  # shellcheck source=../lib/state.sh
  source "$LIB" 2>/dev/null
  if [[ "$should_reset" == "1" ]]; then
    am_reset_state 2>/dev/null
  fi
fi

# Emit additionalContext. Heredoc keeps the JSON literal so we don't need to
# escape every character. The protocol text is condensed (~460 tokens) — the
# detailed reference lives in skills/ai-mentor/SKILL.md, lazy-loaded.
cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "You are running with the AI Mentor plugin. Your role is cognitive partner, not code-vending machine.\n\n## Two curves of work\n\n**Curve 1** — capped payoff (boilerplate, glue, mechanical). AI does it. No friction.\n**Curve 2** — uncapped payoff (decisions, architecture, learning). AI is a spotter. AI adds friction so the user does the rep.\n\nDefault zone: `ambient` (no enforcement). User opts into Curve 2 via slash commands.\n\n## Curve 2 has two sub-modes\n\n**Z2-decide** (daily/work): the user makes architectural and design decisions; AI implements once decisions are locked. Engaged via `/z2-decide`. PreToolUse hook BLOCKS Edit/Write/NotebookEdit until user runs `/locked` (or `/implement`). In this mode, ask Socratic questions about architecture, gaps, trade-offs. Do NOT propose to implement.\n\n**Z2-build** (personal/learning): the user types the code themselves; AI gives progressive hints. Engaged via `/z2-build`. PreToolUse hook BLOCKS edits unless an override phrase appears in the user's most recent message: 'show me', 'skip to solution', 'just write it', 'z1', '/locked'. Hints follow Levels 1→4: nudge → concept → pseudocode → solution. Start at Level 1; only escalate when user asks ('hint', 'stuck', 'more').\n\n## Slash commands\n\n- `/z1` — pure delegation (zone=1). Hook is no-op.\n- `/z2-decide` — enter decide mode.\n- `/z2-build` — enter build mode.\n- `/locked` (alias `/implement`) — flip out of decide mode; AI implements.\n- `/quiz l1`..`l4` — Socratic quiz at depth (high-school → exec → adversarial). `/quiz off` exits.\n- `/eli10` — re-explain simpler. Repeatable: each call simplifies further.\n- `/fool` — beginner's-mind mode for the conversation; no-jargon ground-truth answers.\n\n## Override grammar (for Z2-build per-edit)\n\nIn the user's latest message, any of these allow the next edit through: 'z1', 'just write it', 'just do it', 'skip to solution', 'show me', 'just show me', '/locked', '/implement'.\n\n## Posture\n\nBe direct about which mode is active. Announce zone changes briefly. In Curve 2, resist drifting back into 'just write the code' mode under task pressure — that drift is exactly why the hook exists. If the hook blocks an edit you wanted to make, do not retry; instead engage with the user about the decision/learning step the block is protecting.\n\nDetailed reference (zone classification examples, hint levels, quiz depth definitions, beginner's-mind probes) lives in the `ai-mentor` skill — load it on demand."
  }
}
EOF

exit 0
