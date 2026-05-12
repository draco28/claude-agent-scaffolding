#!/usr/bin/env bash
# scaffold-onboard/lib/memory-bank.sh
# Memory-bank derivation: 9 derived files + 2 live (seeded once) + 1 static.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Render args used by every memory-bank file
_memory_bank_args() {
  local ts="$1"
  local args=("ts=$ts")
  local pc
  pc="$(sf_state_read_answer 1.3.1)"
  [[ "$pc" != "null" ]] && args+=("project_class=$pc")

  # All answered questions
  local path qid val
  path="$(sf_state_path)"
  while IFS=$'\t' read -r qid val; do
    [[ -z "$qid" ]] && continue
    args+=("phase_${qid}=${val}")
  done < <(jq -r '.answers | to_entries[] | "\(.key)\t\(.value)"' "$path")

  # Branching gate flags
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

  printf '%s\n' "${args[@]}"
}

# Derive memory-bank: regenerate derived files, seed live files only if missing,
# copy static file only if missing.
# Args: --force (optional) to overwrite live files too.
sf_memory_bank_derive() {
  local force=0
  if [[ "${1:-}" == "--force" ]]; then force=1; fi

  local root tmpl_dir ts
  root="$(sf_plugin_root)"
  tmpl_dir="$root/templates/memory-bank"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p .claude/memory-bank

  # Collect args once
  local args=()
  while IFS= read -r line; do args+=("$line"); done < <(_memory_bank_args "$ts")

  # 8 derived files
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 07-constraints 08-governance index; do
    sf_render "$tmpl_dir/${f}.md.tmpl" "${args[@]}" > ".claude/memory-bank/${f}.md"
  done

  # 2 live files — seed only if missing (unless --force)
  for f in 05-active-context 06-progress; do
    local target=".claude/memory-bank/${f}.md"
    if [[ ! -f "$target" || "$force" -eq 1 ]]; then
      sf_render "$tmpl_dir/${f}.md.tmpl" "${args[@]}" > "$target"
    else
      sf_log_info "preserved live file: $target"
    fi
  done

  # 1 static file — copy only if missing (--force does NOT overwrite static; it's project-agnostic)
  if [[ ! -f ".claude/memory-bank/WORKFLOW.md" ]]; then
    cp "$tmpl_dir/WORKFLOW.md" ".claude/memory-bank/WORKFLOW.md"
  fi
}

# Read composition.json (if it exists) and return key=value pairs for plugin awareness
_composition_args() {
  local comp="$(sf_data_dir)/composition.json"
  if [[ ! -f "$comp" ]]; then
    echo "has_ai_mentor=false"
    echo "has_architect_critic=false"
    echo "has_superpowers=false"
    echo "has_scaffold_plugin=false"
    return 0
  fi
  local v
  v="$(jq -r '.plugins["ai-mentor"].installed // false' "$comp")"
  echo "has_ai_mentor=$v"
  v="$(jq -r '.plugins["architect-critic"].installed // false' "$comp")"
  echo "has_architect_critic=$v"
  v="$(jq -r '.plugins["superpowers"].installed // false' "$comp")"
  echo "has_superpowers=$v"
  v="$(jq -r '.plugins["scaffold"].installed // false' "$comp")"
  echo "has_scaffold_plugin=$v"
}

# Generate <repo>/CLAUDE.md from the template using state.answers + composition.json
sf_claude_md_generate() {
  local root tmpl ts
  root="$(sf_plugin_root)"
  tmpl="$root/templates/claude-md/CLAUDE.md.tmpl"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # Derive project_name from state answer 1.1.1 (e.g. "test-proj — a fast widget")
  # by taking the segment before " — ". Fall back to basename of PWD.
  local raw_oneliner project_name
  raw_oneliner="$(sf_state_read_answer "1.1.1")"
  if [[ "$raw_oneliner" != "null" && "$raw_oneliner" == *" — "* ]]; then
    project_name="${raw_oneliner%% — *}"
  else
    project_name="$(basename "$PWD")"
  fi

  local args=()
  args+=("project_name=$project_name")
  args+=("ts=$ts")
  while IFS= read -r line; do args+=("$line"); done < <(_memory_bank_args "$ts")
  while IFS= read -r line; do args+=("$line"); done < <(_composition_args)

  sf_render "$tmpl" "${args[@]}" > CLAUDE.md
}

# Generate .claude/settings.json from template, only if not present
sf_claude_settings_generate() {
  if [[ -f ".claude/settings.json" ]]; then
    sf_log_info "preserved existing .claude/settings.json"
    return 0
  fi
  local root tmpl
  root="$(sf_plugin_root)"
  tmpl="$root/templates/settings/claude-settings.json.tmpl"
  mkdir -p .claude
  cp "$tmpl" .claude/settings.json
}
