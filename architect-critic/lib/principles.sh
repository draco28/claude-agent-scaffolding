#!/usr/bin/env bash
# lib/principles.sh — principles.md load + comment-strip + 4-source merge (Phase B, Task TB.2)
# macOS bash 3.2 portable; BSD awk sub() chains (Adaptation 1); no declare -A.

# Returns the absolute path to principles.md in the data dir.
ac_principles_path() {
  echo "$(ac_data_dir)/principles.md"
}

# Seed principles.md from the plugin template if it does not already exist.
# Reads CLAUDE_PLUGIN_ROOT to locate templates/principles.md.
ac_principles_seed() {
  local dest
  dest="$(ac_principles_path)"
  if [[ -f "$dest" ]]; then
    return 0
  fi
  local template="${CLAUDE_PLUGIN_ROOT:-}/templates/principles.md"
  if [[ ! -f "$template" ]]; then
    ac_log_warn "principles.md template not found at $template — creating empty file"
    mkdir -p "$(dirname "$dest")"
    touch "$dest"
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp "$template" "$dest"
}

# Load user-global principles from principles.md.
# - Strips lines starting with "# " (both headers AND inline comments per §6.4).
# - Strips trailing "[promoted YYYY-MM-DD source:......]" annotations.
# - Emits one active principle per line (blank lines omitted).
# Uses BSD awk sub() chains (Adaptation 1 — no gawk 3-arg match()).
ac_principles_load_user_global() {
  local pfile
  pfile="$(ac_principles_path)"
  if [[ ! -f "$pfile" ]]; then
    return 0
  fi
  awk '
    /^# / { next }              # skip header / comment lines (§6.4 rule 1+2)
    /^[[:space:]]*$/ { next }   # skip blank lines
    {
      line = $0
      # Strip trailing [promoted ...] annotation (Adaptation 1: sub() chain)
      sub(/[[:space:]]*\[promoted[^]]*\][[:space:]]*$/, "", line)
      # Trim leading/trailing whitespace
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (length(line) > 0) print line
    }
  ' "$pfile"
}

# Load content of named phases from a master-spec file.
# Args: <spec_path> <phase_ids_csv>
# Phase markers: <!-- master-spec:phase id=N name=<slug> -->
# Extracts content from the marker line up to (but not including) the next marker or EOF.
# Uses BSD awk sub() chains to parse phase id (Adaptation 1).
# Gracefully returns empty if spec_path does not exist.
ac_principles_load_master_spec_phases() {
  local spec_path="$1"
  local phase_ids_csv="$2"
  if [[ ! -f "$spec_path" ]]; then
    return 0
  fi
  # Build a pattern string for awk to check membership in phase_ids_csv.
  # We pass the csv as a string and split it inside awk.
  awk -v ids="$phase_ids_csv" '
    BEGIN {
      n = split(ids, wanted, ",")
      for (i = 1; i <= n; i++) wanted_set[wanted[i]] = 1
      in_wanted = 0
    }
    /<!-- master-spec:phase / {
      # Extract the phase id using sub() chains (Adaptation 1)
      line = $0
      sub(/^.*id=/, "", line)
      sub(/[^0-9].*$/, "", line)
      pid = line
      if (pid in wanted_set) {
        in_wanted = 1
      } else {
        in_wanted = 0
      }
      # Print the marker line itself as part of the phase block
      if (in_wanted) print $0
      next
    }
    in_wanted { print }
  ' "$spec_path"
}

# Load content of .claude/memory-bank/03-code-patterns.md if it exists.
# Gracefully returns empty if absent.
ac_principles_load_memory_bank_patterns() {
  local pfile=".claude/memory-bank/03-code-patterns.md"
  if [[ -f "$pfile" ]]; then
    cat "$pfile"
  fi
}

# Load content of .claude/memory-bank/08-governance.md if it exists.
# Gracefully returns empty if absent.
ac_principles_load_memory_bank_governance() {
  local gfile=".claude/memory-bank/08-governance.md"
  if [[ -f "$gfile" ]]; then
    cat "$gfile"
  fi
}

# Compose the full principles block from all 4 sources with section headers.
# Args: <spec_path> <phase_ids_csv>
# Per SPEC §7 composition pseudo-code:
#   - Omit each section entirely if its source is absent/empty.
# Output goes to stdout.
ac_principles_compose() {
  local spec_path="$1"
  local phase_ids_csv="$2"

  # Source 1: user-global principles
  local user_principles
  user_principles="$(ac_principles_load_user_global)"
  if [[ -n "$user_principles" ]]; then
    printf '%s\n' "# User-global principles"
    printf '%s\n' "$user_principles"
    printf '\n'
  fi

  # Source 2: master-spec accumulated phases
  local phase_content
  phase_content="$(ac_principles_load_master_spec_phases "$spec_path" "$phase_ids_csv")"
  if [[ -n "$phase_content" ]]; then
    printf '%s\n' "# Project context (MASTER-SPEC accumulated phases $phase_ids_csv)"
    printf '%s\n' "$phase_content"
    printf '\n'
  fi

  # Source 3: project patterns
  local patterns
  patterns="$(ac_principles_load_memory_bank_patterns)"
  if [[ -n "$patterns" ]]; then
    printf '%s\n' "# Project patterns"
    printf '%s\n' "$patterns"
    printf '\n'
  fi

  # Source 4: project governance
  local governance
  governance="$(ac_principles_load_memory_bank_governance)"
  if [[ -n "$governance" ]]; then
    printf '%s\n' "# Project governance"
    printf '%s\n' "$governance"
    printf '\n'
  fi
}
