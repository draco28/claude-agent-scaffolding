#!/usr/bin/env bash
# scaffold-onboard/lib/render.sh
# Template substitution. Grammar: {{key}} for single values. Missing values
# render as TODO: <key>. Block forms ({{#if}}, {{#each}}) added in TB.10.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# sf_render <template_path> key=value key=value ...
# Echoes the rendered template. Missing keys render as "TODO: <key>".
sf_render() {
  local tmpl="$1"; shift
  local content
  content="$(cat "$tmpl")"
  # Store key=value pairs in indexed arrays for bash 3 compatibility.
  # (bash 4 associative arrays unavailable on macOS system bash 3.2.)
  local -a var_keys=()
  local -a var_vals=()
  local kv key val
  for kv in "$@"; do
    key="${kv%%=*}"
    val="${kv#*=}"
    var_keys+=("$key")
    var_vals+=("$val")
  done

  # _lookup_var <key> — sets _LOOKUP_RESULT to value, or empty string on miss.
  # Returns 0 if found, 1 if not found.
  _lookup_var() {
    local target="$1"
    local i
    for i in "${!var_keys[@]}"; do
      if [[ "${var_keys[$i]}" == "$target" ]]; then
        _LOOKUP_RESULT="${var_vals[$i]}"
        return 0
      fi
    done
    _LOOKUP_RESULT=""
    return 1
  }

  # Step 1: Process {{#if key}}...{{/if}} blocks.
  # Pass the variable map to awk via environment variables:
  #   AWK_KEYS — newline-separated list of keys
  #   AWK_VALS — newline-separated list of values (parallel to AWK_KEYS)
  # BSD awk (macOS) is used; no 3-arg match(), no gensub().
  local awk_keys_str awk_vals_str
  awk_keys_str="$(printf '%s\n' "${var_keys[@]+"${var_keys[@]}"}")"
  awk_vals_str="$(printf '%s\n' "${var_vals[@]+"${var_vals[@]}"}")"

  local processed
  processed="$(
    AWK_KEYS="$awk_keys_str" AWK_VALS="$awk_vals_str" \
    awk '
    BEGIN {
      # Load the key→value map from environment variables.
      n = split(ENVIRON["AWK_KEYS"], keys, "\n")
          split(ENVIRON["AWK_VALS"], vals, "\n")
      for (i = 1; i <= n; i++) {
        if (keys[i] != "") {
          varmap[keys[i]] = vals[i]
        }
      }
      in_if    = 0
      truthy   = 0
    }

    # Detect {{#if key}} — opening tag.
    /\{\{#if [a-zA-Z0-9_.]+\}\}/ {
      # Extract the key between "{{#if " and "}}".
      line = $0
      sub(/.*\{\{#if /, "", line)
      sub(/\}\}.*/, "", line)
      ifkey = line
      in_if  = 1
      truthy = (ifkey in varmap && varmap[ifkey] == "true") ? 1 : 0
      next  # skip the {{#if}} line itself
    }

    # Detect {{/if}} — closing tag.
    /\{\{\/if\}\}/ {
      in_if  = 0
      truthy = 0
      next  # skip the {{/if}} line itself
    }

    # All other lines: print only when not in a falsy if-block.
    {
      if (!in_if || truthy) print
    }
    ' <<< "$content"
  )"

  # Step 2: Substitute {{key}} placeholders using existing bash loop.
  local result="$processed"
  local _LOOKUP_RESULT=""
  while [[ "$result" =~ \{\{([a-zA-Z0-9_.]+)\}\} ]]; do
    local placeholder="${BASH_REMATCH[0]}"
    local k="${BASH_REMATCH[1]}"
    local v
    if _lookup_var "$k"; then
      v="$_LOOKUP_RESULT"
    else
      v="TODO: $k"
    fi
    # Use bash parameter expansion to replace all occurrences in one pass.
    result="${result//$placeholder/$v}"
  done
  printf '%s\n' "$result"
}

# Echo the body of MASTER-SPEC's "## <heading>" section (first match),
# stopping at the next "## " heading. Empty output if absent. Warns (stderr)
# when a SECOND identical heading exists — spec §2.3 "first wins + warn".
# NOTE: <heading> is assumed ERE-metachar-free (only "Executive Summary" is passed today).
sf_master_spec_section() {
  local file="$1" heading="$2"
  local count
  count="$(grep -cE "^## ${heading}\$" "$file" 2>/dev/null || true)"
  if [[ "${count:-0}" -gt 1 ]]; then
    sf_log_warn "MASTER-SPEC has $count '## $heading' sections; using the first (spec §2.3)."
  fi
  awk -v h="## $heading" '
    $0==h { grab=1; next }
    grab && /^## / { exit }
    grab { print }
  ' "$file"
}

# Deterministic EXEC-SUMMARY renderer. Args: <master-spec> <out> <project_name> <project_class>
# Extracts MASTER-SPEC "## Executive Summary"; ERRORS (rc=1) if absent/empty.
# Appends a cksum provenance trailer used for staleness detection.
sf_render_executive_summary() {
  local master="$1" out="$2" project_name="$3" project_class="$4"
  [[ -f "$master" ]] || { sf_log_error "sf_render_executive_summary: MASTER-SPEC not found: $master"; return 1; }
  local body; body="$(sf_master_spec_section "$master" "Executive Summary")"
  # Trim leading + trailing blank lines (keep internal blanks).
  body="$(printf '%s\n' "$body" | sed -e '/./,$!d' | awk 'NF{n=NR} {a[NR]=$0} END{for(i=1;i<=n;i++)print a[i]}')"
  if [[ -z "${body// /}" ]]; then
    sf_log_error "sf_render_executive_summary: MASTER-SPEC has no non-empty '## Executive Summary' section. Add one (it is the pinned source for EXECUTIVE-SUMMARY.md), then re-run."
    return 1
  fi
  local root tmpl; root="$(sf_plugin_root)"; tmpl="$root/templates/master-spec/EXECUTIVE-SUMMARY.md.tmpl"
  [[ -f "$tmpl" ]] || { sf_log_error "sf_render_executive_summary: template not found: $tmpl"; return 1; }
  local created; created="$(date -u +%Y-%m-%d)"
  # Substitute scalars + the MULTI-LINE body in a single awk pass that reads the
  # body from ENVIRON["EXEC_BODY"] (correction A: sf_render newline-splits AWK_VALS
  # and would corrupt a multi-line value). We do scalar substitution with index()/
  # substr (no gsub — avoids replacement-string metacharacters like & being magic),
  # and emit the body verbatim at the {{executive_summary}} line.
  EXEC_PN="$project_name" EXEC_PC="$project_class" EXEC_DATE="$created" EXEC_BODY="$body" \
  awk '
    function subst_all(line,   key, val, out, p) {
      # Replace every literal {{key}} occurrence with val (no regex metachar magic).
      out = ""
      while ((p = index(line, "{{"))!= 0) {
        out = out substr(line, 1, p-1)
        line = substr(line, p)
        if (line ~ /^\{\{project_name\}\}/)        { out = out ENVIRON["EXEC_PN"];   line = substr(line, 17) }
        else if (line ~ /^\{\{project_class\}\}/)   { out = out ENVIRON["EXEC_PC"];   line = substr(line, 18) }
        else if (line ~ /^\{\{created_date\}\}/)    { out = out ENVIRON["EXEC_DATE"]; line = substr(line, 17) }
        else { out = out "{{"; line = substr(line, 3) }
      }
      return out line
    }
    # body placeholder must be standalone on its line; we replace the whole line with the multi-line body
    /^[[:space:]]*\{\{executive_summary\}\}[[:space:]]*$/ { print ENVIRON["EXEC_BODY"]; next }
    { print subst_all($0) }
  ' "$tmpl" > "$out"
  printf '\n<!-- derived from MASTER-SPEC.md cksum:%s -->\n' "$(cksum < "$master" | awk '{print $1"-"$2}')" >> "$out"
}

# Return 0 if EXEC-SUMMARY is FRESH vs MASTER-SPEC, 1 if STALE / missing / no trailer.
sf_exec_summary_staleness() {
  local master="$1" exec_summary="$2"
  [[ -f "$exec_summary" ]] || return 1
  local cur trailer
  cur="$(cksum < "$master" | awk '{print $1"-"$2}')"
  trailer="$(grep -oE 'cksum:[0-9]+-[0-9]+' "$exec_summary" | tail -1 | sed 's/cksum://')"
  [[ -n "$trailer" && "$trailer" == "$cur" ]]
}

# Initialize MASTER-SPEC.md from the template with project_name and project_class.
# All other placeholders render as TODO: <key> at init; they get filled in
# as phases complete (via sf_master_spec_update_phase).
sf_master_spec_init() {
  local tmpl="$1" project_name="$2" project_class="$3"
  local today
  today="$(date -u +%Y-%m-%d)"
  sf_render "$tmpl" \
    "project_name=$project_name" \
    "project_class=$project_class" \
    "created_date=$today" \
    "updated_date=$today" \
    > MASTER-SPEC.md
}

# Re-render MASTER-SPEC.md from the template, populating Phase N's placeholders
# with values from state.answers. Other phases' placeholders are left as-is
# (preserved from prior runs or showing TODO: <key> if not yet answered).
#
# Strategy: re-render the FULL template each time, with all currently-known
# answers fed in. This is deterministic and idempotent.
sf_master_spec_update_phase() {
  local tmpl="$1" phase_id="$2"
  # Collect every answered question's id+value into key=value pairs
  local args=()
  args+=("project_name=$(sf_project_name)")
  local pc
  pc="$(sf_state_read_answer 1.3.1)"
  [[ "$pc" != "null" ]] && args+=("project_class=$pc")
  args+=("created_date=$(date -u +%Y-%m-%d)")
  args+=("updated_date=$(date -u +%Y-%m-%d)")

  # All phase answers
  local path
  path="$(sf_state_path)"
  local qid val
  while IFS=$'\t' read -r qid val; do
    [[ -z "$qid" ]] && continue
    # phases.yaml uses "1.1.1" → template placeholder {{phase_1.1.1}}
    args+=("phase_${qid}=${val}")
  done < <(jq -r '.answers | to_entries[] | "\(.key)\t\(.value)"' "$path")

  # Branching gate flags for {{#if}} blocks
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
  local llm
  llm="$(sf_state_read_answer 9.3.1)"
  if [[ "$llm" == "yes" || "$llm" == "true" ]]; then
    args+=("uses_llm=true")
  else
    args+=("uses_llm=false")
  fi

  sf_render "$tmpl" "${args[@]}" > MASTER-SPEC.md
}
