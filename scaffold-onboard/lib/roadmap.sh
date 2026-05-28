#!/usr/bin/env bash
# scaffold-onboard/lib/roadmap.sh
#
# Project roadmap state CRUD + ROADMAP.md rendering.
# Per SPEC §7 (scaffold-onboard v0.2) + PLAN T3.2.
#
# State file: $(sf_project_data_dir)/project-roadmap.json (separate from
# onboarding-state.json). Schema per SPEC §7.2:
#   {
#     "schema_version": "1",
#     "started_at": "<ISO-8601>",
#     "checkpoint":  "R1.A | R1.A-complete | R1.B | ... | R1.C-complete",
#     "elapsed_min": <int>,
#     "project_name": "<string>",
#     "phases":          [{id, name, horizon, summary}, ...],
#     "sprints":         [{phase_id, id, name, goal, vs_count_estimate}, ...],
#     "vertical_slices": [{sprint_id, id, name, summary, demo_criteria: [],
#                          traces_fr: [], traces_nfr: [], traces_backlog: []}, ...],
#     "mutations":       [{timestamp, mode, target, note}, ...]
#   }
#
# Function naming follows the SKILL.md body's expected vocabulary (committed
# in 1a4f10a). PLAN T3.2's slightly different names (sf_roadmap_init,
# sf_roadmap_get_checkpoint, sf_roadmap_count_nodes, sf_roadmap_add_mutation)
# are exposed as aliases at the bottom for that contract.
#
# Bash 3.2-compatible (macOS): no `declare -A`, no GNU-only flags.

set -u

# Source helpers + routing (routing provides sf_resolve_output_path).
_sf_roadmap_source_deps() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck disable=SC1090
  [[ -f "$here/_helpers.sh" ]] && source "$here/_helpers.sh"
  # shellcheck disable=SC1090
  [[ -f "$here/routing.sh"  ]] && source "$here/routing.sh"
}
_sf_roadmap_source_deps

# ----------------------------------------------------------------------------
# State file path
# ----------------------------------------------------------------------------
sf_roadmap_state_path() {
  local path
  path="$(sf_project_data_dir)/project-roadmap.json"
  sf_roadmap_migrate_legacy_if_owned "$path" >/dev/null 2>&1 || true
  echo "$path"
}

sf_roadmap_legacy_state_path() {
  echo "$(sf_data_dir)/project-roadmap.json"
}

sf_roadmap_migrate_legacy_if_owned() {
  local path="${1:-}"
  [[ -n "$path" ]] || path="$(sf_project_data_dir)/project-roadmap.json"
  [[ -f "$path" ]] && return 0

  local legacy_state legacy_onboarding
  legacy_state="$(sf_roadmap_legacy_state_path)"
  legacy_onboarding="$(sf_state_legacy_path)"
  [[ -f "$legacy_state" && -f "$legacy_onboarding" ]] || return 0

  local stored_root cur_root
  stored_root="$(jq -r '.project_root // empty' "$legacy_onboarding" 2>/dev/null || true)"
  cur_root="$(sf_project_identity_root)"
  [[ -n "$stored_root" && "$stored_root" == "$cur_root" ]] || return 0

  mkdir -p "$(dirname "$path")"
  local tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  if jq --arg root "$cur_root" '.project_root = (.project_root // $root)' "$legacy_state" > "$tmp"; then
    mv "$tmp" "$path"
  else
    rm -f "$tmp"
    return 1
  fi
}

# ----------------------------------------------------------------------------
# Initialize state file
# ----------------------------------------------------------------------------
# Args: $1 — project name (string)
sf_roadmap_state_init() {
  local project_name="${1:-}"
  local path
  path="$(sf_roadmap_state_path)"
  mkdir -p "$(dirname "$path")"
  local now project_root
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  project_root="$(sf_project_identity_root)"
  # Use jq to construct so we get correctly-formed JSON (and proper escaping).
  jq -n \
    --arg now  "$now" \
    --arg name "$project_name" \
    --arg root "$project_root" \
    '{
      schema_version: "1",
      started_at: $now,
      checkpoint: "R1.A",
      elapsed_min: 0,
      project_name: $name,
      project_root: $root,
      phases: [],
      sprints: [],
      vertical_slices: [],
      mutations: []
    }' > "$path"
}

