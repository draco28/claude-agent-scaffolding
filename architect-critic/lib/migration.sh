#!/usr/bin/env bash
# lib/migration.sh — v0.1.x → v0.2 first-run migration (SPEC §10).
# macOS bash 3.2 portable. BSD-portable date and mv.
#
# Public entry point:
#   ac_migration_check_v01_state — orchestrator; runs SPEC §10 steps 1–4.
# Helpers:
#   ac_migration_backup_state         — rename old state.json → .bak (with collision suffix).
#   ac_migration_move_inbox_outbox    — move inbox/ and outbox/ to legacy-v0.1.x/.
#   ac_migration_prepend_shipped_defaults — prepend shipped principles above existing user content.
#
# CLI: `bash lib/migration.sh check-v01-state`

_AC_MIG_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! command -v ac_log_info >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  source "$_AC_MIG_LIB_DIR/_helpers.sh"
fi
if ! command -v ac_state_init >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  source "$_AC_MIG_LIB_DIR/state.sh"
fi

# Resolve the plugin root once (parent of lib/) for templates lookup.
_AC_MIG_PLUGIN_DIR="$(cd "$_AC_MIG_LIB_DIR/.." && pwd)"

# Internal: returns the architect-critic data dir under $HOME for migration.
# Migration deliberately reads from $HOME (not CLAUDE_PLUGIN_DATA) per SPEC §10
# so first-run upgrade detection is portable across users / sessions.
_ac_migration_home_dir() {
  echo "$HOME/.claude/architect-critic"
}

# ---------------------------------------------------------------------------
# ac_migration_backup_state
# Rename $HOME/.claude/architect-critic/state.json → state.json.v0.1.3.bak
# If the .bak already exists, append .<unix-ts> to avoid clobbering.
# Then re-initialise a fresh schema v2 state.json in the same dir.
# Returns 0 always (no-op when state.json is missing or already at schema v2).
# Echoes the bak path to stdout when a rename occurred (empty otherwise).
# ---------------------------------------------------------------------------
ac_migration_backup_state() {
  local data_dir state_file schema_ver bak_target unix_ts
  data_dir="$(_ac_migration_home_dir)"
  state_file="$data_dir/state.json"

  [[ -f "$state_file" ]] || return 0

  # Read schema_version; default to 0 if jq fails or field missing.
  schema_ver="$(jq -r '.schema_version // 0' "$state_file" 2>/dev/null || echo 0)"
  # Skip when already at schema v2 or above.
  if [[ "$schema_ver" =~ ^[0-9]+$ ]] && [[ "$schema_ver" -ge 2 ]] 2>/dev/null; then
    return 0
  fi

  bak_target="$data_dir/state.json.v0.1.3.bak"
  if [[ -e "$bak_target" ]]; then
    unix_ts="$(date -u +%s)"
    bak_target="${bak_target}.${unix_ts}"
    # Defensive: if the timestamped path also collides (unlikely), bail.
    if [[ -e "$bak_target" ]]; then
      ac_log_error "migration: both state.json.v0.1.3.bak and ${bak_target} already exist; aborting backup"
      return 1
    fi
  fi

  mv "$state_file" "$bak_target" || {
    ac_log_error "migration: failed to rename state.json to $bak_target"
    return 1
  }

  # Re-initialise fresh schema v2 state.json. ac_state_init reads from
  # ac_data_dir → CLAUDE_PLUGIN_DATA, so override it for this call only.
  (
    CLAUDE_PLUGIN_DATA="$data_dir"
    export CLAUDE_PLUGIN_DATA
    ac_state_init
  )

  echo "$bak_target"
  return 0
}

# ---------------------------------------------------------------------------
# ac_migration_move_inbox_outbox
# Move $HOME/.claude/architect-critic/{inbox,outbox} (if present) into
# $HOME/.claude/architect-critic/legacy-v0.1.x/. Preserves contents.
# No-op when neither dir exists. Returns 0.
# ---------------------------------------------------------------------------
ac_migration_move_inbox_outbox() {
  local data_dir legacy_dir sub
  data_dir="$(_ac_migration_home_dir)"
  legacy_dir="$data_dir/legacy-v0.1.x"

  local moved=0
  for sub in inbox outbox; do
    if [[ -d "$data_dir/$sub" ]]; then
      mkdir -p "$legacy_dir" || {
        ac_log_error "migration: failed to create $legacy_dir"
        return 1
      }
      # If a previous legacy/<sub> already exists, append unix-ts to keep both.
      local target="$legacy_dir/$sub"
      if [[ -e "$target" ]]; then
        target="${target}.$(date -u +%s)"
      fi
      mv "$data_dir/$sub" "$target" || {
        ac_log_error "migration: failed to move $sub to $target"
        return 1
      }
      moved=1
    fi
  done

  return 0
}

