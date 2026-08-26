#!/usr/bin/env bash
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/harness.sh"
ROOT="$HERE/.."; . "$ROOT/lib/cli.sh"
TMP="$(mktemp -d)"; export BOARD_FAKE_LOG="$TMP/calls.log" BOARD_FAKE_DIR="$TMP/fake"; mkdir -p "$BOARD_FAKE_DIR"

# huly-run refuses without env, naming the variable
t_capture env -u HULY_URL -u HULY_WORKSPACE -u HULY_TOKEN bash "$ROOT/bin/huly-run" projects list
t_assert_rc 2 "huly-run refuses without env"; t_assert_contains "$T_OUT" "HULY_URL" "names the missing variable"

# through the fake: --json appended, stdout captured, rc 0
export BOARD_HULY_BIN="$HERE/fake/huly"
echo '[{"identifier":"PTRD","name":"pulse-trader"}]' > "$BOARD_FAKE_DIR/projects.list.json"
board_cli projects list; RC=$?
t_assert_eq 0 "$RC" "fake list rc 0"
t_capture jq -r '.[0].identifier' "$BOARD_CLI_OUT"; t_assert_eq "PTRD" "$T_OUT" "stdout captured to file"
t_capture tail -1 "$BOARD_FAKE_LOG"; t_assert_eq "projects list --json" "$T_OUT" "call recorded with --json"

# failure: rc and code from stderr JSON
echo 5 > "$BOARD_FAKE_DIR/issues.get.rc"; echo '{"code":"NOT_FOUND","message":"no","retryable":false}' > "$BOARD_FAKE_DIR/issues.get.err"
board_cli issues get PTRD PTRD-999; RC=$?
t_assert_eq 5 "$RC" "failure rc propagated"; t_capture board_cli_err_code; t_assert_eq "NOT_FOUND" "$T_OUT" "error code parsed"

# operation wrappers produce the exact argv (positional vs flag forms)
: > "$BOARD_FAKE_LOG"
board_cli_project_create "pulse-trader" PTRD "desc"
board_cli_milestone_create PTRD "r1 — Release 1" 1756166400000 "$TMP/d.md"
board_cli_issue_create PTRD "r1.s1 — x" Spine planned "" "$TMP/d.md"
board_cli_issue_create PTRD "r1.s1.w1 — y" "Work item" planned PTRD-3 "$TMP/d.md"
board_cli_issue_update PTRD PTRD-3 --status active
board_cli_issue_milestone_set PTRD PTRD-3 "r1 — Release 1"
board_cli_issue_label_add PTRD PTRD-3 "spine:bone"
board_cli_relation_add PTRD PTRD-4 PTRD-3 is-blocked-by
board_cli_issues_list PTRD '^r1\.s1 '
t_capture sed -n '1p' "$BOARD_FAKE_LOG"; t_assert_eq "projects create pulse-trader PTRD --description desc --json" "$T_OUT" "projects create argv"
t_capture sed -n '2p' "$BOARD_FAKE_LOG"; t_assert_eq "milestones create PTRD r1 — Release 1 1756166400000 --description-file $TMP/d.md --json" "$T_OUT" "milestones create argv"
t_capture sed -n '3p' "$BOARD_FAKE_LOG"; t_assert_eq "issues create --project PTRD --title r1.s1 — x --task-type Spine --status planned --description-file $TMP/d.md --json" "$T_OUT" "issue create (no parent) argv"
t_capture sed -n '4p' "$BOARD_FAKE_LOG"; t_assert_eq "issues create --project PTRD --title r1.s1.w1 — y --task-type Work item --status planned --parent-issue PTRD-3 --description-file $TMP/d.md --json" "$T_OUT" "sub-issue create argv"
t_capture sed -n '5p' "$BOARD_FAKE_LOG"; t_assert_eq "issues update PTRD PTRD-3 --status active --json" "$T_OUT" "issue update argv"
t_capture sed -n '6p' "$BOARD_FAKE_LOG"; t_assert_eq "issues milestone set --project PTRD --identifier PTRD-3 --milestone r1 — Release 1 --json" "$T_OUT" "milestone set argv"
t_capture sed -n '7p' "$BOARD_FAKE_LOG"; t_assert_eq "issues labels add --project PTRD --identifier PTRD-3 --label spine:bone --json" "$T_OUT" "label add argv"
t_capture sed -n '8p' "$BOARD_FAKE_LOG"; t_assert_eq "issues relations add --project PTRD --issue-identifier PTRD-4 --target-issue PTRD-3 --relation-type is-blocked-by --json" "$T_OUT" "relation add argv"
t_capture sed -n '9p' "$BOARD_FAKE_LOG"; t_assert_eq "issues list --project PTRD --title-regex ^r1\\.s1  --limit 200 --json" "$T_OUT" "issues list argv"
t_summary
