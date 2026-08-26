#!/usr/bin/env bash
# setup.sh — workspace-level, idempotent: the Ossify project type must exist
# (UI-only), then task types, statuses and the agent role are added if missing.
BOARD_SPACE_TYPE="${BOARD_SPACE_TYPE:-Ossify project}"
BOARD_TYPE_DEF="${BOARD_TYPE_DEF:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/space-type.json}"

_board_tolerate_conflict() { # after a failed create: rc 0 if CONFLICT, else 1
  [ "$(board_cli_err_code)" = "CONFLICT" ] && return 0
  echo "board: $1 failed: $(board_cli_err_code) $(board_cli_err_message)" >&2; return 1
}

_board_seed_spine_instruction() { # $1 = "does not exist" | "exists but has no task types"
  cat <<EOF
board: the space type '$BOARD_SPACE_TYPE' $1 in workspace '${HULY_WORKSPACE:-?}'.
Create it once, by hand: Settings › Space types › + › category Tracker › based on Classic project ›
name '$BOARD_SPACE_TYPE' — and seed its first task type 'Spine' in the type's Task types section.
The CLI can only copy an existing task type, never create the first one.
Then rerun /board:sync.
EOF
}

board_setup_workspace_type() {
  local rc=0
  board_cli_task_types_list "$BOARD_SPACE_TYPE" || rc=$?
  if [ "$rc" -ne 0 ]; then
    if [ "$(board_cli_err_code)" = "INTEGRATION_FAILED" ]; then
      _board_seed_spine_instruction "does not exist"
      return 5
    fi
    echo "board: cannot list task types: $(board_cli_err_code) $(board_cli_err_message)" >&2
    return 1
  fi
  local existing; existing="$BOARD_CLI_OUT"
  if [ "$(jq -r '.taskTypes | length' "$existing")" = "0" ]; then
    _board_seed_spine_instruction "exists but has no task types"
    return 5
  fi

  local tt
  for tt in $(jq -r '.task_types[]' "$BOARD_TYPE_DEF" | tr ' ' '_'); do
    tt="${tt//_/ }"
    if ! jq -e --arg n "$tt" '.taskTypes[] | select(.name == $n)' "$existing" >/dev/null; then
      board_cli_task_type_create "$tt" "$BOARD_SPACE_TYPE" || _board_tolerate_conflict "task-types create $tt" || return 1
    fi
  done

  # statuses: creation is idempotent server-side (rc 0, "created": false on a repeat),
  # so every status is created unconditionally rather than diffed against the listing
  # (the task-types listing carries no per-type status names to diff against).
  local name cat
  while IFS=$'\t' read -r name cat; do
    board_cli_issue_status_create "$name" "$cat" "$BOARD_SPACE_TYPE" || _board_tolerate_conflict "issue-statuses create $name" || return 1
  done < <(jq -r '.statuses[] | "\(.name)\t\(.category)"' "$BOARD_TYPE_DEF")

  # role: no roles enumeration exists, so this is create-and-tolerate every run
  # (a duplicate create returns CONFLICT without overwriting the existing role).
  board_cli_permissions_list || { echo "board: cannot list permissions: $(board_cli_err_code)" >&2; return 1; }
  local ids
  ids="$(jq -c --argjson allow "$(jq -c '.role.permission_name_allow' "$BOARD_TYPE_DEF")" --argjson deny "$(jq -c '.role.permission_name_deny' "$BOARD_TYPE_DEF")" '
    [ .permissions[] | . as $p | (($p.id // "") + " " + ($p.label // "")) | ascii_downcase as $s
      | select( ($allow | map(ascii_downcase) | map(. as $w | $s | contains($w)) | any)
            and ($deny  | map(ascii_downcase) | map(. as $w | $s | contains($w)) | any | not) )
      | $p.id ]' "$BOARD_CLI_OUT")"
  board_cli_role_create "$BOARD_SPACE_TYPE" "$(jq -r '.role.name' "$BOARD_TYPE_DEF")" "$ids" || _board_tolerate_conflict "spaces roles create agent" || return 1
  return 0
}
