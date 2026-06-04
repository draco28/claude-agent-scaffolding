#!/usr/bin/env bash
# scaffold-onboard/lib/memory-bank.sh
# Memory-bank derivation: 8 derived files (00-04,07,08,index) + 4 live (05,06,09,10 — seeded once)
# + 1 static (WORKFLOW.md) + 1 seeded index (tech-debt.md). 03 keeps a preserved rules zone (SS-1 W2).

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

# Echo the legacy heading-only machine-checkable-rules section from $1.
# This is the pre-SS-1 upgrade fallback: old projects can have authored mcrule
# blocks under the heading but no preserve sentinels yet.
_sf_mb_extract_legacy_rules_zone() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  awk '
    /^## Machine-checkable rules[[:space:]]*$/ { cap=1 }
    cap && /^## / && !/^## Machine-checkable rules[[:space:]]*$/ { exit }
    cap { print }
  ' "$file"
}

# Echo the preserved rules zone (start..end sentinels inclusive) from $1.
# If the sentinels are absent but a legacy heading-only section exists, wrap that
# legacy section in the new sentinels so authored rules survive first upgrade.
# Empty output if the file and legacy section are absent.
_sf_mb_extract_preserve_zone() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  local saved
  saved="$(awk '
    /<!-- mcrules:preserve:start -->/ { cap=1 }
    cap { print }
    /<!-- mcrules:preserve:end -->/   { if (cap) exit }
  ' "$file")"
  if [[ -n "$saved" ]]; then
    printf '%s\n' "$saved"
    return 0
  fi

  local legacy
  legacy="$(_sf_mb_extract_legacy_rules_zone "$file")"
  if [[ -n "$legacy" ]]; then
    printf '%s\n' '<!-- mcrules:preserve:start -->'
    printf '%s\n' '<!-- This zone is PRESERVED across /scaffold-project re-derive. Everything else in'
    printf '%s\n' '     this file re-renders from MASTER-SPEC.md. Rules added here by'
    printf '%s\n' '     authoring-machine-checkable-rules survive regeneration. See'
    printf '%s\n' '     `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**. -->'
    printf '%s\n' "$legacy"
    printf '%s\n' '<!-- mcrules:preserve:end -->'
  fi
}

# Replace the freshly-rendered preserve zone in $1 with the saved zone text ($2).
# Returns non-zero (and leaves $1 untouched) if $1 has no preserve markers, so the
# caller can fall back. macOS-portable (no in-place sed -i).
#
# The saved zone is multi-line. Passing a multi-line value through awk -v is
# unreliable across awk variants (BSD awk in particular mangles embedded
# newlines), so we stage the saved zone in a temp FILE and have awk slurp it via
# getline — the only thing crossing the -v boundary is the single-line filename,
# which is always safe. This guarantees the zone round-trips byte-faithfully.
_sf_mb_reinject_preserve_zone() {
  local file="$1" saved="$2"
  grep -q '<!-- mcrules:preserve:start -->' "$file" || return 1
  grep -q '<!-- mcrules:preserve:end -->'   "$file" || return 1
  local tmp savedfile
  tmp="$(mktemp)"
  savedfile="$(mktemp)"
  printf '%s\n' "$saved" > "$savedfile"
  awk -v sf="$savedfile" '
    /<!-- mcrules:preserve:start -->/ {
      while ((getline line < sf) > 0) print line
      close(sf)
      skip=1; next
    }
    /<!-- mcrules:preserve:end -->/   { if (skip) { skip=0; next } }
    skip { next }
    { print }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
  local rc=$?
  # Clean both temp files. On the success path `mv` already moved $tmp away, so
  # `rm -f` is a harmless no-op; on the awk-failure path it reclaims the orphan.
  rm -f "$savedfile" "$tmp"
  return $rc
}

