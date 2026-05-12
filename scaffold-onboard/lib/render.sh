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

  # Replace each {{key}}. Iterate via regex match until no placeholders remain.
  local result="$content"
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
