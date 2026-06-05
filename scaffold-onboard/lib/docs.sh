#!/usr/bin/env bash
# scaffold-onboard/lib/docs.sh
# Governance doc derivation. Default = 5 docs; --full = +9 (3 LLM-gated).

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"
if ! declare -F sf_state_read_answer >/dev/null 2>&1; then
  source "$(dirname "${BASH_SOURCE[0]}")/state.sh"
fi

# Shared render args — same shape as memory-bank.sh's _memory_bank_args
_docs_args() {
  local ts="$1"
  local args=("ts=$ts")
  args+=("project_name=$(sf_project_name)")
  local pc
  pc="$(sf_state_read_answer 1.3.1)"
  [[ "$pc" != "null" ]] && args+=("project_class=$pc")

  local path qid val
  path="$(sf_state_path)"
  while IFS=$'\t' read -r qid val; do
    [[ -z "$qid" ]] && continue
    args+=("phase_${qid}=${val}")
  done < <(jq -r '.answers | to_entries[] | "\(.key)\t\(.value)"' "$path")

  # Branching gate flags (same as memory-bank.sh)
  if sf_state_gate_passes 'project_class in {Web app, Mobile app, CLI tool, ML or AI system, Agent or plugin, Other}'; then
    args+=("ui_branch=true"); else args+=("ui_branch=false"); fi
  if sf_state_gate_passes 'project_class in {Library or SDK, Data pipeline, Web service (API only)}'; then
    args+=("dx_branch=true"); else args+=("dx_branch=false"); fi
  if sf_state_gate_passes 'project_class in {Web app, Web service (API only), ML or AI system, Agent or plugin, Data pipeline}'; then
    args+=("backend_branch=true"); else args+=("backend_branch=false"); fi
  if sf_state_gate_passes 'project_class in {Web app, Mobile app}'; then
    args+=("frontend_branch=true"); else args+=("frontend_branch=false"); fi
  if sf_state_gate_passes 'project_class == "Library or SDK"'; then
    args+=("library_branch=true"); else args+=("library_branch=false"); fi

  printf '%s\n' "${args[@]}"
}

# Derive default + (optionally) full docs.
# Args: [--full] [--regenerate]
sf_docs_derive() {
  local full=0 regen=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --full) full=1 ;;
      --regenerate) regen=1 ;;
      --fast) export SF_SYNTH_FAST=1 ;;
    esac
    shift
  done

  local root ts tmpl_min tmpl_full
  root="$(sf_plugin_root)"
  tmpl_min="$root/templates/docs-minimal"
  tmpl_full="$root/templates/docs-full"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p docs/adr

  local args=()
  while IFS= read -r line; do args+=("$line"); done < <(_docs_args "$ts")

  # 5 default docs
  _write_or_skip "$tmpl_min/PRD.md.tmpl" "docs/PRD.md" "$regen" "${args[@]}"
  _write_or_skip "$tmpl_min/SRS.md.tmpl" "docs/SRS.md" "$regen" "${args[@]}"
  _write_or_skip "$tmpl_min/BACKLOG.md.tmpl" "docs/BACKLOG.md" "$regen" "${args[@]}"
  _write_or_skip "$tmpl_min/PROJECT_PLAN.md.tmpl" "docs/PROJECT_PLAN.md" "$regen" "${args[@]}"
  _write_or_skip "$tmpl_min/adr/0001-record-architecture-decisions.md.tmpl" \
                 "docs/adr/0001-record-architecture-decisions.md" "$regen" "${args[@]}"

  if [[ "$full" -eq 1 ]]; then
    # Always-on --full docs
    _write_or_skip "$tmpl_full/RISK_REGISTER.md.tmpl" "docs/RISK_REGISTER.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/THREAT_MODEL.md.tmpl" "docs/THREAT_MODEL.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/TEST_STRATEGY.md.tmpl" "docs/TEST_STRATEGY.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/DEFINITION_OF_DONE.md.tmpl" "docs/DEFINITION_OF_DONE.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/CUTOVER_PLAN.md.tmpl" "docs/CUTOVER_PLAN.md" "$regen" "${args[@]}"
    _write_or_skip "$tmpl_full/DEMO_RUNBOOK.md.tmpl" "docs/DEMO_RUNBOOK.md" "$regen" "${args[@]}"

    # LLM-gated --full docs
    local uses_llm
    uses_llm="$(sf_state_read_answer 9.3.1)"
    if [[ "$uses_llm" == "yes" || "$uses_llm" == "true" ]]; then
      _write_or_skip "$tmpl_full/EVALS_PLAN.md.tmpl" "docs/EVALS_PLAN.md" "$regen" "${args[@]}"
      _write_or_skip "$tmpl_full/MODEL_CARD.md.tmpl" "docs/MODEL_CARD.md" "$regen" "${args[@]}"
      _write_or_skip "$tmpl_full/PROMPT_GOVERNANCE.md.tmpl" "docs/PROMPT_GOVERNANCE.md" "$regen" "${args[@]}"
    else
      sf_log_info "LLM-gated --full docs skipped (phase 9.3.1 != yes)"
    fi
  fi
}

# Internal helper: render template to target unless target exists and not --regenerate.
_write_or_skip() {
  local tmpl="$1" target="$2" regen="$3"; shift 3
  if [[ -f "$target" && "$regen" -ne 1 ]]; then
    sf_log_info "preserved: $target"
    return 0
  fi
  mkdir -p "$(dirname "$target")"
  sf_render "$tmpl" "$@" > "$target"
}
