#!/usr/bin/env bash
# scaffold-onboard/lib/synthesis.sh
# Synthesis layer — aggregates state into cross-cutting derived values.
# Task 2 fills in the synthesis functions; this is a minimal placeholder
# so that test-synthesis.sh can source this file during Task 1 TDD.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Resolve synthesize-vs-deterministic. Callers set SF_SYNTH_FAST=1 for --fast.
# Echoes "fast" or "synthesize".
sf_synth_mode() {
  if [[ "${SF_SYNTH_FAST:-0}" == "1" ]]; then
    echo "fast"
  else
    echo "synthesize"
  fi
}

# Extract the YAML frontmatter block (between the first two '---' lines).
_sf_synth_frontmatter() {
  awk 'NR==1 && $0=="---"{f=1; next} f && $0=="---"{exit} f{print}' "$1"
}

# Read a scalar frontmatter field. Echoes the value (quotes stripped) or empty.
sf_synth_brief_field() {
  local file="$1" key="$2"
  _sf_synth_frontmatter "$file" | awk -v k="$key" '
    $0 ~ "^"k":" { sub("^"k":[ \t]*", ""); gsub(/^"|"$/, ""); print; exit }'
}

# Read a list field. Supports inline "[a, b]" and block "- item" forms.
# Echoes one item per line (quotes/brackets stripped).
sf_synth_brief_list() {
  local file="$1" key="$2"
  _sf_synth_frontmatter "$file" | awk -v k="$key" '
    $0 ~ "^"k":" {
      rest=$0; sub("^"k":[ \t]*", "", rest)
      if (rest ~ /^\[/) {
        gsub(/^\[|\]$/, "", rest); n=split(rest, a, ",")
        for (i=1;i<=n;i++){ gsub(/^[ \t]+|[ \t]+$/,"",a[i]); gsub(/^"|"$/,"",a[i]); if(a[i]!="") print a[i] }
        exit
      }
      blk=1; next
    }
    blk && /^[ \t]*-[ \t]+/ { line=$0; sub(/^[ \t]*-[ \t]+/,"",line); gsub(/^"|"$/,"",line); print line; next }
    blk && /^[^ \t-]/ { exit }'
}

# Validate a brief has all required frontmatter keys. Returns 1 + logs on miss.
sf_synth_brief_validate() {
  local file="$1" k
  for k in doc routes_to wave model; do
    if [[ -z "$(sf_synth_brief_field "$file" "$k")" ]]; then
      sf_log_error "brief $file: missing required key '$k'"; return 1
    fi
  done
  if [[ -z "$(sf_synth_brief_list "$file" required_sections)" ]]; then
    sf_log_error "brief $file: required_sections is empty"; return 1
  fi
  return 0
}
