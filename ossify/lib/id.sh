#!/usr/bin/env bash
# ossify ID grammar — single owner (spec §9.2 / OQ7). No VS- shapes.

oss_id_valid_release()   { printf '%s' "$1" | { grep -Eq '^r[0-9]+$' || return 1; }; }
oss_id_valid_spine()     { printf '%s' "$1" | { grep -Eq '^r[0-9]+\.s[0-9]+$' || return 1; }; }
oss_id_valid_work_item() { printf '%s' "$1" | { grep -Eq '^r[0-9]+\.s[0-9]+\.w[0-9]+$' || return 1; }; }

oss_id_parse() {
  local id="$1"
  if oss_id_valid_release "$id"; then
    echo "release ${id#r}"
  elif oss_id_valid_spine "$id"; then
    local r="${id%%.*}" s="${id##*.s}"
    echo "spine ${r#r} ${s}"
  elif oss_id_valid_work_item "$id"; then
    local r rest s w
    r="${id%%.*}"
    rest="${id#*.s}"
    s="${rest%%.*}"
    w="${id##*.w}"
    echo "work_item ${r#r} ${s} ${w}"
  else
    return 1
  fi
}

oss_id_branch_name() { echo "spine/$1-$2"; }
oss_id_release_dir() { echo "docs/specs/$1"; }

_oss_id_max_plus_one() { # $1=jq array path, $2=strip-prefix regex, $3=state file
  { jq -r "$1[].id" "$3" 2>/dev/null || true; } \
    | { grep -E "$2" || true; } \
    | sed -E "s/$2//" \
    | sort -n | tail -1 | awk '{print $1+1}'
}

oss_id_next_release() {
  local n
  n="$(_oss_id_max_plus_one '.releases' '^r' "$1")"
  echo "r${n:-0}"
}
oss_id_next_spine() { # $1=state $2=release-id
  local n
  n="$({ jq -r '.spines[].id' "$1" 2>/dev/null || true; } \
    | { grep -E "^$2\.s[0-9]+$" || true; } \
    | sed -E 's/^.*\.s//' | sort -n | tail -1 | awk '{print $1+1}')"
  echo "$2.s${n:-1}"
}
oss_id_next_work_item() { # $1=state $2=spine-id
  local n
  n="$({ jq -r '.work_items[].id' "$1" 2>/dev/null || true; } \
    | { grep -E "^$2\.w[0-9]+$" || true; } \
    | sed -E 's/^.*\.w//' | sort -n | tail -1 | awk '{print $1+1}')"
  echo "$2.w${n:-1}"
}