# ----------------------------------------------------------------------------
# Internal: atomic jq-driven update of the state file.
# Args: $1 — jq filter string
#       remaining args passed through as --arg pairs (already prepared by
#       caller; e.g., "--arg" "k" "v" "--argjson" "n" "5")
# ----------------------------------------------------------------------------
_sf_roadmap_atomic() {
  local filter="$1"; shift
  local path
  path="$(sf_roadmap_state_path)"
  if [[ ! -f "$path" ]]; then
    sf_log_error "roadmap state file missing: $path (call sf_roadmap_state_init first)"
    return 1
  fi
  local tmp
  tmp="$(mktemp "${path}.XXXXXX")"
  if jq "$@" "$filter" "$path" > "$tmp"; then
    mv "$tmp" "$path"
  else
    rm -f "$tmp"
    sf_log_error "jq update failed; state unchanged"
    return 1
  fi
}

# ----------------------------------------------------------------------------
# Checkpoint accessors
# ----------------------------------------------------------------------------
sf_roadmap_read_checkpoint() {
  local path
  path="$(sf_roadmap_state_path)"
  if [[ ! -f "$path" ]]; then
    echo ""
    return 1
  fi
  jq -r '.checkpoint // ""' "$path"
}

sf_roadmap_set_checkpoint() {
  local value="$1"
  _sf_roadmap_atomic '.checkpoint = $v' --arg v "$value"
}

# ----------------------------------------------------------------------------
# Phase / sprint / slice writers (idempotent by id).
# Each is a list-upsert: if an entry with the same id exists, update in place;
# else append. Order is preserved (insertion order for new entries).
# ----------------------------------------------------------------------------

# Args: phase_id (int) name horizon summary
sf_roadmap_write_phase() {
  local id="$1" name="$2" horizon="$3" summary="$4"
  _sf_roadmap_atomic '
    . as $root
    | ($root.phases | map(.id) | index($id_num)) as $idx
    | if $idx == null
      then .phases += [{id: $id_num, name: $name, horizon: $horizon, summary: $summary}]
      else .phases[$idx] = {id: $id_num, name: $name, horizon: $horizon, summary: $summary}
      end
  ' \
    --argjson id_num "$id" \
    --arg name    "$name" \
    --arg horizon "$horizon" \
    --arg summary "$summary"
}

# Args: sprint_id ("1.1") phase_id (int) name goal [vs_count_estimate]
sf_roadmap_write_sprint() {
  local sprint_id="$1" phase_id="$2" name="$3" goal="$4"
  local vs_estimate="${5:-0}"
  _sf_roadmap_atomic '
    . as $root
    | ($root.sprints | map(.id) | index($sid)) as $idx
    | (if $idx == null
       then .sprints += [{phase_id: $pid_num, id: $sid, name: $name, goal: $goal, vs_count_estimate: $vs_num}]
       else .sprints[$idx] = {phase_id: $pid_num, id: $sid, name: $name, goal: $goal, vs_count_estimate: $vs_num}
       end)
  ' \
    --arg sid     "$sprint_id" \
    --argjson pid_num "$phase_id" \
    --arg name    "$name" \
    --arg goal    "$goal" \
    --argjson vs_num "$vs_estimate"
}

