#!/usr/bin/env bash
# tests/test-subagent.sh — T3.5.2 subagent return-mode parsing fixtures.
#
# Verifies the orchestrator-side JSON parsing contract for return values from
# the scaffold-dev:implementer-agent subagent (per SPEC §6.5/§6.6 and PLAN
# Phase 3.5). No actual subagent dispatch — fixture-based parsing only.
#
# Also asserts that agents/implementer-agent.md registers the subagent with the
# expected name / description / tools allowlist / model fields per Claude Code's
# subagent registration format (per-agent markdown file with YAML frontmatter).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"

AGENT_FILE="$HERE/../agents/implementer-agent.md"

# ---------- Fixtures ----------
GAPS_RESPONSE='{"mode":"gaps-surfaced","gaps":[{"section":"spec §3","question":"AC-2 means X or Y?","severity":"blocking"}]}'
COMPLETE_RESPONSE='{"mode":"complete","report_path":"/abs/report.md","summary":"Implemented AC-1,2,3","stage_status":"all_staged"}'
COMPLETE_PARTIAL='{"mode":"complete","report_path":"/abs/report.md","summary":"AC-1 only","stage_status":"partial"}'
COMPLETE_NONE='{"mode":"complete","report_path":"/abs/report.md","summary":"nothing staged","stage_status":"none"}'
MALFORMED='{"mode":"complete"'
UNKNOWN_MODE='{"mode":"frobnicated","gaps":[]}'
GAPS_NICE='{"mode":"gaps-surfaced","gaps":[{"section":"spec §4","question":"naming?","severity":"nice-to-have"}]}'

# Extract YAML frontmatter from agents/implementer-agent.md (between the two `---` lines).
# Bash 3.2-compatible: awk-based block extractor.
_agent_frontmatter() {
  awk '/^---$/ { c++; next } c == 1 { print }' "$AGENT_FILE"
}

# Extract a single frontmatter field by key (handles "key: value" form, trims spaces).
_agent_field() {
  local key="$1"
  _agent_frontmatter | awk -v k="$key" '
    $0 ~ "^"k":" {
      sub("^"k": *", "")
      print
      exit
    }
  '
}

# ---------- 1. gaps-mode JSON shape parse ----------
test_gaps_parse() {
  echo "test_gaps_parse:"
  local mode gaps_count
  mode="$(echo "$GAPS_RESPONSE" | jq -r '.mode')"
  assert_eq "gaps mode value" "gaps-surfaced" "$mode"
  gaps_count="$(echo "$GAPS_RESPONSE" | jq '.gaps | length')"
  assert_eq "gaps array length" "1" "$gaps_count"
}

# ---------- 2. complete-mode JSON shape parse ----------
test_complete_parse() {
  echo "test_complete_parse:"
  local mode report_path summary stage_status
  mode="$(echo "$COMPLETE_RESPONSE" | jq -r '.mode')"
  report_path="$(echo "$COMPLETE_RESPONSE" | jq -r '.report_path')"
  summary="$(echo "$COMPLETE_RESPONSE" | jq -r '.summary')"
  stage_status="$(echo "$COMPLETE_RESPONSE" | jq -r '.stage_status')"
  assert_eq "complete mode value"   "complete"             "$mode"
  assert_eq "report_path field"     "/abs/report.md"       "$report_path"
  assert_eq "summary field"         "Implemented AC-1,2,3" "$summary"
  assert_eq "stage_status field"    "all_staged"           "$stage_status"
}

# ---------- 3. malformed JSON detection ----------
test_malformed_rejected() {
  echo "test_malformed_rejected:"
  if echo "$MALFORMED" | jq . >/dev/null 2>&1; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') malformed JSON unexpectedly parsed"
  else
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') malformed JSON rejected by jq"
  fi
}

# ---------- 4. stage_status enum values ----------
test_stage_status_enum() {
  echo "test_stage_status_enum:"
  local s1 s2 s3
  s1="$(echo "$COMPLETE_RESPONSE" | jq -r '.stage_status')"
  s2="$(echo "$COMPLETE_PARTIAL"  | jq -r '.stage_status')"
  s3="$(echo "$COMPLETE_NONE"     | jq -r '.stage_status')"
  case "$s1" in
    all_staged|partial|none)
      PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') stage_status '$s1' in enum" ;;
    *)
      FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') stage_status '$s1' not in enum" ;;
  esac
  case "$s2" in
    all_staged|partial|none)
      PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') stage_status '$s2' in enum" ;;
    *)
      FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') stage_status '$s2' not in enum" ;;
  esac
  case "$s3" in
    all_staged|partial|none)
      PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') stage_status '$s3' in enum" ;;
    *)
      FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') stage_status '$s3' not in enum" ;;
  esac
}

