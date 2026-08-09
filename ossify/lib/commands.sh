#!/usr/bin/env bash
# Dispatcher subcommands for the onboarding + planning skills. Thin wrappers:
# resolve the state path (explicit > OSS_STATE_FILE > manifest) then delegate to
# the tested lib functions. NO judgment logic here - that lives in the skills.

oss_cmd_init() { # $1=project-name
  local sf; sf="$(_oss_resolve_state)" || return $?
  oss_state_init "$sf" "$1"
}
oss_cmd_posture_set() { # $1=posture
  local sf; sf="$(_oss_resolve_state)" || return $?
  oss_state_mutate "$sf" set_posture "$(jq -n --arg p "$1" '{posture:$p}')"
}
oss_cmd_composition_set() { # $1=composition-root
  local sf; sf="$(_oss_resolve_state)" || return $?
  oss_state_mutate "$sf" set_composition "$(jq -n --arg c "$1" '{composition_root:$c}')"
}
oss_cmd_overlay_set() { # $1=overlay-wiring
  local sf; sf="$(_oss_resolve_state)" || return $?
  oss_state_mutate "$sf" set_overlay "$(jq -n --arg o "$1" '{overlay_wiring:$o}')"
}
oss_cmd_release_add() { # $1=name $2=goal
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_add_release "$sf" "$1" "$2"
}
oss_cmd_spine_add() { # $1=release $2=name $3=class [$4=target_repo]
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_add_spine "$sf" "$1" "$2" "$3" "${4:-canonical}"
}
oss_cmd_class_set() { # $1=spine $2=new-class $3=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_spine_class "$sf" "$1" "$2" "$3"
}
oss_cmd_bone_add() { # $1=adr $2=title $3=touch-csv [$4=revisit]
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_add_bone "$sf" "$1" "$2" "$3" "${4:-}"
}
oss_cmd_risk_gate_add() { # $1=name $2=touch-csv $3=controls-csv
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_add_risk_gate "$sf" "$1" "$2" "$3"
}
oss_cmd_fake_add() { # $1=boundary $2=channel $3=reason $4=trigger $5=expiry-release
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_add_fake "$sf" "$1" "$2" "$3" "$4" "$5"
}
oss_cmd_feature_add() { # $1=name $2=value $3=class-guess $4=source
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_add_feature "$sf" "$1" "$2" "$3" "$4"
}
oss_cmd_touch_check() { # $@=paths
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_touch_check "$sf" "$@"
}
oss_cmd_ledger_add_auto() { # $1=spine $2=text $3=command $4=expected
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_add_auto "$sf" "$1" "$2" "$3" "$4"
}
oss_cmd_ledger_add_user() { # $1=spine $2=text $3=outcome
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_add_user "$sf" "$1" "$2" "$3"
}
oss_cmd_ledger_supersede() { # $1=line $2=by-spine $3=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_supersede "$sf" "$1" "$2" "$3"
}
oss_cmd_ledger_retire() { # $1=line $2=by-spine $3=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_retire "$sf" "$1" "$2" "$3"
}
oss_cmd_ledger_quarantine()    { local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_quarantine "$sf" "$1" "$2" "${3:-}"; }
oss_cmd_ledger_apply_pending() { local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_apply_pending "$sf" "$1"; }
oss_cmd_ledger_unplan()        { local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_unplan "$sf" "$1" "$2"; }
oss_cmd_fake_status()          { local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_set_fake_status "$sf" "$1" "$2" "$3" "${4:-}"; }
# The two release-close blocking gates (§6.2 steps 3 and 4). Both are rc 0 =
# CLEAN / 1 = BLOCKING / 2 = could-not-check - the OPPOSITE polarity to
# `touch_check`, which is 0 = hit. Read-only selectors: no mutation, no op.
oss_cmd_expired_fakes()        { local sf; sf="$(_oss_resolve_state)" || return $?; oss_reg_expired_fakes "$sf" "$1"; }
oss_cmd_expired_quarantines()  { local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_expired_quarantines "$sf" "$1"; }
oss_cmd_patch_add() { # $1=commit $2=text
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_add_patch "$sf" "$1" "$2"
}
# Explicit state file beats the environment. Without this argument a pre-flight
# probe in one project silently reads another project's state via a stale
# exported $OSS_STATE_FILE (final review, Minor 1).
oss_cmd_get() { # $1=jq-expr [$2=state-file]
  local sf; sf="$(_oss_resolve_state "${2:-}")" || return $?
  oss_state_read "$sf" "$1"
}

