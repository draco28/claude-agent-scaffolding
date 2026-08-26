#!/usr/bin/env bash
# sync.sh — reconcile the desired board (map.jq) against Huly. Keys are title
# prefixes. Creates and updates only; never deletes. Writes the digest only
# after every step succeeded.
BOARD_LIBS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_board_desc_file() { local f; f="$(mktemp)"; printf '%s\n' "$1" > "$f"; echo "$f"; }
_board_search_for_key() { printf '%s ' "$1"; } # --title-search is a case-insensitive substring, not a regex
_board_fail() { board_log "$1" "$2"; echo "board: $2" >&2; return 1; }
# key -> Huly identifier map for this run, as a TSV file (no bash-4 associative arrays: macOS ships bash 3.2)
_board_ident_set() { printf '%s\t%s\n' "$1" "$2" >> "$BOARD_ACT_DIR/ident.tsv"; }
_board_ident_get() { awk -F'\t' -v k="$1" '$1==k{print $2; f=1} END{exit f?0:1}' "$BOARD_ACT_DIR/ident.tsv"; }

# actual-board readers (answers cached per run in $BOARD_ACT_DIR)
# list shapes are data-dependent: when every matched record's creator has a person record the
# CLI emits a bare array (the recorded shape); when the result set includes a creator with NO
# person record (a fresh API-created agent account that never web-logged-in) it emits the raw
# `{"result":[...]}` wrapper instead — same flags, different shape. `.result? // .` unwraps
# both (the `?` matters: `.result` alone errors on a bare array, and jq's `//` does not catch
# runtime type errors, only null/false/empty results).
_board_actual_milestones() { board_cli_milestones_list "$1" || return 1; jq '(.result? // .)' "$BOARD_CLI_OUT" > "$BOARD_ACT_DIR/milestones.json"; }
_board_actual_issue() { # $1=project $2=key ; echoes JSON of the matching issue or "null"
  board_cli_issues_list "$1" "$(_board_search_for_key "$2")" || return 1
  jq -c --arg k "$2 " '(.result? // .) | map(select(.title | startswith($k))) | .[0] // null' "$BOARD_CLI_OUT"
}

