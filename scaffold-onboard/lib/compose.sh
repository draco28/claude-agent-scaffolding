#!/usr/bin/env bash
# scaffold-onboard/lib/compose.sh
# Cross-cutting plugin detection + composition.json caching.
# v0.2: architect-critic detection migrated to filesystem probe (per SPEC §12);
# legacy file-IPC functions (build_critic_request / read_critic_response) removed.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Return the list of paths to probe for installed plugins (ai-mentor, superpowers).
# Override via SF_COMPOSE_PROBE_PATHS env var (colon-separated).
sf_compose_probe_paths() {
  if [[ -n "${SF_COMPOSE_PROBE_PATHS:-}" ]]; then
    echo "$SF_COMPOSE_PROBE_PATHS" | tr ":" "\n"
  else
    # Default: standard Claude Code plugin dirs
    echo "$HOME/.claude/plugins/data"
    echo "$HOME/.claude/plugins/cache"
  fi
}

# Find a plugin by name prefix. Echo the first matching directory or empty.
_compose_find_plugin() {
  local prefix="$1"
  local dir
  while IFS= read -r dir; do
    [[ -d "$dir" ]] || continue
    local match
    match="$(find "$dir" -maxdepth 2 -type d -name "${prefix}*" 2>/dev/null | head -1)"
    if [[ -n "$match" ]]; then
      echo "$match"
      return 0
    fi
  done < <(sf_compose_probe_paths)
  echo ""
}

sf_compose_detect_ai_mentor() {
  _compose_find_plugin "ai-mentor"
}

sf_compose_detect_superpowers() {
  _compose_find_plugin "superpowers"
}

# Architect-critic v0.2+ detection via filesystem probe (per SPEC §12.2 + §12.4).
# Walks plugin cache dirs looking for the v0.2 entry skill `critiquing-spec/SKILL.md`.
# Detection is BINARY (no v0.1.3 fallback per 2026-05-24 drift-resolution pass —
# v0.1.3 shipped with zero skills/ directory, so Skill(architect-critic:critique)
# could never resolve against it; v0.2 is a hard breaking change per its SPEC §3 NG1).
#
# Echoes "v0.2" + returns 0 if v0.2 SKILL.md present.
# Echoes "absent" + returns 1 otherwise.
#
# Override cache dirs via SF_COMPOSE_AC_CACHE_DIRS env var (colon-separated)
# for fixture-based testing.
sf_compose_detect_architect_critic() {
  local cache_dirs
  if [[ -n "${SF_COMPOSE_AC_CACHE_DIRS:-}" ]]; then
    # Test-friendly override: colon-separated cache dirs.
    local IFS=":"
    # shellcheck disable=SC2206
    cache_dirs=( $SF_COMPOSE_AC_CACHE_DIRS )
  else
    cache_dirs=(
      "${HOME}/.claude/plugins/cache"
      "${CLAUDE_PLUGINS_DIR:-}"
    )
  fi
  local cache skill_md
  for cache in "${cache_dirs[@]}"; do
    [[ -z "$cache" || ! -d "$cache" ]] && continue
    # Glob: cache/<marketplace>/architect-critic/<version>/skills/critiquing-spec/SKILL.md
    for skill_md in "$cache"/*/architect-critic/*/skills/critiquing-spec/SKILL.md; do
      [[ -f "$skill_md" ]] && { echo "v0.2"; return 0; }
    done
  done
  echo "absent"
  return 1
}

# Resolve which architect-critic skill to invoke at critic moments.
# Echoes "critiquing-spec" + returns 0 when v0.2 detected.
# Echoes empty string + returns 1 when absent (binary contract — no v0.1.x fallback;
# v0.1.3 had no skills/ directory so Skill(...) could never resolve).
sf_compose_resolve_critic_skill() {
  local detected
  detected="$(sf_compose_detect_architect_critic)"
  if [[ "$detected" == "v0.2" ]]; then
    echo "critiquing-spec"
    return 0
  fi
  echo ""
  return 1
}