oss_cmd_state_restore()  { local sf; sf="$(_oss_resolve_state "${1:-}")" || return $?; oss_state_restore "$sf"; }
oss_cmd_manifest_get()   { oss_manifest_get "$1"; }
oss_cmd_manifest_require(){ oss_manifest_require; }
oss_cmd_work_item_branch(){ oss_id_work_item_branch "$1" "$2"; }
oss_cmd_spine_dir()      { oss_id_spine_dir "$1" "$2" "$3"; }
oss_cmd_branch_name()    { oss_id_branch_name "$1" "$2"; }
# The close router (Task 9) derives its scope from the id SHAPE, so it needs this
# through the dispatcher - oss_id_parse has no wrapper today, and skill prose
# cannot reach a bare lib function (bin/oss dispatches only oss_cmd_*).
oss_cmd_id_parse()       { oss_id_parse "$1"; }
oss_cmd_feature_list()      { local sf; sf="$(_oss_resolve_state)" || return $?; oss_state_read "$sf" '[.feature_map[]]'; }
oss_cmd_spine_list()        { local sf; sf="$(_oss_resolve_state)" || return $?; oss_state_read "$sf" '[.spines[]]'; }
oss_cmd_ledger_active_auto(){ local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_active_auto "$sf"; }
oss_cmd_work_item_add() { # $1=spine $2=title [$3=target_repo]
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_add_work_item "$sf" "$1" "$2" "${3:-canonical}"
}
oss_cmd_release_set_meta() { # $1=release $2=patch-json
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_release_meta "$sf" "$1" "$2"
}
oss_cmd_veto_add() { # $1=spine $2=finding $3=disposition $4=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_add_veto "$sf" "$1" "$2" "$3" "$4"
}
oss_cmd_spine_status()     { local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_spine_status "$sf" "$1" "$2"; }
oss_cmd_work_item_status() { local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_work_item_status "$sf" "$1" "$2"; }
oss_cmd_release_status()   { local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_release_status "$sf" "$1" "$2"; }
oss_cmd_work_item_exec()   { local sf; sf="$(_oss_resolve_state)" || return $?; oss_entity_set_work_item_exec "$sf" "$1" "$2" "$3" "$4"; }

# §9.2's explicit, never-silent migration. Journals a `migrate_schema` op rather
# than rewriting the file in place, so `$sf.base.json` stays v1 and replay still
# rebuilds live from base+journal across the version boundary.
oss_cmd_migrate() { # [$1=state-file]
  local sf v; sf="$(_oss_resolve_state "${1:-}")" || return $?
  v="$(jq -r '.schema_version // empty' "$sf" 2>/dev/null)" || v=""
  case "$v" in ''|*[!0-9]*) echo "oss: state schema missing/invalid - cannot migrate" >&2; return 6 ;; esac
  if [ "$v" -eq "$OSS_STATE_SCHEMA_VERSION" ]; then echo "already at v$v"; return 0; fi
  if [ "$v" -gt "$OSS_STATE_SCHEMA_VERSION" ]; then
    echo "oss: state schema v$v is newer than this build (v$OSS_STATE_SCHEMA_VERSION) - upgrade ossify, do not migrate" >&2
    return 6
  fi
  # F1 (2026-07-31): `migrate_schema` is version-agnostic (every clause
  # `has(...)`-guarded, verified against both a v1 and a v2 fixture) and
  # single-hop by design - it carries every upgrade the registry knows about
  # in one journaled op, not one op per version. This allowlist is deliberately
  # exact (1|2), not "< current": a state at some OTHER stale version is a gap
  # this build does not know how to close and must say so by name, never
  # guess-migrate it.
  case "$v" in
    1|2) ;;
    *) echo "oss: no migration path from v$v to v$OSS_STATE_SCHEMA_VERSION" >&2; return 6 ;;
  esac
  oss_state_mutate "$sf" migrate_schema \
    "$(jq -n --argjson from "$v" --argjson to "$OSS_STATE_SCHEMA_VERSION" '{from:$from,to:$to}')" || return $?
  echo "migrated v$v -> v$OSS_STATE_SCHEMA_VERSION"
}

