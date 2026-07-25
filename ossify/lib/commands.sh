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
oss_cmd_ledger_quarantine() { # $1=line $2=reason
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_quarantine "$sf" "$1" "$2"
}
oss_cmd_patch_add() { # $1=commit $2=text
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_add_patch "$sf" "$1" "$2"
}
oss_cmd_get() { # $1=jq-expr
  local sf; sf="$(_oss_resolve_state)" || return $?; oss_state_read "$sf" "$1"
}
oss_cmd_feature_list()      { local sf; sf="$(_oss_resolve_state)" || return $?; oss_state_read "$sf" '[.feature_map[]]'; }
oss_cmd_spine_list()        { local sf; sf="$(_oss_resolve_state)" || return $?; oss_state_read "$sf" '[.spines[]]'; }
oss_cmd_ledger_active_auto(){ local sf; sf="$(_oss_resolve_state)" || return $?; oss_ledger_active_auto "$sf"; }
