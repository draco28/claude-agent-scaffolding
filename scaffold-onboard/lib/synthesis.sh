#!/usr/bin/env bash
# scaffold-onboard/lib/synthesis.sh
# Synthesis layer — aggregates state into cross-cutting derived values.
# Task 2 fills in the synthesis functions; this is a minimal placeholder
# so that test-synthesis.sh can source this file during Task 1 TDD.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

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
  # Ledger entries may be objects ({id,title,...}) OR plain ID strings, depending
  # on what the synthesis agent returned in ids_minted (#23 Bug 2). Tolerate both.
  known="$(printf '%s' "$ledger" | jq -r '[.use_cases[],.frs[],.nfrs[],.backlog[]] | .[] | if type=="object" then .id else . end' 2>/dev/null)"
  for id in $cited; do
    if ! printf '%s\n' "$known" | grep -qxF "$id"; then
      sf_log_error "cited id '$id' not found in ledger"; return 1
    fi
  done
  return 0
}

# Reject leftover fill-in markers in a synthesized doc.
#
# A "marker" is leftover author-instruction text, not real content. We match:
#   - literal TODO: / TBD tokens, and
#   - an italic-parenthetical *(...)* whose body is an IMPERATIVE fill-in
#     instruction (populate/describe/list/set/seed/verify/steps/...).
# We deliberately do NOT flag every *(...)*: synthesis agents legitimately emit
# italic parentheticals for annotations like *(traces_uc: UC-1)* or
# *(completed 2026-06-14)* — flagging those caused valid docs to be downgraded
# to templates (#23 Bug 1). The keyword gate catches the deterministic template
# stubs (which are all imperative) without tripping on factual annotations.
sf_synth_assert_no_markers() {
  local file="$1"
  local fillin='(populate|describe|list things|list out|set per|set numerical|seed with|seed from|pre-baked|escape clause|tasks to|steps to|steps in|plan your|monitoring checks|features that|fill in|e\.g\.,)'
  if grep -nE "TODO:|\\bTBD\\b|\\*\\([^)]*\\b${fillin}\\b[^)]*\\)\\*" "$file" >/dev/null 2>&1; then
    sf_log_error "fill-in markers remain in $file"; return 1
  fi
  return 0
}

# Assert each required section heading from a brief exists in the doc.
# Normalizes both sides before comparison (#23 Bug 3): synthesis agents vary
# heading case ("## Success Metric" vs required "Success metric") and sometimes
# drop a trailing parenthetical suffix ("## Initial stories" vs required
# "Initial stories (seeded from MASTER-SPEC.md)"). We lowercase, collapse
# whitespace, strip a trailing "(...)" from the required heading, and match as a
# substring so correct content isn't downgraded to a template over cosmetics.
sf_synth_assert_sections() {
  local brief="$1" doc="$2" sec sec_norm doc_norm
  doc_norm="$(tr 'A-Z' 'a-z' < "$doc" | tr -s ' \t' ' ')"
  while IFS= read -r sec; do
    [[ -z "$sec" ]] && continue
    sec_norm="$(printf '%s' "$sec" \
      | sed -E 's/[[:space:]]*\([^)]*\)[[:space:]]*$//' \
      | tr 'A-Z' 'a-z' | tr -s ' \t' ' ' | sed 's/^ *//; s/ *$//')"
    [[ -z "$sec_norm" ]] && continue
    if ! printf '%s' "$doc_norm" | grep -qF "$sec_norm"; then
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
  local body slice fam key source_intro exec_summary_line
  body="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{f=0;skip=1;next} skip{print}' "$brief")"

  slice="$(sf_synth_ledger_empty)"
  while IFS= read -r fam; do
    [[ -z "$fam" ]] && continue
    key="$(_sf_synth_family_key "$fam")"; [[ -z "$key" ]] && continue
    local fam_obj
    fam_obj="$(printf '%s' "$ledger" | jq --arg k "$key" '{($k): (.[$k] // [])}')"
    slice="$(sf_synth_ledger_merge "$slice" "$fam_obj")"
  done < <(sf_synth_brief_list "$brief" consumes)

  # Branch-gated sections (#26 Slip 1): listed but NOT in "must all appear".
  # The agent includes one only when the project's branch/gate activates it
  # (the Synthesis guidance below spells out each gate). Omitting an
  # inapplicable gated section is correct — the validator never hard-requires
  # gated sections, so a needless template fallback no longer fires.
  local gated_block="" gated_list
  gated_list="$(sf_synth_brief_list "$brief" gated_sections)"
  if [[ -n "$gated_list" ]]; then
    gated_block=$'\n\nConditional sections (include a section ONLY when its branch/gate applies — see Synthesis guidance; omit the heading entirely otherwise, never emit an empty heading):\n'"$(printf '%s' "$gated_list" | sed 's/^/- /')"
  fi

  if [[ -n "$exec_summary" ]]; then
    source_intro="Read both source documents in full first:"
    exec_summary_line="- EXECUTIVE-SUMMARY: $exec_summary"
  else
    source_intro="Read the source document in full first:"
    exec_summary_line=""
  fi

  cat <<EOF
You are synthesizing one artifact for the project. $source_intro
- MASTER-SPEC: $master
$exec_summary_line

Write the artifact to: $out_path

Required sections (must all appear, in this order):
$(sf_synth_brief_list "$brief" required_sections | sed 's/^/- /')$gated_block

IDs you must MINT (format below) and/or CITE from the provided ledger:
- mints: $(sf_synth_brief_list "$brief" mints | tr '\n' ' ')
- consumes (cite only these IDs; they already exist): $(sf_synth_brief_list "$brief" consumes | tr '\n' ' ')

Provided ID ledger slice (cite IDs from here; do not invent IDs in consumed families):
$slice

Synthesis guidance:
$body

Hard rules: no leftover fill-in placeholders — no "TODO:"/"TBD", and no imperative author-instruction stubs like "*(populate ...)*" or "*(describe ...)*". Factual italic annotations such as "*(traces_uc: UC-1)*" are fine. Every required section must have real content; emit each required section heading verbatim (including any parenthetical). Conditional sections are included only when their branch/gate applies — omitting an inapplicable one is correct, not an error. Return the ID-ledger JSON described in your agent contract.
EOF
}