board_sync() { # $1=ws-or-any-dir [--force] [--bind IDENT]
  local start="$1"; shift
  local force=0 bind=""
  while [ $# -gt 0 ]; do case "$1" in --force) force=1;; --bind) bind="$2"; shift;; esac; shift; done
  local ws project bare=0
  ws="$(board_resolve_workspace "$start")" || { [ -n "$bind" ] && { ws="$start"; bare=1; } || return 3; }
  [ -d "$ws/.ossify" ] || bare=1
  project="$(board_binding_read "$ws" 2>/dev/null)" || {
    [ -n "$bind" ] || return 4
    project="$bind"
  }
  export BOARD_ACT_DIR; BOARD_ACT_DIR="$(mktemp -d)"

  # digest gate
  local digest=""; if [ "$bare" = 0 ]; then digest="$(board_state_digest "$ws")"; fi
  if [ "$force" = 0 ] && [ "$bare" = 0 ] && [ "$digest" = "$(board_sync_read "$ws" '.digest')" ]; then
    jq -nc --arg p "$project" '{project:$p, skipped:"unchanged", created:0, updated:0, unchanged:0, relations_added:0}'; return 0
  fi

  # workspace type + project
  local rc=0; board_setup_workspace_type || rc=$?; [ "$rc" -ne 0 ] && return "$rc"
  if ! board_cli_project_get "$project"; then
    [ "$(board_cli_err_code)" = "NOT_FOUND" ] || _board_fail "$ws" "projects get $project: $(board_cli_err_code)" || return 1
    cat <<EOF
board: project '$project' does not exist in Tracker. Typed project creation is UI-only (the CLI
cannot do it): New project — name of the repo, identifier '$project', project type '$BOARD_SPACE_TYPE'.
Then rerun /board:sync --bind $project.
EOF
    return 6
  fi
  # Huly gates read visibility by space membership: a non-member account's writes persist
  # but its own reads (milestones/issues list) come back empty, so the mirror would create
  # blind duplicates and its create-then-update-by-label would fail to resolve. HULY_EMAIL is
  # optional; skip silently when unset. Fail-closed on the add itself is deliberate.
  local pname; pname="$(jq -r '.name // ""' "$BOARD_CLI_OUT")"
  if [ -n "${HULY_EMAIL:-}" ] && [ -n "$pname" ]; then
    board_cli_space_members_add "$pname" "[\"$HULY_EMAIL\"]" || _board_fail "$ws" "members add $pname: $(board_cli_err_code)" || return 1
  fi
  [ -n "$bind" ] && board_binding_write "$ws" "$project"
  if [ "$bare" = 1 ]; then
    jq -nc --arg p "$project" '{project:$p, skipped:"bare-binding", created:0, updated:0, unchanged:0, relations_added:0}'; return 0
  fi

  local desired; desired="$BOARD_ACT_DIR/desired.json"
  jq -f "$BOARD_LIBS/map.jq" "$ws/.ossify/project-state.json" > "$desired" || _board_fail "$ws" "map.jq failed on project-state.json" || return 1
  local created=0 updated=0 unchanged=0 rel=0
  : > "$BOARD_ACT_DIR/ident.tsv"

  # milestones
  _board_actual_milestones "$project" || _board_fail "$ws" "milestones list: $(board_cli_err_code) $(board_cli_err_message)" || return 1
  local key title status target desc actual
  while IFS=$'\t' read -r key title status target; do
    desc="$(jq -r --arg k "$key" '.milestones[] | select(.key==$k) | .description' "$desired")"
    actual="$(jq -c --arg k "$key " 'map(select(.label | startswith($k))) | .[0] // null' "$BOARD_ACT_DIR/milestones.json")"
    if [ "$actual" = "null" ]; then
      board_cli_milestone_create "$project" "$title" "$target" "$(_board_desc_file "$desc")" || _board_fail "$ws" "milestones create $key: $(board_cli_err_code) $(board_cli_err_message)" || return 1
      # milestones create has no status flag: it always lands as "planned". A non-planned
      # desired status is set right here, as part of creation, so it doesn't take a second
      # run to converge.
      if [ "$status" != "planned" ]; then
        board_cli_milestone_update "$project" "$title" --status "$status" || _board_fail "$ws" "milestones update $key status: $(board_cli_err_code)" || return 1
      fi
      created=$((created+1))
    else
      local a_label a_status; a_label="$(jq -r '.label' <<<"$actual")"; a_status="$(jq -r '.status // ""' <<<"$actual")"
      if [ "$a_label" != "$title" ] || [ "$a_status" != "$status" ]; then
        # the CLI takes ONE field per update call ("choose one input alternative")
        [ "$a_label" != "$title" ] && { board_cli_milestone_update "$project" "$a_label" --label "$title" || _board_fail "$ws" "milestones update $key label: $(board_cli_err_code)" || return 1; }
        [ "$a_status" != "$status" ] && { board_cli_milestone_update "$project" "$title" --status "$status" || _board_fail "$ws" "milestones update $key status: $(board_cli_err_code)" || return 1; }
        updated=$((updated+1))
      else unchanged=$((unchanged+1)); fi
    fi
  done < <(jq -r '.milestones[] | "\(.key)\t\(.title)\t\(.status)\t\(.target_ms)"' "$desired")

  # issues, spines then work items (map.jq order guarantees parents first)
  local tt parent_key milestone_key label parent_id
  while IFS=$'\t' read -r key title tt status milestone_key parent_key label; do
    desc="$(jq -r --arg k "$key" '.issues[] | select(.key==$k) | .description' "$desired")"
    actual="$(_board_actual_issue "$project" "$key")" || _board_fail "$ws" "issues list $key: $(board_cli_err_code)" || return 1
    parent_id=""; [ "$parent_key" != "null" ] && parent_id="$(_board_ident_get "$parent_key" || true)"
    if [ "$parent_key" != "null" ] && [ -z "$parent_id" ]; then
      local pj; pj="$(_board_actual_issue "$project" "$parent_key")" || return 1
      parent_id="$(jq -r '.identifier // ""' <<<"$pj")"
    fi
    if [ "$actual" = "null" ]; then
      board_cli_issue_create "$project" "$title" "$tt" "$status" "$parent_id" "$(_board_desc_file "$desc")" || _board_fail "$ws" "issues create $key: $(board_cli_err_code) $(board_cli_err_message)" || return 1
      _board_ident_set "$key" "$(jq -r '.identifier' "$BOARD_CLI_OUT")"
      [ "$milestone_key" != "null" ] && { board_cli_issue_milestone_set "$project" "$(_board_ident_get "$key")" "$(jq -r --arg k "$milestone_key" '.milestones[] | select(.key==$k) | .title' "$desired")" || _board_fail "$ws" "milestone set $key" || return 1; }
      [ "$label" != "null" ] && { board_cli_issue_label_add "$project" "$(_board_ident_get "$key")" "$label" || _board_fail "$ws" "labels add $key" || return 1; }
      created=$((created+1))
    else
      _board_ident_set "$key" "$(jq -r '.identifier' <<<"$actual")"
      local a_title a_status iid changed=0
      a_title="$(jq -r '.title' <<<"$actual")"; a_status="$(jq -r '.status.name? // .status // ""' <<<"$actual")"; iid="$(_board_ident_get "$key")"
      if [ "$a_title" != "$title" ]; then
        board_cli_issue_update "$project" "$iid" --title "$title" || _board_fail "$ws" "issues update $key title: $(board_cli_err_code) $(board_cli_err_message)" || return 1
        changed=1
      fi
      if [ "$a_status" != "$status" ]; then
        board_cli_issue_update "$project" "$iid" --status "$status" || _board_fail "$ws" "issues update $key status: $(board_cli_err_code) $(board_cli_err_message)" || return 1
        changed=1
      fi
      # milestone attachment: keyed by title prefix; reattach on mismatch, never detach
      if [ "$milestone_key" != "null" ]; then
        local a_ms; a_ms="$(jq -r '.milestone.label // ""' <<<"$actual")"
        case "$a_ms" in
          "$milestone_key "*) : ;;
          *) board_cli_issue_milestone_set "$project" "$iid" "$(jq -r --arg k "$milestone_key" '.milestones[] | select(.key==$k) | .title' "$desired")" || _board_fail "$ws" "milestone set $key" || return 1
             changed=1 ;;
        esac
      fi
      # label: compare only when the actual object exposes a labels field; add-only, never remove
      if [ "$label" != "null" ] && jq -e 'has("labels")' <<<"$actual" >/dev/null; then
        if ! jq -e --arg l "$label" '[.labels[]? | if type=="object" then (.title // .label // .name // "") else . end] | index($l)' <<<"$actual" >/dev/null; then
          if board_cli_issue_label_add "$project" "$iid" "$label"; then changed=1
          else [ "$(board_cli_err_code)" = "CONFLICT" ] || _board_fail "$ws" "labels add $key" || return 1; fi
        fi
      fi
      if [ "$changed" = 1 ]; then updated=$((updated+1)); else unchanged=$((unchanged+1)); fi
    fi
  done < <(jq -r '.issues[] | "\(.key)\t\(.title)\t\(.task_type)\t\(.status)\t\(.milestone_key)\t\(.parent_key)\t\(.label)"' "$desired")

  # relations: from is-blocked-by to
  local from to fid tid
  while IFS=$'\t' read -r from to; do
    fid="$(_board_ident_get "$from" || true)"; tid="$(_board_ident_get "$to" || true)"; [ -n "$fid" ] && [ -n "$tid" ] || continue
    board_cli_relations_list "$project" "$fid" || _board_fail "$ws" "relations list $from" || return 1
    if ! jq -e --arg t "$tid" '(.result? // .) | .blockedBy[]? | select(.identifier == $t)' "$BOARD_CLI_OUT" >/dev/null; then
      if board_cli_relation_add "$project" "$fid" "$tid" is-blocked-by; then rel=$((rel+1))
      else [ "$(board_cli_err_code)" = "CONFLICT" ] || _board_fail "$ws" "relations add $from -> $to: $(board_cli_err_code)" || return 1; fi
    fi
  done < <(jq -r '.relations[] | "\(.from_key)\t\(.to_key)"' "$desired")

  board_sync_write "$ws" "$(jq -nc --arg p "$project" --arg d "$digest" --arg t "$(_board_now)" '{project:$p, digest:$d, synced_at:$t, branches:{}, sessions:{}, handoffs_seen:[]}')"
  jq -nc --arg p "$project" --argjson c "$created" --argjson u "$updated" --argjson n "$unchanged" --argjson r "$rel" '{project:$p, skipped:null, created:$c, updated:$u, unchanged:$n, relations_added:$r}'
}
