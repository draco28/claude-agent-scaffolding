#!/usr/bin/env bash
# Tests for lib/rules.sh — R2 mcrule DSL parser + validator + filter
# Per SPEC §8.1-8.5 (scaffold-onboard v0.2) + PLAN T3.3.
#
# Assertion count target: 18 (slight over-budget OK; matches Phase 0/1 pattern).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/rules.sh"

FIXTURES="$HERE/fixtures/rules"
mkdir -p "$FIXTURES"

# ---------- Fixture authors (regenerated each run; fixtures/ is gitignored) -

write_all_fixtures() {
  cat > "$FIXTURES/single-banned-imports.md" <<'EOF'
# 03-code-patterns.md (fixture)

Some prose introducing the file.

## Machine-checkable rules

We forbid synchronous HTTP libraries in async code paths because they block the event loop.

<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3, httpx.Client]
<!-- mcrule:end -->

End of fixture.
EOF

  cat > "$FIXTURES/two-banned-imports.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

First rule: async HTTP forbidden.

<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3]
<!-- mcrule:end -->

Second rule: no debug libs anywhere.

<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
forbid: [pdb, ipdb]
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/single-coverage-floor.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

API layer must maintain 80%+ test coverage.

<!-- mcrule:start type=coverage_floor -->
paths: [src/api/]
threshold: 80
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/two-coverage-floor.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

<!-- mcrule:start type=coverage_floor -->
paths: [src/api/]
threshold: 80
<!-- mcrule:end -->

<!-- mcrule:start type=coverage_floor -->
paths: [src/handlers/, src/services/]
threshold: 70
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/single-style-invariants.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

Never use `print()` outside test files.

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
exclude: tests/**/*.py
forbid_pattern: '\bprint\('
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/two-style-invariants.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
exclude: tests/**/*.py
forbid_pattern: '\bprint\('
<!-- mcrule:end -->

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
forbid_pattern: 'TODO\(.*\)'
where: module_top_level
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/single-required-pattern.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

All API handlers must have a docstring with `Args:` and `Returns:` sections.

<!-- mcrule:start type=required_pattern -->
in: src/api/handlers/*.py
require_pattern: 'Args:\s+.*\s+Returns:'
where: function_def
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/two-required-pattern.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

<!-- mcrule:start type=required_pattern -->
in: src/api/handlers/*.py
require_pattern: 'Args:\s+.*\s+Returns:'
where: function_def
<!-- mcrule:end -->

<!-- mcrule:start type=required_pattern -->
in: src/models/*.py
exclude: src/models/_internal.py
require_pattern: '__all__\s*='
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/multiple-mixed.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3, httpx.Client]
<!-- mcrule:end -->

<!-- mcrule:start type=coverage_floor -->
paths: [src/api/]
threshold: 80
<!-- mcrule:end -->

<!-- mcrule:start type=style_invariants -->
in: src/**/*.py
exclude: tests/**/*.py
forbid_pattern: '\bprint\('
<!-- mcrule:end -->

<!-- mcrule:start type=required_pattern -->
in: src/api/handlers/*.py
require_pattern: 'Args:\s+.*\s+Returns:'
where: function_def
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/unknown-type.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

A forward-compat dependency age rule (v0.3+ type — should warn-and-skip in v0.2).

<!-- mcrule:start type=dependency_age -->
max_age_days: 365
paths: [requirements.txt]
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/mixed-known-and-unknown.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
forbid: [requests]
<!-- mcrule:end -->

<!-- mcrule:start type=dependency_age -->
max_age_days: 365
<!-- mcrule:end -->

<!-- mcrule:start type=coverage_floor -->
paths: [src/api/]
threshold: 80
<!-- mcrule:end -->

<!-- mcrule:start type=complexity_ceiling -->
max_cyclomatic: 10
<!-- mcrule:end -->
EOF

  cat > "$FIXTURES/malformed-missing-end.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

This block is missing the end sentinel. Parser must not crash; it should
skip the malformed block and emit nothing for it.

<!-- mcrule:start type=banned_imports -->
in: src/**/*.py
forbid: [requests]

