#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/render.sh"
source "$HERE/../lib/state.sh"

FIXTURE_DIR="$HERE/fixtures"
mkdir -p "$FIXTURE_DIR"

test_simple_substitution() {
  echo "test_simple_substitution:"
  local tmpl="$FIXTURE_DIR/simple.tmpl"
  echo "Hello, {{name}}! You are {{age}}." > "$tmpl"
  local out
  out="$(sf_render "$tmpl" name=World age=42)"
  assert_eq "simple substitution" "Hello, World! You are 42." "$out"
}

test_missing_var_becomes_todo() {
  echo "test_missing_var_becomes_todo:"
  local tmpl="$FIXTURE_DIR/missing.tmpl"
  echo "Project: {{name}}; Owner: {{owner}}" > "$tmpl"
  local out
  out="$(sf_render "$tmpl" name=foo)"
  if echo "$out" | grep -q "TODO: owner"; then
    PASS=$((PASS+1)); echo "  ✓ missing var rendered as TODO"
  else
    FAIL=$((FAIL+1)); echo "  ✗ missing var not flagged: $out"
  fi
}

test_value_with_spaces() {
  echo "test_value_with_spaces:"
  local tmpl="$FIXTURE_DIR/spaces.tmpl"
  echo "Pitch: {{pitch}}" > "$tmpl"
  local out
  out="$(sf_render "$tmpl" "pitch=todo-cli — a fast local-first task manager.")"
  assert_eq "spaces in value" \
    "Pitch: todo-cli — a fast local-first task manager." \
    "$out"
}

test_if_true() {
  echo "test_if_true:"
  local tmpl="$FIXTURE_DIR/if.tmpl"
  cat > "$tmpl" <<'EOF'
Pre.
{{#if has_llm}}
LLM section here.
{{/if}}
Post.
EOF
  local out
  out="$(sf_render "$tmpl" has_llm=true)"
  if echo "$out" | grep -q "LLM section here"; then
    PASS=$((PASS+1)); echo "  ✓ if-true renders block"
  else
    FAIL=$((FAIL+1)); echo "  ✗ if-true skipped block: $out"
  fi
}

test_if_false() {
  echo "test_if_false:"
  local tmpl="$FIXTURE_DIR/if.tmpl"
  local out
  out="$(sf_render "$tmpl" has_llm=false)"
  if echo "$out" | grep -q "LLM section here"; then
    FAIL=$((FAIL+1)); echo "  ✗ if-false rendered block"
  else
    PASS=$((PASS+1)); echo "  ✓ if-false skipped block"
  fi
}

test_simple_substitution
test_missing_var_becomes_todo
test_value_with_spaces
test_if_true
test_if_false
report_results
