#!/usr/bin/env bash
#
# scaffold/tests/test-state.sh — regression suite for lib/repo.sh and lib/state.sh.
#
# Isolation:
#   - CLAUDE_PLUGIN_DATA points at a tempdir under /tmp.
#   - Tests cd into a tempdir with `git init` so repo functions have something
#     real to read.
#   - Trap on EXIT cleans up tempfiles.
#
# Usage: bash scaffold/tests/test-state.sh

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB_STATE="$PLUGIN_ROOT/lib/state.sh"

TMPDIR_TESTS="$(mktemp -d -t scaffold-tests-XXXXXX)"
export CLAUDE_PLUGIN_DATA="$TMPDIR_TESTS/data"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$CLAUDE_PLUGIN_DATA"

cleanup() { rm -rf "$TMPDIR_TESTS"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED_TESTS=()
pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "$2" ]] && printf '      %s\n' "$2"; }

# Helper: create a tempdir, git-init it, optionally with files, cd into it.
make_repo() {
  local subdir="$1"
  local repodir="$TMPDIR_TESTS/$subdir"
  mkdir -p "$repodir"
  ( cd "$repodir" && git init -q -b main && git config user.email t@t && git config user.name t \
    && touch .keep && git add .keep && git commit -q -m init )
  printf '%s' "$repodir"
}

# Source the libs (re-sources repo.sh internally).
# shellcheck source=../lib/state.sh
source "$LIB_STATE"

echo ""
echo "── repo helpers (lib/repo.sh) ──"

# R1 — sf_repo_root in a git repo
REPO1="$(make_repo r1)"
( cd "$REPO1" && [[ "$(sf_repo_root)" == "$REPO1" ]] ) && pass "R1 sf_repo_root in git repo" || fail "R1 sf_repo_root in git repo"

# R2 — sf_repo_root falls back to pwd outside git
NONGIT="$TMPDIR_TESTS/nongit"; mkdir -p "$NONGIT"
( cd "$NONGIT" && [[ "$(sf_repo_root)" == "$NONGIT" ]] ) && pass "R2 sf_repo_root non-git → pwd" || fail "R2 sf_repo_root non-git → pwd"

# R3 — sf_repo_hash deterministic
( cd "$REPO1" && [[ "$(sf_repo_hash)" == "$(sf_repo_hash)" ]] ) && pass "R3 sf_repo_hash deterministic" || fail "R3 sf_repo_hash deterministic"

# R4 — sf_repo_hash differs by repo (different paths, no remote)
REPO2="$(make_repo r2)"
H1="$( cd "$REPO1" && sf_repo_hash )"
H2="$( cd "$REPO2" && sf_repo_hash )"
[[ "$H1" != "$H2" ]] && pass "R4 sf_repo_hash differs across repos" || fail "R4 sf_repo_hash differs across repos" "H1=$H1 H2=$H2"

