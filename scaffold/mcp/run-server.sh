#!/usr/bin/env bash
# scaffold/mcp/run-server.sh — launcher for the scaffold-memory MCP server.
#
# Lazy-installs the venv on first run via scripts/install.sh, then execs
# python server.py. Detects current repo (hash + branch) and passes via env so
# the server can scope all memory operations to this project.
#
# Called by Claude Code per-session when the user first invokes any
# scaffold-memory tool (lazy MCP server start).

set +e

VENV_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/scaffold}/venv"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Lazy install on first run
if ! [[ -x "$VENV_DIR/bin/python" ]] || \
   ! "$VENV_DIR/bin/python" -c "import fastmcp, sqlite_vec" 2>/dev/null; then
  echo "scaffold-memory: venv missing; running scripts/install.sh..." >&2
  bash "${PLUGIN_ROOT}/scripts/install.sh" 1>&2 || {
    echo "scaffold-memory: install failed; MCP server not started." >&2
    exit 1
  }
fi

# Detect current repo for scoping. Sourcing lib/repo.sh gives us the same
# hash and branch logic the slash commands use.
# shellcheck source=../lib/repo.sh
source "${PLUGIN_ROOT}/lib/repo.sh"
export SCAFFOLD_REPO_HASH
SCAFFOLD_REPO_HASH="$(sf_repo_hash)"
export SCAFFOLD_REPO_BRANCH
SCAFFOLD_REPO_BRANCH="$(sf_branch)"
export SCAFFOLD_DATA_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/scaffold}"

exec "$VENV_DIR/bin/python" "${PLUGIN_ROOT}/mcp/server.py"