# One-time migration (SS-1 W7): relocate provenance-trailed harvest content
# (a "- <text>" bullet immediately followed by a "<!-- Added from VS… -->" trailer)
# out of spec-derived files into 09-known-issues.md, BEFORE those files are
# re-rendered. Never silent-drop: every relocated pair is appended to 09 and a
# summary is logged. Idempotent: once relocated, nothing matches on the next run.
# For 03, content inside the mcrules preserve zone is skipped (never migrated).
_sf_mb_migrate_harvested() {
  local mb=".claude/memory-bank"
  local known="$mb/09-known-issues.md"
  local moved=0 src
  for src in \
    "$mb/00-project-brief.md" \
    "$mb/01-product-context.md" \
    "$mb/02-system-patterns.md" \
    "$mb/03-code-patterns.md" \
    "$mb/04-tech-context.md" \
    "$mb/07-constraints.md" \
    "$mb/08-governance.md" \
    "$mb/index.md"; do
    [[ -f "$src" ]] || continue
    local relocated kept
    relocated="$(mktemp)"; kept="$(mktemp)"
    : > "$relocated"; : > "$kept"
    local prev="" have_prev=0 inzone=0
    while IFS= read -r cur || [[ -n "$cur" ]]; do
      # Track the preserve zone; lines inside it are kept verbatim, never migrated.
      case "$cur" in
        *"<!-- mcrules:preserve:start -->"*) inzone=1 ;;
      esac
      if [[ "$inzone" -eq 1 ]]; then
        # flush any pending prev first (it was outside the zone)
        if [[ "$have_prev" -eq 1 ]]; then printf '%s\n' "$prev" >> "$kept"; have_prev=0; prev=""; fi
        printf '%s\n' "$cur" >> "$kept"
        case "$cur" in
          *"<!-- mcrules:preserve:end -->"*) inzone=0 ;;
        esac
        continue
      fi
      # Outside the zone: detect a bullet (prev) followed by an "Added from VS" trailer (cur).
      if [[ "$cur" == *"<!-- Added from VS"* && "$have_prev" -eq 1 && "$prev" == -* ]]; then
        printf '%s\n%s\n' "$prev" "$cur" >> "$relocated"
        have_prev=0; prev=""
        continue
      fi
      if [[ "$have_prev" -eq 1 ]]; then printf '%s\n' "$prev" >> "$kept"; fi
      prev="$cur"; have_prev=1
    done < "$src"
    [[ "$have_prev" -eq 1 ]] && printf '%s\n' "$prev" >> "$kept"

    if [[ -s "$relocated" ]]; then
      # If 09 doesn't exist yet (legacy bank being upgraded), seed it from its
      # template FIRST so it keeps the proper header/sections/cadence pointer — the
      # later live-seed loop will then preserve it (seed-if-missing). Falling back to
      # a bare header would permanently strip the template on exactly the upgrade path.
      if [[ ! -f "$known" ]]; then
        local _ki_tmpl; _ki_tmpl="$(sf_plugin_root)/templates/memory-bank/09-known-issues.md.tmpl"
        if [[ -f "$_ki_tmpl" ]]; then sf_render "$_ki_tmpl" > "$known"; else printf '# Known Issues\n' > "$known"; fi
      fi
      {
        echo ""
        echo "## Migrated from $(basename "$src") (SS-1)"
        cat "$relocated"
      } >> "$known"
      _SF_MB_MIGRATED_TO_KNOWN_ISSUES=1
      mv "$kept" "$src"
      local c; c="$(grep -c '<!-- Added from VS' "$relocated")"
      moved=$((moved + c))
      if [[ "$c" -eq 1 ]]; then
        sf_log_warn "migrated 1 harvested entry from $(basename "$src") → 09-known-issues.md (SS-1 W7)"
      else
        sf_log_warn "migrated $c harvested entries from $(basename "$src") → 09-known-issues.md (SS-1 W7)"
      fi
    fi
    rm -f "$relocated" "$kept"
  done
  [[ "$moved" -gt 0 ]] && sf_log_info "SS-1 migration: relocated $moved harvested entries into 09-known-issues.md"
  return 0
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

  # SS-1 W7: one-time relocate of provenance-trailed harvest content out of derived
  # files before they are regenerated. No-op on fresh projects.
  _SF_MB_MIGRATED_TO_KNOWN_ISSUES=0
  _sf_mb_migrate_harvested

  # Collect args once
  local args=()
  while IFS= read -r line; do args+=("$line"); done < <(_memory_bank_args "$ts")

  # 8 derived files. 03-code-patterns keeps a preserved rules zone (SS-1 W2):
  # capture the existing zone, re-render, re-inject.
  local f
  for f in 00-project-brief 01-product-context 02-system-patterns 03-code-patterns 04-tech-context 07-constraints 08-governance index; do
    local out=".claude/memory-bank/${f}.md"
    if [[ "$f" == "03-code-patterns" ]]; then
      local saved_zone
      saved_zone="$(_sf_mb_extract_preserve_zone "$out")"
      sf_render "$tmpl_dir/${f}.md.tmpl" "${args[@]}" > "$out"
      if [[ -n "$saved_zone" ]]; then
        _sf_mb_reinject_preserve_zone "$out" "$saved_zone" \
          || sf_log_warn "03-code-patterns: could not re-inject preserved rules zone"
      fi
    else
      sf_render "$tmpl_dir/${f}.md.tmpl" "${args[@]}" > "$out"
    fi
  done

  # 4 live files — seed only if missing (unless --force)
  for f in 05-active-context 06-progress 09-known-issues 10-decisions-log; do
    local target=".claude/memory-bank/${f}.md"
    if [[ "$f" == "09-known-issues" && "$force" -eq 1 && "${_SF_MB_MIGRATED_TO_KNOWN_ISSUES:-0}" -eq 1 ]]; then
      sf_log_info "preserved live file with newly migrated content: $target"
      continue
    fi
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

  # 1 seeded index — seed header only if missing; scaffold-dev's /defer command
  # and round-close auto-file sweep append [TD] entries into it over time (#33).
  local td_target=".claude/memory-bank/tech-debt.md"
  if [[ ! -f "$td_target" ]]; then
    sf_render "$tmpl_dir/tech-debt.md.tmpl" "${args[@]}" > "$td_target"
  else
    sf_log_info "preserved seeded index: $td_target"
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
