#!/usr/bin/env bash
# lib/helpers.sh — cross-platform primitives for claude-security-audit.
# Bash 3.2+ compatible (macOS portability).

# csa_sha256 <string> — print the SHA-256 hex digest of the given string.
csa_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  else
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  fi
}

# csa_realpath <path> — resolve symlinks and .. traversal; print absolute path.
csa_realpath() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1" 2>/dev/null && return 0
  fi
  local target="$1"
  if [[ -d "$target" ]]; then
    (cd "$target" 2>/dev/null && pwd)
  elif [[ -f "$target" ]]; then
    local dir; dir="$(dirname "$target")"
    local base; base="$(basename "$target")"
    (cd "$dir" 2>/dev/null && printf '%s/%s\n' "$(pwd)" "$base")
  else
    printf '%s\n' "$target"
  fi
}

# csa_sed_inplace <sed_expr> <file> — portable in-place sed (GNU + BSD).
csa_sed_inplace() {
  local expr="$1"; local file="$2"
  if sed --version >/dev/null 2>&1; then
    sed -i "$expr" "$file"
  else
    sed -i '' "$expr" "$file"
  fi
}

# csa_mkdir_lock <lock_dir_path> <label> — atomic lock acquisition via mkdir.
# Returns 0 on first acquire, 1 if already locked.
csa_mkdir_lock() {
  local lock_dir="$1"; local label="$2"
  if mkdir "$lock_dir" 2>/dev/null; then
    {
      printf 'pid=%d\n' "$$"
      printf 'host=%s\n' "$(hostname 2>/dev/null || echo unknown)"
      printf 'iso=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      printf 'label=%s\n' "$label"
    } > "$lock_dir/info"
    return 0
  fi
  return 1
}
