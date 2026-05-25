#!/usr/bin/env bash
# scaffold-dev/lib/render.sh
# Minimal {{key}} template substitution. Vars supplied as JSON object.
# Missing keys warn to stderr; placeholder is left in place. Nested expansion
# is NOT performed (values containing {{...}} pass through literally).

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi

# sd_render_template <tmpl-path> <vars-json>
# Echoes rendered content (no extra trailing newline beyond what was in tmpl).
sd_render_template() {
  local tmpl="$1" vars_json="$2"

  if [[ ! -f "$tmpl" ]]; then
    sd_log_error "sd_render_template: template not found: $tmpl"
    return 1
  fi

  local content
  content="$(cat "$tmpl")"

  # Two-pass substitution to prevent nested {{...}} re-expansion: pass 1
  # replaces placeholders with a sentinel keyed by index; pass 2 converts
  # sentinels back to literal values.
  local -a sentinels=()
  local -a values=()
  local idx=0
  while IFS=$'\t' read -r key value; do
    [[ -z "$key" ]] && continue
    local sentinel
    sentinel=$'\x01'"SD_RENDER_${idx}_"$'\x02'
    content="${content//\{\{${key}\}\}/${sentinel}}"
    sentinels+=("$sentinel")
    values+=("$value")
    idx=$((idx+1))
  done < <(echo "$vars_json" | jq -r 'to_entries[] | "\(.key)\t\(.value)"' 2>/dev/null)

  local i
  for (( i = 0; i < idx; i++ )); do
    content="${content//${sentinels[$i]}/${values[$i]}}"
  done

  # Step 2: warn for any remaining placeholders.
  local missing
  missing="$(echo "$content" | grep -oE '\{\{[a-zA-Z0-9_.-]+\}\}' | sort -u)"
  if [[ -n "$missing" ]]; then
    local m
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      local k="${m#\{\{}"; k="${k%\}\}}"
      sd_log_warn "sd_render_template: unresolved placeholder for key '$k'"
    done <<<"$missing"
  fi

  printf '%s' "$content"
  # Preserve a trailing newline if the original template ended with one.
  if [[ -n "$(tail -c1 "$tmpl")" ]]; then
    : # no trailing newline in original — omit
  else
    echo ""
  fi
}
