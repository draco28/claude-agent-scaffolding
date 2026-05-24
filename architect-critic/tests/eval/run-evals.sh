#!/usr/bin/env bash
# run-evals.sh — print the eval runbook prompt for Claude Code session execution.
# This script does NOT call any LLM. Eval orchestration happens inside Claude Code.
# Usage: bash run-evals.sh [skill_name | all]   # prints the prompt to paste

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
target="${1:-all}"

cat <<EOF
=== architect-critic eval harness ===

This is a Claude-Code-session-driven eval. There is no API-based runner.

To run: open this repo in Claude Code and paste the following prompt:

---
Run the architect-critic eval harness per architect-critic/tests/eval/RUNBOOK.md.
${target:+(target: $target)}
For each skill, iterate fixtures in tests/eval/fixtures/<skill>/, dispatch an Agent
to invoke the skill on each fixture, then dispatch a judge Agent to score against
the rubric. Write per-fixture JSON results to tests/eval/results/<skill>/<id>.json.
When done, run bash tests/eval/lib/aggregate-scores.sh and report the summary.
---

After the in-session run completes, you can also run:
  bash $EVAL_DIR/lib/aggregate-scores.sh

to print the aggregate report from any existing result files.
EOF
