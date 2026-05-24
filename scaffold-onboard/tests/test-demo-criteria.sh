#!/usr/bin/env bash
# Tests for lib/demo-criteria.sh — auto:/user: demo criteria grammar parser + writer.
# Per SPEC §9 (scaffold-onboard v0.2) + PLAN T3.5 (~14 assertions).
#
# API under test (per SPEC §9.3):
#   sf_demo_parse_line <line_text>             → JSON or exit 1
#   sf_demo_parse_slice <roadmap_md> <slice_id> → JSON array (markdown source)
#   sf_demo_append <target_path> <slice_id> <criterion_line> → idempotent write
#     - target_path *.md  → markdown mode (writes to ##### Demo criteria block)
#     - target_path *.json → state mode (writes to vertical_slices[].demo_criteria[])
#
# Grammar (SPEC §9.1): arrow is the literal U+2192 (→), NOT ASCII ->.
# ASCII -> is a grammar violation (exit 1).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/demo-criteria.sh"

# Fixtures dir is gitignored (per .gitignore line 24); generate inline.
FIXTURE_DIR="$HERE/fixtures"
mkdir -p "$FIXTURE_DIR"

write_roadmap_fixture() {
  cat > "$1" <<'EOF'
# Project roadmap (test fixture)

## Phase 1 — Foundation

### Sprint 1.1 — Bootstrap

#### VS-1.1.1: Pipeline boots end-to-end

A minimal slice that boots the pipeline.

##### Demo criteria

- [ ] auto: `pytest tests/integration/test_pipeline.py` → expected: exit 0
- [ ] user: Navigate to localhost:3000/insights → expected: action-needed card visible

#### VS-1.1.2: Health endpoint returns 200

Trivial health probe slice.

##### Demo criteria

- [ ] auto: `curl -s localhost:8000/health` → expected: output contains "ok"
- [ ] user: Click status icon — verify badge turns green → expected: badge green within 2s
- [ ] auto: `pytest tests/test_health.py -q` → expected: exit 0

## Phase 2 — Iteration

### Sprint 2.1 — UX

#### VS-2.1.1: Chatbot panel opens

##### Demo criteria

- [ ] user: Click chatbot icon → expected: chat panel opens within 5s
EOF
}

write_state_fixture() {
  cat > "$1" <<'EOF'
{
  "schema_version": "1.0",
  "checkpoint": "R1.C",
  "vertical_slices": [
    {
      "id": "VS-1.1.1",
      "title": "Pipeline boots end-to-end",
      "demo_criteria": [
        "auto: pytest tests/integration/test_pipeline.py → expected: exit 0"
      ]
    },
    {
      "id": "VS-1.1.2",
      "title": "Health endpoint returns 200",
      "demo_criteria": []
    }
  ]
}
EOF
}

# Read-only roadmap fixture for parse_* tests (created once, reused).
ROADMAP_FIXTURE="$FIXTURE_DIR/roadmap-with-demos.md"
write_roadmap_fixture "$ROADMAP_FIXTURE"

# Per-test setup: copy a fresh fixture into a tmp dir for mutating tests.
test_setup_tmp_fixtures() {
  TMP_DIR="$(mktemp -d -t scaffold-onboard-demo.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  TMP_ROADMAP="$TMP_DIR/ROADMAP.md"
  TMP_STATE="$TMP_DIR/project-roadmap.json"
  write_roadmap_fixture "$TMP_ROADMAP"
  write_state_fixture   "$TMP_STATE"
}

teardown_tmp_fixtures() {
  cd "$HERE" 2>/dev/null || cd /tmp
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
  TMP_DIR=""
}

# ============================================================================
# Group 1 — sf_demo_parse_line (single-line validator)
# ============================================================================
echo ""
echo "── sf_demo_parse_line: grammar + JSON shape ───────────────────────────"

