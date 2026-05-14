#!/usr/bin/env bash
# architect-critic lib/inbox.sh — request envelope read + validate.
# Sourced by /critique and tests. Requires _helpers.sh sourced first.

# ac_inbox_dir — returns the inbox directory path
ac_inbox_dir() {
  echo "$(ac_data_dir)/inbox"
}

# ac_inbox_path <request_id> — returns path to the envelope file
ac_inbox_path() {
  local rid="$1"
  echo "$(ac_inbox_dir)/${rid}.json"
}

# ac_inbox_read <request_id> — cat the envelope; non-zero if missing
ac_inbox_read() {
  local rid="$1"
  local path
  path="$(ac_inbox_path "$rid")"
  if [[ ! -f "$path" ]]; then
    ac_log_error "inbox file not found: $path"
    return 1
  fi
  cat "$path"
}

# ac_inbox_validate <envelope_json>
# Validates the request envelope per SPEC §6.1.
# Returns 0 on success; returns 1 + stderr message on first ERROR failure.
# Warnings are logged but do not cause failure.
ac_inbox_validate() {
  local json="$1"

  # Rule 1: request_id non-empty string
  local rid
  rid="$(printf '%s' "$json" | jq -r '.request_id // empty' 2>/dev/null)"
  if [[ -z "$rid" ]]; then
    ac_log_error "validation failed: request_id is missing or empty"
    return 1
  fi

  # Rule 2: depth in {premise-audit, close}
  local depth
  depth="$(printf '%s' "$json" | jq -r '.depth // empty' 2>/dev/null)"
  if [[ "$depth" != "premise-audit" && "$depth" != "close" ]]; then
    ac_log_error "validation failed: depth '$depth' not in {premise-audit, close}"
    return 1
  fi

  # Rule 3: adversaries non-empty array; each entry in {claude, codex}
  local adv_len
  adv_len="$(printf '%s' "$json" | jq 'if (.adversaries | type) == "array" then .adversaries | length else 0 end' 2>/dev/null)"
  if [[ "$adv_len" -lt 1 ]]; then
    ac_log_error "validation failed: adversaries must be a non-empty array"
    return 1
  fi
  local adv_invalid
  adv_invalid="$(printf '%s' "$json" | jq -r '.adversaries[] | select(. != "claude" and . != "codex")' 2>/dev/null)"
  if [[ -n "$adv_invalid" ]]; then
    ac_log_error "validation failed: adversaries contains invalid entry: $adv_invalid"
    return 1
  fi

  # Rule 4: target.type in {master-spec-phase, master-spec-full}
  local ttype
  ttype="$(printf '%s' "$json" | jq -r '.target.type // empty' 2>/dev/null)"
  if [[ "$ttype" != "master-spec-phase" && "$ttype" != "master-spec-full" ]]; then
    ac_log_error "validation failed: target.type '$ttype' not in {master-spec-phase, master-spec-full}"
    return 1
  fi

  # Rule 5: target.path is a string and resolves to a readable file
  local tpath
  tpath="$(printf '%s' "$json" | jq -r '.target.path // empty' 2>/dev/null)"
  if [[ -z "$tpath" ]]; then
    ac_log_error "validation failed: target.path is missing"
    return 1
  fi
  if [[ ! -r "$tpath" ]]; then
    ac_log_error "validation failed: target.path is not readable: $tpath"
    return 1
  fi

  # Rule 6: if target.type == master-spec-phase, phase_id must be int 1-10
  if [[ "$ttype" == "master-spec-phase" ]]; then
    local phase_id
    phase_id="$(printf '%s' "$json" | jq -r '.target.phase_id // empty' 2>/dev/null)"
    if [[ -z "$phase_id" ]]; then
      ac_log_error "validation failed: target.phase_id required for master-spec-phase"
      return 1
    fi
    # Must be an integer
    if ! [[ "$phase_id" =~ ^[0-9]+$ ]]; then
      ac_log_error "validation failed: target.phase_id must be an integer, got: $phase_id"
      return 1
    fi
    if [[ "$phase_id" -lt 1 || "$phase_id" -gt 10 ]]; then
      ac_log_error "validation failed: target.phase_id must be 1-10, got: $phase_id"
      return 1
    fi
  fi

  # Rule 7: sources.accumulated_phases is array of ints
  local ap_type
  ap_type="$(printf '%s' "$json" | jq -r '(.sources.accumulated_phases | type) // "null"' 2>/dev/null)"
  if [[ "$ap_type" != "array" ]]; then
    ac_log_error "validation failed: sources.accumulated_phases must be an array, got: $ap_type"
    return 1
  fi

  # Rule 8: concession_threshold is int 1-5
  local ct
  ct="$(printf '%s' "$json" | jq -r '.concession_threshold // empty' 2>/dev/null)"
  if [[ -z "$ct" ]]; then
    ac_log_error "validation failed: concession_threshold is missing"
    return 1
  fi
  if ! [[ "$ct" =~ ^[0-9]+$ ]]; then
    ac_log_error "validation failed: concession_threshold must be an integer, got: $ct"
    return 1
  fi
  if [[ "$ct" -lt 1 || "$ct" -gt 5 ]]; then
    ac_log_error "validation failed: concession_threshold must be 1-5, got: $ct"
    return 1
  fi

  # Warnings (log but accept):

  # sources.principles missing file → warn (re-seed signal)
  local principles_path
  principles_path="$(printf '%s' "$json" | jq -r '.sources.principles // empty' 2>/dev/null)"
  if [[ -n "$principles_path" && ! -f "$principles_path" ]]; then
    ac_log_warn "sources.principles file not found: $principles_path (re-seed signal)"
  fi

  # project_class == null → warn
  local pc_type
  pc_type="$(printf '%s' "$json" | jq -r '(.project_class | type)' 2>/dev/null)"
  if [[ "$pc_type" == "null" ]]; then
    ac_log_warn "project_class is null — audit will proceed without project classification"
  fi

  return 0
}
