#!/usr/bin/env bash
# test-codex-async.sh — async codex spine (companion task --background) for v0.3 (#39).
# Drives the env-driven codex-companion shim via bin/arc (no real Codex, no network).
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# shellcheck source=../_helpers.sh
source "$TESTS_DIR/_helpers.sh"

export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
ARC="$PLUGIN_ROOT/bin/arc"

echo "=== test-codex-async.sh (v0.3) ==="

# Async spine drives the companion via `node`; loud-skip if node is absent.
if ! command -v node >/dev/null 2>&1; then
  echo "  ! node not found — skipping async codex tests (loud skip)"
  exit 0
fi

# Skeleton sanity assertion (real spine tests land in Task 2).
assert_eq "shim wiring placeholder" "ok" "ok"

report_results
