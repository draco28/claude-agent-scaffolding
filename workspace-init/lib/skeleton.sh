#!/usr/bin/env bash
# lib/skeleton.sh — directory skeleton creation + init-log entries.
# Per SPEC §8.1 (preflight validation), §8.2 (root dir creation),
# §8.3 (subdir seeding + .gitignore render).
#
# All filesystem operations append TAB-separated entries to
# <ai-root>/.workspace/init-log so Phase 3g rollback can replay them in reverse.
#
# Requires: lib/_helpers.sh (wi_log_*, wi_log_op).
# Bash 3.2+ compatible (stock macOS).

set -u

if ! declare -F wi_log_op >/dev/null 2>&1; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_helpers.sh"
fi

# Internal: derive the init-log path from the AI workspace root.
_wi_skeleton_log() {
  local ai_root="$1"
  echo "${ai_root}/.workspace/init-log"
}

# Internal: append a log entry only if no existing line has the exact
# `OP\tPATH` prefix. Keeps the init-log de-duplicated across idempotent reruns.
_wi_skeleton_log_once() {
  local log="$1"
  local op="$2"
  local target_path="$3"
  if [[ -f "$log" ]] && grep -qE "^${op}	$(printf '%s' "$target_path" | sed 's/[][\\/.^$*]/\\&/g')(	|\$)" "$log" 2>/dev/null; then
    return 0
  fi
  wi_log_op "$log" "$op" "$target_path"
}

# wi_skeleton_preflight <parent> <name> [--pair-with <existing-canonical>]
#
# Validates the inputs needed to start an init run, per SPEC §8.1:
#   - <name> matches ^[a-z0-9-]+$ (kebab-case)
#   - <parent> exists and is writable
#   - AI workspace target (<parent>/<name>-ai) does NOT already exist
#   - Fresh mode: canonical target (<parent>/<name>) must NOT exist
#   - Pair-with mode: --pair-with path must exist + be a git repo
#
# Returns 0 on success, non-zero on any failure (with error to stderr).
wi_skeleton_preflight() {
  local parent="$1"
  local name="$2"
  local pair_with=""
  shift 2
  while (( $# > 0 )); do
    case "$1" in
      --pair-with)
        pair_with="$2"
        shift 2
        ;;
      *)
        wi_log_error "wi_skeleton_preflight: unknown arg: $1"
        return 1
        ;;
    esac
  done

  # Name: kebab-case
  if ! [[ "$name" =~ ^[a-z0-9-]+$ ]]; then
    wi_log_error "wi_skeleton_preflight: invalid project name (must match ^[a-z0-9-]+\$): $name"
    return 1
  fi

  # Parent: exists + writable
  if [[ ! -d "$parent" ]]; then
    wi_log_error "wi_skeleton_preflight: parent dir does not exist: $parent"
    return 1
  fi
  if [[ ! -w "$parent" ]]; then
    wi_log_error "wi_skeleton_preflight: parent dir not writable: $parent"
    return 1
  fi

  local ai_root="${parent}/${name}-ai"
  local canonical_root="${parent}/${name}"

  if [[ -d "$ai_root" ]]; then
    wi_log_error "wi_skeleton_preflight: AI workspace target already exists: $ai_root"
    return 1
  fi

  if [[ -n "$pair_with" ]]; then
    if [[ ! -d "$pair_with" ]]; then
      wi_log_error "wi_skeleton_preflight: --pair-with path does not exist: $pair_with"
      return 1
    fi
    if [[ ! -d "$pair_with/.git" ]] && ! git -C "$pair_with" rev-parse --git-dir >/dev/null 2>&1; then
      wi_log_error "wi_skeleton_preflight: --pair-with path is not a git repo: $pair_with"
      return 1
    fi
  else
    if [[ -d "$canonical_root" ]]; then
      wi_log_error "wi_skeleton_preflight: canonical target already exists: $canonical_root"
      return 1
    fi
  fi

  return 0
}

