#!/usr/bin/env bash
#
# code-judo — plugin test runner.
#
# Runs every suite under tests/. There is nothing under tests/ that this runner
# skips: a gate the runner does not execute is a gate somebody walks by hand and
# eventually forgets, so if a suite is added here it goes in this list.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SUITES="
tests/test-frontmatter-lint.sh
tests/test-fidelity-pins.sh
"

failed=0
ran=0

for suite in $SUITES; do
  [ -n "$suite" ] || continue
  ran=$((ran + 1))
  printf '\n=== %s ===\n' "$suite"
  if bash "$SCRIPT_DIR/$suite"; then
    :
  else
    failed=$((failed + 1))
    printf '!!! FAILED: %s\n' "$suite"
  fi
done

printf '\n=== code-judo: %d suite(s) run, %d failed ===\n' "$ran" "$failed"
[ "$failed" -eq 0 ] || exit 1
exit 0
