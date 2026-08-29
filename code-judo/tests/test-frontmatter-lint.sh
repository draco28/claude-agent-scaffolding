#!/usr/bin/env bash
#
# code-judo — frontmatter lint
#
# Asserts each skills/*/SKILL.md complies with the plugin's frontmatter contract:
#
#   - YAML frontmatter fenced by ---
#   - `name` and `description` both present
#   - `name` is kebab-case and matches its directory
#   - `description` is non-empty and ≤1024 chars (Claude Code's limit)
#   - NO `version` field, NO `when_to_use` field
#   - the ONLY optional field is `disable-model-invocation`, and no other key
#     may appear at all
#   - the two human-invoked-only skills carry `disable-model-invocation: true`,
#     and the two model-invocable skills do NOT carry the key
#
# The last two checks are a matched pair on purpose. Allowing a third field is a
# LOOSENING of ai-mentor's exactly-two-fields rule, so the adjacent control is
# the unknown-key check: widening the set by one named key must not stop the
# lint detecting any other key. Both must hold, or the loosening has quietly
# turned into "anything goes".
#
# Usage:   bash code-judo/tests/test-frontmatter-lint.sh
# Exit:    0 if every skill passes every check; 1 if any check fails.
# Deps:    bash 3.2+ (no GNU-isms), awk. No jq, no yq.

set -u  # failures are counted explicitly; do not `set -e`

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$PLUGIN_ROOT/skills"

# Skills that must be human-invoked only (space-separated, matched whole-word).
HUMAN_ONLY="deep-review deepen-architecture"

PASS=0
FAIL=0

if [ -t 1 ]; then
  GREEN=$(printf '\033[32m'); RED=$(printf '\033[31m'); DIM=$(printf '\033[2m'); RST=$(printf '\033[0m')
else
  GREEN=""; RED=""; DIM=""; RST=""
fi

pass() { PASS=$((PASS+1)); printf '  %s✓%s %s\n' "$GREEN" "$RST" "$1"; }
fail() {
  FAIL=$((FAIL+1))
  printf '  %s✗%s %s\n' "$RED" "$RST" "$1"
  [ -n "${2:-}" ] && printf '      %s%s%s\n' "$DIM" "$2" "$RST"
  return 0
}

# Frontmatter block: the lines between the first two `---` fences.
extract_frontmatter() {
  awk '
    BEGIN { state = 0 }
    /^---[[:space:]]*$/ {
      if (state == 0) { state = 1; next }
      else if (state == 1) { state = 2; exit }
    }
    state == 1 { print }
  ' "$1"
}

# Key names, one per line. Flat YAML only, which is the convention here.
extract_keys() {
  printf '%s\n' "$1" | awk '
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*#/ { next }
    {
      idx = index($0, ":")
      if (idx == 0) next
      key = substr($0, 1, idx - 1)
      sub(/^[[:space:]]+/, "", key)
      sub(/[[:space:]]+$/, "", key)
      if (key != "") print key
    }
  '
}

# Raw value of one key, as a single line (everything after the first colon).
extract_value() {
  printf '%s\n' "$1" | awk -v k="$2" '
    {
      idx = index($0, ":")
      if (idx == 0) next
      this_key = substr($0, 1, idx - 1)
      this_val = substr($0, idx + 1)
      sub(/^[[:space:]]+/, "", this_key)
      sub(/[[:space:]]+$/, "", this_key)
      if (this_key == k) {
        sub(/^[[:space:]]+/, "", this_val)
        sub(/[[:space:]]+$/, "", this_val)
        print this_val
        exit
      }
    }
  '
}

count_key() {
  printf '%s\n' "$1" | awk -v k="$2" '$0 == k { n++ } END { print n+0 }'
}

is_kebab_case() {
  case "$1" in
    "" ) return 1 ;;
    -*|*-) return 1 ;;
    *[!a-z0-9-]* ) return 1 ;;
    *) return 0 ;;
  esac
}

is_human_only() {
  case " $HUMAN_ONLY " in
    *" $1 "*) return 0 ;;
    *) return 1 ;;
  esac
}

