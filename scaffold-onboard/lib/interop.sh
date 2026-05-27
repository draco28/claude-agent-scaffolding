#!/usr/bin/env bash
# scaffold-onboard/lib/interop.sh
# Claude/Codex workspace compatibility checks and additive repair.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"
if ! declare -F sf_discover_manifest >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/routing.sh"
fi
if ! declare -F sf_agents_merge_managed_section >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/agents.sh"
fi

sf_interop_manifest_path() {
  local root="${1:-}"
  if [[ -n "$root" ]]; then
    echo "${root%/}/.workspace/pairing.json"
    return 0
  fi
  sf_discover_manifest
}

sf_interop_required_routing_keys() {
  cat <<'EOF'
master_spec
executive_summary
memory_bank
claude_md
agents_md
scaffold_project_outputs
roadmap
sprint_specs
implementation_handoffs
brainstorm_artifacts
EOF
}

sf_interop_check() {
  local root="${1:-}"
  local manifest
  if ! manifest="$(sf_interop_manifest_path "$root")" || [[ ! -f "$manifest" ]]; then
    echo "missing:manifest"
    return 1
  fi

  local missing=0
  local key
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    if [[ "$(jq -r --arg k "$key" '.routing[$k] // empty' "$manifest" 2>/dev/null)" == "" ]]; then
      echo "missing:routing.${key}"
      missing=1
    fi
  done < <(sf_interop_required_routing_keys)

  local ai_root agents_path
  ai_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)"
  agents_path="${ai_root}/AGENTS.md"
  if [[ -z "$ai_root" || ! -d "$ai_root" ]]; then
    echo "missing:ai_workspace.root"
    missing=1
  elif [[ ! -f "$agents_path" ]]; then
    echo "missing:AGENTS.md"
    missing=1
  elif ! grep -qF "$SF_AGENTS_START" "$agents_path"; then
    echo "missing:AGENTS.md.managed_section"
    missing=1
  fi

  if [[ -n "$ai_root" ]]; then
    if [[ ! -d "$ai_root/.workspace/locks" ]]; then
      echo "missing:.workspace/locks"
      missing=1
    fi
  fi

  if [[ "$missing" -eq 0 ]]; then
    echo "ready:claude-codex-workspace"
  fi
  return "$missing"
}

sf_interop_repair() {
  local root="${1:-}"
  local manifest
  if ! manifest="$(sf_interop_manifest_path "$root")" || [[ ! -f "$manifest" ]]; then
    sf_log_error "sf_interop_repair: pairing manifest not found"
    return 1
  fi

  local tmp
  tmp="$(mktemp "${manifest}.XXXXXX")"
  if ! jq '
    .routing = (.routing // {}) |
    .routing.master_spec              = (.routing.master_spec              // "ai_workspace") |
    .routing.executive_summary        = (.routing.executive_summary        // "canonical") |
    .routing.memory_bank              = (.routing.memory_bank              // "ai_workspace") |
    .routing.claude_md                = (.routing.claude_md                // "ai_workspace") |
    .routing.agents_md                = (.routing.agents_md                // "ai_workspace") |
    .routing.scaffold_project_outputs = (.routing.scaffold_project_outputs // "ai_workspace") |
    .routing.roadmap                  = (.routing.roadmap                  // "canonical") |
    .routing.sprint_specs             = (.routing.sprint_specs             // "ai_workspace") |
    .routing.implementation_handoffs  = (.routing.implementation_handoffs  // "ai_workspace") |
    .routing.brainstorm_artifacts     = (.routing.brainstorm_artifacts     // "ai_workspace") |
    .during_dev = (.during_dev // {}) |
    .during_dev.worktrees_dir        = (.during_dev.worktrees_dir        // "${canonical.root}/.worktrees") |
    .during_dev.branch_naming        = (.during_dev.branch_naming        // "slice/sprint-{N}-work-{NN}-{kebab-name}") |
    .during_dev.sprint_dir_template  = (.during_dev.sprint_dir_template  // "${ai_workspace.root}/docs/specs/sprint-{N}") |
    .during_dev.slice_spec_format    = (.during_dev.slice_spec_format    // "wabash-format-b-v1") |
    .well_known_paths = (.well_known_paths // {}) |
    .well_known_paths.master_spec = (.well_known_paths.master_spec // "${ai_workspace.root}/docs/MASTER-SPEC.md") |
    .well_known_paths.memory_bank = (.well_known_paths.memory_bank // "${ai_workspace.root}/.claude/memory-bank")
  ' "$manifest" > "$tmp"; then
    rm -f "$tmp"
    sf_log_error "sf_interop_repair: jq failed"
    return 1
  fi
  mv "$tmp" "$manifest"

  local ai_root
  ai_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)"
  if [[ -z "$ai_root" || ! -d "$ai_root" ]]; then
    sf_log_error "sf_interop_repair: ai_workspace.root missing or not a directory"
    return 1
  fi
  mkdir -p "$ai_root/.workspace/locks"
  sf_agents_merge_managed_section "$ai_root/AGENTS.md" "$manifest"
  echo "repaired:claude-codex-workspace"
}