# ---------------------------------------------------------------------------
# ac_migration_prepend_shipped_defaults
# Preserves user-authored principles.md by prepending the plugin's shipped
# defaults block above the existing content, marked with an HTML comment.
# No-op when principles.md is missing OR when shipped defaults already present
# (detected by the marker `source: shipped-default`).
# Returns 0.
# ---------------------------------------------------------------------------
ac_migration_prepend_shipped_defaults() {
  local data_dir pfile shipped_template tmp
  data_dir="$(_ac_migration_home_dir)"
  pfile="$data_dir/principles.md"
  shipped_template="$_AC_MIG_PLUGIN_DIR/templates/principles.md"

  [[ -f "$pfile" ]] || return 0

  # Idempotency: if shipped defaults already present, skip.
  if grep -q 'source: shipped-default' "$pfile" 2>/dev/null; then
    return 0
  fi

  if [[ ! -f "$shipped_template" ]]; then
    ac_log_warn "migration: shipped principles template not found at $shipped_template; skipping prepend"
    return 0
  fi

  tmp="$(mktemp "${pfile}.mig.XXXXXX")" || return 1

  # Layout: shipped template, then a marker comment, then existing user content.
  cat "$shipped_template" > "$tmp"
  printf '\n<!-- migrated from v0.1.x -->\n\n' >> "$tmp"
  cat "$pfile" >> "$tmp"

  mv "$tmp" "$pfile" || {
    rm -f "$tmp"
    ac_log_error "migration: failed to update principles.md"
    return 1
  }

  return 0
}

# ---------------------------------------------------------------------------
# ac_migration_check_v01_state — orchestrator (SPEC §10).
# Runs steps 1–4 in order. Prints one-line user-facing notice to stdout when
# a migration actually occurred (i.e., something on disk changed). Silent
# no-op on fresh install or when already migrated.
# Returns 0 always (best-effort upgrade — never block the user).
# ---------------------------------------------------------------------------
ac_migration_check_v01_state() {
  local data_dir notice_path migrated bak_path
  data_dir="$(_ac_migration_home_dir)"
  migrated=0
  notice_path=""

  # If the architect-critic dir does not exist at all, this is a fresh install.
  [[ -d "$data_dir" ]] || return 0

  # Step 1: state.json backup + fresh schema v2 init.
  if [[ -f "$data_dir/state.json" ]]; then
    local schema_ver
    schema_ver="$(jq -r '.schema_version // 0' "$data_dir/state.json" 2>/dev/null || echo 0)"
    if [[ "$schema_ver" =~ ^[0-9]+$ ]] && [[ "$schema_ver" -lt 2 ]] 2>/dev/null; then
      bak_path="$(ac_migration_backup_state)" || true
      if [[ -n "$bak_path" ]]; then
        migrated=1
        notice_path="$bak_path"
      fi
    fi
  fi

  # Step 2: relocate inbox/outbox if present.
  if [[ -d "$data_dir/inbox" || -d "$data_dir/outbox" ]]; then
    ac_migration_move_inbox_outbox || true
    migrated=1
    [[ -n "$notice_path" ]] || notice_path="$data_dir/legacy-v0.1.x/"
  fi

  # Step 3: principles.md prepend (only if file exists and lacks shipped block).
  if [[ -f "$data_dir/principles.md" ]] && ! grep -q 'source: shipped-default' "$data_dir/principles.md" 2>/dev/null; then
    ac_migration_prepend_shipped_defaults || true
    migrated=1
    [[ -n "$notice_path" ]] || notice_path="$data_dir/principles.md"
  fi

  # Step 4: user-facing notice when migration occurred.
  if [[ "$migrated" -eq 1 ]]; then
    echo "architect-critic upgraded from v0.1.x to v0.2.0. Legacy state preserved at ${notice_path}. See CHANGELOG for breaking changes."
  fi

  return 0
}

# ---------------------------------------------------------------------------
# CLI dispatch — supports `bash lib/migration.sh check-v01-state` (Phase 8 smoke).
# ---------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    check-v01-state) ac_migration_check_v01_state ;;
    *) echo "Usage: $0 check-v01-state" >&2; exit 2 ;;
  esac
fi
