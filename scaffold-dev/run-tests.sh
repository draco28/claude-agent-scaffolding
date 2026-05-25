#!/usr/bin/env bash
# run-tests.sh — scaffold-dev test runner.
# Discovers tests/test-*.sh (or runs a specific file passed as arg).
# Aggregates per-file results. Exits non-zero if any file fails.

set -uo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PLUGIN_ROOT"

FILES=0
FAILED_FILES=()

if [[ $# -gt 0 ]]; then
  TARGETS=("$@")
else
  TARGETS=(tests/test-*.sh)
fi

for t in "${TARGETS[@]}"; do
  [[ -f "$t" ]] || continue
  FILES=$((FILES + 1))
  echo "=== $t ==="
  if bash "$t"; then
    :
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
