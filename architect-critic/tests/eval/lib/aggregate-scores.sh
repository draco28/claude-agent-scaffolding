#!/usr/bin/env bash
# aggregate-scores.sh — read per-fixture JSON results and print pass/fail summary.
# Run AFTER the Claude-Code-session eval run has written results/*.json.

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RESULTS_DIR="${EVAL_DIR}/results"

if [[ ! -d "$RESULTS_DIR" ]]; then
  echo "No results dir at $RESULTS_DIR — run the eval harness first."
  exit 1
fi

total_pass=0
total_fail=0
total_files=0

for skill_dir in "$RESULTS_DIR"/*/; do
  [[ -d "$skill_dir" ]] || continue
  skill="$(basename "$skill_dir")"
  skill_pass=0
  skill_fail=0

  for result in "$skill_dir"*.json; do
    [[ -e "$result" ]] || continue
    total_files=$((total_files + 1))
    pass=$(jq -r '.pass' "$result" 2>/dev/null || echo "false")
    if [[ "$pass" == "true" ]]; then
      skill_pass=$((skill_pass + 1))
      total_pass=$((total_pass + 1))
    else
      skill_fail=$((skill_fail + 1))
      total_fail=$((total_fail + 1))
      notes=$(jq -r '.notes // ""' "$result" 2>/dev/null)
      echo "  FAIL: ${skill}/$(basename "$result" .json) — ${notes}"
    fi
  done

  echo "${skill}: ${skill_pass} pass / ${skill_fail} fail"
done

echo ""
echo "=== TOTAL: ${total_pass}/${total_files} passed ==="
[[ $total_fail -eq 0 ]]
