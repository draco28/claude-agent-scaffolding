#!/usr/bin/env bash
# run-evals.sh — orchestrate LLM-as-judge eval runs for architect-critic skills
# Usage: run-evals.sh [skill_name | all]
# Exit code: 0 = all scenarios pass; 1 = at least one failure

set -euo pipefail

EVAL_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS=(critiquing-spec reviewing-critique-history listing-principles promoting-principle)

target="${1:-all}"

run_skill_evals() {
  local skill="$1"
  local fixtures_dir="${EVAL_DIR}/fixtures/${skill}"
  local rubric="${EVAL_DIR}/rubrics/${skill}.md"

  if [[ ! -d "$fixtures_dir" ]]; then
    echo "SKIP: no fixtures dir for $skill"
    return 0
  fi

  for fixture in "$fixtures_dir"/*.md; do
    [[ -e "$fixture" ]] || continue
    echo "EVAL: $skill / $(basename "$fixture")"
    # TODO: Tasks 0.2+ implement: invoke skill via Agent subagent;
    # capture output; score via LLM-judge subagent; aggregate.
    echo "  PENDING (orchestrator stub)"
  done
}

if [[ "$target" == "all" ]]; then
  for s in "${SKILLS[@]}"; do
    run_skill_evals "$s"
  done
else
  run_skill_evals "$target"
fi
