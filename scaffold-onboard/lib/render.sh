#!/usr/bin/env bash
# scaffold-onboard/lib/render.sh
# Template substitution. Grammar: {{key}} for single values. Missing values
# render as TODO: <key>. Block forms ({{#if}}, {{#each}}) added in TB.10.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# sf_render <template_path> key=value key=value ...
# Echoes the rendered template. Missing keys render as "TODO: <key>".
sf_render() {
  local tmpl="$1"; shift
  local content
  content="$(cat "$tmpl")"
  # Store key=value pairs in indexed arrays for bash 3 compatibility.
  # (bash 4 associative arrays unavailable on macOS system bash 3.2.)
  local -a var_keys=()
  local -a var_vals=()
  local kv key val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    var_keys+=("$key")
    var_vals+=("$val")
  done

  # _lookup_var <key> — sets _LOOKUP_RESULT to value, or empty string on miss.
  # Returns 0 if found, 1 if not found.
  _lookup_var() {
    local target="$1"
    local i
    for i in "${!var_keys[@]}"; do
      if [[ "${var_keys[$i]}" == "$target" ]]; then
        _LOOKUP_RESULT="${var_vals[$i]}"
        return 0
      fi
    done
    _LOOKUP_RESULT=""
    return 1
  }

  # Step 1: Process {{#if key}}...{{/if}} blocks.
  # Pass the variable map to awk via environment variables:
  #   AWK_KEYS — newline-separated list of keys
  #   AWK_VALS — newline-separated list of values (parallel to AWK_KEYS)
  # BSD awk (macOS) is used; no 3-arg match(), no gensub().
  local awk_keys_str awk_vals_str
  awk_keys_str="$(printf '%s\n' "${var_keys[@]+"${var_keys[@]}"}")"
  awk_vals_str="$(printf '%s\n' "${var_vals[@]+"${var_vals[@]}"}")"

  local processed
  processed="$(
    AWK_KEYS="$awk_keys_str" AWK_VALS="$awk_vals_str" \
    awk '
    BEGIN {
      # Load the key→value map from environment variables.
      n = split(ENVIRON["AWK_KEYS"], keys, "\n")
          split(ENVIRON["AWK_VALS"], vals, "\n")
      for (i = 1; i <= n; i++) {
        if (keys[i] != "") {
          varmap[keys[i]] = vals[i]
        }
      }
      in_if    = 0
      truthy   = 0
    }

    # Detect {{#if key}} — opening tag.
    /\{\{#if [a-zA-Z0-9_.]+\}\}/ {
      # Extract the key between "{{#if " and "}}".
      line = $0
      sub(/.*\{\{#if /, "", line)
      sub(/\}\}.*/, "", line)
      ifkey = line
      in_if  = 1
      truthy = (ifkey in varmap && varmap[ifkey] == "true") ? 1 : 0
      next  # skip the {{#if}} line itself
    }

    # Detect {{/if}} — closing tag.
    /\{\{\/if\}\}/ {
      in_if  = 0
      truthy = 0
      next  # skip the {{/if}} line itself
    }

    # All other lines: print only when not in a falsy if-block.
    {
      if (!in_if || truthy) print
    }
    ' <<< "$content"
  )"

  # Step 2: Substitute {{key}} placeholders using existing bash loop.
  local result="$processed"
  local _LOOKUP_RESULT=""
  while [[ "$result" =~ \{\{([a-zA-Z0-9_.]+)\}\} ]]; do
    local placeholder="${BASH_REMATCH[0]}"
    local k="${BASH_REMATCH[1]}"
    local v
    if _lookup_var "$k"; then
      v="$_LOOKUP_RESULT"
    else
      v="TODO: $k"
    fi
    # Use bash parameter expansion to replace all occurrences in one pass.
    result="${result//$placeholder/$v}"
  done
  printf '%s\n' "$result"
}

# Initialize MASTER-SPEC.md from the template with project_name and project_class.
# All other placeholders render as TODO: <key> at init; they get filled in
# as phases complete (via sf_master_spec_update_phase).
sf_master_spec_init() {
  local tmpl="$1" project_name="$2" project_class="$3"
  local today
  today="$(date -u +%Y-%m-%d)"
  sf_render "$tmpl" \
    "project_name=$project_name" \
    "project_class=$project_class" \
    "created_date=$today" \
    "updated_date=$today" \
    > MASTER-SPEC.md
}

# Re-render MASTER-SPEC.md from the template, populating Phase N's placeholders
# with values from state.answers. Other phases' placeholders are left as-is
# (preserved from prior runs or showing TODO: <key> if not yet answered).
#
# Strategy: re-render the FULL template each time, with all currently-known
# answers fed in. This is deterministic and idempotent.
sf_master_spec_update_phase() {
  local tmpl="$1" phase_id="$2"
  # Collect every answered question's id+value into key=value pairs
  local args=()
  # Derive project_name: prefer pitch prefix from answer 1.1.1 (text before " — "),
  # fallback to basename of cwd. Same logic as sf_claude_md_generate, kept
  # consistent so MASTER-SPEC and CLAUDE.md agree on project name.
  local raw_pitch _project_name
  raw_pitch="$(sf_state_read_answer 1.1.1)"
  if [[ "$raw_pitch" != "null" && "$raw_pitch" == *" — "* ]]; then
    _project_name="${raw_pitch%% — *}"
  else
    _project_name="$(basename "$PWD")"
  fi
  args+=("project_name=$_project_name")
  local pc
  pc="$(sf_state_read_answer 1.3.1)"
  [[ "$pc" != "null" ]] && args+=("project_class=$pc")
  args+=("created_date=$(date -u +%Y-%m-%d)")
  args+=("updated_date=$(date -u +%Y-%m-%d)")

  # All phase answers
  local path
  path="$(sf_state_path)"
  local qid val
  while IFS=$'\t' read -r qid val; do
    [[ -z "$qid" ]] && continue
    # phases.yaml uses "1.1.1" → template placeholder {{phase_1.1.1}}
    args+=("phase_${qid}=${val}")
  done < <(jq -r '.answers | to_entries[] | "\(.key)\t\(.value)"' "$path")

  # Branching gate flags for {{#if}} blocks
  if sf_state_gate_passes 'project_class in {Web app, Mobile app, CLI tool, ML or AI system, Agent or plugin, Other}'; then
    args+=("ui_branch=true")
  else
    args+=("ui_branch=false")
  fi
  if sf_state_gate_passes 'project_class in {Library or SDK, Data pipeline, Web service (API only)}'; then
    args+=("dx_branch=true")
  else
    args+=("dx_branch=false")
  fi
  if sf_state_gate_passes 'project_class in {Web app, Web service (API only), ML or AI system, Agent or plugin, Data pipeline}'; then
    args+=("backend_branch=true")
  else
    args+=("backend_branch=false")
  fi
  if sf_state_gate_passes 'project_class in {Web app, Mobile app}'; then
    args+=("frontend_branch=true")
  else
    args+=("frontend_branch=false")
  fi
  if sf_state_gate_passes 'project_class == "Library or SDK"'; then
    args+=("library_branch=true")
  else
    args+=("library_branch=false")
  fi
  local llm
  llm="$(sf_state_read_answer 9.3.1)"
  if [[ "$llm" == "yes" || "$llm" == "true" ]]; then
    args+=("uses_llm=true")
  else
    args+=("uses_llm=false")
  fi

  sf_render "$tmpl" "${args[@]}" > MASTER-SPEC.md
}
