#!/usr/bin/env bash
# lib/routing.sh — manifest-aware output path resolution
#
# Per SPEC §10 (scaffold-onboard v0.2):
#   - sf_discover_manifest:     walks up from cwd looking for .workspace/pairing.json
#   - sf_resolve_output_path:   logical name + relative path → absolute path
#     - Manifest present: look up routing.<name>, expand via mi_manifest_resolve
#     - Manifest absent:  $(pwd)/<rel_path> (single-repo fallback)
#     - Unknown logical name: warn + cwd fallback
#     - 'roadmap' missing from routing: defaults to canonical (§10.4 forward-compat)
#
# Cross-plugin sourcing of workspace-init's mi_manifest_resolve via a
# probe-and-source pattern; falls back to a local minimal resolver
# (sufficient for ${ai_workspace.root}, ${canonical.root}, ${HOME}, ${USER}).
#
# Bash 3.2-compatible (macOS-portable): no `declare -A`, no `trap RETURN`.

# Source logging helpers from _helpers.sh. Path resolution: prefer
# CLAUDE_PLUGIN_ROOT, else walk from this file.
_sf_routing_source_helpers() {
  local helpers
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" && -f "${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh" ]]; then
    helpers="${CLAUDE_PLUGIN_ROOT}/lib/_helpers.sh"
  else
    helpers="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_helpers.sh"
  fi
  # shellcheck disable=SC1090
  [[ -f "$helpers" ]] && source "$helpers"
}
_sf_routing_source_helpers

# Tracks whether we've already attempted to source/define mi_manifest_resolve
# in this shell session. Tests reset this to "" to force re-probe.
_SF_ROUTING_RESOLVER_SOURCED="${_SF_ROUTING_RESOLVER_SOURCED:-}"

# ----------------------------------------------------------------------------
# sf_discover_manifest
# ----------------------------------------------------------------------------
# Walks up from cwd looking for .workspace/pairing.json.
# Echoes the absolute manifest path on success, returns 1 (no output) on failure.
sf_discover_manifest() {
  local dir
  dir="$(pwd)"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/.workspace/pairing.json" ]]; then
      echo "$dir/.workspace/pairing.json"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# ----------------------------------------------------------------------------
# sf_manifest_get <jq-path>  (SS-5.1)
# ----------------------------------------------------------------------------
# Read a scalar field from the discovered manifest. Echoes the value + rc=0;
# rc=1 (no output) when there is no manifest OR the field is absent/null.
# set -e-safe: callers capture rc=1 with `if v="$(sf_manifest_get …)"; then …`.
sf_manifest_get() {
  local expr="$1" manifest out
  if ! manifest="$(sf_discover_manifest)"; then
    return 1
  fi
  out="$(jq -r "${expr} // empty" "$manifest" 2>/dev/null)"
  if [[ -z "$out" || "$out" == "null" ]]; then
    return 1
  fi
  echo "$out"
}

# ----------------------------------------------------------------------------
# Cross-plugin mi_manifest_resolve sourcing
# ----------------------------------------------------------------------------
# Probe known locations for workspace-init's lib/manifest.sh. If found,
# source it (provides mi_manifest_resolve). If not, define a local fallback.
#
# Probe order (each entry is a single path or a glob):
#   1. SF_ROUTING_MI_RESOLVER_PATHS (colon-separated paths; test/dev override)
#   2. ${CLAUDE_PLUGIN_ROOT}/../workspace-init/lib/manifest.sh
#   3. ${HOME}/.claude/plugins/cache/*/workspace-init/*/lib/manifest.sh
#   4. ${CODEX_HOME:-$HOME/.codex}/plugins/cache/*/workspace-init/*/lib/manifest.sh
_sf_routing_source_mi_resolver() {
  # If already sourced/defined in this session, no-op.
  if [[ "$_SF_ROUTING_RESOLVER_SOURCED" == "1" ]]; then
    return 0
  fi

  local candidates=()
  local p

  # Override path list (test/dev hook).
  if [[ -n "${SF_ROUTING_MI_RESOLVER_PATHS:-}" ]]; then
    # macOS bash 3.2 has no readarray; use IFS-split.
    local OLDIFS="$IFS"
    IFS=':'
    for p in $SF_ROUTING_MI_RESOLVER_PATHS; do
      candidates+=("$p")
    done
    IFS="$OLDIFS"
  fi

  # Sibling-of-plugin location (when both plugins are installed in same dir).
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    candidates+=("${CLAUDE_PLUGIN_ROOT}/../workspace-init/lib/manifest.sh")
  fi

  # Claude Code plugin cache (versioned, marketplace-keyed).
  # Glob may expand to literal pattern if no match; guard with -f.
  local glob_pattern="${HOME}/.claude/plugins/cache/*/workspace-init/*/lib/manifest.sh"
  for p in $glob_pattern; do
    candidates+=("$p")
  done
  glob_pattern="${CODEX_HOME:-$HOME/.codex}/plugins/cache/*/workspace-init/*/lib/manifest.sh"
  for p in $glob_pattern; do
    candidates+=("$p")
  done

  for p in "${candidates[@]}"; do
    if [[ -f "$p" ]]; then
      # shellcheck disable=SC1090
      source "$p"
      _SF_ROUTING_RESOLVER_SOURCED=1
      return 0
    fi
  done

  # Fallback: define local minimal mi_manifest_resolve.
  _sf_routing_define_local_mi_resolver
  _SF_ROUTING_RESOLVER_SOURCED=1
  return 0
}

# Local fallback resolver. Handles the same call shape as workspace-init:
#   mi_manifest_resolve <ai-root> <string-with-vars>
#
# Handles:
#   - ${ai_workspace.root}, ${canonical.root}, ${ai_workspace.name},
#     ${canonical.name}, ${canonical.default_branch} (manifest field refs)
#   - ${HOME}, ${USER} (env vars)
# Sufficient for scaffold-onboard's routing needs + tests; intentionally not
# feature-complete with workspace-init's resolver (which also supports
# ${PLUGIN_DATA:<name>} per workspace-init SPEC §6.3).
_sf_routing_define_local_mi_resolver() {
  mi_manifest_resolve() {
    local ai_root="$1"
    local input="$2"
    local manifest="$ai_root/.workspace/pairing.json"
    if [[ ! -f "$manifest" ]]; then
      sf_log_error "mi_manifest_resolve: manifest not found: $manifest"
      return 1
    fi
    local expanded="$input"
    expanded="${expanded//\$\{HOME\}/$HOME}"
    expanded="${expanded//\$\{USER\}/${USER:-$(id -un)}}"
    # Handle ${section.field} references. Use bash 3.2-portable while-loop regex.
    while [[ "$expanded" =~ \$\{([a-z_]+)\.([a-z_]+)\} ]]; do
      local nest_section="${BASH_REMATCH[1]}"
      local nest_field="${BASH_REMATCH[2]}"
      local nest_val
      nest_val="$(jq -r ".${nest_section}.${nest_field} // empty" "$manifest" 2>/dev/null)"
      # Avoid infinite loop on unresolved refs.
      if [[ -z "$nest_val" || "$nest_val" == "null" ]]; then
        sf_log_warn "mi_manifest_resolve: nested ref \${${nest_section}.${nest_field}} unresolved"
        # Replace the unresolved placeholder with empty to escape the loop.
        expanded="${expanded//\$\{${nest_section}.${nest_field}\}/}"
        continue
      fi
      expanded="${expanded//\$\{${nest_section}.${nest_field}\}/${nest_val}}"
    done
    expanded="${expanded//\$\{HOME\}/$HOME}"
    expanded="${expanded//\$\{USER\}/${USER:-$(id -un)}}"
    echo "$expanded"
  }
}

# ----------------------------------------------------------------------------
# sf_resolve_output_path
# ----------------------------------------------------------------------------
# Args:
#   $1 — logical name (e.g., "master_spec")
#   $2 — relative path within destination (e.g., "MASTER-SPEC.md")
# Behavior:
#   - Manifest absent              → $(pwd)/<rel_path>
#   - Manifest present:
#     - Unknown name               → warn + $(pwd)/<rel_path>
#     - 'roadmap' missing from map → defaults to canonical (§10.4)
#     - Otherwise                  → <destination.root>/<rel_path>
sf_resolve_output_path() {
  local logical_name="$1"
  local rel_path="$2"

  if [[ -z "$logical_name" || -z "$rel_path" ]]; then
    sf_log_error "sf_resolve_output_path: missing arg(s); usage: sf_resolve_output_path <logical_name> <rel_path>"
    return 1
  fi

  local manifest
  manifest="$(sf_discover_manifest)" || manifest=""

  # No manifest → single-repo fallback.
  if [[ -z "$manifest" ]]; then
    echo "$(pwd)/${rel_path}"
    return 0
  fi

  # Manifest present: look up routing.<logical_name>.
  local destination
  destination="$(jq -r ".routing[\"${logical_name}\"] // empty" "$manifest" 2>/dev/null)"

  if [[ -z "$destination" || "$destination" == "null" ]]; then
    # §10.4 forward-compat: workspace-init v0.1 manifests lack routing.roadmap;
    # default to canonical for that specific logical name.
    if [[ "$logical_name" == "roadmap" ]]; then
      destination="canonical"
    else
      sf_log_warn "logical name '${logical_name}' not in manifest.routing; falling back to cwd"
      echo "$(pwd)/${rel_path}"
      return 0
    fi
  fi

  # Ensure mi_manifest_resolve is available (source or define local fallback).
  _sf_routing_source_mi_resolver

  local ai_root root
  ai_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)"
  ai_root="${ai_root//\$\{HOME\}/$HOME}"
  ai_root="${ai_root//\$\{USER\}/${USER:-$(id -un)}}"
  root="$(mi_manifest_resolve "$ai_root" "\${${destination}.root}")"
  if [[ -z "$root" ]]; then
    sf_log_warn "could not resolve \${${destination}.root} from manifest; falling back to cwd"
    echo "$(pwd)/${rel_path}"
    return 0
  fi
  echo "${root}/${rel_path}"
}
