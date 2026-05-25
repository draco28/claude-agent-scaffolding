#!/usr/bin/env bash
# tests/test-render.sh — 10 tests for lib/render.sh

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

sd_test_summary