And the file just ends without a closing sentinel.
EOF

  cat > "$FIXTURES/malformed-missing-type-attr.md" <<'EOF'
# 03-code-patterns.md (fixture)

## Machine-checkable rules

This start sentinel is missing the `type=` attribute. Parser must warn
and skip.

<!-- mcrule:start -->
in: src/**/*.py
forbid: [requests]
<!-- mcrule:end -->
EOF
}

write_all_fixtures

# ---------- 1. Sentinel parsing (8 assertions) ------------------------------

test_parse_single_banned_imports() {
  echo "test_parse_single_banned_imports:"
  local out
  out="$(sf_rules_parse "$FIXTURES/single-banned-imports.md" 2>/dev/null)"
  local count type
  count="$(echo "$out" | jq 'length')"
  type="$(echo "$out" | jq -r '.[0].type')"
  assert_eq "single banned_imports → 1 entry" "1" "$count"
  assert_eq "single banned_imports → type=banned_imports" "banned_imports" "$type"
}

test_parse_two_banned_imports() {
  echo "test_parse_two_banned_imports:"
  local out
  out="$(sf_rules_parse "$FIXTURES/two-banned-imports.md" 2>/dev/null)"
  local count
  count="$(echo "$out" | jq 'length')"
  assert_eq "two banned_imports → 2 entries" "2" "$count"
}

test_parse_single_coverage_floor_full_fields() {
  echo "test_parse_single_coverage_floor_full_fields:"
  local out
  out="$(sf_rules_parse "$FIXTURES/single-coverage-floor.md" 2>/dev/null)"
  local type paths threshold
  type="$(echo "$out" | jq -r '.[0].type')"
  paths="$(echo "$out" | jq -r '.[0].paths')"
  threshold="$(echo "$out" | jq -r '.[0].threshold')"
  assert_eq "coverage_floor → type preserved" "coverage_floor" "$type"
  assert_eq "coverage_floor → paths preserved" "[src/api/]" "$paths"
  assert_eq "coverage_floor → threshold preserved" "80" "$threshold"
}

test_parse_two_coverage_floor() {
  echo "test_parse_two_coverage_floor:"
  local out
  out="$(sf_rules_parse "$FIXTURES/two-coverage-floor.md" 2>/dev/null)"
  local count second_paths
  count="$(echo "$out" | jq 'length')"
  second_paths="$(echo "$out" | jq -r '.[1].paths')"
  assert_eq "two coverage_floor → 2 entries" "2" "$count"
  assert_eq "second coverage_floor paths preserved" \
    "[src/handlers/, src/services/]" "$second_paths"
}

test_parse_single_style_invariants_regex_preserved() {
  echo "test_parse_single_style_invariants_regex_preserved:"
  local out
  out="$(sf_rules_parse "$FIXTURES/single-style-invariants.md" 2>/dev/null)"
  local pattern
  pattern="$(echo "$out" | jq -r '.[0].forbid_pattern')"
  # Regex metacharacters preserved verbatim (single-quotes stripped is OK)
  assert_eq "style_invariants regex preserved verbatim" \
    "'\\bprint\\('" "$pattern"
}

test_parse_two_style_invariants() {
  echo "test_parse_two_style_invariants:"
  local out
  out="$(sf_rules_parse "$FIXTURES/two-style-invariants.md" 2>/dev/null)"
  local count
  count="$(echo "$out" | jq 'length')"
  assert_eq "two style_invariants → 2 entries" "2" "$count"
}

test_parse_single_required_pattern() {
  echo "test_parse_single_required_pattern:"
  local out
  out="$(sf_rules_parse "$FIXTURES/single-required-pattern.md" 2>/dev/null)"
  local type in_field where
  type="$(echo "$out" | jq -r '.[0].type')"
  in_field="$(echo "$out" | jq -r '.[0].in')"
  where="$(echo "$out" | jq -r '.[0].where')"
  assert_eq "required_pattern → type preserved" "required_pattern" "$type"
  assert_eq "required_pattern → in preserved" "src/api/handlers/*.py" "$in_field"
  assert_eq "required_pattern → where preserved" "function_def" "$where"
}

