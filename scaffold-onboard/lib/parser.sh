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

# Print the content of phase N (markdown between marker N and marker N+1, or EOF).
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
