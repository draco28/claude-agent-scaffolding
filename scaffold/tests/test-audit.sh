#!/usr/bin/env bash
#
# scaffold/tests/test-audit.sh — regression suite for lib/audit.sh.
#
# Tests the gap-analysis checks: presence/absence of expected files, status
# values (pass/warn/info/fail), and renderer output.
#
# Isolation: tempdir git repos with various file layouts, CLAUDE_PLUGIN_DATA
# under /tmp, trap cleanup.
#
# Usage: bash scaffold/tests/test-audit.sh

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_AUDIT="$PLUGIN_ROOT/lib/audit.sh"

TMPDIR_TESTS="$(mktemp -d -t scaffold-audit-tests-XXXXXX)"
export CLAUDE_PLUGIN_DATA="$TMPDIR_TESTS/data"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$CLAUDE_PLUGIN_DATA"

cleanup() { rm -rf "$TMPDIR_TESTS"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED_TESTS=()
pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "$2" ]] && printf '      %s\n' "$2"; }

# Source the audit lib (re-sources state.sh + repo.sh).
# shellcheck source=../lib/audit.sh
source "$LIB_AUDIT"

# Helper: extract status for a given check name from TSV rows.
status_for() {
  local rows="$1" name="$2"
  echo "$rows" | awk -F'\t' -v n="$name" '$2 == n {print $3; exit}'
}

# ── Fixture A: empty repo (most checks should fail) ─────────────────────────
make_empty_repo() {
  local d="$TMPDIR_TESTS/empty"; mkdir -p "$d"
  ( cd "$d" && git init -q -b main && git config user.email t@t && git config user.name t \
    && touch .keep && git add .keep && git commit -q -m init )
  echo "$d"
}

# ── Fixture B: well-formed repo (most pass) ─────────────────────────────────
make_full_repo() {
  local d="$TMPDIR_TESTS/full"; mkdir -p "$d"
  ( cd "$d" && git init -q -b main && git config user.email t@t && git config user.name t )
  cat > "$d/README.md" <<'XEOF'
# example

A test project.

## Quickstart

Run it.
XEOF
  echo "MIT" > "$d/LICENSE"
  echo "*.pyc" > "$d/.gitignore"
  echo "[project]" > "$d/pyproject.toml"
  mkdir -p "$d/docs/adr" && echo "# ADR-0001" > "$d/docs/adr/0001-foo.md"
  mkdir -p "$d/docs/runbooks" && touch "$d/docs/runbooks/.gitkeep"
  mkdir -p "$d/docs/slices" && touch "$d/docs/slices/.gitkeep"
  echo "# Changelog" > "$d/CHANGELOG.md"
  mkdir -p "$d/tests" && touch "$d/tests/conftest.py"
  ( cd "$d" && git add . && git commit -q -m init )
  echo "$d"
}

# ── Fixture C: LLM project ──────────────────────────────────────────────────
make_llm_repo() {
  local d="$TMPDIR_TESTS/llm"; mkdir -p "$d"
  ( cd "$d" && git init -q -b main && git config user.email t@t && git config user.name t )
  printf '%s\n' "[project]" "dependencies=['anthropic']" > "$d/pyproject.toml"
  ( cd "$d" && git add . && git commit -q -m init )
  echo "$d"
}

echo ""
echo "── Fixture A: empty repo (most checks fail) ──"
EMPTY="$(make_empty_repo)"
ROWS_EMPTY="$( cd "$EMPTY" && sf_audit_run )"

s="$(status_for "$ROWS_EMPTY" "README.md exists")"
[[ "$s" == "fail" ]] && pass "A1 empty repo: README.md exists → fail" || fail "A1 empty README" "got '$s'"

s="$(status_for "$ROWS_EMPTY" "License file exists")"
[[ "$s" == "fail" ]] && pass "A2 empty repo: license → fail" || fail "A2 empty license"

s="$(status_for "$ROWS_EMPTY" ".gitignore exists")"
[[ "$s" == "fail" ]] && pass "A3 empty repo: gitignore → fail" || fail "A3 empty gitignore"

s="$(status_for "$ROWS_EMPTY" "docs/adr/ exists")"
[[ "$s" == "fail" ]] && pass "A4 empty repo: docs/adr → fail" || fail "A4 empty adrs"

s="$(status_for "$ROWS_EMPTY" "docs/runbooks/ exists")"
[[ "$s" == "info" ]] && pass "A5 empty repo: runbooks → info (optional)" || fail "A5 empty runbooks" "got '$s'"

s="$(status_for "$ROWS_EMPTY" "Test framework detected")"
[[ "$s" == "warn" ]] && pass "A6 empty repo: test framework → warn" || fail "A6 empty tests"

