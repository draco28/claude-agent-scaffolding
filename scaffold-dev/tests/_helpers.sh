#!/usr/bin/env bash
# Shared assertion helpers for scaffold-dev test suites.
# Source from each test-*.sh file; tests use assert_* and tmp helpers.
# Mirrors scaffold-onboard/tests/_helpers.sh with sd_* prefix.

set -u

PASS=0
FAIL=0
TMP_DIR=""

if [[ -t 1 && "${NO_COLOR:-}" == "" ]]; then
  _color_pass() { printf "\033[32m%s\033[0m" "$1"; }
  _color_fail() { printf "\033[31m%s\033[0m" "$1"; }
else
  _color_pass() { printf "%s" "$1"; }
  _color_fail() { printf "%s" "$1"; }
fi

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_ne() {
  local label="$1" a="$2" b="$3"
  if [[ "$a" != "$b" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') $label (both: $a)"
  fi
}

assert_file_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') file exists: $path"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') file missing: $path"
  fi
}

assert_file_missing() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') file absent: $path"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') file unexpectedly present: $path"
  fi
}

assert_file_contains() {
  local path="$1" pattern="$2"
  if [[ ! -e "$path" ]]; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') file missing for contains-check: $path"
    return
  fi
  if grep -qE -- "$pattern" "$path"; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') $path contains /$pattern/"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') $path does not contain /$pattern/"
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') $label"
    echo "    needle:   $needle"
    echo "    haystack: $haystack"
  fi
}

assert_exit_code() {
  local expected="$1"; shift
  local label="exit code $expected for: $*"
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  :
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass 'PASS') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail 'FAIL') $label (got $actual)"
  fi
}

# setup_tmp_repo creates an isolated tmp dir, exports CLAUDE_PLUGIN_DATA,
# inits a git repo, and cds into it.
setup_tmp_repo() {
  TMP_DIR="$(mktemp -d -t scaffold-dev-test.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  mkdir -p "$TMP_DIR/repo"
  cd "$TMP_DIR/repo"
  git init -q
  git config user.email "test@example.com"
  git config user.name  "Test"
}

# setup_tmp_workspace builds a dual-repo workspace mirroring workspace-init's
# pairing.json schema. Exports TMP_AI_WORKSPACE, TMP_CANONICAL, TMP_MANIFEST.
# Initializes canonical as a git repo with a first commit on main.
setup_tmp_workspace() {
  local project="${1:-foo}"
  local project_type="${2:-personal}"
  TMP_DIR="$(mktemp -d -t scaffold-dev-test.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  TMP_AI_WORKSPACE="$TMP_DIR/${project}-ai"
  TMP_CANONICAL="$TMP_DIR/${project}"
  mkdir -p "$TMP_AI_WORKSPACE/.workspace" "$TMP_CANONICAL"
  TMP_MANIFEST="$TMP_AI_WORKSPACE/.workspace/pairing.json"
  cat > "$TMP_MANIFEST" <<EOF
{
  "schema_version": "1.0",
  "topology": "dual-repo",
  "ai_workspace": { "root": "${TMP_AI_WORKSPACE}", "name": "${project}-ai", "git_tracked": true },
  "canonical":    { "root": "${TMP_CANONICAL}",    "name": "${project}", "git_tracked": true, "default_branch": "main" },
  "routing": {
    "master_spec":              "ai_workspace",
    "executive_summary":        "canonical",
    "memory_bank":              "ai_workspace",
    "claude_md":                "ai_workspace",
    "agents_md":                "ai_workspace",
    "scaffold_project_outputs": "ai_workspace",
    "backlog":                  "canonical",
    "project_plan":             "canonical",
    "roadmap":                  "canonical",
    "prd":                      "canonical",
    "srs":                      "canonical",
    "product_adrs":             "canonical",
    "process_adrs":             "ai_workspace",
    "sprint_specs":             "ai_workspace",
    "implementation_handoffs":  "ai_workspace",
    "brainstorm_artifacts":     "ai_workspace"
  },
  "during_dev": {
    "worktrees_dir":       "\${canonical.root}/.worktrees",
    "branch_naming":       "slice/sprint-{N}-work-{NN}-{kebab-name}",
    "sprint_dir_template": "\${ai_workspace.root}/docs/specs/sprint-{N}",
    "slice_spec_format":   "wabash-format-b-v1"
  },
  "well_known_paths": {
    "master_spec": "\${ai_workspace.root}/docs/MASTER-SPEC.md",
    "memory_bank": "\${ai_workspace.root}/.claude/memory-bank",
    "roadmap_state": "\${ai_workspace.root}/.workspace/project-roadmap.json"
  },
  "git_policy": {
    "project_type":           "${project_type}",
    "allow_ai_local_commits": true,
    "allow_ai_local_merge":   true,
    "allow_ai_local_rebase":  true,
    "allow_ai_fetch":         false,
    "allow_ai_push":          false,
    "allow_ai_pull":          false,
    "trace_filter": { "enforce": true, "blocked_patterns": ["^Co-Authored-By:"] }
  },
  "created_at": "2026-05-25T00:00:00Z",
  "created_by": "scaffold-dev-test"
}
EOF
  # Initialize canonical as a real git repo with main branch + initial commit.
  (
    cd "$TMP_CANONICAL"
    git init -q -b main 2>/dev/null || { git init -q && git checkout -q -b main 2>/dev/null || true; }
    git config user.email "test@example.com"
    git config user.name  "Test"
    echo "# ${project}" > README.md
    git add README.md
    git commit -q -m "initial"
  )
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

sd_test_summary() {
  echo ""
  echo "Results: $(_color_pass "$PASS passed"), $(_color_fail "$FAIL failed")"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}
