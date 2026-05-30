#!/usr/bin/env bash
# Shared assertion helpers for scaffold-onboard test suites.
# Source from each test-*.sh file; tests use assert_* and tmp-repo helpers.

set -u

PASS=0
FAIL=0
TMP_DIR=""

# Color helpers — emit ANSI only on TTYs or when NO_COLOR is unset.
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
    echo "  $(_color_pass '✓') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $label"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_file_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') file exists: $path"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file missing: $path"
  fi
}

assert_file_missing() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') file absent: $path"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file unexpectedly present: $path"
  fi
}

assert_file_contains() {
  local path="$1" pattern="$2"
  if [[ ! -e "$path" ]]; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file missing for contains-check: $path"
    return
  fi
  if grep -qE "$pattern" "$path"; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') $path contains /$pattern/"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $path does not contain /$pattern/"
  fi
}

assert_file_not_contains() {
  local path="$1" pattern="$2"
  if [[ ! -e "$path" ]]; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') file missing for not-contains-check: $path"
    return
  fi
  if grep -qE "$pattern" "$path"; then
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $path unexpectedly contains /$pattern/"
  else
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') $path does not contain /$pattern/"
  fi
}

assert_exit_code() {
  local expected="$1"; shift
  local label="exit code $expected for: $*"
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e 2>/dev/null || true
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS+1))
    echo "  $(_color_pass '✓') $label"
  else
    FAIL=$((FAIL+1))
    echo "  $(_color_fail '✗') $label (got $actual)"
  fi
}

# setup_tmp_repo creates an isolated tmp dir, exports CLAUDE_PLUGIN_DATA,
# inits a git repo, and cds into it. NOTE: does not restore the prior pwd —
# test scripts are expected to invoke it once and exit (cleanup trap handles
# tmp removal). If a later test needs to call this multiple times in one
# script, save the original directory first: ORIG_DIR=$(pwd).
setup_tmp_repo() {
  TMP_DIR="$(mktemp -d -t scaffold-onboard-test.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  mkdir -p "$TMP_DIR/repo"
  cd "$TMP_DIR/repo"
  git init -q
  git config user.email "test@example.com"
  git config user.name  "Test"
}

# setup_tmp_workspace_init creates a dual-repo workspace under TMP_DIR:
#   <TMP_DIR>/<project>-ai/.workspace/pairing.json
#   <TMP_DIR>/<project>/
# Exports globals: TMP_AI_WORKSPACE, TMP_CANONICAL, TMP_MANIFEST.
# Project name defaults to "foo"; project_type to "personal".
# Args: $1 — project name (default: foo)
#       $2 — project type (default: personal)
#       $3 — include_roadmap_routing (default: yes; "no" omits routing.roadmap)
# Supports tests T3.1, T7.1, and others.
setup_tmp_workspace_init() {
  local project="${1:-foo}"
  local project_type="${2:-personal}"
  local include_roadmap="${3:-yes}"
  TMP_DIR="$(mktemp -d -t scaffold-onboard-test.XXXXXX)"
  export CLAUDE_PLUGIN_DATA="$TMP_DIR/plugin-data"
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  TMP_AI_WORKSPACE="$TMP_DIR/${project}-ai"
  TMP_CANONICAL="$TMP_DIR/${project}"
  mkdir -p "$TMP_AI_WORKSPACE/.workspace" "$TMP_CANONICAL"
  TMP_MANIFEST="$TMP_AI_WORKSPACE/.workspace/pairing.json"
  if [[ "$include_roadmap" == "yes" ]]; then
    cat > "$TMP_MANIFEST" <<EOF
{
  "schema_version": "1.0",
  "topology": "dual-repo",
  "ai_workspace": { "root": "${TMP_AI_WORKSPACE}", "name": "${project}-ai" },
  "canonical":    { "root": "${TMP_CANONICAL}",    "name": "${project}", "default_branch": "main" },
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
  "git_policy": { "project_type": "${project_type}" }
}
EOF
  else
    cat > "$TMP_MANIFEST" <<EOF
{
  "schema_version": "1.0",
  "topology": "dual-repo",
  "ai_workspace": { "root": "${TMP_AI_WORKSPACE}", "name": "${project}-ai" },
  "canonical":    { "root": "${TMP_CANONICAL}",    "name": "${project}", "default_branch": "main" },
  "routing": {
    "master_spec": "ai_workspace",
    "prd":         "canonical"
  },
  "git_policy": { "project_type": "${project_type}" }
}
EOF
  fi
}

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

trap cleanup EXIT

report_results() {
  echo ""
  echo "Results: $(_color_pass "$PASS passed"), $(_color_fail "$FAIL failed")"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
  exit 0
}