# ---------- 5. Multi-call clarification loop counter (max 3 per SPEC §6.6) ----------
test_clarification_loop_max_3() {
  echo "test_clarification_loop_max_3:"
  local i max=3 iterations=0
  i=0
  while [[ $i -lt $max ]]; do
    iterations=$((iterations+1))
    local mode
    mode="$(echo "$GAPS_RESPONSE" | jq -r '.mode')"
    if [[ "$mode" != "gaps-surfaced" ]]; then
      break
    fi
    i=$((i+1))
  done
  assert_eq "loop iterations capped at 3" "3" "$iterations"
  assert_eq "loop counter reached max"    "3" "$i"
}

# ---------- 6. subagent_type name string (frontmatter `name:` field) ----------
# Claude Code prefixes the plugin name automatically, so the on-disk name is
# the un-prefixed form. The full dispatch name is `scaffold-dev:implementer-agent`.
test_subagent_name_exact() {
  echo "test_subagent_name_exact:"
  local name
  name="$(_agent_field name)"
  assert_eq "subagent name exact" "implementer-agent" "$name"
}

# ---------- 7. agents/implementer-agent.md file exists ----------
test_agent_file_exists() {
  echo "test_agent_file_exists:"
  assert_file_exists "$AGENT_FILE"
}

# ---------- 8. agent file has the expected name + description fields ----------
test_agent_has_description() {
  echo "test_agent_has_description:"
  local desc
  desc="$(_agent_field description)"
  if [[ -n "$desc" ]]; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') description field non-empty"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') description field missing or empty"
  fi
}

# ---------- 9. tools field contains the expected 6 tools ----------
test_tools_allowed_six() {
  echo "test_tools_allowed_six:"
  local tools
  tools="$(_agent_field tools)"
  for tool in Bash Read Write Edit Glob Grep; do
    if echo "$tools" | grep -q "$tool"; then
      PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') tools contains $tool"
    else
      FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') tools missing $tool (tools='$tools')"
    fi
  done
}

# ---------- 10. tools field does NOT contain Task (nesting forbidden) ----------
test_tools_denied_task() {
  echo "test_tools_denied_task:"
  local tools
  tools="$(_agent_field tools)"
  if echo "$tools" | grep -qw 'Task'; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') tools unexpectedly contains Task"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') tools omits Task"
  fi
}

# ---------- 11. body references the executing-work-item SKILL.md as system prompt source ----------
test_body_references_skill() {
  echo "test_body_references_skill:"
  if grep -q 'skills/executing-work-item/SKILL.md' "$AGENT_FILE"; then
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') body references executing-work-item SKILL.md"
  else
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') body missing reference to executing-work-item SKILL.md"
  fi
}

# ---------- 12. gap entry shape (section, question, severity) ----------
test_gap_entry_shape() {
  echo "test_gap_entry_shape:"
  local section question severity
  section="$(echo "$GAPS_RESPONSE"  | jq -r '.gaps[0].section')"
  question="$(echo "$GAPS_RESPONSE" | jq -r '.gaps[0].question')"
  severity="$(echo "$GAPS_RESPONSE" | jq -r '.gaps[0].severity')"
  assert_eq "gap.section"  "spec §3"             "$section"
  assert_eq "gap.question" "AC-2 means X or Y?"  "$question"
  assert_eq "gap.severity" "blocking"            "$severity"
}

# ---------- 13. severity enum (blocking, nice-to-have) ----------
test_severity_enum() {
  echo "test_severity_enum:"
  local sev_blocking sev_nice
  sev_blocking="$(echo "$GAPS_RESPONSE" | jq -r '.gaps[0].severity')"
  sev_nice="$(echo "$GAPS_NICE"         | jq -r '.gaps[0].severity')"
  case "$sev_blocking" in
    blocking|nice-to-have)
      PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') severity '$sev_blocking' in enum" ;;
    *)
      FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') severity '$sev_blocking' not in enum" ;;
  esac
  case "$sev_nice" in
    blocking|nice-to-have)
      PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') severity '$sev_nice' in enum" ;;
    *)
      FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') severity '$sev_nice' not in enum" ;;
  esac
}

# ---------- 14. Unknown mode value rejected ----------
test_unknown_mode_rejected() {
  echo "test_unknown_mode_rejected:"
  local mode
  mode="$(echo "$UNKNOWN_MODE" | jq -r '.mode')"
  case "$mode" in
    complete|gaps-surfaced)
      FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') unknown mode '$mode' unexpectedly accepted" ;;
    *)
      PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') unknown mode '$mode' rejected" ;;
  esac
}

test_gaps_parse
test_complete_parse
test_malformed_rejected
test_stage_status_enum
test_clarification_loop_max_3
test_subagent_name_exact
test_agent_file_exists
test_agent_has_description
test_tools_allowed_six
test_tools_denied_task
test_body_references_skill
test_gap_entry_shape
test_severity_enum
test_unknown_mode_rejected

sd_test_summary