test_parse_two_required_pattern() {
  echo "test_parse_two_required_pattern:"
  local out
  out="$(sf_rules_parse "$FIXTURES/two-required-pattern.md" 2>/dev/null)"
  local count
  count="$(echo "$out" | jq 'length')"
  assert_eq "two required_pattern → 2 entries" "2" "$count"
}

# ---------- 2. Validation (5 assertions) ------------------------------------

test_validate_valid_banned_imports_body() {
  echo "test_validate_valid_banned_imports_body:"
  local body
  body="$(cat <<'EOF'
in: src/**/*.py
where: any_function_marked_async
forbid: [requests, urllib3]
EOF
)"
  set +e
  sf_rules_validate_block "$body" banned_imports >/dev/null 2>&1
  local rc=$?
  set -e 2>/dev/null || true
  assert_eq "valid banned_imports body → exit 0" "0" "$rc"
}

test_validate_banned_imports_missing_forbid() {
  echo "test_validate_banned_imports_missing_forbid:"
  local body
  body="$(cat <<'EOF'
in: src/**/*.py
where: any_function_marked_async
EOF
)"
  local stderr_capture; stderr_capture="$(mktemp -t sf-rules-stderr.XXXXXX)"
  set +e
  sf_rules_validate_block "$body" banned_imports >/dev/null 2>"$stderr_capture"
  local rc=$?
  set -e 2>/dev/null || true
  assert_eq "banned_imports missing forbid → exit 1" "1" "$rc"
  if grep -qi "forbid" "$stderr_capture"; then
    PASS=$((PASS+1)); echo "  ✓ stderr mentions 'forbid'"
  else
    FAIL=$((FAIL+1)); echo "  ✗ stderr does not mention 'forbid'"
    cat "$stderr_capture" | sed 's/^/      /'
  fi
  rm -f "$stderr_capture"
}

test_validate_coverage_floor_missing_threshold() {
  echo "test_validate_coverage_floor_missing_threshold:"
  local body
  body="$(cat <<'EOF'
paths: [src/api/]
EOF
)"
  set +e
  sf_rules_validate_block "$body" coverage_floor >/dev/null 2>&1
  local rc=$?
  set -e 2>/dev/null || true
  assert_eq "coverage_floor missing threshold → exit 1" "1" "$rc"
}

test_validate_unknown_type_arg() {
  echo "test_validate_unknown_type_arg:"
  local body
  body="$(cat <<'EOF'
foo: bar
EOF
)"
  # When caller passes an unknown type, validator must reject (validation
  # is type-aware; unknown types belong to the parse-time warn-and-skip
  # path, not validator path).
  set +e
  sf_rules_validate_block "$body" dependency_age >/dev/null 2>&1
  local rc=$?
  set -e 2>/dev/null || true
  assert_eq "unknown type → validator exit 1" "1" "$rc"
}

test_validate_all_optional_fields_accepted() {
  echo "test_validate_all_optional_fields_accepted:"
  local body
  body="$(cat <<'EOF'
in: src/**/*.py
exclude: tests/**/*.py
where: function_def
require_pattern: 'Args:\s+.*\s+Returns:'
EOF
)"
  set +e
  sf_rules_validate_block "$body" required_pattern >/dev/null 2>&1
  local rc=$?
  set -e 2>/dev/null || true
  assert_eq "required_pattern w/ all optional fields → exit 0" "0" "$rc"
}

# ---------- 3. Filter (3 assertions) ----------------------------------------

test_filter_banned_imports_from_mixed() {
  echo "test_filter_banned_imports_from_mixed:"
  local rules_json filtered count first_type
  rules_json="$(sf_rules_parse "$FIXTURES/multiple-mixed.md" 2>/dev/null)"
  filtered="$(sf_rules_filter "$rules_json" banned_imports)"
  count="$(echo "$filtered" | jq 'length')"
  first_type="$(echo "$filtered" | jq -r '.[0].type')"
  assert_eq "filter banned_imports from 4-type mix → 1 entry" "1" "$count"
  assert_eq "filtered entry has correct type" "banned_imports" "$first_type"
}

