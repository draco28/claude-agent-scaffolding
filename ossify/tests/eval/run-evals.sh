#!/usr/bin/env bash
# run-evals.sh — print the ossify planning-judge eval runbook prompt for
# Claude-Code-session execution. Does NOT call any LLM.
# Usage: bash run-evals.sh [surface | all]

set -euo pipefail
EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
target="${1:-all}"

cat <<EOF
=== ossify planning-judge eval harness ===

Session-driven eval (no API runner). Open this repo in Claude Code and paste:

---
Run the ossify planning-judge eval harness per ossify/tests/eval/RUNBOOK.md.
${target:+(target: $target)}
For each surface, iterate fixtures in tests/eval/fixtures/<surface>/, dispatch an
Agent to apply the owning skill's judgment to each fixture, then a judge Agent to
score against tests/eval/rubrics/<surface>.md. Write per-fixture JSON to
tests/eval/results/<surface>/<id>.json. When done, run
bash ossify/tests/eval/lib/aggregate-scores.sh and report the summary.
---

Then: bash $EVAL_DIR/lib/aggregate-scores.sh
EOF
