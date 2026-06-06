#!/usr/bin/env bash
# scaffold-onboard/lib/state.sh
# Onboarding state CRUD. State file lives at
# $(sf_project_data_dir)/onboarding-state.json.

set -u
source "$(dirname "${BASH_SOURCE[0]}")/_helpers.sh"

sf_state_path() {
  local path
  path="$(sf_project_data_dir)/onboarding-state.json"
  sf_state_migrate_legacy_if_owned "$path" >/dev/null 2>&1 || true
  echo "$path"
}

sf_state_legacy_path() {
  echo "$(sf_data_dir)/onboarding-state.json"
}

sf_state_migrate_legacy_if_owned() {
  local path="${1:-}"
  [[ -n "$path" ]] || path="$(sf_project_data_dir)/onboarding-state.json"
  [[ -f "$path" ]] && return 0

  local legacy
  legacy="$(sf_state_legacy_path)"
  [[ -f "$legacy" ]] || return 0

  local stored_root cur_root
  stored_root="$(jq -r '.project_root // empty' "$legacy" 2>/dev/null || true)"
  cur_root="$(sf_project_identity_root)"
  [[ -n "$stored_root" && "$stored_root" == "$cur_root" ]] || return 0

  mkdir -p "$(dirname "$path")"
  cp "$legacy" "$path"
}

sf_state_init() {
  local path
  path="$(sf_state_path)"
  mkdir -p "$(dirname "$path")"
  local now project_root
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  project_root="$(sf_project_identity_root)"
  jq -n \
    --arg now "$now" \
    --arg root "$project_root" \
    '{
      schema_version: 2,
      status: "in_progress",
      current_phase: 1,
      current_question: null,
      project_class: null,
      project_root: $root,
      created_at: $now,
      updated_at: $now,
      answers: {},
      phase_records: {},
      touched_this_run: []
    }' > "$path"
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

