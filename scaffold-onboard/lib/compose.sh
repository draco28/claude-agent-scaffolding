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

  # Preserve existing user_overrides if composition.json exists
  local overrides_json
  if [[ -f "$path" ]]; then
    overrides_json="$(jq '.user_overrides // {}' "$path")"
  else
    overrides_json='{"disable_mentor_suggestions":false,"disable_critic":false,"disable_superpowers_subskill":false}'
  fi

  if jq -n \
    --arg now "$now" \
    --arg mentor "$mentor_dir" \
    --arg critic "$critic_dir" \
    --arg sp "$superpowers_dir" \
    --arg br "$brainstorming" \
    --argjson overrides "$overrides_json" \
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

# Set a user override toggle. Args: <key> <true|false>
sf_compose_set_override() {
  local key="$1" value="$2"
  local path tmp
  path="$(sf_compose_path)"
  [[ -f "$path" ]] || sf_compose_refresh
  if [[ "$value" != "true" && "$value" != "false" ]]; then
    sf_log_error "override value must be true or false, got: $value"
    return 1
  fi
  tmp="$(mktemp "${path}.XXXXXX")"
  if jq --arg k "$key" --argjson v "$value" '.user_overrides[$k] = $v' "$path" > "$tmp"; then
    mv "$tmp" "$path"
  else
    rm -f "$tmp"
    sf_log_error "jq failed setting override"
    return 1
  fi
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

# Build a critic request envelope per SPEC §8.3 and write it to the
# architect-critic inbox dir. Echo the path of the written request file.
# Args: <depth> <phase_id_or_empty>
sf_compose_build_critic_request() {
  local depth="$1" phase_id="${2:-}"
  local comp
  comp="$(sf_compose_path)"
  [[ -f "$comp" ]] || { sf_log_error "composition.json missing"; return 1; }

  local critic_dir
  critic_dir="$(jq -r '.plugins["architect-critic"].data_dir // ""' "$comp")"
  [[ -z "$critic_dir" ]] && { sf_log_error "architect-critic not installed"; return 1; }

  local principles
  principles="$(jq -r '.plugins["architect-critic"].principles_file // ""' "$comp")"

  local inbox_dir
  inbox_dir="$critic_dir/inbox"
  mkdir -p "$inbox_dir"

  local now request_id req_path
  now="$(date -u +%Y-%m-%dT%H%M%S)"
  if [[ -n "$phase_id" ]]; then
    request_id="crit-${now}-phase${phase_id}"
  else
    request_id="crit-${now}-close"
  fi
  req_path="$inbox_dir/${request_id}.json"

  # Adversaries: claude only for per-phase audits; claude+codex at close.
  local adversaries_json
  if [[ "$depth" == "close" ]]; then
    adversaries_json='["claude","codex"]'
  else
    adversaries_json='["claude"]'
  fi

  # target: master-spec-phase (for per-phase) or master-spec-full (for close)
  local target_json
  local master_spec_path
  master_spec_path="$(pwd)/MASTER-SPEC.md"
  if [[ "$depth" == "close" ]]; then
    target_json="$(jq -n --arg p "$master_spec_path" '{type:"master-spec-full",path:$p}')"
  else
    target_json="$(jq -n --arg p "$master_spec_path" --argjson pid "$phase_id" \
      '{type:"master-spec-phase",path:$p,phase_id:$pid}')"
  fi

  # Accumulated phases: 1..N-1 for per-phase audits; 1..10 for close
  local acc_json
  if [[ "$depth" == "close" ]]; then
    acc_json='[1,2,3,4,5,6,7,8,9,10]'
  else
    acc_json="$(jq -n --argjson pid "$phase_id" '[range(1;$pid)]')"
  fi

  local project_class
  project_class="$(sf_state_read_answer 1.3.1)"
  [[ "$project_class" == "null" ]] && project_class=""

  if jq -n \
    --arg rid "$request_id" \
    --arg depth "$depth" \
    --argjson adv "$adversaries_json" \
    --argjson target "$target_json" \
    --arg principles "$principles" \
    --argjson acc "$acc_json" \
    --argjson conc 4 \
    --arg pc "$project_class" \
    '{
      request_id: $rid,
      depth: $depth,
      adversaries: $adv,
      target: $target,
      sources: { principles: $principles, accumulated_phases: $acc },
      concession_threshold: $conc,
      project_class: $pc
    }' > "$req_path"; then
    echo "$req_path"
  else
    rm -f "$req_path"
    sf_log_error "jq failed building critic request"
    return 1
  fi
}

# Read a critic response from the outbox by request_id, with a polling timeout.
# Args: <request_id> <timeout_seconds>
# Echoes the response JSON on success; returns 1 on timeout.
sf_compose_read_critic_response() {
  local request_id="$1" timeout_s="$2"
  local comp critic_dir outbox_path
  comp="$(sf_compose_path)"
  critic_dir="$(jq -r '.plugins["architect-critic"].data_dir // ""' "$comp")"
  [[ -z "$critic_dir" ]] && return 1
  outbox_path="$critic_dir/outbox/${request_id}.json"

  local elapsed=0
  while [[ "$elapsed" -lt "$timeout_s" ]]; do
    if [[ -f "$outbox_path" ]]; then
      cat "$outbox_path"
      return 0
    fi
    sleep 1
    elapsed=$((elapsed+1))
  done
  sf_log_warn "Critic response timeout for request $request_id (waited ${timeout_s}s)"
  return 1
}
