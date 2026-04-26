#!/usr/bin/env bash
# scaffold/lib/slice.sh — slice workflow state machine and helpers.
#
# 5-phase pipeline:
#   spec → contract → scaffold → implement → verify → complete
#
# Slice state lives at state.slices[<id>] = {
#   name, number, phase, spec_path,
#   acceptance_criteria: [{id, text, status}],
#   last_test_result: {exit_code, summary, captured_at} | null,
#   test_command,
#   created_at, updated_at
# }
#
# Sources lib/state.sh + lib/repo.sh.

SF_SLICE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./state.sh
source "${SF_SLICE_LIB_DIR}/state.sh"

# ── Slug + ID + numbering ───────────────────────────────────────────────────

# sf_slice_slug — alias of sf_slug (in lib/repo.sh) for slice-naming clarity.
sf_slice_slug() {
  sf_slug "$1"
}

# sf_slice_format_number — zero-pad to 2 digits up to 99; raw beyond.
sf_slice_format_number() {
  local n="$1"
  if (( n <= 99 )); then
    printf '%02d' "$n"
  else
    printf '%d' "$n"
  fi
}

# sf_slice_format_id — produce "slice-NN-<slug>".
sf_slice_format_id() {
  local n="$1" name="$2"
  printf 'slice-%s-%s' "$(sf_slice_format_number "$n")" "$(sf_slice_slug "$name")"
}

# sf_slice_next_number — max existing slice number + 1, or 1 if none.
sf_slice_next_number() {
  local n
  n="$(sf_read_state | jq '[.slices[].number // 0] | max // 0' 2>/dev/null)"
  [[ -z "$n" || "$n" == "null" ]] && n=0
  echo $((n + 1))
}

# sf_slice_spec_path — relative path to spec file for a slice id.
sf_slice_spec_path() {
  printf 'docs/slices/%s.md' "$1"
}

# ── Read helpers ────────────────────────────────────────────────────────────

# sf_current_slice — id of the current slice, or empty.
sf_current_slice() {
  sf_state_get current_slice
}

# sf_slice_phase <id> — phase string for a slice; empty if unknown.
sf_slice_phase() {
  local id="$1"
  sf_state_get_path ".slices[\"${id}\"].phase"
}

# sf_slice_exists <id> — exit 0 if a slice with that id is in state.
sf_slice_exists() {
  local id="$1"
  local found
  found="$(sf_read_state | jq -r ".slices | has(\"${id}\")" 2>/dev/null)"
  [[ "$found" == "true" ]]
}

# sf_slice_in_progress — exit 0 if any slice is in a non-complete phase.
sf_slice_in_progress() {
  local count
  count="$(sf_read_state | jq '[.slices[] | select(.phase != "complete")] | length' 2>/dev/null)"
  [[ -n "$count" && "$count" -gt 0 ]]
}

# sf_slice_get_field <id> <jq-subpath> — read any subfield of a slice.
sf_slice_get_field() {
  local id="$1" subpath="$2"
  sf_state_get_path ".slices[\"${id}\"].${subpath}"
}

# ── Acceptance-criteria parsing from spec file ──────────────────────────────

# sf_slice_parse_acs <spec_path> — emit JSON array of AC objects from a spec.
# Looks for lines like "- [ ] **AC-1:** text" or "- [x] AC-1: text".
sf_slice_parse_acs() {
  local path="$1"
  if [[ ! -r "$path" ]]; then
    echo '[]'
    return 0
  fi
  awk '
    /^[[:space:]]*-[[:space:]]+\[([[:space:]xX])\][[:space:]]+\*?\*?(AC-?[0-9]+)/ {
      line = $0
      # Determine status from [ ] vs [x]
      status = (match(line, /\[[xX]\]/) > 0) ? "passing" : "pending"
      # Extract AC id
      match(line, /AC-?[0-9]+/)
      id = substr(line, RSTART, RLENGTH)
      gsub(/-/, "-", id)  # normalize
      # Extract text after the AC id and optional colon/asterisks
      text_start = RSTART + RLENGTH
      text = substr(line, text_start)
      gsub(/^[:* ]+/, "", text)
      gsub(/\\\\/, "\\\\", text)
      gsub(/"/, "\\\"", text)
      printf "{\"id\":\"%s\",\"text\":\"%s\",\"status\":\"%s\"}\n", id, text, status
    }
  ' "$path" | jq -s . 2>/dev/null || echo '[]'
}

