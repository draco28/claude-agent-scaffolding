#!/usr/bin/env bash
# scaffold SessionStart hook.
#
# Detects scaffold-managed repos (via plugin-data presence) and injects ~200-300
# tokens of project context: project name, branch, stack, current slice + phase,
# recent memory entries, and a slash-command quick reference.
#
# Source-aware: re-emits on every source (startup, resume, clear, compact) so
# the project context survives context compaction. Unlike ai-mentor's hook,
# scaffold has no per-session mutable state to reset — we just always emit
# when managed, silently exit when not.
#
# FAIL-OPEN: any error path → exit 0 with empty output. Never break the session.

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || exit 0
LIB_DIR="${SCRIPT_DIR}/../lib"

# shellcheck source=../lib/state.sh
source "${LIB_DIR}/state.sh" 2>/dev/null || exit 0

# Read source field from stdin (Claude Code provides it; we don't actually
# branch on it — but consume stdin so the hook protocol stays clean).
INPUT="$(cat 2>/dev/null)" || INPUT=""

# Quick exit if we're not inside a git repo (scaffold is git-only).
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Quick exit if this (repo, branch) isn't scaffold-managed.
if ! sf_is_managed; then
  exit 0
fi

# ── Build context ──────────────────────────────────────────────────────────

REPO_NAME="$(basename "$(sf_repo_root)")"
BRANCH="$(sf_branch)"
STATE="$(sf_read_state)"
STACK="$(echo "$STATE" | jq -r '.stack | join(", ")' 2>/dev/null)"
[[ -z "$STACK" || "$STACK" == "null" ]] && STACK="(none detected)"
LLM_PROJECT="$(echo "$STATE" | jq -r '.llm_project' 2>/dev/null)"
[[ "$LLM_PROJECT" == "true" ]] && LLM_TAG=" · LLM project" || LLM_TAG=""

CURRENT_SLICE="$(echo "$STATE" | jq -r '.current_slice // empty' 2>/dev/null)"
SLICE_LINE=""
if [[ -n "$CURRENT_SLICE" ]]; then
  PHASE="$(echo "$STATE" | jq -r --arg s "$CURRENT_SLICE" '.slices[$s].phase // "?"' 2>/dev/null)"
  AC_PASSING="$(echo "$STATE" | jq -r --arg s "$CURRENT_SLICE" '[.slices[$s].acceptance_criteria[]? | select(.status == "passing")] | length' 2>/dev/null)"
  AC_TOTAL="$(echo "$STATE" | jq -r --arg s "$CURRENT_SLICE" '.slices[$s].acceptance_criteria | length' 2>/dev/null)"
  SLICE_LINE="${CURRENT_SLICE} (phase: ${PHASE}; ACs: ${AC_PASSING}/${AC_TOTAL} passing)"
else
  SLICE_LINE="(none — start one with /slice-new <name>)"
fi

# Pull last 3 memory entries. Try sqlite3 CLI first, fall back to python3.
# Both paths are stdlib-only on the typical machine; we never spin up the venv
# from this hook (it fires before the MCP server starts).
MEMORY_LINES=""
DB_PATH="$(sf_project_dir)/memory.db"
if [[ -r "$DB_PATH" ]]; then
  if command -v sqlite3 >/dev/null 2>&1; then
    MEMORY_LINES="$(sqlite3 "$DB_PATH" \
      "SELECT '- ' || type || ': ' || COALESCE(NULLIF(title,''), substr(body,1,60))
       FROM memory ORDER BY created_at DESC LIMIT 3;" 2>/dev/null)"
  elif command -v python3 >/dev/null 2>&1; then
    MEMORY_LINES="$(python3 -c '
import sqlite3, sys
try:
    db = sqlite3.connect(sys.argv[1])
    rows = db.execute(
        "SELECT type, COALESCE(NULLIF(title, \"\"), substr(body,1,60)) "
        "FROM memory ORDER BY created_at DESC LIMIT 3"
    ).fetchall()
    for t, x in rows:
        print(f"- {t}: {x}")
except Exception:
    pass
' "$DB_PATH" 2>/dev/null)"
  fi
fi
if [[ -z "$MEMORY_LINES" ]]; then
  MEMORY_LINES="(memory bank empty — record decisions/patterns/notes via the scaffold-memory MCP tools)"
fi

# Build the context string. Heredoc escaped for JSON injection below.
CONTEXT="$(cat <<EOF
You are working in a scaffold-managed repo.

Project: ${REPO_NAME} · branch: ${BRANCH} · stack: ${STACK}${LLM_TAG}
Current slice: ${SLICE_LINE}

Recent memory entries (newest first):
${MEMORY_LINES}

Slash command quick reference:
- Project: /scaffold-status /scaffold-audit /scaffold-claude-md-edit /scaffold-claude-md-rebuild
- Slice (5-phase): /slice-new → /slice-spec → /slice-contract → /slice-scaffold → /slice-implement → /slice-verify ; /slice-status /slice-list
- Governance: /adr-new /changelog /runbook-new
- Worktrees: /scaffold-worktree-fork /scaffold-worktree-list
- Memory bank (MCP, natural language): record_decision, record_pattern, record_note, record_retrospective, recall, list_recent

Phase gates are strict — phase commands refuse to advance without prerequisites met (the error message tells you which command to run).
Composition with ai-mentor: spec authoring + scaffold ops are Curve 1 (run in /z1 or ambient); AC capture from Socratic discussion is Curve 2/decide. See scaffold's SKILL.md for the full reference.
EOF
)"

# Emit JSON. Use jq to safely escape the context as a JSON string.
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$CONTEXT" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: $ctx
    }
  }'
else
  # Without jq we can't emit safely — exit silently.
  exit 0
fi

exit 0