# Args: slice_id ("VS-1.1.1") sprint_id ("1.1") name summary
#       [traces_fr_json] [traces_nfr_json] [traces_backlog_json]
sf_roadmap_write_slice() {
  local slice_id="$1" sprint_id="$2" name="$3" summary="$4"
  local trace_args_provided=0
  [[ $# -ge 5 ]] && trace_args_provided=1
  local traces_fr="${5:-[]}"
  local traces_nfr="${6:-[]}"
  local traces_backlog="${7:-[]}"
  if ! printf '%s' "$traces_fr" | jq -e 'type == "array"' >/dev/null 2>&1; then
    sf_log_error "sf_roadmap_write_slice: traces_fr must be a JSON array"
    return 1
  fi
  if ! printf '%s' "$traces_nfr" | jq -e 'type == "array"' >/dev/null 2>&1; then
    sf_log_error "sf_roadmap_write_slice: traces_nfr must be a JSON array"
    return 1
  fi
  if ! printf '%s' "$traces_backlog" | jq -e 'type == "array"' >/dev/null 2>&1; then
    sf_log_error "sf_roadmap_write_slice: traces_backlog must be a JSON array"
    return 1
  fi
  _sf_roadmap_atomic '
    . as $root
    | ($root.vertical_slices | map(.id) | index($vid)) as $idx
    | (if $idx == null
       then .vertical_slices += [{
          sprint_id: $sid,
          id: $vid,
          name: $name,
          summary: $summary,
          demo_criteria: [],
          traces_fr: $traces_fr,
          traces_nfr: $traces_nfr,
          traces_backlog: $traces_backlog
        }]
       else .vertical_slices[$idx] = (.vertical_slices[$idx]
            | .sprint_id = $sid
            | .id = $vid
            | .name = $name
            | .summary = $summary
            | .traces_fr = (if $trace_args_provided == 1 then $traces_fr else (.traces_fr // []) end)
            | .traces_nfr = (if $trace_args_provided == 1 then $traces_nfr else (.traces_nfr // []) end)
            | .traces_backlog = (if $trace_args_provided == 1 then $traces_backlog else (.traces_backlog // []) end))
       end)
  ' \
    --arg vid     "$slice_id" \
    --arg sid     "$sprint_id" \
    --arg name    "$name" \
    --arg summary "$summary" \
    --argjson trace_args_provided "$trace_args_provided" \
    --argjson traces_fr "$traces_fr" \
    --argjson traces_nfr "$traces_nfr" \
    --argjson traces_backlog "$traces_backlog"
}

# ----------------------------------------------------------------------------
# Mutations array
# ----------------------------------------------------------------------------
# Args: mode (add-phase|add-sprint|add-slice|refine-slice|reorganize) target note
sf_roadmap_add_mutation() {
  local mode="$1" target="$2" note="$3"
  local now
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  _sf_roadmap_atomic '
    .mutations += [{timestamp: $ts, mode: $mode, target: $target, note: $note}]
  ' \
    --arg ts     "$now" \
    --arg mode   "$mode" \
    --arg target "$target" \
    --arg note   "$note"
}

# Alias matching SKILL.md's "append_mutation" vocabulary.
sf_roadmap_append_mutation() {
  sf_roadmap_add_mutation "$@"
}

# ----------------------------------------------------------------------------
# Node count + size class
# ----------------------------------------------------------------------------
# Returns the total number of authored hierarchy nodes
# (phases + sprints + vertical_slices).
sf_roadmap_count_nodes() {
  local path
  path="$(sf_roadmap_state_path)"
  if [[ ! -f "$path" ]]; then
    echo 0
    return 0
  fi
  jq -r '(.phases | length) + (.sprints | length) + (.vertical_slices | length)' "$path"
}

# Alias matching SKILL.md's "_estimate" vocabulary. Same semantics as
# count_nodes for the authored-state path; the SKILL surface calls this at
# R1.A close (where only phases exist) and expects an authored-node count
# (the skill body multiplies by SPEC-recommended avg sprints/slices itself
# to surface an estimate — see SKILL.md §6 line 211).
sf_roadmap_count_nodes_estimate() {
  sf_roadmap_count_nodes
}

# Size-class classification per SPEC §7.3:
#   ≤50  → "normal"
#   51-100 → "large"   (surface continue/split/reduce prompt)
#   >100 → "split"     (recommended split-into-product-epics)
sf_roadmap_size_class() {
  local n
  n="$(sf_roadmap_count_nodes)"
  if [[ "$n" -le 50 ]]; then
    echo "normal"
  elif [[ "$n" -le 100 ]]; then
    echo "large"
  else
    echo "split"
  fi
}

# ----------------------------------------------------------------------------
# Re-run mode detection (per SPEC §7.5)
# ----------------------------------------------------------------------------
# Args: parsed CLI flags ("--add-phase", "--add-sprint", "--add-slice",
#       "--refine-slice", "--reorganize"). Trailing flag-arguments (phase id,
#       sprint id, etc.) are accepted but not validated here.
# Echoes one of: initial | add-phase | add-sprint | add-slice | refine-slice | reorganize
# Returns:
#   0 — mode echoed
#   1 — defensive reject (e.g., --reorganize with no prior state)
sf_roadmap_detect_rerun_mode() {
  local state_exists=0
  local path
  path="$(sf_roadmap_state_path)"
  [[ -f "$path" ]] && state_exists=1

  # Scan args for the first recognized mode flag.
  local mode_flag=""
  local arg
  for arg in "$@"; do
    case "$arg" in
      --add-phase|--add-sprint|--add-slice|--refine-slice|--reorganize)
        mode_flag="$arg"
        break
        ;;
    esac
  done

  if [[ -z "$mode_flag" ]]; then
    # No mode flag. Defensive default: "initial" (skill body re-prompts user
    # for disambiguation when state already exists).
    echo "initial"
    return 0
  fi

  # Mode flag present. --reorganize requires existing state.
  if [[ "$mode_flag" == "--reorganize" && "$state_exists" == "0" ]]; then
    sf_log_warn "--reorganize requires prior project-roadmap.json state; refusing"
    return 1
  fi

  # Strip leading "--" → mode name.
  echo "${mode_flag#--}"
}

# Roadmap state mode (parallel to lib/state.sh's sf_state_mode for the
# onboarding state file). Returns one of: new | resume | rerun.
sf_roadmap_state_mode() {
  local path
  path="$(sf_roadmap_state_path)"
  if [[ ! -f "$path" ]]; then
    echo "new"
    return 0
  fi
  local cp
  cp="$(jq -r '.checkpoint // ""' "$path")"
  if [[ "$cp" == "R1.C-complete" ]]; then
    echo "rerun"
  else
    echo "resume"
  fi
}

# ----------------------------------------------------------------------------
# Elapsed-minutes calculator (started_at → now, integer minutes).
# ----------------------------------------------------------------------------
sf_roadmap_read_elapsed() {
  local path
  path="$(sf_roadmap_state_path)"
  if [[ ! -f "$path" ]]; then
    echo 0
    return 1
  fi
  local started
  started="$(jq -r '.started_at // ""' "$path")"
  if [[ -z "$started" ]]; then
    echo 0
    return 0
  fi
  # Parse ISO-8601 UTC timestamp on macOS BSD date and Linux GNU date.
  local started_epoch now_epoch
  if started_epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$started" "+%s" 2>/dev/null)"; then
    : # BSD date succeeded
  elif started_epoch="$(date -u -d "$started" +%s 2>/dev/null)"; then
    : # GNU date succeeded
  else
    echo 0
    return 1
  fi
  now_epoch="$(date -u +%s)"
  echo $(( (now_epoch - started_epoch) / 60 ))
}

# ----------------------------------------------------------------------------
# ROADMAP.md renderer (per SPEC §7.1)
# ----------------------------------------------------------------------------
# Reads project-roadmap.json and emits markdown to the manifest-resolved
# path (sf_resolve_output_path "roadmap" "ROADMAP.md"). Idempotent:
# re-rendering the same state produces a byte-identical file.
#
# Idempotent re-render note (per SPEC §13.3 backcompat principle): for v0.2
# the renderer is **fully deterministic over state JSON** — re-running with
# unchanged state produces byte-identical output. Preserving user-edited
# inline content (i.e., partial-overwrite of existing ROADMAP.md) is deferred
# to v0.3; in v0.2, users who want freeform context appended to ROADMAP.md
# should keep it in a separate file or wrap it outside the rendered region.
sf_roadmap_render() {
  local out_path
  out_path="$(sf_resolve_output_path "roadmap" "ROADMAP.md")"
  local state_path
  state_path="$(sf_roadmap_state_path)"
  if [[ ! -f "$state_path" ]]; then
    sf_log_error "roadmap state missing: $state_path"
    return 1
  fi

  mkdir -p "$(dirname "$out_path")"
  local tmp
  tmp="$(mktemp "${out_path}.XXXXXX")"

  _sf_roadmap_render_to_stdout "$state_path" > "$tmp"
  mv "$tmp" "$out_path"
}

# Internal: emit roadmap markdown for a given state file to stdout.
_sf_roadmap_render_to_stdout() {
  local state_path="$1"

  local project_name today
  project_name="$(jq -r '.project_name // "<project>"' "$state_path")"
  # Use started_at's date prefix for the "Derived on" line so re-renders are
  # idempotent (not "today's date"). Falls back to the ISO date of started_at.
  today="$(jq -r '(.started_at // "") | split("T")[0]' "$state_path")"
  [[ -z "$today" || "$today" == "null" ]] && today="$(date -u +%Y-%m-%d)"

  printf '# ROADMAP — %s\n\n' "$project_name"
  printf '> Derived from MASTER-SPEC.md by `/plan-roadmap` on %s.\n' "$today"
  printf '> Co-edited by user + scaffold-dev orchestrator over time.\n\n'
  printf '## Roadmap overview\n\n'
  printf '<3-paragraph summary of project shape, with 3-timelines framing>\n\n'

  # Iterate phases in array order. For each phase: walk its sprints in array
  # order; for each sprint: walk its slices in array order.
  local phase_count
  phase_count="$(jq -r '.phases | length' "$state_path")"
  local i j k
  for (( i = 0; i < phase_count; i++ )); do
    local p_id p_name p_horizon p_summary
    p_id="$(jq -r --argjson i "$i" '.phases[$i].id' "$state_path")"
    p_name="$(jq -r --argjson i "$i" '.phases[$i].name' "$state_path")"
    p_horizon="$(jq -r --argjson i "$i" '.phases[$i].horizon' "$state_path")"
    p_summary="$(jq -r --argjson i "$i" '.phases[$i].summary' "$state_path")"

    printf '## Phase %s: %s — %s\n\n' "$p_id" "$p_name" "$p_horizon"
    printf '%s\n\n' "$p_summary"

    # Sprints belonging to this phase (phase_id matches).
    local sprint_count
    sprint_count="$(jq -r --argjson pid "$p_id" '[.sprints[] | select(.phase_id == $pid)] | length' "$state_path")"
    for (( j = 0; j < sprint_count; j++ )); do
      local s_id s_name s_goal
      s_id="$(jq -r --argjson pid "$p_id" --argjson j "$j" '[.sprints[] | select(.phase_id == $pid)] [$j].id' "$state_path")"
      s_name="$(jq -r --argjson pid "$p_id" --argjson j "$j" '[.sprints[] | select(.phase_id == $pid)] [$j].name' "$state_path")"
      s_goal="$(jq -r --argjson pid "$p_id" --argjson j "$j" '[.sprints[] | select(.phase_id == $pid)] [$j].goal' "$state_path")"

      printf '### Sprint %s: %s\n\n' "$s_id" "$s_name"
      printf '%s\n\n' "$s_goal"

      # Slices belonging to this sprint (sprint_id matches).
      local slice_count
      slice_count="$(jq -r --arg sid "$s_id" '[.vertical_slices[] | select(.sprint_id == $sid)] | length' "$state_path")"
      for (( k = 0; k < slice_count; k++ )); do
        local v_id v_name v_summary
        v_id="$(jq -r --arg sid "$s_id" --argjson k "$k" '[.vertical_slices[] | select(.sprint_id == $sid)] [$k].id' "$state_path")"
        v_name="$(jq -r --arg sid "$s_id" --argjson k "$k" '[.vertical_slices[] | select(.sprint_id == $sid)] [$k].name' "$state_path")"
        v_summary="$(jq -r --arg sid "$s_id" --argjson k "$k" '[.vertical_slices[] | select(.sprint_id == $sid)] [$k].summary' "$state_path")"

        printf '#### %s: %s\n\n' "$v_id" "$v_name"
        printf '%s\n\n' "$v_summary"

        printf '##### Traceability\n\n'
        local traces_fr traces_nfr traces_backlog
        traces_fr="$(jq -r --arg sid "$s_id" --argjson k "$k" '[.vertical_slices[] | select(.sprint_id == $sid)] [$k].traces_fr // [] | if length == 0 then "None" else join(", ") end' "$state_path")"
        traces_nfr="$(jq -r --arg sid "$s_id" --argjson k "$k" '[.vertical_slices[] | select(.sprint_id == $sid)] [$k].traces_nfr // [] | if length == 0 then "None" else join(", ") end' "$state_path")"
        traces_backlog="$(jq -r --arg sid "$s_id" --argjson k "$k" '[.vertical_slices[] | select(.sprint_id == $sid)] [$k].traces_backlog // [] | if length == 0 then "None" else join(", ") end' "$state_path")"
        printf -- '- FR: %s\n' "$traces_fr"
        printf -- '- NFR: %s\n' "$traces_nfr"
        printf -- '- Backlog: %s\n\n' "$traces_backlog"

        # Demo criteria block (always emit the heading; lines if present).
        printf '##### Demo criteria\n\n'
        local crit_count
        crit_count="$(jq -r --arg sid "$s_id" --argjson k "$k" '[.vertical_slices[] | select(.sprint_id == $sid)] [$k].demo_criteria | length' "$state_path")"
        if [[ "$crit_count" -gt 0 ]]; then
          jq -r --arg sid "$s_id" --argjson k "$k" \
            '[.vertical_slices[] | select(.sprint_id == $sid)] [$k].demo_criteria[] | "- [ ] " + .' \
            "$state_path"
        else
          printf -- '- [ ] auto: <command> → expected: <exit code 0 | pattern>\n'
          printf -- '- [ ] user: <action> → expected: <observable outcome>\n'
        fi
        printf '\n'
      done
    done
  done
}

sf_roadmap_traceability_report() {
  local state_path srs_path backlog_path
  state_path="$(sf_roadmap_state_path)"
  if [[ ! -f "$state_path" ]]; then
    sf_log_error "roadmap state missing: $state_path"
    return 1
  fi
  srs_path="$(sf_resolve_output_path "srs" "docs/SRS.md")"
  backlog_path="$(sf_resolve_output_path "backlog" "docs/BACKLOG.md")"

  printf 'Requirement traceability report\n\n'
  _sf_roadmap_print_trace_group "FR" "$srs_path" "$state_path"
  printf '\n'
  _sf_roadmap_print_trace_group "NFR" "$srs_path" "$state_path"
  printf '\n'
  _sf_roadmap_print_trace_group "BACKLOG" "$backlog_path" "$state_path"
}

_sf_roadmap_print_trace_group() {
  local prefix="$1" source_path="$2" state_path="$3"
  printf '%s\n' "$prefix"
  if [[ ! -f "$source_path" ]]; then
    printf '%s\n' "- source missing: $source_path"
    return 0
  fi

  local ids
  ids="$(grep -Eo "${prefix}-[0-9]+" "$source_path" | sort -u)"
  if [[ -z "$ids" ]]; then
    printf '%s\n' "- no IDs found"
    return 0
  fi

  local id slices jq_field
  case "$prefix" in
    FR) jq_field='traces_fr' ;;
    NFR) jq_field='traces_nfr' ;;
    BACKLOG) jq_field='traces_backlog' ;;
    *) jq_field='traces_fr' ;;
  esac
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    slices="$(jq -r --arg id "$id" --arg field "$jq_field" '
      [.vertical_slices[] | select((.[$field] // []) | index($id)) | .id] | join(", ")
    ' "$state_path")"
    if [[ -n "$slices" ]]; then
      printf '%s\n' "- ${id}: ${slices}"
    else
      printf '%s\n' "- ${id}: unassigned"
    fi
  done <<< "$ids"
}

# ----------------------------------------------------------------------------
# PLAN T3.2 contract aliases (preserve both naming conventions)
# ----------------------------------------------------------------------------
sf_roadmap_init()           { sf_roadmap_state_init "$@"; }
sf_roadmap_get_checkpoint() { sf_roadmap_read_checkpoint "$@"; }