# A1: auto form with exit-code expected
out="$(sf_demo_parse_line "- [ ] auto: \`pytest\` → expected: exit 0" 2>/dev/null)"
prefix="$(printf '%s' "$out" | jq -r '.prefix' 2>/dev/null)"
body="$(printf '%s' "$out"   | jq -r '.body'   2>/dev/null)"
expected="$(printf '%s' "$out" | jq -r '.expected' 2>/dev/null)"
assert_eq "A1a parse auto line — prefix"   "auto"      "$prefix"
assert_eq "A1b parse auto line — body"     "\`pytest\`" "$body"
assert_eq "A1c parse auto line — expected" "exit 0"    "$expected"

# A2: auto form with pattern-in-output expected
out="$(sf_demo_parse_line "- [ ] auto: \`curl localhost:8000\` → expected: output contains \"X\"" 2>/dev/null)"
prefix="$(printf '%s' "$out" | jq -r '.prefix')"
expected="$(printf '%s' "$out" | jq -r '.expected')"
assert_eq "A2a parse auto pattern — prefix"   "auto" "$prefix"
assert_eq "A2b parse auto pattern — expected" "output contains \"X\"" "$expected"

# A3: user form
out="$(sf_demo_parse_line "- [ ] user: Navigate to localhost:3000 → expected: page loads" 2>/dev/null)"
prefix="$(printf '%s' "$out" | jq -r '.prefix')"
body="$(printf '%s' "$out"   | jq -r '.body')"
expected="$(printf '%s' "$out" | jq -r '.expected')"
assert_eq "A3a parse user line — prefix"   "user"                   "$prefix"
assert_eq "A3b parse user line — body"     "Navigate to localhost:3000" "$body"
assert_eq "A3c parse user line — expected" "page loads"             "$expected"

# A4: ASCII -> is a grammar violation
set +e
sf_demo_parse_line "- [ ] auto: \`pytest\` -> expected: exit 0" >/dev/null 2>&1
rc=$?
set -e 2>/dev/null || true
assert_eq "A4 ASCII -> rejected (exit 1)" "1" "$rc"

# A5: missing 'expected:' tail
set +e
sf_demo_parse_line "- [ ] auto: \`pytest\` → exit 0" >/dev/null 2>&1
rc=$?
set -e 2>/dev/null || true
assert_eq "A5 missing 'expected:' clause rejected (exit 1)" "1" "$rc"

# ============================================================================
# Group 2 — sf_demo_parse_slice (file-level parser)
# ============================================================================
echo ""
echo "── sf_demo_parse_slice: array shape per slice ─────────────────────────"

# A6: VS-1.1.2 has 3 criteria in the fixture
arr_json="$(sf_demo_parse_slice "$ROADMAP_FIXTURE" "VS-1.1.2" 2>/dev/null)"
count="$(printf '%s' "$arr_json" | jq 'length' 2>/dev/null)"
assert_eq "A6 sf_demo_parse_slice VS-1.1.2 returns 3 criteria" "3" "$count"

# A7: VS-9.9.9 missing → empty array (documented choice: empty array, not exit 1)
set +e
arr_json="$(sf_demo_parse_slice "$ROADMAP_FIXTURE" "VS-9.9.9" 2>/dev/null)"
rc=$?
set -e 2>/dev/null || true
count="$(printf '%s' "$arr_json" | jq 'length' 2>/dev/null)"
assert_eq "A7a sf_demo_parse_slice non-existent slice — exit 0" "0" "$rc"
assert_eq "A7b sf_demo_parse_slice non-existent slice — empty array" "0" "$count"

# A8: only the named slice's criteria are returned (no bleed-through)
arr_json="$(sf_demo_parse_slice "$ROADMAP_FIXTURE" "VS-2.1.1" 2>/dev/null)"
count="$(printf '%s' "$arr_json" | jq 'length' 2>/dev/null)"
first_body="$(printf '%s' "$arr_json" | jq -r '.[0].body')"
assert_eq "A8a sf_demo_parse_slice VS-2.1.1 returns 1 criterion (no bleed)" "1" "$count"
assert_eq "A8b sf_demo_parse_slice VS-2.1.1 body matches" "Click chatbot icon" "$first_body"

# ============================================================================
# Group 3 — sf_demo_append + idempotence (markdown + state)
# ============================================================================
echo ""
echo "── sf_demo_append: idempotent markdown append ─────────────────────────"

test_setup_tmp_fixtures

# A9: append a new line under VS-1.1.1 Demo criteria
new_line="- [ ] auto: \`pytest tests/test_new.py\` → expected: exit 0"
sf_demo_append "$TMP_ROADMAP" "VS-1.1.1" "$new_line" >/dev/null 2>&1
rc=$?
got="$(grep -c -F -- "$new_line" "$TMP_ROADMAP")"
assert_eq "A9a sf_demo_append (markdown) — exit 0" "0" "$rc"
assert_eq "A9b sf_demo_append (markdown) — line present exactly once" "1" "$got"

# A10: same call twice — idempotent (still exactly once)
sf_demo_append "$TMP_ROADMAP" "VS-1.1.1" "$new_line" >/dev/null 2>&1
got="$(grep -c -F -- "$new_line" "$TMP_ROADMAP")"
assert_eq "A10 sf_demo_append idempotent (no duplicate on re-supply)" "1" "$got"

# A11: append a *different* line — pre-existing line still present
another_line="- [ ] user: Open settings — verify toggle persists → expected: state retained after reload"
sf_demo_append "$TMP_ROADMAP" "VS-1.1.1" "$another_line" >/dev/null 2>&1
got_a="$(grep -c -F -- "$new_line"     "$TMP_ROADMAP")"
got_b="$(grep -c -F -- "$another_line" "$TMP_ROADMAP")"
assert_eq "A11a sf_demo_append second line — original preserved" "1" "$got_a"
assert_eq "A11b sf_demo_append second line — new line appended"  "1" "$got_b"

# A12: state-mode append (target ends in .json)
state_line="auto: pytest tests/test_state_append.py → expected: exit 0"
sf_demo_append "$TMP_STATE" "VS-1.1.2" "$state_line" >/dev/null 2>&1
rc=$?
got_arr="$(jq -r '.vertical_slices[] | select(.id=="VS-1.1.2") | .demo_criteria[]' "$TMP_STATE")"
assert_eq "A12a sf_demo_append (state) — exit 0" "0" "$rc"
assert_eq "A12b sf_demo_append (state) — entry appended" "$state_line" "$got_arr"

# A12c: state-mode idempotent
sf_demo_append "$TMP_STATE" "VS-1.1.2" "$state_line" >/dev/null 2>&1
count="$(jq -r '.vertical_slices[] | select(.id=="VS-1.1.2") | .demo_criteria | length' "$TMP_STATE")"
assert_eq "A12c sf_demo_append (state) idempotent — length 1" "1" "$count"

teardown_tmp_fixtures

# ============================================================================
# Group 4 — Grammar edge cases
# ============================================================================
echo ""
echo "── grammar edge cases ────────────────────────────────────────────────"

# A13: command body containing an arrow inside flags — first U+2192 after prefix is the delimiter
# (Body contains nested →; the first → after "auto: " is the delimiter.)
edge_line="- [ ] auto: \`echo hi\` → expected: output contains \"→\""
out="$(sf_demo_parse_line "$edge_line" 2>/dev/null)"
prefix="$(printf '%s' "$out" | jq -r '.prefix')"
expected="$(printf '%s' "$out" | jq -r '.expected')"
assert_eq "A13a edge: first → is delimiter — prefix"   "auto" "$prefix"
assert_eq "A13b edge: arrow preserved in expected"     "output contains \"→\"" "$expected"

# A14: user line with em-dash (—) in body — em-dash is preserved; U+2192 is delimiter
emdash_line="- [ ] user: Open page — verify X → expected: X visible"
out="$(sf_demo_parse_line "$emdash_line" 2>/dev/null)"
body="$(printf '%s' "$out" | jq -r '.body')"
expected="$(printf '%s' "$out" | jq -r '.expected')"
assert_eq "A14a em-dash preserved in body" "Open page — verify X" "$body"
assert_eq "A14b em-dash line — expected"   "X visible"             "$expected"

report_results