# wi_skeleton_preflight_existing_dual <ai-root> <canonical-root>
#
# Scenario C preflight (issue #9): BOTH repos already exist and are populated —
# an AI workspace that grew its memory-bank/specs organically before the user
# discovered the plugins, alongside an existing canonical. Unlike
# wi_skeleton_preflight --pair-with (which requires the AI workspace to NOT exist
# yet and CREATES it), this validates that the AI workspace ALREADY exists and is
# non-empty, and the canonical exists + is a git repo. The AI workspace may or may
# not itself be a git repo (Scenario C only writes a manifest + installs hooks; it
# never seeds or stubs). Returns 0 on success, non-zero (error to stderr) on any
# failure. Performs NO mutation.
wi_skeleton_preflight_existing_dual() {
  local ai_root="${1:-}"
  local canonical_root="${2:-}"

  if [[ -z "$ai_root" || -z "$canonical_root" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: usage: <ai-root> <canonical-root>"
    return 1
  fi

  # AI workspace: exists, is a dir, and is non-empty (already populated).
  if [[ ! -d "$ai_root" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: AI workspace does not exist: $ai_root"
    return 1
  fi
  if [[ -z "$(ls -A "$ai_root" 2>/dev/null)" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: AI workspace is empty (Scenario C expects an already-populated workspace): $ai_root"
    return 1
  fi

  # Canonical: exists, is a dir, is a git repo.
  if [[ ! -d "$canonical_root" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: canonical does not exist: $canonical_root"
    return 1
  fi
  if [[ ! -d "$canonical_root/.git" ]] && ! git -C "$canonical_root" rev-parse --git-dir >/dev/null 2>&1; then
    wi_log_error "wi_skeleton_preflight_existing_dual: canonical is not a git repo: $canonical_root"
    return 1
  fi

  # Guard against accidental self-pairing.
  if [[ "$ai_root" == "$canonical_root" ]]; then
    wi_log_error "wi_skeleton_preflight_existing_dual: ai_root and canonical must be different paths: $ai_root"
    return 1
  fi

  return 0
}

# wi_skeleton_create_root_pair <parent> <name>
#
# Fresh-mode root creation (SPEC §8.2): mkdir both AI workspace and canonical.
# Also creates <ai>/.workspace so the init-log has a parent. Logs all three.
wi_skeleton_create_root_pair() {
  local parent="$1"
  local name="$2"
  local ai_root="${parent}/${name}-ai"
  local canonical_root="${parent}/${name}"

  if ! mkdir -p "$ai_root"; then
    wi_log_error "wi_skeleton_create_root_pair: mkdir failed: $ai_root"
    return 1
  fi
  if ! mkdir -p "$canonical_root"; then
    wi_log_error "wi_skeleton_create_root_pair: mkdir failed: $canonical_root"
    return 1
  fi
  if ! mkdir -p "${ai_root}/.workspace"; then
    wi_log_error "wi_skeleton_create_root_pair: mkdir failed: ${ai_root}/.workspace"
    return 1
  fi

  local log
  log="$(_wi_skeleton_log "$ai_root")"
  _wi_skeleton_log_once "$log" MKDIR "$ai_root"
  _wi_skeleton_log_once "$log" MKDIR "$canonical_root"
  _wi_skeleton_log_once "$log" MKDIR "${ai_root}/.workspace"
  return 0
}

# wi_skeleton_create_root_ai_only <parent> <name>
#
# Pair-with-mode root creation (SPEC §8.2): mkdir only AI workspace. The
# canonical already exists and must NOT be touched here.
wi_skeleton_create_root_ai_only() {
  local parent="$1"
  local name="$2"
  local ai_root="${parent}/${name}-ai"

  if ! mkdir -p "$ai_root"; then
    wi_log_error "wi_skeleton_create_root_ai_only: mkdir failed: $ai_root"
    return 1
  fi
  if ! mkdir -p "${ai_root}/.workspace"; then
    wi_log_error "wi_skeleton_create_root_ai_only: mkdir failed: ${ai_root}/.workspace"
    return 1
  fi

  local log
  log="$(_wi_skeleton_log "$ai_root")"
  _wi_skeleton_log_once "$log" MKDIR "$ai_root"
  _wi_skeleton_log_once "$log" MKDIR "${ai_root}/.workspace"
  return 0
}

# wi_skeleton_seed_subdirs <ai-root>
#
# SPEC §8.3: seed subdir skeleton + .gitkeep + .gitignore. Idempotent — second
# invocation on an already-seeded ai-root must not crash and must not append
# duplicate log entries (rollback replay relies on each path appearing once).
wi_skeleton_seed_subdirs() {
  local ai_root="$1"

  if [[ ! -d "$ai_root" ]]; then
    wi_log_error "wi_skeleton_seed_subdirs: ai_root does not exist: $ai_root"
    return 1
  fi

  local log
  log="$(_wi_skeleton_log "$ai_root")"

  local subdirs=(".workspace" ".claude" "docs" "docs/specs" ".superpowers" ".archive")
  local sd d gk
  for sd in "${subdirs[@]}"; do
    d="${ai_root}/${sd}"
    if ! mkdir -p "$d"; then
      wi_log_error "wi_skeleton_seed_subdirs: mkdir failed: $d"
      return 1
    fi
    _wi_skeleton_log_once "$log" MKDIR "$d"

    gk="${d}/.gitkeep"
    if [[ ! -f "$gk" ]]; then
      touch "$gk" || { wi_log_error "touch failed: $gk"; return 1; }
      _wi_skeleton_log_once "$log" WRITE_FILE "$gk"
    fi
  done

  # Render .gitignore from template (fallback to inline if template absent —
  # belt-and-braces so the plugin still works if someone deletes the template).
  local gi="${ai_root}/.gitignore"
  if [[ ! -f "$gi" ]]; then
    local tmpl="${WI_TEMPLATES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates}/gitignore.tmpl"
    if [[ -f "$tmpl" ]]; then
      if ! cp "$tmpl" "$gi"; then
        wi_log_error "wi_skeleton_seed_subdirs: cp failed: $tmpl -> $gi"
        return 1
      fi
    else
      cat > "$gi" <<'EOF'
# Onboarding session state (scaffold-onboard)
.claude/.onboarding-state.json

# Handoff escape valve files — per scaffold-dev §6b (durable per-machine; not synced)
.workspace/handoffs/

# OS-level cruft
.DS_Store
*.swp
EOF
    fi
    _wi_skeleton_log_once "$log" WRITE_FILE "$gi"
  fi

  return 0
}