echo ""
echo "── Fixture B: well-formed repo (most pass) ──"
FULL="$(make_full_repo)"
ROWS_FULL="$( cd "$FULL" && sf_audit_run )"

s="$(status_for "$ROWS_FULL" "README.md exists")"
[[ "$s" == "pass" ]] && pass "B1 full repo: README.md → pass" || fail "B1 full README" "got '$s'"

s="$(status_for "$ROWS_FULL" "Has Quickstart section")"
[[ "$s" == "pass" ]] && pass "B2 full repo: Quickstart heading → pass" || fail "B2 quickstart" "got '$s'"

s="$(status_for "$ROWS_FULL" "License file exists")"
[[ "$s" == "pass" ]] && pass "B3 full repo: license → pass" || fail "B3 license"

s="$(status_for "$ROWS_FULL" ".gitignore exists")"
[[ "$s" == "pass" ]] && pass "B4 full repo: gitignore → pass" || fail "B4 gitignore"

s="$(status_for "$ROWS_FULL" "At least one ADR")"
[[ "$s" == "pass" ]] && pass "B5 full repo: has ADR → pass" || fail "B5 adr" "got '$s'"

s="$(status_for "$ROWS_FULL" "Test framework detected")"
[[ "$s" == "pass" ]] && pass "B6 full repo: pytest detected → pass" || fail "B6 tests" "got '$s'"

s="$(status_for "$ROWS_FULL" "CHANGELOG.md exists")"
[[ "$s" == "pass" ]] && pass "B7 full repo: changelog → pass" || fail "B7 changelog"

# B8 — README without Quickstart → warn
mkdir -p "$TMPDIR_TESTS/no-quick"
cd "$TMPDIR_TESTS/no-quick" && git init -q -b main && git config user.email t@t && git config user.name t
echo "# no quick" > README.md
git add . && git commit -q -m init
ROWS_NQ="$(sf_audit_run)"
s="$(status_for "$ROWS_NQ" "Has Quickstart section")"
[[ "$s" == "warn" ]] && pass "B8 README without Quickstart → warn" || fail "B8 no-quickstart warn" "got '$s'"

echo ""
echo "── Fixture C: LLM project (LLM-specific checks fire) ──"
LLM="$(make_llm_repo)"
ROWS_LLM="$( cd "$LLM" && sf_audit_run )"

s="$(status_for "$ROWS_LLM" "evals/ directory")"
[[ "$s" == "warn" ]] && pass "C1 LLM repo without evals/ → warn" || fail "C1 evals warn" "got '$s'"

s="$(status_for "$ROWS_LLM" "Model card documented")"
[[ "$s" == "warn" ]] && pass "C2 LLM repo without model card → warn" || fail "C2 model card" "got '$s'"

# Same checks should NOT fire on non-LLM repo
s="$(status_for "$ROWS_FULL" "evals/ directory")"
[[ -z "$s" ]] && pass "C3 non-LLM repo: no evals/ check fired" || fail "C3 non-LLM evals fired"

echo ""
echo "── Renderer + summary ──"

# R1 — renderer produces a markdown table
md="$( cd "$EMPTY" && sf_audit_run | sf_audit_render_md )"
echo "$md" | grep -q "^| Status | Category | Check | Detail |" \
  && pass "R1 renderer outputs markdown table header" \
  || fail "R1 renderer header"

# R2 — summary returns 1 when there are fails
( cd "$EMPTY" && sf_audit_run | sf_audit_summary >/dev/null 2>&1; [[ $? -eq 1 ]] ) \
  && pass "R2 summary returns 1 with fails" \
  || fail "R2 summary returns 1 with fails"

# R3 — summary returns 0 when no fails
( cd "$FULL" && sf_audit_run | sf_audit_summary >/dev/null 2>&1; [[ $? -eq 0 ]] ) \
  && pass "R3 summary returns 0 with no fails" \
  || fail "R3 summary returns 0 with no fails"

# R4 — summary text shape
sumline="$( cd "$EMPTY" && sf_audit_run | sf_audit_summary 2>&1 | tail -1 )"
echo "$sumline" | grep -qE 'pass · [0-9]+ warn · [0-9]+ info · [0-9]+ fail' \
  && pass "R4 summary line format" \
  || fail "R4 summary format" "got '$sumline'"

# Summary
TOTAL=$((PASS+FAIL))
echo ""
echo "─────────────────────────────────"
if [[ $FAIL -eq 0 ]]; then
  printf '\033[32mAll %d tests passed.\033[0m\n' "$TOTAL"
  exit 0
else
  printf '\033[31m%d/%d tests failed.\033[0m\n' "$FAIL" "$TOTAL"
  for t in "${FAILED_TESTS[@]}"; do printf '  - %s\n' "$t"; done
  exit 1
fi
