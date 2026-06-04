#!/usr/bin/env bash
# scaffold-dev/lib/harvest.sh
# Slice-close memory-bank harvest:
#   - sd_harvest_reports <slice_dir> — sweep every work-N.NN-*/report.md and
#     extract "## Suggestions for memory bank" entries. Emits JSON array.
#   - sd_harvest_handoffs <slice_id> — sweep <ai_workspace>/.workspace/handoffs/
#     for files prefixed by the slice id, extract section "## 4. What's NOT in
#     memory bank yet". Emits JSON array.
#   - sd_harvest_apply <items-json> <slice-id> — write each item to its named
#     memory-bank file with a provenance trailer.

set -u

# Spec-derived memory-bank basenames — harvest must NEVER append prose into these
# (SS-1 W4 / #45). Per the cadence policy (memory-bank/WORKFLOW.md), harvested prose
# routes to dev-authored files. 03-code-patterns is mixed: its derived body is off
# limits to raw harvest; enforceable patterns go through authoring-machine-checkable-rules.
_SD_HARVEST_DERIVED_FILES="00-project-brief.md 01-product-context.md 02-system-patterns.md 03-code-patterns.md 04-tech-context.md 07-constraints.md 08-governance.md index.md"

_sd_harvest_is_derived() {
  local f="$1" d
  for d in $_SD_HARVEST_DERIVED_FILES; do
    [[ "$f" == "$d" ]] && return 0
  done
  return 1
}

# Locate scaffold-onboard's canonical template for a memory-bank basename
# (e.g. "09-known-issues.md.tmpl"). Tries the sibling repo layout and the
# versioned plugin-cache layout. Returns 1 if not found.
_sd_harvest_onboard_template() {
  local name="$1" candidate
  for candidate in \
    "$_SD_LIB_DIR/../../scaffold-onboard/templates/memory-bank/$name" \
    "$_SD_LIB_DIR/../../../scaffold-onboard"/*/templates/memory-bank/"$name"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

# Seed a missing dev-authored live file (09-known-issues.md / 10-decisions-log.md)
# from scaffold-onboard's canonical template (single source). When that template
# can't be located (exotic cross-plugin install layout), fall back to a
# STRUCTURALLY-VALID minimal file (title + cadence pointer + a section), NOT a bare
# header — so a later /scaffold-project that preserves this live file still has the
# contract shape and the bare-header-clobber bug cannot re-surface.
_sd_harvest_seed_live_file() {
  local file="$1" base="$2"   # base e.g. "09-known-issues.md"
  [[ -f "$file" ]] && return 0
  mkdir -p "$(dirname "$file")"
  local tmpl
  if tmpl="$(_sd_harvest_onboard_template "${base}.tmpl")"; then
    cp "$tmpl" "$file"
    return 0
  fi
  local title section
  case "$base" in
    09-known-issues.md)  title="Known Issues" ; section="## Caveats & gotchas" ;;
    10-decisions-log.md) title="Decisions Log" ; section="## Decisions" ;;
    *)                   title="${base%.md}" ; section="## Notes" ;;
  esac
  {
    printf '# %s\n\n' "$title"
    printf '> Live file — dev-authored, never auto-regenerated. Update cadence: see\n'
    printf '> `memory-bank/WORKFLOW.md` → **Memory-bank update cadence**.\n\n'
    printf '%s\n*(none yet)*\n' "$section"
  } > "$file"
  return 0
}

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi
if ! declare -F sd_manifest_get >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/manifest.sh"
fi

# _sd_harvest_extract_section <file> <heading-pattern>
# Echo all lines under a Markdown heading matching <heading-pattern> until the
# next heading at the same or shallower level (or EOF).
_sd_harvest_extract_section() {
  local file="$1" heading_pat="$2"
  awk -v pat="$heading_pat" '
    BEGIN { in_sec = 0; depth = 0 }
    /^#+ / {
      # Compute heading depth.
      d = 0
      for (i = 1; i <= length($0); i++) {
        if (substr($0, i, 1) == "#") d++; else break
      }
      if (in_sec == 1 && d <= depth) { in_sec = 0 }
      if ($0 ~ pat) { in_sec = 1; depth = d; next }
    }
    in_sec == 1 { print }
  ' "$file"
}

# sd_harvest_reports <slice_dir>
sd_harvest_reports() {
  local slice_dir="$1"
  if [[ ! -d "$slice_dir" ]]; then
    echo "[]"
    return 0
  fi
  # Walk every work-*/report.md.
  local acc=""
  local report
  for report in "$slice_dir"/work-*/report.md; do
    [[ -f "$report" ]] || continue
    # Extract work-item id from path: work-<id>-<kebab>/report.md
    local parent
    parent="$(basename "$(dirname "$report")")"
    # parent looks like "work-1.01-foo"
    local work_id
    work_id="$(echo "$parent" | sed -nE 's/^work-([0-9.]+)-.*$/\1/p')"
    if [[ -z "$work_id" ]]; then
      work_id="$(echo "$parent" | sed -nE 's/^work-([0-9.]+).*$/\1/p')"
    fi

    # Extract the section body.
    local body
    body="$(_sd_harvest_extract_section "$report" '^## +Suggestions for memory bank')"
    [[ -z "$body" ]] && continue

    # Parse each "- target_file: X\n  suggestion: Y" pair via awk into JSON objects.
    local items_json
    items_json="$(echo "$body" | awk -v w="$work_id" '
      BEGIN { tf = ""; sg = "" }
      /^- *target_file:/ {
        if (tf != "" && sg != "") {
          gsub(/"/, "\\\"", tf); gsub(/"/, "\\\"", sg)
          printf "{\"source\":\"report\",\"work_item\":\"%s\",\"target_file\":\"%s\",\"suggestion\":\"%s\"}\n", w, tf, sg
        }
        line = $0
        sub(/^- *target_file: */, "", line)
        sub(/[[:space:]]+$/, "", line)
        tf = line
        sg = ""
        next
      }
      /^[[:space:]]+suggestion:/ {
        line = $0
        sub(/^[[:space:]]+suggestion: */, "", line)
        sub(/[[:space:]]+$/, "", line)
        sg = line
        next
      }
      END {
        if (tf != "" && sg != "") {
          gsub(/"/, "\\\"", tf); gsub(/"/, "\\\"", sg)
          printf "{\"source\":\"report\",\"work_item\":\"%s\",\"target_file\":\"%s\",\"suggestion\":\"%s\"}\n", w, tf, sg
        }
      }
    ')"

    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if [[ -z "$acc" ]]; then acc="$line"; else acc="${acc}"$'\n'"${line}"; fi
    done <<<"$items_json"
  done

  if [[ -z "$acc" ]]; then
    echo "[]"
  else
    printf '%s\n' "$acc" | jq -s '.'
  fi
}

