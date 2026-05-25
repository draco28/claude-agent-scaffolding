#!/usr/bin/env bash
# scaffold-dev/lib/state.sh
# Active-context cursor CRUD against 05-active-context.md in the memory bank.
#
# The cursor lives between HTML sentinels:
#   <!-- sd:cursor:start -->
#   ```json
#   {"sprint":"3","slice":"VS-3.2","work_item":"2.04"}
#   ```
#   <!-- sd:cursor:end -->
#
# Writes are atomic (jq-builds-JSON then awk-rewrites then mv). Reads pull the
# JSON block out via awk and emit a single JSON object to stdout.

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi
if ! declare -F sd_manifest_get >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/manifest.sh"
fi

# Locate the active-context file. Memory-bank dir comes from manifest's
# well_known_paths.memory_bank (resolved) when present, falling back to
# <ai_workspace.root>/.claude/memory-bank.
sd_state_active_context_path() {
  local manifest
  if ! manifest="$(sd_manifest_discover)"; then
    return 1
  fi
  local mb_raw mb
  mb_raw="$(sd_jq_get "$manifest" '.well_known_paths.memory_bank')"
  if [[ -n "$mb_raw" ]]; then
    local ai_root
    ai_root="$(sd_jq_get "$manifest" '.ai_workspace.root')"
    mb="$(sd_manifest_resolve "$ai_root" "$mb_raw")"
  else
    local ai_root
    ai_root="$(sd_jq_get "$manifest" '.ai_workspace.root')"
    mb="$ai_root/.claude/memory-bank"
  fi
  echo "$mb/05-active-context.md"
}

# sd_state_read_cursor — emit the cursor JSON object to stdout.
# Returns 1 if the active-context file or the JSON block is absent.
sd_state_read_cursor() {
  local path
  if ! path="$(sd_state_active_context_path)"; then
    sd_log_error "sd_state_read_cursor: no manifest"
    return 1
  fi
  if [[ ! -f "$path" ]]; then
    sd_log_error "sd_state_read_cursor: $path not found"
    return 1
  fi
  # Extract the JSON between sd:cursor:start ... sd:cursor:end (strip fence).
  local json
  json="$(awk '
    /<!-- sd:cursor:start -->/ { in_block = 1; next }
    /<!-- sd:cursor:end -->/   { in_block = 0; next }
    in_block == 1 {
      if ($0 ~ /^[[:space:]]*```/) next
      print
    }
  ' "$path")"
  # Trim leading/trailing blank lines.
  json="$(echo "$json" | awk 'NF { found = 1 } found { print }')"
  if [[ -z "$json" ]]; then
    sd_log_error "sd_state_read_cursor: cursor block not found in $path"
    return 1
  fi
  echo "$json" | jq -c '.'
}

# sd_state_write_cursor <sprint> <slice> <work_item>
# Atomically updates the cursor block. Creates the file with a stub heading
# when absent.
sd_state_write_cursor() {
  local sprint="$1" slice="$2" work_item="$3"
  local path
  if ! path="$(sd_state_active_context_path)"; then
    sd_log_error "sd_state_write_cursor: no manifest"
    return 1
  fi
  mkdir -p "$(dirname "$path")"

  local cursor_json
  cursor_json="$(jq -nc \
    --arg s "$sprint" --arg sl "$slice" --arg w "$work_item" \
    '{sprint: $s, slice: $sl, work_item: $w}')"

  local tmp="${path}.tmp.$$"
  if [[ ! -f "$path" ]]; then
    # Create from scratch.
    cat > "$tmp" <<EOF
# Active context

<!-- sd:cursor:start -->
\`\`\`json
${cursor_json}
\`\`\`
<!-- sd:cursor:end -->
EOF
  else
    # Rewrite existing file: replace the body between sentinels.
    awk -v repl="${cursor_json}" '
      BEGIN { state = 0 }
      /<!-- sd:cursor:start -->/ {
        print
        print "```json"
        print repl
        print "```"
        state = 1
        next
      }
      /<!-- sd:cursor:end -->/ {
        if (state == 1) { state = 2 }
        print
        next
      }
      state == 1 { next }
      { print }
    ' "$path" > "$tmp"
    # If no start sentinel found, append a fresh block.
    if ! grep -q '<!-- sd:cursor:start -->' "$tmp"; then
      cat >> "$tmp" <<EOF

<!-- sd:cursor:start -->
\`\`\`json
${cursor_json}
\`\`\`
<!-- sd:cursor:end -->
EOF
    fi
  fi

  mv "$tmp" "$path" || { rm -f "$tmp"; return 1; }
  return 0
}

sd_state_active_sprint()    { sd_state_read_cursor | jq -r .sprint; }
sd_state_active_slice()     { sd_state_read_cursor | jq -r .slice; }
sd_state_active_work_item() { sd_state_read_cursor | jq -r .work_item; }
