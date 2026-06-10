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

# Echo the body of MASTER-SPEC's "## <heading>" section (first match), stopping
# at the next section heading, top-level section delimiter, or master-spec phase
# marker. Empty output if absent. Warns (stderr) when a SECOND identical heading
# exists — spec §2.3 "first wins + warn".
# NOTE: <heading> is assumed ERE-metachar-free (only "Executive Summary" is passed today).
sf_master_spec_section() {
  local file="$1" heading="$2"
  local count
  count="$(grep -cE "^## ${heading}[[:space:]]*$" "$file" 2>/dev/null || true)"
  if [[ "${count:-0}" -gt 1 ]]; then
    sf_log_warn "MASTER-SPEC has $count '## $heading' sections; using the first (spec §2.3)."
  fi
  awk -v heading="$heading" '
    BEGIN { h = "^## " heading "[[:space:]]*$" }
    $0 ~ h { grab=1; next }
    grab && /^## / { exit }
    grab && /^---[[:space:]]*$/ { exit }
    grab && /^<!-- master-spec:phase id=/ { exit }
    grab { print }
  ' "$file"
}

_sf_render_executive_summary_body() {
  local master="$1" out="$2" project_name="$3" project_class="$4" body="$5"
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

_sf_master_spec_replace_section_body() {
  local file="$1" heading="$2" body="$3"
  # Guard the single write choke point: a body destined for MASTER-SPEC's pinned
  # "## <heading>" section must NOT contain a section delimiter. The section's own
  # extractor (sf_master_spec_section) stops at `## `, a `---`/`***`/`___` horizontal
  # rule, or a `<!-- master-spec:phase` marker — so writing one of those back would
  # silently truncate MASTER-SPEC, inject a bogus top-level section, or resurrect old
  # stale-tail content. Reject loudly and leave MASTER-SPEC untouched. This protects
  # ALL callers (from_synthesized, from_state, future). A single `-` bullet is fine;
  # only a 3+ dash/star/underscore HORIZONTAL RULE is a delimiter.
  if printf '%s\n' "$body" | grep -qE '^[[:space:]]*##[[:space:]]'; then
    sf_log_error "_sf_master_spec_replace_section_body: refusing to write an Executive Summary body containing a section delimiter (## heading) — it would corrupt MASTER-SPEC. The summary must be prose/bullets only."
    return 1
  fi
  if printf '%s\n' "$body" | grep -qE '^[[:space:]]*-{3,}[[:space:]]*$'; then
    sf_log_error "_sf_master_spec_replace_section_body: refusing to write an Executive Summary body containing a section delimiter (--- rule) — it would corrupt MASTER-SPEC. The summary must be prose/bullets only."
    return 1
  fi
  if printf '%s\n' "$body" | grep -qE '^[[:space:]]*(\*{3,}|_{3,})[[:space:]]*$'; then
    sf_log_error "_sf_master_spec_replace_section_body: refusing to write an Executive Summary body containing a section delimiter (*** / ___ rule) — it would corrupt MASTER-SPEC. The summary must be prose/bullets only."
    return 1
  fi
  if printf '%s\n' "$body" | grep -qE '^<!-- master-spec:phase'; then
    sf_log_error "_sf_master_spec_replace_section_body: refusing to write an Executive Summary body containing a section delimiter (phase marker) — it would corrupt MASTER-SPEC. The summary must be prose/bullets only."
    return 1
  fi
  local tmp
  tmp="$(mktemp "${file}.XXXXXX")" || return 1
  MASTER_SPEC_BODY="$body" awk -v heading="$heading" '
    BEGIN {
      h = "^## " heading "[[:space:]]*$"
      replaced = 0
      skipping = 0
    }
    $0 ~ h && replaced == 0 {
      print
      print ""
      print ENVIRON["MASTER_SPEC_BODY"]
      print ""
      skipping = 1
      replaced = 1
      next
    }
    skipping && (/^## / || /^---[[:space:]]*$/ || /^<!-- master-spec:phase id=/) {
      skipping = 0
      print
      next
    }
    skipping { next }
    { print }
    END { if (replaced != 1) exit 42 }
  ' "$file" > "$tmp"
  local rc=$?
  if [[ "$rc" != "0" ]]; then
    rm -f "$tmp"
    sf_log_error "_sf_master_spec_replace_section_body: could not update MASTER-SPEC '## $heading' section"
    return 1
  fi
  mv "$tmp" "$file"
}


# Onboarding synthesis path: the synthesis agent emits EXECUTIVE-SUMMARY.md
# first, then this helper copies that synthesized body back into MASTER-SPEC's
# pinned "## Executive Summary" section before rendering the canonical summary
# file with a checksum from the updated source.
sf_render_executive_summary_from_synthesized() {
  local master="$1" out="$2" project_name="$3" project_class="$4"
  [[ -f "$master" ]] || { sf_log_error "sf_render_executive_summary_from_synthesized: MASTER-SPEC not found: $master"; return 1; }
  [[ -f "$out" ]] || { sf_log_error "sf_render_executive_summary_from_synthesized: EXECUTIVE-SUMMARY not found: $out"; return 1; }

  # Guard against silent truncation BEFORE extraction. sf_master_spec_section stops at
  # the next `## `/`---`/phase-marker, so an agent body carrying an INTERIOR delimiter
  # would be truncated to the text above it — slipping past the write-back guard, which
  # only ever sees the already-truncated body. Read the agent's `## Executive Summary`
  # region as the span from that H2 to the NEXT `## ` heading OR EOF (deliberately NOT
  # stopping at `---`/phase-marker — we WANT to see those here), then drop a single
  # TRAILING horizontal rule (the conventional section-ending `---` is fine; only an
  # INTERIOR delimiter is corruption). If any delimiter remains, reject loudly.
  # Capture from the agent's single `## Executive Summary` H2 to EOF (the agent doc has
  # exactly one intended H2; any `## ` AFTER it is an interior heading the agent emitted,
  # which is exactly what we must catch — so do NOT stop at the next `## `).
  local raw_region
  raw_region="$(awk '
    BEGIN { h = "^## Executive Summary[[:space:]]*$" }
    $0 ~ h && !grab { grab=1; next }
    grab { print }
  ' "$out")"
  # Trim a single trailing rule (+ trailing blanks) so a body that merely ENDS with `---`
  # still succeeds; only non-trailing delimiters are the corruption case.
  raw_region="$(printf '%s\n' "$raw_region" | awk '
    { a[NR]=$0 }
    END {
      n=NR
      while (n>0 && (a[n] ~ /^[[:space:]]*$/ || a[n] ~ /^[[:space:]]*(-{3,}|\*{3,}|_{3,})[[:space:]]*$/)) n--
      for (i=1;i<=n;i++) print a[i]
    }')"
  if printf '%s\n' "$raw_region" | grep -qE '^[[:space:]]*##[[:space:]]'; then
    sf_log_error "sf_render_executive_summary_from_synthesized: the synthesized '## Executive Summary' body contains an interior section heading (## ...) — extracting it would silently TRUNCATE the summary. Re-run the synthesis agent and have it emit a prose/bullets-only Executive Summary (no nested ## headings)."
    return 1
  fi
  if printf '%s\n' "$raw_region" | grep -qE '^[[:space:]]*(-{3,}|\*{3,}|_{3,})[[:space:]]*$'; then
    sf_log_error "sf_render_executive_summary_from_synthesized: the synthesized '## Executive Summary' body contains an interior horizontal rule (--- / *** / ___) — extracting it would silently TRUNCATE the summary. Re-run the synthesis agent and have it emit a prose/bullets-only Executive Summary (no interior rules)."
    return 1
  fi
  if printf '%s\n' "$raw_region" | grep -qE '^<!-- master-spec:phase'; then
    sf_log_error "sf_render_executive_summary_from_synthesized: the synthesized '## Executive Summary' body contains a master-spec phase marker — extracting it would silently TRUNCATE the summary. Re-run the synthesis agent and have it emit a prose/bullets-only Executive Summary."
    return 1
  fi

  local body
  body="$(sf_master_spec_section "$out" "Executive Summary")"
  body="$(printf '%s\n' "$body" | sed -e '/./,$!d' | awk '
    { a[NR]=$0 }
    END {
      n=NR
      while (n>0 && (a[n] ~ /^[[:space:]]*$/ || a[n] ~ /^[[:space:]]*(-{3,}|\*{3,}|_{3,})[[:space:]]*$/)) n--
      for (i=1;i<=n;i++) print a[i]
    }')"
  if [[ -z "${body// /}" ]]; then
    # The agent emits a `## Executive Summary` H2 body; the rendered canonical file
    # instead carries the template's `# <name> — Executive Summary` H1 shape. If we
    # find that H1 (and no H2 body), this helper was re-invoked against an already-
    # rendered file without a fresh agent write — call that out specifically.
    if grep -qE '^# .* — Executive Summary[[:space:]]*$' "$out"; then
      sf_log_error "sf_render_executive_summary_from_synthesized: \$out already holds a rendered EXECUTIVE-SUMMARY (H1 shape) with no '## Executive Summary' H2 body — re-run the synthesis agent so it writes a fresh '## Executive Summary' section before calling this helper."
    else
      sf_log_error "sf_render_executive_summary_from_synthesized: synthesized EXECUTIVE-SUMMARY has no non-empty '## Executive Summary' body"
    fi
    return 1
  fi
  if printf '%s\n' "$body" | grep -qiE '^[[:space:]]*(TODO:[[:space:]]*)?(\{\{)?executive_summary(\}\})?[[:space:]]*$'; then
    sf_log_error "sf_render_executive_summary_from_synthesized: synthesized EXECUTIVE-SUMMARY is still a placeholder"
    return 1
  fi

  _sf_master_spec_replace_section_body "$master" "Executive Summary" "$body" || return 1
  _sf_render_executive_summary_body "$master" "$out" "$project_name" "$project_class" "$body"
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
