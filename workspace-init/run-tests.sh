#!/usr/bin/env bash
# run-tests.sh — workspace-init test runner.
# Discovers tests/test-*.sh, runs each via bash, aggregates PASS/FAIL.
# Exits non-zero if any file fails.

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PLUGIN_ROOT"

FILES=0
FAILED_FILES=()

for t in tests/test-*.sh; do
  [[ -f "$t" ]] || continue
  FILES=$((FILES + 1))
  echo "=== $t ==="
  if bash "$t"; then
    : # per-file summary already printed by wi_test_summary
  else
    FAILED_FILES+=("$t")
  fi
  echo ""
done

echo "================================================================"
echo "Test files run: $FILES"
echo "Failed files:   ${#FAILED_FILES[@]}"
if [[ "${#FAILED_FILES[@]}" -gt 0 ]]; then
  printf '  - %s\n' "${FAILED_FILES[@]}"
  exit 1
fi
exit 0
