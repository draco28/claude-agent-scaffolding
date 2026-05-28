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

# Empty ledger literal.
sf_synth_ledger_empty() { echo '{"use_cases":[],"frs":[],"nfrs":[],"backlog":[]}'; }

# Merge a returned ids_minted object into the running ledger (array concat per family).
sf_synth_ledger_merge() {
  local ledger="$1" add="$2"
  printf '%s\n%s\n' "$ledger" "$add" | jq -s '
    .[0] as $l | .[1] as $a
    | {
        use_cases: (($l.use_cases // []) + ($a.use_cases // [])),
        frs:       (($l.frs       // []) + ($a.frs       // [])),
        nfrs:      (($l.nfrs      // []) + ($a.nfrs      // [])),
        backlog:   (($l.backlog   // []) + ($a.backlog   // []))
      }'
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

# Assert every space-separated cited ID exists in the ledger's id sets.
sf_synth_validate_cited() {
  local ledger="$1" cited="$2" id
  local known
  known="$(printf '%s' "$ledger" | jq -r '[.use_cases[],.frs[],.nfrs[],.backlog[]] | .[].id')"
  for id in $cited; do
    if ! printf '%s\n' "$known" | grep -qxF "$id"; then
      sf_log_error "cited id '$id' not found in ledger"; return 1
    fi
  done
  return 0
}

# Reject leftover fill-in markers in a synthesized doc.
sf_synth_assert_no_markers() {
  local file="$1"
  if grep -nE '\*\([^)]*\)\*|TODO: ' "$file" >/dev/null 2>&1; then
    sf_log_error "fill-in markers remain in $file"; return 1
  fi
  return 0
}

# Assert each required section heading from a brief exists in the doc.
sf_synth_assert_sections() {
  local brief="$1" doc="$2" sec
  while IFS= read -r sec; do
    [[ -z "$sec" ]] && continue
    if ! grep -qF "$sec" "$doc"; then
      sf_log_error "required section '$sec' missing from $doc"; return 1
    fi
  done < <(sf_synth_brief_list "$brief" required_sections)
  return 0
}

# Map a family token (UC/FR/NFR/BACKLOG) to its ledger array key.
_sf_synth_family_key() {
  case "$1" in
    UC) echo use_cases ;; FR) echo frs ;; NFR) echo nfrs ;; BACKLOG) echo backlog ;;
    *) echo "" ;;
  esac
}

sf_synth_brief_assemble() {
  local brief="$1" ledger="$2" out_path="$3" master="$4" exec_summary="$5"
  local body slice fam key
  body="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{f=0;skip=1;next} skip{print}' "$brief")"

  slice="$(sf_synth_ledger_empty)"
  while IFS= read -r fam; do
    [[ -z "$fam" ]] && continue
    key="$(_sf_synth_family_key "$fam")"; [[ -z "$key" ]] && continue
    local fam_obj
    fam_obj="$(printf '%s' "$ledger" | jq --arg k "$key" '{($k): (.[$k] // [])}')"
    slice="$(sf_synth_ledger_merge "$slice" "$fam_obj")"
  done < <(sf_synth_brief_list "$brief" consumes)

  cat <<EOF
You are synthesizing one artifact for the project. Read both source documents in full first:
- MASTER-SPEC: $master
- EXECUTIVE-SUMMARY: $exec_summary

Write the artifact to: $out_path

Required sections (must all appear, in this order):
$(sf_synth_brief_list "$brief" required_sections | sed 's/^/- /')

IDs you must MINT (format below) and/or CITE from the provided ledger:
- mints: $(sf_synth_brief_list "$brief" mints | tr '\n' ' ')
- consumes (cite only these IDs; they already exist): $(sf_synth_brief_list "$brief" consumes | tr '\n' ' ')

Provided ID ledger slice (cite IDs from here; do not invent IDs in consumed families):
$slice

Synthesis guidance:
$body

Hard rules: no fill-in markers (no "*(...)*", no "TODO:"); every required section has real content; return the ID-ledger JSON described in your agent contract.
EOF
}

sf_synth_coverage_report() {
  local ledger="$1" covered="$2" id
  echo "## Requirement coverage"
  for id in $(printf '%s' "$ledger" | jq -r '[.frs[],.nfrs[]] | .[].id'); do
    if printf '%s\n' "$covered" | grep -qxF "$id"; then
      echo "- $id: covered"
    else
      echo "- $id: UNASSIGNED"
    fi
  done
}
