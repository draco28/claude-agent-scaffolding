#!/usr/bin/env bash
# cli.sh — one function per Huly CLI operation the sync uses. Nothing else in
# the plugin spells a `huly` argv. stdout and stderr are kept in separate files
# (the CLI's failure document is JSON on stderr; see @firfi/huly-cli
# skills/huly-cli/references/automation.md).
BOARD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD_HULY_BIN="${BOARD_HULY_BIN:-$BOARD_LIB_DIR/../bin/huly-run}"
BOARD_CLI_OUT="${BOARD_CLI_OUT:-}"; BOARD_CLI_ERR="${BOARD_CLI_ERR:-}"

board_cli() { # runs the CLI with --json; rc = CLI rc; $BOARD_CLI_OUT/$BOARD_CLI_ERR are files
  BOARD_CLI_OUT="$(mktemp)"; BOARD_CLI_ERR="$(mktemp)"
  local rc=0
  "$BOARD_HULY_BIN" "$@" --json >"$BOARD_CLI_OUT" 2>"$BOARD_CLI_ERR" || rc=$?
  return $rc
}
board_cli_err_code() { jq -r '.code // "UNKNOWN"' "$BOARD_CLI_ERR" 2>/dev/null || echo UNKNOWN; }
board_cli_err_message() { jq -r '.message // ""' "$BOARD_CLI_ERR" 2>/dev/null || true; }

# --- reads ---
board_cli_projects_list()      { board_cli projects list; }
board_cli_project_get()        { board_cli projects get "$1"; }                       # $1=identifier
board_cli_project_statuses()   { board_cli projects statuses "$1"; }                  # $1=identifier
board_cli_space_types_list()   { board_cli spaces types list; }
board_cli_task_types_list()    { board_cli task-types list --project-type "$1"; }     # $1=type name
board_cli_permissions_list()   { board_cli spaces permissions list; }
board_cli_milestones_list()    { board_cli milestones list --project "$1" --limit 200; }
board_cli_issues_list()        { board_cli issues list --project "$1" --title-regex "$2" --limit 200; } # $2=regex
board_cli_relations_list()     { board_cli issues relations list --project "$1" --issue-identifier "$2"; }

# --- writes ---
board_cli_project_create()     { board_cli projects create "$1" "$2" --description "$3"; }   # name identifier desc
board_cli_space_create_typed() { board_cli spaces create "$1" "$2"; }                        # type name
board_cli_task_type_create()   { board_cli task-types create "$1" --project-type "$2"; }     # name type
board_cli_issue_status_create(){ board_cli issue-statuses create "$1" "$2" --project-type "$3"; } # name category type
board_cli_role_create()        { board_cli spaces roles create "$1" "$2" "$3" --confirm; }   # type role permissionsJSON
board_cli_milestone_create()   { board_cli milestones create "$1" "$2" "$3" --description-file "$4"; } # project label targetDateMs file
board_cli_milestone_update()   { local p="$1" m="$2"; shift 2; board_cli milestones update "$p" "$m" "$@"; }
board_cli_issue_create() { # project title taskType status parent(''=none) descFile
  if [ -n "$5" ]; then
    board_cli issues create --project "$1" --title "$2" --task-type "$3" --status "$4" --parent-issue "$5" --description-file "$6"
  else
    board_cli issues create --project "$1" --title "$2" --task-type "$3" --status "$4" --description-file "$6"
  fi
}
board_cli_issue_update()       { local p="$1" i="$2"; shift 2; board_cli issues update "$p" "$i" "$@"; }
board_cli_issue_milestone_set(){ board_cli issues milestone set --project "$1" --identifier "$2" --milestone "$3"; }
board_cli_issue_label_add()    { board_cli issues labels add --project "$1" --identifier "$2" --label "$3"; }
board_cli_relation_add()       { board_cli issues relations add --project "$1" --issue-identifier "$2" --target-issue "$3" --relation-type "$4"; }
board_cli_comment_add()        { board_cli comments add --project "$1" --issue-identifier "$2" --body-file "$3"; }
