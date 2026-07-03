#!/usr/bin/env bash
# tests/test-render.sh — unit tests for lib/render.sh (direct + dispatcher/strict-mode paths)

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/render.sh"

# 1. simple {{key}} substitution
test_simple_substitution() {
  echo "test_simple_substitution:"
  setup_tmp_repo
  echo "Hello {{name}}!" > t.tmpl
  local out
  out="$(sd_render_template t.tmpl '{"name":"World"}')"
  assert_eq "simple substitution" "Hello World!" "$out"
}

# 2. multiple distinct keys
test_multi_keys() {
  echo "test_multi_keys:"
  setup_tmp_repo
  echo "{{a}} and {{b}}" > t.tmpl
  local out
  out="$(sd_render_template t.tmpl '{"a":"foo","b":"bar"}')"
  assert_eq "multi keys" "foo and bar" "$out"
}

# 3. same key used multiple times
test_repeated_key() {
  echo "test_repeated_key:"
  setup_tmp_repo
  echo "{{x}}/{{x}}/{{x}}" > t.tmpl
  local out
  out="$(sd_render_template t.tmpl '{"x":"a"}')"
  assert_eq "repeated key" "a/a/a" "$out"
}

# 4. missing key warns + leaves placeholder OR renders empty (we accept either)
test_missing_key_warns() {
  echo "test_missing_key_warns:"
  setup_tmp_repo
  echo "Hello {{name}}!" > t.tmpl
  local out err
  err="$(sd_render_template t.tmpl '{}' 2>&1 >/dev/null)"
  assert_contains "warn includes missing key" "name" "$err"
}

# 5. empty template renders empty
test_empty_template() {
  echo "test_empty_template:"
  setup_tmp_repo
  : > t.tmpl
  local out
  out="$(sd_render_template t.tmpl '{}')"
  assert_eq "empty template" "" "$out"
}

# 6. template without any placeholders passes through
test_passthrough() {
  echo "test_passthrough:"
  setup_tmp_repo
  echo "no placeholders here" > t.tmpl
  local out
  out="$(sd_render_template t.tmpl '{"x":"y"}')"
  assert_eq "passthrough" "no placeholders here" "$out"
}

# 7. HTML entities preserved
test_html_entities() {
  echo "test_html_entities:"
  setup_tmp_repo
  echo '<b>{{name}}</b> &amp; co.' > t.tmpl
  local out
  out="$(sd_render_template t.tmpl '{"name":"Bob"}')"
  assert_eq "html preserved" "<b>Bob</b> &amp; co." "$out"
}

# 8. multi-line template
test_multiline() {
  echo "test_multiline:"
  setup_tmp_repo
  cat > t.tmpl <<'EOF'
Title: {{title}}
Body: {{body}}
EOF
  local out
  out="$(sd_render_template t.tmpl '{"title":"T","body":"B"}')"
  assert_contains "title line" "Title: T" "$out"
  assert_contains "body line"  "Body: B"  "$out"
}

# 9. nested {{var}} not supported — value containing {{ should not re-expand
test_no_nested_expansion() {
  echo "test_no_nested_expansion:"
  setup_tmp_repo
  echo "{{a}}" > t.tmpl
  local out
  out="$(sd_render_template t.tmpl '{"a":"{{b}}","b":"inner"}')"
  # Either the value passes through literally or warn — we accept literal.
  assert_eq "no nested expansion" "{{b}}" "$out"
}

# 10. dots in keys allowed (project_name.foo)
test_dotted_key() {
  echo "test_dotted_key:"
  setup_tmp_repo
  echo "Hi {{project.name}}" > t.tmpl
  local out
  out="$(sd_render_template t.tmpl '{"project.name":"todo-cli"}')"
  assert_eq "dotted key" "Hi todo-cli" "$out"
}

test_work_item_template_contains_traceability() {
  echo "test_work_item_template_contains_traceability:"
  local tmpl="$HERE/../templates/work-item-spec.md.tmpl"
  assert_file_contains "$tmpl" "Traceability"
  assert_file_contains "$tmpl" "{{traceability_block}}"
}

test_handoff_template_contains_traceability() {
  echo "test_handoff_template_contains_traceability:"
  local tmpl="$HERE/../templates/implementation-handoff.md.tmpl"
  assert_file_contains "$tmpl" "Requirement traceability"
  assert_file_contains "$tmpl" "{{traceability_block}}"
}