# Write a per-phase reasoning record. <record_file> must be a file containing a
# JSON object (the conducting agent authors it via its Write tool — keeps prose
# escaping out of bash). Merges into .phase_records["<phase_id>"] atomically and
# appends <phase_id> to .touched_this_run (unique). Bumps schema_version to 2 so
# a legacy file becomes conformant on first write.
sf_state_write_phase_record() {
  local phase_id="$1" record_file="$2"
  local path; path="$(sf_state_path)"
  if [[ ! -f "$record_file" ]]; then
    sf_log_error "sf_state_write_phase_record: record file not found: $record_file"
    return 1
  fi
  if ! jq -e . "$record_file" >/dev/null 2>&1; then
    sf_log_error "sf_state_write_phase_record: record file is not valid JSON: $record_file"
    return 1
  fi
  if ! jq -e 'type == "object"' "$record_file" >/dev/null 2>&1; then
    sf_log_error "sf_state_write_phase_record: record file must be a JSON object: $record_file"
    return 1
  fi
  local tmp now
  tmp="$(mktemp "${path}.XXXXXX")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg p "$phase_id" --arg now "$now" --slurpfile rec "$record_file" \
    '
    .schema_version = 2
    | .phase_records = (.phase_records // {})
    | .phase_records[$p] = ($rec[0] + {authored_at: $now})
    | .touched_this_run = (((.touched_this_run // []) + [$p]) | unique)
    | .updated_at = $now
    ' "$path" > "$tmp"
  mv "$tmp" "$path"
}

# Read .phase_records["<phase_id>"] as a JSON object. Prints "null" if absent.
sf_state_read_phase_record() {
  local phase_id="$1"
  local path; path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then echo "null"; return 0; fi
  jq -c --arg p "$phase_id" '.phase_records[$p] // null' "$path"
}

# Reset the per-run touched-phases tracker. Call once at skill entry / resume so
# the reconcile hint reflects only phases (re)authored in the current run.
sf_state_run_reset() {
  local path; path="$(sf_state_path)"
  [[ -f "$path" ]] || return 0
  local tmp now
  tmp="$(mktemp "${path}.XXXXXX")"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  jq --arg now "$now" '.touched_this_run = [] | .updated_at = $now' "$path" > "$tmp"
  mv "$tmp" "$path"
}

# Print phase IDs (re)authored in the current run, one per line, sorted.
# Mechanical reconcile hint handed to the synthesis agent.
sf_state_phases_touched_this_run() {
  local path; path="$(sf_state_path)"
  [[ -f "$path" ]] || return 0
  jq -r '(.touched_this_run // []) | sort_by(. | tonumber? // .) | .[]' "$path"
}

# Emit a human-readable markdown digest of the enriched state for the MASTER-SPEC
# synthesis agent: per phase, the verbatim answers (qid: value) followed by the
# agent-authored phase record fields (if any). This is the synthesis SOURCE — it
# replaces template transcription. Tool-agnostic: any agent that can read text
# can consume it.
sf_state_synthesis_digest() {
  local path; path="$(sf_state_path)"
  [[ -f "$path" ]] || { sf_log_error "sf_state_synthesis_digest: no state file"; return 1; }
  echo "# Onboarding discussion digest"
  echo ""
  echo "Project: $(sf_project_name)"
  echo ""
  local phase
  for phase in 1 2 3 4 5 6 7 8 9 10; do
    echo "## Phase $phase"
    echo ""
    echo "### Answers (verbatim)"
    # Answers whose qid starts with "<phase>." — numeric phase prefix match.
    jq -r --arg p "$phase" '
      .answers // {}
      | to_entries
      | map(select(.key | startswith($p + ".")))
      | sort_by(.key)
      | .[] | "- \(.key): \(.value)"
    ' "$path"
    echo ""
    local rec
    rec="$(jq -c --arg p "$phase" '.phase_records[$p] // null' "$path")"
    if [[ "$rec" != "null" ]]; then
      echo "### Synthesized phase record"
      printf '%s\n' "$rec" | jq -r '
        to_entries
        | map(select(.key != "authored_at"))
        | .[] | "- **\(.key)**: \(.value)"
      '
      echo ""
    fi
  done
}

# Resolve a clean project name for titles/paths. Prefers the explicit onboarding
# answer 1.1.4; falls back to the cwd basename. Never truncates the pitch on
# em-dash (the v0.2.x bug that produced garbage H1 titles).
sf_project_name() {
  local explicit
  explicit="$(sf_state_read_answer 1.1.4 2>/dev/null || echo null)"
  if [[ -n "$explicit" && "$explicit" != "null" ]]; then
    printf '%s\n' "$explicit"
    return 0
  fi
  basename "$PWD"
}

sf_state_lock_path() {
  echo "$(sf_project_data_dir)/onboarding.lock"
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
# Returns one of: new | resume | reonboard | project_mismatch
#
# project_mismatch fires when the stored project_root no longer matches the
# current project identity root. With project-scoped state this is a same-project
# safety guard for moved/malformed state, not the normal cross-project path.
#
# Legacy state files (pre-v0.2.1) lacking project_root are treated as
# unknown — they surface project_mismatch with stored="unknown" so the
# user is forced to confirm.
sf_state_mode() {
  local path
  path="$(sf_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "new"
    return 0
  fi
  local status stored_root cur_root
  status="$(sf_state_read_field status)"

  # Cross-project contamination check (Issue #4)
  stored_root="$(sf_state_read_field project_root)"
  cur_root="$(sf_project_identity_root)"
  if [[ -z "$stored_root" || "$stored_root" == "null" ]]; then
    stored_root="unknown"
  fi
  if [[ "$stored_root" != "$cur_root" ]]; then
    # Stash on stderr so the skill body can surface the absolute paths
    # in its prompt without re-reading the state file.
    sf_log_warn "state project_root mismatch: stored=$stored_root current=$cur_root"
    echo "project_mismatch"
    return 0
  fi

  case "$status" in
    "in_progress") echo "resume" ;;
    "complete")    echo "reonboard" ;;
    *)             echo "new" ;;  # malformed or unrecognized
  esac
}

# Get the stored project_root from the state file (returns "unknown" for
# legacy state files lacking the field). Useful for skill bodies that need
# to render the project-mismatch prompt with both stored and current paths.
sf_state_stored_project_root() {
  local stored
  stored="$(sf_state_read_field project_root)"
  if [[ -z "$stored" || "$stored" == "null" ]]; then
    echo "unknown"
  else
    echo "$stored"
  fi
}