# Filesystem probe for architect-critic v0.2 (binary v0.2-or-absent), mirroring
# scaffold-onboard's sf_compose_detect_architect_critic. Used by start's
# spec-core critic moment. No composition.json read. Stateless by design: it
# takes no state path and needs no manifest, so a skill can probe before (or
# without) an initialized project.
# Scan EVERY cache before deciding, and report the highest version found. The
# previous form returned on the first hit and globbed only critiquing-spec, so a
# stale v0.2 directory won over a newer v0.3 install and v0.3 was unreportable.
oss_cmd_critic_detect() {
  local cache critic_root skill_md found="absent"
  # An explicit override root (set by the .opencode wrapper when ossify is
  # selected as the architect-critic capability) takes priority over the
  # ambient cache scan. The root points at the plugin directory itself
  # (e.g. architect-critic/skills/critiquing-spec/SKILL.md).
  critic_root="${OSS_ARCHITECT_CRITIC_ROOT:-}"
  if [ -n "$critic_root" ] && [ -f "$critic_root/skills/critiquing-spec/SKILL.md" ]; then
    if [ -f "$critic_root/skills/managing-async-critique/SKILL.md" ]; then
      echo "v0.3"
    else
      echo "v0.2"
    fi
    return 0
  fi
  # `${HOME:-}`, not `${HOME}`: under the dispatcher's `set -u` an unset HOME is a
  # fatal parameter-expansion error raised BEFORE the loop body runs, so none of
  # the errexit-exemption machinery below applies - the probe dies with empty
  # stdout instead of echoing `absent`. That breaks the documented contract that
  # it answers on any machine, installed or not. The sibling was already guarded.
  for cache in "${HOME:-}/.claude/plugins/cache" "${CLAUDE_PLUGINS_DIR:-}"; do
    { [ -z "$cache" ] || [ ! -d "$cache" ]; } && continue
    for skill_md in "$cache"/*/architect-critic/*/skills/critiquing-spec/SKILL.md; do
      [ -f "$skill_md" ] || continue
      if [ -f "${skill_md%/skills/critiquing-spec/SKILL.md}/skills/managing-async-critique/SKILL.md" ]; then
        found="v0.3"
      elif [ "$found" = "absent" ]; then
        found="v0.2"
      fi
    done
  done
  echo "$found"
  [ "$found" = "absent" ] && return 1
  return 0
}

# Per-work-item verification gate (Task 5 / spec §6). Thin wrappers, no
# judgment logic - state-file resolution does not apply here, these take
# explicit paths/args like the id.sh wrappers above.
oss_cmd_verify_acs()          { oss_verify_parse_acs "$1"; }
oss_cmd_verify_step()         { oss_verify_auto_step "$1" "$2" "$3"; }
oss_cmd_redgate()             { oss_verify_redgate "$1" "$2" "$3"; }
oss_cmd_zero_tests_guard()    { oss_verify_zero_tests_guard "$1"; }
oss_cmd_report_cross_check()  { oss_verify_report_cross_check "$1" "$2"; }

# Per-work-item worktree layer (Task 4). D4: repo-parameterized - only
# `canonical` resolves today, Plan D adds `private_core` by extending
# _oss_repo_root alone. Thin dispatcher wrappers, no judgment logic.
oss_cmd_repo_root()        { _oss_repo_root "${1:-canonical}"; }
oss_cmd_worktree_add()     { oss_worktree_add "$1" "$2" "$3" "${4:-HEAD}"; }
oss_cmd_worktree_resolve() { oss_worktree_resolve "$1" "$2"; }
oss_cmd_worktree_remove()  { oss_worktree_remove "$1" "$2"; }
oss_cmd_worktree_list()    { oss_worktree_list "${1:-canonical}"; }

# Cumulative demo runner (spec §6.1 + companion §4.3). Thin dispatcher
# wrappers, no judgment logic - resolution (workdir, composition root) lives in
# lib/demo.sh; the vacuous-green guard lives in lib/verify.sh.
oss_cmd_demo_run() { # [$1=state-file] [$2=workdir]
  local sf; sf="$(_oss_resolve_state "${1:-}")" || return $?
  oss_demo_run_auto "$sf" "${2:-}"
}
oss_cmd_demo_user_lines() { local sf; sf="$(_oss_resolve_state)" || return $?; oss_demo_user_lines "$sf" "${1:-}"; }
oss_cmd_demo_record()     { local sf; sf="$(_oss_resolve_state)" || return $?; oss_demo_record_close "$sf" "$1" "$2" "$3" "$4" "${5:-}"; }

# Memory-bank harvest (spec §6.1's core row), driven from spine close step 9.
# `harvest_dir` takes no state and needs none - it resolves the memory bank from
# the manifest alone. `harvest_apply` keeps the house state-first shape, and the
# lib deliberately does not read it: the harvest writes to the memory bank, not
# to state. `${1:-}` rather than `$1` so a missing payload is the lib's own rc-2
# usage error instead of a strict-mode unbound-variable abort.
oss_cmd_harvest_dir()   { oss_harvest_memory_bank_dir; }
oss_cmd_harvest_apply() { # $1=payload-json
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_harvest_apply "$sf" "${1:-}"
}