# sd_harvest_handoffs <slice_id>
# Walks <ai_workspace>/.workspace/handoffs/<slice_id>-*.md and section-4 items.
sd_harvest_handoffs() {
  local slice_id="$1"
  local ai_root
  ai_root="$(sd_manifest_get '.ai_workspace.root')" || { echo "[]"; return 0; }
  local dir="$ai_root/.workspace/handoffs"
  [[ -d "$dir" ]] || { echo "[]"; return 0; }

  local acc=""
  local f
  for f in "$dir/${slice_id}"-*.md; do
    [[ -f "$f" ]] || continue
    local body
    body="$(_sd_harvest_extract_section "$f" "^## +4\\. +What's NOT in memory bank yet")"
    [[ -z "$body" ]] && continue
    local fname
    fname="$(basename "$f")"
    # Each "- item" line becomes a JSON object.
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      if [[ "$line" =~ ^-[[:space:]]+(.+)$ ]]; then
        local item="${BASH_REMATCH[1]}"
        local obj
        obj="$(jq -nc --arg s "handoff" --arg hf "$fname" --arg it "$item" \
          '{source: $s, handoff_file: $hf, item: $it}')"
        if [[ -z "$acc" ]]; then acc="$obj"; else acc="${acc}"$'\n'"${obj}"; fi
      fi
    done <<<"$body"
  done

  if [[ -z "$acc" ]]; then
    echo "[]"
  else
    printf '%s\n' "$acc" | jq -s '.'
  fi
}

# sd_harvest_apply <items-json> <slice-id>
# Appends each item.suggestion (or item.item) to the named target_file with
# a provenance trailer line. Skips items already present in the file
# (text-equality match).
sd_harvest_apply() {
  local items_json="$1" slice_id="$2"
  local ai_root mb
  ai_root="$(sd_manifest_get '.ai_workspace.root')" || { sd_log_error "sd_harvest_apply: no ai_workspace.root"; return 1; }
  mb="$ai_root/.claude/memory-bank"
  mkdir -p "$mb"

  local n
  n="$(echo "$items_json" | jq 'length')"
  [[ "$n" == "0" ]] && return 0

  local today
  today="$(date -u +%Y-%m-%d)"

  local i=0
  while (( i < n )); do
    local target source text
    target="$(echo "$items_json" | jq -r ".[$i].target_file // empty")"
    source="$(echo "$items_json" | jq -r ".[$i].source // empty")"
    text="$(echo "$items_json" | jq -r ".[$i].suggestion // .[$i].item // empty")"
    i=$((i+1))
    [[ -z "$text" ]] && continue
    if [[ -z "$target" ]]; then
      sd_log_warn "sd_harvest_apply: skipping item with no target_file: $text"
      continue
    fi

    # SS-1 W4: never append harvested prose into a spec-derived file — reroute to
    # the dev-authored catch-all (09-known-issues.md) and warn. Enforceable patterns
    # belong in 03's rules zone via authoring-machine-checkable-rules, not here.
    if _sd_harvest_is_derived "$target"; then
      sd_log_warn "sd_harvest_apply: '$target' is spec-derived — rerouting to 09-known-issues.md (cadence policy: memory-bank/WORKFLOW.md)"
      target="09-known-issues.md"
    fi

    local file="$mb/$target"
    case "$target" in
      09-known-issues.md|10-decisions-log.md)
        _sd_harvest_seed_live_file "$file" "$target" ;;
      *)
        [[ -f "$file" ]] || { mkdir -p "$(dirname "$file")"; echo "# $target" > "$file"; } ;;
    esac

    # Idempotency: skip if line text already present.
    if grep -Fq "$text" "$file"; then
      continue
    fi

    {
      echo ""
      echo "- $text"
      echo "<!-- Added from $slice_id retrospective, $today; source: $source -->"
    } >> "$file"
  done
  return 0
}