# sf_slice_count_acs <spec_path> — number of AC items in the spec.
sf_slice_count_acs() {
  sf_slice_parse_acs "$1" | jq 'length' 2>/dev/null || echo 0
}

# ── Slice creation ──────────────────────────────────────────────────────────

# sf_slice_create <name> [--force]
# - Allocates next number on the branch
# - Generates spec file from template
# - Writes slice entry to state.slices, sets current_slice
# - Refuses if a slice is in progress unless --force is set
# Echoes the slice id on success.
sf_slice_create() {
  local name="$1" force="${2:-}"
  if [[ -z "$name" ]]; then
    echo "sf_slice_create: name required" >&2
    return 1
  fi

  if sf_slice_in_progress && [[ "$force" != "--force" ]]; then
    local current; current="$(sf_current_slice)"
    echo "scaffold: a slice is already in progress: ${current}" >&2
    echo "  - finish it (run /slice-verify when tests pass) or pass --force to /slice-new to suspend it." >&2
    return 1
  fi

  local n id spec_path
  n="$(sf_slice_next_number)"
  id="$(sf_slice_format_id "$n" "$name")"

  if sf_slice_exists "$id"; then
    echo "scaffold: slice ${id} already exists in this branch's state" >&2
    return 1
  fi

  spec_path="$(sf_slice_spec_path "$id")"
  local repo_root; repo_root="$(sf_repo_root)"
  mkdir -p "${repo_root}/docs/slices"

  local tmpl; tmpl="${CLAUDE_PLUGIN_ROOT:-${SF_SLICE_LIB_DIR}/..}/templates/slice-spec.md.tmpl"
  local now; now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local branch; branch="$(sf_branch)"
  local test_cmd; test_cmd="$(sf_test_command)"
  [[ -z "$test_cmd" ]] && test_cmd="(detect when entering /slice-contract)"

  if [[ -r "$tmpl" ]]; then
    sed -e "s|{{number}}|${n}|g" \
        -e "s|{{name}}|${name}|g" \
        -e "s|{{date}}|${now}|g" \
        -e "s|{{branch}}|${branch}|g" \
        -e "s|{{test_command}}|${test_cmd}|g" \
        "$tmpl" > "${repo_root}/${spec_path}"
  else
    {
      echo "# Slice ${n}: ${name}"
      echo ""
      echo "**Status:** spec"
      echo ""
      echo "## Acceptance criteria"
      echo ""
      echo "- [ ] **AC-1:** TODO"
    } > "${repo_root}/${spec_path}"
  fi

  # Write slice entry to state
  local slice_obj
  slice_obj="$(jq -n --arg id "$id" --arg name "$name" --argjson n "$n" \
                     --arg spec_path "$spec_path" --arg now "$now" \
                     --arg test_cmd "$test_cmd" \
    '{
      name: $name, number: $n, phase: "spec", spec_path: $spec_path,
      acceptance_criteria: [], last_test_result: null,
      test_command: $test_cmd, created_at: $now, updated_at: $now
    }')"
  sf_state_apply_typed ".slices[\"${id}\"] = \$val | .current_slice = \"${id}\"" "$slice_obj"

  echo "$id"
}