# R5 — sf_repo_hash uses remote URL when present
( cd "$REPO1" && git remote add origin https://example.com/test.git )
H1_remote="$( cd "$REPO1" && sf_repo_hash )"
[[ "$H1" != "$H1_remote" ]] && pass "R5 sf_repo_hash uses remote URL when set" || fail "R5 sf_repo_hash uses remote URL"

# R6 — sf_branch returns main
( cd "$REPO1" && [[ "$(sf_branch)" == "main" ]] ) && pass "R6 sf_branch on main" || fail "R6 sf_branch on main" "got $(cd "$REPO1" && sf_branch)"

# R7 — sf_branch_safe replaces /
( cd "$REPO1" && git checkout -q -b feat/auth )
( cd "$REPO1" && [[ "$(sf_branch_safe)" == "feat__auth" ]] ) && pass "R7 sf_branch_safe replaces /" || fail "R7 sf_branch_safe replaces /" "got $(cd "$REPO1" && sf_branch_safe)"

# R8 — detached HEAD
( cd "$REPO1" && git checkout -q "$(git rev-parse HEAD)" )
b="$( cd "$REPO1" && sf_branch )"
[[ "$b" == _detached_* ]] && pass "R8 sf_branch detached → _detached_*" || fail "R8 sf_branch detached" "got $b"

# R9 — unborn repo
UNBORN="$TMPDIR_TESTS/unborn"; mkdir -p "$UNBORN"
( cd "$UNBORN" && git init -q -b main )
b="$( cd "$UNBORN" && sf_branch )"
[[ "$b" == "_unborn" ]] && pass "R9 sf_branch unborn → _unborn" || fail "R9 sf_branch unborn" "got $b"

# R10 — non-git dir
b="$( cd "$NONGIT" && sf_branch )"
[[ "$b" == "_no_git" ]] && pass "R10 sf_branch non-git → _no_git" || fail "R10 sf_branch non-git" "got $b"

# R11 — stack detection: python via pyproject.toml
PYPROJ="$(make_repo pyproj)"
echo "[project]" > "$PYPROJ/pyproject.toml"
out="$( cd "$PYPROJ" && sf_stack_detect )"
[[ "$out" == "python" ]] && pass "R11 sf_stack_detect python" || fail "R11 sf_stack_detect python" "got '$out'"

# R12 — stack detection: node + python multi
echo '{}' > "$PYPROJ/package.json"
out="$( cd "$PYPROJ" && sf_stack_detect | tr '\n' ' ' )"
[[ "$out" == "python node " ]] && pass "R12 multi-stack: python+node" || fail "R12 multi-stack" "got '$out'"

# R13 — sf_stack_detect_json
out="$( cd "$PYPROJ" && sf_stack_detect_json )"
echo "$out" | jq -e '. == ["python","node"]' >/dev/null 2>&1 && pass "R13 stack_detect_json valid" || fail "R13 stack_detect_json" "got '$out'"

# R14 — LLM detection (positive: anthropic in pyproject)
LLMPROJ="$(make_repo llmproj)"
printf '%s\n' "[project]" "dependencies=['anthropic']" > "$LLMPROJ/pyproject.toml"
out="$( cd "$LLMPROJ" && sf_llm_detect )"
[[ "$out" == "true" ]] && pass "R14 sf_llm_detect anthropic → true" || fail "R14 sf_llm_detect anthropic" "got '$out'"

# R15 — LLM detection (negative: plain repo)
out="$( cd "$REPO2" && sf_llm_detect )"
[[ "$out" == "false" ]] && pass "R15 sf_llm_detect plain repo → false" || fail "R15 sf_llm_detect plain repo" "got '$out'"

# R16 — sf_test_command pytest
TESTPROJ="$(make_repo testproj)"
mkdir -p "$TESTPROJ/tests" && touch "$TESTPROJ/tests/conftest.py"
out="$( cd "$TESTPROJ" && sf_test_command )"
[[ "$out" == "pytest" ]] && pass "R16 sf_test_command pytest" || fail "R16 sf_test_command pytest" "got '$out'"

# R17 — sf_test_command empty for unknown stack
out="$( cd "$REPO2" && sf_test_command )"
[[ -z "$out" ]] && pass "R17 sf_test_command empty for unknown" || fail "R17 sf_test_command empty for unknown" "got '$out'"

echo ""
echo "── state helpers (lib/state.sh) ──"

# Switch back to a fresh branch for clean state tests
( cd "$REPO1" && git checkout -q -b feat-auth-state 2>/dev/null )

# S1 — sf_default_state is valid JSON with required fields
out="$( cd "$REPO1" && sf_default_state )"
echo "$out" | jq -e '.schema_version == 1 and (.slices|type == "object") and (.adr_counter == 0)' >/dev/null && \
  pass "S1 default state has required fields" || fail "S1 default state" "got: $out"

# S2 — sf_read_state returns default if missing
( cd "$REPO1" && [[ "$(sf_read_state | jq -r .schema_version)" == "1" ]] ) && pass "S2 read missing → default" || fail "S2 read missing → default"

# S3 — sf_init_state creates state file
( cd "$REPO1" && sf_init_state )
( cd "$REPO1" && [[ -r "$(sf_state_path)" ]] ) && pass "S3 sf_init_state creates state file" || fail "S3 sf_init_state creates state file"

# S4 — sf_init_state idempotent (returns 1 if state already exists)
( cd "$REPO1" && sf_init_state; [[ $? -eq 1 ]] ) && pass "S4 sf_init_state idempotent" || fail "S4 sf_init_state idempotent"

# S5 — sf_state_apply changes field
( cd "$REPO1" && sf_state_apply '.current_slice = "slice-04-test"' )
out="$( cd "$REPO1" && sf_state_get current_slice )"
[[ "$out" == "slice-04-test" ]] && pass "S5 sf_state_apply sets field" || fail "S5 sf_state_apply" "got '$out'"

# S6 — sf_state_apply bumps updated_at
sleep 1
ts1="$( cd "$REPO1" && sf_state_get updated_at )"
( cd "$REPO1" && sf_state_apply '.adr_counter = 5' )
ts2="$( cd "$REPO1" && sf_state_get updated_at )"
[[ "$ts1" != "$ts2" ]] && pass "S6 sf_state_apply bumps updated_at" || fail "S6 sf_state_apply bumps updated_at" "ts1=$ts1 ts2=$ts2"

# S7 — sf_state_apply_typed for bool
( cd "$REPO1" && sf_state_apply_typed '.llm_project = $val' true )
out="$( cd "$REPO1" && sf_state_get llm_project )"
[[ "$out" == "true" ]] && pass "S7 sf_state_apply_typed bool" || fail "S7 sf_state_apply_typed bool" "got '$out'"

# S8 — sf_state_apply_typed for array
( cd "$REPO1" && sf_state_apply_typed '.stack = $val' '["python","rust"]' )
out="$( cd "$REPO1" && sf_state_get_path '.stack | join(",")' )"
[[ "$out" == "python,rust" ]] && pass "S8 sf_state_apply_typed array" || fail "S8 sf_state_apply_typed array" "got '$out'"

# S9 — malformed state → default
echo "garbage{not json" > "$( cd "$REPO1" && sf_state_path )"
out="$( cd "$REPO1" && sf_read_state | jq -r .schema_version )"
[[ "$out" == "1" ]] && pass "S9 malformed state → default" || fail "S9 malformed state → default" "got '$out'"

# S10 — sf_write_state_stdin refuses malformed
echo "garbage{not json" | ( cd "$REPO1" && sf_write_state_stdin; [[ $? -eq 1 ]] ) \
  && pass "S10 sf_write_state_stdin refuses malformed" || fail "S10 sf_write_state_stdin refuses malformed"

# S11 — sf_is_managed yes when state exists
( cd "$REPO1" && sf_init_state >/dev/null 2>&1; sf_is_managed ) && pass "S11 sf_is_managed yes when state exists" || fail "S11 sf_is_managed yes when state exists"

# S12 — sf_is_managed no when state missing (different repo, no init)
NEW_REPO="$(make_repo r3-no-init)"
( cd "$NEW_REPO" && ! sf_is_managed ) && pass "S12 sf_is_managed no when state missing" || fail "S12 sf_is_managed no when state missing"

# S13 — multi-branch isolation
( cd "$REPO1" && git checkout -q -b another-branch && sf_init_state >/dev/null 2>&1 )
ANOTHER_PATH="$( cd "$REPO1" && sf_state_path )"
( cd "$REPO1" && git checkout -q feat-auth-state )
AUTH_PATH="$( cd "$REPO1" && sf_state_path )"
[[ "$ANOTHER_PATH" != "$AUTH_PATH" ]] && pass "S13 multi-branch state files are distinct" || fail "S13 multi-branch state isolation"

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
