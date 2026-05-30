#!/usr/bin/env bash
# scaffold-onboard/lib/memory-bank.sh
# Memory-bank derivation: 9 derived files + 2 live (seeded once) + 1 static.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"
if ! declare -F sf_agents_merge_managed_section >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/agents.sh"
fi

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
# Args: --force  (optional) to overwrite live files too.
#       --fast   (optional) sets SF_SYNTH_FAST=1 to skip synthesis dispatch;
#                used by the /scaffold-project --fast flag and as the synthesis
#                fallback path when sub-agent dispatch fails.
sf_memory_bank_derive() {
  local force=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --force) force=1 ;;
      --fast)  export SF_SYNTH_FAST=1 ;;
    esac
  done

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

  # 1 static file — copied when missing, and refreshed on --force so existing
  # projects pick up template rewrites (e.g. the corrected slice-workflow loop,
  # PR #27 / Codex round-3). WORKFLOW.md is project-agnostic (no per-project
  # substitution), so a --force overwrite cannot clobber project-specific content.
  if [[ ! -f ".claude/memory-bank/WORKFLOW.md" || "$force" -eq 1 ]]; then
    cp "$tmpl_dir/WORKFLOW.md" ".claude/memory-bank/WORKFLOW.md"
  fi
}

# Read composition.json (if it exists) and return key=value pairs for plugin awareness
_composition_args() {
  local comp="$(sf_data_dir)/composition.json"
  # architect-critic in v0.2 is NOT tracked in composition.json (per SPEC §12.2 +
  # ac v0.2 settlement #1). Source it from the filesystem probe instead.
  local ac_detected ac_flag
  ac_detected="$(sf_compose_detect_architect_critic 2>/dev/null || true)"
  if [[ "$ac_detected" == "v0.2" ]]; then ac_flag="true"; else ac_flag="false"; fi

  if [[ ! -f "$comp" ]]; then
    echo "has_ai_mentor=false"
    echo "has_architect_critic=$ac_flag"
    echo "has_superpowers=false"
    echo "has_scaffold_plugin=false"
    return 0
  fi
  local v
  v="$(jq -r '.plugins["ai-mentor"].installed // false' "$comp")"
  echo "has_ai_mentor=$v"
  echo "has_architect_critic=$ac_flag"
  v="$(jq -r '.plugins["superpowers"].installed // false' "$comp")"
  echo "has_superpowers=$v"
  # Read the scaffold-dev key only. The legacy "scaffold" plugin (v1.0, which
  # scaffold-dev replaced) shipped a DIFFERENT command surface (/slice-*,
  # /adr-new), so a stale `.plugins["scaffold"]` key must NOT light up the
  # scaffold-dev /orchestrate command block — that would advertise commands the
  # user hasn't installed (PR #27 / Codex round-3). The "scaffold" key was never
  # written by any version anyway, so there is nothing to fall back to.
  v="$(jq -r '.plugins["scaffold-dev"].installed // false' "$comp")"
  echo "has_scaffold_plugin=$v"
}

# Generate <repo>/CLAUDE.md from the template using state.answers + composition.json
sf_claude_md_generate() {
  local root tmpl ts
  root="$(sf_plugin_root)"
  tmpl="$root/templates/claude-md/CLAUDE.md.tmpl"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local args=()
  args+=("project_name=$(sf_project_name)")
  args+=("ts=$ts")
  while IFS= read -r line; do args+=("$line"); done < <(_memory_bank_args "$ts")
  while IFS= read -r line; do args+=("$line"); done < <(_composition_args)

  # Karpathy Behavioral Discipline opt-in (#21). Captured in Phase 10 of /onboard
  # as answer phase_10.4.include_karpathy. Emit the section only when the answer
  # is the literal "yes"; any other value (no / null / missing) opts out.
  local karpathy
  karpathy="$(sf_state_read_answer phase_10.4.include_karpathy 2>/dev/null || echo null)"
  if [[ "$karpathy" == "yes" ]]; then
    args+=("include_karpathy=true")
  else
    args+=("include_karpathy=false")
  fi

  sf_render "$tmpl" "${args[@]}" > CLAUDE.md
}

# Generate .claude/settings.json from template, only if not present.
# We never overwrite a user's settings file. But on an upgrade, an existing file
# may still carry the escape-capable grants removed from the default in v0.3.4
# (#25) — `Bash(rg:*)` (rg --pre runs arbitrary commands), `Bash(jq:*)` (jq -n
# 'env' dumps secrets), and unrestricted local file read via cat/grep/ls. Those
# auto-approve with no prompt, so we scan and WARN loudly rather than silently
# preserving the vulnerability. We do NOT auto-edit the file (that could clobber
# the user's own grants); remediation is left to the user (PR #27 / Codex round-3).
sf_claude_settings_generate() {
  if [[ -f ".claude/settings.json" ]]; then
    local unsafe
    unsafe="$(jq -r '[.permissions.allow[]? | select(test("^Bash\\((rg|jq|cat|grep|ls):"))] | join(", ")' .claude/settings.json 2>/dev/null || echo "")"
    if [[ -n "$unsafe" ]]; then
      sf_log_warn "existing .claude/settings.json auto-approves escape-capable grants: ${unsafe}. These were removed from the default in v0.3.4 (#25) — rg --pre runs arbitrary commands and jq -n 'env' discloses secrets, both with no prompt. Remove them from permissions.allow (not auto-edited)."
    else
      sf_log_info "preserved existing .claude/settings.json"
    fi
    return 0
  fi
  local root tmpl
  root="$(sf_plugin_root)"
  tmpl="$root/templates/settings/claude-settings.json.tmpl"
  mkdir -p .claude
  cp "$tmpl" .claude/settings.json
}

# Generate or refresh the scaffold-managed Codex section in AGENTS.md.
# User-authored content outside the marker block is preserved.
sf_agents_md_generate() {
  local manifest_path=".workspace/pairing.json"
  if declare -F sf_discover_manifest >/dev/null 2>&1; then
    manifest_path="$(sf_discover_manifest 2>/dev/null || echo "$manifest_path")"
  fi
  sf_agents_merge_managed_section "AGENTS.md" "$manifest_path"
}
