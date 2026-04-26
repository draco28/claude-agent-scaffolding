#!/usr/bin/env bash
#
# scaffold/tests/test-claude-md.sh — regression suite for lib/claude-md.sh.
#
# Tests the two-layer CLAUDE.md generator: seeding from templates,
# concatenation order, footer timestamp, manual-edit detection, opt-out.
#
# Isolation: CLAUDE_PLUGIN_DATA + tempdir git repo + trap cleanup.
#
# Usage: bash scaffold/tests/test-claude-md.sh

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_CMD="$PLUGIN_ROOT/lib/claude-md.sh"

TMPDIR_TESTS="$(mktemp -d -t scaffold-cmd-tests-XXXXXX)"
export CLAUDE_PLUGIN_DATA="$TMPDIR_TESTS/data"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$CLAUDE_PLUGIN_DATA"

cleanup() { rm -rf "$TMPDIR_TESTS"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED_TESTS=()
pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "$2" ]] && printf '      %s\n' "$2"; }

# Source the lib (re-sources state.sh and repo.sh).
# shellcheck source=../lib/claude-md.sh
source "$LIB_CMD"

# Make a fresh git repo for each test run; cd into it.
REPO="$TMPDIR_TESTS/repo"
mkdir -p "$REPO"
( cd "$REPO" && git init -q -b main && git config user.email t@t && git config user.name t \
  && touch .keep && git add .keep && git commit -q -m init )
cd "$REPO"

# Initialize scaffold state so claude_md_managed defaults to true
sf_init_state >/dev/null

echo ""
echo "── path resolution ──"

# C1 — paths point inside CLAUDE_PLUGIN_DATA
[[ "$(sf_personal_defaults_path)" == "$CLAUDE_PLUGIN_DATA/personal-defaults.md" ]] \
  && pass "C1 sf_personal_defaults_path under CLAUDE_PLUGIN_DATA" \
  || fail "C1 sf_personal_defaults_path"
[[ "$(sf_project_layer_path)" == *"/projects/"*"/claude-md-project.md" ]] \
  && pass "C2 sf_project_layer_path under projects/<hash>/" \
  || fail "C2 sf_project_layer_path" "got $(sf_project_layer_path)"
[[ "$(sf_claude_md_path)" == "$REPO/CLAUDE.md" ]] \
  && pass "C3 sf_claude_md_path is <repo>/CLAUDE.md" \
  || fail "C3 sf_claude_md_path"

echo ""
echo "── seeding ──"

# C4 — seed personal-defaults from template
[[ ! -e "$(sf_personal_defaults_path)" ]] && pass "C4a personal-defaults missing initially" \
  || fail "C4a personal-defaults missing initially"
sf_seed_personal_defaults
[[ -r "$(sf_personal_defaults_path)" ]] && pass "C4b sf_seed_personal_defaults creates file" \
  || fail "C4b sf_seed_personal_defaults"

# C5 — seed project layer with substitutions
sf_seed_project_layer
proj_path="$(sf_project_layer_path)"
[[ -r "$proj_path" ]] && pass "C5a sf_seed_project_layer creates file" \
  || fail "C5a sf_seed_project_layer"
grep -q "$(basename "$REPO")" "$proj_path" && pass "C5b project_name substitution" \
  || fail "C5b project_name substitution" "missing repo name in: $(cat "$proj_path")"

# C6 — sf_seed_personal_defaults idempotent
echo "user-edited content" > "$(sf_personal_defaults_path)"
sf_seed_personal_defaults
content="$(cat "$(sf_personal_defaults_path)")"
[[ "$content" == "user-edited content" ]] && pass "C6 seed_personal_defaults idempotent" \
  || fail "C6 seed_personal_defaults idempotent" "got: $content"

echo ""
echo "── generation ──"

# C7 — generate produces output file
sf_generate_claude_md >/dev/null
[[ -r "$REPO/CLAUDE.md" ]] && pass "C7 sf_generate_claude_md writes <repo>/CLAUDE.md" \
  || fail "C7 sf_generate_claude_md writes file"

# C8 — output contains both layers
grep -q "Personal preferences" "$REPO/CLAUDE.md" && \
  grep -q "Project: $(basename "$REPO")" "$REPO/CLAUDE.md" && \
  pass "C8 generated file contains both layers" \
  || fail "C8 generated file contains both layers"

# C9 — output contains user-edited personal content
grep -q "user-edited content" "$REPO/CLAUDE.md" && pass "C9 user content in personal layer carried through" \
  || fail "C9 user content in personal layer carried through"

# C10 — footer marker present
grep -q "scaffold-claude-md generated-at:" "$REPO/CLAUDE.md" && pass "C10 footer marker present" \
  || fail "C10 footer marker"

# C11 — footer timestamp parseable
ts="$(sf_claude_md_footer_timestamp)"
[[ "$ts" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] && pass "C11 footer timestamp ISO-8601" \
  || fail "C11 footer timestamp" "got '$ts'"

echo ""
echo "── manual-edit detection ──"

# C12 — fresh-generated file is NOT manually edited
sf_claude_md_manually_edited; rc=$?
[[ $rc -eq 1 ]] && pass "C12 fresh file → not manually edited" \
  || fail "C12 fresh file → not manually edited" "got rc=$rc"

# C13 — backdating footer (so mtime > footer + 60s) → manually edited
old_ts="2020-01-01T00:00:00Z"
sed -i.bak "s|generated-at: [^ ]* |generated-at: $old_ts |" "$REPO/CLAUDE.md" 2>/dev/null \
  || sed -i '' "s|generated-at: [^ ]* |generated-at: $old_ts |" "$REPO/CLAUDE.md" 2>/dev/null
rm -f "$REPO/CLAUDE.md.bak"
touch "$REPO/CLAUDE.md"
sf_claude_md_manually_edited; rc=$?
[[ $rc -eq 0 ]] && pass "C13 backdated footer → manually edited" \
  || fail "C13 backdated footer → manually edited" "got rc=$rc, footer_ts=$(sf_claude_md_footer_timestamp)"

echo ""
echo "── opt-out ──"

# C14 — claude_md_managed=false refuses generation
sf_state_apply_typed '.claude_md_managed = $val' false
rm -f "$REPO/CLAUDE.md"
sf_generate_claude_md 2>/dev/null
[[ ! -e "$REPO/CLAUDE.md" ]] && pass "C14 claude_md_managed=false refuses generation" \
  || fail "C14 claude_md_managed=false refuses generation"

# Restore
sf_state_apply_typed '.claude_md_managed = $val' true

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