# Returns "true" if superpowers is installed AND its brainstorming skill is present
sf_compose_brainstorming_available() {
  local sp
  sp="$(sf_compose_detect_superpowers)"
  if [[ -n "$sp" && -f "$sp/skills/brainstorming/SKILL.md" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

sf_compose_path() {
  echo "$(sf_data_dir)/composition.json"
}

sf_compose_lock_path() {
  echo "$(sf_data_dir)/compose.lock"
}

# Acquire the compose lock with polling timeout (default 5 seconds).
sf_compose_lock_acquire() {
  local lock max_wait elapsed
  lock="$(sf_compose_lock_path)"
  mkdir -p "$(dirname "$lock")"
  max_wait="${1:-5}"
  elapsed=0
  while [[ "$elapsed" -lt "$max_wait" ]]; do
    set -C
    if echo "$$" > "$lock" 2>/dev/null; then
      set +C
      return 0
    fi
    set +C
    sleep 1
    elapsed=$((elapsed+1))
  done
  return 1
}

sf_compose_lock_release() {
  rm -f "$(sf_compose_lock_path)"
}

# Internal: does the actual refresh work without acquiring lock.
# Callers must hold the compose lock when calling this.
_sf_compose_refresh_locked() {
  local path tmp now
  path="$(sf_compose_path)"
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${path}.XXXXXX")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local mentor_dir superpowers_dir brainstorming
  mentor_dir="$(sf_compose_detect_ai_mentor)"
  superpowers_dir="$(sf_compose_detect_superpowers)"
  brainstorming="$(sf_compose_brainstorming_available)"

  # Preserve existing user_overrides if composition.json exists.
  # Note: architect-critic is NOT tracked here in v0.2 (per SPEC §12.2 +
  # ac v0.2 settlement #1); detection is filesystem-only via
  # `sf_compose_detect_architect_critic`. Pre-v0.2 composition.json files
  # carrying a `plugins.architect-critic` entry will have it dropped on next
  # refresh — this is expected behavior, documented in CHANGELOG.
  local overrides_json
  if [[ -f "$path" ]]; then
    overrides_json="$(jq '.user_overrides // {}' "$path")"
  else
    overrides_json='{"disable_mentor_suggestions":false,"disable_critic":false,"disable_superpowers_subskill":false}'
  fi

  if jq -n \
    --arg now "$now" \
    --arg mentor "$mentor_dir" \
    --arg sp "$superpowers_dir" \
    --arg br "$brainstorming" \
    --argjson overrides "$overrides_json" \
    '{
      schema_version: "1",
      detected_at: $now,
      plugins: {
        "ai-mentor": {
          installed: ($mentor != ""),
          data_dir: $mentor,
          state_file: (if $mentor != "" then ($mentor + "/state.json") else "" end)
        },
        "superpowers": {
          installed: ($sp != ""),
          skills_dir: (if $sp != "" then ($sp + "/skills") else "" end),
          brainstorming_available: ($br == "true")
        }
      },
      user_overrides: ($overrides | . + {
        disable_mentor_suggestions: (.disable_mentor_suggestions // false),
        disable_critic: (.disable_critic // false),
        disable_superpowers_subskill: (.disable_superpowers_subskill // false)
      })
    }' > "$tmp"; then
    mv "$tmp" "$path"
  else
    rm -f "$tmp"
    sf_log_error "jq failed during compose refresh"
    return 1
  fi
}

# Public wrapper: acquire lock, refresh, release.
sf_compose_refresh() {
  sf_compose_lock_acquire || { sf_log_error "could not acquire compose lock"; return 1; }
  _sf_compose_refresh_locked
  local rc=$?
  sf_compose_lock_release
  return $rc
}

# Set a user override toggle. Args: <key> <true|false>
sf_compose_set_override() {
  local key="$1" value="$2"
  local path tmp
  path="$(sf_compose_path)"

  sf_compose_lock_acquire || { sf_log_error "could not acquire compose lock"; return 1; }

  # Bootstrap composition.json if missing — call internal (we hold lock)
  if [[ ! -f "$path" ]]; then
    _sf_compose_refresh_locked
  fi

  if [[ "$value" != "true" && "$value" != "false" ]]; then
    sf_log_error "override value must be true or false, got: $value"
    sf_compose_lock_release
    return 1
  fi

  tmp="$(mktemp "${path}.XXXXXX")"
  if jq --arg k "$key" --argjson v "$value" '.user_overrides[$k] = $v' "$path" > "$tmp"; then
    mv "$tmp" "$path"
  else
    rm -f "$tmp"
    sf_log_error "jq failed setting override"
    sf_compose_lock_release
    return 1
  fi

  sf_compose_lock_release
}

# Return 0 if a plugin is currently marked installed in composition.json.
sf_compose_is_installed() {
  local name="$1"
  local path
  path="$(sf_compose_path)"
  [[ -f "$path" ]] || return 1
  local v
  v="$(jq -r --arg n "$name" '.plugins[$n].installed // false' "$path")"
  [[ "$v" == "true" ]]
}

# Emit ai-mentor /z2-decide hint for judgment-dense phases (5, 7).
# Returns empty string when phase doesn't qualify, plugin isn't installed,
# or user has disabled hints.
sf_compose_mentor_hint() {
  local phase="$1"
  case "$phase" in
    5|7) ;;
    *)   echo ""; return 0 ;;
  esac

  local path
  path="$(sf_compose_path)"
  [[ -f "$path" ]] || { echo ""; return 0; }

  local installed disabled
  installed="$(jq -r '.plugins["ai-mentor"].installed // false' "$path")"
  disabled="$(jq -r '.user_overrides.disable_mentor_suggestions // false' "$path")"
  [[ "$installed" != "true" ]] && { echo ""; return 0; }
  [[ "$disabled" == "true" ]]   && { echo ""; return 0; }

  case "$phase" in
    5) echo "💡 Phase 5 (Architecture) is judgment-dense. Consider /z2-decide for spotter mode." ;;
    7) echo "💡 Phase 7 (Implementation) is judgment-dense. Consider /z2-decide for spotter mode." ;;
  esac
}

# Similarly: superpowers brainstorming hint at Phase 5/7
sf_compose_brainstorming_hint() {
  local phase="$1"
  case "$phase" in
    5|7) ;;
    *)   echo ""; return 0 ;;
  esac

  local path
  path="$(sf_compose_path)"
  [[ -f "$path" ]] || { echo ""; return 0; }

  local avail disabled
  avail="$(jq -r '.plugins["superpowers"].brainstorming_available // false' "$path")"
  disabled="$(jq -r '.user_overrides.disable_superpowers_subskill // false' "$path")"
  [[ "$avail" != "true" ]]    && { echo ""; return 0; }
  [[ "$disabled" == "true" ]] && { echo ""; return 0; }

  echo "💡 superpowers:brainstorming is available for visual trade-off exploration on this phase."
}

# v0.2 NOTE: The legacy file-IPC functions `sf_compose_build_critic_request`
# and `sf_compose_read_critic_response` were removed per SPEC §12.3.
# architect-critic is now invoked in-conversation via
# `Skill(architect-critic:critiquing-spec)`. No `inbox/` / `outbox/` paths.
# See SPEC §12.4 and the `critic-moments.md` reference doc.
