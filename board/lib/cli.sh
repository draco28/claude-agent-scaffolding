#!/usr/bin/env bash
# cli.sh — one function per Huly CLI operation the sync uses. Nothing else in
# the plugin spells a `huly` argv. stdout and stderr are kept in separate files
# (the CLI's failure document is JSON on stderr; see @firfi/huly-cli
# skills/huly-cli/references/automation.md).
BOARD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOARD_HULY_BIN="${BOARD_HULY_BIN:-$BOARD_LIB_DIR/../bin/huly-run}"
BOARD_CLI_OUT="${BOARD_CLI_OUT:-}"; BOARD_CLI_ERR="${BOARD_CLI_ERR:-}"

board_cli() { # runs the CLI with --json; rc = CLI rc; $BOARD_CLI_OUT/$BOARD_CLI_ERR are files
  # under a sync the files live in BOARD_ACT_DIR, which board_sync removes whole at exit —
  # a reconcile makes hundreds of CLI calls and each leaves two files. Previous files are
  # never deleted here: callers stash "$BOARD_CLI_OUT" across later calls (setup.sh does).
  BOARD_CLI_OUT="$(mktemp "${BOARD_ACT_DIR:-${TMPDIR:-/tmp}}/board-cli.out.XXXXXX")"
  BOARD_CLI_ERR="$(mktemp "${BOARD_ACT_DIR:-${TMPDIR:-/tmp}}/board-cli.err.XXXXXX")"
  local rc=0
  "$BOARD_HULY_BIN" "$@" --json >"$BOARD_CLI_OUT" 2>"$BOARD_CLI_ERR" || rc=$?
  return $rc
}
# the failure document is the LAST stderr line: the server prepends non-JSON warning lines
# ("no document found, failed to apply model transaction, …"), and a whole-file jq parse
# dies on the first one — every real code (CONFLICT included) then read as UNKNOWN
board_cli_err_code() { tail -1 "$BOARD_CLI_ERR" 2>/dev/null | jq -r '.code // "UNKNOWN"' 2>/dev/null || echo UNKNOWN; }
board_cli_err_message() { tail -1 "$BOARD_CLI_ERR" 2>/dev/null | jq -r '.message // ""' 2>/dev/null || true; }

# --- reads ---
board_cli_projects_list()      { board_cli projects list; }
board_cli_project_get()        { board_cli projects get "$1"; }                       # $1=identifier
board_cli_project_statuses()   { board_cli projects statuses "$1"; }                  # $1=identifier
board_cli_space_types_list()   { board_cli spaces types list; }
board_cli_task_types_list()    { board_cli task-types list --project-type "$1"; }     # $1=type name
board_cli_permissions_list()   { board_cli spaces permissions list; }
board_cli_milestones_list()    { board_cli milestones list --project "$1" --limit 200; }
board_cli_issues_list()        { board_cli issues list --project "$1" --title-search "$2" --limit 200; } # $2=substring
board_cli_relations_list()     { board_cli issues relations list --project "$1" --issue-identifier "$2"; }

# --- writes ---
board_cli_project_create()     { board_cli projects create "$1" "$2" --description "$3"; }   # name identifier desc
board_cli_task_type_create()   { board_cli task-types create "$1" --project-type "$2"; }     # name type
board_cli_issue_status_create(){ board_cli issue-statuses create "$1" "$2" --project-type "$3"; } # name category type
board_cli_role_create()        { board_cli spaces roles create "$1" "$2" "$3" --confirm --yes; } # type role permissionsJSON
board_cli_space_members_add()  { board_cli spaces members add "$1" "$2" --yes; }               # spaceName membersJSON
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