# 11. work-item-spec template §6 must render machine-checkable auto: AC lines (#36)
test_work_item_spec_acs_block_renders_auto() {
  echo "test_work_item_spec_acs_block_renders_auto:"
  setup_tmp_repo
  local tmpl="$HERE/../templates/work-item-spec.md.tmpl"
  local vars
  vars='{"work_item_id":"work-3.2.01","work_item_title":"t","vs_id":"VS-3.2","vs_kebab":"k","round_id":"R1","worktree_abs_path":"/tmp/wt","branch_name":"b","context_paragraph":"c","decisions_baked_in":"-","traceability_block":"-","files_to_modify":"-","acs_block":"- [ ] AC-1 auto: `pytest tests/test_foo.py` → expected: exit 0","verification_block":"-","demo_contribution":"d","not_in_scope":"-","reference_index":"-"}'
  local out
  out="$(sd_render_template "$tmpl" "$vars")"
  # Assert the CONCRETE injected content — "AC-1 auto:" and "pytest tests/test_foo.py"
  # appear ONLY in the rendered acs_block, never in §6's instructional/comment text — so a
  # pass proves the payload actually rendered (not that prose merely mentions "auto:").
  assert_contains "work-item §6 renders the injected AC label" "AC-1 auto:" "$out"
  assert_contains "work-item §6 renders the concrete injected command" "pytest tests/test_foo.py" "$out"
  if printf '%s' "$out" | grep -q '{{acs_block}}'; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') work-item template left unresolved {{acs_block}} placeholder"
  else
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') work-item template resolved {{acs_block}}"
  fi
  if printf '%s' "$out" | grep -q '{{acs_table}}'; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') work-item template still references removed {{acs_table}} placeholder"
  else
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') work-item template no longer references {{acs_table}}"
  fi
}

# --- dispatcher (strict-mode) path: the tests above source render.sh directly, so
# they never run under bin/sd's `set -euo pipefail`. These invoke the REAL dispatcher
# to guard the regression where a fully-resolved template silently aborted (exit 1,
# no output) because the "no unresolved placeholders" grep returned 1 under set -e.
_SD_BIN="$HERE/../bin/sd"

test_dispatcher_fully_resolved_renders() {
  echo "test_dispatcher_fully_resolved_renders:"
  local tmpl; tmpl="$(mktemp -t sd-render.XXXXXX)"
  printf '# {{title}}\n\nbody {{value}} end\n' > "$tmpl"
  local out rc
  out="$("$_SD_BIN" render_template "$tmpl" '{"title":"Hi","value":"42"}' 2>/dev/null)"; rc=$?
  rm -f "$tmpl"
  assert_eq "fully-resolved via dispatcher exits 0" "0" "$rc"
  assert_contains "content actually printed" "body 42 end" "$out"
}

test_dispatcher_handoff_12_sections() {
  echo "test_dispatcher_handoff_12_sections:"
  local vars
  vars='{"handoff_type":"forward","scope":"vs-1.1.1","scope_specifier":"S","purpose_slug":"bugfix-auth","short_id":"a1b2","source_session_metadata":"m","references_forward_handoff":"n/a","purpose_paragraph":"why.","state_pointers_block":"- ptr","not_in_memory_bank_block":"- delta","workflow_deviations":"None.","in_flight_state_block":"- none","must_read_before_doing":"- /x","next_intended_actions":"do X","anti_actions_block":"- do NOT Y","return_template_stub":"stub","next_session_focus":"Land the fix first.","references_block":"- ref","suggested_skills_block":"- scaffold-dev:work-item"}'
  local out rc
  out="$("$_SD_BIN" render_template "$HERE/../templates/handoff.md.tmpl" "$vars" 2>/dev/null)"; rc=$?
  assert_eq "handoff render via dispatcher exits 0" "0" "$rc"
  local n; n="$(printf '%s\n' "$out" | grep -cE '^## [0-9]+\. ')"
  assert_eq "12 numbered sections rendered" "12" "$n"
  assert_contains "focus lead field" "Next-session focus:" "$out"
  assert_contains "References section (8)" "## 8. References" "$out"
  assert_contains "Suggested-skills section (10)" "## 10. Suggested skills / plugins" "$out"
  if printf '%s' "$out" | grep -qE '\{\{'; then
    FAIL=$((FAIL+1)); echo "  $(_color_fail 'FAIL') leftover placeholder in handoff render"
  else
    PASS=$((PASS+1)); echo "  $(_color_pass 'PASS') no leftover placeholders"
  fi
}

test_simple_substitution
test_multi_keys
test_repeated_key
test_missing_key_warns
test_empty_template
test_passthrough
test_html_entities
test_multiline
test_no_nested_expansion
test_dotted_key
test_work_item_template_contains_traceability
test_handoff_template_contains_traceability
test_work_item_spec_acs_block_renders_auto
test_dispatcher_fully_resolved_renders
test_dispatcher_handoff_12_sections

sd_test_summary
