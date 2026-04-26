#!/usr/bin/env bash
# scaffold/scripts/install.sh — bootstrap the Python venv for the MCP server.
#
# Idempotent: skips if the venv already exists with all required packages.
# Called automatically by mcp/run-server.sh on first MCP tool invocation;
# can also be run manually to re-install or re-resolve dependencies.
#
# Exit codes:
#   0 = venv ready (created or already existed)
#   1 = no Python 3.11+ found, or pip install failed

set +e

# Use system trust store by default — corporate networks often intercept TLS
# with their own root CA, which uv's bundled trust store doesn't know about.
# UV_NATIVE_TLS=true tells uv to read the OS cert store (which includes any
# corp CAs the admin has installed). User can override by setting it explicitly.
export UV_NATIVE_TLS="${UV_NATIVE_TLS:-true}"

VENV_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/scaffold}/venv"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
REQS="${PLUGIN_ROOT}/mcp/requirements.txt"

# Already installed and importable? Quick exit.
if [[ -x "$VENV_DIR/bin/python" ]]; then
  if "$VENV_DIR/bin/python" -c "import fastmcp, sqlite_vec" 2>/dev/null; then
    echo "scaffold: venv already installed at $VENV_DIR" >&2
    exit 0
  fi
fi

# Find a usable Python 3.11+
PYTHON=""
for cand in python3.13 python3.12 python3.11 python3; do
  if command -v "$cand" >/dev/null 2>&1; then
    if "$cand" -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)" 2>/dev/null; then
      PYTHON="$cand"; break
    fi
  fi
done

if [[ -z "$PYTHON" ]]; then
  echo "scaffold: no Python 3.11+ found on PATH; MCP memory bank disabled." >&2
  echo "  Install Python 3.11 or higher and re-run this script." >&2
  exit 1
fi

echo "scaffold: bootstrapping Python venv at $VENV_DIR (using $PYTHON)..." >&2
mkdir -p "$(dirname "$VENV_DIR")"

# Prefer uv when available — fast, doesn't depend on ensurepip being installed.
# Falls back to `python -m venv` for environments without uv.
if [[ ! -d "$VENV_DIR" ]]; then
  if command -v uv >/dev/null 2>&1; then
    if ! uv venv --python "$PYTHON" --seed "$VENV_DIR" 2>&1 >&2; then
      echo "scaffold: uv venv creation failed." >&2
      exit 1
    fi
  elif ! "$PYTHON" -m venv "$VENV_DIR" 2>&1 >&2; then
    echo "scaffold: venv creation failed." >&2
    echo "  Try installing uv (https://docs.astral.sh/uv/) or your distro's python-venv package." >&2
    exit 1
  fi
fi

# Install requirements. Prefer uv pip if available (much faster than vanilla pip).
if command -v uv >/dev/null 2>&1; then
  if ! uv pip install --python "$VENV_DIR/bin/python" --quiet -r "$REQS" 2>&1 >&2; then
    echo "scaffold: uv pip install failed." >&2
    exit 1
  fi
else
  "$VENV_DIR/bin/pip" install --quiet --upgrade pip 2>&1 >&2 || true
  if ! "$VENV_DIR/bin/pip" install --quiet -r "$REQS" 2>&1 >&2; then
    echo "scaffold: pip install failed." >&2
    exit 1
  fi
fi

# Sanity check
if ! "$VENV_DIR/bin/python" -c "import fastmcp, sqlite_vec" 2>/dev/null; then
  echo "scaffold: venv installed but core packages not importable." >&2
  exit 1
fi

echo "scaffold: venv ready at $VENV_DIR" >&2
exit 0
