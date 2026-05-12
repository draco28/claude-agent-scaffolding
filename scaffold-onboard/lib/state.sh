#!/usr/bin/env bash
# scaffold-onboard/lib/state.sh
# Onboarding state CRUD. State file lives at $(sf_data_dir)/onboarding-state.json.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

sf_state_path() {
  echo "$(sf_data_dir)/onboarding-state.json"
}

sf_state_init() {
  local path
  path="$(sf_state_path)"
  mkdir -p "$(dirname "$path")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat > "$path" <<JSON
{
  "status": "in_progress",
  "current_phase": 1,
  "current_question": null,
  "project_class": null,
  "created_at": "$now",
  "updated_at": "$now",
  "answers": {}
}
JSON
}

# Read a top-level field from the state file. Returns "null" if missing.
sf_state_read_field() {
  local key="$1"
  local path
  path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "null"
    return 0
  fi
  jq -r --arg k "$key" '.[$k] // "null"' "$path"
}

# Write a top-level field atomically: jq writes to tmp, then mv.
# Treats numeric strings as numbers; anything else as a JSON string.
sf_state_write_atomic() {
  local key="$1" value="$2"
  local path
  path="$(sf_state_path)"
  local tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Detect numeric value (integer only)
  if [[ "$value" =~ ^-?[0-9]+$ ]]; then
    jq --arg k "$key" --argjson v "$value" --arg now "$now" \
      '.[$k] = $v | .updated_at = $now' "$path" > "$tmp"
  else
    jq --arg k "$key" --arg v "$value" --arg now "$now" \
      '.[$k] = $v | .updated_at = $now' "$path" > "$tmp"
  fi
  mv "$tmp" "$path"
}

# Write an answer to state.answers["<question_id>"]. value is treated as a
# raw string; jq handles escaping.
sf_state_write_answer() {
  local qid="$1" value="$2"
  local path
  path="$(sf_state_path)"
  local tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg q "$qid" --arg v "$value" --arg now "$now" \
    '.answers[$q] = $v | .updated_at = $now' "$path" > "$tmp"
  mv "$tmp" "$path"
}

# Read state.answers["<question_id>"]. Returns "null" if absent.
sf_state_read_answer() {
  local qid="$1"
  local path
  path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "null"
    return 0
  fi
  jq -r --arg q "$qid" '.answers[$q] // "null"' "$path"
}

sf_state_lock_path() {
  echo "$(sf_data_dir)/onboarding.lock"
}

# Acquire the onboarding lock. Exits 1 if already held.
# Lock contents: PID + iso-timestamp, for diagnostics.
sf_state_lock_acquire() {
  local path
  path="$(sf_state_lock_path)"
  mkdir -p "$(dirname "$path")"
  # Use noclobber redirection for atomic create-or-fail
  if ( set -o noclobber; echo "$$ $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$path" ) 2>/dev/null; then
    return 0
  else
    sf_log_error "onboarding lock already held: $path ($(cat "$path" 2>/dev/null || echo unknown))"
    return 1
  fi
}

sf_state_lock_release() {
  rm -f "$(sf_state_lock_path)"
}

# Advance current_phase by 1. If already at 10, set status=complete instead.
sf_state_advance_phase() {
  local cur
  cur="$(sf_state_read_field current_phase)"
  if [[ "$cur" == "10" ]]; then
    sf_state_write_atomic status complete
  else
    sf_state_write_atomic current_phase "$((cur+1))"
  fi
}