# sf_slice_refresh_acs <id> — re-parse the spec file's ACs into state.
sf_slice_refresh_acs() {
  local id="$1"
  local spec_path; spec_path="$(sf_slice_get_field "$id" spec_path)"
  if [[ -z "$spec_path" ]]; then
    return 1
  fi
  local repo_root; repo_root="$(sf_repo_root)"
  local full="${repo_root}/${spec_path}"
  local acs; acs="$(sf_slice_parse_acs "$full")"
  sf_state_apply_typed ".slices[\"${id}\"].acceptance_criteria = \$val" "$acs"
}

# ── Phase transitions ───────────────────────────────────────────────────────

# All sf_slice_phase_<X> functions share the same pattern:
# 1. Load current slice id
# 2. Verify gate prerequisite (spec/contract/scaffold/etc.)
# 3. Run any side-effect (e.g., test command for verify)
# 4. Update state.slices[<id>].phase
# 5. Emit a status line on stdout for the prose to consume
#
# All return non-zero with a message on stderr if the gate fails.

# sf_slice_phase_spec — re-enter spec phase (always allowed).
# Re-parses ACs from the spec file into state.
sf_slice_phase_spec() {
  local id; id="$(sf_current_slice)"
  if [[ -z "$id" ]]; then
    echo "scaffold: no current slice. Run /slice-new <name> first." >&2
    return 1
  fi
  sf_slice_refresh_acs "$id"
  sf_state_apply ".slices[\"${id}\"].phase = \"spec\""
  echo "phase: spec  slice: ${id}"
}

# sf_slice_phase_contract — gate: spec exists + ≥1 AC.
sf_slice_phase_contract() {
  local id; id="$(sf_current_slice)"
  if [[ -z "$id" ]]; then
    echo "scaffold: no current slice. Run /slice-new <name> first." >&2
    return 1
  fi
  local spec_path; spec_path="$(sf_slice_get_field "$id" spec_path)"
  local repo_root; repo_root="$(sf_repo_root)"
  local full="${repo_root}/${spec_path}"
  if [[ ! -r "$full" ]]; then
    echo "scaffold: spec file missing: ${spec_path}. Run /slice-spec." >&2
    return 1
  fi
  sf_slice_refresh_acs "$id"
  local count; count="$(sf_slice_count_acs "$full")"
  if [[ "$count" -lt 1 ]]; then
    echo "scaffold: spec has no acceptance criteria. Add at least one '- [ ] **AC-1:** ...' line, then re-run /slice-contract." >&2
    return 1
  fi
  # Re-detect test command (might have changed since /slice-new)
  local test_cmd; test_cmd="$(sf_test_command)"
  if [[ -n "$test_cmd" ]]; then
    sf_state_apply ".slices[\"${id}\"].test_command = \"${test_cmd}\""
  fi
  sf_state_apply ".slices[\"${id}\"].phase = \"contract\""
  echo "phase: contract  slice: ${id}  acs: ${count}  test_cmd: ${test_cmd:-(none detected)}"
}

# sf_slice_phase_scaffold — gate: prior phase ∈ {contract, scaffold}.
# We don't actually verify "tests are failing" here because that requires
# running the test command which may be expensive; we trust the user advanced
# from contract correctly. /slice-implement re-checks.
sf_slice_phase_scaffold() {
  local id; id="$(sf_current_slice)"
  if [[ -z "$id" ]]; then
    echo "scaffold: no current slice." >&2; return 1
  fi
  local prior; prior="$(sf_slice_phase "$id")"
  case "$prior" in
    contract|scaffold|implement) ;;
    *)
      echo "scaffold: cannot enter scaffold phase from phase=${prior}. Run /slice-contract first." >&2
      return 1
      ;;
  esac
  sf_state_apply ".slices[\"${id}\"].phase = \"scaffold\""
  echo "phase: scaffold  slice: ${id}"
}

