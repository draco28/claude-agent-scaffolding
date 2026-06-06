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

# seed_master_spec_fixture <out_path> [project_name] [project_class] [pitch]
# Writes a structurally valid MASTER-SPEC.md fixture to <out_path>.
# The file satisfies sf_spec_validate: top-level heading, ## Executive Summary,
# **Project class:** kv, and phase markers for phases 1–10.
# project_name defaults to "test-proj"; project_class defaults to "CLI tool".
# When pitch is non-empty it is included verbatim in the Executive Summary body,
# so an assert_file_contains check for that exact phrase is satisfied by the
# fixture itself (no post-write printf patch needed).
seed_master_spec_fixture() {
  local out_path="$1"
  local project_name="${2:-test-proj}"
  local project_class="${3:-CLI tool}"
  local pitch="${4:-}"
  mkdir -p "$(dirname "$out_path")"
  # Build the optional pitch line (empty string when pitch is omitted).
  local pitch_line=""
  if [[ -n "$pitch" ]]; then
    pitch_line="${pitch}"$'\n'
  fi
  cat > "$out_path" <<FIXTURE
# ${project_name} — Master Specification

**Project class:** ${project_class}
**Spec version:** 1.0

## Executive Summary

${pitch_line}${project_name} is a fast, local-first tool for ${project_class} workflows.
It solves the problem of slow, cloud-coupled alternatives by delivering
a single-binary solution that works offline. Primary users are solo devs
and ops engineers who need sub-200ms response times for everyday tasks.
The MVP scope centers on add/list/complete tasks persisted to a local file.

<!-- master-spec:phase id=1 name=Foundation -->

### 1.1 Elevator pitch & problem statement

**Pitch:** ${project_name} — a fast, local-first task manager
**Problem:** Existing managers are heavy and cloud-coupled.
**Success criteria:** Solo devs adopt as their default task tool.

### 1.2 Target users & outcomes

**Primary users:** Solo devs and ops engineers.
**Core use case:** Add a task, see what's pending, mark done — all under 200ms.

### 1.3 Project classification & MVP

**Project class:** ${project_class}
**MVP scope:** add/list/complete tasks; persist to ~/.todo.json; tab-complete.

<!-- master-spec:phase id=2 name=Constraints -->

### 2.1 Timeline & team

**Timeline:** 4 weeks
**Team:** Solo

### 2.2 Risk summary

**Risks:** tech: dep drift; market: niche; resource: solo bandwidth

<!-- master-spec:phase id=3 name=Domain model -->

### 3.1 Core domain entities

**Entities:** Task, Project (optional)
**Identity & description:** Task(id, title, status, due); Project(id, name)

### 3.2 Relationships

**Key relationships:** Project has many Tasks

<!-- master-spec:phase id=4 name=Integrations -->

### 4.1 External services

**APIs consumed:** none
**APIs produced:** none

<!-- master-spec:phase id=5 name=Tech stack -->

### 5.1 Platform

**Platform:** CLI

### 5.2 Language & storage

**Language / runtime:** Rust
**Storage:** file (~/.todo.json)

<!-- master-spec:phase id=6 name=UX -->

### 6.1 UX

**Interface type:** CLI
**Primary user journey:** todo add 'feed cat' → todo list → todo done 1

<!-- master-spec:phase id=7 name=Architecture -->

### 7.1 Code structure

**Top-level directories:** src/{cli,store,model}
**Key coding conventions:** statically typed Rust

<!-- master-spec:phase id=8 name=Toolchain -->

### 8.1 Build

**Package manager / build:** cargo

### 8.2 CI/CD

**CI:** GitHub Actions
**Environments:** dev only

<!-- master-spec:phase id=9 name=Quality -->

### 9.1 Testing

**Coverage target:** 80%
**Test types:** unit, integration

### 9.3 LLM evaluation

**Uses LLM:** no

<!-- master-spec:phase id=10 name=Operations -->

### 10.1 Support model

**Support model:** direct
FIXTURE
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