check_skill() {
  skill_md="$1"
  skill_name="$(basename "$(dirname "$skill_md")")"
  rel_path="skills/$skill_name/SKILL.md"

  printf '\n%s%s%s\n' "$DIM" "── $rel_path ──" "$RST"

  fm="$(extract_frontmatter "$skill_md")"
  if [ -z "$fm" ]; then
    fail "$rel_path: has YAML frontmatter fenced by ---" "no frontmatter block found"
    return 0
  fi
  pass "$rel_path: has YAML frontmatter fenced by ---"

  keys="$(extract_keys "$fm")"

  # Required keys.
  if [ "$(count_key "$keys" name)" -ge 1 ]; then
    pass "$rel_path: has 'name'"
  else
    fail "$rel_path: has 'name'" "missing"
  fi
  if [ "$(count_key "$keys" description)" -ge 1 ]; then
    pass "$rel_path: has 'description'"
  else
    fail "$rel_path: has 'description'" "missing"
  fi

  # Banned keys.
  if [ "$(count_key "$keys" version)" -eq 0 ]; then
    pass "$rel_path: no 'version'"
  else
    fail "$rel_path: no 'version'" "skill frontmatter carries no version; the plugin manifest owns versioning"
  fi
  if [ "$(count_key "$keys" when_to_use)" -eq 0 ]; then
    pass "$rel_path: no 'when_to_use'"
  else
    fail "$rel_path: no 'when_to_use'" "fold it into description"
  fi

  # Control for the loosening: nothing outside the allowed set may appear.
  unknown="$(printf '%s\n' "$keys" | awk '
    NF && $0 != "name" && $0 != "description" && $0 != "disable-model-invocation"
  ' | awk '{ printf "%s%s", sep, $0; sep = ", " }')"
  if [ -z "$unknown" ]; then
    pass "$rel_path: no unknown frontmatter keys"
  else
    fail "$rel_path: no unknown frontmatter keys" "found: [$unknown]"
  fi

  # name.
  name_val="$(extract_value "$fm" name)"
  if is_kebab_case "$name_val"; then
    pass "$rel_path: 'name' is kebab-case ('$name_val')"
  else
    fail "$rel_path: 'name' is kebab-case" "name='$name_val'"
  fi
  if [ "$name_val" = "$skill_name" ]; then
    pass "$rel_path: 'name' matches directory"
  else
    fail "$rel_path: 'name' matches directory" "directory='$skill_name' but name='$name_val'"
  fi

  # description.
  desc_val="$(extract_value "$fm" description)"
  desc_len=$(printf '%s' "$desc_val" | awk '{ total += length($0) } END { print total+0 }')
  if [ "$desc_len" -eq 0 ]; then
    fail "$rel_path: 'description' is non-empty" "empty"
  elif [ "$desc_len" -le 1024 ]; then
    pass "$rel_path: 'description' length ${desc_len}/1024"
  else
    fail "$rel_path: 'description' length ≤1024" "actual=${desc_len} (over by $((desc_len-1024)))"
  fi

  # Invocation posture — asserted in BOTH directions.
  dmi_count="$(count_key "$keys" disable-model-invocation)"
  dmi_val="$(extract_value "$fm" disable-model-invocation)"
  if is_human_only "$skill_name"; then
    if [ "$dmi_count" -ge 1 ] && [ "$dmi_val" = "true" ]; then
      pass "$rel_path: human-invoked only (disable-model-invocation: true)"
    else
      fail "$rel_path: human-invoked only (disable-model-invocation: true)" \
        "count=$dmi_count value='$dmi_val' — this skill must never be model-triggered"
    fi
  else
    if [ "$dmi_count" -eq 0 ]; then
      pass "$rel_path: model-invocable (no disable-model-invocation key)"
    else
      fail "$rel_path: model-invocable (no disable-model-invocation key)" \
        "found the key with value '$dmi_val'; this skill is meant to be reachable by trigger"
    fi
  fi
}

printf '%scode-judo frontmatter lint%s\n' "$DIM" "$RST"
printf '%sskills dir: %s%s\n' "$DIM" "$SKILLS_DIR" "$RST"

if [ ! -d "$SKILLS_DIR" ]; then
  printf '%s✗%s skills directory missing at %s\n' "$RED" "$RST" "$SKILLS_DIR"
  exit 1
fi

found_any=0
for skill_md in "$SKILLS_DIR"/*/SKILL.md; do
  [ -e "$skill_md" ] || continue
  found_any=1
  check_skill "$skill_md"
done

if [ "$found_any" -eq 0 ]; then
  printf '\n%s✗%s no skills found under %s/*/SKILL.md\n' "$RED" "$RST" "$SKILLS_DIR"
  exit 1
fi

# Every skill named human-only must actually exist, or the posture assertions
# above passed vacuously by iterating over a set that never contained them.
for expected in $HUMAN_ONLY; do
  if [ -f "$SKILLS_DIR/$expected/SKILL.md" ]; then
    pass "human-invoked skill '$expected' exists"
  else
    fail "human-invoked skill '$expected' exists" "no skills/$expected/SKILL.md"
  fi
done

printf '\n%s──%s %d passed, %d failed\n' "$DIM" "$RST" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
