#!/usr/bin/env bash
#
# scaffold/tests/test-worktree.sh — regression suite for lib/worktree.sh.
#
# Tests the worktree fork + list helpers against real `git worktree` machinery
# in a tempdir. State is isolated via CLAUDE_PLUGIN_DATA pointed at /tmp.
#
# Usage: bash scaffold/tests/test-worktree.sh

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$PLUGIN_ROOT/lib/worktree.sh"

TMPDIR_TESTS="$(mktemp -d -t scaffold-wt-tests-XXXXXX)"
export CLAUDE_PLUGIN_DATA="$TMPDIR_TESTS/data"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
mkdir -p "$CLAUDE_PLUGIN_DATA"

cleanup() { rm -rf "$TMPDIR_TESTS"; }
trap cleanup EXIT

PASS=0; FAIL=0; FAILED_TESTS=()
pass() { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); printf '  \033[31m✗\033[0m %s\n' "$1"; [[ -n "$2" ]] && printf '      %s\n' "$2"; }

# shellcheck source=../lib/worktree.sh
source "$LIB"

# Setup: create a real git repo with a commit
REPO="$TMPDIR_TESTS/parent"
mkdir -p "$REPO"
( cd "$REPO" && git init -q -b main \
    && git config user.email t@t && git config user.name t \
    && touch .keep && git add .keep && git commit -q -m init )
cd "$REPO"
sf_init_state >/dev/null

# Pre-populate parent state with some accounting fields
sf_state_apply '.adr_counter = 7'
sf_state_apply_typed '.stack = $val' '["python","node"]'
sf_state_apply '.current_slice = "slice-03-fake"'
sf_state_apply_typed '.slices["slice-03-fake"] = $val' '{"name":"fake","number":3,"phase":"complete"}'

echo ""
echo "── fork: success path ──"

# F1 — fork a new branch with default path
out="$(sf_worktree_fork "feat-auth" 2>&1)"
RC=$?
[[ $RC -eq 0 ]] && pass "F1 fork returns 0 on success" || fail "F1 fork rc" "got $RC, output: $out"

# F2 — worktree dir exists at default path
DEFAULT_PATH="$TMPDIR_TESTS/parent-feat-auth"
[[ -d "$DEFAULT_PATH" ]] && pass "F2 worktree dir at default path" || fail "F2 default path"

# F3 — git knows about the worktree
git -C "$REPO" worktree list | grep -q "$DEFAULT_PATH" \
  && pass "F3 git worktree list includes new worktree" \
  || fail "F3 git aware of worktree"

# F4 — branch exists
git -C "$REPO" show-ref --verify --quiet refs/heads/feat-auth \
  && pass "F4 new branch ref created" \
  || fail "F4 branch ref"

# F5 — new state.json exists
NEW_STATE="$CLAUDE_PLUGIN_DATA/projects/$(sf_repo_hash)/branches/feat-auth/state.json"
[[ -r "$NEW_STATE" ]] && pass "F5 new branch state.json created" || fail "F5 state file"

# F6 — current_slice was reset (forking starts fresh slice context)
[[ "$(jq -r .current_slice "$NEW_STATE")" == "null" ]] && pass "F6 current_slice reset to null" \
  || fail "F6 current_slice" "got: $(jq -r .current_slice "$NEW_STATE")"

# F7 — slices map cleared
[[ "$(jq -r '.slices | length' "$NEW_STATE")" == "0" ]] && pass "F7 slices map empty after fork" \
  || fail "F7 slices map" "got: $(jq -r '.slices' "$NEW_STATE")"

# F8 — adr_counter inherited (per-repo, not per-branch)
[[ "$(jq -r .adr_counter "$NEW_STATE")" == "7" ]] && pass "F8 adr_counter inherited from parent (7)" \
  || fail "F8 adr_counter" "got: $(jq -r .adr_counter "$NEW_STATE")"

# F9 — stack inherited
[[ "$(jq -r '.stack | join(",")' "$NEW_STATE")" == "python,node" ]] && pass "F9 stack inherited" \
  || fail "F9 stack" "got: $(jq -r '.stack' "$NEW_STATE")"

# F10 — CLAUDE.md materialized in new worktree
[[ -r "$DEFAULT_PATH/CLAUDE.md" ]] && pass "F10 CLAUDE.md materialized in new worktree" \
  || fail "F10 CLAUDE.md"

echo ""
echo "── fork: refusal cases ──"

# F11 — refuse when branch already exists
out="$(sf_worktree_fork "feat-auth" 2>&1)"
[[ $? -ne 0 ]] && echo "$out" | grep -qi "already exists" \
  && pass "F11 refuses duplicate branch name" \
  || fail "F11 duplicate branch refuse" "got: $out"

# F12 — refuse when target path is occupied
mkdir -p "$TMPDIR_TESTS/parent-feat-blocked"
out="$(sf_worktree_fork "feat-blocked" 2>&1)"
[[ $? -ne 0 ]] && echo "$out" | grep -qi "already exists" \
  && pass "F12 refuses occupied target path" \
  || fail "F12 occupied path refuse"

# F13 — refuse when no branch name given
out="$(sf_worktree_fork "" 2>&1)"
[[ $? -ne 0 ]] && pass "F13 refuses empty branch name" || fail "F13 empty refuse"

echo ""
echo "── fork: --path support ──"

# F14 — fork with custom path
CUSTOM_PATH="$TMPDIR_TESTS/custom-spike-dir"
out="$(sf_worktree_fork "feat-custom" "$CUSTOM_PATH" 2>&1)"
[[ $? -eq 0 && -d "$CUSTOM_PATH" ]] && pass "F14 --path argument creates worktree at chosen location" \
  || fail "F14 --path" "rc=$? exists=$([[ -d "$CUSTOM_PATH" ]] && echo y || echo n)"

# F15 — branch with slash in name slugged correctly in dir name (default path)
out="$(sf_worktree_fork "feat/payments" 2>&1)"
[[ $? -eq 0 && -d "$TMPDIR_TESTS/parent-feat-payments" ]] \
  && pass "F15 slash-named branch slugged in default path" \
  || fail "F15 slash slug" "rc=$?"

# F16 — slash branch state stored under sanitized dir name (__)
SLASH_STATE="$CLAUDE_PLUGIN_DATA/projects/$(sf_repo_hash)/branches/feat__payments/state.json"
[[ -r "$SLASH_STATE" ]] && pass "F16 slash branch state under feat__payments/" \
  || fail "F16 slash state path"

echo ""
echo "── list ──"

# L1 — list shows main + 3 forked worktrees as table
out="$(sf_worktree_list)"
echo "$out" | grep -q "^| Path | Branch" && pass "L1 list emits markdown table header" \
  || fail "L1 table header"

# L2 — main worktree listed
echo "$out" | grep -q "main" && pass "L2 main worktree present" || fail "L2 main"

# L3 — feat-auth worktree listed
echo "$out" | grep -q "feat-auth" && pass "L3 feat-auth worktree present" || fail "L3 feat-auth"

# L4 — list correctly shows adr_counter inheritance (current slice = none on forked branches)
forked_row="$(echo "$out" | grep "feat-auth")"
echo "$forked_row" | grep -q "(none)" && pass "L4 forked branch shows (none) for current_slice" \
  || fail "L4 forked current_slice display"

# L5 — list with custom-path worktree present
echo "$out" | grep -q "custom-spike-dir" && pass "L5 custom-path worktree shown" || fail "L5 custom-path list"

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
