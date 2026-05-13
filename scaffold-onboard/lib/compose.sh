#!/usr/bin/env bash
# scaffold-onboard/lib/compose.sh
# Cross-cutting plugin detection + composition.json caching + critic dispatch.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

# Return the list of paths to probe for installed plugins.
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

sf_compose_detect_architect_critic() {
  _compose_find_plugin "architect-critic"
}

sf_compose_detect_superpowers() {
  _compose_find_plugin "superpowers"
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

# Probe every cross-cutting plugin and write composition.json. Atomic via tmp+mv.
sf_compose_refresh() {
  local path tmp now
  path="$(sf_compose_path)"
  mkdir -p "$(dirname "$path")"
  tmp="$(mktemp "${path}.XXXXXX")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local mentor_dir critic_dir superpowers_dir brainstorming
  mentor_dir="$(sf_compose_detect_ai_mentor)"
  critic_dir="$(sf_compose_detect_architect_critic)"
  superpowers_dir="$(sf_compose_detect_superpowers)"
  brainstorming="$(sf_compose_brainstorming_available)"

  jq -n \
    --arg now "$now" \
    --arg mentor "$mentor_dir" \
    --arg critic "$critic_dir" \
    --arg sp "$superpowers_dir" \
    --arg br "$brainstorming" \
    '{
      detected_at: $now,
      plugins: {
        "ai-mentor": {
          installed: ($mentor != ""),
          data_dir: $mentor,
          state_file: (if $mentor != "" then ($mentor + "/state.json") else "" end)
        },
        "architect-critic": {
          installed: ($critic != ""),
          data_dir: $critic,
          principles_file: (if $critic != "" then ($critic + "/principles.md") else "" end),
          command: "/critique"
        },
        "superpowers": {
          installed: ($sp != ""),
          skills_dir: (if $sp != "" then ($sp + "/skills") else "" end),
          brainstorming_available: ($br == "true")
        }
      },
      user_overrides: {
        disable_mentor_suggestions: false,
        disable_critic: false,
        disable_superpowers_subskill: false
      }
    }' > "$tmp"
  mv "$tmp" "$path"
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