test_filter_nonmatching_type_returns_empty() {
  echo "test_filter_nonmatching_type_returns_empty:"
  local rules_json filtered count
  rules_json="$(sf_rules_parse "$FIXTURES/multiple-mixed.md" 2>/dev/null)"
  filtered="$(sf_rules_filter "$rules_json" no_such_type)"
  count="$(echo "$filtered" | jq 'length')"
  assert_eq "filter on non-matching type → empty JSON array" "0" "$count"
}

test_filter_multiple_matching() {
  echo "test_filter_multiple_matching:"
  local rules_json filtered count
  rules_json="$(sf_rules_parse "$FIXTURES/two-banned-imports.md" 2>/dev/null)"
  filtered="$(sf_rules_filter "$rules_json" banned_imports)"
  count="$(echo "$filtered" | jq 'length')"
  assert_eq "filter banned_imports from 2-banned-imports fixture → 2" "2" "$count"
}

# ---------- 4. Extensibility (2 assertions) ---------------------------------

test_parse_unknown_type_warns_and_skips() {
  echo "test_parse_unknown_type_warns_and_skips:"
  local stderr_capture; stderr_capture="$(mktemp -t sf-rules-warn.XXXXXX)"
  local out
  out="$(sf_rules_parse "$FIXTURES/unknown-type.md" 2>"$stderr_capture")"
  local count
  count="$(echo "$out" | jq 'length')"
  assert_eq "unknown type alone → 0 entries in JSON" "0" "$count"
  if grep -qi "dependency_age" "$stderr_capture"; then
    PASS=$((PASS+1)); echo "  ✓ stderr warns about 'dependency_age'"
  else
    FAIL=$((FAIL+1)); echo "  ✗ stderr does not warn about unknown type"
    cat "$stderr_capture" | sed 's/^/      /'
  fi
  rm -f "$stderr_capture"
}

test_parse_mixed_known_and_unknown_no_crash() {
  echo "test_parse_mixed_known_and_unknown_no_crash:"
  local stderr_capture; stderr_capture="$(mktemp -t sf-rules-mixed.XXXXXX)"
  local out rc
  set +e
  out="$(sf_rules_parse "$FIXTURES/mixed-known-and-unknown.md" 2>"$stderr_capture")"
  rc=$?
  set -e 2>/dev/null || true
  assert_eq "mixed known+unknown → parser exits 0 (no crash)" "0" "$rc"
  local count banned_count cov_count
  count="$(echo "$out" | jq 'length')"
  banned_count="$(echo "$out" | jq '[.[] | select(.type=="banned_imports")] | length')"
  cov_count="$(echo "$out" | jq '[.[] | select(.type=="coverage_floor")] | length')"
  assert_eq "mixed → only 2 known entries present" "2" "$count"
  assert_eq "mixed → banned_imports preserved" "1" "$banned_count"
  assert_eq "mixed → coverage_floor preserved" "1" "$cov_count"
  rm -f "$stderr_capture"
}

# ---------- Run all tests ---------------------------------------------------

echo "=== test-rules.sh ==="
# Sentinel parsing (8 assertions)
test_parse_single_banned_imports                # 1, 2
test_parse_two_banned_imports                    # 3
test_parse_single_coverage_floor_full_fields     # 4, 5, 6
test_parse_two_coverage_floor                    # 7, 8
test_parse_single_style_invariants_regex_preserved  # 9
test_parse_two_style_invariants                  # 10
test_parse_single_required_pattern               # 11, 12, 13
test_parse_two_required_pattern                  # 14

# Validation (5 assertions)
test_validate_valid_banned_imports_body          # 15
test_validate_banned_imports_missing_forbid      # 16, 17
test_validate_coverage_floor_missing_threshold   # 18
test_validate_unknown_type_arg                   # 19
test_validate_all_optional_fields_accepted       # 20

# Filter (3 assertions)
test_filter_banned_imports_from_mixed            # 21, 22
test_filter_nonmatching_type_returns_empty       # 23
test_filter_multiple_matching                    # 24

# Extensibility (2 assertions)
test_parse_unknown_type_warns_and_skips          # 25, 26
test_parse_mixed_known_and_unknown_no_crash      # 27, 28, 29, 30

report_results
