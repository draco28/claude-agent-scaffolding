#!/usr/bin/env bash
# scaffold/lib/state.sh — branch-scoped project state I/O.
#
# State lives at:
#   ${CLAUDE_PLUGIN_DATA}/projects/<repo-hash>/branches/<branch-safe>/state.json
#
# All readers fail-safe: missing file or malformed JSON → return default state.
# All writers are atomic: write to tempfile, validate, mv into place.
#
# Sources lib/repo.sh for repo-hash and branch detection.

SF_STATE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./repo.sh
source "${SF_STATE_LIB_DIR}/repo.sh"

# ── Path resolution ─────────────────────────────────────────────────────────

# sf_data_dir — root of plugin data on disk.
# Honors CLAUDE_PLUGIN_DATA when set (Claude Code hook/MCP runtime), falls back
# to a sensible legacy path for shell-level tests.
sf_data_dir() {
  printf '%s' "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/scaffold}"
}

# sf_project_dir — per-repo plugin-data dir (where memory.db etc. live).
sf_project_dir() {
  printf '%s/projects/%s' "$(sf_data_dir)" "$(sf_repo_hash)"
}

# sf_state_dir — per-(repo, branch) dir holding state.json.
sf_state_dir() {
  printf '%s/branches/%s' "$(sf_project_dir)" "$(sf_branch_safe)"
}

# sf_state_path — full path to state.json.
sf_state_path() {
  printf '%s/state.json' "$(sf_state_dir)"
}

# ── Schema ──────────────────────────────────────────────────────────────────

# sf_default_state — default state JSON. Top-level fields:
#   schema_version, current_slice, slices (map),
#   stack (array), llm_project (bool),
#   last_audit_at, audit_results_path,
#   adr_counter (int), claude_md_managed (bool),
#   created_at, updated_at.
sf_default_state() {
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat <<EOF
{
  "schema_version": 1,
  "current_slice": null,
  "slices": {},
  "stack": [],
  "llm_project": false,
  "last_audit_at": null,
  "audit_results_path": null,
  "adr_counter": 0,
  "claude_md_managed": true,
  "created_at": "${now}",
  "updated_at": "${now}"
}
EOF
}

# ── Read ────────────────────────────────────────────────────────────────────

# sf_read_state — echo state JSON. Default if missing/malformed.
sf_read_state() {
  local path
  path="$(sf_state_path)"
  if [[ ! -r "$path" ]]; then
    sf_default_state; return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    sf_default_state; return 0
  fi
  if ! jq -e . "$path" >/dev/null 2>&1; then
    sf_default_state; return 0
  fi
  cat "$path"
}

# sf_state_get — echo a top-level field's raw value (jq -r).
# Usage: sf_state_get current_slice
#        sf_state_get adr_counter
sf_state_get() {
  local field="$1"
  sf_read_state | jq -r ".${field} // empty" 2>/dev/null || echo ""
}

# sf_state_get_path — echo a value at any jq path.
# Usage: sf_state_get_path '.slices["slice-04-auth"].phase'
sf_state_get_path() {
  local path="$1"
  sf_read_state | jq -r "${path} // empty" 2>/dev/null || echo ""
}

# sf_is_managed — exit 0 if this (repo, branch) has scaffold state, 1 otherwise.
sf_is_managed() {
  [[ -r "$(sf_state_path)" ]]
}

# ── Write ───────────────────────────────────────────────────────────────────

# sf_write_state_stdin — atomic write of state JSON from stdin.
# Refuses to write malformed JSON. Returns 0 on success, 1 on failure.
sf_write_state_stdin() {
  local dir path tmp
  dir="$(sf_state_dir)"
  path="$(sf_state_path)"
  if ! mkdir -p "$dir" 2>/dev/null; then
    return 1
  fi
  tmp="$(mktemp "${path}.XXXXXX" 2>/dev/null)" || return 1
  cat > "$tmp"
  if ! command -v jq >/dev/null 2>&1; then
    rm -f "$tmp"; return 1
  fi
  if ! jq -e . "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"; return 1
  fi
  mv "$tmp" "$path"
}

# sf_state_apply — apply a jq update expression to state. Auto-bumps updated_at.
# Usage: sf_state_apply '.current_slice = "slice-04-auth"'
#        sf_state_apply '.slices["slice-04"].phase = "implement"'
#        sf_state_apply '.adr_counter += 1'
sf_state_apply() {
  local expr="$1"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sf_read_state \
    | jq --arg now "$now" "(${expr}) | .updated_at = \$now" \
    | sf_write_state_stdin
}

# sf_state_apply_typed — apply update with a JSON-typed value injected as $val.
# Use when the value is non-string (number, bool, array, object).
# Usage: sf_state_apply_typed '.llm_project = $val' true
#        sf_state_apply_typed '.stack = $val' '["python","node"]'
sf_state_apply_typed() {
  local expr="$1" raw_val="$2"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sf_read_state \
    | jq --arg now "$now" --argjson val "$raw_val" "(${expr}) | .updated_at = \$now" \
    | sf_write_state_stdin
}

# ── Init ────────────────────────────────────────────────────────────────────

# sf_init_state — create state.json for the current (repo, branch) if missing.
# Detects stack and LLM signals at init time; never overwrites an existing
# state file (idempotent).
# Returns 0 if state was created, 1 if it already existed (no-op).
sf_init_state() {
  if sf_is_managed; then
    return 1
  fi
  local stack_json llm now
  stack_json="$(sf_stack_detect_json)"
  llm="$(sf_llm_detect)"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sf_default_state \
    | jq --argjson stack "$stack_json" --argjson llm "$llm" --arg now "$now" \
        '.stack = $stack | .llm_project = $llm | .created_at = $now | .updated_at = $now' \
    | sf_write_state_stdin
}
