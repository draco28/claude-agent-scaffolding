#!/usr/bin/env bash
# Bones / risk gates / fakes / feature map + touch-surface matching.

_oss_csv_to_json() { printf '%s\n' "$1" | jq -R 'split(",") | map(gsub("^ +| +$";"")) | map(select(length>0))'; }

oss_reg_add_bone() { # $1=state $2=adr-ref $3=title $4=touch-csv $5=revisit(optional)
  oss_state_mutate "$1" add_bone \
    "$(jq -n --arg adr "$2" --arg t "$3" --argjson touch "$(_oss_csv_to_json "$4")" \
        --arg rv "${5:-}" --arg ts "$(_oss_now)" \
      '{adr:$adr,title:$t,touch:$touch,revisit_trigger:(if $rv=="" then null else $rv end),at:$ts}')"
}

oss_reg_add_risk_gate() { # $1=state $2=name $3=touch-csv $4=controls-csv
  oss_state_mutate "$1" add_risk_gate \
    "$(jq -n --arg n "$2" --argjson touch "$(_oss_csv_to_json "$3")" \
        --argjson c "$(_oss_csv_to_json "$4")" --arg ts "$(_oss_now)" \
      '{name:$n,touch:$touch,controls:$c,at:$ts}')"
}

oss_reg_add_fake() { # $1=state $2=boundary $3=channel $4=reason $5=trigger $6=expiry-release
  case "$3" in real|fake|deferred) ;; *) echo "oss: channel must be real|fake|deferred" >&2; return 2;; esac
  oss_state_mutate "$1" add_fake \
    "$(jq -n --arg b "$2" --arg c "$3" --arg r "$4" --arg tr "$5" --arg ex "$6" --arg ts "$(_oss_now)" \
      '{boundary:$b,channel:$c,reason:$r,replacement_trigger:$tr,expiry_release:$ex,status:"active",at:$ts}')"
}

oss_reg_add_feature() { # $1=state $2=name $3=value $4=class-guess $5=source
  oss_state_mutate "$1" add_feature \
    "$(jq -n --arg n "$2" --arg v "$3" --arg cg "$4" --arg s "$5" --arg ts "$(_oss_now)" \
      '{name:$n,value:$v,class_guess:$cg,source:$s,at:$ts}')"
}

# Touch-surface matching: bones/risk_gates store touch:[glob,...]. Matches
# each given path against every stored glob via bash `case` glob semantics
# (case-globs: `*` matches `/`, so `src/domain/**` matches any path under
# src/domain/ as a plain prefix-wildcard - not a real double-star). Prints
# `bone <adr>` / `risk_gate <name>` per match, rc 0 if any path matched any
# glob, rc 1 if clean. Dedup of repeated matches is deliberately not done in
# v1 (callers act on any-match, not on the match list).
oss_reg_touch_check() { # $1=state $2..=paths ; rc 0 if any match, 1 if clean
  local sf="$1"; shift
  local hit=1 path glob kind name
  while IFS=$'\t' read -r kind name glob; do
    [ -n "$glob" ] || continue
    for path in "$@"; do
      # shellcheck disable=SC2254
      case "$path" in $glob) echo "$kind $name"; hit=0;; esac
    done
  done < <(
    { jq -r '.bones[] | . as $b | .touch[] | ["bone", $b.adr, .] | @tsv' "$sf" 2>/dev/null || true; }
    { jq -r '.risk_gates[] | . as $g | .touch[] | ["risk_gate", $g.name, .] | @tsv' "$sf" 2>/dev/null || true; }
  )
  return "$hit"
}
