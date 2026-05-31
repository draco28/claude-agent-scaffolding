#!/usr/bin/env bash
# tests/test-pr.sh — lib/pr.sh primitives (pr_hierarchical merge mode, #40).
# Uses a local bare repo as origin + a gh PATH-shim (no network).

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/_helpers.sh"
source "$HERE/../lib/_helpers.sh"
source "$HERE/../lib/manifest.sh"
source "$HERE/../lib/worktree.sh"
source "$HERE/../lib/merge.sh"
source "$HERE/../lib/pr.sh"

# Build a dual-repo workspace + bare origin + gh shim on PATH.
_setup_pr_workspace() {
  setup_tmp_workspace "$@"
  BARE_ORIGIN="$TMP_DIR/origin.git"
  git init -q --bare "$BARE_ORIGIN"
  git -C "$TMP_CANONICAL" remote add origin "$BARE_ORIGIN"
  chmod +x "$HERE/fixtures/gh-shim/gh" 2>/dev/null || true
  export PATH="$HERE/fixtures/gh-shim:$PATH"
  export GH_SHIM_LOG="$TMP_DIR/gh-calls.log"
  : > "$GH_SHIM_LOG"
  # Reset shim env to defaults each setup.
  unset GH_SHIM_AUTH_RC GH_SHIM_MERGE_RC GH_SHIM_PR_VIEW_JSON
  export GH_SHIM_PR_URL="https://github.com/test/repo/pull/123"
}

# 0. smoke — shim is reachable and records calls
test_shim_smoke() {
  echo "test_shim_smoke:"
  _setup_pr_workspace
  local out; out="$(gh pr create --head x --base y --title t --body-file /dev/null)"
  assert_contains "shim echoes canned PR url" "pull/123" "$out"
  assert_file_contains "$GH_SHIM_LOG" "pr create"
}

test_shim_smoke

sd_test_summary
