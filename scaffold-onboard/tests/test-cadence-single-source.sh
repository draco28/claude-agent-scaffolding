#!/usr/bin/env bash
# test-cadence-single-source.sh — SS-1 W6 grep-guard: the memory-bank update cadence
# is stated in exactly ONE place (WORKFLOW.md, marked canonical). Every other skill
# points to it rather than restating it.
#
# Self-match avoidance: the canonical marker is the full HTML comment built from
# $marker_core below. This test never writes that full literal anywhere (not even in
# comments) — it assembles it at runtime — so grepping the source tree for the full
# marker does NOT match this test file (which contains only the bare substring and the
# "<!-- ${marker_core} -->" variable form). The same is true of test-memory-bank.sh,
# which asserts on the bare substring only.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"

REPO_ROOT="$(cd "$HERE/../.." && pwd)"
marker_core="cadence-policy:canonical"
full_marker="<!-- ${marker_core} -->"

test_canonical_marker_unique() {
  echo "test_canonical_marker_unique:"
  local files n
  files="$(grep -rlF "$full_marker" "$REPO_ROOT/scaffold-onboard" "$REPO_ROOT/scaffold-dev" 2>/dev/null)"
  n="$(printf '%s\n' "$files" | grep -c . )"
  if [[ "$n" == "1" ]]; then
    PASS=$((PASS+1)); echo "  ✓ exactly one canonical cadence marker"
  else
    FAIL=$((FAIL+1)); echo "  ✗ expected 1 canonical marker, found $n:"
    printf '      %s\n' $files
  fi
}

test_canonical_marker_in_workflow() {
  echo "test_canonical_marker_in_workflow:"
  if grep -qF "$full_marker" "$REPO_ROOT/scaffold-onboard/templates/memory-bank/WORKFLOW.md"; then
    PASS=$((PASS+1)); echo "  ✓ canonical marker lives in WORKFLOW.md template"
  else
    FAIL=$((FAIL+1)); echo "  ✗ canonical marker not in WORKFLOW.md template"
  fi
}

test_sweep_targets_point_to_policy() {
  echo "test_sweep_targets_point_to_policy:"
  local missing=0 f
  for f in \
    "$REPO_ROOT/scaffold-onboard/templates/memory-bank/05-active-context.md.tmpl" \
    "$REPO_ROOT/scaffold-onboard/templates/memory-bank/06-progress.md.tmpl" \
    "$REPO_ROOT/scaffold-onboard/templates/memory-bank/tech-debt.md.tmpl" \
    "$REPO_ROOT/scaffold-onboard/templates/memory-bank/08-governance.md.tmpl" \
    "$REPO_ROOT/scaffold-onboard/templates/memory-bank/09-known-issues.md.tmpl" \
    "$REPO_ROOT/scaffold-onboard/templates/memory-bank/10-decisions-log.md.tmpl" \
    "$REPO_ROOT/scaffold-dev/skills/executing-work-item/SKILL.md" \
    "$REPO_ROOT/scaffold-dev/skills/deferring-work-item/SKILL.md" \
    "$REPO_ROOT/scaffold-dev/skills/writing-sprint-retrospective/SKILL.md" \
    "$REPO_ROOT/scaffold-dev/skills/closing-vertical-slice/SKILL.md"; do
    if ! grep -qF 'Memory-bank update cadence' "$f"; then
      echo "  ✗ no policy pointer in ${f#$REPO_ROOT/}"; missing=$((missing+1))
    fi
  done
  if [[ "$missing" == "0" ]]; then
    PASS=$((PASS+1)); echo "  ✓ all sweep targets point to the policy"
  else
    FAIL=$((FAIL+1))
  fi
}

test_canonical_marker_unique
test_canonical_marker_in_workflow
test_sweep_targets_point_to_policy
report_results
