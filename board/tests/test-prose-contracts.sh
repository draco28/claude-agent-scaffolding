#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
ROOT="$HERE/.."
for s in sync doctor; do
  t_capture sed -n '1p' "$ROOT/skills/$s/SKILL.md"; t_assert_eq "---" "$T_OUT" "$s SKILL has frontmatter"
  t_capture grep -c "^name: $s$" "$ROOT/skills/$s/SKILL.md"; t_assert_eq 1 "$T_OUT" "$s SKILL name matches dir"
  t_capture grep -c '^description: ' "$ROOT/skills/$s/SKILL.md"; t_assert_eq 1 "$T_OUT" "$s SKILL has description"
  t_capture grep -c 'skills/'"$s"'/SKILL.md' "$ROOT/commands/$s.md"; t_assert_eq 1 "$T_OUT" "/$s command points at its skill"
done
# every ${CLAUDE_PLUGIN_ROOT}/... pointer in prose resolves to a file
while read -r p; do
  rel="${p#\$\{CLAUDE_PLUGIN_ROOT\}/}"; rel="${rel%%[\`\)\" ]*}"
  [ -e "$ROOT/$rel" ] && T_PASS=$((T_PASS+1)) || { T_FAIL=$((T_FAIL+1)); echo "FAIL: dangling pointer $p"; }
done < <(grep -ohE '\$\{CLAUDE_PLUGIN_ROOT\}/[A-Za-z0-9_./-]+' "$ROOT"/skills/*/SKILL.md "$ROOT"/commands/*.md | sort -u)
# doctor is prose: it must not call a lib verb that reads-and-reports
t_capture grep -cE 'bin/board (plan|drift|report)' "$ROOT/skills/doctor/SKILL.md"; t_assert_eq 0 "$T_OUT" "doctor invokes no read-and-report verb"
t_summary
