#!/usr/bin/env bash
# tests/test-skill-line-cap.sh — enforce the self-declared 500-line SKILL.md cap
# (superpowers:writing-skills Pass D guidance, cited in closing-vertical-slice §15
# and planning-vertical-slice §14). Regression guard for #77: the two
# vertical-slice skills had grown to 660/729 lines. Reference-grade prose lives in
# references/*.md; the SKILL.md body stays operative and auditable in one read.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
CAP=500

# Local numeric assert (the shared _helpers.sh has no <= assert); mirrors its
# PASS/FAIL + _color_* convention so the result rolls up into sd_test_summary.
assert_le_cap() {
  local skill="$1" n="$2"
  if [ "$n" -le "$CAP" ]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') $skill SKILL.md $n lines (<= $CAP)"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') $skill SKILL.md $n lines (> $CAP cap)"
  fi
}

test_all_skill_bodies_under_cap() {
  echo "test_all_skill_bodies_under_cap:"
  local f n
  for f in "$HERE"/../skills/*/SKILL.md; do
    [ -e "$f" ] || continue
    n="$(wc -l < "$f")"
    assert_le_cap "$(basename "$(dirname "$f")")" "$n"
  done
}

test_all_skill_bodies_under_cap

sd_test_summary
