#!/usr/bin/env bash
# setup.sh — workspace-level, idempotent: the Ossify project type must exist
# (UI-only), then task types, statuses and the agent role are added if missing.
BOARD_SPACE_TYPE="${BOARD_SPACE_TYPE:-Ossify project}"
BOARD_TYPE_DEF="${BOARD_TYPE_DEF:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/space-type.json}"

_board_tolerate_conflict() { # after a failed create: rc 0 if CONFLICT, else 1
  [ "$(board_cli_err_code)" = "CONFLICT" ] && return 0
  echo "board: $1 failed: $(board_cli_err_code) $(board_cli_err_message)" >&2; return 1
}

board_setup_workspace_type() {
  board_cli_space_types_list || { echo "board: cannot list space types: $(board_cli_err_code)" >&2; return 1; }
  if ! jq -e --arg t "$BOARD_SPACE_TYPE" '.[] | select(.name == $t)' "$BOARD_CLI_OUT" >/dev/null; then
    cat <<EOF
board: the space type '$BOARD_SPACE_TYPE' does not exist in workspace '${HULY_WORKSPACE:-?}'.
Create it once, by hand: Settings › Space types › + › category Tracker › based on Classic project › name '$BOARD_SPACE_TYPE'.
Then rerun /board:sync.
EOF
    return 5
  fi
  local has_role; has_role="$(jq -r --arg t "$BOARD_SPACE_TYPE" '.[] | select(.name == $t) | [.roles[]?.name] | index("agent") != null' "$BOARD_CLI_OUT")"

  board_cli_task_types_list "$BOARD_SPACE_TYPE" || { echo "board: cannot list task types: $(board_cli_err_code)" >&2; return 1; }
  local existing; existing="$BOARD_CLI_OUT"
  local tt
  for tt in $(jq -r '.task_types[]' "$BOARD_TYPE_DEF" | tr ' ' '_'); do
    tt="${tt//_/ }"
    if ! jq -e --arg n "$tt" '.[] | select(.name == $n)' "$existing" >/dev/null; then
      board_cli_task_type_create "$tt" "$BOARD_SPACE_TYPE" || _board_tolerate_conflict "task-types create $tt" || return 1
    fi
  done
  # statuses: per task type; a status missing on ANY task type is created type-wide
  # (issue-statuses create without --task-type adds it to every task type; a
  # CONFLICT on the ones that already have it is tolerated).
  local name cat
  while IFS=$'\t' read -r name cat; do
    local missing
    missing="$(jq -r --arg n "$name" --argjson want "$(jq -c '.task_types' "$BOARD_TYPE_DEF")" '
      [ .[] | select(.name as $t | $want | index($t)) | select(([.statuses[]?.name] | index($n)) == null) ] | length' "$existing")"
    if [ "${missing:-0}" != "0" ] || [ "$(jq 'length' "$existing")" = "0" ]; then
      board_cli_issue_status_create "$name" "$cat" "$BOARD_SPACE_TYPE" || _board_tolerate_conflict "issue-statuses create $name" || return 1
    fi
  done < <(jq -r '.statuses[] | "\(.name)\t\(.category)"' "$BOARD_TYPE_DEF")

  if [ "$has_role" != "true" ]; then
    board_cli_permissions_list || { echo "board: cannot list permissions: $(board_cli_err_code)" >&2; return 1; }
    local ids
    ids="$(jq -c --argjson allow "$(jq -c '.role.permission_name_allow' "$BOARD_TYPE_DEF")" --argjson deny "$(jq -c '.role.permission_name_deny' "$BOARD_TYPE_DEF")" '
      [ .[] | . as $p | (($p.name // "") + " " + ($p.label // "")) | ascii_downcase as $s
        | select( ($allow | map(ascii_downcase) | map(. as $w | $s | contains($w)) | any)
              and ($deny  | map(ascii_downcase) | map(. as $w | $s | contains($w)) | any | not) )
        | $p._id ]' "$BOARD_CLI_OUT")"
    board_cli_role_create "$BOARD_SPACE_TYPE" "$(jq -r '.role.name' "$BOARD_TYPE_DEF")" "$ids" || _board_tolerate_conflict "spaces roles create agent" || return 1
  fi
  return 0
}