# Evaluate a branching gate expression against current state.answers.
# Supported forms:
#   "project_class == \"Web app\""
#   "project_class in {Web app, Mobile app}"
#   "uses_llm == true"
# Returns 0 if gate passes, 1 if not.
sf_state_gate_passes() {
  local expr="$1"
  # Substitute known variables
  local project_class uses_llm
  project_class="$(sf_state_read_answer 1.3.1)"
  uses_llm="$(sf_state_read_answer 9.3.1)"

  # Form: project_class in {A, B, C}
  if [[ "$expr" =~ ^project_class[[:space:]]+in[[:space:]]+\{(.+)\}$ ]]; then
    local list="${BASH_REMATCH[1]}"
    local IFS=','
    local item
    for item in $list; do
      # trim leading/trailing whitespace
      item="${item#"${item%%[![:space:]]*}"}"
      item="${item%"${item##*[![:space:]]}"}"
      if [[ "$item" == "$project_class" ]]; then
        return 0
      fi
    done
    return 1
  fi

  # Form: project_class == "value"
  if [[ "$expr" =~ ^project_class[[:space:]]+==[[:space:]]+\"(.+)\"$ ]]; then
    [[ "$project_class" == "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  fi

  # Form: uses_llm == true
  if [[ "$expr" =~ ^uses_llm[[:space:]]+==[[:space:]]+(true|false)$ ]]; then
    [[ "$uses_llm" == "${BASH_REMATCH[1]}" ]] && return 0 || return 1
  fi

  sf_log_warn "Unknown gate expression: $expr (defaulting to passes)"
  return 0
}

# ---------------------------------------------------------------------------
# phases.yaml reader helpers (BSD awk — no gawk 3-arg match)
# ---------------------------------------------------------------------------

# Return all question IDs for phase N from phases.yaml, one per line.
# Usage: sf_phases_questions_for <yaml> <target_phase>
sf_phases_questions_for() {
  local yaml="$1" target="$2"
  awk -v target="$target" '
    /^  - id: [0-9]+$/ {
      line = $0
      sub(/^  - id: /, "", line)
      cur_phase = line
      next
    }
    /^          - id: "[0-9]+[A-Z]?\.[0-9]+\.[0-9]+"$/ {
      if (cur_phase == target) {
        line = $0
        sub(/^          - id: "/, "", line)
        sub(/"$/, "", line)
        print line
      }
    }
  ' "$yaml"
}

# Return the text value of a question by id.
# Usage: sf_phases_question_text <yaml> <qid>
sf_phases_question_text() {
  local yaml="$1" qid="$2"
  awk -v qid="$qid" '
    $0 == "          - id: \"" qid "\"" { found = 1; next }
    found && /text:/ {
      line = $0
      sub(/^[[:space:]]*text: "/, "", line)
      sub(/"$/, "", line)
      print line
      exit
    }
  ' "$yaml"
}

# Return the required value (true/false) of a question by id.
# Usage: sf_phases_question_required <yaml> <qid>
sf_phases_question_required() {
  local yaml="$1" qid="$2"
  awk -v qid="$qid" '
    $0 == "          - id: \"" qid "\"" { found = 1; next }
    found && /required:/ {
      line = $0
      sub(/^[[:space:]]*required:[[:space:]]*/, "", line)
      print line
      exit
    }
  ' "$yaml"
}

# Return the gate expression of a question by id, or empty if none.
# Usage: sf_phases_question_gate <yaml> <qid>
sf_phases_question_gate() {
  local yaml="$1" qid="$2"
  awk -v qid="$qid" '
    $0 == "          - id: \"" qid "\"" { found = 1; next }
    found && /^          - id:/ { exit }
    found && /gate:/ {
      line = $0
      sub(/^[[:space:]]*gate:[[:space:]]*/, "", line)
      sub(/^"/, "", line)
      sub(/"$/, "", line)
      print line
      exit
    }
  ' "$yaml"
}

# Determine the onboarding mode based on state file existence + status.
# Returns one of: new | resume | reonboard
sf_state_mode() {
  local path
  path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "new"
    return 0
  fi
  local status
  status="$(sf_state_read_field status)"
  case "$status" in
    "in_progress") echo "resume" ;;
    "complete")    echo "reonboard" ;;
    *)             echo "new" ;;  # malformed or unrecognized
  esac
}
