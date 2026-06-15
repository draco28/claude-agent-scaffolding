#!/usr/bin/env bash
# scaffold-dev/lib/roadmap.sh
# Consumer-side field-read of the structured roadmap state that scaffold-onboard
# publishes (project-roadmap.json) into the workspace contract path declared by
# the manifest's well_known_paths.roadmap_state (#28 Phase 3).
#
# This is the replacement for the old, brittle approach of grepping a rendered
# `#### VS-…:` heading out of ROADMAP.md and string-splitting the slice id to
# guess the sprint. Here we resolve the published JSON and read `id` + `sprint_id`
# as explicit fields — no id parsing, so a 3-part id (VS-<phase>.<sprint>.<slice>)
# can never be mis-derived into the wrong sprint.

set -u

_SD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F sd_log_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/_helpers.sh"
fi
if ! declare -F sd_manifest_discover >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$_SD_LIB_DIR/manifest.sh"
fi

# sd_roadmap_state_path — resolve the absolute path of the published structured
# roadmap state (project-roadmap.json). Honors the manifest's routed
# well_known_paths.roadmap_state; falls back to the canonical workspace location
# for older manifests (pre workspace-init 0.1.2) that lack the key. Echoes the
# path (the file may or may not exist yet); returns 1 with no manifest or an
# unresolved path. Symmetric with scaffold-onboard's sf_roadmap_publish_state.
sd_roadmap_state_path() {
  local manifest ai_root routed dest
  manifest="$(sd_manifest_discover)" || { sd_log_error "sd_roadmap_state_path: no workspace manifest (walked up from $PWD)"; return 1; }
  ai_root="$(jq -r '.ai_workspace.root // empty' "$manifest" 2>/dev/null)"
  [[ -n "$ai_root" ]] || { sd_log_error "sd_roadmap_state_path: manifest missing ai_workspace.root"; return 1; }
  ai_root="${ai_root//\$\{HOME\}/$HOME}"
  ai_root="${ai_root//\$\{USER\}/${USER:-$(id -un 2>/dev/null)}}"
  routed="$(jq -r '.well_known_paths.roadmap_state // empty' "$manifest" 2>/dev/null)"
  if [[ -n "$routed" ]]; then
    dest="$(sd_manifest_resolve "$ai_root" "$routed")" || return 1
  else
    dest="$ai_root/.workspace/project-roadmap.json"
  fi
  if [[ -z "$dest" || "$dest" == *'${'* ]]; then
    sd_log_error "sd_roadmap_state_path: unresolved roadmap_state path: '${dest:-<empty>}' (from '$routed')"
    return 1
  fi
  echo "$dest"
}

# sd_roadmap_slice_json <slice-id> — echo the JSON record for the vertical slice
# whose `id` matches EXACTLY, or fail (listing available ids) if none match.
# This is an exact-id field-read, never a heading grep or id string-split.
sd_roadmap_slice_json() {
  local id="$1" state rec avail
  [[ -n "$id" ]] || { sd_log_error "sd_roadmap_slice_json: empty slice id"; return 1; }
  state="$(sd_roadmap_state_path)" || return 1
  if [[ ! -f "$state" ]]; then
    sd_log_error "sd_roadmap_slice_json: structured roadmap not published at $state — run /plan-roadmap (scaffold-onboard) to publish project-roadmap.json"
    return 1
  fi
  rec="$(jq -c --arg id "$id" '.vertical_slices[]? | select(.id == $id)' "$state" 2>/dev/null)"
  if [[ -z "$rec" ]]; then
    avail="$(jq -r '[.vertical_slices[]?.id] | join(", ")' "$state" 2>/dev/null)"
    sd_log_error "sd_roadmap_slice_json: no slice '$id' in roadmap ($state). Available: ${avail:-<none>}"
    return 1
  fi
  echo "$rec"
}

# sd_roadmap_slice_field <slice-id> <field> — echo a single field from the slice
# record (e.g. sprint_id, slice_name). Fails if the slice or field is absent.
sd_roadmap_slice_field() {
  local id="$1" field="$2" rec val
  rec="$(sd_roadmap_slice_json "$id")" || return 1
  val="$(printf '%s' "$rec" | jq -r --arg f "$field" '.[$f] // empty' 2>/dev/null)"
  if [[ -z "$val" ]]; then
    sd_log_error "sd_roadmap_slice_field: slice '$id' has no '$field' field"
    return 1
  fi
  echo "$val"
}

# sd_roadmap_slice_sprint_id <slice-id> — convenience accessor for the field the
# orchestrator needs most: the slice's sprint_id (e.g. "1.1" for VS-1.1.1). Path
# derivation (sprint dir, branch name) keys off this, NOT off splitting the id.
sd_roadmap_slice_sprint_id() {
  sd_roadmap_slice_field "$1" "sprint_id"
}

# sd_roadmap_next_slice <slice-id> — echo the id of the NEXT vertical slice in the
# same sprint: the slice whose 3rd id-field index is the smallest value greater
# than this slice's index. Echoes nothing (rc 0) when this is the final slice of
# its sprint. Returns 1 only on a real lookup failure (no manifest, unpublished
# state, unknown slice) — propagated from sd_roadmap_slice_sprint_id, which gates
# both file existence and slice presence. `sort_by` keeps this robust to roadmap
# array order; we never assume the slices are stored sorted. Single source of
# truth for "what comes after this slice" — closing-vertical-slice §11.1
# (final-slice detection) and the close-time active-context reconcile both call it.
sd_roadmap_next_slice() {
  local id="$1" sprint state cur_idx
  [[ -n "$id" ]] || { sd_log_error "sd_roadmap_next_slice: empty slice id"; return 1; }
  sprint="$(sd_roadmap_slice_sprint_id "$id")" || return 1
  state="$(sd_roadmap_state_path)" || return 1
  cur_idx="${id##*.}"
  jq -r --arg sid "$sprint" --argjson cur "$cur_idx" '
    [ .vertical_slices[]?
      | select(.sprint_id == $sid)
      | (.id | sub("^VS-"; "") | split(".") | .[2] | tonumber) as $idx
      | select($idx > $cur)
      | {idx: $idx, id: .id} ]
    | sort_by(.idx) | .[0].id // empty' "$state"
}

# sd_roadmap_next_sprint <sprint-id> — echo the id of the NEXT sprint in roadmap
# order (the entry after this one in the `sprints[]` array), or nothing (rc 0)
# when this is the final sprint. Sprint ids are dotted (e.g. "1.1") so the "next"
# sprint is an array-order lookup, never an integer +1. Returns 1 on no manifest
# or unpublished state. Lifted verbatim from the §11.1 inline next-sprint jq so
# the sprint-final "Next up" pointer and the §11.2 carry-forward sweep agree.
sd_roadmap_next_sprint() {
  local sid="$1" state
  [[ -n "$sid" ]] || { sd_log_error "sd_roadmap_next_sprint: empty sprint id"; return 1; }
  state="$(sd_roadmap_state_path)" || return 1
  if [[ ! -f "$state" ]]; then
    sd_log_error "sd_roadmap_next_sprint: structured roadmap not published at $state — run /plan-roadmap (scaffold-onboard)"
    return 1
  fi
  jq -r --arg sid "$sid" '
    (.sprints // [] | map(.id)) as $ids
    | ($ids | index($sid)) as $i
    | if $i == null or ($i + 1) >= ($ids | length) then empty else $ids[$i + 1] end
  ' "$state"
}
