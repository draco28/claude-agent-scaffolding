#!/usr/bin/env bash
# Entity write paths: thin payload builders over oss_state_mutate.

oss_entity_add_release() { # $1=state $2=name $3=goal
  local sf="$1" id ts
  id="$(oss_id_next_release "$sf")"; ts="$(_oss_now)"
  oss_state_mutate "$sf" add_release \
    "$(jq -n --arg id "$id" --arg n "$2" --arg g "$3" --arg ts "$ts" \
      '{id:$id,name:$n,goal:$g,status:"planned",created_at:$ts}')" || return $?
  echo "$id"
}

oss_entity_add_spine() { # $1=state $2=release-id $3=name $4=class $5=target_repo
  local sf="$1" rel="$2" class="$4" id ts
  case "$class" in bone|flesh) ;; *) echo "oss: class must be bone|flesh" >&2; return 2;; esac
  jq -e --arg r "$rel" '.releases[] | select(.id == $r)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown release '$rel'" >&2; return 7; }
  id="$(oss_id_next_spine "$sf" "$rel")"; ts="$(_oss_now)"
  oss_state_mutate "$sf" add_spine \
    "$(jq -n --arg id "$id" --arg r "$rel" --arg n "$3" --arg c "$class" --arg t "$5" --arg ts "$ts" \
      '{id:$id,release:$r,name:$n,class:$c,target_repo:$t,status:"planned",created_at:$ts}')" || return $?
  echo "$id"
}

oss_entity_add_work_item() { # $1=state $2=spine-id $3=title
  local sf="$1" spine="$2" id ts
  jq -e --arg s "$spine" '.spines[] | select(.id == $s)' "$sf" >/dev/null 2>&1 \
    || { echo "oss: unknown spine '$spine'" >&2; return 7; }
  id="$(oss_id_next_work_item "$sf" "$spine")"; ts="$(_oss_now)"
  oss_state_mutate "$sf" add_work_item \
    "$(jq -n --arg id "$id" --arg s "$spine" --arg t "$3" --arg ts "$ts" \
      '{id:$id,spine:$s,title:$t,status:"planned",created_at:$ts}')" || return $?
  echo "$id"
}

oss_entity_set_spine_class() { # $1=state $2=spine-id $3=new-class $4=reason
  local sf="$1" spine="$2" to="$3" from ts
  case "$to" in bone|flesh) ;; *) echo "oss: class must be bone|flesh" >&2; return 2;; esac
  from="$(jq -r --arg s "$spine" '.spines[] | select(.id == $s) | .class // empty' "$sf")"
  [ -n "$from" ] || { echo "oss: unknown spine '$spine'" >&2; return 7; }
  ts="$(_oss_now)"
  oss_state_mutate "$sf" set_spine_class \
    "$(jq -n --arg s "$spine" --arg f "$from" --arg t2 "$to" --arg r "$4" --arg ts "$ts" \
      '{spine:$s,from:$f,to:$t2,reason:$r,at:$ts}')"
}
