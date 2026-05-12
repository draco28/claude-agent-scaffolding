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
