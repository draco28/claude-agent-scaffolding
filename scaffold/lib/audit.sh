#!/usr/bin/env bash
# scaffold/lib/audit.sh — gap analysis for the current repo.
#
# Public surface:
#   sf_audit_run    — emit one tab-separated row per check on stdout.
#   sf_audit_render_md — read TSV rows on stdin, write a markdown table.
#
# TSV row shape: category<TAB>name<TAB>status<TAB>detail
# Status values: pass | warn | info | fail
#
# Sources lib/state.sh + lib/repo.sh for stack and LLM detection.

SF_AUDIT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./state.sh
source "${SF_AUDIT_LIB_DIR}/state.sh"

# Internal helper. Args: category name status detail
_audit_row() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4"
}

# ── Individual check groups ─────────────────────────────────────────────────

_audit_readme() {
  local root; root="$(sf_repo_root)"
  if [[ -r "$root/README.md" ]]; then
    _audit_row README "README.md exists" pass ""
    if grep -q -E '^##? *Quickstart' "$root/README.md" 2>/dev/null; then
      _audit_row README "Has Quickstart section" pass ""
    else
      _audit_row README "Has Quickstart section" warn "missing ## Quickstart heading"
    fi
  else
    _audit_row README "README.md exists" fail "no README.md"
  fi
}

_audit_license() {
  local root; root="$(sf_repo_root)"
  local lic
  for cand in LICENSE LICENSE.md LICENSE.txt COPYING; do
    if [[ -r "$root/$cand" ]]; then lic="$cand"; break; fi
  done
  if [[ -n "$lic" ]]; then
    _audit_row License "License file exists" pass "$lic"
  else
    _audit_row License "License file exists" fail "no LICENSE / LICENSE.md / COPYING"
  fi
}

_audit_gitignore() {
  local root; root="$(sf_repo_root)"
  if [[ -r "$root/.gitignore" ]]; then
    _audit_row Gitignore ".gitignore exists" pass ""
  else
    _audit_row Gitignore ".gitignore exists" fail "no .gitignore"
  fi
}

_audit_adrs() {
  local root; root="$(sf_repo_root)"
  if [[ -d "$root/docs/adr" ]]; then
    _audit_row ADRs "docs/adr/ exists" pass ""
    local count
    count="$(find "$root/docs/adr" -maxdepth 1 -type f -name '[0-9]*.md' 2>/dev/null | wc -l)"
    if [[ "$count" -gt 0 ]]; then
      _audit_row ADRs "At least one ADR" pass "$count file(s)"
    else
      _audit_row ADRs "At least one ADR" warn "directory empty — record decisions via /adr-new"
    fi
  else
    _audit_row ADRs "docs/adr/ exists" fail "no docs/adr/ — run /scaffold-init or /adr-new"
  fi
}

_audit_runbooks() {
  local root; root="$(sf_repo_root)"
  if [[ -d "$root/docs/runbooks" ]]; then
    _audit_row Runbooks "docs/runbooks/ exists" pass ""
  else
    _audit_row Runbooks "docs/runbooks/ exists" info "optional — create via /runbook-new"
  fi
}

_audit_slices() {
  local root; root="$(sf_repo_root)"
  if [[ -d "$root/docs/slices" ]]; then
    _audit_row Slices "docs/slices/ exists" pass ""
  else
    _audit_row Slices "docs/slices/ exists" info "optional — create via /slice-new"
  fi
}

_audit_changelog() {
  local root; root="$(sf_repo_root)"
  if [[ -r "$root/CHANGELOG.md" ]]; then
    _audit_row Changelog "CHANGELOG.md exists" pass ""
  else
    _audit_row Changelog "CHANGELOG.md exists" info "create via /changelog when you ship something"
  fi
}

_audit_tests() {
  local cmd; cmd="$(sf_test_command)"
  if [[ -n "$cmd" ]]; then
    _audit_row Tests "Test framework detected" pass "$cmd"
  else
    _audit_row Tests "Test framework detected" warn "no pytest/vitest/jest/cargo/go signals"
  fi
}

_audit_llm() {
  local llm; llm="$(sf_llm_detect)"
  [[ "$llm" != "true" ]] && return 0
  local root; root="$(sf_repo_root)"
  # Evals dir
  if [[ -d "$root/evals" || -d "$root/src/evals" ]]; then
    _audit_row LLM "evals/ directory" pass ""
  else
    _audit_row LLM "evals/ directory" warn "LLM project detected — recommend an evals/ harness"
  fi
  # Model card
  if [[ -r "$root/docs/MODEL_CARD.md" ]]; then
    _audit_row LLM "Model card documented" pass "docs/MODEL_CARD.md"
  elif [[ -r "$root/README.md" ]] && grep -qE '(claude|gpt|sonnet|opus|haiku|gemini|llama|mistral)' -i "$root/README.md" 2>/dev/null; then
    _audit_row LLM "Model card documented" warn "model mentioned in README; consider docs/MODEL_CARD.md"
  else
    _audit_row LLM "Model card documented" warn "no MODEL_CARD.md or model name in README"
  fi
}

# ── Top-level audit run ─────────────────────────────────────────────────────

# sf_audit_run — emit TSV rows for every check.
sf_audit_run() {
  _audit_readme
  _audit_license
  _audit_gitignore
  _audit_adrs
  _audit_runbooks
  _audit_slices
  _audit_changelog
  _audit_tests
  _audit_llm
}

# ── Renderers ───────────────────────────────────────────────────────────────

# sf_audit_render_md — read TSV rows from stdin, write markdown table.
# Status icons: ✓ pass, ⚠ warn, ⓘ info, ✗ fail
sf_audit_render_md() {
  local repo_name; repo_name="$(basename "$(sf_repo_root)")"
  printf '# Audit — %s\n\n' "$repo_name"
  printf 'Generated %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '| Status | Category | Check | Detail |\n'
  printf '|---|---|---|---|\n'
  awk -F'\t' '{
    icon = "?"
    if ($3 == "pass") icon = "✓"
    else if ($3 == "warn") icon = "⚠"
    else if ($3 == "info") icon = "ⓘ"
    else if ($3 == "fail") icon = "✗"
    printf "| %s | %s | %s | %s |\n", icon, $1, $2, $4
  }'
}

# sf_audit_summary — read TSV rows from stdin, emit a one-line summary on stderr.
# Returns 1 if any "fail" rows present, 0 otherwise.
sf_audit_summary() {
  local pass=0 warn=0 info=0 fail=0
  while IFS=$'\t' read -r _ _ status _; do
    case "$status" in
      pass) pass=$((pass+1)) ;;
      warn) warn=$((warn+1)) ;;
      info) info=$((info+1)) ;;
      fail) fail=$((fail+1)) ;;
    esac
  done
  printf '\n%d pass · %d warn · %d info · %d fail\n' "$pass" "$warn" "$info" "$fail"
  [[ "$fail" -eq 0 ]]
}