# Assemble the MASTER-SPEC synthesis prompt. Unlike sf_synth_brief_assemble
# (which synthesizes a downstream artifact FROM MASTER-SPEC), this synthesizes
# MASTER-SPEC itself FROM the onboarding discussion digest.
# Args: <brief> <digest_file> <out_path>
#   digest_file — path to a FILE containing the digest text. Passed as a file
#                 (not a string) to avoid ARG_MAX failures when the digest is
#                 large (verbose answers + many phase records can exceed the OS
#                 per-argument / ARG_MAX limit on the sf dispatcher exec call).
# Always first-author: MASTER-SPEC is authored whole from the digest. (Partial
# reconcile was decommissioned in v0.7.0 — #58 wontfix.)
sf_synth_master_spec_prompt() {
  # Guard: arg count. The signature dropped from 6 args to 3 in v0.7.0 (partial
  # reconcile decommissioned, #58). Reject a stale caller still passing the old
  # `… <mode> <touched> <existing>` form rather than silently ignoring args 4-6.
  if [[ $# -ne 3 ]]; then
    sf_log_error "sf_synth_master_spec_prompt: expects 3 args <brief> <digest_file> <out_path> (got $#) — the 6-arg reconcile form was removed in v0.7.0 (#58)"
    return 1
  fi
  local brief="$1" digest_file="$2" out_path="$3"

  # Guard: brief file must exist and be readable.
  [[ -f "$brief" && -r "$brief" ]] || { sf_log_error "sf_synth_master_spec_prompt: brief not found/readable: $brief"; return 1; }

  # Guard: digest file must exist and be readable.
  if [[ ! -f "$digest_file" || ! -r "$digest_file" ]]; then
    sf_log_error "sf_synth_master_spec_prompt: digest file not found or not readable: $digest_file"
    return 1
  fi

  # Guard: digest file must be non-empty. `sf_state_synthesis_digest` always
  # emits at least a header on success; an empty file means digest generation
  # failed (e.g. corrupt onboarding-state.json) and the caller's `> "$file"`
  # redirection still left a readable 0-byte file. Refuse to assemble a prompt
  # from nothing — otherwise the close ceremony would synthesize a hollow
  # MASTER-SPEC instead of preserving status=close_pending.
  if [[ ! -s "$digest_file" ]]; then
    sf_log_error "sf_synth_master_spec_prompt: digest file is empty (state synthesis likely failed): $digest_file"
    return 1
  fi

  local digest body
  digest="$(cat "$digest_file")"
  body="$(awk 'NR==1 && $0=="---"{f=1;next} f && $0=="---"{f=0;skip=1;next} skip{print}' "$brief")"

  local mode_block="MODE: first-author
No existing MASTER-SPEC. Author the whole document fresh."

  # IMPORTANT: emit via printf with every dynamic value as a DATA argument.
  # Do NOT use an unquoted heredoc here — $digest carries verbatim user-authored
  # answer text, and an unquoted heredoc would run $(...) / backticks it contains
  # (command injection) or silently expand $VARs in it.
  # Reading the digest from a file via $(cat "$digest_file") does NOT re-expand
  # command substitutions or backticks in the content — the shell only evaluates
  # them once at the $(cat ...) assignment site, and the resulting string is inert.
  printf '%s\n' \
    "You are synthesizing the project's MASTER-SPEC.md from the onboarding discussion" \
    "digest below." \
    "" \
    "Write the artifact to: $out_path" \
    "" \
    "$mode_block" \
    "" \
    "--- BEGIN DISCUSSION DIGEST ---" \
    "$digest" \
    "--- END DISCUSSION DIGEST ---" \
    "" \
    "$body"
}

sf_synth_coverage_report() {
  local ledger="$1" covered="$2" id
  echo "## Requirement coverage"
  # Tolerate object- or string-shaped ledger entries (#23 Bug 2).
  for id in $(printf '%s' "$ledger" | jq -r '[.frs[],.nfrs[]] | .[] | if type=="object" then .id else . end' 2>/dev/null); do
    if printf '%s\n' "$covered" | grep -qxF "$id"; then
      echo "- $id: covered"
    else
      echo "- $id: UNASSIGNED"
    fi
  done
}