# sf_slice_phase_implement — gate: prior phase ∈ {scaffold, implement}.
sf_slice_phase_implement() {
  local id; id="$(sf_current_slice)"
  if [[ -z "$id" ]]; then
    echo "scaffold: no current slice." >&2; return 1
  fi
  local prior; prior="$(sf_slice_phase "$id")"
  case "$prior" in
    scaffold|implement|verify) ;;
    *)
      echo "scaffold: cannot enter implement phase from phase=${prior}. Run /slice-scaffold first." >&2
      return 1
      ;;
  esac
  sf_state_apply ".slices[\"${id}\"].phase = \"implement\""
  echo "phase: implement  slice: ${id}"
}

# sf_slice_phase_verify — actually runs the test command, captures result.
# - If exit 0: phase → complete; emits "verified" status.
# - Else: phase → verify; captures last_test_result; emits "failing" status.
# Always returns 0 (we don't want bash's set -e to abort the prose flow).
sf_slice_phase_verify() {
  local id; id="$(sf_current_slice)"
  if [[ -z "$id" ]]; then
    echo "scaffold: no current slice." >&2; return 1
  fi
  local prior; prior="$(sf_slice_phase "$id")"
  case "$prior" in
    implement|verify|scaffold) ;;
    *)
      echo "scaffold: cannot enter verify from phase=${prior}. Run /slice-implement first." >&2
      return 1
      ;;
  esac

  local test_cmd; test_cmd="$(sf_slice_get_field "$id" test_command)"
  # Re-detect if missing/placeholder
  if [[ -z "$test_cmd" || "$test_cmd" == "(detect when entering /slice-contract)" ]]; then
    test_cmd="$(sf_test_command)"
    [[ -n "$test_cmd" ]] && sf_state_apply ".slices[\"${id}\"].test_command = \"${test_cmd}\""
  fi
  if [[ -z "$test_cmd" ]]; then
    echo "scaffold: no test command available. Set up a test framework (pytest/vitest/jest/cargo/go) and re-run /slice-verify." >&2
    return 1
  fi

  local repo_root; repo_root="$(sf_repo_root)"
  local out_file; out_file="$(mktemp)"
  local exit_code
  ( cd "$repo_root" && eval "$test_cmd" ) >"$out_file" 2>&1
  exit_code=$?

  local summary
  summary="$(tail -10 "$out_file" | head -10)"
  local now; now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  local result
  result="$(jq -n --argjson code "$exit_code" --arg summary "$summary" --arg now "$now" \
    '{exit_code: $code, summary: $summary, captured_at: $now}')"
  sf_state_apply_typed ".slices[\"${id}\"].last_test_result = \$val" "$result"

  if [[ "$exit_code" -eq 0 ]]; then
    sf_state_apply ".slices[\"${id}\"].phase = \"complete\""
    echo "phase: complete  slice: ${id}  test_cmd: ${test_cmd}"
    echo "all tests passed"
  else
    sf_state_apply ".slices[\"${id}\"].phase = \"verify\""
    echo "phase: verify  slice: ${id}  test_cmd: ${test_cmd}  exit_code: ${exit_code}"
    echo "tests failing — last 10 lines of output:"
    cat "$out_file" | tail -10
  fi
  rm -f "$out_file"
  return 0
}

# ── List/status renderers ───────────────────────────────────────────────────

# sf_slice_list_table — emit a markdown table of all slices on this branch.
sf_slice_list_table() {
  local rows
  rows="$(sf_read_state | jq -r '
    (.slices | to_entries | sort_by(.value.number) // []) as $entries
    | if ($entries | length) == 0 then
        "_(no slices yet — start one with /slice-new <name>)_"
      else
        "| # | Slice | Phase | ACs | Created |\n|---|---|---|---|---|\n" +
        ($entries | map(
          "| \(.value.number) | \(.key) | \(.value.phase) | \(.value.acceptance_criteria | length) | \(.value.created_at | split("T")[0]) |"
        ) | join("\n"))
      end
  ' 2>/dev/null)"
  echo "$rows"
}
