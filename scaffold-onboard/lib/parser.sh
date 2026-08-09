#!/usr/bin/env bash
# scaffold-onboard/lib/parser.sh
# MASTER-SPEC.md parser. Three primitives: phase markers, key-value lines,
# subsection headers. Free-text is everything between known anchors.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Returns a space-separated list of phase IDs present in the spec.
sf_spec_phases_present() {
  local path="$1"
  grep -oE '<!-- master-spec:phase id=([0-9]+) name=' "$path" \
    | grep -oE 'id=[0-9]+' \
    | sed 's/id=//' \
    | tr '\n' ' ' \
    | sed 's/ $//'
}

# Print the content of phase N (markdown between marker N and marker N+1, the
# post-MVP appendix boundary, or EOF). The appendix is a top-level peer after
# Phase 10 and must not be reported as Operations & Support content.
sf_spec_phase() {
  local path="$1" pid="$2"
  awk -v target="$pid" '
    BEGIN { in_phase = 0 }
    /^<!-- master-spec:phase id=[0-9]+ name=.+ -->$/ {
      # Extract id value using sub() — POSIX awk compatible
      line = $0
      sub(/^<!-- master-spec:phase id=/, "", line)
      sub(/ .*$/, "", line)
      pid = line
      if (pid == target) { in_phase = 1; next }
      else if (in_phase) { in_phase = 0 }
    }
    # Contract anchor: MASTER-SPEC.brief.md requires this exact heading as the
    # Phase-10 extraction boundary. Keep the heading synchronized there.
    /^## Appendix: Post-MVP Horizon[[:space:]]*$/ {
      if (in_phase) { in_phase = 0 }
    }
    in_phase { print }
  ' "$path"
}

# Read a bold-key colon-value line. Returns empty string if not found.
# Pattern: ^\*\*([\w\s&/-]+):\*\*\s+(.+)$
sf_spec_kv() {
  local path="$1" key="$2"
  # Escape regex specials in key
  local key_re
  key_re="$(printf '%s' "$key" | sed -e 's/[][\\.^$*+?(){}|]/\\&/g')"
  grep -m1 -oE "^\*\*${key_re}:\*\*[[:space:]]+.*$" "$path" 2>/dev/null \
    | sed -E "s/^\*\*${key_re}:\*\*[[:space:]]+//"
}

sf_spec_project_class() {
  sf_spec_kv "$1" "Project class"
}

# Print content of subsection `M.N` (### M.N Title) until the next ### or ##.
sf_spec_subsection() {
  local path="$1" sec="$2"
  awk -v target="$sec" '
    BEGIN { in_sec = 0 }
    /^### [0-9]+\.[0-9]+ / {
      line = $0
      sub(/^### /, "", line)
      sub(/ .*$/, "", line)
      sec = line
      if (sec == target) { in_sec = 1; print; next }
      else if (in_sec) { in_sec = 0 }
    }
    /^## / { if (in_sec) in_sec = 0 }
    in_sec { print }
  ' "$path"
}

# Print content of the executive summary section.
sf_spec_summary() {
  local path="$1"
  awk '
    BEGIN { in_sec = 0 }
    /^## Executive Summary[[:space:]]*$/ { in_sec = 1; next }
    /^## / && !/^## Executive Summary/ { if (in_sec) in_sec = 0 }
    /^---[[:space:]]*$/ { if (in_sec) in_sec = 0 }
    in_sec { print }
  ' "$path"
}

# The 9 enum values for project class (spec §6.5)
SF_PROJECT_CLASS_ENUM=(
  "CLI tool" "Library or SDK" "Web app" "Web service (API only)"
  "Mobile app" "ML or AI system" "Agent or plugin" "Data pipeline" "Other"
)

# Validate a MASTER-SPEC.md file. Exit 0 if OK; non-zero with stderr message
# on first ERROR. WARNINGs and INFOs do not block.
sf_spec_validate() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    sf_log_error "MASTER-SPEC.md not found at $path. Run /onboard first."
    return 1
  fi
  if ! head -1 "$path" | grep -qE "^# .+ — Master Specification$"; then
    sf_log_error "Missing top-level '# <name> — Master Specification' heading."
    return 1
  fi
  if ! grep -qE "^## Executive Summary[[:space:]]*$" "$path"; then
    sf_log_error "Missing ## Executive Summary section."
    return 1
  fi
  local phases
  phases="$(sf_spec_phases_present "$path")"
  local missing=""
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if ! echo " $phases " | grep -q " $i "; then
      missing="$missing id=$i"
    fi
  done
  if [[ -n "$missing" ]]; then
    sf_log_error "Missing phase markers:$missing. Phases must be authored via /onboard."
    return 1
  fi
  local pc
  pc="$(sf_spec_project_class "$path")"
  if [[ -z "$pc" ]]; then
    sf_log_error "Project class enum not found. Expected **Project class:** <enum>."
    return 1
  fi
  local known=0 enum
  for enum in "${SF_PROJECT_CLASS_ENUM[@]}"; do
    if [[ "$pc" == "$enum" ]]; then known=1; break; fi
  done
  if [[ "$known" -ne 1 ]]; then
    sf_log_error "Project class '$pc' not in enum. Expected one of: ${SF_PROJECT_CLASS_ENUM[*]}"
    return 1
  fi
  # WARNING-level: spec version
  local sv
  sv="$(sf_spec_kv "$path" "Spec version")"
  if [[ "$sv" != "1.0" ]]; then
    sf_log_warn "Spec version '$sv' unrecognized. Continuing with v1.0 parser."
  fi
  return 0
}
