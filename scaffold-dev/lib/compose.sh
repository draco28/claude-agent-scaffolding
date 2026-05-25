#!/usr/bin/env bash
# scaffold-dev/lib/compose.sh
# Cross-plugin filesystem-probe detection for optional companions
# (architect-critic, ai-mentor) per SPEC §16.3 / §16.4. Detection is binary:
# present → "v0.2" / "v2.0"; absent → "absent" with rc=1.
#
# Cache-dir overrides:
#   SD_COMPOSE_AC_CACHE_DIRS     — colon-separated for architect-critic
#   SD_COMPOSE_MENTOR_CACHE_DIRS — colon-separated for ai-mentor

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi

# Default cache-dir set when no override is provided.
_sd_compose_default_cache_dirs() {
  echo "${HOME}/.claude/plugins/cache"
  if [[ -n "${CLAUDE_PLUGINS_DIR:-}" ]]; then
    echo "$CLAUDE_PLUGINS_DIR"
  fi
}

# _sd_compose_split_dirs <colon-list>
_sd_compose_split_dirs() {
  local list="$1"
  local IFS=":"
  for d in $list; do
    echo "$d"
  done
}

# sd_compose_detect_architect_critic
# Echoes "v0.2" + rc=0 when a v0.2 critiquing-spec SKILL.md is reachable;
# echoes "absent" + rc=1 otherwise.
sd_compose_detect_architect_critic() {
  local cache_dirs=()
  if [[ -n "${SD_COMPOSE_AC_CACHE_DIRS:-}" ]]; then
    while IFS= read -r d; do cache_dirs+=("$d"); done < <(_sd_compose_split_dirs "$SD_COMPOSE_AC_CACHE_DIRS")
  else
    while IFS= read -r d; do cache_dirs+=("$d"); done < <(_sd_compose_default_cache_dirs)
  fi
  local cache skill_md
  for cache in "${cache_dirs[@]+"${cache_dirs[@]}"}"; do
    [[ -z "$cache" || ! -d "$cache" ]] && continue
    for skill_md in "$cache"/*/architect-critic/*/skills/critiquing-spec/SKILL.md; do
      [[ -f "$skill_md" ]] && { echo "v0.2"; return 0; }
    done
  done
  echo "absent"
  return 1
}

# sd_compose_detect_ai_mentor
# Echoes "v2.0" + rc=0 when a v2.0 grill-me SKILL.md is reachable;
# echoes "absent" + rc=1 otherwise.
sd_compose_detect_ai_mentor() {
  local cache_dirs=()
  if [[ -n "${SD_COMPOSE_MENTOR_CACHE_DIRS:-}" ]]; then
    while IFS= read -r d; do cache_dirs+=("$d"); done < <(_sd_compose_split_dirs "$SD_COMPOSE_MENTOR_CACHE_DIRS")
  else
    while IFS= read -r d; do cache_dirs+=("$d"); done < <(_sd_compose_default_cache_dirs)
  fi
  local cache skill_md
  for cache in "${cache_dirs[@]+"${cache_dirs[@]}"}"; do
    [[ -z "$cache" || ! -d "$cache" ]] && continue
    for skill_md in "$cache"/*/ai-mentor/*/skills/grill-me/SKILL.md; do
      [[ -f "$skill_md" ]] && { echo "v2.0"; return 0; }
    done
  done
  echo "absent"
  return 1
}

sd_compose_warn_critic_absent() {
  sd_log_warn "[scaffold-dev] architect-critic not installed; skipping adversarial review at this gate. Install via /plugin install architect-critic for adversarial review."
}

sd_compose_warn_grillme_absent() {
  sd_log_warn "[scaffold-dev] ai-mentor not installed; grill-me offer skipped. Install via /plugin install ai-mentor for stress-test-the-design dialogue."
}
